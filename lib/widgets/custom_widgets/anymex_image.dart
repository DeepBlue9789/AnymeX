import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anymex/controllers/services/storage/anymex_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:anymex/utils/theme_extensions.dart';

bool isLocalFile(String value) {
  if (value.isEmpty) return false;
  if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('data:image')) {
    return false;
  }
  return value.startsWith('/') || value.startsWith('file://') || RegExp(r'^[a-zA-Z]:\\').hasMatch(value);
}

bool isBase64Image(String value) {
  if (value.isEmpty) return false;
  if (value.startsWith('data:image')) return true;
  if (value.length > 1000) return true;
  if (isLocalFile(value)) return false;
  if (value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('assets/')) {
    return false;
  }
  return RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(value.trim());
}

Uint8List base64ToBytes(String base64) {
  try {
    final cleaned = (base64.contains(',') ? base64.split(',').last : base64)
        .replaceAll(RegExp(r'\s+'), '');
    return base64Decode(cleaned);
  } catch (e) {
    debugPrint("Error decoding base64 image: $e");
    return Uint8List(0);
  }
}

class AnymeXImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final Alignment alignment;
  final Color? color;
  final String? errorImage;
  final ValueChanged<Color>? onColorExtracted;
  final Map<String, String>? headers;
  final Duration? fadeInDuration;
  final Duration? fadeOutDuration;

  const AnymeXImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.radius = 8,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.color,
    this.errorImage,
    this.onColorExtracted, 
    this.headers,
    this.fadeInDuration,
    this.fadeOutDuration,
  });

  static Widget heroFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final fromHero = fromHeroContext.widget as Hero;
    final toHero = toHeroContext.widget as Hero;
    final heroContext = flightDirection == HeroFlightDirection.push
        ? fromHeroContext
        : toHeroContext;
    final hero =
        flightDirection == HeroFlightDirection.push ? fromHero : toHero;

    return InheritedTheme.captureAll(
      heroContext,
      Material(
        type: MaterialType.transparency,
        child: hero.child,
      ),
    );
  }

  @override
  State<AnymeXImage> createState() => _AnymeXImageState();
}

class _AnymeXImageState extends State<AnymeXImage> {
  Uint8List? _cachedBytes;
  Color? _extractedColor;

  @override
  void initState() {
    super.initState();
    _handleImageChange();
  }

  @override
  void didUpdateWidget(AnymeXImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _handleImageChange();
    }
  }

  void _handleImageChange() {
    final isBase64 = isBase64Image(widget.imageUrl);
    if (isBase64) {
      final bytes = base64ToBytes(widget.imageUrl);
      _cachedBytes = bytes.isNotEmpty ? bytes : null;
    } else {
      _cachedBytes = null;
    }
    _extractedColor = null;

    if (widget.onColorExtracted != null && _cachedBytes != null) {
      _extractDominantColor(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBase64 = _cachedBytes != null;
    final isLocal = !isBase64 && isLocalFile(widget.imageUrl);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: isBase64
            ? Image.memory(
                _cachedBytes!,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                alignment: widget.alignment,
                color: widget.color,
                colorBlendMode: widget.color != null ? BlendMode.color : null,
                errorBuilder: (_, __, ___) => _fallback(context),
              )
            : isLocal
                ? Image.file(
                    File(widget.imageUrl.replaceFirst('file://', '')),
                    key: ValueKey('${widget.imageUrl}_${File(widget.imageUrl.replaceFirst('file://', '')).existsSync() ? File(widget.imageUrl.replaceFirst('file://', '')).lastModifiedSync().millisecondsSinceEpoch : 0}'),
                    width: widget.width,
                    height: widget.height,
                    fit: widget.fit,
                    alignment: widget.alignment,
                    color: widget.color,
                    colorBlendMode: widget.color != null ? BlendMode.color : null,
                    errorBuilder: (ctx, err, stack) {
                      debugPrint('[AnymeXImage Error] Failed to load local file: ${widget.imageUrl} | $err');
                      return _fallback(context);
                    },
                  )
                : CachedNetworkImage(
                cacheManager: AnymeXCacheManager.instance,
                imageUrl: widget.imageUrl,
                httpHeaders: widget.headers,
                width: widget.width,
                height: widget.height,
                memCacheWidth: widget.width != null && widget.width!.isFinite
                    ? (widget.width! * 2.5).toInt().clamp(80, 1920)
                    : (widget.height != null && widget.height!.isFinite
                        ? (widget.height! * 2.5 * (16 / 9)).toInt().clamp(80, 1920)
                        : null),
                memCacheHeight: null,
                fit: widget.fit,
                alignment: widget.alignment,
                color: widget.color,
                colorBlendMode: widget.color != null ? BlendMode.color : null,
                placeholder: (_, __) => _placeholder(context),
                fadeInDuration: widget.fadeInDuration ?? const Duration(milliseconds: 200),
                fadeOutDuration: widget.fadeOutDuration ?? const Duration(milliseconds: 150),
                errorWidget: (_, __, ___) {
                  if (widget.errorImage != null && widget.errorImage!.isNotEmpty) {
                    return CachedNetworkImage(
                      cacheManager: AnymeXCacheManager.instance,
                      imageUrl: widget.errorImage!,
                      width: widget.width,
                      height: widget.height,
                      fit: widget.fit,
                      placeholder: (_, __) => _placeholder(context),
                      fadeInDuration: widget.fadeInDuration ?? const Duration(milliseconds: 200),
                      fadeOutDuration: widget.fadeOutDuration ?? const Duration(milliseconds: 150),
                      errorWidget: (_, __, ___) => _fallback(context),
                    );
                  }
                  return _fallback(context);
                },
              ),
      ),
    );
  }

  Future<void> _extractDominantColor(bool isBase64) async {
    if (_extractedColor != null) return;
    try {
      ImageProvider imageProvider;

      if (isBase64) {
        imageProvider = MemoryImage(_cachedBytes!);
      } else if (isLocalFile(widget.imageUrl)) {
        imageProvider = FileImage(File(widget.imageUrl.replaceFirst('file://', '')));
      } else {
        imageProvider = CachedNetworkImageProvider(
          widget.imageUrl,
          cacheManager: AnymeXCacheManager.instance,
        );
      }

      final PaletteGenerator paletteGenerator =
          await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 10,
      );

      final dominantColor = paletteGenerator.dominantColor?.color ??
          paletteGenerator.vibrantColor?.color ??
          paletteGenerator.mutedColor?.color;

      if (dominantColor != null && mounted) {
        _extractedColor = dominantColor;
        widget.onColorExtracted?.call(dominantColor);
      }
    } catch (_) {}
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      alignment: Alignment.center,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .opaque(0.2),
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .opaque(0.3),
            context.colors.surfaceContainer.opaque(0.5),
          ],
        ),
      ),
      child: Center(
        child: Text(
          '(╥﹏╥)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .opaque(0.3),
              ),
        ),
      ),
    );
  }
}
