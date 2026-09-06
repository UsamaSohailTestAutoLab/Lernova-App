import '../models/fun/conversation.dart';
import '../models/fun/phrase.dart';
import '../models/fun/vocab_word.dart';

abstract class FunContentRepository {
  Future<List<VocabWord>> getVocabWords(String languageId);
  Future<List<Phrase>> getPhrases(String languageId);
  Future<List<Conversation>> getConversations(String languageId);
}
