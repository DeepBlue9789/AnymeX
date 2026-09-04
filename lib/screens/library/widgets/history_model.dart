import 'package:anymex/controllers/source/source_controller.dart';
import 'package:anymex/controllers/source/source_mapper.dart';
import 'package:anymex/controllers/service_handler/service_handler.dart';
import 'package:anymex/database/data_keys/keys.dart';
import 'package:anymex/database/isar_models/offline_media.dart';
import 'package:anymex/screens/anime/widgets/track_dialog.dart' as anime_track;
import 'package:anymex/screens/manga/widgets/track_dialog.dart' as manga_track;
import 'package:anymex/database/isar_models/video.dart' as local_video;
import 'package:anymex/screens/anime/details_page.dart';
import 'package:anymex/screens/anime/watch/watch_view.dart';
import 'package:anymex/screens/manga/reading_page.dart';
import 'package:anymex/screens/novel/reader/novel_reader.dart';
import 'package:anymex/utils/extension_utils.dart';
import 'package:anymex/utils/function.dart';
import 'package:anymex/utils/logger.dart';
import 'package:anymex/utils/m3u8_parser.dart';
import 'package:anymex/widgets/custom_widgets/anymex_progress.dart';
import 'package:anymex/widgets/non_widgets/snackbar.dart';
import 'package:anymex_extension_runtime_bridge/anymex_extension_runtime_bridge.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:anymex/widgets/custom_widgets/anymex_image.dart';
import 'package:anymex/widgets/media_items/media_peek_popup.dart';

typedef _LogFn = void Function(String message);

class HistoryModel {
  OfflineMedia? media;
  String? title;
  String cover;
  String poster;
  String? sourceName;
  String? formattedEpisodeTitle;
  num? progress;
  num? totalProgress;
  String? progressTitle;
  bool? isManga;
  double? calculatedProgress;
  VoidCallback? onTap;
  VoidCallback? onLongPress;
  String? progressText;
  String? date;

  HistoryModel(
      {this.media,
      this.title,
      required this.cover,
      required this.poster,
      this.formattedEpisodeTitle,
      this.sourceName,
      this.progress,
      this.totalProgress,
      this.progressTitle,
      this.isManga,
      this.calculatedProgress,
      this.onTap,
      this.onLongPress,
      this.progressText,
      this.date});

  factory HistoryModel.fromOfflineMedia(OfflineMedia media, ItemType type) {
    final onTap = _buildHistoryTapHandler(media, type);
    final onLongPress = () {
      final heroTag = '${media.mediaId}-recent-${media.currentEpisode?.timeStampInMilliseconds ?? ''}';
      final mediaModel = convertOfflineToMedia(media);
      MediaPeekPopup.show(Get.context!, mediaModel, type, heroTag);
    };

    final isManga = !type.isAnime;
    final poster = media.poster ?? media.cover ?? '';
    final cover = media.cover ?? media.poster ?? '';

    bool isPosterOrCover(String? url) {
      if (url == null || url.trim().isEmpty) return true;
      final trimmed = url.trim();
      return trimmed == poster || trimmed == cover;
    }

    String resolvedCover = '';

    // 1. Resolve online episode thumbnail
    final rawThumb = media.currentEpisode?.thumbnail;
    final currentEpNum = media.currentEpisode?.number;
    final matchedEp = media.episodes?.firstWhereOrNull((e) =>
            e.number == currentEpNum ||
            (double.tryParse(e.number) != null &&
                double.tryParse(e.number) ==
                    double.tryParse(currentEpNum ?? ''))) ??
        media.watchedEpisodes?.firstWhereOrNull((e) =>
            e.number == currentEpNum ||
            (double.tryParse(e.number) != null &&
                double.tryParse(e.number) ==
                    double.tryParse(currentEpNum ?? '')));
    final defaultEpThumb = matchedEp?.thumbnail;

    if (defaultEpThumb != null &&
        defaultEpThumb.trim().isNotEmpty &&
        !isLocalFile(defaultEpThumb) &&
        !isPosterOrCover(defaultEpThumb)) {
      resolvedCover = defaultEpThumb;
    } else if (rawThumb != null &&
        rawThumb.trim().isNotEmpty &&
        !isLocalFile(rawThumb) &&
        !isPosterOrCover(rawThumb)) {
      resolvedCover = rawThumb;
    }

    // 2. Fallback: Use media cover / poster
    if (resolvedCover.isEmpty) {
      resolvedCover = cover.isNotEmpty ? cover : poster;
    }

    final resolvedPoster = (resolvedCover.isNotEmpty && !isPosterOrCover(resolvedCover))
        ? resolvedCover
        : (media.poster ?? media.cover ?? '');

    Logger.i('[HistoryModel] id=${media.mediaId} ep=${media.currentEpisode?.number} | rawThumb=$rawThumb | resolvedCover=$resolvedCover');

    final progressVal = isManga
        ? media.currentChapter?.pageNumber
        : media.currentEpisode?.timeStampInMilliseconds;
    var totalProgressVal = isManga
        ? media.currentChapter?.totalPages
        : media.currentEpisode?.durationInMilliseconds;

    // Fallback: if duration is missing on currentEpisode, check watchedEpisodes
    if (!isManga && (totalProgressVal == null || totalProgressVal <= 0) && media.currentEpisode != null) {
      final matchedWatched = media.watchedEpisodes
          ?.firstWhereOrNull((e) => e.number == media.currentEpisode?.number);
      if (matchedWatched?.durationInMilliseconds != null &&
          matchedWatched!.durationInMilliseconds! > 0) {
        totalProgressVal = matchedWatched.durationInMilliseconds;
      }
    }

    return HistoryModel(
        media: media,
        title: media.name,
        cover: resolvedCover,
        poster: resolvedPoster,
        formattedEpisodeTitle: formatEpChapTitle(
            isManga
                ? media.currentChapter?.number
                : media.currentEpisode?.number,
            isManga),
        sourceName: isManga
            ? media.currentChapter?.sourceName
            : media.currentEpisode?.source,
        progress: progressVal,
        totalProgress: totalProgressVal,
        progressTitle:
            isManga ? media.currentChapter?.title : media.currentEpisode?.title,
        isManga: isManga,
        calculatedProgress: calculateProgress(progressVal, totalProgressVal),
        onTap: onTap,
        onLongPress: onLongPress,
        date: formattedDate(isManga
            ? media.currentChapter?.lastReadTime ?? 0
            : media.currentEpisode?.lastWatchedTime ?? 0),
        progressText: formatProgressText(media, isManga));
  }
  @override
  String toString() {
    return '''
HistoryModel(
  title: $title,
  cover: $cover,
  poster: $poster,
  sourceName: $sourceName,
  formattedEpisodeTitle: $formattedEpisodeTitle,
  progress: $progress,
  totalProgress: $totalProgress,
  progressTitle: $progressTitle,
  isManga: $isManga,
  calculatedProgress: $calculatedProgress,
  progressText: $progressText,
  date: $date
)
  ''';
  }
}

VoidCallback _buildHistoryTapHandler(OfflineMedia media, ItemType type) {
  return () async {
    await _handleHistoryTap(media, type);
  };
}

Future<void> _handleHistoryTap(OfflineMedia media, ItemType type) async {
  switch (type) {
    case ItemType.anime:
      await _handleAnimeTap(media);
      return;
    case ItemType.manga:
      await _handleMangaTap(media);
      return;
    case ItemType.novel:
      await _handleNovelTap(media);
      return;
  }
}

Future<void> _handleMangaTap(OfflineMedia media) async {
  final chapter = media.currentChapter;
  if (chapter == null) {
    snackBar(
      "Error: Missing required media. It seems you closed the app directly after reading the chapter!",
      maxLines: 3,
    );
    return;
  }

  final sourceName = chapter.sourceName;
  if (sourceName == null || sourceName.isEmpty) {
    snackBar("Cant Play since user closed the app abruptly");
    return;
  }

  final source =
      Get.find<SourceController>().getMangaExtensionByName(sourceName);
  if (source == null) {
    snackBar("Install $sourceName First, Then Click");
    return;
  }

  var chapters = media.chapters ?? [];
  if (chapters.length <= 1) {
    Get.dialog(
      const Center(child: AnymexProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      final mediaModel = convertOfflineToMedia(media);
      final details = await source.methods
          .getDetail(DMedia.withUrl(mediaModel.id.toString()));
      if (details.episodes != null && details.episodes!.isNotEmpty) {
        chapters = DEpisodeToChapter(
          details.episodes!.reversed.toList(),
          details.title ?? media.name ?? '',
        );
      }
    } catch (e) {
      Logger.i("Error fetching chapters: $e");
    } finally {
      if (Get.isDialogOpen == true) {
        Get.back();
      }
    }
  }

  final mediaModel = convertOfflineToMedia(media);
  final dbId = '${mediaModel.id}_${mediaModel.serviceType.name}_${mediaModel.type}';
  final savedTracking = DynamicKeys.trackingPermission.get<bool?>(dbId);

  bool? shouldTrack;
  if (savedTracking != null) {
    shouldTrack = savedTracking;
  } else if (General.shouldAskForTrack.get(true) == false) {
    shouldTrack = true;
  } else if (Get.context != null) {
    shouldTrack = mediaModel.serviceType == ServicesType.extensions
        ? false
        : await manga_track.showTrackingDialog(Get.context!, dbId: dbId);
  } else {
    shouldTrack = mediaModel.serviceType != ServicesType.extensions;
  }

  if (shouldTrack == null) return;

  navigateWithSlide(() => ReadingPage(
        anilistData: mediaModel,
        chapterList: chapters,
        currentChapter: chapter,
        shouldTrack: shouldTrack!,
      ));
}

Future<void> _handleNovelTap(OfflineMedia media) async {
  final chapter = media.currentChapter;
  if (chapter == null || media.chapters == null) {
    snackBar(
      "Error: Missing required media. It seems you closed the app directly after reading the chapter!",
      maxLines: 3,
    );
    return;
  }

  final sourceName = chapter.sourceName;
  if (sourceName == null || sourceName.isEmpty) {
    snackBar("Cant Read since user closed the app abruptly");
    return;
  }

  final source =
      Get.find<SourceController>().getNovelExtensionByName(sourceName);
  if (source == null) {
    snackBar("Install $sourceName First, Then Click");
    return;
  }

  navigateWithSlide(() => NovelReader(
        chapter: chapter,
        chapters: media.chapters ?? [],
        media: convertOfflineToMedia(media),
        source: source,
      ));
}

Future<void> _handleAnimeTap(OfflineMedia media) async {
  final currentEpisode = media.currentEpisode;
  if (currentEpisode == null) {
    snackBar(
      "Error: Missing required media. It seems you closed the app directly after watching the episode!",
      duration: 2000,
      maxLines: 3,
    );
    return;
  }

  final sourceName = currentEpisode.source;
  final mediaIdStr = media.mediaId ?? media.id.toString();
  final sourceController = Get.find<SourceController>();

  // Determine candidate sources according to priority:
  // 1. User's saved/sticky source for this anime
  // 2. Source named on currentEpisode
  // 3. Next default installed anime sources sorted by user priority
  final candidateSources = <Source>[];
  final seenIds = <String>{};

  if (mediaIdStr.isNotEmpty) {
    final saved = sourceController.getSavedSource(mediaIdStr, ItemType.anime);
    if (saved != null && saved.id != null && seenIds.add(saved.id!)) {
      candidateSources.add(saved);
    }
  }
  if (sourceName != null && sourceName.isNotEmpty) {
    final byName = sourceController.getExtensionByValue(sourceName,
        mediaId: mediaIdStr.isNotEmpty ? mediaIdStr : null);
    if (byName != null && byName.id != null && seenIds.add(byName.id!)) {
      candidateSources.add(byName);
    }
  }
  for (final ext in sourceController.getInstalledExtensions(ItemType.anime)) {
    if (ext.id != null && seenIds.add(ext.id!)) {
      candidateSources.add(ext);
    }
  }

  if (candidateSources.isEmpty) {
    final mediaModel = convertOfflineToMedia(media);
    navigate(() => AnimeDetailsPage(
        media: mediaModel,
        tag: 'history-${media.mediaId}',
        initialTabIndex: 1));
    return;
  }

  final episodeList = media.episodes ?? [];

  final logSession = _LoaderLogSession();
  logSession.show();
  logSession.log("Preparing playback...");

  try {
    _AnimePlaybackData? playbackData;
    Source? winningSource;

    for (final candidate in candidateSources) {
      if (logSession.isCancelled) return;
      sourceController.setActiveSource(candidate,
          mediaId: mediaIdStr.isNotEmpty ? mediaIdStr : null);
      logSession.log("Checking source ${candidate.name}...");

      try {
        final result = await _resolveAnimePlaybackData(
          media: media,
          source: candidate,
          log: logSession.log,
          session: logSession,
        );
        if (result != null) {
          playbackData = result;
          winningSource = candidate;
          break;
        }
      } catch (e) {
        Logger.i("Source ${candidate.name} playback resolution failed: $e");
      }
    }

    if (playbackData == null || winningSource == null) {
      if (logSession.isCancelled) return;
      logSession.log("Playback preparation failed.");
      logSession.close();
      final mediaModel = convertOfflineToMedia(media);
      navigate(() => AnimeDetailsPage(
          media: mediaModel,
          tag: 'history-${media.mediaId}',
          initialTabIndex: 1));
      return;
    }

    if (logSession.isCancelled) return;
    logSession.log("Playback is ready.");
    logSession.close();

    final mediaModel = convertOfflineToMedia(media);
    final dbId =
        '${mediaModel.id}_${mediaModel.serviceType.name}_${mediaModel.type}';
    final savedTracking = DynamicKeys.trackingPermission.get<bool?>(dbId);

    bool? shouldTrack;
    if (savedTracking != null) {
      shouldTrack = savedTracking;
    } else if (General.shouldAskForTrack.get(true) == false) {
      shouldTrack = true;
    } else if (Get.context != null) {
      shouldTrack = mediaModel.serviceType == ServicesType.extensions
          ? false
          : await anime_track.showTrackingDialog(Get.context!, dbId: dbId);
    } else {
      shouldTrack = mediaModel.serviceType != ServicesType.extensions;
    }

    if (shouldTrack == null) return;

    navigateWithSlide(() => WatchScreen(
          episodeSrc: playbackData!.currentTrack,
          episodeList: episodeList,
          anilistData: mediaModel,
          currentEpisode: currentEpisode,
          episodeTracks: playbackData.tracks,
          shouldTrack: shouldTrack!,
        ));
  } catch (e) {
    if (logSession.isCancelled) return;
    Logger.i("Error preparing anime playback: $e");
    logSession.log("Failed to prepare playback.");
    snackBar("Unable to prepare playback right now. Please try again.");
  } finally {
    logSession.close();
  }
}

Future<_AnimePlaybackData?> _resolveAnimePlaybackData({
  required OfflineMedia media,
  required Source source,
  required _LogFn log,
  required _LoaderLogSession session,
}) async {
  final currentEpisode = media.currentEpisode!;
  var tracks =
      List<local_video.Video>.from(currentEpisode.videoTracks ?? const []);

  if (session.isCancelled) return null;

  final firstStoredTrack = tracks.isNotEmpty ? tracks.first : null;
  final isStoredLinkValid =
      await _pingVideoUrl(firstStoredTrack, log: log, session: session);

  if (session.isCancelled) return null;

  if (!isStoredLinkValid) {
    log("Fetching fresh stream URLs from ${source.name}...");

    var episodeUrl = currentEpisode.link ?? "";
    final currentEpNum = currentEpisode.number;

    if (episodeUrl.isEmpty) {
      log("Searching episodes on ${source.name}...");
      try {
        final mediaModel = convertOfflineToMedia(media);
        DEpisode? matchedEp;

        // 1. If mediaId is an extension URL/path, query directly
        if (mediaModel.id.isNotEmpty &&
            (mediaModel.id.startsWith('/') ||
                mediaModel.id.startsWith('http'))) {
          final detail = await source.methods
              .getDetail(DMedia.withUrl(mediaModel.id))
              .timeout(const Duration(seconds: 6));
          if (detail.episodes != null && detail.episodes!.isNotEmpty) {
            matchedEp = detail.episodes!.firstWhereOrNull(
              (e) =>
                  (double.tryParse(e.episodeNumber) ?? 0) ==
                      (double.tryParse(currentEpNum) ?? -1) ||
                  e.episodeNumber == currentEpNum,
            );
          }
        }

        // 2. Search and fuzzy map via SourceMapper
        if (matchedEp == null) {
          final key = '${source.id}-${media.mediaId}-0';
          final savedTitle = DynamicKeys.mappedMediaTitle.get<String?>(key);
          final titles = <String>[
            media.name ?? '',
            if (media.english != null && media.english!.isNotEmpty)
              media.english!,
            if (media.jname != null && media.jname!.isNotEmpty) media.jname!,
          ];
          final mapped = await SourceMapper.mapMedia(
            titles,
            RxString(''),
            mediaId: media.mediaId ?? media.id.toString(),
            type: ItemType.anime,
            savedTitle: savedTitle,
          );
          if (mapped != null && mapped.id.isNotEmpty) {
            final detail = await source.methods
                .getDetail(DMedia.withUrl(mapped.id))
                .timeout(const Duration(seconds: 6));
            if (detail.episodes != null && detail.episodes!.isNotEmpty) {
              matchedEp = detail.episodes!.firstWhereOrNull(
                (e) =>
                    (double.tryParse(e.episodeNumber) ?? 0) ==
                        (double.tryParse(currentEpNum) ?? -1) ||
                    e.episodeNumber == currentEpNum,
              );
            }
          }
        }

        if (matchedEp != null) {
          episodeUrl = matchedEp.url ?? '';
          currentEpisode.link = episodeUrl;
        }
      } catch (e) {
        Logger.i("Error matching episode on source ${source.name}: $e");
      }
    }

    if (episodeUrl.isEmpty || session.isCancelled) {
      log("Episode URL not found on ${source.name}.");
      return null;
    }

    final refreshedVideos = await source.methods.getVideoList(
      DEpisode(
        url: episodeUrl,
        episodeNumber: currentEpisode.number,
      ),
    );

    if (session.isCancelled) return null;

    if (refreshedVideos.isEmpty) {
      log("Source ${source.name} returned 0 video streams.");
      return null;
    }

    log("Received ${refreshedVideos.length} stream option(s) from ${source.name}.");
    tracks = refreshedVideos
        .map(local_video.Video.fromVideo)
        .where((video) => (video.url ?? '').isNotEmpty)
        .toList();
    if (tracks.isEmpty || session.isCancelled) {
      return null;
    }
  } else {
    log("Saved stream URL is valid.");
  }

  if (session.isCancelled) return null;

  log("Choosing preferred server...");
  final selectedTrack = _selectTrack(
    tracks: tracks,
    previousTrack: currentEpisode.currentTrack,
    mediaId: media.mediaId ?? media.id.toString(),
  );
  if (selectedTrack == null || session.isCancelled) {
    return null;
  }

  currentEpisode.videoTracks = tracks;
  currentEpisode.currentTrack = selectedTrack;
  log("Selected stream: ${selectedTrack.quality ?? 'Auto'}");

  return _AnimePlaybackData(currentTrack: selectedTrack, tracks: tracks);
}

local_video.Video? _selectTrack({
  required List<local_video.Video> tracks,
  required local_video.Video? previousTrack,
  String? mediaId,
}) {
  if (tracks.isEmpty) return null;

  if (mediaId != null && mediaId.isNotEmpty) {
    final prefServer = DynamicKeys.preferredServer.get<String?>(mediaId);
    if (prefServer != null && prefServer.isNotEmpty) {
      final prefUpper = prefServer.trim().toUpperCase();
      final match = tracks.firstWhereOrNull((t) {
        final q = t.quality?.trim().toUpperCase();
        return q == prefUpper || (q != null && q.contains(prefUpper));
      });
      if (match != null) return match;
    }
  }

  if (previousTrack == null) return tracks.first;

  for (final track in tracks) {
    if (track.url == previousTrack.url && (track.url ?? '').isNotEmpty) {
      return track;
    }
  }
  for (final track in tracks) {
    if (track.quality == previousTrack.quality &&
        (track.url ?? '').isNotEmpty) {
      return track;
    }
  }

  return tracks.first;
}

Future<bool> _pingVideoUrl(
  local_video.Video? video, {
  required _LogFn log,
  required _LoaderLogSession session,
}) async {
  final url = video?.url?.trim();
  if (url == null || url.isEmpty || session.isCancelled) {
    log("Saved URL is empty.");
    return false;
  }
  log("Checking URL availability...");

  final uri = Uri.tryParse(url);
  if (uri == null) {
    log("Saved URL format is invalid.");
    return false;
  }

  var headContentType = '';
  try {
    final headResponse = await http
        .head(uri, headers: video?.headers ?? const {})
        .timeout(const Duration(seconds: 8));
    headContentType = headResponse.headers['content-type'] ?? '';

    if (headResponse.statusCode >= 200 && headResponse.statusCode < 400) {
      log("URL responded successfully.");
      final shouldValidateM3u8 =
          _looksLikeM3u8(uri.toString()) || _isM3u8ContentType(headContentType);
      if (!shouldValidateM3u8) {
        return true;
      }

      log("Checking stream playlist...");
      final firstSegmentUri = await _resolveFirstM3u8Segment(
        uri: uri,
        headers: video?.headers,
        log: log,
      );
      if (firstSegmentUri == null) {
        log("Unable to parse playable segment from playlist.");
        return false;
      }
      log("Checking first stream segment...");
      return _pingUri(firstSegmentUri, headers: video?.headers);
    }
  } catch (_) {}

  try {
    log("HEAD check failed. Trying fallback request...");
    final getHeaders = <String, String>{
      ...?video?.headers,
      'Range': 'bytes=0-0',
    };
    final getResponse = await http
        .get(uri, headers: getHeaders)
        .timeout(const Duration(seconds: 8));

    final statusCode = getResponse.statusCode;
    final ok = (statusCode >= 200 && statusCode < 400) || statusCode == 416;
    if (!ok) {
      log("URL is not reachable.");
      return false;
    }

    log("URL reachable via fallback request.");
    final contentType = getResponse.headers['content-type'] ?? headContentType;
    final shouldValidateM3u8 =
        _looksLikeM3u8(uri.toString()) || _isM3u8ContentType(contentType);
    if (!shouldValidateM3u8) {
      return true;
    }

    log("Checking stream playlist...");
    final firstSegmentUri = await _resolveFirstM3u8Segment(
      uri: uri,
      headers: video?.headers,
      cachedBody: getResponse.body,
      log: log,
    );
    if (firstSegmentUri == null) {
      log("Unable to parse playable segment from playlist.");
      return false;
    }
    log("Checking first stream segment...");
    return _pingUri(firstSegmentUri, headers: video?.headers);
  } catch (_) {
    log("URL check failed due to network error.");
    return false;
  }
}

bool _looksLikeM3u8(String url) {
  return url.toLowerCase().contains('.m3u8');
}

bool _isM3u8ContentType(String contentType) {
  final lower = contentType.toLowerCase();
  return lower.contains('application/vnd.apple.mpegurl') ||
      lower.contains('application/x-mpegurl') ||
      lower.contains('audio/mpegurl') ||
      lower.contains('audio/x-mpegurl');
}

Future<Uri?> _resolveFirstM3u8Segment({
  required Uri uri,
  required Map<String, String>? headers,
  required _LogFn log,
  String? cachedBody,
}) async {
  log("Reading playlist...");
  final playlistText =
      cachedBody ?? await _fetchText(uri: uri, headers: headers);
  if (playlistText == null || playlistText.isEmpty) {
    return null;
  }

  final parsed = parseM3u8Playlist(playlistText);
  if (parsed == null) {
    return null;
  }

  if (parsed.firstVariant != null) {
    log("Master playlist found. Opening first variant...");
    final variantUri = uri.resolve(parsed.firstVariant!);
    return _resolveFirstM3u8Segment(
      uri: variantUri,
      headers: headers,
      log: log,
    );
  }

  if (parsed.segments.isEmpty) {
    return null;
  }
  log("First segment found.");
  return uri.resolve(parsed.segments.first);
}

Future<String?> _fetchText({
  required Uri uri,
  required Map<String, String>? headers,
}) async {
  try {
    final response = await http
        .get(uri, headers: headers ?? const {})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 200 && response.statusCode < 400) {
      return response.body;
    }
  } catch (_) {
    return null;
  }
  return null;
}

Future<bool> _pingUri(
  Uri uri, {
  required Map<String, String>? headers,
}) async {
  try {
    final head = await http
        .head(uri, headers: headers ?? const {})
        .timeout(const Duration(seconds: 8));
    if (head.statusCode >= 200 && head.statusCode < 400) {
      return true;
    }
  } catch (_) {}

  try {
    final getHeaders = <String, String>{
      ...?headers,
      'Range': 'bytes=0-0',
    };
    final get = await http
        .get(uri, headers: getHeaders)
        .timeout(const Duration(seconds: 8));
    return (get.statusCode >= 200 && get.statusCode < 400) ||
        get.statusCode == 416;
  } catch (_) {
    return false;
  }
}

class _AnimePlaybackData {
  final local_video.Video currentTrack;
  final List<local_video.Video> tracks;

  const _AnimePlaybackData({
    required this.currentTrack,
    required this.tracks,
  });
}

class _LoaderLogSession {
  final RxString _currentLog = 'Preparing stream...'.obs;
  var _isClosed = false;
  var isCancelled = false;

  void show() {
    Get.dialog(
      WillPopScope(
        onWillPop: () async {
          cancel();
          return true;
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(Get.context!).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(Get.context!).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Obx(
                      () => Text(
                        _currentLog.value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 200),
    );
  }

  void log(String message) {
    if (_isClosed || isCancelled) return;
    _currentLog.value = message;
  }

  void cancel() {
    if (isCancelled) return;
    isCancelled = true;
    close();
  }

  void close() {
    if (_isClosed) return;
    _isClosed = true;
    if (Get.isDialogOpen == true) {
      Get.back();
    }
  }
}

double calculateProgress(int? min, int? max) {
  if (min == null || max == null || max <= 0 || min <= 0) {
    return 0.0;
  }

  return (min / max).clamp(0.0, 1.0);
}

String formatEpChapTitle(dynamic title, bool isManga) {
  final newTitle = title?.toString() ?? '??';
  return isManga ? 'Chapter $newTitle' : 'Episode $newTitle';
}

String formattedDate(int milliseconds) {
  return formatTimeAgo(milliseconds);
}

String formatProgressText(OfflineMedia data, bool isManga) {
  if (isManga) {
    return 'PAGE ${data.currentChapter?.pageNumber ?? '0'} / ${data.currentChapter?.totalPages ?? '??'}';
  } else {
    final watchedEpisodeNumber = data.currentEpisode?.number;
    final totalEpisodes = data.totalEpisodes;

    if (watchedEpisodeNumber == null) return '--';

    final watched = watchedEpisodeNumber.toString().split('.').first;
    final total = totalEpisodes ?? '??';
    return '$watched|$total';
  }
}
