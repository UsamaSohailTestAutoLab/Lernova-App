import '../../../core/constants/app_enums.dart';

/// Passed as `extra` through go_router to the Fun intro/play/results
/// routes.
class FunGameNavArgs {
  final FunGameMode mode;
  const FunGameNavArgs({required this.mode});
}
