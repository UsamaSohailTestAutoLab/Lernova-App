import 'package:flutter_test/flutter_test.dart';
import 'package:lernova/core/constants/app_enums.dart';
import 'package:lernova/data/models/exercise.dart';
import 'package:lernova/data/models/fun/conversation.dart';
import 'package:lernova/data/models/fun/fun_question.dart';
import 'package:lernova/data/models/fun/phrase.dart';
import 'package:lernova/data/models/fun/vocab_word.dart';
import 'package:lernova/data/models/vocab_preview_item.dart';
import 'package:lernova/features/preview/application/vocab_preview_builder.dart';

const _words = [
  VocabWord(id: 'w1', word: 'Hola', translation: 'Hello', languageId: 'es', category: 'greetings'),
  VocabWord(id: 'w2', word: 'Casa', translation: 'House', languageId: 'es', category: 'home'),
];

const _phrases = [
  Phrase(id: 'p1', phrase: 'Como estas', meaning: 'How are you', languageId: 'es', category: 'greetings'),
];

void main() {
  group('VocabPreviewBuilder.fromVocabIds', () {
    test('resolves known word ids and preserves first-seen order', () {
      final items = VocabPreviewBuilder.fromVocabIds(vocabIds: ['w2', 'w1'], wordPool: _words);
      expect(items.map((i) => i.id).toList(), ['w2', 'w1']);
      expect(items[0].word, 'Casa');
      expect(items[0].meaning, 'House');
    });

    test('falls back to the phrase pool when a word lookup misses', () {
      final items = VocabPreviewBuilder.fromVocabIds(
        vocabIds: ['p1'],
        wordPool: _words,
        phrasePool: _phrases,
      );
      expect(items, hasLength(1));
      expect(items.single.word, 'Como estas');
      expect(items.single.meaning, 'How are you');
    });

    test('silently drops ids that resolve in neither pool', () {
      final items = VocabPreviewBuilder.fromVocabIds(
        vocabIds: ['w1', 'synthetic_set_1', 'p1'],
        wordPool: _words,
        phrasePool: _phrases,
      );
      expect(items.map((i) => i.id).toSet(), {'w1', 'p1'});
    });

    test('de-duplicates repeated ids', () {
      final items = VocabPreviewBuilder.fromVocabIds(vocabIds: ['w1', 'w1', 'w1'], wordPool: _words);
      expect(items, hasLength(1));
    });
  });

  test('fromFunQuestions derives items from resolved words, not question prompt text', () {
    const questions = [
      FunQuestion(
        id: 'q1',
        type: FunQuestionType.meaningToWord,
        promptText: 'Hello', // deliberately the flipped/meaning-side prompt
        options: ['Hola', 'Casa'],
        correctIndex: 0,
        vocabId: 'w1',
      ),
    ];
    final items = VocabPreviewBuilder.fromFunQuestions(questions, wordPool: _words);
    expect(items.single.word, 'Hola'); // real word, not the question's prompt
    expect(items.single.meaning, 'Hello');
  });

  test('fromWordMatchingPairs builds one item per pair with synthesized ids', () {
    const pairs = [WordPair(left: 'Hola', right: 'Hello'), WordPair(left: 'Casa', right: 'House')];
    final items = VocabPreviewBuilder.fromWordMatchingPairs(pairs);
    expect(items, hasLength(2));
    expect(items[0].word, 'Hola');
    expect(items[0].meaning, 'Hello');
    expect(items.map((i) => i.id).toSet(), hasLength(2)); // ids are distinct
  });

  test('fromVocabWords maps word/translation/emoji directly', () {
    const word = VocabWord(
      id: 'w3',
      word: 'Agua',
      translation: 'Water',
      languageId: 'es',
      category: 'food',
      emoji: '💧',
    );
    final items = VocabPreviewBuilder.fromVocabWords([word]);
    expect(items.single.word, 'Agua');
    expect(items.single.meaning, 'Water');
    expect(items.single.emoji, '💧');
  });

  test('fromPhrase maps a single phrase', () {
    final item = VocabPreviewBuilder.fromPhrase(_phrases.first);
    expect(item.word, 'Como estas');
    expect(item.meaning, 'How are you');
  });

  test('fromConversation builds a single "what to expect" card', () {
    const conversation = Conversation(
      id: 'conv1',
      title: 'At the Café',
      scenario: 'Ordering coffee',
      languageId: 'es',
      turns: [],
    );
    final item = VocabPreviewBuilder.fromConversation(conversation);
    expect(item.word, 'At the Café');
    expect(item.meaning, 'Ordering coffee');
    expect(item.canSpeak, isFalse, reason: 'an English blurb must not be read aloud in Spanish');
  });

  // Regression: Review Words showed Hola / Gracias / Por Favor twice in
  // "Say Hello" (and Sí twice in "Yes, No, Sorry"). The cards came from
  // two different places — the per-exercise vocab id and the lesson's
  // word-matching set — whose ids never collide, so id-keyed
  // de-duplication let both through. The key is the word itself.
  group('Review Words de-duplication', () {
    test('the same word reached by different ids yields one card', () {
      final fromIds = VocabPreviewBuilder.fromVocabIds(vocabIds: ['w1'], wordPool: _words);
      final fromPairs = VocabPreviewBuilder.fromWordMatchingPairs(
        const [WordPair(left: 'Hola', right: 'Hello')],
      );

      final merged = VocabPreviewBuilder.dedupe([...fromIds, ...fromPairs]);

      expect(merged, hasLength(1));
      expect(merged.single.word, 'Hola');
    });

    test('de-duplication ignores case, spacing and punctuation', () {
      final items = VocabPreviewBuilder.dedupe(const [
        VocabPreviewItem(id: 'a', word: 'Por favor', meaning: 'Please'),
        VocabPreviewItem(id: 'b', word: 'por  favor', meaning: 'Please'),
        VocabPreviewItem(id: 'c', word: '¡Por favor!', meaning: 'Please'),
      ]);
      expect(items, hasLength(1));
    });

    test('distinct words all survive, in first-seen order', () {
      final items = VocabPreviewBuilder.dedupe(const [
        VocabPreviewItem(id: 'a', word: 'Sí', meaning: 'Yes'),
        VocabPreviewItem(id: 'b', word: 'No', meaning: 'No'),
        VocabPreviewItem(id: 'c', word: 'Lo siento', meaning: 'Sorry'),
        VocabPreviewItem(id: 'd', word: 'Sí', meaning: 'Yes'),
        VocabPreviewItem(id: 'e', word: 'No', meaning: 'No'),
      ]);
      expect(items.map((i) => i.word).toList(), ['Sí', 'No', 'Lo siento']);
    });

    test('a word-matching set with a repeated left side yields one card', () {
      final items = VocabPreviewBuilder.fromWordMatchingPairs(
        const [
          WordPair(left: 'Madre', right: 'Mother'),
          WordPair(left: 'Padre', right: 'Father'),
          WordPair(left: 'Madre', right: 'Mother'),
        ],
      );
      expect(items.map((i) => i.word).toList(), ['Madre', 'Padre']);
    });
  });

  group('Listen support', () {
    test('a word card is speakable in the course language', () {
      final items = VocabPreviewBuilder.fromVocabWords(_words, languageId: 'fr');
      expect(items.first.canSpeak, isTrue);
      expect(items.first.ttsLocale, 'fr-FR');
    });

    test('locale falls back to Spanish for an unknown language id', () {
      final items = VocabPreviewBuilder.fromVocabWords(_words, languageId: 'xx');
      expect(items.first.ttsLocale, 'es-ES');
    });
  });
}
