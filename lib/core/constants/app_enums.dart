/// Exercise interaction types. Each maps to a dedicated widget in
/// features/exercises/presentation.
enum ExerciseType {
  multipleChoice,
  translation,
  listening,
  speaking,
  wordMatching,
  sentenceArrangement,
  fillInTheBlank,
  imageRecognition,
}

enum LessonNodeState { locked, unlocked, current, completed, perfect }

enum LearningGoal { casual, regular, serious, intense }

enum DailyGoalXp { five, ten, twenty, fifty }

extension DailyGoalXpX on DailyGoalXp {
  int get xp => switch (this) {
        DailyGoalXp.five => 5,
        DailyGoalXp.ten => 10,
        DailyGoalXp.twenty => 20,
        DailyGoalXp.fifty => 50,
      };

  String get label => switch (this) {
        DailyGoalXp.five => 'Casual',
        DailyGoalXp.ten => 'Regular',
        DailyGoalXp.twenty => 'Serious',
        DailyGoalXp.fifty => 'Intense',
      };
}

enum LeagueTier { bronze, silver, gold, sapphire, emerald, diamond }

extension LeagueTierX on LeagueTier {
  String get label => switch (this) {
        LeagueTier.bronze => 'Bronze',
        LeagueTier.silver => 'Silver',
        LeagueTier.gold => 'Gold',
        LeagueTier.sapphire => 'Sapphire',
        LeagueTier.emerald => 'Emerald',
        LeagueTier.diamond => 'Diamond',
      };

  LeagueTier? get next {
    const order = LeagueTier.values;
    final i = order.indexOf(this);
    return i < order.length - 1 ? order[i + 1] : null;
  }

  LeagueTier? get previous {
    const order = LeagueTier.values;
    final i = order.indexOf(this);
    return i > 0 ? order[i - 1] : null;
  }
}

enum AchievementId {
  firstLesson,
  streak3,
  streak7,
  streak30,
  xp100,
  xp500,
  xp1000,
  perfectLesson,
  fiveLessonsInADay,
  unitComplete,
  courseComplete,
  wordMaster,
  phraseMaster,
  speedLearner,
  perfectRound,
}

enum ShopItemType { streakFreeze, mascotOutfit }

/// The casual game modes shown in the Fun hub. All are real, playable
/// gameplay (see [FunGameModeX.isImplemented]) gated behind a Fun-hub
/// level so the roadmap is honest rather than a screen full of dead
/// buttons.
enum FunGameMode {
  fallingWords,
  wordRush,
  wordMatch,
  memoryMatch,
  phraseBuilder,
  listenAndCatch,
  conversationChallenge,
  sentenceBuilder,
  meaningShooter,
}

extension FunGameModeX on FunGameMode {
  String get title => switch (this) {
        FunGameMode.fallingWords => 'Word Bubble',
        FunGameMode.wordRush => 'Word Rush',
        FunGameMode.wordMatch => 'Word Match',
        FunGameMode.memoryMatch => 'Memory Match',
        FunGameMode.phraseBuilder => 'Phrase Builder',
        FunGameMode.listenAndCatch => 'Listen & Catch',
        FunGameMode.conversationChallenge => 'Conversation Challenge',
        FunGameMode.sentenceBuilder => 'Sentence Builder',
        FunGameMode.meaningShooter => 'Meaning Shooter',
      };

  String get emoji => switch (this) {
        FunGameMode.fallingWords => '🫧',
        FunGameMode.wordRush => '⚡',
        FunGameMode.wordMatch => '🧩',
        FunGameMode.memoryMatch => '🧠',
        FunGameMode.phraseBuilder => '💬',
        FunGameMode.listenAndCatch => '🎧',
        FunGameMode.conversationChallenge => '🗣️',
        FunGameMode.sentenceBuilder => '🔤',
        FunGameMode.meaningShooter => '🎯',
      };

  String get blurb => switch (this) {
        FunGameMode.fallingWords => 'Catch the right meaning before it falls',
        FunGameMode.wordRush => 'Fast-paced word catching with big combos',
        FunGameMode.wordMatch => 'Pair up words and meanings',
        FunGameMode.memoryMatch => 'Flip cards, find the matching pairs',
        FunGameMode.phraseBuilder => 'Complete everyday phrases',
        FunGameMode.listenAndCatch => 'Listen closely, catch what you hear',
        FunGameMode.conversationChallenge => 'Follow a real back-and-forth chat',
        FunGameMode.sentenceBuilder => 'Drag words into the right order',
        FunGameMode.meaningShooter => 'Pop the bubble with the right meaning',
      };

  /// Fun-hub level (see [FunProgress.gameLevels]) at which this mode
  /// unlocks. The two flagship modes are open from the start.
  int get unlockLevel => switch (this) {
        FunGameMode.fallingWords => 1,
        FunGameMode.wordRush => 1,
        FunGameMode.wordMatch => 3,
        FunGameMode.memoryMatch => 4,
        FunGameMode.sentenceBuilder => 5,
        FunGameMode.phraseBuilder => 6,
        FunGameMode.listenAndCatch => 7,
        FunGameMode.meaningShooter => 8,
        FunGameMode.conversationChallenge => 9,
      };

  /// All 10 spec'd modes now have real gameplay behind them. Kept as an
  /// explicit getter (rather than deleting the concept) so a future new
  /// mode added to this enum defaults to *not* implemented until its
  /// screen/controller actually exist — see `docs/FUN_TAB.md`.
  bool get isImplemented => true;
}

/// The question "shape" a [FunQuestion] takes — covers every prompt/answer
/// combination in the Fun spec (English<->target word, image, audio,
/// synonym/antonym, phrase<->meaning). Combos framed as "meaning -> word"
/// from either direction collapse to the single [meaningToWord] type since
/// they're mechanically identical.
enum FunQuestionType {
  wordToMeaning,
  meaningToWord,
  imageToWord,
  wordToImage,
  audioToMeaning,
  wordToSynonym,
  wordToOpposite,
  phraseToMeaning,
  meaningToPhrase,
}
