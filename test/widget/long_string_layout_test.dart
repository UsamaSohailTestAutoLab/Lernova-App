import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lernova/core/theme/app_theme.dart';
import 'package:lernova/core/widgets/choice_tile.dart';
import 'package:lernova/core/widgets/prompt_panel.dart';
import 'package:lernova/core/widgets/question_header.dart';
import 'package:lernova/features/exercises/application/lesson_session_controller.dart';
import 'package:lernova/features/exercises/presentation/widgets/option_choice_list.dart';
import 'package:lernova/features/fun/presentation/widgets/water_bubble.dart';

import '../support/long_strings.dart';

/// The narrowest screen we intend to support. Overflow shows up here
/// long before it shows up on a 400dp+ device.
const _smallPhone = Size(320, 640);

Future<void> _pumpAt(WidgetTester tester, Widget child, {Size size = _smallPhone}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('option and prompt surfaces survive every supported script', () {
    for (final entry in LongStrings.byScript.entries) {
      final script = entry.key;
      final text = entry.value;

      testWidgets('OptionChoiceList — $script', (tester) async {
        await _pumpAt(
          tester,
          OptionChoiceList(
            options: [text, text, LongStrings.english, text],
            correctIndex: 0,
            feedback: ExerciseFeedback.none,
            onSelect: (_) {},
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('AppChoiceTile — $script', (tester) async {
        await _pumpAt(
          tester,
          Column(
            children: [
              AppChoiceTile(label: text, secondaryLabel: text, onTap: () {}),
              AppChoiceTile(
                label: text,
                state: ChoiceTileState.incorrect,
                leading: const Icon(Icons.abc_rounded),
                onTap: () {},
              ),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('QuestionHeader + PromptPanel — $script', (tester) async {
        await _pumpAt(
          tester,
          Column(
            children: [
              QuestionHeader(prompt: text, hint: text, typeLabel: script),
              PromptPanel(text: text, trailing: const Icon(Icons.volume_up_rounded)),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('water bubbles survive every supported script', () {
    for (final entry in LongStrings.byScript.entries) {
      testWidgets('WaterBubble — ${entry.key}', (tester) async {
        // The size a 3-option round hands a bubble on a 320dp phone:
        // ~106dp lanes, so ~90dp of bubble.
        await _pumpAt(
          tester,
          Align(
            child: WaterBubble(
              label: entry.value,
              state: BubbleVisualState.idle,
              width: 90,
              height: 70,
              onTap: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('answer pills', () {
    testWidgets('an emoji supports the word rather than replacing it', (tester) async {
      await _pumpAt(
        tester,
        const Align(
          child: WaterBubble(
            label: 'Apple',
            emoji: '🍎',
            state: BubbleVisualState.idle,
            onTap: null,
          ),
        ),
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('🍎'), findsOneWidget);
    });

    testWidgets('a narrow pill drops the emoji and keeps the word', (tester) async {
      // The word is the answer; the emoji is decoration. When only one
      // fits, it is never the word that goes.
      await _pumpAt(
        tester,
        const Align(
          child: WaterBubble(
            label: 'Apple',
            emoji: '🍎',
            width: 90,
            height: 60,
            state: BubbleVisualState.idle,
            onTap: null,
          ),
        ),
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('🍎'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a 3-option bubble round fits 320dp without overlapping lanes', (tester) async {
    // Mirrors BubbleField's layout math: one lane per option, and a
    // bubble that is always narrower than its own lane.
    const width = 320.0;
    const optionCount = 3;

    final laneWidth = width / optionCount;
    final bubbleWidth = math.min(laneWidth - 16.0, 168.0).clamp(72.0, 168.0);

    expect(
      bubbleWidth,
      lessThanOrEqualTo(laneWidth),
      reason: 'a bubble must never be wider than its own lane — that was the overlap bug',
    );

    // Every option lands inside the viewport, sway included. Drift is
    // bounded by the slack left in the lane, so it can never push a
    // bubble into a neighbour or off the edge.
    final maxDrift = math.min((laneWidth - bubbleWidth) / 2, 14.0);
    for (var i = 0; i < optionCount; i++) {
      final left = laneWidth * i + laneWidth / 2 - bubbleWidth / 2;
      expect(left - maxDrift, greaterThanOrEqualTo(0.0));
      expect(left + bubbleWidth + maxDrift, lessThanOrEqualTo(width + 0.01));
    }
  });
}
