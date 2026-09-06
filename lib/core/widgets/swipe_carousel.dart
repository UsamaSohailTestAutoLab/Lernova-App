import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A generic swipeable `PageView` shell with a dot indicator and a
/// per-page pinned bottom slot — used by the vocabulary-preview step and
/// the first-time onboarding explainer, so carousel mechanics (paging,
/// progress dots, advance-by-swipe-or-button) exist in exactly one place.
class SwipeCarouselScaffold extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Builds the pinned area below the page/dots for the current [index].
  /// [goNext] animates to the next page; callers on the final page
  /// typically ignore it and navigate onward instead.
  final Widget Function(BuildContext context, int index, VoidCallback goNext) bottomBuilder;
  final ValueChanged<int>? onPageChanged;

  const SwipeCarouselScaffold({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.bottomBuilder,
    this.onPageChanged,
  });

  @override
  State<SwipeCarouselScaffold> createState() => _SwipeCarouselScaffoldState();
}

class _SwipeCarouselScaffoldState extends State<SwipeCarouselScaffold> {
  static const _maxDots = 10;

  final _controller = PageController();
  int _index = 0;

  void _goNext() {
    if (_index >= widget.itemCount - 1) return;
    _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.itemCount,
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onPageChanged?.call(i);
            },
            itemBuilder: widget.itemBuilder,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // A dot per page only scales to short carousels (the onboarding
        // explainer's 5 slides). Longer ones — a vocab preview can have
        // dozens of words at higher levels — switch to a linear progress
        // bar with a "X / N" count instead of overflowing a Row of dots.
        if (widget.itemCount <= _maxDots)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.itemCount; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / widget.itemCount,
                    minHeight: 6,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_index + 1} / ${widget.itemCount}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        widget.bottomBuilder(context, _index, _goNext),
      ],
    );
  }
}
