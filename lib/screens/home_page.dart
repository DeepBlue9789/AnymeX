import 'dart:math' as math;

import 'package:anymex/controllers/cacher/cache_controller.dart';
import 'package:anymex/controllers/offline/offline_storage_controller.dart';
import 'package:anymex/controllers/service_handler/service_handler.dart';
import 'package:anymex/controllers/settings/methods.dart';
import 'package:anymex/controllers/settings/settings.dart';
import 'package:anymex/controllers/source/source_controller.dart';
import 'package:anymex/controllers/sync/gist_sync_controller.dart';
import 'package:anymex/database/isar_models/offline_media.dart';
import 'package:anymex/database/isar_models/episode.dart';
import 'package:anymex/screens/library/widgets/history_model.dart';
import 'package:anymex/utils/theme_extensions.dart';
import 'package:anymex/widgets/anime/continue_watching_cards.dart';
import 'package:anymex/widgets/common/reusable_carousel.dart';
import 'package:anymex/widgets/common/scroll_aware_app_bar.dart';
import 'package:anymex/widgets/custom_widgets/anymex_button.dart';
import 'package:anymex/widgets/custom_widgets/anymex_image.dart';

import 'package:anymex/widgets/header.dart';
import 'package:anymex/widgets/helper/platform_builder.dart';

import 'package:anymex/widgets/non_widgets/snackbar.dart';
import 'package:anymex_extension_runtime_bridge/Models/Source.dart';
import 'package:anymex/database/data_keys/keys.dart';
import 'package:anymex/widgets/custom_widgets/anymex_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ScrollController _scrollController;
  final ValueNotifier<bool> _isAppBarVisibleExternally =
      ValueNotifier<bool>(true);
  bool _snapAll = false;

  Widget _buildContinueWatchingSection(
      OfflineStorageController offlineStorageController) {
    return Obx(() {
      final isSyncing = Get.isRegistered<GistSyncController>() &&
          Get.find<GistSyncController>().isSyncing.value;
      if (offlineStorageController.isAnimeLibraryLoading.value ||
          (isSyncing && offlineStorageController.rxAnimeLibrary.isEmpty)) {
        return const _ContinueWatchingSkeleton();
      }

      final settings = Get.find<Settings>();
      final completionThreshold = settings.markAsCompleted;

      // Compute display entries: for completed episodes, advance to next episode
      final rawHistory = offlineStorageController.rxAnimeLibrary
          .where((e) => e.currentEpisode != null)
          .toList()
        ..sort((a, b) => (b.currentEpisode?.lastWatchedTime ?? 0)
            .compareTo(a.currentEpisode?.lastWatchedTime ?? 0));

      // Build display list, advancing past completed episodes
      final displayEntries = <_HistoryDisplayEntry>[];
      final toRemoveIds = <String>[];

      for (final media in rawHistory) {
        final ep = media.currentEpisode;
        if (ep == null) continue;

        final ts = ep.timeStampInMilliseconds ?? 0;
        var dur = ep.durationInMilliseconds ?? 0;
        if (dur <= 0 && media.watchedEpisodes != null) {
          final matched = media.watchedEpisodes!
              .firstWhereOrNull((e) => e.number == ep.number);
          if (matched?.durationInMilliseconds != null &&
              matched!.durationInMilliseconds! > 0) {
            dur = matched.durationInMilliseconds!;
          }
        }
        final progressPct =
            dur > 0 ? ((ts / dur) * 100).toInt() : 0;
        final isCompleted = progressPct >= completionThreshold;

        if (isCompleted) {
          // Find the next episode in the list
          final episodes = media.episodes ?? [];
          final currentNum = double.tryParse(ep.number) ?? 0;

          // Check if tracker has released episode information for this anime
          int? maxReleasedEpisode;
          if (serviceHandler.isLoggedIn.value && serviceHandler.animeList.isNotEmpty) {
            final tracked = serviceHandler.animeList
                .firstWhereOrNull((a) => a.id == media.mediaId);
            if (tracked != null) {
              if (tracked.releasedEpisodes != null) {
                maxReleasedEpisode = int.tryParse(tracked.releasedEpisodes!);
              } else if (tracked.mediaStatus == 'FINISHED') {
                maxReleasedEpisode = int.tryParse(tracked.totalEpisodes ?? '');
              } else if (tracked.mediaStatus == 'RELEASING' || tracked.nextAiringEpisode != null) {
                maxReleasedEpisode = tracked.nextAiringEpisode != null
                    ? tracked.nextAiringEpisode!.episode - 1
                    : null;
              }
            }
          }

          final nextEp = episodes.cast<dynamic>().firstWhereOrNull((e) {
            final num = double.tryParse((e as dynamic).number as String) ?? 0;
            if (num <= currentNum) return false;
            if (maxReleasedEpisode != null && num > maxReleasedEpisode) return false;
            final hasLink = (e as dynamic).link != null &&
                ((e as dynamic).link as String).isNotEmpty;
            final hadAnyLinks = episodes.any((x) =>
                (x as dynamic).link != null &&
                ((x as dynamic).link as String).isNotEmpty);
            if (hadAnyLinks && !hasLink) return false;
            return true;
          });

          if (nextEp != null) {
            displayEntries.add(_HistoryDisplayEntry(
              media: media,
              overrideEpisodeNumber: (nextEp as dynamic).number as String,
              overrideEpisodeTitle: (nextEp as dynamic).title as String?,
              isNextEpisode: true,
            ));
          } else if (episodes.isNotEmpty) {
            // All currently released or total episodes watched (e.g. 7/7 or 12/12)
            // -> remove entry from local history. Later, when a new episode is released,
            // the tracker (AniList) continue watching section will trigger Up Next for that episode.
            if (media.mediaId != null && media.mediaId!.isNotEmpty) {
              toRemoveIds.add(media.mediaId!);
            }
          } else {
            // Episode list not populated yet, display current episode entry
            displayEntries.add(_HistoryDisplayEntry(
              media: media,
            ));
          }
        } else {
          displayEntries.add(_HistoryDisplayEntry(
            media: media,
          ));
        }

        if (displayEntries.length >= 20) {
          break;
        }
      }

      if (toRemoveIds.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final id in toRemoveIds) {
            offlineStorageController.clearMediaHistory(
              id,
              mediaType: ItemType.anime,
            );
          }
        });
      }

      // Check tracker (AniList / MAL / Simkl) Continue Watching items
      // When tracker data has anime with 1 or 2 unwatched episodes, create cards for them in the History section!
      if (serviceHandler.isLoggedIn.value && serviceHandler.animeList.isNotEmpty) {
        final continueWatchingAnime = serviceHandler.animeList
            .where((anime) => anime.watchingStatus == 'CURRENT')
            .toList();

        for (final anime in continueWatchingAnime) {
          if (anime.id == null || anime.id!.isEmpty) continue;
          final watched = int.tryParse(anime.episodeCount ?? '0') ?? 0;
          int? totalOrReleased;
          if (anime.releasedEpisodes != null) {
            totalOrReleased = int.tryParse(anime.releasedEpisodes!);
          } else if (anime.mediaStatus == 'FINISHED') {
            totalOrReleased = int.tryParse(anime.totalEpisodes ?? '0');
          } else if (anime.mediaStatus == 'RELEASING' || anime.nextAiringEpisode != null) {
            totalOrReleased = anime.nextAiringEpisode != null
                ? anime.nextAiringEpisode!.episode - 1
                : null;
          } else {
            totalOrReleased = int.tryParse(anime.totalEpisodes ?? '0');
          }

          if (totalOrReleased == null || totalOrReleased <= 0) continue;

          final unwatched = totalOrReleased - watched;

          if (watched >= 1 && (unwatched == 1 || unwatched == 2)) {
            final alreadyPresent = displayEntries
                .any((e) => e.media.mediaId == anime.id);
            if (alreadyPresent) continue;

            final nextEpNum = (watched + 1).toString();
            final existingOffline =
                offlineStorageController.getAnimeById(anime.id!);
            if (existingOffline != null) {
              if (existingOffline.poster == null ||
                  existingOffline.poster!.isEmpty) {
                existingOffline.poster = anime.poster;
              }
              if (existingOffline.cover == null ||
                  existingOffline.cover!.isEmpty) {
                existingOffline.cover = anime.poster;
              }
              if (existingOffline.name == null ||
                  existingOffline.name!.isEmpty) {
                existingOffline.name = anime.title;
              }
              if (existingOffline.idMal == null ||
                  existingOffline.idMal!.isEmpty) {
                existingOffline.idMal = anime.idMal;
              }
            }

            final targetEp = existingOffline?.episodes?.firstWhereOrNull(
              (e) => e.number == nextEpNum,
            );

            final offlineMedia = existingOffline ??
                OfflineMedia(
                  mediaId: anime.id,
                  idMal: anime.idMal,
                  name: anime.title,
                  poster: anime.poster,
                  cover: anime.poster,
                  mediaTypeIndex: 1,
                  currentEpisode: Episode(
                    number: nextEpNum,
                    title: targetEp?.title ?? 'Episode $nextEpNum',
                    source: DynamicKeys.stickySource.get(anime.id!),
                  ),
                  episodes: targetEp != null
                      ? [targetEp]
                      : [
                          Episode(
                            number: nextEpNum,
                            title: 'Episode $nextEpNum',
                          )
                        ],
                );

            displayEntries.add(_HistoryDisplayEntry(
              media: offlineMedia,
              overrideEpisodeNumber: nextEpNum,
              overrideEpisodeTitle: targetEp?.title ?? 'Episode $nextEpNum',
              isNextEpisode: true,
            ));
          }

          if (displayEntries.length >= 20) {
            break;
          }
        }
      }

      if (displayEntries.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "History",
                  style: TextStyle(
                    fontFamily: "Poppins-SemiBold",
                    fontSize: 17,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showClearAllHistoryDialog(
                      context,
                      offlineStorageController,
                      rawHistory),
                  child: Text(
                    "Clear All",
                    style: TextStyle(
                      fontFamily: "Poppins-SemiBold",
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 168,
            child: RepaintBoundary(
              child: Builder(
                builder: (context) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                      mainAxisSpacing: 0,
                      crossAxisSpacing: 10,
                      mainAxisExtent: 200,
                    ),
                    itemCount: displayEntries.length,
                    itemBuilder: (context, i) {
                      final entry = displayEntries[i];
                      final model = entry.toHistoryModel();
                      return _RemovableHistoryCard(
                        key: ValueKey(entry.media.mediaId),
                        media: model,
                        snapAll: _snapAll,
                        onRemoved: () {
                          offlineStorageController.clearMediaHistory(
                            entry.media.mediaId ?? '',
                            mediaType: ItemType.anime,
                          );
                        },
                        onLongPress: model.onLongPress,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }

  void _showClearAllHistoryDialog(BuildContext context,
      OfflineStorageController controller, List<OfflineMedia> items) {
    showDialog(
      context: context,
      builder: (context) => AnymexDialog(
        title: 'Clear All History',
        contentWidget: const Text(
          'Are you sure you want to clear all local watch history? This action cannot be undone.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
        confirmText: 'Clear All',
        onConfirm: () {
          HapticFeedback.mediumImpact();
          setState(() => _snapAll = true);
          Future.delayed(const Duration(milliseconds: 1500), () {
            controller.clearMediaHistoryBulk(
              items.map((e) => e.mediaId ?? ''),
              mediaType: ItemType.anime,
            );
            if (mounted) setState(() => _snapAll = false);
          });
        },
      ),
    );
  }

  List<Widget> _buildHomeWidgets({
    required BuildContext context,
    required ServiceHandler serviceHandler,
    required CacheController cacheController,
    required OfflineStorageController offlineStorageController,
    required Settings settings,
  }) {
    final baseWidgets = serviceHandler.homeWidgets(context);
    final shouldShowContinueSection = settings.showContinueWatchingCard;

    if (!shouldShowContinueSection) {
      return List<Widget>.from(baseWidgets);
    }
    final localSections = <Widget>[
      const SizedBox(height: 8),
      if (shouldShowContinueSection)
        _buildContinueWatchingSection(offlineStorageController),
      const SizedBox(height: 4),
    ];

    int insertionIndex;
    if (serviceHandler.serviceType.value == ServicesType.simkl) {
      insertionIndex = serviceHandler.isLoggedIn.value ? 3 : 2;
    } else {
      // Always insert local history at the very top of the feed,
      // regardless of login state. "Resume where you left off" belongs
      // above online lists and recommendations.
      insertionIndex = 0;
    }
    insertionIndex = math.min(insertionIndex, baseWidgets.length);

    return [
      ...baseWidgets.take(insertionIndex),
      ...localSections,
      ...baseWidgets.skip(insertionIndex),
    ];
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDiscordDialog();
      if (Get.isRegistered<OfflineStorageController>()) {
        Get.find<OfflineStorageController>().refreshHistoryEpisodes();
      }
      if (Get.isRegistered<GistSyncController>()) {
        final syncCtrl = Get.find<GistSyncController>();
        if (syncCtrl.syncProvider.value == 'pocketbase' && syncCtrl.isPocketbaseConnected.value) {
          syncCtrl.pullLocalHistoryNow();
        }
      }
    });
  }

  void _showDiscordDialog() {
    if (kDebugMode) return;
    if (General.hasJoinedNewDiscord.get(false)) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AnymexDialog(
            title: 'Important Announcement',
            showCancelButton: false,
            confirmText: 'Join Discord',
            onConfirm: () async {
              General.hasJoinedNewDiscord.set(true);
              final url = Uri.parse(Get.find<Settings>().discordUrl.value);
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            contentWidget: const Text(
              'Our previous Discord server with over 2,100 members was unfortunately taken down due to copyright infringement.\n\n'
              'We are trying to rebuild! Please join our new Discord server to help us gain our wonderful community back. '
              'You must join to continue using the app.',
            ),
          ),
        );
      },
    );
  }

  ScrollController get scrollController => _scrollController;

  @override
  void dispose() {
    _scrollController.dispose();
    _isAppBarVisibleExternally.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cacheController = Get.find<CacheController>();
    final offlineStorageController = Get.find<OfflineStorageController>();
    final serviceHandler = Get.find<ServiceHandler>();
    final settings = Get.find<Settings>();
    final sourceController = Get.find<SourceController>();
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const appBarHeight = kToolbarHeight + 20;
    final double bottomNavBarHeight = MediaQuery.of(context).padding.bottom;

    bool isMobile =
        getResponsiveValue(context, desktopValue: false, mobileValue: true);

    final List<dynamic> novelData = [];

    return RefreshIndicator(
      onRefresh: () async {
        if (Get.isRegistered<GistSyncController>()) {
          final syncCtrl = Get.find<GistSyncController>();
          if (syncCtrl.syncProvider.value == 'pocketbase' && syncCtrl.isPocketbaseConnected.value) {
            await syncCtrl.pullLocalHistoryNow();
          }
        }
        await offlineStorageController.refreshHistoryEpisodes();
        if (!serviceHandler.isLoggedIn.value) {
          snackBar(
              "W-what are you doing step-bro, login before you do that (●´⌓`●)",
              duration: 1200);
        }
        await serviceHandler.refresh();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: isMobile
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: isDesktop ? 10 : statusBarHeight + appBarHeight,
                  ),
                  Column(
                    crossAxisAlignment: isMobile
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Obx(() {
                        cacheController.currentPool.length;
                        final children = _buildHomeWidgets(
                          context: context,
                          serviceHandler: serviceHandler,
                          cacheController: cacheController,
                          offlineStorageController: offlineStorageController,
                          settings: settings,
                        );
                        return Column(children: children);
                      }),
                      if (novelData.isNotEmpty)
                        ReusableCarousel(
                          title: "Recommended Novels",
                          data: novelData,
                          type: ItemType.novel,
                          source: sourceController.activeNovelSource.value,
                        ),
                    ],
                  ),
                  if (!isDesktop)
                    SizedBox(height: bottomNavBarHeight)
                  else
                    const SizedBox(height: 50),
                ],
              ),
            ),
            if (!isDesktop)
              CustomAnimatedAppBar(
                isVisible: _isAppBarVisibleExternally,
                scrollController: _scrollController,
                headerContent: const Header(type: PageType.home),
                visibleStatusBarStyle: SystemUiOverlayStyle(
                  statusBarIconBrightness:
                      Theme.of(context).brightness == Brightness.light
                          ? Brightness.dark
                          : Brightness.light,
                  statusBarBrightness: Theme.of(context).brightness,
                  statusBarColor: Colors.transparent,
                ),
                hiddenStatusBarStyle: SystemUiOverlayStyle(
                  statusBarIconBrightness:
                      Theme.of(context).brightness == Brightness.light
                          ? Brightness.light
                          : Brightness.dark,
                  statusBarBrightness:
                      Theme.of(context).brightness == Brightness.light
                          ? Brightness.dark
                          : Brightness.light,
                  statusBarColor: Colors.transparent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ImageButton extends StatelessWidget {
  final String buttonText;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final String backgroundImage;
  final double width;
  final double height;
  final double borderRadius;
  final TextStyle? textStyle;
  final double margin;

  const ImageButton({
    super.key,
    required this.buttonText,
    required this.onPressed,
    this.onLongPress,
    required this.backgroundImage,
    this.width = 160,
    this.height = 60,
    this.borderRadius = 18,
    this.textStyle,
    this.margin = 0,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = Theme.of(context).brightness == Brightness.dark
        ? [
            Colors.black.withOpacity(0.5),
            Colors.black.withOpacity(0.5),
          ]
        : [Colors.transparent, Colors.transparent];
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.symmetric(vertical: margin),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius.multiplyRadius()),
        border: Border.all(
          width: 1,
          color: context.colors.inverseSurface.withOpacity(0.3),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(borderRadius.multiplyRadius()),
              child: AnymeXImage(
                height: height,
                width: width,
                imageUrl: backgroundImage,
                fit: BoxFit.cover,
                radius: 0,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
          Positioned.fill(
            child: AnymexButton(
              onTap: onPressed,
              onLongPress: onLongPress,
              padding: EdgeInsets.zero,
              color: Colors.transparent,
              border: BorderSide(
                color: context.colors.primary.withOpacity(0.7),
              ),
              radius: borderRadius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText.toUpperCase(),
                    style: textStyle ??
                        const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins-SemiBold',
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    color: context.colors.primary,
                    height: 2,
                    width: 6 * buttonText.length.toDouble(),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovableHistoryCard extends StatefulWidget {
  final HistoryModel media;
  final VoidCallback onRemoved;
  final VoidCallback? onLongPress;
  final bool snapAll;

  const _RemovableHistoryCard({
    super.key,
    required this.media,
    required this.onRemoved,
    this.onLongPress,
    this.snapAll = false,
  });

  @override
  State<_RemovableHistoryCard> createState() => _RemovableHistoryCardState();
}

class _RemovableHistoryCardState extends State<_RemovableHistoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didUpdateWidget(covariant _RemovableHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapAll && !oldWidget.snapAll) {
      _controller.forward(from: 0);
    }
  }

  void _triggerRemoval() {
    HapticFeedback.lightImpact();
    _controller.forward(from: 0).then((_) => widget.onRemoved());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContinueWatchingCard(
      media: widget.media,
      onRemove: _triggerRemoval,
      onLongPress: widget.onLongPress,
    );
  }
}

/// Data class holding either the original or next-episode display info.
class _HistoryDisplayEntry {
  final OfflineMedia media;
  final String? overrideEpisodeNumber;
  final String? overrideEpisodeTitle;
  final bool isNextEpisode;

  const _HistoryDisplayEntry({
    required this.media,
    this.overrideEpisodeNumber,
    this.overrideEpisodeTitle,
    this.isNextEpisode = false,
  });

  HistoryModel toHistoryModel() {
    if (!isNextEpisode) {
      return HistoryModel.fromOfflineMedia(media, ItemType.anime);
    }
    final base = HistoryModel.fromOfflineMedia(media, ItemType.anime);
    final epNum = overrideEpisodeNumber ?? '??';

    final targetEp = media.episodes?.cast<dynamic>().firstWhereOrNull(
      (e) {
        final numStr = (e as dynamic).number?.toString();
        if (numStr == null) return false;
        if (numStr == epNum) return true;
        final d1 = double.tryParse(numStr);
        final d2 = double.tryParse(epNum);
        return d1 != null && d2 != null && d1 == d2;
      },
    );

    VoidCallback? nextOnTap;
    if (targetEp != null) {
      final epObj = targetEp as dynamic;
      final posterUrl = (media.poster != null && media.poster!.isNotEmpty)
          ? media.poster
          : media.cover;
      final coverUrl = (media.cover != null && media.cover!.isNotEmpty)
          ? media.cover
          : media.poster;

      final clonedMedia = OfflineMedia(
        mediaId: media.mediaId,
        idMal: media.idMal,
        name: media.name,
        jname: media.jname,
        english: media.english,
        poster: posterUrl,
        cover: coverUrl,
        mediaTypeIndex: media.mediaTypeIndex,
        currentEpisode: Episode(
          number: epObj.number as String,
          title: epObj.title as String? ?? overrideEpisodeTitle ?? 'Episode $epNum',
          timeStampInMilliseconds: 0,
          durationInMilliseconds: 0,
          lastWatchedTime: DateTime.now().millisecondsSinceEpoch,
          source: media.currentEpisode?.source ??
              DynamicKeys.stickySource.get(media.mediaId ?? ''),
          link: epObj.link as String?,
          thumbnail: epObj.thumbnail as String?,
        ),
        episodes: media.episodes,
        watchedEpisodes: media.watchedEpisodes,
      )..id = media.id;
      nextOnTap = HistoryModel.fromOfflineMedia(clonedMedia, ItemType.anime).onTap;
    } else {
      final posterUrl = (media.poster != null && media.poster!.isNotEmpty)
          ? media.poster
          : media.cover;
      final coverUrl = (media.cover != null && media.cover!.isNotEmpty)
          ? media.cover
          : media.poster;

      final clonedMedia = OfflineMedia(
        mediaId: media.mediaId,
        idMal: media.idMal,
        name: media.name,
        jname: media.jname,
        english: media.english,
        poster: posterUrl,
        cover: coverUrl,
        mediaTypeIndex: media.mediaTypeIndex,
        currentEpisode: Episode(
          number: epNum,
          title: overrideEpisodeTitle ?? 'Episode $epNum',
          timeStampInMilliseconds: 0,
          durationInMilliseconds: 0,
          lastWatchedTime: DateTime.now().millisecondsSinceEpoch,
          source: media.currentEpisode?.source ??
              DynamicKeys.stickySource.get(media.mediaId ?? ''),
        ),
        episodes: media.episodes,
        watchedEpisodes: media.watchedEpisodes,
      )..id = media.id;
      nextOnTap = HistoryModel.fromOfflineMedia(clonedMedia, ItemType.anime).onTap;
    }

    final nextEpThumb = (targetEp as dynamic)?.thumbnail as String?;
    final poster = media.poster ?? media.cover ?? '';
    final cover = media.cover ?? media.poster ?? '';

    bool isPosterOrCover(String? url) {
      if (url == null || url.trim().isEmpty) return true;
      final trimmed = url.trim();
      return trimmed == poster || trimmed == cover;
    }

    String nextCover = '';
    if (nextEpThumb != null && nextEpThumb.trim().isNotEmpty && !isPosterOrCover(nextEpThumb)) {
      nextCover = nextEpThumb;
    } else {
      nextCover = cover.isNotEmpty ? cover : poster;
    }

    final resolvedPoster = (nextCover.isNotEmpty && !isPosterOrCover(nextCover))
        ? nextCover
        : (media.poster ?? media.cover ?? '');

    return HistoryModel(
      media: media,
      title: base.title,
      cover: nextCover,
      poster: resolvedPoster,
      formattedEpisodeTitle: '▶ Episode $epNum',
      sourceName: base.sourceName,
      progress: 0,
      totalProgress: 1,
      progressTitle: overrideEpisodeTitle ?? 'Episode $epNum',
      isManga: false,
      calculatedProgress: 0.0,
      onTap: nextOnTap,
      onLongPress: base.onLongPress,
      date: null,
      progressText: 'Up Next',
    );
  }
}

/// Shimmer skeleton for the local history section while data loads.
class _ContinueWatchingSkeleton extends StatelessWidget {
  const _ContinueWatchingSkeleton();

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlightColor =
        Theme.of(context).colorScheme.surfaceContainerHigh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: 120,
              height: 18,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 168,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, _) => Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                width: 200,
                height: 168,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
