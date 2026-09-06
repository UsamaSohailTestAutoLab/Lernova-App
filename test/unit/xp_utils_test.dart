import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/utils/xp_utils.dart';

void main() {
  group('XpUtils', () {
    test('first-try correct answer awards full XP', () {
      expect(XpUtils.xpForAnswer(isRetry: false), 10);
    });

    test('retry correct answer awards reduced XP', () {
      expect(XpUtils.xpForAnswer(isRetry: true), 5);
    });

    test('lesson bonus without perfect', () {
      expect(XpUtils.lessonBonusXp(isPerfect: false), 10);
    });

    test('lesson bonus with perfect adds extra', () {
      expect(XpUtils.lessonBonusXp(isPerfect: true), 30);
    });

    test('level is 1 at zero XP', () {
      expect(XpUtils.levelForXp(0), 1);
    });

    test('level increments every 500 XP', () {
      expect(XpUtils.levelForXp(499), 1);
      expect(XpUtils.levelForXp(500), 2);
      expect(XpUtils.levelForXp(1000), 3);
    });

    test('xpToNextLevel counts down within a level', () {
      expect(XpUtils.xpToNextLevel(450), 50);
      expect(XpUtils.xpToNextLevel(0), 500);
    });

    test('levelProgress is a 0..1 ratio within the level', () {
      expect(XpUtils.levelProgress(0), 0);
      expect(XpUtils.levelProgress(250), 0.5);
      expect(XpUtils.levelProgress(500), 0);
    });
  });
}
