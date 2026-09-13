import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/constants/app_enums.dart';
import 'package:lingoquest/core/theme/app_spacing.dart';
import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/features/fun/presentation/widgets/game_mode_card.dart';

/// The Fun Zone grid, in both themes and all three card states.
///
/// Deliberately named without the `_test` suffix so `flutter test` does
/// not pick it up — golden output moves with the Flutter version and the
/// host's font rasterizer, and these exist to be looked at. Run by path:
///
///     flutter test test/widget/fun_cards_golden.dart --update-goldens
///
/// Dark mode is the reason this is worth having. The cards are painted
/// from a per-mode palette rather than theme tokens, so "does it still
/// read on the dark ground?" cannot be answered from the widget tree —
/// only by looking at all ten.
Future<void> _loadRealFonts() async {
  for (final family in const {
    'Inter': 'assets/fonts/Inter.ttf',
    'Baloo 2': 'assets/fonts/Baloo2.ttf',
  }.entries) {
    final loader = FontLoader(family.key)..addFont(rootBundle.load(family.value));
    await loader.load();
  }
}

/// Cycles the three states across the grid so one image shows all of
/// them: playable, Pro-locked, and locked behind a Fun level.
Widget _grid() => GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(AppSpacing.lg),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 0.95,
      children: [
        for (var i = 0; i < FunGameMode.values.length; i++)
          GameModeCard(
            mode: FunGameMode.values[i],
            level: i + 1,
            unlocked: i % 3 != 2,
            requiresPro: i % 3 == 1,
            onTap: () {},
          ),
      ],
    );

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: theme, home: Scaffold(body: _grid())),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  testWidgets('Fun cards — light', (tester) async {
    await _pump(tester, AppTheme.light());
    await expectLater(
      find.byType(GridView),
      matchesGoldenFile('goldens/fun_cards_light.png'),
    );
  });

  testWidgets('Fun cards — dark', (tester) async {
    await _pump(tester, AppTheme.dark());
    await expectLater(
      find.byType(GridView),
      matchesGoldenFile('goldens/fun_cards_dark.png'),
    );
  });
}
