import 'vocab_preview_item.dart';

/// The reusability seam for the vocabulary-preview step: any entry
/// screen (Path lesson intro, any Fun game intro) builds one of these
/// after starting its real session, and the shared preview screen takes
/// it from there — it knows nothing about lessons, falling words, word
/// matching, or any other mode-specific concept.
class VocabPreviewNavArgs {
  final List<VocabPreviewItem> items;
  final String levelLabel;
  final String onStartRoute;
  final Object? onStartExtra;

  /// Stable identity of the level being previewed (`path:<lessonId>` or
  /// `fun:<mode>:<level>`), used to remember whether these words have
  /// already been reviewed once.
  ///
  /// The first run through a level is not skippable — a beginner meeting
  /// this vocabulary for the first time should see all of it. On every
  /// later attempt the review becomes optional. Null disables the whole
  /// mechanism, leaving the preview mandatory.
  final String? previewKey;

  const VocabPreviewNavArgs({
    required this.items,
    required this.levelLabel,
    required this.onStartRoute,
    this.onStartExtra,
    this.previewKey,
  });
}
