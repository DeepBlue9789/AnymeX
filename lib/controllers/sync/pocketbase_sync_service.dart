import 'dart:async';
import 'dart:convert';

import 'package:anymex/controllers/sync/gist_sync_service.dart';
import 'package:anymex/utils/logger.dart';
import 'package:http/http.dart' as http;

class PocketBaseAuthResult {
  final bool success;
  final String token;
  final String userId;
  final String email;
  final String message;

  const PocketBaseAuthResult({
    required this.success,
    this.token = '',
    this.userId = '',
    this.email = '',
    this.message = '',
  });
}

class PocketBaseTestResult {
  final bool success;
  final String message;
  final bool progressCollectionExists;
  final bool historyCollectionExists;

  const PocketBaseTestResult({
    required this.success,
    required this.message,
    this.progressCollectionExists = false,
    this.historyCollectionExists = false,
  });
}

class PocketBaseSyncService {
  static final PocketBaseSyncService _instance = PocketBaseSyncService._internal();
  factory PocketBaseSyncService() => _instance;
  PocketBaseSyncService._internal();

  String _cleanUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url;
  }

  Map<String, String> _headers(String? token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = token;
    }
    return headers;
  }

  Future<PocketBaseAuthResult> authenticate({
    required String baseUrl,
    required String identity,
    required String password,
  }) async {
    try {
      final url = _cleanUrl(baseUrl);
      final body = jsonEncode({
        'identity': identity.trim(),
        'password': password,
      });

      // 1. Try standard user collection ('users')
      final userAuthEndpoint = Uri.parse('$url/api/collections/users/auth-with-password');
      final response = await http
          .post(userAuthEndpoint, headers: _headers(null), body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String? ?? '';
        final record = data['record'] as Map<String, dynamic>? ?? {};
        final userId = record['id'] as String? ?? '';
        final email = record['email'] as String? ?? identity;

        return PocketBaseAuthResult(
          success: true,
          token: token,
          userId: userId,
          email: email,
          message: 'Authenticated successfully',
        );
      }

      // 2. Try PocketBase v0.23+ superuser auth ('_superusers')
      final superuserEndpoint = Uri.parse('$url/api/collections/_superusers/auth-with-password');
      final superuserResp = await http
          .post(superuserEndpoint, headers: _headers(null), body: body)
          .timeout(const Duration(seconds: 10));

      if (superuserResp.statusCode == 200) {
        final superData = jsonDecode(superuserResp.body) as Map<String, dynamic>;
        final token = superData['token'] as String? ?? '';
        final record = superData['record'] as Map<String, dynamic>? ?? {};
        final userId = record['id'] as String? ?? 'superuser';
        final email = record['email'] as String? ?? identity;

        return PocketBaseAuthResult(
          success: true,
          token: token,
          userId: userId,
          email: email,
          message: 'Authenticated as Superuser',
        );
      }

      // 3. Try legacy PocketBase (< v0.23) admin auth ('admins')
      final adminEndpoint = Uri.parse('$url/api/admins/auth-with-password');
      final adminResp = await http
          .post(adminEndpoint, headers: _headers(null), body: body)
          .timeout(const Duration(seconds: 10));

      if (adminResp.statusCode == 200) {
        final adminData = jsonDecode(adminResp.body) as Map<String, dynamic>;
        final token = adminData['token'] as String? ?? '';
        final adminObj = adminData['admin'] as Map<String, dynamic>? ?? {};
        final adminId = adminObj['id'] as String? ?? 'admin';

        return PocketBaseAuthResult(
          success: true,
          token: token,
          userId: adminId,
          email: identity,
          message: 'Authenticated as Admin',
        );
      }

      final errData = jsonDecode(response.body) as Map<String, dynamic>?;
      final msg = errData?['message'] ?? 'Authentication failed (HTTP ${response.statusCode})';
      return PocketBaseAuthResult(success: false, message: msg.toString());
    } catch (e) {
      return PocketBaseAuthResult(success: false, message: 'Connection error: $e');
    }
  }

  Future<PocketBaseTestResult> testConnection({
    required String baseUrl,
    required String identity,
    required String password,
  }) async {
    final auth = await authenticate(
      baseUrl: baseUrl,
      identity: identity,
      password: password,
    );

    if (!auth.success) {
      return PocketBaseTestResult(
        success: false,
        message: auth.message,
      );
    }

    final url = _cleanUrl(baseUrl);
    final collections = await _checkAndCreateCollections(url, auth.token);

    return PocketBaseTestResult(
      success: true,
      message: 'Connected & Authenticated as ${auth.email}',
      progressCollectionExists: collections['anymex_progress'] ?? false,
      historyCollectionExists: collections['anymex_history'] ?? false,
    );
  }

  Future<Map<String, bool>> _checkAndCreateCollections(String url, String token) async {
    final status = <String, bool>{
      'anymex_progress': false,
      'anymex_history': false,
    };

    final progressFields = [
      {'name': 'user_id', 'type': 'text', 'required': false},
      {'name': 'media_id', 'type': 'text', 'required': false, 'presentable': true},
      {'name': 'mal_id', 'type': 'text', 'required': false},
      {'name': 'media_type', 'type': 'text', 'required': false},
      {'name': 'service_type', 'type': 'text', 'required': false},
      {'name': 'episode_number', 'type': 'text', 'required': false},
      {'name': 'timestamp_ms', 'type': 'number', 'required': false},
      {'name': 'duration_ms', 'type': 'number', 'required': false},
      {'name': 'chapter_number', 'type': 'number', 'required': false},
      {'name': 'page_number', 'type': 'number', 'required': false},
      {'name': 'total_pages', 'type': 'number', 'required': false},
      {'name': 'scroll_offset', 'type': 'number', 'required': false},
      {'name': 'max_scroll_offset', 'type': 'number', 'required': false},
      {'name': 'updated_at', 'type': 'number', 'required': false},
      {'name': 'is_completed', 'type': 'bool', 'required': false},
      {'name': 'last_updated', 'type': 'text', 'required': false},
    ];

    final historyFields = [
      {'name': 'user_id', 'type': 'text', 'required': false},
      {'name': 'media_id', 'type': 'text', 'required': false, 'presentable': true},
      {'name': 'title', 'type': 'text', 'required': false},
      {'name': 'cover', 'type': 'text', 'required': false},
      {'name': 'poster', 'type': 'text', 'required': false},
      {'name': 'episode_number', 'type': 'text', 'required': false},
      {'name': 'episode_title', 'type': 'text', 'required': false},
      {'name': 'timestamp_ms', 'type': 'number', 'required': false},
      {'name': 'duration_ms', 'type': 'number', 'required': false},
      {'name': 'last_watched_time', 'type': 'number', 'required': false},
      {'name': 'source', 'type': 'text', 'required': false},
      {'name': 'media_type', 'type': 'text', 'required': false},
      {'name': 'thumbnail', 'type': 'text', 'required': false},
      {'name': 'episode_link', 'type': 'text', 'required': false},
      {'name': 'server', 'type': 'text', 'required': false},
      {'name': 'sub_language', 'type': 'text', 'required': false},
    ];

    try {
      final listEndpoint = Uri.parse('$url/api/collections?page=1&perPage=100');
      final resp = await http
          .get(listEndpoint, headers: _headers(token))
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        final collectionsMap = <String, Map<String, dynamic>>{};
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final name = item['name'] as String?;
            if (name != null) collectionsMap[name] = item;
          }
        }

        status['anymex_progress'] = collectionsMap.containsKey('anymex_progress');
        status['anymex_history'] = collectionsMap.containsKey('anymex_history');

        if (status['anymex_progress']!) {
          await _patchCollectionFields(url, token, collectionsMap['anymex_progress']!['id'] as String, progressFields);
        }
        if (status['anymex_history']!) {
          await _patchCollectionFields(url, token, collectionsMap['anymex_history']!['id'] as String, historyFields);
        }
      }
    } catch (_) {}

    // Auto-create missing collections if possible
    if (!(status['anymex_progress'] ?? false)) {
      status['anymex_progress'] = await _createCollection(url, token, {
        'name': 'anymex_progress',
        'type': 'base',
        'schema': progressFields,
        'fields': progressFields,
        'listRule': '',
        'viewRule': '',
        'createRule': '',
        'updateRule': '',
        'deleteRule': '',
      });
    }

    if (!(status['anymex_history'] ?? false)) {
      status['anymex_history'] = await _createCollection(url, token, {
        'name': 'anymex_history',
        'type': 'base',
        'schema': historyFields,
        'fields': historyFields,
        'listRule': '',
        'viewRule': '',
        'createRule': '',
        'updateRule': '',
        'deleteRule': '',
      });
    }

    return status;
  }

  Future<void> _patchCollectionFields(String url, String token, String collectionId, List<Map<String, dynamic>> desiredFields) async {
    try {
      final endpoint = Uri.parse('$url/api/collections/$collectionId');
      final resp = await http.get(endpoint, headers: _headers(token)).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final existingFields = (data['fields'] as List<dynamic>?) ?? (data['schema'] as List<dynamic>?) ?? [];

      final existingNames = existingFields
          .map((f) => (f as Map<String, dynamic>)['name'] as String?)
          .whereType<String>()
          .toSet();

      final missing = desiredFields.where((f) => !existingNames.contains(f['name'])).toList();
      if (missing.isEmpty) return;

      final updatedFields = List<dynamic>.from(existingFields)..addAll(missing);

      await http.patch(
        endpoint,
        headers: _headers(token),
        body: jsonEncode({'fields': updatedFields, 'schema': updatedFields}),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      Logger.i('Failed to patch collection fields for $collectionId: $e');
    }
  }

  Future<bool> _createCollection(String url, String token, Map<String, dynamic> schema) async {
    try {
      final endpoint = Uri.parse('$url/api/collections');
      final resp = await http
          .post(endpoint, headers: _headers(token), body: jsonEncode(schema))
          .timeout(const Duration(seconds: 8));

      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      Logger.i('Failed to auto-create collection ${schema['name']}: $e');
      return false;
    }
  }

  Future<bool> pushGistEntry({
    required String baseUrl,
    required String token,
    required String userId,
    required GistProgressEntry entry,
    bool isCompleted = false,
  }) async {
    try {
      final url = _cleanUrl(baseUrl);
      final filter = 'media_id="${entry.mediaId}" && user_id="$userId"';
      final searchEndpoint =
          Uri.parse('$url/api/collections/anymex_progress/records?filter=(${Uri.encodeComponent(filter)})');

      final searchResp = await http
          .get(searchEndpoint, headers: _headers(token))
          .timeout(const Duration(seconds: 5));

      if (isCompleted) {
        if (searchResp.statusCode == 200) {
          final data = jsonDecode(searchResp.body) as Map<String, dynamic>;
          final items = (data['items'] as List<dynamic>?) ?? [];
          if (items.isNotEmpty) {
            final recordId = (items.first as Map<String, dynamic>)['id'] as String;
            final deleteEndpoint = Uri.parse('$url/api/collections/anymex_progress/records/$recordId');
            final delResp = await http.delete(deleteEndpoint, headers: _headers(token));
            return delResp.statusCode == 204 || delResp.statusCode == 200;
          }
        }
        return true;
      }

      final payload = {
        'user_id': userId,
        'media_id': entry.mediaId,
        'mal_id': entry.malId ?? '',
        'media_type': entry.mediaType,
        'service_type': entry.serviceType ?? '',
        'episode_number': entry.episodeNumber ?? '',
        'timestamp_ms': entry.timestampMs ?? 0,
        'duration_ms': entry.durationMs ?? 0,
        'chapter_number': entry.chapterNumber ?? 0.0,
        'page_number': entry.pageNumber ?? 0,
        'total_pages': entry.totalPages ?? 0,
        'scroll_offset': entry.scrollOffset ?? 0.0,
        'max_scroll_offset': entry.maxScrollOffset ?? 0.0,
        'updated_at': entry.updatedAt,
        'is_completed': isCompleted,
        'last_updated': DateTime.now().toIso8601String(),
      };

      if (searchResp.statusCode == 200) {
        final data = jsonDecode(searchResp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        if (items.isNotEmpty) {
          final recordId = (items.first as Map<String, dynamic>)['id'] as String;
          final updateEndpoint = Uri.parse('$url/api/collections/anymex_progress/records/$recordId');
          final patchResp = await http.patch(updateEndpoint, headers: _headers(token), body: jsonEncode(payload));
          return patchResp.statusCode == 200;
        }
      }

      final createEndpoint = Uri.parse('$url/api/collections/anymex_progress/records');
      final createResp = await http.post(createEndpoint, headers: _headers(token), body: jsonEncode(payload));
      return createResp.statusCode == 200 || createResp.statusCode == 201;
    } catch (e) {
      Logger.e('PocketBase pushGistEntry failed: $e');
      return false;
    }
  }

  Future<GistProgressEntry?> fetchGistEntry({
    required String baseUrl,
    required String token,
    required String userId,
    required String mediaId,
  }) async {
    try {
      final url = _cleanUrl(baseUrl);
      final filter = 'media_id="$mediaId" && user_id="$userId"';
      final endpoint = Uri.parse(
          '$url/api/collections/anymex_progress/records?filter=(${Uri.encodeComponent(filter)})');

      final resp = await http.get(endpoint, headers: _headers(token)).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        if (items.isNotEmpty) {
          final item = items.first as Map<String, dynamic>;
          return GistProgressEntry(
            mediaId: item['media_id']?.toString() ?? mediaId,
            malId: item['mal_id']?.toString(),
            mediaType: item['media_type']?.toString() ?? 'anime',
            serviceType: item['service_type']?.toString(),
            episodeNumber: item['episode_number']?.toString(),
            timestampMs: item['timestamp_ms'] as int?,
            durationMs: item['duration_ms'] as int?,
            chapterNumber: (item['chapter_number'] as num?)?.toDouble(),
            pageNumber: item['page_number'] as int?,
            totalPages: item['total_pages'] as int?,
            scrollOffset: (item['scroll_offset'] as num?)?.toDouble(),
            maxScrollOffset: (item['max_scroll_offset'] as num?)?.toDouble(),
            updatedAt: item['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          );
        }
      }
      return null;
    } catch (e) {
      Logger.e('PocketBase fetchGistEntry failed: $e');
      return null;
    }
  }

  Future<bool> pushProgress({
    required String baseUrl,
    required String token,
    required String userId,
    required String mediaId,
    required String? malId,
    required String episodeNumber,
    required int timestampMs,
    int durationMs = 0,
    required bool isCompleted,
    String mediaType = 'anime',
  }) async {
    return pushGistEntry(
      baseUrl: baseUrl,
      token: token,
      userId: userId,
      entry: GistProgressEntry(
        mediaId: mediaId,
        malId: malId,
        mediaType: mediaType,
        episodeNumber: episodeNumber,
        timestampMs: timestampMs,
        durationMs: durationMs,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      isCompleted: isCompleted,
    );
  }

  Future<List<Map<String, dynamic>>> fetchAllProgress({
    required String baseUrl,
    required String token,
    required String userId,
  }) async {
    try {
      final url = _cleanUrl(baseUrl);
      final filter = 'user_id="$userId"';
      final endpoint = Uri.parse(
          '$url/api/collections/anymex_progress/records?filter=(${Uri.encodeComponent(filter)})&perPage=500');

      final resp = await http.get(endpoint, headers: _headers(token)).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        return items.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      Logger.e('PocketBase fetchAllProgress failed: $e');
      return [];
    }
  }

  Future<bool> pushLocalHistory({
    required String baseUrl,
    required String token,
    required String userId,
    required Map<String, dynamic> historyData,
  }) async {
    try {
      final url = _cleanUrl(baseUrl);
      final mediaId = historyData['media_id']?.toString() ?? '';
      if (mediaId.isEmpty) return false;

      final filter = 'media_id="$mediaId" && user_id="$userId"';
      final searchEndpoint =
          Uri.parse('$url/api/collections/anymex_history/records?filter=(${Uri.encodeComponent(filter)})');

      final searchResp = await http
          .get(searchEndpoint, headers: _headers(token))
          .timeout(const Duration(seconds: 5));

      final payload = {
        'user_id': userId,
        'media_id': mediaId,
        'title': historyData['title'] ?? '',
        'cover': historyData['cover'] ?? '',
        'poster': historyData['poster'] ?? '',
        'episode_number': historyData['episode_number'] ?? '1',
        'episode_title': historyData['episode_title'] ?? '',
        'timestamp_ms': historyData['timestamp_ms'] ?? 0,
        'duration_ms': historyData['duration_ms'] ?? 0,
        'last_watched_time': historyData['last_watched_time'] ?? DateTime.now().millisecondsSinceEpoch,
        'source': historyData['source'] ?? '',
        'media_type': historyData['media_type'] ?? 'anime',
        'thumbnail': historyData['thumbnail'] ?? '',
        'episode_link': historyData['episode_link'] ?? '',
        'server': historyData['server'] ?? '',
        'sub_language': historyData['sub_language'] ?? '',
      };

      if (searchResp.statusCode == 200) {
        final data = jsonDecode(searchResp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        if (items.isNotEmpty) {
          final recordId = (items.first as Map<String, dynamic>)['id'] as String;
          final updateEndpoint = Uri.parse('$url/api/collections/anymex_history/records/$recordId');
          final patchResp = await http.patch(updateEndpoint, headers: _headers(token), body: jsonEncode(payload));
          return patchResp.statusCode == 200;
        }
      }

      final createEndpoint = Uri.parse('$url/api/collections/anymex_history/records');
      final createResp = await http.post(createEndpoint, headers: _headers(token), body: jsonEncode(payload));
      return createResp.statusCode == 200 || createResp.statusCode == 201;
    } catch (e) {
      Logger.e('PocketBase pushLocalHistory failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> fetchLocalHistory({
    required String baseUrl,
    required String token,
    required String userId,
  }) async {
    try {
      final url = _cleanUrl(baseUrl);
      final filter = 'user_id="$userId"';
      final endpoint = Uri.parse(
          '$url/api/collections/anymex_history/records?filter=(${Uri.encodeComponent(filter)})&sort=-last_watched_time&perPage=100');

      final resp = await http.get(endpoint, headers: _headers(token)).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        return items.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      Logger.e('PocketBase fetchLocalHistory failed: $e');
      return null;
    }
  }

  Future<bool> clearRemoteData({
    required String baseUrl,
    required String token,
    required String userId,
  }) async {
    try {
      final url = _cleanUrl(baseUrl);
      final progressItems = await fetchAllProgress(baseUrl: url, token: token, userId: userId);
      final historyItems = (await fetchLocalHistory(baseUrl: url, token: token, userId: userId)) ?? [];

      for (final item in progressItems) {
        final id = item['id'] as String?;
        if (id != null) {
          final ep = Uri.parse('$url/api/collections/anymex_progress/records/$id');
          await http.delete(ep, headers: _headers(token));
        }
      }

      for (final item in historyItems) {
        final id = item['id'] as String?;
        if (id != null) {
          final ep = Uri.parse('$url/api/collections/anymex_history/records/$id');
          await http.delete(ep, headers: _headers(token));
        }
      }
      return true;
    } catch (e) {
      Logger.e('PocketBase clearRemoteData failed: $e');
      return false;
    }
  }

  Future<bool> deleteHistoryItem({
    required String baseUrl,
    required String token,
    required String userId,
    required String mediaId,
  }) async {
    try {
      final url = _cleanUrl(baseUrl);
      final filter = 'media_id="$mediaId" && user_id="$userId"';

      // 1. Delete matching records from anymex_history
      final histEndpoint = Uri.parse(
          '$url/api/collections/anymex_history/records?filter=(${Uri.encodeComponent(filter)})');
      final histResp = await http
          .get(histEndpoint, headers: _headers(token))
          .timeout(const Duration(seconds: 5));

      if (histResp.statusCode == 200) {
        final data = jsonDecode(histResp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        for (final item in items) {
          final id = (item as Map<String, dynamic>)['id'] as String?;
          if (id != null) {
            final delEp =
                Uri.parse('$url/api/collections/anymex_history/records/$id');
            await http.delete(delEp, headers: _headers(token));
          }
        }
      }

      // 2. Delete matching records from anymex_progress
      final progEndpoint = Uri.parse(
          '$url/api/collections/anymex_progress/records?filter=(${Uri.encodeComponent(filter)})');
      final progResp = await http
          .get(progEndpoint, headers: _headers(token))
          .timeout(const Duration(seconds: 5));

      if (progResp.statusCode == 200) {
        final data = jsonDecode(progResp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        for (final item in items) {
          final id = (item as Map<String, dynamic>)['id'] as String?;
          if (id != null) {
            final delEp =
                Uri.parse('$url/api/collections/anymex_progress/records/$id');
            await http.delete(delEp, headers: _headers(token));
          }
        }
      }

      return true;
    } catch (e) {
      Logger.e('PocketBase deleteHistoryItem failed: $e');
      return false;
    }
  }
}
