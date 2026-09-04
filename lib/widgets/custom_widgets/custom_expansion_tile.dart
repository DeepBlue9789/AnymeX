import 'package:anymex/controllers/settings/settings.dart';
import 'package:anymex/utils/theme_extensions.dart';
import 'package:anymex/widgets/custom_widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:anymex/widgets/common/custom_tiles.dart';

class AnymexExpansionTile extends StatelessWidget {
  final String title;
  final Widget content;
  final bool initialExpanded;
  final Widget? leading;

  const AnymexExpansionTile({
    super.key,
    required this.title,
    required this.content,
    this.initialExpanded = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final highlightProvider = SettingsHighlightProvider.of(context);
    final shouldExpand =
        initialExpanded || (highlightProvider?.expansionTitle == title);

    return AnymexCard(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
        leading: leading,
        title: AnymexText(
          text: title,
          size: 15,
          variant: TextVariant.semiBold,
          color: context.colors.primary,
        ),
        initiallyExpanded: shouldExpand,
        childrenPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        children: [
          ExpansionSectionScope(sectionTitle: title, child: content),
        ],
      ),
    );
  }
}

class AnymexCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool enableAnimation;
  final Color? color;
  final ShapeBorder? shape;
  final Clip? clipBehavior;

  const AnymexCard({
    super.key,
    required this.child,
    this.padding,
    this.enableAnimation = false,
    this.color,
    this.shape,
    this.clipBehavior,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<Settings>();
    return Card(
      clipBehavior: clipBehavior,
      color: color ??
          (settings.disableGradient
              ? context.colors.surfaceContainerLow
              : context.colors.surfaceContainerLow.opaque(0.3)),
      elevation: 2,
      shadowColor: context.colors.shadow.opaque(0.1),
      shape: shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: enableAnimation
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: padding ?? const EdgeInsets.all(0.0),
              child: child,
            )
          : Padding(
              padding: padding ?? const EdgeInsets.all(0.0),
              child: child,
            ),
    );
  }
}
