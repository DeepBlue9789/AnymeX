import 'package:anymex/controllers/settings/settings.dart';
import 'package:anymex/controllers/source/source_controller.dart';
import 'package:anymex/models/Media/media.dart';
import 'package:anymex/models/models_convertor/carousel/carousel_data.dart';
import 'package:anymex/screens/anime/details_page.dart';
import 'package:anymex/screens/manga/details_page.dart';
import 'package:anymex/screens/novel/details/details_view.dart';
import 'package:anymex/utils/function.dart';
import 'package:anymex/utils/theme_extensions.dart';
import 'package:anymex/widgets/animation/slide_scale.dart';
import 'package:anymex/widgets/common/cards/base_card.dart';
import 'package:anymex/widgets/common/cards/card_gate.dart';
import 'package:anymex/widgets/common/skeleton_loader.dart';
import 'package:anymex/widgets/custom_widgets/custom_text.dart';
import 'package:anymex/widgets/helper/platform_builder.dart';
import 'package:anymex/widgets/helper/tv_wrapper.dart';
import 'package:anymex/widgets/media_items/media_peek_popup.dart';
import 'package:anymex_extension_runtime_bridge/Models/Source.dart';
import 'package:anymex_extension_runtime_bridge/anymex_extension_runtime_bridge.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ReusableCarousel extends StatefulWidget {
  final List<dynamic> data;
  final String title;
  final ItemType type;
  final DataVariant variant;
  final bool isLoading;
  final Source? source;
  final CardStyle? cardStyle;

  const ReusableCarousel({
    super.key,
    required this.data,
    required this.title,
    this.type = ItemType.anime,
    this.variant = DataVariant.regular,
    this.isLoading = false,
    this.source,
    this.cardStyle,
  });

  @override
  State<ReusableCarousel> createState() => _ReusableCarouselState();
}

class _ReusableCarouselState extends State<ReusableCarousel> {
  @override
  Widget build(BuildContext context) {
    if (_isEmptyOrOffline) {
      return _buildOfflinePlaceholder();
    }

    if (widget.data.isEmpty && !widget.isLoading) {
      return const SizedBox.shrink();
    }

    if (widget.isLoading) {
      return CarouselSkeleton(title: widget.title, showSpinner: true);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderTitle(),
          const SizedBox(height: 10),
          _buildCarouselList(),
        ],
      ),
    );
  }

  bool get _isEmptyOrOffline =>
      widget.data.isEmpty && widget.variant == DataVariant.offline;

  Widget _buildHeaderTitle() {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0),
      child: AnymexText(
        text: widget.title,
        variant: TextVariant.semiBold,
        size: 17,
        color: context.colors.primary,
        isMarquee: true,
      ),
    );
  }

  Widget _buildOfflinePlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildHeaderTitle(),
        const SizedBox(height: 15, width: double.infinity),
        SizedBox(
          height: 280,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(widget.type != ItemType.anime
                  ? Iconsax.book
                  : Icons.movie_filter_rounded),
              const SizedBox(height: 10, width: double.infinity),
              AnymexText(
                text: widget.type != ItemType.anime
                    ? "For real, why aren't you reading yet? 📚"
                    : "Lowkey time for a binge sesh 🎬",
                variant: TextVariant.semiBold,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselList() {
    final List<CarouselData> processedData =
        convertData(widget.data, variant: widget.variant);
    final isContinueWatching = widget.title.toLowerCase().contains("continue");

    return Obx(() {
      final cardHeight = getCardHeight(
          CardStyle.values[settingsController.cardStyle], getPlatform(context));

      if (isContinueWatching) {
        return SizedBox(
          height: (cardHeight * 2) + 25, // 2 rows + padding/spacing
          child: GridView.builder(
            itemCount: processedData.length,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 15, top: 5, bottom: 10),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: cardHeight *
                  0.7, // Estimate a reasonable width for grid items
            ),
            itemBuilder: (context, index) =>
                _buildCarouselItem(processedData[index], index),
          ),
        );
      }

      return SizedBox(
        height: cardHeight,
        child: SuperListView.builder(
          itemCount: processedData.length,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 15, top: 5, bottom: 10),
          itemBuilder: (context, index) =>
              _buildCarouselItem(processedData[index], index),
        ),
      );
    });
  }

  Widget _buildCarouselItem(CarouselData itemData, int index) {
    final tag = '${widget.title}-${itemData.id}';
    final isContinueWatching = widget.title.toLowerCase().contains('continue');

    return Obx(() {
      final card = settingsController.enableAnimation
          ? SlideAndScaleAnimation(child: _buildCard(itemData, tag))
          : _buildCard(itemData, tag);

      Widget child = AnymexOnTap(
        onTap: () => _navigateToDetailsPage(itemData, tag),
        child: GestureDetector(
          onLongPress: () => widget.type == ItemType.novel
              ? {}
              : _showPeekPopup(context, itemData, tag),
          child: card,
        ),
      );

      // Glow when 1-2 episodes remain in Continue Watching
      if (isContinueWatching) {
        final remaining = _computeRemainingEpisodes(itemData.episodes);
        if (remaining != null && remaining > 0 && remaining <= 2) {
          // Tweak these values to independently control the horizontal and vertical glow sizes
          // Negative values shrink the glow on that axis, positive values expand it.
          const double horizontalGlowSpread = -3.0;
          const double verticalGlowSpread = 1.0;

          child = Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              // Shadow casting layer
              Positioned(
                left: -horizontalGlowSpread,
                right: -horizontalGlowSpread,
                top: -verticalGlowSpread,
                bottom: -verticalGlowSpread,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.primary.withOpacity(0.65),
                        blurRadius: 5.0,
                        spreadRadius: 0.5,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                ),
              ),
              // Actual card content
              child,
            ],
          );
        }
      }

      return child;
    });
  }

  /// Parses `"watched | total"` episode strings like `"12 | 24"`.
  /// Returns (total - watched) if parseable, otherwise null.
  int? _computeRemainingEpisodes(String? episodes) {
    if (episodes == null || episodes.isEmpty) return null;
    final parts = episodes.split('|');
    if (parts.length < 2) return null;
    final watched = int.tryParse(parts[0].trim());
    final total = int.tryParse(parts[1].trim());
    if (watched == null || total == null || total <= 0) return null;
    return (total - watched).clamp(0, total);
  }

  void _showPeekPopup(BuildContext context, CarouselData itemData, String tag) {
    final bool isMediaManga = _determineIfManga(itemData);
    final ItemType mediaType = isMediaManga ? ItemType.manga : ItemType.anime;
    final media = Media.fromCarouselData(itemData, mediaType);
    if (media.userStatus != null && media.userStatus!.isNotEmpty) return;
    MediaPeekPopup.show(context, media, mediaType, tag);
  }

  MediaCardGate _buildCard(CarouselData itemData, String tag) {
    return MediaCardGate(
        itemData: itemData,
        tag: tag,
        variant: widget.variant,
        type: widget.type,
        cardStyle: CardStyle.values[settingsController.cardStyle]);
  }

  void _navigateToDetailsPage(CarouselData itemData, String tag) {
    final controller = Get.find<SourceController>();
    bool isMediaManga = _determineIfManga(itemData);
    if (widget.variant == DataVariant.recommendation) {
      isMediaManga = widget.type == ItemType.manga;
    }
    final ItemType mediaType = isMediaManga ? ItemType.manga : ItemType.anime;
    final media = Media.fromCarouselData(itemData, mediaType);

    void onTapHandler() {
      if (mediaType == ItemType.novel || widget.type == ItemType.novel) {
        final source =
            widget.source ?? sourceController.installedNovelExtensions.first;
        navigateWithAnimation(() => NovelDetailsPage(
              media: media,
              tag: tag,
              source: source,
            ));
      } else if (mediaType == ItemType.manga) {
        navigateWithAnimation(() => MangaDetailsPage(
              media: media,
              tag: tag,
            ));
      } else {
        final isContinueWatching = widget.title == "Continue Watching";
        navigateWithAnimation(() => AnimeDetailsPage(
              media: media,
              tag: tag,
              initialTabIndex: isContinueWatching ? 1 : 0,
            ));
      }
    }

    _setActiveSource(controller, itemData);
    onTapHandler();
  }

  bool _determineIfManga(CarouselData itemData) {
    return (widget.variant == DataVariant.relation &&
            itemData.source == "MANGA") ||
        (widget.source?.itemType == ItemType.manga) ||
        widget.type == ItemType.manga;
  }

  void _setActiveSource(SourceController controller, CarouselData itemData) {
    if (widget.source != null) {
      controller.setActiveSource(widget.source!);
    } else if (itemData.source != null) {
      if (widget.type == ItemType.manga) {
        controller.getMangaExtensionByName(itemData.source!);
      } else {
        controller.getExtensionByValue(itemData.source!);
      }
    }
  }
}
