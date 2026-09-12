import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:lingoquest/core/theme/app_theme.dart';
import 'package:lingoquest/core/widgets/lingoquest_parrot.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
  );
  // Bounded: the mascot plays a one-shot settle that would otherwise
  // keep pumpAndSettle busy.
  await tester.pump(const Duration(milliseconds: 600));
}

/// The asset an [Image] under the mascot is actually pointing at.
String? _renderedAsset(WidgetTester tester) {
  final images = tester.widgetList<Image>(
    find.descendant(
      of: find.byType(LingoQuestParrot),
      matching: find.byType(Image),
    ),
  );
  for (final image in images) {
    final provider = image.image;
    if (provider is AssetImage) return provider.assetName;
    if (provider is ExactAssetImage) return provider.assetName;
  }
  return null;
}

void main() {
  // A pose is only useful if the widget asks for its file *and* that
  // file is really in the bundle. Those are two different mistakes — a
  // typo in the constant, and an artwork file that never got exported —
  // and each one alone leaves the app silently showing the wrong parrot.
  group('every pose the mascot can ask for is bundled', () {
    testWidgets('each mood loads its own artwork', (tester) async {
      for (final mood in LingoQuestParrotMood.values) {
        await _pump(tester, LingoQuestParrot(size: 96, mood: mood));

        final rendered = _renderedAsset(tester);
        expect(
          rendered,
          LingoQuestParrot(mood: mood).poseAsset,
          reason: '${mood.name} did not render its own pose',
        );
        expect(tester.takeException(), isNull, reason: mood.name);
      }
    });

    testWidgets('the wordmark loads the hero pose', (tester) async {
      await _pump(tester, const LingoQuestParrot(size: 64, showWordmark: true));

      expect(_renderedAsset(tester), LingoQuestParrot.heroAsset);
      expect(find.text('LingoQuest'), findsOneWidget);
    });

    test('every declared pose file exists in the bundle', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final declared = {
        LingoQuestParrot.artworkAsset,
        LingoQuestParrot.celebrateAsset,
        LingoQuestParrot.curiousAsset,
        LingoQuestParrot.sadAsset,
        LingoQuestParrot.heroAsset,
      };

      for (final path in declared) {
        final bytes = await rootBundle.load(path);
        expect(bytes.lengthInBytes, greaterThan(0), reason: path);
      }
    });
  });

  // Poses are added one file at a time, so each has to name its own —
  // a shared path would make "add the celebrate pose" silently restyle
  // every other mood too.
  group('poses are addressable one at a time', () {
    test('each mood names a distinct file', () {
      final paths = {
        for (final mood in LingoQuestParrotMood.values)
          mood: LingoQuestParrot(mood: mood).poseAsset,
      };

      expect(
        paths.values.toSet(),
        hasLength(LingoQuestParrotMood.values.length),
        reason: 'two moods share a file',
      );
      // Happy is the base file: supplying only that one dresses the app.
      expect(paths[LingoQuestParrotMood.happy], LingoQuestParrot.artworkAsset);
    });

    test('the wordmark overrides the mood', () {
      for (final mood in LingoQuestParrotMood.values) {
        expect(
          LingoQuestParrot(mood: mood, showWordmark: true).poseAsset,
          LingoQuestParrot.heroAsset,
          reason: mood.name,
        );
      }
    });
  });

  // The size a caller asks for is the box the art occupies, whichever
  // of the three sources ends up drawing it.
  testWidgets('it honours the requested size', (tester) async {
    await _pump(tester, const LingoQuestParrot(size: 80));

    final box = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(LingoQuestParrot),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(box.width, 80);
  });
}
