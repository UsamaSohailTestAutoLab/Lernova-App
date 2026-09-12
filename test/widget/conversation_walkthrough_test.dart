import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/data/models/fun/conversation.dart';
import 'package:lingoquest/features/fun/presentation/widgets/conversation_walkthrough.dart';

const _conversation = Conversation(
  id: 'es_conv_meeting',
  title: 'Meeting Someone New',
  scenario: "You're introducing yourself to someone new.",
  languageId: 'es',
  turns: [
    ConversationTurn(
      id: 't1',
      line: '¡Hola! ¿Cómo estás?',
      lineEnglish: 'Hello! How are you?',
      options: ['Estoy bien, gracias', 'Tengo diez años'],
      optionsEnglish: ["I'm good, thank you", "I'm ten years old"],
      correctIndex: 0,
    ),
  ],
);

/// Older content, before the bilingual format.
const _untranslated = Conversation(
  id: 'legacy',
  title: 'Legacy',
  scenario: 'No translations',
  languageId: 'es',
  turns: [
    ConversationTurn(
      id: 't1',
      line: '¡Hola!',
      options: ['Hola', 'Adiós'],
      correctIndex: 0,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required ConversationStage stage,
  Conversation conversation = _conversation,
  Brightness brightness = Brightness.light,
}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
        home: Scaffold(
          body: ConversationWalkthrough(
            conversation: conversation,
            stage: stage,
            onContinue: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  // The learner used to be dropped straight into a Spanish-only chat and
  // asked to pick a reply, with no way to know what any of it meant.
  testWidgets('step 1 presents the whole exchange in English', (tester) async {
    await _pump(tester, stage: ConversationStage.english);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hello! How are you?'), findsOneWidget);
    expect(find.text("I'm good, thank you"), findsOneWidget);
    // Nothing in the learning language yet, and nothing to listen to.
    expect(find.text('¡Hola! ¿Cómo estás?'), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });

  testWidgets('step 2 shows the same exchange in Spanish, with meanings and audio',
      (tester) async {
    await _pump(tester, stage: ConversationStage.target);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('¡Hola! ¿Cómo estás?'), findsOneWidget);
    expect(find.text('Estoy bien, gracias'), findsOneWidget);
    // Each line still carries its English meaning — the pairing is the point.
    expect(find.text('Hello! How are you?'), findsOneWidget);
    expect(find.text("I'm good, thank you"), findsOneWidget);
    // One Listen button per line.
    expect(find.byIcon(Icons.volume_up_rounded), findsNWidgets(2));
  });

  testWidgets('the two steps lead into practice', (tester) async {
    await _pump(tester, stage: ConversationStage.english);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Show it in Spanish'), findsOneWidget);

    await _pump(tester, stage: ConversationStage.target);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Practice it'), findsOneWidget);
  });

  // Every bubble names its speaker, so the screen reads as a
  // conversation and you can see which lines will be asked of you.
  testWidgets('each line says who is speaking', (tester) async {
    await _pump(tester, stage: ConversationStage.target);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('They say'), findsOneWidget);
    expect(find.text('You say'), findsOneWidget);
    // And the screen says what happens after it.
    expect(find.textContaining("you'll pick the right reply"), findsOneWidget);
  });

  // This mode has no vocabulary list, so it used to open on a Review
  // Words step whose only card repeated the scenario blurb. Step 1 now
  // carries that blurb *and* says what the mode will ask of you.
  testWidgets('step 1 doubles as the "how this works" screen', (tester) async {
    await _pump(tester, stage: ConversationStage.english);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("You're introducing yourself to someone new."), findsOneWidget);
    expect(find.text('How this works'), findsOneWidget);
    expect(find.textContaining('Read the whole conversation in English'), findsOneWidget);
    expect(find.textContaining('hear them'), findsOneWidget);
    expect(find.textContaining('pick the right reply each turn'), findsOneWidget);
  });

  // Regression: your own replies were drawn on the raw primaryLight
  // literal — a pale green the theme's near-white dark-mode text was
  // invisible against, so half the conversation could not be read.
  testWidgets('your own replies are readable in dark mode', (tester) async {
    await _pump(
      tester,
      stage: ConversationStage.target,
      brightness: Brightness.dark,
    );
    await tester.pump(const Duration(milliseconds: 300));

    final bubble = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Estoy bien, gracias'),
            matching: find.byType(Container),
          )
          .last,
    );
    final bg = (bubble.decoration as BoxDecoration).color!;
    final text = tester.widget<Text>(find.text('Estoy bien, gracias'));
    final ink = text.style!.color!;

    // Reply-bubble ink and ground must not both be light.
    expect(
      (bg.computeLuminance() - ink.computeLuminance()).abs(),
      greaterThan(0.3),
      reason: 'the reply text has to stand off its own bubble',
    );
  });

  testWidgets('content without translations falls back rather than showing blanks',
      (tester) async {
    expect(_untranslated.hasTranslations, isFalse);
    expect(_conversation.hasTranslations, isTrue);

    // The English step renders the learning-language line rather than an
    // empty bubble, so even a fallback render is never broken.
    await _pump(tester, stage: ConversationStage.english, conversation: _untranslated);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('¡Hola!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
