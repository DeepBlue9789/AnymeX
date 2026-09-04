import 'dart:math';
import 'package:flutter/widgets.dart';

class PlayerUtils {
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");

    if (duration.inHours < 1) {
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return "$minutes:$seconds";
    }

    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  static bool isInGestureSafeZone(
    BuildContext context,
    Offset position, {
    bool enableSafeZones = true,
    double margin = 40.0,
  }) {
    if (!enableSafeZones) return false;

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return false;

    final size = mediaQuery.size;
    final viewPadding = mediaQuery.viewPadding;
    final padding = mediaQuery.padding;

    final effectiveTopPadding = max(viewPadding.top, padding.top);
    final effectiveBottomPadding = max(viewPadding.bottom, padding.bottom);
    final effectiveLeftPadding = max(viewPadding.left, padding.left);
    final effectiveRightPadding = max(viewPadding.right, padding.right);

    final topSafeZone =
        max(effectiveTopPadding + 8.0, margin + 8.0).clamp(margin, 90.0);
    final bottomSafeZone =
        max(effectiveBottomPadding + 8.0, margin + 8.0).clamp(margin, 90.0);
    final leftSafeZone =
        max(effectiveLeftPadding + 8.0, margin).clamp(margin * 0.75, 70.0);
    final rightSafeZone =
        max(effectiveRightPadding + 8.0, margin).clamp(margin * 0.75, 70.0);

    if (position.dy < topSafeZone) return true;
    if (position.dy > size.height - bottomSafeZone) return true;
    if (position.dx < leftSafeZone) return true;
    if (position.dx > size.width - rightSafeZone) return true;

    return false;
  }
}

