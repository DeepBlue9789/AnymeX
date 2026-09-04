import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:anymex/controllers/service_handler/service_handler.dart';
import 'package:anymex/controllers/source/source_controller.dart';
import 'package:anymex/controllers/sync/gist_sync_controller.dart';
import 'package:anymex/database/data_keys/keys.dart';
import 'package:anymex/database/database.dart';
import 'package:anymex/database/isar_models/chapter.dart';
import 'package:anymex/database/isar_models/custom_list.dart';
import 'package:anymex/database/isar_models/episode.dart';
import 'package:anymex/database/isar_models/offline_media.dart';
import 'package:anymex/main.dart';
import 'package:anymex/models/Media/media.dart';
import 'package:anymex/utils/logger.dart';
import 'package:anymex/controllers/services/anilist/kitsu.dart';
import 'package:anymex/widgets/custom_widgets/anymex_image.dart';
import 'package:anymex_extension_runtime_bridge/anymex_extension_runtime_bridge.dart'
    hide isar;
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';

enum MediaLibraryType {
  anime,
  manga,
  novel,
}

class OfflineStorageController extends GetxController {
  GistSyncController? get _syncCtrl => Get.isRegistered<GistSyncController>()
      ? Get.find<GistSyncController>()
      : null;

  final Map<String, Future<void>> _activeWrites = {};
  bool _isRefreshingHistory = false;

  final RxList<OfflineMedia> rxAnimeLibrary = <OfflineMedia>[].obs;
  final RxBool isAnimeLibraryLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _cleanupDuplicateOfflineMedias();
    unawaited(clearThumbnails());
    watchAnimeLibrary().listen((data) {
      rxAnimeLibrary.assignAll(data);
      isAnimeLibraryLoading.value = false;
    });
    unawaited(refreshHistoryEpisodes());
  }

  Future<void> _cleanupDuplicateOfflineMedias() async {
    try {
      final allMedias = await isar.offlineMedias.where().findAll();
      final seenMediaIds = <String>{};
      final idsToDelete = <int>[];

      for (final media in allMedias) {
        final mId = media.mediaId;
        if (mId == null || mId.isEmpty) continue;
        if (seenMediaIds.contains(mId)) {
          idsToDelete.add(media.id);
        } else {
          seenMediaIds.add(mId);
        }
      }

      if (idsToDelete.isNotEmpty) {
        await isar.safeWriteTxn(() async {
          await isar.offlineMedias.deleteAll(idsToDelete);
        });
        Logger.i('Cleaned up ${idsToDelete.length} duplicate offline media records.');
      }
    } catch (e) {
      Logger.e('Error cleaning up duplicate offline media: $e');
    }
  }

  Future<T> _synchronizedWrite<T>(String mediaId, Future<T> Function() action) async {
    if (mediaId.isEmpty) return action();
    
    while (_activeWrites.containsKey(mediaId)) {
      await _activeWrites[mediaId];
    }
    
    final completer = Completer<void>();
    _activeWrites[mediaId] = completer.future;
    
    try {
      return await action();
    } finally {
      _activeWrites.remove(mediaId);
      completer.complete();
    }
  }

  Stream<List<OfflineMedia>> watchAnimeLibrary() {
    return isar.offlineMedias
        .filter()
        .mediaTypeIndexEqualTo(1)
        .watch(fireImmediately: true);
  }

  Stream<List<OfflineMedia>> watchMangaLibrary() {
    return isar.offlineMedias
        .filter()
        .mediaTypeIndexEqualTo(0)
        .watch(fireImmediately: true);
  }

  Stream<List<OfflineMedia>> watchNovelLibrary() {
    return isar.offlineMedias
        .filter()
        .mediaTypeIndexEqualTo(2)
        .watch(fireImmediately: true);
  }

  Stream<OfflineMedia?> watchMediaById(String mediaId) {
    return isar.offlineMedias
        .filter()
        .mediaIdEqualTo(mediaId)
        .watch(fireImmediately: true)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  Stream<List<CustomList>> watchCustomLists(ItemType mediaType) {
    return isar.customLists.where().watch(fireImmediately: true);
  }

  Stream<CustomListData> watchCustomListData(
      String listName, ItemType mediaType) async* {
    await for (final customList in isar.customLists
        .filter()
        .listNameEqualTo(listName)
        .and()
        .mediaTypeIndexEqualTo(mediaType.index)
        .watch(fireImmediately: true)) {
      if (customList.isEmpty) {
        yield CustomListData(listName: listName, listData: []);
        continue;
      }

      final list = customList.first;
      final mediaIds = list.mediaIds ?? [];

      if (mediaIds.isEmpty) {
        yield CustomListData(listName: listName, listData: []);
        continue;
      }

      final mediaItems = await isar.offlineMedias
          .filter()
          .anyOf(
              mediaIds,
              (q, String id) => q
                  .mediaIdEqualTo(id)
                  .and()
                  .mediaTypeIndexEqualTo(mediaType.index))
          .findAll();

      yield CustomListData(
        listName: listName,
        listData: mediaItems,
      );
    }
  }

  Future<List<OfflineMedia>> getAnimeLibrary(
      {int offset = 0, int limit = 50}) async {
    return await isar.offlineMedias
        .filter()
        .mediaTypeIndexEqualTo(1)
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<List<OfflineMedia>> getMangaLibrary(
      {int offset = 0, int limit = 50}) async {
    return await isar.offlineMedias
        .filter()
        .mediaTypeIndexEqualTo(0)
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<List<OfflineMedia>> getNovelLibrary(
      {int offset = 0, int limit = 50}) async {
    return await isar.offlineMedias
        .filter()
        .mediaTypeIndexEqualTo(2)
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<List<OfflineMedia>> getLibraryFromType(
    ItemType mediaType, {
    int offset = 0,
    int limit = 50,
  }) async {
    return await isar.offlineMedias
        .filter()
        .mediaTypeIndexEqualTo(mediaType.index)
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<List<CustomList>> getCustomListsFromType(ItemType type) async {
    return await isar.customLists
        .filter()
        .mediaTypeIndexEqualTo(type.index)
        .findAll();
  }

  Future<List<OfflineMedia>> searchMedia(
    String query,
    ItemType mediaType,
  ) async {
    return await isar.offlineMedias
        .filter()
        .mediaTypeIndexEqualTo(mediaType.index)
        .group((q) => q
            .nameContains(query, caseSensitive: false)
            .or()
            .jnameContains(query, caseSensitive: false)
            .or()
            .englishContains(query, caseSensitive: false))
        .findAll();
  }

  OfflineMedia? getMediaById(String mediaId) {
    return isar.offlineMedias.filter().mediaIdEqualTo(mediaId).findFirstSync();
  }

  OfflineMedia? getAnimeById(String id) => getMediaById(id);
  OfflineMedia? getMangaById(String id) => getMediaById(id);
  OfflineMedia? getNovelById(String id) => getMediaById(id);

  Future<bool> clearMediaHistory(
    String mediaId, {
    required ItemType mediaType,
    bool syncToCloud = true,
  }) async {
    if (mediaId.isEmpty) return false;

    final media = getMediaById(mediaId);
    if (media == null || media.mediaTypeIndex != mediaType.index) {
      return false;
    }

    final hadHistory = mediaType == ItemType.anime
        ? media.currentEpisode != null
        : media.currentChapter != null;
    if (!hadHistory) return false;

    await isar.safeWriteTxn(() async {
      if (mediaType == ItemType.anime) {
        media.currentEpisode = null;
      } else {
        media.currentChapter = null;
      }
      await isar.offlineMedias.put(media);
    });

    if (syncToCloud) {
      final targetId = media.mediaId ?? media.id.toString();
      _syncCtrl?.removeHistoryItem(targetId);
    }

    return true;
  }

  Future<int> clearMediaHistoryBulk(
    Iterable<String> mediaIds, {
    required ItemType mediaType,
    bool syncToCloud = true,
  }) async {
    final ids = mediaIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return 0;

    final mediaItems = ids
        .map(getMediaById)
        .whereType<OfflineMedia>()
        .where((media) => media.mediaTypeIndex == mediaType.index)
        .toList();
    if (mediaItems.isEmpty) return 0;

    var clearedCount = 0;
    await isar.safeWriteTxn(() async {
      for (final media in mediaItems) {
        final hasHistory = mediaType == ItemType.anime
            ? media.currentEpisode != null
            : media.currentChapter != null;
        if (!hasHistory) continue;

        if (mediaType == ItemType.anime) {
          media.currentEpisode = null;
        } else {
          media.currentChapter = null;
        }

        await isar.offlineMedias.put(media);
        clearedCount++;
      }
    });

    if (syncToCloud) {
      for (final media in mediaItems) {
        final targetId = media.mediaId ?? media.id.toString();
        _syncCtrl?.removeHistoryItem(targetId);
      }
    }

    return clearedCount;
  }

  Future<List<CustomList>> getCustomListsByType(ItemType type) async {
    return await isar.customLists
        .filter()
        .mediaTypeIndexEqualTo(type.index)
        .findAll();
  }

  Future<CustomList?> getCustomListByName(String listName,
      {ItemType? mediaType}) async {
    var query = isar.customLists.filter().listNameEqualTo(listName);
    if (mediaType != null) {
      return await query.mediaTypeIndexEqualTo(mediaType.index).findFirst();
    }
    return await query.findFirst();
  }

  Future<void> syncHistoryFromRemote(List<Map<String, dynamic>> remoteItems) async {
    final remoteMediaIds = remoteItems
        .map((e) => e['media_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    // 1. Upsert remote items (additions & updates)
    for (final item in remoteItems) {
      await upsertSyncedHistory(item);
    }

    // 2. Clear local history entries that were removed on remote
    final localAnime = await getAnimeLibrary();
    for (final anime in localAnime) {
      if (anime.currentEpisode != null) {
        final mId = anime.mediaId ?? anime.id.toString();
        if (!remoteMediaIds.contains(mId)) {
          await clearMediaHistory(mId, mediaType: ItemType.anime, syncToCloud: false);
        }
      }
    }
  }

  Future<void> addCustomList(String listName,
      {ItemType mediaType = ItemType.anime}) async {
    if (listName.isEmpty) return;

    final existing = await getCustomListByName(listName, mediaType: mediaType);
    if (existing != null) {
      Logger.i('List with name "$listName" already exists');
      return;
    }

    await isar.safeWriteTxn(() async {
      await isar.customLists.put(CustomList(
        listName: listName,
        mediaIds: [],
        mediaTypeIndex: mediaType.index,
      ));
    });

    Logger.i('Created custom list: $listName');
  }

  Future<void> removeCustomList(String listName,
      {required ItemType mediaType}) async {
    if (listName.isEmpty) return;

    final list = await getCustomListByName(listName, mediaType: mediaType);
    if (list == null) return;

    await isar.safeWriteTxn(() async {
      await isar.customLists.delete(list.id);
    });

    Logger.i('Removed custom list: $listName');
  }

  Future<void> renameCustomList(String oldName, String newName,
      {required ItemType mediaType}) async {
    if (oldName.isEmpty || newName.isEmpty || oldName == newName) return;

    final existing = await getCustomListByName(newName, mediaType: mediaType);
    if (existing != null) {
      Logger.i('List with name "$newName" already exists');
      return;
    }

    final list = await getCustomListByName(oldName, mediaType: mediaType);
    if (list == null) return;

    await isar.safeWriteTxn(() async {
      list.listName = newName;
      await isar.customLists.put(list);
    });

    Logger.i('Renamed list: $oldName -> $newName');
  }

  Future<void> addMediaToList(String listName, String mediaId,
      {ItemType? mediaType}) async {
    if (listName.isEmpty || mediaId.isEmpty) return;

    final list = await getCustomListByName(listName, mediaType: mediaType);
    if (list == null) {
      Logger.i('List not found: $listName');
      return;
    }

    await isar.safeWriteTxn(() async {
      list.mediaIds = List<String>.from(list.mediaIds ?? []);
      if (!list.mediaIds!.contains(mediaId)) {
        list.mediaIds!.add(mediaId);
        await isar.customLists.put(list);
        Logger.i('Added media $mediaId to list $listName');
      }
    });
  }

  Future<void> removeMediaFromList(
    String listName,
    String mediaId, {
    ItemType? mediaType,
  }) async {
    if (listName.isEmpty || mediaId.isEmpty) return;

    final list = await getCustomListByName(listName, mediaType: mediaType);
    if (list == null) return;

    await isar.safeWriteTxn(() async {
      list.mediaIds = List<String>.from(list.mediaIds ?? []);
      list.mediaIds!.remove(mediaId);
      await isar.customLists.put(list);
      Logger.i('Removed media $mediaId from list $listName');
    });
  }

  Future<List<OfflineMedia>> getMediaFromCustomList(String listName,
      {ItemType? mediaType}) async {
    final list = await getCustomListByName(listName, mediaType: mediaType);
    if (list == null || list.mediaIds == null) return [];

    return await isar.offlineMedias
        .filter()
        .anyOf(list.mediaIds!, (q, String id) => q.mediaIdEqualTo(id))
        .findAll();
  }

  Future<void> addMediaToLibrary(OfflineMedia original) async {
    final existing = getMediaById(original.mediaId ?? "");

    if (existing != null) return;

    await isar.safeWriteTxn(() async {
      await isar.offlineMedias.put(original);
    });
  }

  Future<void> addMedia(String listName, Media original) async {
    await _synchronizedWrite(original.id, () async {
      final type = original.mediaType;
      final existing = getMediaById(original.id);

      if (existing == null) {
        await isar.safeWriteTxn(() async {
          if (type == ItemType.manga || type == ItemType.novel) {
            final chapter = Chapter(number: 1);
            await isar.offlineMedias.put(
              _createOfflineMedia(original, null, null, chapter, null),
            );
          } else {
            final episode = Episode(number: '1');
            await isar.offlineMedias.put(
              _createOfflineMedia(original, null, null, null, episode),
            );
          }
        });
      }

      await addMediaToList(listName, original.id, mediaType: type);
    });
  }

  Future<void> removeMedia(String listName, Media original) async {
    await removeMediaFromList(listName, original.id,
        mediaType: original.mediaType);
  }

  Future<void> addOrUpdateAnime(
    Media original,
    List<Episode>? episodes,
    Episode? currentEpisode,
  ) async {
    await _synchronizedWrite(original.id, () async {
      final existingAnime = getAnimeById(original.id);

      await isar.safeWriteTxn(() async {
        if (existingAnime != null) {
          existingAnime.episodes = episodes;
          if (currentEpisode != null) {
            currentEpisode.source = sourceController.activeSource.value?.name;
          }
          existingAnime.currentEpisode = currentEpisode;
          if (existingAnime.idMal == null && original.idMal != '0') {
            existingAnime.idMal = original.idMal;
          }
          await isar.offlineMedias.put(existingAnime);
          Logger.i('Updated anime: ${existingAnime.name}');
        } else {
          await isar.offlineMedias.put(
            _createOfflineMedia(original, null, episodes, null, currentEpisode),
          );
          Logger.i('Added new anime: ${original.title}');
        }
      });
      rxAnimeLibrary.refresh();
    });
  }

  Future<void> updateAnimeEpisodesOnly(
    String animeId,
    List<Episode> episodes,
  ) async {
    if (episodes.isEmpty) return;
    await _synchronizedWrite(animeId, () async {
      final existingAnime = getAnimeById(animeId);
      if (existingAnime == null) return;

      await isar.safeWriteTxn(() async {
        existingAnime.episodes = episodes;
        if (existingAnime.currentEpisode != null) {
          final curEpNum = existingAnime.currentEpisode!.number;
          final matchingEp = episodes.firstWhereOrNull((e) =>
              e.number == curEpNum ||
              (double.tryParse(e.number) != null &&
                  double.tryParse(e.number) == double.tryParse(curEpNum)));
          if (matchingEp != null &&
              matchingEp.thumbnail != null &&
              matchingEp.thumbnail!.isNotEmpty &&
              !isLocalFile(matchingEp.thumbnail!)) {
            existingAnime.currentEpisode!.thumbnail = matchingEp.thumbnail;
          }
        }
        await isar.offlineMedias.put(existingAnime);
      });
      rxAnimeLibrary.refresh();
    });
  }

  Future<void> addOrUpdateManga(
    Media original,
    List<Chapter>? chapters,
    Chapter? currentChapter,
  ) async {
    await _synchronizedWrite(original.id, () async {
      final existingManga = getMangaById(original.id);

      await isar.safeWriteTxn(() async {
        if (existingManga != null) {
          existingManga.chapters = chapters;
          if (currentChapter != null) {
            currentChapter.sourceName =
                sourceController.activeMangaSource.value?.name;
          }
          existingManga.currentChapter = currentChapter;
          await isar.offlineMedias.put(existingManga);
          Logger.i('Updated manga: ${existingManga.name}');
        } else {
          await isar.offlineMedias.put(
            _createOfflineMedia(original, chapters, null, currentChapter, null),
          );
          Logger.i('Added new manga: ${original.title}');
        }
      });
    });
  }

  Future<void> addOrUpdateNovel(
    Media original,
    List<Chapter>? chapters,
    Chapter? currentChapter,
    Source source,
  ) async {
    await _synchronizedWrite(original.id, () async {
      final existingNovel = getNovelById(original.id);

      await isar.safeWriteTxn(() async {
        if (existingNovel != null) {
          existingNovel.chapters = chapters;
          if (currentChapter != null) {
            currentChapter.sourceName = source.name;
          }
          existingNovel.currentChapter = currentChapter;
          await isar.offlineMedias.put(existingNovel);
          Logger.i('Updated novel: ${existingNovel.name}');
        } else {
          await isar.offlineMedias.put(
            _createOfflineMedia(original, chapters, null, currentChapter, null),
          );
          Logger.i('Added new novel: ${original.title}');
        }
      });
    });
  }

  Future<void> addOrUpdateWatchedEpisode(
    String animeId,
    Episode episode, {
    bool syncToCloud = true,
  }) async {
    await _synchronizedWrite(animeId, () async {
      final existingAnime = getAnimeById(animeId);
      if (existingAnime == null) {
        Logger.i(
            'Anime with ID: $animeId not found. Unable to add/update episode.');
        return;
      }

      await isar.safeWriteTxn(() async {
        existingAnime.watchedEpisodes ??= [];
        episode.source = sourceController.activeSource.value?.name;
        episode.lastWatchedTime = DateTime.now().millisecondsSinceEpoch;

        final index = existingAnime.watchedEpisodes!
            .indexWhere((e) => e.number == episode.number);
        existingAnime.watchedEpisodes =
            List<Episode>.from(existingAnime.watchedEpisodes!);

        final existingEpThumb = index != -1
            ? existingAnime.watchedEpisodes![index].thumbnail
            : (existingAnime.currentEpisode?.number == episode.number
                ? existingAnime.currentEpisode?.thumbnail
                : null);

        if ((episode.thumbnail == null || episode.thumbnail!.isEmpty || isLocalFile(episode.thumbnail!)) &&
            existingEpThumb != null &&
            existingEpThumb.isNotEmpty &&
            !isLocalFile(existingEpThumb)) {
          episode.thumbnail = existingEpThumb;
        }

        if (index != -1) {
          existingAnime.watchedEpisodes![index] = episode;
          Logger.i(
              'Overwritten episode: ${episode.number} for anime ID: $animeId with source => ${episode.source}');
        } else {
          existingAnime.watchedEpisodes!.add(episode);
          Logger.i('Added new episode: ${episode.title} for anime ID: $animeId');
        }

        existingAnime.currentEpisode = episode;

        await isar.offlineMedias.put(existingAnime);
      });

      if (syncToCloud) {
        // For PocketBase: only push episode progress on player exit (syncEpisodeProgressOnExit).
        // Here we only sync history for the continue-watching card.
        final isSyncingProgress = _syncCtrl?.syncProvider.value != 'pocketbase';
        if (isSyncingProgress) {
          _syncCtrl?.pushEpisodeProgress(
            mediaId: animeId,
            episode: episode,
          );
        }
        _syncCtrl?.pushLocalHistoryItem(existingAnime, episode);
      }
      rxAnimeLibrary.refresh();
    });
  }

  Future<void> refreshHistoryEpisodes() async {
    if (_isRefreshingHistory) return;
    _isRefreshingHistory = true;
    try {
      final candidateMediaIds = <String>{};

      for (final media in rxAnimeLibrary) {
        if (media.mediaTypeIndex == 1 &&
            media.mediaId != null &&
            media.mediaId!.isNotEmpty &&
            (media.currentEpisode != null ||
                (media.watchedEpisodes != null &&
                    media.watchedEpisodes!.isNotEmpty))) {
          candidateMediaIds.add(media.mediaId!);
        }
      }

      if (Get.isRegistered<ServiceHandler>()) {
        final handler = Get.find<ServiceHandler>();
        if (handler.isLoggedIn.value && handler.animeList.isNotEmpty) {
          for (final anime in handler.animeList) {
            if (anime.watchingStatus == 'CURRENT' &&
                anime.id != null &&
                anime.id!.isNotEmpty) {
              candidateMediaIds.add(anime.id!);
            }
          }
        }
      }

      if (candidateMediaIds.isEmpty) return;

      bool anyUpdated = false;

      for (final mediaId in candidateMediaIds) {
        var media = getAnimeById(mediaId);
        final existingEpisodes = List<Episode>.from(media?.episodes ?? []);

        final anilistOrMalId = (int.tryParse(mediaId) != null)
            ? mediaId
            : (media?.idMal != null &&
                    media!.idMal != '0' &&
                    int.tryParse(media.idMal!) != null
                ? media.idMal
                : null);

        List<Episode>? updatedEpisodes;

        if (anilistOrMalId != null) {
          try {
            final isMal = Get.isRegistered<ServiceHandler>() &&
                Get.find<ServiceHandler>().serviceType.value == ServicesType.mal;
            final param = isMal ? 'mal_id' : 'anilist_id';
            final url =
                Uri.parse('https://api.ani.zip/mappings?$param=$anilistOrMalId');
            final resp =
                await http.get(url).timeout(const Duration(seconds: 5));
            if (resp.statusCode == 200 && resp.body.isNotEmpty) {
              final Map<String, dynamic> data = jsonDecode(resp.body);
              final episodesData = data['episodes'] as Map<String, dynamic>?;
              if (episodesData != null && episodesData.isNotEmpty) {
                final episodeMap = <String, Episode>{};
                for (final ep in existingEpisodes) {
                  episodeMap[ep.number] = ep;
                }

                episodesData.forEach((key, epVal) {
                  if (epVal is Map<String, dynamic>) {
                    final epNum = epVal['episodeNumber']?.toString() ?? key;
                    final epTitle = epVal['title']?['en']?.toString() ??
                        epVal['title']?['ja']?.toString() ??
                        'Episode $epNum';
                    final epThumb = epVal['image']?.toString();
                    final epDesc = epVal['overview']?.toString();

                    Episode? existing = episodeMap[epNum];
                    if (existing == null) {
                      final matchKey = episodeMap.keys.firstWhereOrNull((k) =>
                          double.tryParse(k) != null &&
                          double.tryParse(k) == double.tryParse(epNum));
                      if (matchKey != null) {
                        existing = episodeMap[matchKey];
                      }
                    }

                    if (existing != null) {
                      if (epThumb != null && epThumb.trim().isNotEmpty && !isLocalFile(epThumb)) {
                        existing.thumbnail = epThumb;
                      }
                      if ((existing.title == null ||
                              existing.title!.isEmpty ||
                              existing.title == 'Episode $epNum') &&
                          epTitle.isNotEmpty) {
                        existing.title = epTitle;
                      }
                      if ((existing.desc == null || existing.desc!.isEmpty) &&
                          epDesc != null &&
                          epDesc.isNotEmpty) {
                        existing.desc = epDesc;
                      }
                    } else {
                      episodeMap[epNum] = Episode(
                        number: epNum,
                        title: epTitle,
                        thumbnail: epThumb,
                        desc: epDesc,
                        source: media?.currentEpisode?.source,
                      );
                    }
                  }
                });

                final sortedList = episodeMap.values.toList()
                  ..sort((a, b) => (double.tryParse(a.number) ?? 0)
                      .compareTo(double.tryParse(b.number) ?? 0));
                updatedEpisodes = sortedList;
              }
            }
          } catch (e) {
            Logger.i('AniZip history refresh for $mediaId: $e');
          }

          final needsKitsu = updatedEpisodes == null ||
              updatedEpisodes.any((ep) => ep.thumbnail == null || ep.thumbnail!.isEmpty);
          if (needsKitsu) {
            try {
              final baseList = updatedEpisodes ?? (existingEpisodes.isNotEmpty ? existingEpisodes : <Episode>[]);
              if (baseList.isNotEmpty) {
                final kitsuList = await Kitsu.fetchKitsuEpisodes(anilistOrMalId, baseList)
                    .timeout(const Duration(seconds: 5));
                if (kitsuList.isNotEmpty) {
                  final episodeMap = <String, Episode>{};
                  for (final ep in (updatedEpisodes ?? existingEpisodes)) {
                    episodeMap[ep.number] = ep;
                  }
                  for (final kEp in kitsuList) {
                    Episode? existing = episodeMap[kEp.number];
                    if (existing == null) {
                      final matchKey = episodeMap.keys.firstWhereOrNull((k) =>
                          double.tryParse(k) != null &&
                          double.tryParse(k) == double.tryParse(kEp.number));
                      if (matchKey != null) {
                        existing = episodeMap[matchKey];
                      }
                    }

                    if (existing != null) {
                      if ((existing.thumbnail == null || existing.thumbnail!.isEmpty || isLocalFile(existing.thumbnail!)) &&
                          kEp.thumbnail != null &&
                          kEp.thumbnail!.isNotEmpty &&
                          !isLocalFile(kEp.thumbnail!)) {
                        existing.thumbnail = kEp.thumbnail;
                      }
                      if ((existing.title == null || existing.title!.isEmpty || existing.title == 'Episode ${existing.number}') && kEp.title != null && kEp.title!.isNotEmpty) {
                        existing.title = kEp.title;
                      }
                      if ((existing.desc == null || existing.desc!.isEmpty) && kEp.desc != null && kEp.desc!.isNotEmpty) {
                        existing.desc = kEp.desc;
                      }
                    } else {
                      episodeMap[kEp.number] = kEp;
                    }
                  }
                  final sortedList = episodeMap.values.toList()
                    ..sort((a, b) => (double.tryParse(a.number) ?? 0)
                        .compareTo(double.tryParse(b.number) ?? 0));
                  updatedEpisodes = sortedList;
                }
              }
            } catch (e) {
              Logger.i('Kitsu fallback refresh for $mediaId: $e');
            }
          }
        }

        // 2. Also check if source extension can provide episode updates / links
        final sourceName = media?.currentEpisode?.source ??
            DynamicKeys.stickySource.get(mediaId);
        final hasValidSourceUrl =
            mediaId.startsWith('/') || mediaId.startsWith('http');
        if (sourceName != null &&
            sourceName.isNotEmpty &&
            hasValidSourceUrl &&
            Get.isRegistered<SourceController>()) {
          final sourceCtrl = Get.find<SourceController>();
          final source =
              sourceCtrl.getExtensionByValue(sourceName, mediaId: mediaId);
          if (source != null) {
            try {
              final details = await source.methods
                  .getDetail(DMedia.withUrl(mediaId))
                  .timeout(const Duration(seconds: 5));
              if (details.episodes != null && details.episodes!.isNotEmpty) {
                final srcEpisodes = details.episodes!.reversed.toList();
                final currentList = updatedEpisodes ?? existingEpisodes;
                final episodeMap = <String, Episode>{};
                for (final ep in currentList) {
                  episodeMap[ep.number] = ep;
                }

                for (final srcEp in srcEpisodes) {
                  final epNum = srcEp.episodeNumber;
                  final epTitle = srcEp.name ?? 'Episode $epNum';
                  if (episodeMap.containsKey(epNum)) {
                    final existing = episodeMap[epNum]!;
                    if ((existing.link == null || existing.link!.isEmpty) &&
                        srcEp.url != null) {
                      existing.link = srcEp.url;
                    }
                    if ((existing.title == null ||
                            existing.title!.isEmpty ||
                            existing.title == 'Episode $epNum') &&
                        srcEp.name != null &&
                        srcEp.name!.isNotEmpty) {
                      existing.title = srcEp.name;
                    }
                    if ((existing.thumbnail == null || existing.thumbnail!.isEmpty) &&
                        srcEp.thumbnail != null &&
                        srcEp.thumbnail!.isNotEmpty) {
                      existing.thumbnail = srcEp.thumbnail;
                    }
                  } else {
                    episodeMap[epNum] = Episode(
                      number: epNum,
                      title: epTitle,
                      link: srcEp.url,
                      thumbnail: srcEp.thumbnail,
                      desc: srcEp.description,
                      source: sourceName,
                    );
                  }
                }

                final sortedList = episodeMap.values.toList()
                  ..sort((a, b) => (double.tryParse(a.number) ?? 0)
                      .compareTo(double.tryParse(b.number) ?? 0));
                updatedEpisodes = sortedList;
              }
            } catch (e) {
              Logger.i('Source history refresh for $mediaId: $e');
            }
          }
        }

        if (updatedEpisodes != null) {
          final tracked = Get.isRegistered<ServiceHandler>()
              ? Get.find<ServiceHandler>()
                  .animeList
                  .firstWhereOrNull((a) => a.id == mediaId)
              : null;

          if (media == null) {
            final newMedia = OfflineMedia(
              mediaId: mediaId,
              idMal: tracked?.idMal,
              name: tracked?.title,
              poster: tracked?.poster,
              cover: tracked?.poster,
              mediaTypeIndex: 1,
              episodes: updatedEpisodes,
            );
            await isar.safeWriteTxn(() async {
              await isar.offlineMedias.put(newMedia);
            });
            anyUpdated = true;
          } else {
            bool metadataUpdated = false;
            if (tracked != null) {
              if (media.name == null || media.name!.isEmpty) {
                media.name = tracked.title;
                metadataUpdated = true;
              }
              if (media.poster == null || media.poster!.isEmpty) {
                media.poster = tracked.poster;
                metadataUpdated = true;
              }
              if (media.cover == null || media.cover!.isEmpty) {
                media.cover = tracked.poster;
                metadataUpdated = true;
              }
            }

            final episodesChanged =
                updatedEpisodes.length != existingEpisodes.length ||
                    updatedEpisodes.any((ep) {
                      final prev = existingEpisodes.firstWhereOrNull((e) =>
                          e.number == ep.number ||
                          (double.tryParse(e.number) != null &&
                              double.tryParse(e.number) == double.tryParse(ep.number)));
                      return prev == null ||
                          (ep.thumbnail != null &&
                              ep.thumbnail!.isNotEmpty &&
                              prev.thumbnail != ep.thumbnail) ||
                          (ep.title != null &&
                              ep.title!.isNotEmpty &&
                              prev.title != ep.title);
                    });

            if (episodesChanged || metadataUpdated) {
              await isar.safeWriteTxn(() async {
                final latestMedia = getAnimeById(mediaId);
                if (latestMedia != null) {
                  latestMedia.episodes = updatedEpisodes;
                  if (metadataUpdated && tracked != null) {
                    if (latestMedia.name == null || latestMedia.name!.isEmpty) {
                      latestMedia.name = tracked.title;
                    }
                    if (latestMedia.poster == null || latestMedia.poster!.isEmpty) {
                      latestMedia.poster = tracked.poster;
                    }
                    if (latestMedia.cover == null || latestMedia.cover!.isEmpty) {
                      latestMedia.cover = tracked.poster;
                    }
                  }

                  if (latestMedia.currentEpisode != null) {
                    final currentEpNum = latestMedia.currentEpisode!.number;
                    final matchingEp = updatedEpisodes?.firstWhereOrNull((e) =>
                        e.number == currentEpNum ||
                        (double.tryParse(e.number) != null &&
                            double.tryParse(e.number) == double.tryParse(currentEpNum)));
                    if (matchingEp != null &&
                        matchingEp.thumbnail != null &&
                        matchingEp.thumbnail!.isNotEmpty &&
                        !isLocalFile(matchingEp.thumbnail!)) {
                      latestMedia.currentEpisode!.thumbnail = matchingEp.thumbnail;
                    }
                  }

                  if (latestMedia.watchedEpisodes != null) {
                    final updatedWatched = List<Episode>.from(latestMedia.watchedEpisodes!);
                    bool watchedChanged = false;
                    for (int wIdx = 0; wIdx < updatedWatched.length; wIdx++) {
                      final wEp = updatedWatched[wIdx];
                      final matchingEp = updatedEpisodes?.firstWhereOrNull((e) =>
                          e.number == wEp.number ||
                          (double.tryParse(e.number) != null &&
                              double.tryParse(e.number) == double.tryParse(wEp.number)));
                      if (matchingEp != null &&
                          matchingEp.thumbnail != null &&
                          matchingEp.thumbnail!.isNotEmpty &&
                          !isLocalFile(matchingEp.thumbnail!)) {
                        if (wEp.thumbnail != matchingEp.thumbnail) {
                          wEp.thumbnail = matchingEp.thumbnail;
                          watchedChanged = true;
                        }
                      }
                    }
                    if (watchedChanged) {
                      latestMedia.watchedEpisodes = updatedWatched;
                    }
                  }

                  await isar.offlineMedias.put(latestMedia);
                }
              });
              anyUpdated = true;
            }
          }
        }
      }

      if (anyUpdated) {
        rxAnimeLibrary.refresh();
      }
    } catch (e) {
      Logger.e('Error during refreshHistoryEpisodes: $e');
    } finally {
      _isRefreshingHistory = false;
    }
  }


  Future<void> upsertSyncedHistory(Map<String, dynamic> remoteHistory) async {
    final mediaId = remoteHistory['media_id']?.toString() ?? '';
    if (mediaId.isEmpty) return;

    final epNum = remoteHistory['episode_number']?.toString() ?? '1';
    final epTitle = remoteHistory['episode_title']?.toString() ?? 'Episode $epNum';
    final timestampMs = (remoteHistory['timestamp_ms'] as num?)?.toInt() ?? 0;
    final durationMs = (remoteHistory['duration_ms'] as num?)?.toInt() ?? 0;
    final lastWatched = (remoteHistory['last_watched_time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    final source = remoteHistory['source']?.toString() ?? '';
    final server = remoteHistory['server']?.toString() ?? '';
    final subLang = remoteHistory['sub_language']?.toString() ?? '';
    final thumbnail = remoteHistory['thumbnail']?.toString() ?? '';
    final title = remoteHistory['title']?.toString() ?? 'Synced Media';
    final cover = remoteHistory['cover']?.toString() ?? '';
    final poster = remoteHistory['poster']?.toString() ?? '';

    if (source.isNotEmpty) {
      await DynamicKeys.stickySource.set(mediaId, source);
    }
    if (server.isNotEmpty) {
      await DynamicKeys.preferredServer.set(mediaId, server);
    }
    if (subLang.isNotEmpty) {
      await DynamicKeys.preferredSubtitle.set(mediaId, subLang);
    }

    await isar.safeWriteTxn(() async {
      var existingAnime = getAnimeById(mediaId);

      if (existingAnime == null) {
        final episode = Episode(
          number: epNum,
          title: epTitle,
          timeStampInMilliseconds: timestampMs,
          durationInMilliseconds: durationMs,
          lastWatchedTime: lastWatched,
          source: source,
          thumbnail: thumbnail,
          link: remoteHistory['episode_link']?.toString() ?? '',
        );
        final newAnime = OfflineMedia(
          mediaId: mediaId,
          name: title,
          cover: cover.isNotEmpty ? cover : poster,
          poster: poster.isNotEmpty ? poster : cover,
          mediaTypeIndex: 1,
          currentEpisode: episode,
          watchedEpisodes: [episode],
        );
        await isar.offlineMedias.put(newAnime);
      } else {
        existingAnime.watchedEpisodes ??= [];
        final index = existingAnime.watchedEpisodes!
            .indexWhere((e) => e.number == epNum);
        existingAnime.watchedEpisodes =
            List<Episode>.from(existingAnime.watchedEpisodes!);

        final localEp = index != -1
            ? existingAnime.watchedEpisodes![index]
            : (existingAnime.currentEpisode?.number == epNum
                ? existingAnime.currentEpisode
                : null);

        // Smart merge: don't overwrite valid local data with empty remote data
        final resolvedDuration = (durationMs > 0)
            ? durationMs
            : (localEp?.durationInMilliseconds ?? 0);

        final resolvedTimestamp = (localEp != null &&
                (localEp.lastWatchedTime ?? 0) > lastWatched &&
                (localEp.timeStampInMilliseconds ?? 0) > 0)
            ? localEp.timeStampInMilliseconds!
            : ((timestampMs > 0) ? timestampMs : (localEp?.timeStampInMilliseconds ?? 0));

        final resolvedLastWatched = (localEp != null &&
                (localEp.lastWatchedTime ?? 0) > lastWatched)
            ? localEp.lastWatchedTime!
            : lastWatched;

        var resolvedThumb = thumbnail;
        final localThumb = localEp?.thumbnail;
        if (resolvedThumb.isEmpty && localThumb != null && localThumb.isNotEmpty && !isLocalFile(localThumb)) {
          resolvedThumb = localThumb;
        } else if (isLocalFile(resolvedThumb)) {
          resolvedThumb = (localThumb != null && !isLocalFile(localThumb)) ? localThumb : '';
        }

        final mergedEpisode = Episode(
          number: epNum,
          title: (epTitle.isNotEmpty && epTitle != 'Episode $epNum')
              ? epTitle
              : (localEp?.title ?? epTitle),
          timeStampInMilliseconds: resolvedTimestamp,
          durationInMilliseconds: resolvedDuration,
          lastWatchedTime: resolvedLastWatched,
          source: source.isNotEmpty ? source : (localEp?.source ?? ''),
          thumbnail: resolvedThumb,
          link: remoteHistory['episode_link']?.toString().isNotEmpty == true
              ? remoteHistory['episode_link'].toString()
              : (localEp?.link ?? ''),
        );

        if (index != -1) {
          existingAnime.watchedEpisodes![index] = mergedEpisode;
        } else {
          existingAnime.watchedEpisodes!.add(mergedEpisode);
        }

        final currentLastWatched = existingAnime.currentEpisode?.lastWatchedTime ?? 0;
        if (resolvedLastWatched >= currentLastWatched) {
          existingAnime.currentEpisode = mergedEpisode;
        }

        if ((existingAnime.name == null || existingAnime.name!.isEmpty) && title.isNotEmpty) {
          existingAnime.name = title;
        }
        if ((existingAnime.cover == null || existingAnime.cover!.isEmpty) && cover.isNotEmpty) {
          existingAnime.cover = cover;
        }
        if ((existingAnime.poster == null || existingAnime.poster!.isEmpty) && poster.isNotEmpty) {
          existingAnime.poster = poster;
        }

        await isar.offlineMedias.put(existingAnime);
      }
    });

    rxAnimeLibrary.refresh();
  }

  Future<void> updateOrAddHistory({
    required String animeId,
    required Episode episode,
    String? title,
    String? poster,
    String? cover,
  }) async {
    await _synchronizedWrite(animeId, () async {
      await addOrUpdateWatchedEpisode(animeId, episode);

      if (title != null || poster != null || cover != null) {
        final existingAnime = getAnimeById(animeId);
        if (existingAnime != null) {
          bool needsUpdate = false;
          if (title != null &&
              (existingAnime.name == null || existingAnime.name!.isEmpty)) {
            existingAnime.name = title;
            needsUpdate = true;
          }
          if (poster != null &&
              (existingAnime.poster == null || existingAnime.poster!.isEmpty)) {
            existingAnime.poster = poster;
            needsUpdate = true;
          }
          if (cover != null &&
              (existingAnime.cover == null || existingAnime.cover!.isEmpty)) {
            existingAnime.cover = cover;
            needsUpdate = true;
          }
          if (needsUpdate) {
            await isar.safeWriteTxn(() async {
              await isar.offlineMedias.put(existingAnime);
            });
          }
        }
      }
    });
  }

  Episode? getWatchedEpisode(String anilistId, String episodeNumber) {
    final anime = getAnimeById(anilistId);
    if (anime?.watchedEpisodes == null) return null;

    return anime!.watchedEpisodes!
        .firstWhereOrNull((e) => e.number == episodeNumber);
  }

  Future<void> addOrUpdateReadChapter(
    String mangaId,
    Chapter chapter, {
    Source? source,
    bool syncToCloud = true,
  }) async {
    await _synchronizedWrite(mangaId, () async {
      OfflineMedia? existingManga = getMangaById(mangaId);
      existingManga ??= getNovelById(mangaId);

      if (existingManga == null) {
        Logger.i(
            'Manga with ID: $mangaId not found. Unable to add/update chapter.');
        return;
      }

      await isar.safeWriteTxn(() async {
        existingManga!.readChapters ??= [];
        chapter.sourceName =
            source?.name ?? sourceController.activeMangaSource.value?.name;
        chapter.lastReadTime = DateTime.now().millisecondsSinceEpoch;

        final index = existingManga.readChapters!
            .indexWhere((c) => c.number == chapter.number);
        existingManga.readChapters =
            List<Chapter>.from(existingManga.readChapters!);
        if (index != -1) {
          existingManga.readChapters![index] = chapter;
          Logger.i(
              'Overwritten chapter: ${chapter.title} for manga ID: $mangaId');
        } else {
          existingManga.readChapters!.add(chapter);
          Logger.i('Added new chapter: ${chapter.title} for manga ID: $mangaId');
        }

        existingManga.currentChapter = chapter;

        await isar.offlineMedias.put(existingManga);
      });

      if (syncToCloud) {
        _syncCtrl?.pushChapterProgress(
          mediaId: mangaId,
          mediaType: existingManga.mediaTypeIndex == 2 ? 'novel' : 'manga',
          chapter: chapter,
        );
      }
    });
  }

  Chapter? getReadChapter(String anilistId, double number) {
    final manga = getMangaById(anilistId);
    if (manga?.readChapters == null) return null;

    return manga!.readChapters!.firstWhereOrNull((c) => c.number == number);
  }

  Future<void> addOrUpdateNovelChapter(String novelId, Chapter chapter) async {
    await _synchronizedWrite(novelId, () async {
      final existingNovel = getNovelById(novelId);
      if (existingNovel == null) {
        Logger.i(
            'Novel with ID: $novelId not found. Unable to add/update chapter.');
        return;
      }

      await isar.safeWriteTxn(() async {
        existingNovel.readChapters ??= [];
        chapter.sourceName = sourceController.activeNovelSource.value?.name;
        chapter.lastReadTime = DateTime.now().millisecondsSinceEpoch;

        final index = existingNovel.readChapters!
            .indexWhere((c) => c.number == chapter.number);
        existingNovel.readChapters =
            List<Chapter>.from(existingNovel.readChapters!);
        if (index != -1) {
          existingNovel.readChapters![index] = chapter;
          Logger.i(
              'Overwritten chapter: ${chapter.title} for novel ID: $novelId');
        } else {
          existingNovel.readChapters!.add(chapter);
          Logger.i('Added new chapter: ${chapter.title} for novel ID: $novelId');
        }

        existingNovel.currentChapter = chapter;

        await isar.offlineMedias.put(existingNovel);
      });
    });
  }

  Future<Chapter?> getReadNovelChapter(String novelId, double number) async {
    final novel = getNovelById(novelId);
    if (novel?.readChapters == null) return null;

    return novel!.readChapters!.firstWhereOrNull((c) => c.number == number);
  }

  Future<List<OfflineMedia>> getNovelsFromCustomList(String listName) async {
    return await getMediaFromCustomList(listName);
  }

  Future<double> getNovelReadingProgress(String novelId) async {
    final novel = getNovelById(novelId);
    if (novel?.chapters == null || novel!.chapters!.isEmpty) {
      return 0.0;
    }

    final totalChapters = novel.chapters!.length;
    final readChapters = novel.readChapters?.length ?? 0;

    return readChapters / totalChapters;
  }

  Future<Chapter?> getLatestReadNovelChapter(String novelId) async {
    final novel = getNovelById(novelId);
    if (novel?.readChapters == null || novel!.readChapters!.isEmpty) {
      return null;
    }

    final sorted = List<Chapter>.from(novel.readChapters!);
    sorted.sort((a, b) => (b.lastReadTime ?? 0).compareTo(a.lastReadTime ?? 0));

    return sorted.first;
  }

  Future<void> markNovelChapterAsRead(
      String novelId, double chapterNumber) async {
    final novel = getNovelById(novelId);
    if (novel == null) return;

    await isar.safeWriteTxn(() async {
      novel.readChapters ??= [];

      final existingIndex =
          novel.readChapters!.indexWhere((c) => c.number == chapterNumber);
      novel.readChapters = List<Chapter>.from(novel.readChapters!);

      if (existingIndex != -1) {
        novel.readChapters![existingIndex].lastReadTime =
            DateTime.now().millisecondsSinceEpoch;
      } else {
        final readChapter = Chapter(
          number: chapterNumber,
          lastReadTime: DateTime.now().millisecondsSinceEpoch,
          sourceName: sourceController.activeNovelSource.value?.name,
        );

        novel.readChapters!.add(readChapter);
      }

      await isar.offlineMedias.put(novel);
      Logger.i(
          'Marked chapter $chapterNumber as read for novel: ${novel.name}');
    });
  }

  Future<Chapter?> getNextUnreadNovelChapter(String novelId) async {
    final novel = getNovelById(novelId);
    if (novel?.chapters == null || novel!.chapters!.isEmpty) {
      return null;
    }

    final readChapterNumbers =
        novel.readChapters?.map((c) => c.number).toSet() ?? <double>{};

    for (final chapter in novel.chapters!) {
      if (!readChapterNumbers.contains(chapter.number)) {
        return chapter;
      }
    }

    return null;
  }

  Future<bool> isNovelChapterRead(String novelId, double chapterNumber) async {
    final novel = getNovelById(novelId);
    if (novel?.readChapters == null) return false;

    return novel!.readChapters!
        .any((chapter) => chapter.number == chapterNumber);
  }

  Future<Map<String, dynamic>> getNovelStats() async {
    final allNovels =
        await isar.offlineMedias.filter().mediaTypeIndexEqualTo(2).findAll();

    int completedNovels = 0;
    int readingNovels = 0;

    for (final novel in allNovels) {
      if (novel.chapters == null || novel.chapters!.isEmpty) continue;

      final totalChapters = novel.chapters!.length;
      final readChapters = novel.readChapters?.length ?? 0;

      if (readChapters >= totalChapters) {
        completedNovels++;
      } else if (readChapters > 0) {
        readingNovels++;
      }
    }

    final totalNovels = allNovels.length;

    return {
      'total': totalNovels,
      'completed': completedNovels,
      'reading': readingNovels,
      'planToRead': totalNovels - completedNovels - readingNovels,
    };
  }

  OfflineMedia _createOfflineMedia(
    Media original,
    List<Chapter>? chapters,
    List<Episode>? episodes,
    Chapter? currentChapter,
    Episode? currentEpisode,
  ) {
    final handler = Get.find<ServiceHandler>();
    return OfflineMedia(
      mediaId: original.id,
      idMal: original.idMal,
      jname: original.romajiTitle,
      name: original.title,
      english: original.title,
      japanese: original.romajiTitle,
      description: original.description,
      poster: original.poster,
      cover: original.cover,
      totalEpisodes: original.totalEpisodes,
      type: original.type,
      season: original.season,
      premiered: original.premiered,
      duration: original.duration,
      status: original.status,
      rating: original.rating,
      popularity: original.popularity,
      format: original.format,
      aired: original.aired,
      totalChapters: original.totalChapters,
      genres: original.genres,
      studios: original.studios,
      chapters: chapters,
      episodes: episodes,
      currentEpisode: currentEpisode,
      currentChapter: currentChapter,
      watchedEpisodes: [],
      readChapters: [],
      serviceIndex: handler.serviceType.value.index,
      mediaTypeIndex: original.mediaType.index,
    );
  }

  Future<void> clearThumbnails() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory(p.join(docDir.path, 'anymex_thumbnails'));
      if (await thumbDir.exists()) {
        await thumbDir.delete(recursive: true);
      }
    } catch (e) {
      Logger.e('Failed to clear thumbnails: $e');
    }
  }

  Future<void> clearCache() async {
    await isar.safeWriteTxn(() async {
      await isar.offlineMedias.clear();
      await isar.customLists.clear();
    });

    await clearThumbnails();
    Logger.i('Cache cleared successfully');
  }

  List<CustomListData> getEditableCustomListData(
      {required ItemType mediaType}) {
    final lists = isar.customLists
        .filter()
        .mediaTypeIndexEqualTo(mediaType.index)
        .findAllSync();

    return lists.map((list) {
      final mediaIds = list.mediaIds ?? [];

      if (mediaIds.isEmpty) {
        return CustomListData(listName: list.listName ?? '', listData: []);
      }

      final mediaItems = isar.offlineMedias
          .filter()
          .anyOf(
            mediaIds,
            (q, String id) => q
                .mediaIdEqualTo(id)
                .and()
                .mediaTypeIndexEqualTo(mediaType.index),
          )
          .findAllSync();

      return CustomListData(
        listName: list.listName ?? '',
        listData: mediaItems,
      );
    }).toList();
  }

  Future<void> applyCustomListChanges(
    List<CustomListData> updatedLists, {
    required ItemType mediaType,
  }) async {
    final existingLists = await getCustomListsByType(mediaType);

    await isar.safeWriteTxn(() async {
      for (var existingList in existingLists) {
        await isar.customLists.delete(existingList.id);
      }

      for (var updatedListData in updatedLists) {
        await isar.customLists.put(CustomList(
          listName: updatedListData.listName,
          mediaIds: updatedListData.listData
              .map((media) => media.mediaId ?? '')
              .where((id) => id.isNotEmpty)
              .toList(),
          mediaTypeIndex: mediaType.index,
        ));
      }
    });

    Logger.i('Applied custom list changes for ${mediaType.name}');
  }
}

class CustomListData {
  String listName;
  List<OfflineMedia> listData;

  CustomListData({required this.listData, required this.listName});
}
