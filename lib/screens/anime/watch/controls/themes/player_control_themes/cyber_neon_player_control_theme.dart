import 'dart:io';

import 'package:anymex/screens/anime/watch/controller/player_controller.dart';
import 'package:anymex/screens/anime/watch/controls/themes/setup/player_control_theme.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/decoder_quick_button.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/progress_slider.dart';
import 'package:anymex/screens/settings/sub_settings/settings_player.dart';
import 'package:anymex/utils/theme_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CyberNeonPlayerControlTheme extends PlayerControlTheme {
  CyberNeonPlayerControlTheme();

  @override
  String get id => 'cyber_neon';

  @override
  String get name => 'Cyber Neon';

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget buildTopControls(BuildContext context, PlayerController controller) {
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;

    return Obx(() {
      if (controller.isLocked.value) {
        if (!controller.showControls.value) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _CyberGlassButton(
              icon: Icons.lock_open_rounded,
              tooltip: 'Unlock Controls',
              color: Colors.cyanAccent,
              onPressed: () => controller.isLocked.value = false,
            ),
          ),
        );
      }

      return IgnorePointer(
        ignoring: !controller.showControls.value,
        child: AnimatedSlide(
          offset: controller.showControls.value ? Offset.zero : const Offset(0, -1),
          duration: controller.overlayAnimationDuration(320),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: controller.showControls.value ? 1.0 : 0.0,
            duration: controller.overlayAnimationDuration(260),
            child: SafeArea(
              bottom: false,
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 12,
                  vertical: isDesktop ? 16 : 8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.opaque(0.6, iReallyMeanIt: true),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.theme.colorScheme.primary.opaque(0.4, iReallyMeanIt: true),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.theme.colorScheme.primary.opaque(0.2, iReallyMeanIt: true),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _CyberGlassButton(
                      icon: CupertinoIcons.back,
                      tooltip: 'Back',
                      onPressed: () => controller.handleBack(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            controller.currentEpisode.value.title ??
                                controller.itemName ??
                                'Unknown Title',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            'EP ${controller.currentEpisode.value.number}',
                            style: TextStyle(
                              color: context.theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const DecoderQuickButton(isMobile: true),
                    const SizedBox(width: 8),
                    _CyberGlassButton(
                      icon: Icons.lock_outline_rounded,
                      tooltip: 'Lock',
                      onPressed: () => controller.isLocked.value = true,
                    ),
                    const SizedBox(width: 8),
                    _CyberGlassButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      color: Colors.cyanAccent,
                      onPressed: () {
                        controller.showSheetWithPause(
                          () => showModalBottomSheet(
                            context: Get.context!,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => Container(
                              margin: EdgeInsets.fromLTRB(
                                  16, 16, 16, MediaQuery.of(ctx).padding.bottom + 16),
                              height: MediaQuery.of(ctx).size.height * 0.85,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: context.theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: context.theme.colorScheme.primary
                                      .opaque(0.3, iReallyMeanIt: true),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.theme.colorScheme.primary
                                        .opaque(0.2, iReallyMeanIt: true),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                              child: const SettingsPlayer(isModal: true),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget buildCenterControls(BuildContext context, PlayerController controller) {
    return Obx(() {
      if (controller.isLocked.value || !controller.showControls.value) {
        return const SizedBox.shrink();
      }

      return AnimatedOpacity(
        opacity: controller.showControls.value ? 1.0 : 0.0,
        duration: controller.overlayAnimationDuration(260),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CyberCircleButton(
              icon: Icons.replay_10_rounded,
              onPressed: () {
                final current = controller.currentPosition.value;
                final target = current - const Duration(seconds: 10);
                controller.seekTo(target < Duration.zero ? Duration.zero : target);
              },
              size: 46,
            ),
            const SizedBox(width: 28),
            _CyberCircleButton(
              icon: controller.isPlaying.value
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onPressed: () => controller.togglePlayPause(),
              size: 64,
              isPrimary: true,
            ),
            const SizedBox(width: 28),
            _CyberCircleButton(
              icon: Icons.forward_10_rounded,
              onPressed: () {
                final current = controller.currentPosition.value;
                final total = controller.episodeDuration.value;
                final target = current + const Duration(seconds: 10);
                controller.seekTo(target > total ? total : target);
              },
              size: 46,
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget buildBottomControls(BuildContext context, PlayerController controller) {
    return Obx(() {
      if (controller.isLocked.value) return const SizedBox.shrink();

      return IgnorePointer(
        ignoring: !controller.showControls.value,
        child: AnimatedSlide(
          offset: controller.showControls.value ? Offset.zero : const Offset(0, 1),
          duration: controller.overlayAnimationDuration(320),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: controller.showControls.value ? 1.0 : 0.0,
            duration: controller.overlayAnimationDuration(260),
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.black.opaque(0.65, iReallyMeanIt: true),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: context.theme.colorScheme.primary.opaque(0.35, iReallyMeanIt: true),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.theme.colorScheme.primary.opaque(0.15, iReallyMeanIt: true),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDuration(controller.currentPosition.value),
                          style: TextStyle(
                            color: context.theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ProgressSlider(
                              style: SliderStyle.capsule,
                              activeTrackColor: context.theme.colorScheme.primary,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.cyanAccent,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(controller.episodeDuration.value),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CyberPillButton(
                            icon: Icons.queue_music_rounded,
                            label: 'Episodes',
                            onPressed: () {
                              controller.isEpisodePaneOpened.value =
                                  !controller.isEpisodePaneOpened.value;
                            },
                          ),
                          const SizedBox(width: 8),
                          _CyberPillButton(
                            icon: Icons.subtitles_outlined,
                            label: 'Tracks',
                            onPressed: () {
                              controller.isTracksPaneOpened.value =
                                  !controller.isTracksPaneOpened.value;
                            },
                          ),
                          const SizedBox(width: 8),
                          _CyberPillButton(
                            icon: Icons.cloud_outlined,
                            label: 'Source',
                            onPressed: () {
                              controller.isSourcePaneOpened.value =
                                  !controller.isSourcePaneOpened.value;
                            },
                          ),
                          const SizedBox(width: 8),
                          _CyberPillButton(
                            icon: Icons.speed_rounded,
                            label: 'Speed',
                            onPressed: () {
                              controller.isSpeedPaneOpened.value =
                                  !controller.isSpeedPaneOpened.value;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _CyberGlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _CyberGlassButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.opaque(0.08, iReallyMeanIt: true),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (color ?? context.theme.colorScheme.primary).opaque(0.3, iReallyMeanIt: true),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: color ?? context.theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _CyberCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool isPrimary;

  const _CyberCircleButton({
    required this.icon,
    required this.onPressed,
    required this.size,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.theme.colorScheme.primary;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPrimary ? primaryColor : Colors.black.opaque(0.6, iReallyMeanIt: true),
          border: Border.all(
            color: isPrimary ? Colors.cyanAccent : primaryColor.opaque(0.4, iReallyMeanIt: true),
            width: isPrimary ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPrimary ? primaryColor : Colors.black).opaque(0.4, iReallyMeanIt: true),
              blurRadius: isPrimary ? 20 : 10,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: size * 0.5,
          color: isPrimary ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class _CyberPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CyberPillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.opaque(0.06, iReallyMeanIt: true),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.theme.colorScheme.primary.opaque(0.3, iReallyMeanIt: true),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: context.theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
