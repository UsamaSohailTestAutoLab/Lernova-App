import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/course.dart';
import '../../../data/repositories/content_providers.dart';
import '../application/onboarding_controller.dart';

class PlacementTestScreen extends ConsumerStatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  ConsumerState<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends ConsumerState<PlacementTestScreen> {
  int _index = 0;
  int? _selected;
  final Set<int> _correctUnlocks = {};
  bool _finishing = false;

  Future<void> _finish(int unlockedUnitIndex) async {
    setState(() => _finishing = true);
    final controller = ref.read(onboardingProvider.notifier);
    if (unlockedUnitIndex >= 0) {
      controller.setPlacementResult(unlockedUnitIndex);
    } else {
      controller.skipPlacement();
    }
    await controller.finish();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  void _submitAnswer(PlacementQuestion question, List<PlacementQuestion> all) {
    if (_selected == question.correctIndex) {
      _correctUnlocks.add(question.unlocksUnitIndex);
    }
    if (_index == all.length - 1) {
      final best = _correctUnlocks.isEmpty
          ? 0
          : _correctUnlocks.reduce((a, b) => a > b ? a : b);
      _finish(best);
    } else {
      setState(() {
        _index++;
        _selected = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selections = ref.watch(onboardingProvider);
    final languageId = selections.languageId;
    if (languageId == null) {
      return const Scaffold(body: Center(child: Text('No language selected')));
    }

    final courseAsync = ref.watch(courseByLanguageProvider(languageId));

    return Scaffold(
      appBar: AppBar(title: const Text('Quick placement test')),
      body: SafeArea(
        child: courseAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => ErrorStateView(
            message: 'Could not load the placement test.',
            onRetry: () => ref.invalidate(courseByLanguageProvider(languageId)),
          ),
          data: (course) {
            final questions = course?.placementQuestions ?? [];
            if (questions.isEmpty) {
              return _SkipOnlyView(onSkip: () => _finish(-1), isLoading: _finishing);
            }
            final question = questions[_index];

            return Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.xl),
                    child: LinearProgressIndicator(
                      value: (_index + 1) / questions.length,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Question ${_index + 1} of ${questions.length}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(question.prompt, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xl),
                  Expanded(
                    child: ListView.separated(
                      itemCount: question.options.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) {
                        final selected = _selected == i;
                        return _OptionTile(
                          label: question.options[i],
                          selected: selected,
                          onTap: () => setState(() => _selected = i),
                        );
                      },
                    ),
                  ),
                  PrimaryButton(
                    label: _index == questions.length - 1 ? 'Finish' : 'Next',
                    isLoading: _finishing,
                    onPressed: _selected == null
                        ? null
                        : () => _submitAnswer(question, questions),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: AppTextButton(
                      label: "Skip — I'm a complete beginner",
                      onPressed: _finishing ? null : () => _finish(-1),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SkipOnlyView extends StatelessWidget {
  final VoidCallback onSkip;
  final bool isLoading;
  const _SkipOnlyView({required this.onSkip, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_rounded, size: 56, color: AppColors.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              "This course doesn't have a placement test yet.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: 'Start from the beginning', isLoading: isLoading, onPressed: onSkip),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? primary.withValues(alpha: 0.1) : null,
          border: Border.all(
            color: selected ? primary : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
