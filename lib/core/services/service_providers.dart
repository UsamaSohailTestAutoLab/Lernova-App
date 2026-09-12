import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_course_repository.dart';
import '../../data/local/local_fun_content_repository.dart';
import '../../data/local/local_leaderboard_repository.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/fun_content_repository.dart';
import '../../data/repositories/leaderboard_repository.dart';
import 'local_storage_service.dart';
import 'stt_service.dart';
import 'tts_service.dart';
import 'notification_permission_service.dart';

/// Overridden in `main()` once [LocalStorageService.create] resolves, so
/// every other provider can depend on it synchronously.
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('localStorageServiceProvider must be overridden');
});

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return LocalCourseRepository();
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LocalLeaderboardRepository();
});

final funContentRepositoryProvider = Provider<FunContentRepository>((ref) {
  return LocalFunContentRepository();
});

final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>((ref) {
  return const NotificationPermissionService();
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

final sttServiceProvider = Provider<SttService>((ref) {
  final service = SttService();
  ref.onDispose(service.dispose);
  return service;
});
