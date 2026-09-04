import 'package:anymex/database/data_keys/keys.dart';
import 'package:anymex/database/isar_models/episode.dart';
import 'package:anymex/database/isar_models/video.dart' as model;
import 'package:anymex/models/Media/media.dart' as anymex;
import 'package:anymex/screens/anime/watch/controller/player_controller.dart';
import 'package:anymex/screens/anime/watch/controls/themes/setup/themed_controls.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/double_tap_seek.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/episodes_pane.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/overlay.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/buffering_overlay.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/subtitle_text.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/tracks_popup.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/source_popup.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/speed_popup.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/sync_subs_popup.dart';
import 'package:anymex/screens/anime/widgets/media_indicator.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/shader_osd.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

class WatchScreen extends StatefulWidget {
  final model.Video episodeSrc;
  final Episode currentEpisode;
  final List<Episode> episodeList;
  final anymex.Media anilistData;
  final List<model.Video> episodeTracks;
  final bool shouldTrack;
  const WatchScreen({
    super.key,
    required this.episodeSrc,
    required this.currentEpisode,
    required this.episodeList,
    required this.anilistData,
    required this.episodeTracks,
    this.shouldTrack = true,
  });

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> with AutomaticKeepAliveClientMixin {
  late PlayerController controller;
  bool _canPop = false;

  @override
  bool get wantKeepAlive => true;

  @override
  initState() {
    super.initState();
    controller = Get.put(PlayerController(
        widget.episodeSrc,
        widget.currentEpisode,
        widget.episodeList,
        widget.anilistData,
        widget.episodeTracks,
        shouldTrack: widget.shouldTrack));
  }

  @override
  void dispose() {
    Get.delete<PlayerController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await controller.prepareForExit();
        if (mounted) {
          setState(() {
            _canPop = true;
          });
          navigator.pop(result);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // BASE LAYER: The Video Widget MUST be completely isolated here
            const Positioned.fill(
              child: _StaticVideoLayer(),
            ),
            
            // TOP LAYER: The UI Controls
            Positioned.fill(
              child: Stack(
                children: [
                  PlayerOverlay(controller: controller),
                  BufferingOverlay(controller: controller),
                  Obx(() {
                    controller.playerReloadVersion.value;
                    if (PlayerKeys.useLibass.get<bool>(false)) {
                      return const SizedBox.shrink();
                    }
                    return SubtitleText(controller: controller);
                  }),
                  DoubleTapSeekWidget(
                    controller: controller,
                  ),
                  const Align(
                    alignment: Alignment.center,
                    child: ThemedCenterControls(),
                  ),
                  const Align(
                    alignment: Alignment.topCenter,
                    child: ThemedTopControls(),
                  ),
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: ThemedBottomControls(),
                  ),
                  MediaIndicatorBuilder(
                    isVolumeIndicator: false,
                    controller: controller,
                  ),
                  MediaIndicatorBuilder(
                    isVolumeIndicator: true,
                    controller: controller,
                  ),
                  ShaderOsd(controller: controller),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    left: 0,
                    child: SourcePopup(controller: controller),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    left: 0,
                    child: TracksPopup(controller: controller),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    left: 0,
                    child: SyncSubsPopup(controller: controller),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    left: 0,
                    child: EpisodesPane(controller: controller),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    left: 0,
                    child: SpeedPopup(controller: controller),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomProgressLine(controller: controller),
                  ),
                ],
              ), 
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomProgressLine extends StatelessWidget {
  final PlayerController controller;
  const _BottomProgressLine({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final showControls = controller.showControls.value;
      final duration = controller.episodeDuration.value.inMilliseconds;
      
      return AnimatedOpacity(
        opacity: (showControls || duration == 0) ? 0.0 : 1.0,
        duration: controller.overlayAnimationDuration(300),
        child: IgnorePointer(
          ignoring: showControls || duration == 0,
          child: _ProgressBar(controller: controller),
        ),
      );
    });
  }
}

class _ProgressBar extends StatelessWidget {
  final PlayerController controller;
  const _ProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final duration = controller.episodeDuration.value.inMilliseconds;
      final position = controller.currentPosition.value.inMilliseconds;
      final progress = duration == 0 ? 0.0 : (position / duration).clamp(0.0, 1.0);
      final theme = Theme.of(context);
      final primaryColor = theme.colorScheme.primary;

      return RepaintBoundary(
        child: SizedBox(
          height: 5.0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final filledWidth = totalWidth * progress;

              return Stack(
                alignment: Alignment.bottomLeft,
                clipBehavior: Clip.none,
                children: [
                  // Filled progress line with static 40% opacity flush with bottom
                  if (filledWidth > 0)
                    Container(
                      height: 2.5,
                      width: filledWidth,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.40),
                      ),
                    ),
                  // Comet Head leading edge at 90% opacity
                  if (filledWidth > 0)
                    Positioned(
                      left: (filledWidth - 6).clamp(0.0, totalWidth - 10),
                      bottom: -1.0,
                      child: Container(
                        width: 10,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Color.lerp(primaryColor, Colors.white, 0.15)!
                              .withOpacity(0.90),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.60),
                              blurRadius: 5,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    });
  }
}

class _StaticVideoLayer extends StatelessWidget {
  const _StaticVideoLayer();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    
    return Obx(() => Video(
      key: const ValueKey('video_player_surface'),
      controller: controller.videoController,
      fit: controller.videoFit.value,
      fill: Colors.black,
      controls: null,
      subtitleViewConfiguration: SubtitleViewConfiguration(
        visible: PlayerKeys.useLibass.get<bool>(false)
      ),
    ));
  }
}
