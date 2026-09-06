class OnboardingExplainerSlide {
  final String emoji;
  final String title;
  final String body;

  /// An optional headline shown above [body], styled larger and in the
  /// brand colour. Used on the final slide to make the call to action
  /// unmissable.
  final String? callout;

  const OnboardingExplainerSlide({
    required this.emoji,
    required this.title,
    required this.body,
    this.callout,
  });
}

/// The 5-screen "how Lernova works" explainer shown once, between the
/// Welcome screen's "Get started" and account creation.
const onboardingExplainerSlides = [
  OnboardingExplainerSlide(
    emoji: '🛤️',
    title: 'The Path',
    body: 'Work through short, bite-sized lessons in order. Finish one to '
        'unlock the next — your whole course laid out as a path you can '
        'always see your place on.',
  ),
  OnboardingExplainerSlide(
    emoji: '🎮',
    title: 'The Fun Zone',
    body: 'Vocabulary sticks better when it\'s playful. Catch falling words, '
        'match pairs, flip cards and more — casual games that reinforce '
        'exactly what you\'re learning on the Path.',
  ),
  OnboardingExplainerSlide(
    emoji: '🔁',
    title: 'Learn → Practice → Play',
    body: 'New words are introduced, practiced in a lesson, then '
        'reinforced through a game. Repetition across all three is what '
        'actually makes a word stick.',
  ),
  OnboardingExplainerSlide(
    emoji: '📈',
    title: 'Your Progress',
    body: 'Every lesson and game earns XP, builds your streak and tracks '
        'which words you\'ve mastered. Close the app any time — you\'ll '
        'pick up exactly where you left off.',
  ),
  OnboardingExplainerSlide(
    emoji: '🚀',
    title: 'Ready when you are',
    callout: 'Press Ready and Onboard Yourself',
    body: 'Pick a language, set your daily goal, and start your first '
        'lesson.',
  ),
];
