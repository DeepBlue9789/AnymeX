import 'dart:convert';
import 'dart:io';

import 'package:anymex/database/data_keys/keys.dart';
import 'package:anymex/screens/anime/watch/controller/player_controller.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/control_button.dart';
import 'package:anymex/screens/anime/watch/controls/widgets/progress_slider.dart';
import 'package:anymex/widgets/custom_widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:anymex/utils/theme_extensions.dart';
import 'package:get/get.dart';

class BottomControls extends StatefulWidget {
  const BottomControls({super.key});

  @override
  State<BottomControls> createState() => _BottomControlsState();
}

class _BottomControlsState extends State<BottomControls> {
  // Cache the expensive JSON decode so it doesn't run on every reactive rebuild.
  // Re-parsed only when the settings value actually changes.
  List<String> _leftButtonIds = [];
  List<String> _rightButtonIds = [];
  Map<String, dynamic> _buttonConfigs = {};
  String _cachedJsonString = '';

  @override
  void initState() {
    super.initState();
    _parseButtonConfig();
  }

  void _parseButtonConfig() {
    final jsonString = PlayerUiKeys.bottomControlsSettings.get<String>('{}');
    if (jsonString == _cachedJsonString) return;
    _cachedJsonString = jsonString;
    try {
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      _leftButtonIds = List<String>.from(decoded['leftButtonIds'] ?? []);
      _rightButtonIds = List<String>.from(decoded['rightButtonIds'] ?? []);
      _buttonConfigs = Map<String, dynamic>.from(decoded['buttonConfigs'] ?? {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Re-check config in case it changed while the widget was alive.
    _parseButtonConfig();

    final controller = Get.find<PlayerController>();
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;

    return Obx(() {
      if (controller.isLocked.value) {
        final show = controller.showControls.value;
        return AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: controller.overlayAnimationDuration(300),
          child: IgnorePointer(
            ignoring: !show,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 20,
                    vertical: isDesktop ? 24 : 8,
                  ),
                  child: IgnorePointer(
                    ignoring: true,
                    child: Opacity(
                      opacity: 0.7,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                        child: const ProgressSlider(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      final showControls = controller.showControls.value;
      final inSkipSegment = controller.currentSkipInterval.value != null;
      final bottomBarVisible = showControls || inSkipSegment;

      return IgnorePointer(
        ignoring: !bottomBarVisible,
        child: AnimatedSlide(
          offset: bottomBarVisible ? Offset.zero : const Offset(0, 1),
          duration: controller.overlayAnimationDuration(400),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: bottomBarVisible ? 1.0 : 0.0,
            duration: controller.overlayAnimationDuration(300),
            curve: Curves.easeOut,
            child: showControls
                ? _buildFullBar(context, isDesktop)
                : _buildStandaloneSkip(context, isDesktop),
          ),
        ),
      );
    });
  }

  Widget _buildStandaloneSkip(BuildContext context, bool isDesktop) {
    final horizontal = isDesktop ? 32.0 : 20.0;
    final vertical = isDesktop ? 24.0 : 8.0;
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: horizontal + 20,
            bottom: vertical + 5,
            child: _buildSkipButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBar(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 20,
            vertical: isDesktop ? 24 : 8,
          ),
          child: _buildLayout(context),
        ),
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    final controller = Get.find<PlayerController>();
    final theme = context.theme;
    final isDark = theme.brightness == Brightness.dark;

    // Only watch the coarse state changes (active/inactive, interval identity).
    // The countdown progress animation is handled inside _CountdownProgressBar,
    // which has its own Obx isolated by a RepaintBoundary — so the outer
    // Material/InkWell/Container does NOT rebuild every second.
    return Obx(() {
      final isCountdownActive = controller.isAutoSkipCountdownActive;
      final interval = controller.currentSkipInterval.value;
      final inSegment = interval != null || isCountdownActive;

      return Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap:
              controller.isLocked.value ? null : controller.performSkipAction,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.6)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? theme.colorScheme.outline
                    : theme.colorScheme.outline.opaque(0.5),
                width: 0.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Isolated fill bar — only this widget rebuilds each second.
                if (isCountdownActive)
                  Positioned.fill(
                    child: _CountdownProgressBar(
                      controller: controller,
                      fillColor: theme.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (inSegment)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            isCountdownActive
                                ? Icons.close_rounded
                                : Icons.skip_next_rounded,
                            color: controller.isLocked.value
                                ? theme.colorScheme.onSurface.opaque(0.4)
                                : theme.colorScheme.onSurface,
                            size: 20,
                          ),
                        ),
                      AnymexText(
                        text: controller.skipButtonLabel,
                        variant: TextVariant.semiBold,
                        color: controller.isLocked.value
                            ? theme.colorScheme.onSurface.opaque(0.4)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// A self-contained fill bar for the skip countdown.
/// Keeps its own Obx that only watches [autoSkipCountdownRemaining] so
/// the parent skip-button widget never rebuilds on each countdown tick.
class _CountdownProgressBar extends StatelessWidget {
  final PlayerController controller;
  final Color fillColor;

  const _CountdownProgressBar({
    required this.controller,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Obx(() {
        final remaining = controller.autoSkipCountdownRemaining.value;
        final progress = 1.0 -
            (remaining / PlayerController.autoSkipCountdownSeconds);
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 950),
          curve: Curves.linear,
          tween: Tween<double>(begin: progress - (1.0 / PlayerController.autoSkipCountdownSeconds), end: progress),
          builder: (context, value, _) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(color: fillColor),
              ),
            );
          },
        );
      }),
    );
  }
}

// _buildLayout lives back in _BottomControlsState — it accesses _leftButtonIds etc.
extension _BottomControlsStateLayout on _BottomControlsState {
  Widget _buildLayout(BuildContext context) {
    final controller = Get.find<PlayerController>();
    final theme = context.theme;
    final isDark = theme.brightness == Brightness.dark;

    // Use the cached config — no JSON decode on every rebuild.
    final List<String> leftButtonIds = _leftButtonIds;
    final List<String> rightButtonIds = _rightButtonIds;
    final Map<String, dynamic> buttonConfigs = _buttonConfigs;

    bool isVisible(String id) =>
        (buttonConfigs[id]?['visible'] as bool?) ?? true;

    final serverCount = controller.episodeTracks.length;

    final Map<String, Widget> buttonWidgets = {
      'playlist': ControlButton(
        icon: Icons.playlist_play_rounded,
        onPressed: () {
          controller.isEpisodePaneOpened.value =
              !controller.isEpisodePaneOpened.value;
        },
        tooltip: 'Playlist',
        compact: true,
      ),
      'shaders': ControlButton(
        icon: Icons.tune_rounded,
        onPressed: () => controller.openColorProfileBottomSheet(context),
        tooltip: 'Shaders & Color Profiles',
        compact: true,
      ),
      'source': ControlButton(
        icon: Icons.cloud_rounded,
        onPressed: () {
          controller.isSourcePaneOpened.value =
              !controller.isSourcePaneOpened.value;
        },
        tooltip: 'Source',
        compact: true,
      ),
      'tracks': ControlButton(
        icon: Icons.library_music_rounded,
        onPressed: () {
          controller.isTracksPaneOpened.value =
              !controller.isTracksPaneOpened.value;
        },
        tooltip: 'Tracks',
        compact: true,
      ),
      'sync_subs': ControlButton(
        icon: Icons.sync_rounded,
        onPressed: () {
          controller.isSyncSubsPaneOpened.value =
              !controller.isSyncSubsPaneOpened.value;
        },
        tooltip: 'Sync Subtitles',
        compact: true,
      ),
      'speed': ControlButton(
        icon: Icons.speed_rounded,
        onPressed: () {
          controller.isSpeedPaneOpened.value =
              !controller.isSpeedPaneOpened.value;
        },
        tooltip: 'Speed',
        compact: true,
      ),
      'orientation': Obx(() {
        final autoRotate = controller.isLandscapeAutoRotateEnabled.value;
        return ControlButton(
          icon: autoRotate
              ? Icons.screen_rotation_alt_rounded
              : Icons.screen_lock_rotation_rounded,
          onPressed: () => controller.toggleLandscapeAutoRotate(),
          tooltip: autoRotate ? 'Auto-rotate ON' : 'Auto-rotate OFF',
          compact: true,
        );
      }),
      'aspect_ratio': ControlButton(
        icon: Icons.fit_screen_rounded,
        onPressed: () => controller.toggleVideoFit(),
        onLongPress: controller.resetVideoFit,
        tooltip: 'Aspect Ratio',
        compact: true,
      ),
    };

    List<Widget> buildButtonList(List<String> ids) {
      final regularButtons = <Widget>[];
      final compactButtons = <Widget>[];

      for (var id in ids) {
        if (!isVisible(id)) continue;
        if (id == 'source' &&
            (controller.isOffline.value ||
                (serverCount <= 1 &&
                    controller.getCurrentStreamSubtitleOptions().isEmpty)))
          continue;
        if (id == 'tracks' &&
            (controller.embeddedAudioTracks.value.isEmpty &&
                controller.embeddedSubs.value.isEmpty)) continue;
        if (id == 'orientation' && !(Platform.isAndroid || Platform.isIOS)) {
          continue;
        }

        final widget = buttonWidgets[id];
        if (widget != null) {
          if ((widget is ControlButton && widget.compact) || id == 'orientation') {
            compactButtons.add(widget);
          } else {
            regularButtons.add(widget);
          }
        }
      }

      if (compactButtons.isNotEmpty) {
        regularButtons.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceVariant.opaque(0.2)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? theme.colorScheme.outline.opaque(0.15)
                    : theme.colorScheme.outline.opaque(0.3),
                width: 0.5,
              ),
            ),
            child:
                Row(mainAxisSize: MainAxisSize.min, children: compactButtons),
          ),
        );
      }
      return regularButtons;
    }

    final leftButtons = buildButtonList(leftButtonIds);
    final rightButtons = buildButtonList(rightButtonIds);

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 20, 5),
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildSkipButton(context),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            child: const ProgressSlider(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceVariant.opaque(0.3)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? theme.colorScheme.outline.opaque(0.2)
                          : theme.colorScheme.outline.opaque(0.4),
                      width: 0.5,
                    ),
                  ),
                  child: RepaintBoundary(
                    child: Obx(() => Text(
                          controller.formattedCurrentPosition,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        )),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceVariant.opaque(0.3)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? theme.colorScheme.outline.opaque(0.2)
                          : theme.colorScheme.outline.opaque(0.4),
                      width: 0.5,
                    ),
                  ),
                  child: RepaintBoundary(
                    child: Obx(() => Text(
                          controller.formattedEpisodeDuration,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        )),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...leftButtons,
                  if (leftButtons.isNotEmpty && rightButtons.isNotEmpty)
                    const SizedBox(width: 16),
                  ...rightButtons,
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 20, 5),
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildSkipButton(context),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
          child: const ProgressSlider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceVariant.opaque(0.3)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? theme.colorScheme.outline.opaque(0.2)
                            : theme.colorScheme.outline.opaque(0.4),
                        width: 0.5,
                      ),
                    ),
                    child: RepaintBoundary(
                      child: Obx(() => Text(
                            controller.formattedCurrentPosition,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          )),
                    ),
                  ),
                  if (leftButtons.isNotEmpty) const SizedBox(width: 16),
                  ...leftButtons,
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  ...rightButtons,
                  if (rightButtons.isNotEmpty) const SizedBox(width: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceVariant.opaque(0.3)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? theme.colorScheme.outline.opaque(0.2)
                            : theme.colorScheme.outline.opaque(0.4),
                        width: 0.5,
                      ),
                    ),
                    child: RepaintBoundary(
                      child: Obx(() => Text(
                            controller.formattedEpisodeDuration,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          )),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
