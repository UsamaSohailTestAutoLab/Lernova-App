import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/fun/conversation.dart';
import '../models/fun/phrase.dart';
import '../models/fun/vocab_word.dart';
import '../repositories/fun_content_repository.dart';

/// Loads Fun-game vocabulary/phrase/country content from bundled JSON
/// assets — same `rootBundle.loadString` pattern as
/// [LocalCourseRepository], one file per language so a new language is
/// a new asset, not new code.
class LocalFunContentRepository implements FunContentRepository {
  final Map<String, List<VocabWord>> _vocabCache = {};
  final Map<String, List<Phrase>> _phraseCache = {};
  final Map<String, List<Conversation>> _conversationCache = {};

  String _vocabAssetPath(String languageId) => 'assets/data/fun/vocab_$languageId.json';
  String _phraseAssetPath(String languageId) => 'assets/data/fun/phrases_$languageId.json';
  String _conversationAssetPath(String languageId) =>
      'assets/data/fun/conversations_$languageId.json';

  @override
  Future<List<VocabWord>> getVocabWords(String languageId) async {
    final cached = _vocabCache[languageId];
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(_vocabAssetPath(languageId));
      final list = jsonDecode(raw) as List;
      final words =
          list.map((e) => VocabWord.fromJson(e as Map<String, dynamic>)).toList();
      _vocabCache[languageId] = words;
      return words;
    } catch (_) {
      // No Fun content authored for this language yet.
      return const [];
    }
  }

  @override
  Future<List<Phrase>> getPhrases(String languageId) async {
    final cached = _phraseCache[languageId];
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(_phraseAssetPath(languageId));
      final list = jsonDecode(raw) as List;
      final phrases =
          list.map((e) => Phrase.fromJson(e as Map<String, dynamic>)).toList();
      _phraseCache[languageId] = phrases;
      return phrases;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<Conversation>> getConversations(String languageId) async {
    final cached = _conversationCache[languageId];
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(_conversationAssetPath(languageId));
      final list = jsonDecode(raw) as List;
      final conversations =
          list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
      _conversationCache[languageId] = conversations;
      return conversations;
    } catch (_) {
      return const [];
    }
  }
}
