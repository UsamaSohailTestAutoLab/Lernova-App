import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lingoquest/core/services/local_storage_service.dart';
import 'package:lingoquest/core/services/service_providers.dart';
import 'package:lingoquest/core/theme/app_colors.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/data/models/fun/vocab_word.dart';
import 'package:lingoquest/features/fun/application/fun_memory_match_session_controller.dart';
import 'package:lingoquest/features/fun/presentation/fun_memory_match_screen.dart';

List<VocabWord> _words() => const [
      VocabWord(id: 'w1', word: 'Hola', translation: 'Hello', languageId: 'es', category: 'g'),
      VocabWord(id: 'w2', word: 'Adiós', translation: 'Goodbye', languageId: 'es', category: 'g'),
      VocabWord(id: 'w3', word: 'Gracias', translation: 'Thanks', languageId: 'es', category: 'g'),
    ];

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.create();
    container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const FunMemoryMatchScreen(),
        ),
      ),
    );
  }

  void startRound() {
    container.read(funMemoryMatchSessionProvider.notifier).start(
          words: _words(),
          vocabStrength: const {},
          pairCount: 3,
          random: Random(1),
        );
  }

  testWidgets('the round opens by showing the board with what to do', (tester) async {
    startRound();
    await pump(tester);
    await tester.pump();

    expect(find.text('Memorise the pairs'), findsOneWidget);
    // A countdown you can watch, not just a number.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Every card face up: three pairs means all six labels are readable.
    for (final w in _words()) {
      expect(find.text(w.word), findsOneWidget);
      expect(find.text(w.translation), findsOneWidget);
    }
  });

  // Connector lines were tried first and had to cross the board to
  // reach their partner, running straight through the words they were
  // pointing at. Shared colour says the same thing without covering
  // anything.
  testWidgets('the two halves of a pair share a colour while memorising', (tester) async {
    startRound();
    await pump(tester);
    await tester.pump();

    final cards = container.read(funMemoryMatchSessionProvider)!.cards;
    final colors = memoryPairColors(cards);

    Color colorOf(String label) {
      final text = tester.widget<Text>(find.descendant(
        of: find.byType(GridView),
        matching: find.text(label),
      ));
      return text.style!.color!;
    }

    for (final w in _words()) {
      expect(colorOf(w.word), colorOf(w.translation),
          reason: '${w.word} and ${w.translation} are a pair');
    }
    // And different pairs are told apart.
    expect(colors.toSet(), hasLength(3));
  });

  testWidgets('"I\'m ready" skips the countdown into play', (tester) async {
    startRound();
    await pump(tester);
    await tester.pump();

    await tester.tap(find.text("I'm ready"));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      container.read(funMemoryMatchSessionProvider)!.phase,
      MemoryMatchPhase.playing,
    );
    expect(find.text('Find the matching pairs'), findsOneWidget);
    expect(find.textContaining('Tap two cards'), findsOneWidget);
  });

  // A wrong pick used to stop the round with a full "Not quite!" panel
  // asking the player to type a meaning. In a placement game that hid
  // the board they were holding in mind; now the two cards just go red.
  testWidgets('a wrong pair turns both cards red with no interruption', (tester) async {
    startRound();
    await pump(tester);
    await tester.pump();

    await tester.tap(find.text("I'm ready"));
    await tester.pump(const Duration(milliseconds: 300));

    final cards = container.read(funMemoryMatchSessionProvider)!.cards;
    final b = cards.indexWhere((c) => c.pairId != cards[0].pairId);

    // Face-down cards show no label, so tap them by grid position.
    final tappable = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(tappable.at(0));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(tappable.at(b));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Not quite!'), findsNothing);
    expect(find.text('Type the meaning'), findsNothing);
    // The board is still there, and the two wrong cards read as wrong.
    expect(find.byType(GridView), findsOneWidget);
    final wrongCards = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Text),
        ))
        .where((t) => t.style?.color == AppColors.error)
        .toList();
    expect(wrongCards, hasLength(2), reason: 'both picked cards should be red');

    // And it clears itself — no button to press.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(container.read(funMemoryMatchSessionProvider)!.flippedIndices, isEmpty);
  });
}
