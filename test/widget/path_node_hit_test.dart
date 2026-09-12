import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/data/models/lesson.dart';
import 'package:lingoquest/features/course/presentation/widgets/path_node.dart';

const _lesson = Lesson(id: 'l0', title: 'Yes, No, Sorry', subtitle: '', exercises: []);
const _rowWidth = 400.0;

/// Regression for a real on-device bug: tapping a lesson node whose path
/// zig-zags away from center (every second lesson in a unit — see
/// `PathGeometry.dxFor`) silently did nothing, while dead-center nodes
/// worked anywhere on their visible circle. Reproduced by tapping a live
/// build over adb; root cause was `Align` + `Transform.translate(dx)`
/// for the horizontal offset, which is supposed to move paint and
/// hit-testing together but didn't line up on a real device. The fix
/// computes the offset as a real `Positioned.left`, so this test taps at
/// the exact pixel the circle is actually drawn at and expects it to
/// register — that pixel *is* the regression surface.
Future<void> _pump(
  WidgetTester tester, {
  required double dx,
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _rowWidth,
            child: PathNode(
              lesson: _lesson,
              state: LessonNodeState.unlocked,
              incomingDx: 0,
              dx: dx,
              nodeSize: 68,
              currentNodeSize: 80,
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping the visible circle of an off-center node triggers onTap', (tester) async {
    var tapped = false;
    const dx = 60.0;
    await _pump(tester, dx: dx, onTap: () => tapped = true);

    final topLeft = tester.getTopLeft(find.byType(PathNode));
    // The node's own vertical center (see _nodeCenterY in path_node.dart)
    // and horizontal center-plus-offset — exactly where the circle paints.
    final circleCenter = topLeft + const Offset(_rowWidth / 2, 44) + Offset(dx, 0);

    await tester.tapAt(circleCenter);
    await tester.pump();

    expect(tapped, isTrue, reason: 'the visible circle for an offset node must be tappable');
  });

  testWidgets('a dead-center node (dx=0) is tappable at its visual center', (tester) async {
    var tapped = false;
    await _pump(tester, dx: 0, onTap: () => tapped = true);

    final topLeft = tester.getTopLeft(find.byType(PathNode));
    final circleCenter = topLeft + const Offset(_rowWidth / 2, 44);

    await tester.tapAt(circleCenter);
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('the offset node is tappable across its full circle, not just one edge',
      (tester) async {
    // Guards against a narrow "sliver" hit region — the actual shape of
    // the original bug — by trying several points spread across the
    // visible circle's diameter, not just its exact center.
    const dx = 60.0;
    const nodeSize = 68.0;

    for (final fraction in [-0.3, 0.0, 0.3]) {
      var tapped = false;
      await _pump(tester, dx: dx, onTap: () => tapped = true);

      final topLeft = tester.getTopLeft(find.byType(PathNode));
      final point = topLeft +
          const Offset(_rowWidth / 2, 44) +
          Offset(dx + fraction * nodeSize, fraction * nodeSize);

      await tester.tapAt(point);
      await tester.pump();

      expect(tapped, isTrue, reason: 'missed at fraction $fraction of the circle');
    }
  });

  testWidgets('a locked offset node shakes and shows its message instead of navigating',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: _rowWidth,
              child: PathNode(
                lesson: _lesson,
                state: LessonNodeState.locked,
                incomingDx: 0,
                dx: 60,
                nodeSize: 68,
                currentNodeSize: 80,
                lockedMessage: "Complete 'Say Hello' first.",
              ),
            ),
          ),
        ),
      ),
    );

    final topLeft = tester.getTopLeft(find.byType(PathNode));
    final circleCenter = topLeft + const Offset(_rowWidth / 2 + 60, 44);

    await tester.tapAt(circleCenter);
    await tester.pump();

    expect(find.text("Complete 'Say Hello' first."), findsOneWidget);
  });
}
