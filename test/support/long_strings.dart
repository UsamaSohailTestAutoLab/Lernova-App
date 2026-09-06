/// Text samples for the scripts Lernova's interface is meant to support,
/// used to prove question/answer surfaces don't overflow, clip or break
/// on anything longer or taller than English.
///
/// These are deliberately *realistic worst cases*, not arbitrary long
/// strings: a real German compound noun, Arabic (RTL, taller line box),
/// Japanese (no word breaks, wide glyphs), Russian (Cyrillic, long
/// words), and Turkish (dotted/dotless i, long agglutinated forms).
class LongStrings {
  LongStrings._();

  static const german = 'Rindfleischetikettierungsüberwachungsaufgabenübertragungsgesetz';
  static const arabic = 'مرحبا كيف حالك اليوم يا صديقي العزيز';
  static const japanese = 'おはようございます、今日はいい天気ですね';
  static const russian = 'Достопримечательности Санкт-Петербурга';
  static const turkish = 'Muvaffakiyetsizleştiricileştiriveremeyebileceklerimizdenmişsinizcesine';

  /// A short Latin control, so a failing case can be distinguished from
  /// a surface that was broken to begin with.
  static const english = 'Hello';

  static const Map<String, String> byScript = {
    'english': english,
    'german': german,
    'arabic': arabic,
    'japanese': japanese,
    'russian': russian,
    'turkish': turkish,
  };
}
