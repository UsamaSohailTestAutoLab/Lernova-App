import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lernova_parrot.dart';
import '../application/onboarding_controller.dart';
import '../../progress/application/progress_controller.dart';
import '../application/user_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decideNext());
  }

  Future<void> _decideNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // No accounts to check any more — onboarding completion alone
    // decides between "carry on learning" and "first run".
    final onboardingComplete = ref.read(isOnboardingCompleteProvider);
    if (!onboardingComplete) {
      context.go(AppRoutes.welcome);
      return;
    }

    // An install from before languages could be switched has progress
    // with nothing saying which language it belongs to. Label it with
    // whatever the profile is learning, so the first switch parks it
    // under the right course instead of misfiling it.
    final languageId = ref.read(userProvider).selectedLanguageId;
    if (languageId != null) {
      ref.read(progressProvider.notifier).adoptActiveLanguage(languageId);
    }

    // Someone who finished onboarding before the name step existed is
    // still carrying the placeholder profile name. Ask for just that,
    // once — re-running the whole flow would discard the language, goal
    // and placement they already chose.
    if (!UserController.hasRealName(ref.read(userProvider))) {
      context.go(AppRoutes.nameEntry, extra: true);
      return;
    }

    context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LernovaParrot(size: 120, mood: LernovaParrotMood.celebrate),
              const SizedBox(height: 20),
              Text(
                'Lernova',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
