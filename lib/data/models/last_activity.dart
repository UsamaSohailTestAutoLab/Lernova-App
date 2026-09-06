/// Which side of the app the learner was last in.
enum LastActivityKind { pathLesson, funGame }

/// The last thing the learner actually opened, so "Continue learning"
/// resumes *that* instead of always assuming the Path.
///
/// Recorded when an activity **starts**, not when it finishes — the whole
/// point is picking up something that was abandoned halfway, and a
/// session that was never completed would otherwise leave no trace.
///
/// Hand-written `toJson`/`fromJson`/`copyWith`, matching the house style
/// (this project has no code generation).
class LastActivity {
  final LastActivityKind kind;
  final DateTime at;

  /// Path: where in the course the learner was.
  final String? courseId;
  final String? lessonId;
  final int? unitIndex;
  final int? lessonIndex;

  /// Fun: which mode, and at which level.
  final String? funModeName;
  final int? funLevel;

  /// Rendered at write time so the Home card never has to resolve
  /// content just to draw a label.
  final String title;
  final String subtitle;

  const LastActivity({
    required this.kind,
    required this.at,
    required this.title,
    required this.subtitle,
    this.courseId,
    this.lessonId,
    this.unitIndex,
    this.lessonIndex,
    this.funModeName,
    this.funLevel,
  });

  factory LastActivity.pathLesson({
    required DateTime at,
    required String courseId,
    required String lessonId,
    required int unitIndex,
    required int lessonIndex,
    required String title,
    required String subtitle,
  }) {
    return LastActivity(
      kind: LastActivityKind.pathLesson,
      at: at,
      courseId: courseId,
      lessonId: lessonId,
      unitIndex: unitIndex,
      lessonIndex: lessonIndex,
      title: title,
      subtitle: subtitle,
    );
  }

  factory LastActivity.funGame({
    required DateTime at,
    required String funModeName,
    required int funLevel,
    required String title,
    required String subtitle,
  }) {
    return LastActivity(
      kind: LastActivityKind.funGame,
      at: at,
      funModeName: funModeName,
      funLevel: funLevel,
      title: title,
      subtitle: subtitle,
    );
  }

  LastActivity copyWith({
    LastActivityKind? kind,
    DateTime? at,
    String? courseId,
    String? lessonId,
    int? unitIndex,
    int? lessonIndex,
    String? funModeName,
    int? funLevel,
    String? title,
    String? subtitle,
  }) {
    return LastActivity(
      kind: kind ?? this.kind,
      at: at ?? this.at,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      unitIndex: unitIndex ?? this.unitIndex,
      lessonIndex: lessonIndex ?? this.lessonIndex,
      funModeName: funModeName ?? this.funModeName,
      funLevel: funLevel ?? this.funLevel,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'at': at.toIso8601String(),
        'courseId': courseId,
        'lessonId': lessonId,
        'unitIndex': unitIndex,
        'lessonIndex': lessonIndex,
        'funModeName': funModeName,
        'funLevel': funLevel,
        'title': title,
        'subtitle': subtitle,
      };

  /// Returns null rather than throwing on anything malformed — a broken
  /// resume pointer should quietly fall back to the Path, never block the
  /// Home screen from loading.
  static LastActivity? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final kindName = json['kind'] as String?;
    final atRaw = json['at'] as String?;
    if (kindName == null || atRaw == null) return null;

    final kind = LastActivityKind.values
        .where((k) => k.name == kindName)
        .firstOrNull;
    final at = DateTime.tryParse(atRaw);
    if (kind == null || at == null) return null;

    return LastActivity(
      kind: kind,
      at: at,
      courseId: json['courseId'] as String?,
      lessonId: json['lessonId'] as String?,
      unitIndex: json['unitIndex'] as int?,
      lessonIndex: json['lessonIndex'] as int?,
      funModeName: json['funModeName'] as String?,
      funLevel: json['funLevel'] as int?,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
    );
  }
}
