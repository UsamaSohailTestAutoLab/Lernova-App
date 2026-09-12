import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/core/services/stt_service.dart';
import 'package:lingoquest/data/models/exercise.dart';
import 'package:lingoquest/features/exercises/application/lesson_session_controller.dart';
import 'package:lingoquest/features/exercises/presentation/speaking_exercise.dart';

const _payload = SpeakingPayload(
  prompt: 'Say this phrase out loud',
  targetPhrase: 'Hola, ¿cómo estás?',
  translation: 'Hello, how are you?',
);

/// A fake that never touches the real speech_to_text plugin — resolves
/// with whatever [response] is configured, simulating a recognized
/// transcript without a real microphone.
class _FakeSttService extends SttService {
  String? response;
  _FakeSttService(this.response);

  @override
  Future<String?> listenOnce({
    String locale = 'es-ES',
    Duration timeout = const Duration(seconds: 6),
  }) async {
    return response;
  }
}

Widget _harness(SttService fake, ValueChanged<String> onSubmit, {VoidCallback? onSkip}) {
  return ProviderScope(
    overrides: [sttServiceProvider.overrideWithValue(fake)],
    child: MaterialApp(
      home: Scaffold(
        body: SpeakingExercise(
          payload: _payload,
          feedback: ExerciseFeedback.none,
          onSubmit: onSubmit,
          onSkip: onSkip,
        ),
      ),
    ),
  );
}

/// One full mic → result cycle.
Future<void> _attempt(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.mic_none_rounded));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('Try again'));
  await tester.pump();
}

void main() {
  testWidgets('a close-enough recognized transcript reaches success and submits it', (tester) async {
    String? submitted;
    await tester.pumpWidget(_harness(_FakeSttService('Hola, como estas'), (v) => submitted = v));

    expect(find.text('Tap to speak'), findsOneWidget);

    // The fake resolves near-instantly, so "Listening…"/"Checking…" are
    // too fleeting to reliably observe mid-transition — a single bounded
    // pump past the widget's real 350ms "checking" delay is what actually
    // settles it, per this project's documented pumpAndSettle-with-real-
    // timers gotcha (see docs/TESTING.md).
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('🎉 Excellent!'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(submitted, 'Hola, como estas');
  });

  testWidgets('an unrelated transcript shows retry with what was heard', (tester) async {
    String? submitted;
    await tester.pumpWidget(_harness(_FakeSttService('buenas noches amigo'), (v) => submitted = v));

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('❌ Try again'), findsOneWidget);
    expect(find.textContaining('buenas noches amigo'), findsOneWidget);
    expect(submitted, isNull);

    // Tapping "Try again" resets back to idle so the mic can be tapped again.
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Tap to speak'), findsOneWidget);
  });

  testWidgets('no recognized speech (null) shows a "didn\'t catch that" retry', (tester) async {
    await tester.pumpWidget(_harness(_FakeSttService(null), (_) {}));

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('❌ Try again'), findsOneWidget);
    expect(find.textContaining("didn't catch that"), findsOneWidget);
  });

  // Regression: Skip used to be gated on a counter that only incremented
  // when the recognizer heard *silence*. A learner who spoke the wrong
  // words every time never saw it, and the exercise had no exit at all.
  // It is now offered unconditionally — a broken microphone or an accent
  // the recognizer can't place must never be a wall.
  testWidgets('the escape hatch is there before any attempt is made', (tester) async {
    await tester.pumpWidget(
      _harness(_FakeSttService('buenas noches amigo'), (_) {}, onSkip: () {}),
    );

    expect(find.text('Skip this one'), findsOneWidget);
  });

  testWidgets('speaking the wrong phrase repeatedly still offers Skip', (tester) async {
    var skipped = false;
    await tester.pumpWidget(
      _harness(_FakeSttService('buenas noches amigo'), (_) {}, onSkip: () => skipped = true),
    );

    await _attempt(tester);
    await _attempt(tester);

    // Third failure — of any kind — and the label grows more explicit.
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    final skip = find.textContaining('Skip this one');
    expect(skip, findsOneWidget);
    await tester.tap(skip);
    await tester.pump();
    expect(skipped, isTrue);
  });

  testWidgets('the target phrase can always be played back', (tester) async {
    await tester.pumpWidget(_harness(_FakeSttService(null), (_) {}));

    // Available from the very first frame, before any attempt is made.
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });
}
