import 'package:anymex/controllers/settings/methods.dart';
import 'package:anymex/screens/library/widgets/history_model.dart';
import 'package:anymex/utils/theme_extensions.dart';
import 'package:anymex/widgets/custom_widgets/anymex_image.dart';
import 'package:anymex/widgets/custom_widgets/custom_expansion_tile.dart';
import 'package:anymex/widgets/custom_widgets/custom_text.dart';
import 'package:anymex/widgets/helper/tv_wrapper.dart';
import 'package:flutter/material.dart';

class ContinueWatchingCard extends StatelessWidget {
  final HistoryModel media;
  final VoidCallback? onRemove;
  final VoidCallback? onLongPress;

  const ContinueWatchingCard({super.key, required this.media, this.onRemove, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colors;
    final imgUrl = media.cover.isEmpty ? media.poster : media.cover;

    return AnymexCard(
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: colorScheme.outline.opaque(0.1, iReallyMeanIt: true),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12.multiplyRadius()),
      ),
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainer.opaque(0.4),
      child: AnymexOnTap(
        onTap: media.onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12.multiplyRadius()),
                      topRight: Radius.circular(12.multiplyRadius()),
                    ),
                    child: AnymeXImage(
                      key: ValueKey(imgUrl),
                      imageUrl: imgUrl,
                      width: double.infinity,
                      radius: 0,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12.multiplyRadius()),
                        topRight: Radius.circular(12.multiplyRadius()),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.opaque(0.2, iReallyMeanIt: true),
                          Colors.black.opaque(0.7, iReallyMeanIt: true),
                        ],
                        stops: const [0.6, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
                if (onRemove != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              Colors.black.opaque(0.65, iReallyMeanIt: true),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),

                Positioned(
                  bottom: 12,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final badgeRaw = media.formattedEpisodeTitle ?? '';
                          final badgeText = badgeRaw.replaceAll(
                            RegExp(r'^(▶\s*)?(Episode|Chapter)\s*', caseSensitive: false),
                            '',
                          );
                          return Container(
                            constraints: const BoxConstraints(maxWidth: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.opaque(0.5, iReallyMeanIt: true),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.opaque(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: AnymexText(
                              text: badgeText,
                              size: 11,
                              maxLines: 1,
                              variant: TextVariant.bold,
                              color: colorScheme.onPrimary,
                              overflow: TextOverflow.ellipsis,
                              isMarquee: false,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    year2023: false,
                    value: media.calculatedProgress,
                    backgroundColor: Colors.white.opaque(0.2),
                    color: colorScheme.primary,
                    minHeight: 3,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnymexText(
                          text: media.progressTitle ?? media.title!,
                          size: 13,
                          maxLines: 1,
                          variant: TextVariant.bold,
                          overflow: TextOverflow.ellipsis,
                          isMarquee: true,
                        ),
                        if (media.title != null &&
                            media.title != media.progressTitle)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: AnymexText(
                              text: media.title!,
                              size: 11,
                              maxLines: 1,
                              variant: TextVariant.regular,
                              color: colorScheme.onSurface.opaque(0.6),
                              overflow: TextOverflow.ellipsis,
                              isMarquee: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AnymexText(
                      text: media.progressText!,
                      size: 11,
                      color: colorScheme.primary,
                      variant: TextVariant.bold,
                    ),
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
