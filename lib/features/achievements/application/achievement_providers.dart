import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/application/progress_controller.dart';

final unlockedAchievementsProvider = Provider<Set<String>>((ref) {
  return ref.watch(progressProvider).unlockedAchievementIds;
});
