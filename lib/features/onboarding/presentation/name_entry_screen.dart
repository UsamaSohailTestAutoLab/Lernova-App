import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/lernova_parrot.dart';
import '../application/onboarding_controller.dart';
import '../application/user_controller.dart';
import 'onboarding_step_scaffold.dart';

/// Asks for the learner's name, once, during first-time onboarding.
///
/// Held in [OnboardingController] rather than written straight to the
/// profile, like every other step: nothing is persisted until
/// `finish()` provisions the real records, so backing out of onboarding
/// never leaves a half-saved profile behind.
class NameEntryScreen extends ConsumerStatefulWidget {
  /// True when this is the *only* thing being asked — someone who
  /// finished onboarding before this step existed, and so is still
  /// carrying the placeholder profile name.
  ///
  /// Re-running the whole onboarding flow for them would throw away a
  /// language, a goal and a placement they already set, so they get this
  /// one screen and go straight back to where they were.
  final bool standalone;

  const NameEntryScreen({super.key, this.standalone = false});

  @override
  ConsumerState<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends ConsumerState<NameEntryScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(onboardingProvider).fullName ?? '');
  final _focus = FocusNode();

  /// Only shown after a submit attempt — flagging "can't be empty" on a
  /// field nobody has typed in yet reads as a telling-off.
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_showError && _controller.text.trim().isNotEmpty) {
        setState(() => _showError = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      _focus.requestFocus();
      return;
    }
    if (widget.standalone) {
      await ref.read(userProvider.notifier).setFullName(name);
      if (!mounted) return;
      context.go(AppRoutes.home);
      return;
    }
    ref.read(onboardingProvider.notifier).setFullName(name);
    context.push(AppRoutes.languageSelection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasName = _controller.text.trim().isNotEmpty;

    return OnboardingStepScaffold(
      stepProgress: widget.standalone ? 1 : 0.2,
      title: "What's your name?",
      subtitle: 'So Lernova can greet you properly.',
      ctaLabel: widget.standalone ? 'Save' : 'Continue',
      // Kept tappable while empty so pressing it explains *why* nothing
      // happened, instead of leaving a dead button with no reason given.
      onCta: _continue,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: LernovaParrot(size: 110, mood: LernovaParrotMood.happy),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _continue(),
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              prefixIcon: const Icon(Icons.person_rounded),
              errorText: _showError ? 'Please enter your name to continue.' : null,
            ),
          ),
          if (hasName) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nice to meet you, ${_controller.text.trim()}!',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
