import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AnymexSkeleton extends StatelessWidget {
  final Widget child;

  const AnymexSkeleton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      highlightColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
      child: child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        shape: shape,
      ),
    );
  }
}

class CarouselSkeleton extends StatelessWidget {
  final String title;
  final bool showSpinner;
  
  const CarouselSkeleton({
    super.key,
    required this.title,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    final isContinueWatching = title.toLowerCase().contains("continue");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AnymexSkeleton(
                  child: SkeletonBox(
                    width: 140,
                    height: 22,
                    borderRadius: 6,
                  ),
                ),
                if (showSpinner)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isContinueWatching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: GridView.builder(
                itemCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.62,
                ),
                itemBuilder: (context, index) => _buildSkeletonCard(context),
              ),
            )
          else
            SizedBox(
              height: 210,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => const SizedBox(
                  width: 135,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnymexSkeleton(
                          child: SkeletonBox(
                            width: 135,
                            height: double.infinity,
                            borderRadius: 16,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      AnymexSkeleton(
                        child: SkeletonBox(
                          width: 100,
                          height: 14,
                          borderRadius: 4,
                        ),
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

  Widget _buildSkeletonCard(BuildContext context) {
    return AnymexSkeleton(
      child: SkeletonBox(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 16,
      ),
    );
  }
}

class AnimeDetailsSkeleton extends StatelessWidget {
  const AnimeDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: AnymexSkeleton(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SkeletonBox(
                    height: 50,
                    borderRadius: 16,
                  ),
                ),
                const SizedBox(width: 7),
                SkeletonBox(
                  height: 50,
                  width: 60,
                  borderRadius: 16,
                ),
                const SizedBox(width: 7),
                SkeletonBox(
                  height: 50,
                  width: 60,
                  borderRadius: 16,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SkeletonBox(
              height: 100,
              borderRadius: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class EpisodeListSkeleton extends StatelessWidget {
  final bool isSliver;
  
  const EpisodeListSkeleton({super.key, this.isSliver = true});

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      padding: const EdgeInsets.only(top: 10),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: AnymexSkeleton(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: 140,
                  height: 80,
                  borderRadius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      SkeletonBox(
                        width: double.infinity,
                        height: 14,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      SkeletonBox(
                        width: 100,
                        height: 12,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 12),
                      SkeletonBox(
                        width: 50,
                        height: 10,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (isSliver) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 600,
          child: list,
        ),
      );
    }
    
    return list;
  }
}
