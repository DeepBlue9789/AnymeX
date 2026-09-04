import 'dart:async';

import 'package:anymex/utils/function.dart';
import 'package:anymex/widgets/custom_widgets/anymex_animated_logo.dart';
import 'package:anymex/widgets/custom_widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:anymex/utils/theme_extensions.dart';
import 'package:get/get.dart';

class AnymexToast {
  static SnackbarController? _activeSnackbar;

  static void show({
    required String message,
    Duration duration = const Duration(seconds: 2),
    bool showIcon = true,
  }) {
    final context = Get.context;
    if (context == null) return;

    final activeSnackbar = _activeSnackbar;
    if (activeSnackbar != null) {
      unawaited(activeSnackbar.close(withAnimations: false));
      _activeSnackbar = null;
    }

    final colorScheme = context.colors;

    final controller = Get.showSnackbar(
      GetSnackBar(
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
        duration: duration,
        onTap: (_) {
          Get.closeCurrentSnackbar();
        },
        messageText: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.opaque(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showIcon) ...[
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.opaque(0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: AnymeXAnimatedLogo(
                          size: 28,
                          autoPlay: true,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    12.width(),
                  ],
                  Flexible(
                    child: AnymexText(
                      text: message,
                      size: 13,
                      color: colorScheme.onSurface,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    _activeSnackbar = controller;
    unawaited(
      controller.future.whenComplete(() {
        if (identical(_activeSnackbar, controller)) {
          _activeSnackbar = null;
        }
      }),
    );
  }
}
