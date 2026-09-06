import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/service_providers.dart';

final funVocabWordsProvider = FutureProvider.family(
  (ref, String languageId) =>
      ref.watch(funContentRepositoryProvider).getVocabWords(languageId),
);

final funPhrasesProvider = FutureProvider.family(
  (ref, String languageId) =>
      ref.watch(funContentRepositoryProvider).getPhrases(languageId),
);

final funConversationsProvider = FutureProvider.family(
  (ref, String languageId) =>
      ref.watch(funContentRepositoryProvider).getConversations(languageId),
);
