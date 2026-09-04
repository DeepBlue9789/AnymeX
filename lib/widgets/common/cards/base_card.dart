import 'package:anymex/models/models_convertor/carousel/carousel_data.dart';
import 'package:anymex/utils/function.dart';
import 'package:anymex/widgets/custom_widgets/custom_text.dart';
import 'package:anymex_extension_runtime_bridge/Models/Source.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

enum CardStyle { saikou, exotic, minimalExotic, modern, blur }

abstract class CarouselCard extends StatelessWidget {
  final CarouselData itemData;
  final String tag;

  const CarouselCard({
    super.key,
    required this.itemData,
    required this.tag,
  });

  bool isDesktop(context) => MediaQuery.of(context).size.width > 600;

  bool shouldShowTitle() {
    return itemData.title != null &&
        itemData.title!.isNotEmpty &&
        itemData.title != '?';
  }

  Widget buildCardTitle(bool isDesktop) {
    return SizedBox(
      height: 45,
      child: AnymexText(
        text: itemData.title ?? '?',
        maxLines: 2,
        size: isDesktop ? 14 : 11,
        variant: TextVariant.semiBold,
        overflow: TextOverflow.ellipsis,
        isMarquee: false,
      ),
    );
  }

  Widget buildCompactBadges(
      BuildContext context, DataVariant variant, ItemType type) {
    final theme = Theme.of(context);
    final isManga = type == ItemType.manga;

    return Stack(
      children: [
        if (itemData.episodes != null && itemData.episodes != '??')
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isManga ? Iconsax.book : Iconsax.play5,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 3),
                  AnymexText(
                    text: itemData.episodes!,
                    color: theme.colorScheme.onSurface,
                    size: 9,
                    variant: TextVariant.bold,
                  ),
                ],
              ),
            ),
          ),
        if (itemData.rating != null && itemData.rating != '??' && itemData.rating != '0.0')
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.star5,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 3),
                  AnymexText(
                    text: itemData.rating!,
                    color: theme.colorScheme.onSurface,
                    size: 9,
                    variant: TextVariant.bold,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }


  IconData getIconForVariant(
      String extraData, DataVariant variant, ItemType type) {
    switch (variant) {
      case DataVariant.anilist:
      case DataVariant.offline:
        return type == ItemType.manga ? Iconsax.book : Iconsax.play5;
      case DataVariant.library:
        return Iconsax.star5;
      case DataVariant.relation:
        if (extraData == "MANGA" || extraData == "ANIME") {
          return extraData == "MANGA" ? Iconsax.book : Iconsax.play5;
        }
        return type == ItemType.manga ? Iconsax.book5 : Iconsax.play5;
      case DataVariant.extension:
        return Iconsax.status;
      default:
        return Iconsax.star5;
    }
  }

  Widget? buildNextEpisodePill(BuildContext context) {
    final isContinueWatching = tag.toLowerCase().contains('continue');
    if (!isContinueWatching) return null;
    if (!itemData.releasing && itemData.nextAiringEpisode == null) return null;

    int? watched;
    int? released;

    if (itemData.episodes != null && itemData.episodes!.contains('|')) {
      final parts = itemData.episodes!.split('|');
      watched = int.tryParse(parts[0].trim());
      if (itemData.nextAiringEpisode != null) {
        released = itemData.nextAiringEpisode!.episode - 1;
      } else if (parts.length > 1) {
        released = int.tryParse(parts[1].trim());
      }
    } else {
      if (itemData.nextAiringEpisode != null) {
        released = itemData.nextAiringEpisode!.episode - 1;
      }
    }

    if (watched == null || released == null || released <= 0 || watched < released) {
      return null;
    }

    if (itemData.nextAiringEpisode == null || itemData.nextAiringEpisode!.airingAt <= 0) {
      return null;
    }

    final countdown = formatTimeUntilNextRelease(itemData.nextAiringEpisode!.airingAt);
    if (countdown == null || countdown.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnymexText(
        text: countdown,
        color: Colors.white,
        size: 10,
        variant: TextVariant.bold,
        isMarquee: false,
      ),
    );
  }
}

String? formatTimeUntilNextRelease(int airingAtInSeconds) {
  final nowInSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final diff = airingAtInSeconds - nowInSeconds;
  if (diff <= 0) return null;

  final duration = Duration(seconds: diff);
  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;

  if (days > 0) {
    if (hours > 0) return '${days}d${hours}h';
    if (minutes > 0) return '${days}d${minutes}m';
    return '${days}d';
  }
  if (hours > 0) {
    if (minutes > 0) return '${hours}h${minutes}m';
    return '${hours}h';
  }
  if (minutes > 0) {
    return '${minutes}m';
  }
  return '1m';
}
