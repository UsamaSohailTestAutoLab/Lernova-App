/// What the app remembers about asking for a store review.
///
/// iOS keeps its own count and will simply ignore a fourth request in a
/// year, so this is not the enforcement mechanism — the system is. It
/// exists because those three requests a year are a budget worth
/// spending well: an unprompted ask from a learner two lessons in is
/// wasted, and once wasted it cannot be retried until the year rolls
/// over. Android's Play In-App Review has its own opaque quota and the
/// same reasoning applies.
///
/// Nothing here records what the learner *did* with the prompt, because
/// neither platform says. [asksMade] counts requests made, not reviews
/// left, and no part of the app may treat it as the latter.
class ReviewPromptState {
  /// How many times the app has asked the system to show the prompt.
  final int asksMade;

  /// When the last request was made, or null if never.
  final DateTime? lastAskedAt;

  /// First time the app was in a position to ask — set on the first
  /// eligibility check, which is what "how long have they had the app"
  /// is measured from. Using the account's join date instead would
  /// count time for someone who installed and never opened it again.
  final DateTime? firstEligibleCheckAt;

  const ReviewPromptState({
    this.asksMade = 0,
    this.lastAskedAt,
    this.firstEligibleCheckAt,
  });

  static const ReviewPromptState fresh = ReviewPromptState();

  ReviewPromptState copyWith({
    int? asksMade,
    DateTime? lastAskedAt,
    DateTime? firstEligibleCheckAt,
  }) {
    return ReviewPromptState(
      asksMade: asksMade ?? this.asksMade,
      lastAskedAt: lastAskedAt ?? this.lastAskedAt,
      firstEligibleCheckAt: firstEligibleCheckAt ?? this.firstEligibleCheckAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'asksMade': asksMade,
        'lastAskedAt': lastAskedAt?.toIso8601String(),
        'firstEligibleCheckAt': firstEligibleCheckAt?.toIso8601String(),
      };

  factory ReviewPromptState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return fresh;
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.tryParse(json[key] as String);
    return ReviewPromptState(
      asksMade: json['asksMade'] as int? ?? 0,
      lastAskedAt: date('lastAskedAt'),
      firstEligibleCheckAt: date('firstEligibleCheckAt'),
    );
  }
}
