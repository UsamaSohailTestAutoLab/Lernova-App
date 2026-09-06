import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/exercise.dart';
import '../application/lesson_session_controller.dart';

class WordMatchingExercise extends StatefulWidget {
  final WordMatchingPayload payload;
  final ExerciseFeedback feedback;
  final ValueChanged<Map<int, int>> onComplete;

  const WordMatchingExercise({
    super.key,
    required this.payload,
    required this.feedback,
    required this.onComplete,
  });

  @override
  State<WordMatchingExercise> createState() => _WordMatchingExerciseState();
}

class _WordMatchingExerciseState extends State<WordMatchingExercise> {
  late final List<int> _rightOrder;
  late final List<GlobalKey> _leftKeys;
  late final List<GlobalKey> _rightKeys;
  final GlobalKey _stackKey = GlobalKey();

  int? _selectedLeft;
  final Map<int, int> _matched = {}; // leftIndex -> rightOriginalIndex, always correct
  int? _wrongLeft;
  int? _wrongRight;

  @override
  void initState() {
    super.initState();
    final count = widget.payload.pairs.length;
    _rightOrder = List.generate(count, (i) => i)..shuffle();
    _leftKeys = List.generate(count, (_) => GlobalKey());
    _rightKeys = List.generate(count, (_) => GlobalKey());
  }

  void _tapLeft(int leftIndex) {
    if (widget.feedback != ExerciseFeedback.none) return;
    if (_matched.containsKey(leftIndex) || _wrongLeft != null) return;
    setState(() => _selectedLeft = leftIndex);
  }

  void _tapRight(int rightOriginalIndex) {
    if (widget.feedback != ExerciseFeedback.none) return;
    if (_matched.containsValue(rightOriginalIndex) || _wrongLeft != null) return;
    if (_selectedLeft == null) return;

    final leftIndex = _selectedLeft!;
    // Right options keep their original pair index even after shuffling,
    // so a correct match is exactly leftIndex == rightOriginalIndex.
    final correct = leftIndex == rightOriginalIndex;

    if (correct) {
      setState(() {
        _matched[leftIndex] = rightOriginalIndex;
        _selectedLeft = null;
      });
      if (_matched.length == widget.payload.pairs.length) {
        widget.onComplete(Map<int, int>.from(_matched));
      }
      return;
    }

    // Wrong: flash both chips red, then release them so the pair can be
    // retried — never marked completed on a miss.
    setState(() {
      _selectedLeft = null;
      _wrongLeft = leftIndex;
      _wrongRight = rightOriginalIndex;
    });
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      setState(() {
        _wrongLeft = null;
        _wrongRight = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pairs = widget.payload.pairs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.payload.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xl),
        Stack(
          key: _stackKey,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < pairs.length; i++)
                        _MatchChip(
                          key: _leftKeys[i],
                          label: pairs[i].left,
                          selected: _selectedLeft == i,
                          matched: _matched.containsKey(i),
                          wrong: _wrongLeft == i,
                          onTap: () => _tapLeft(i),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    children: [
                      for (final rightIndex in _rightOrder)
                        _MatchChip(
                          key: _rightKeys[rightIndex],
                          label: pairs[rightIndex].right,
                          selected: false,
                          matched: _matched.containsValue(rightIndex),
                          wrong: _wrongRight == rightIndex,
                          onTap: () => _tapRight(rightIndex),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ConnectorPainter(
                    matched: _matched,
                    leftKeys: _leftKeys,
                    rightKeys: _rightKeys,
                    stackKey: _stackKey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Draws a line between each confirmed-correct pair's chips, read from
/// their [GlobalKey]s' laid-out geometry each repaint — cheap enough for
/// the small pair counts this exercise ever has, so [shouldRepaint]
/// doesn't bother diffing and just always repaints.
class _ConnectorPainter extends CustomPainter {
  final Map<int, int> matched;
  final List<GlobalKey> leftKeys;
  final List<GlobalKey> rightKeys;
  final GlobalKey stackKey;

  _ConnectorPainter({
    required this.matched,
    required this.leftKeys,
    required this.rightKeys,
    required this.stackKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stackBox = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final linePaint = Paint()
      ..color = AppColors.success
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = AppColors.success;

    for (final entry in matched.entries) {
      final leftBox = leftKeys[entry.key].currentContext?.findRenderObject() as RenderBox?;
      final rightBox = rightKeys[entry.value].currentContext?.findRenderObject() as RenderBox?;
      if (leftBox == null || rightBox == null) continue;

      final start = stackBox.globalToLocal(
        leftBox.localToGlobal(Offset(leftBox.size.width, leftBox.size.height / 2)),
      );
      final end = stackBox.globalToLocal(
        rightBox.localToGlobal(Offset(0, rightBox.size.height / 2)),
      );

      canvas.drawLine(start, end, linePaint);
      canvas.drawCircle(start, 3.5, dotPaint);
      canvas.drawCircle(end, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) => true;
}

class _MatchChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool matched;
  final bool wrong;
  final VoidCallback onTap;

  const _MatchChip({
    super.key,
    required this.label,
    required this.selected,
    required this.matched,
    this.wrong = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = matched
        ? AppColors.success
        : wrong
            ? AppColors.error
            : selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: matched ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: matched
                ? AppColors.successLight
                : wrong
                    ? AppColors.errorLight
                    : selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: selected || matched || wrong ? 2 : 1),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: matched
                  ? AppColors.success
                  : wrong
                      ? AppColors.error
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}
