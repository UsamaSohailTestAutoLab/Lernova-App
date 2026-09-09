import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/course.dart';
import '../../../data/models/language.dart';
import '../../../data/models/language_progress.dart';
import '../../../data/repositories/content_providers.dart';
import '../../../data/repositories/fun_content_providers.dart';
import '../../course/application/course_progress.dart';
import '../../fun/application/fun_progress_controller.dart';
import '../../onboarding/application/user_controller.dart';
import '../../progress/application/progress_controller.dart';

/// One language as the language list needs to see it: the language
/// itself, its course (null while a language is listed but not yet
/// authored), and where the learner left off in it.
class LanguageSummary {
  final Language language;
  final Course? course;
  final LanguageProgress progress;
  final bool isActive;

  /// Where the learner would resume, as a (unitIndex, lessonIndex)
  /// pair. Null for a finished course or one with no content.
  final (int, int)? resumeAt;

  const LanguageSummary({
    required this.language,
    required this.course,
    required this.progress,
    required this.isActive,
    required this.resumeAt,
  });

  bool get isAvailable => course != null;
  bool get hasStarted => !progress.isUntouched;

  int get lessonsCompleted => progress.completedLessonIds.length;
  int get totalLessons => course?.totalLessons ?? 0;

  /// Human-readable "where am I" line — the whole point of the list is
  /// that a learner can see, before switching, that Spanish is still
  /// waiting at Unit 2 Lesson 3.
  String get positionLabel {
    if (course == null) return 'Coming soon';
    if (!hasStarted) return 'Not started';
    final at = resumeAt;
    if (at == null) return 'Course complete';
    return 'Unit ${at.$1 + 1} · Lesson ${at.$2 + 1}';
  }
}

/// Every language, ordered so the one being learned is first and the
/// rest follow by how recently they were studied — an unstarted
/// language has nothing to sort by and sinks to the bottom.
final languageSummariesProvider =
    FutureProvider<List<LanguageSummary>>((ref) async {
  final languages = await ref.watch(languagesProvider.future);
  final courses = await ref.watch(coursesProvider.future);
  final progress = ref.watch(progressProvider);
  final activeLanguageId = ref.watch(userProvider).selectedLanguageId;

  Course? courseFor(String languageId) {
    for (final course in courses) {
      if (course.languageId == languageId) return course;
    }
    return null;
  }

  final summaries = <LanguageSummary>[];
  for (final language in languages) {
    final course = courseFor(language.id);
    final slice = progress.sliceForLanguage(language.id);
    summaries.add(
      LanguageSummary(
        language: language,
        course: course,
        progress: slice,
        isActive: language.id == activeLanguageId,
        resumeAt: course == null
            ? null
            : CourseProgress.findCurrentLesson(course, progress.viewAs(slice)),
      ),
    );
  }

  summaries.sort((a, b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    if (a.isAvailable != b.isAvailable) return a.isAvailable ? -1 : 1;
    final aAt = a.progress.lastStudiedAt;
    final bAt = b.progress.lastStudiedAt;
    if (aAt != null && bAt != null) return bAt.compareTo(aAt);
    if (aAt != null) return -1;
    if (bAt != null) return 1;
    return 0;
  });

  return summaries;
});

/// The language currently being learned, resolved from the profile.
/// Null before onboarding picks one, or while the list is loading.
final activeLanguageProvider = Provider<Language?>((ref) {
  final languageId = ref.watch(userProvider).selectedLanguageId;
  if (languageId == null) return null;
  final languages = ref.watch(languagesProvider).valueOrNull;
  if (languages == null) return null;
  for (final language in languages) {
    if (language.id == languageId) return language;
  }
  return null;
});

/// What happened, so the caller can tell the learner whether they are
/// resuming or starting fresh.
class LanguageSwitchOutcome {
  final Language language;
  final bool isFirstTime;

  const LanguageSwitchOutcome({
    required this.language,
    required this.isFirstTime,
  });
}

/// Switching languages, in one place.
///
/// The order matters: progress is parked *before* the profile changes
/// language, because parking has to know which language the current
/// progress belongs to. Doing it the other way round would file
/// Spanish's lessons under French.
class LanguageSwitchController {
  final Ref _ref;

  const LanguageSwitchController(this._ref);

  Future<LanguageSwitchOutcome> switchTo(String languageId) async {
    final language = (await _ref.read(languagesProvider.future))
        .firstWhere((l) => l.id == languageId);

    final course = await _ref.read(courseByLanguageProvider(languageId).future);
    if (course == null) {
      throw StateError('No course is available for ${language.name} yet');
    }

    final user = _ref.read(userProvider);
    final progressController = _ref.read(progressProvider.notifier);

    // Whichever the profile says, falling back to the label progress
    // carries and finally to the target itself — for a profile with no
    // language at all there is nothing to park, and parking under the
    // target is a no-op rather than a misfile.
    final from = user.selectedLanguageId ??
        _ref.read(progressProvider).activeLanguageId ??
        languageId;

    final wasUntouched =
        _ref.read(progressProvider).sliceForLanguage(languageId).isUntouched;

    progressController.switchLanguage(from: from, to: languageId);

    await _ref.read(userProvider.notifier).selectLanguage(languageId);
    await _ref.read(userProvider.notifier).setCurrentCourse(course.id);

    // Fun keeps its levels under a per-language key, so it just needs
    // to be told to re-read; the content providers are keyed by
    // language id and resolve on their own.
    _ref.invalidate(funProgressProvider);
    _ref.invalidate(funVocabWordsProvider);
    _ref.invalidate(funPhrasesProvider);
    _ref.invalidate(funConversationsProvider);

    return LanguageSwitchOutcome(
      language: language,
      isFirstTime: wasUntouched,
    );
  }
}

final languageSwitchControllerProvider = Provider<LanguageSwitchController>(
  LanguageSwitchController.new,
);
