import 'package:anymex/controllers/settings/methods.dart';
import 'package:anymex/utils/function.dart';
import 'package:anymex/utils/theme_extensions.dart';
import 'package:anymex/widgets/common/cards/base_card.dart';
import 'package:anymex/widgets/custom_widgets/anymex_image.dart';
import 'package:anymex/widgets/custom_widgets/custom_text.dart';
import 'package:anymex_extension_runtime_bridge/Models/Source.dart';
import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class SaikouCard extends CarouselCard {
  final DataVariant variant;
  final ItemType type;

  const SaikouCard({
    super.key,
    required super.itemData,
    required super.tag,
    required this.variant,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      constraints: BoxConstraints(maxWidth: isDesktop(context) ? 150 : 108),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardImage(context),
          if (shouldShowTitle()) ...[
            const SizedBox(height: 10),
            buildCardTitle(isDesktop(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildCardImage(BuildContext context) {
    final nextPill = buildNextEpisodePill(context);
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.multiplyRoundness()),
        child: Stack(
          children: [
            Hero(
              tag: tag,
              transitionOnUserGestures: true,
              flightShuttleBuilder: AnymeXImage.heroFlightShuttleBuilder,
              child: AnymeXImage(
                imageUrl: itemData.poster!,
                radius: 12,
                height: double.infinity,
                width: double.infinity,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
              ),
            ),
            buildCompactBadges(context, variant, type),
            if (variant == DataVariant.library) buildProgress(context, variant),
            if (nextPill != null)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(child: nextPill),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildProgress(BuildContext context, DataVariant variant) {
    final theme = Theme.of(context);

    return Positioned(
      top: 0,
      left: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.play5,
              size: 16,
              color: theme.colorScheme.onPrimary,
            ),
            const SizedBox(width: 4),
            AnymexText(
              text: itemData.source ?? '',
              color: theme.colorScheme.onPrimary,
              size: 12,
              variant: TextVariant.bold,
            ),
          ],
        ),
      ),
    );
  }
}

class ModernCard extends CarouselCard {
  final DataVariant variant;
  final ItemType type;

  const ModernCard({
    super.key,
    required super.itemData,
    required super.tag,
    required this.variant,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final nextPill = buildNextEpisodePill(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      constraints: BoxConstraints(maxWidth: isDesktop(context) ? 150 : 108),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.multiplyRoundness()),
        child: Stack(
          children: [
            Hero(
              tag: tag,
              transitionOnUserGestures: true,
              flightShuttleBuilder: AnymeXImage.heroFlightShuttleBuilder,
              child: AnymeXImage(
                imageUrl: itemData.poster!,
                radius: 12,
                height: double.infinity,
                width: double.infinity,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
              ),
            ),
            if (shouldShowTitle())
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.opaque(0.5, iReallyMeanIt: true),
                        Colors.black.opaque(0.7, iReallyMeanIt: true),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (nextPill != null) ...[
                        nextPill,
                        const SizedBox(height: 4),
                      ],
                      AnymexText(
                        text: itemData.title ?? '?',
                        maxLines: 2,
                        size: isDesktop(context) ? 14 : 12,
                        variant: TextVariant.semiBold,
                        overflow: TextOverflow.ellipsis,
                        color: Colors.white,
                        isMarquee: false,
                      ),
                    ],
                  ),
                ),
              )
            else if (nextPill != null)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(child: nextPill),
              ),
            buildCompactBadges(context, variant, type),
          ],
        ),
      ),
    );
  }
}

class ExoticCard extends CarouselCard {
  final DataVariant variant;
  final ItemType type;

  const ExoticCard({
    super.key,
    required super.itemData,
    required super.tag,
    required this.variant,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.colors.primary;
    final nextPill = buildNextEpisodePill(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      constraints: BoxConstraints(maxWidth: isDesktop(context) ? 160 : 118),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.multiplyRoundness()),
        boxShadow: [
          BoxShadow(
            color: primaryColor.opaque(0.15, iReallyMeanIt: true),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.multiplyRoundness()),
                border: Border.all(
                  color: primaryColor.opaque(0.3, iReallyMeanIt: true),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.multiplyRoundness()),
                child: Stack(
                  children: [
                    Hero(
                      tag: tag,
                      transitionOnUserGestures: true,
                      flightShuttleBuilder: AnymeXImage.heroFlightShuttleBuilder,
                      child: AnymeXImage(
                        imageUrl: itemData.poster!,
                        radius: 10,
                        height: double.infinity,
                        width: double.infinity,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                      ),
                    ),
                    buildCompactBadges(context, variant, type),
                    if (nextPill != null)
                      Positioned(
                        bottom: 6,
                        left: 0,
                        right: 0,
                        child: Center(child: nextPill),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (shouldShowTitle()) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnymexText(
                text: itemData.title ?? '?',
                maxLines: 1,
                size: isDesktop(context) ? 14 : 12,
                variant: TextVariant.semiBold,
                overflow: TextOverflow.ellipsis,
                isMarquee: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MinimalExoticCard extends CarouselCard {
  final DataVariant variant;
  final ItemType type;

  const MinimalExoticCard({
    super.key,
    required super.itemData,
    required super.tag,
    required this.variant,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.colors.primary;
    final nextPill = buildNextEpisodePill(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      constraints: BoxConstraints(maxWidth: isDesktop(context) ? 160 : 118),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.multiplyRoundness()),
        boxShadow: [
          BoxShadow(
            color: primaryColor.opaque(0.15, iReallyMeanIt: true),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.multiplyRoundness()),
                border: Border.all(
                  color: primaryColor.opaque(0.3, iReallyMeanIt: true),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.multiplyRoundness()),
                child: Stack(
                  children: [
                    Hero(
                      tag: tag,
                      transitionOnUserGestures: true,
                      flightShuttleBuilder: AnymeXImage.heroFlightShuttleBuilder,
                      child: AnymeXImage(
                        imageUrl: itemData.poster!,
                        radius: 10,
                        height: double.infinity,
                        width: double.infinity,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                      ),
                    ),
                    buildCompactBadges(context, variant, type),
                    if (shouldShowTitle())
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.opaque(0.5, iReallyMeanIt: true),
                                Colors.black.opaque(0.7, iReallyMeanIt: true),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (nextPill != null) ...[
                                nextPill,
                                const SizedBox(height: 4),
                              ],
                              AnymexText(
                                text: itemData.title ?? '?',
                                maxLines: 2,
                                size: isDesktop(context) ? 14 : 12,
                                variant: TextVariant.semiBold,
                                overflow: TextOverflow.ellipsis,
                                color: Colors.white,
                                isMarquee: false,
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (nextPill != null)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(child: nextPill),
                      ),
                  ],
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}

class BlurCard extends CarouselCard {
  final DataVariant variant;
  final ItemType type;

  const BlurCard({
    super.key,
    required super.itemData,
    required super.tag,
    required this.variant,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final nextPill = buildNextEpisodePill(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      constraints: BoxConstraints(maxWidth: isDesktop(context) ? 150 : 108),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.multiplyRoundness()),
        child: Stack(
          children: [
            Hero(
              tag: tag,
              transitionOnUserGestures: true,
              flightShuttleBuilder: AnymeXImage.heroFlightShuttleBuilder,
              child: AnymeXImage(
                imageUrl: itemData.poster!,
                radius: 12,
                height: double.infinity,
                width: double.infinity,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
              ),
            ),
            if (shouldShowTitle()) ...[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                    height: 50,
                    child: Blur(
                        blur: 5,
                        blurColor: context.colors.primary,
                        colorOpacity: 0.3,
                        child: Container())),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (nextPill != null) ...[
                        nextPill,
                        const SizedBox(height: 4),
                      ],
                      AnymexText(
                        text: itemData.title ?? '?',
                        maxLines: 2,
                        size: isDesktop(context) ? 14 : 12,
                        variant: TextVariant.semiBold,
                        overflow: TextOverflow.ellipsis,
                        color: Colors.white,
                        isMarquee: false,
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (nextPill != null)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(child: nextPill),
              ),
            buildCompactBadges(context, variant, type),
          ],
        ),
      ),
    );
  }
}
