import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key, required this.child});

  AppShimmer.box({super.key, double height = 16, double? width, BorderRadius? radius})
      : child = Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius ?? BorderRadius.circular(8),
          ),
        );

  AppShimmer.circle({super.key, double size = 40})
      : child = Container(
          height: size,
          width: size,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        );

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
}

/// A generic "block of text" skeleton -- used by Terms & Conditions and
/// Privacy Policy while their HTML content loads.
class TextContentShimmer extends StatelessWidget {
  const TextContentShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AppShimmer.box(height: 24, width: 180),
        const SizedBox(height: 16),
        for (var i = 0; i < 5; i++) ...[
          AppShimmer.box(height: 14),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
