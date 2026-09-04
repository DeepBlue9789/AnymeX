import 'dart:ui';

import 'package:anymex/database/isar_models/episode.dart';
import 'package:anymex/utils/string_extensions.dart';
import 'package:anymex/utils/theme_extensions.dart';
import 'package:anymex/widgets/animation/animations.dart';
import 'package:anymex/widgets/custom_widgets/custom_text.dart';
import 'package:anymex/widgets/custom_widgets/anymex_image.dart';
import 'package:flutter/material.dart';

enum EpisodeLayoutType {
  compact,
  detailed,
}

class BetterEpisode extends StatelessWidget {
  final Episode episode;
  final bool isSelected;
  final EpisodeLayoutType layoutType;
  final String? fallbackImageUrl;
  final List<Episode>? offlineEpisodes;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BetterEpisode({
    super.key,
    required this.episode,
    this.isSelected = false,
    this.layoutType = EpisodeLayoutType.compact,
    this.fallbackImageUrl,
    this.offlineEpisodes,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final episodeProgress = _calculateProgress();
    final isFiller = episode.filler ?? false;
    final hasProgress = episodeProgress > 0.0 && episodeProgress <= 1.0;

    return StaggeredAnimatedItemWrapper(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: layoutType == EpisodeLayoutType.compact
            ? _buildCompactLayout(
                context, episodeProgress, isFiller, hasProgress)
            : _buildDetailedLayout(
                context, episodeProgress, isFiller, hasProgress),
      ),
    );
  }


  String get episodeNumber => episode.number.contains('.0') ? episode.number.toInt().toString() : episode.number.toString();

  String get episodeTitle => episode.title ?? 'Episode $episodeNumber'; 


  double _calculateProgress() {
    if (offlineEpisodes == null) return 0.0;

    final savedEP = offlineEpisodes!.cast<Episode?>().firstWhere(
          (e) => e?.number == episode.number,
          orElse: () => null,
        );

    if (savedEP?.timeStampInMilliseconds != null &&
        savedEP?.durationInMilliseconds != null &&
        savedEP!.durationInMilliseconds! > 0) {
      return savedEP.timeStampInMilliseconds! / savedEP.durationInMilliseconds!;
    }

    return 0.0;
  }

  Color _getBackgroundColor(BuildContext context, bool isFiller) {
    final theme = Theme.of(context);

    if (isSelected) {
      return theme.colorScheme.primary.opaque(0.4, iReallyMeanIt: true);
    } else if (isFiller) {
      return Colors.orange.withOpacity(0.15);
    } else {
      return theme.colorScheme.secondaryContainer.opaque(
        layoutType == EpisodeLayoutType.compact ? 0.4 : 0.5,
      );
    }
  }

  String get _imageUrl {
    return episode.thumbnail ?? fallbackImageUrl ?? '';
  }

  Widget _buildCompactLayout(
    BuildContext context,
    double progress,
    bool isFiller,
    bool hasProgress,
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      height: 75,
      decoration: BoxDecoration(
        color: _getBackgroundColor(context, isFiller),
        borderRadius: BorderRadius.circular(12),
        border:
            isFiller ? Border.all(color: Colors.orange.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 75,
            child: _buildImageSection(context, progress, hasProgress, isCompact: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFiller)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 2.0),
                    child: AnymexText(
                      text: "[Filler]",
                      size: 10,
                      color: Colors.orange,
                      variant: TextVariant.bold,
                    ),
                  ),
                AnymexText(
                  text: episodeTitle,
                  variant: TextVariant.bold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  isMarquee: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedLayout(
    BuildContext context,
    double progress,
    bool isFiller,
    bool hasProgress,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _getBackgroundColor(context, isFiller),
        borderRadius: BorderRadius.circular(12),
        border:
            isFiller ? Border.all(color: Colors.orange.withOpacity(0.3)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            height: 80,
            child: _buildImageSection(context, progress, hasProgress),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (isFiller)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.5))),
                      child: const AnymexText(
                        text: "FILLER",
                        size: 10,
                        color: Colors.orange,
                        variant: TextVariant.bold,
                      ),
                    ),
                  ),
                AnymexText(
                  text: episodeTitle,
                  variant: TextVariant.bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  isMarquee: true,
                ),
                const SizedBox(height: 4),
                _buildDescription(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(
    BuildContext context,
    double progress,
    bool hasProgress, {
    bool isCompact = false,
  }) {
    const imageWidth = 130.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _OptimizedNetworkImage(
            imageUrl: _imageUrl,
            width: double.infinity,
            height: double.infinity,
            fallbackUrl: fallbackImageUrl,
          ),
        ),
        if (hasProgress) ...[
          _buildProgressIndicator(context, progress, imageWidth, isCompact),
          _buildWatchedIcon(context),
        ],
        _buildEpisodeNumberBadge(context),
      ],
    );
  }

  Widget _buildProgressIndicator(
    BuildContext context,
    double progress,
    double imageWidth,
    bool isCompact,
  ) {
    return Positioned(
      bottom: 0,
      left: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: context.colors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        height: isCompact ? 4 : 2,
        width: imageWidth * progress,
      ),
    );
  }

  Widget _buildWatchedIcon(BuildContext context) {
    return Positioned(
      top: 5,
      right: 5,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: context.colors.primary,
        ),
        child: Icon(
          Icons.remove_red_eye,
          color: context.colors.onPrimary,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildEpisodeNumberBadge(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black.opaque(0.2),
              border: Border.all(
                width: 2,
                color: context.colors.primary,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.opaque(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: AnymexText(
              text: "EP $episodeNumber",
              variant: TextVariant.bold,
              color: Colors.white,
              size: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    final description = episode.desc;
    final displayText = (description?.isEmpty ?? true)
        ? 'No Description Available'
        : description!;

    return _ExpandableDescription(displayText, context);
  }
}

class _ExpandableDescription extends StatefulWidget {
  final String description;
  final BuildContext context;
  const _ExpandableDescription(this.description, this.context);

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: 11,
      fontFamily: 'Poppins',
      fontStyle: FontStyle.italic,
      color: theme.colorScheme.inverseSurface.withOpacity(0.90),
    );
    final linkStyle = TextStyle(
      fontSize: 11,
      fontFamily: 'Poppins',
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.primary,
    );

    String displayText = widget.description;
    bool showToggle = false;

    if (widget.description.length > 110) {
      showToggle = true;
      if (!isExpanded) {
        displayText = '${widget.description.substring(0, 110).trim()}... ';
      } else {
        displayText = '${widget.description} ';
      }
    }

    return GestureDetector(
      onTap: showToggle ? () => setState(() => isExpanded = !isExpanded) : null,
      child: RichText(
        text: TextSpan(
          style: textStyle,
          children: [
            TextSpan(text: displayText),
            if (showToggle)
              TextSpan(
                text: isExpanded ? "Show less" : "Show more",
                style: linkStyle,
              ),
          ],
        ),
      ),
    );
  }
}

class _OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final String? fallbackUrl;

  const _OptimizedNetworkImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fallbackUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnymeXImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      radius: 0,
      errorImage: fallbackUrl,
    );
  }
}
