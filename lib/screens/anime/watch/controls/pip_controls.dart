import 'dart:io';

import 'package:anymex/screens/anime/watch/controller/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Minimal controls overlay shown when the player is in PIP mode.
/// Shows play/pause, +85s skip, and subtitles scaled to the PIP window.
class PipControls extends StatelessWidget {
  final PlayerController controller;

  const PipControls({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    // Scale subtitle font relative to PIP window width (baseline ~400px full screen)
    final scaleFactor = (size.width / 400.0).clamp(0.4, 1.0);
    final subtitleFontSize = (14.0 * scaleFactor).clamp(8.0, 14.0);
    final iconSize = (28.0 * scaleFactor).clamp(16.0, 28.0);

    return Obx(() {
      if (!controller.isPipMode.value) return const SizedBox.shrink();

      return Stack(
        children: [
          // Subtitle overlay — scales with PIP window size
          Positioned(
            bottom: iconSize + 16,
            left: 8,
            right: 8,
            child: _PipSubtitle(
              controller: controller,
              fontSize: subtitleFontSize,
            ),
          ),

          // Controls row (play/pause and +85s skip)
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Play/Pause
                Obx(() => _PipIconButton(
                      icon: controller.isPlaying.value
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: iconSize,
                      onTap: () => controller.togglePlayPause(),
                    )),

                // +85s skip button
                _PipIconButton(
                  icon: Icons.forward_30_rounded,
                  size: iconSize,
                  onTap: () => controller.megaSeek(85),
                  label: '+85s',
                  labelSize: (subtitleFontSize - 2).clamp(6.0, 12.0),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _PipSubtitle extends StatelessWidget {
  final PlayerController controller;
  final double fontSize;

  const _PipSubtitle({required this.controller, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lines = controller.subtitleText.value;
      if (lines.isEmpty) return const SizedBox.shrink();

      final text = lines.join('\n');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            height: 1.3,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1)),
            ],
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      );
    });
  }
}

class _PipIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final String? label;
  final double? labelSize;

  const _PipIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.label,
    this.labelSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        child: label != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: size * 0.8),
                  Text(
                    label!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: labelSize ?? 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
