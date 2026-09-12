import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/lingoquest_parrot.dart';
import '../../../data/models/app_settings.dart';
import '../../fun/application/fun_progress_controller.dart';
import '../../languages/application/language_switch_controller.dart';
import '../../progress/application/progress_controller.dart';
import '../../../core/services/purchase_service.dart';
import '../../reviews/application/review_prompt_controller.dart';
import '../application/purchase_controller.dart';
import '../application/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      // Transparent so the shell's textured backdrop shows through.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: const LingoQuestParrot(size: 64, showWordmark: true),
            ),
          ),
          const _SectionHeader('LingoQuest Pro'),
          // Selling Pro to somebody who already pays for it is the
          // fastest way to make a subscriber feel unseen, so the whole
          // group swaps: the upsell becomes a membership row, restore
          // gives way to the store's manage page.
          Consumer(
            builder: (context, ref, _) {
              final entitlement = ref.watch(progressProvider).proEntitlement;
              if (!entitlement.isActive) {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.workspace_premium_rounded,
                          color: AppColors.accent),
                      title: const Text('Upgrade to Pro'),
                      subtitle: const Text(
                          'Unlock every level on the Path and in the Fun Zone'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(AppRoutes.premium),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final purchase = ref.watch(purchaseProvider);
                        return ListTile(
                          leading: const Icon(Icons.restore_rounded),
                          title: const Text('Restore Purchase'),
                          subtitle: const Text(
                              'Already subscribed? Bring Pro back on this device'),
                          enabled: !purchase.isBusy,
                          // This used to show a snackbar explaining that
                          // purchases restore from the store account,
                          // and then not restore anything. Both stores
                          // require a restore that works.
                          onTap: () =>
                              ref.read(purchaseProvider.notifier).restore(),
                        );
                      },
                    ),
                  ],
                );
              }

              final plan = ProProducts.planLabel(entitlement.productId);
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.verified_rounded,
                        color: AppColors.success),
                    title: const Text('LingoQuest Pro'),
                    subtitle: Text(
                      plan == null ? 'Active' : 'Active · $plan plan',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.premium),
                  ),
                  ListTile(
                    leading: const Icon(Icons.open_in_new_rounded),
                    title: const Text('Manage subscription'),
                    subtitle: const Text('Change your plan or cancel'),
                    onTap: () async {
                      final opened = await ref
                          .read(subscriptionManagerProvider)
                          .openManageSubscriptions(
                            productId: entitlement.productId,
                          );
                      if (!context.mounted || opened) return;
                      AppSnackBar.show(
                        context,
                        'Manage your subscription in your store account settings.',
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const _SectionHeader('Language'),
          Consumer(
            builder: (context, ref, _) {
              final language = ref.watch(activeLanguageProvider);
              return ListTile(
                leading: language == null
                    ? const Icon(Icons.translate_rounded)
                    : Text(
                        language.flagEmoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                title: const Text('Switch language'),
                subtitle: Text(
                  language == null
                      ? 'Choose what to learn'
                      : 'Learning ${language.name} · progress is kept per language',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.languages),
              );
            },
          ),
          const _SectionHeader('Your learning'),
          ListTile(
            leading: const Icon(Icons.insights_rounded),
            title: const Text('Statistics'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.statistics),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Achievements'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.achievements),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('How LingoQuest works'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.onboardingExplainer, extra: true),
          ),
          const _SectionHeader('Preferences'),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_themeLabel(settings.themeMode)),
            trailing: DropdownButton<AppThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox.shrink(),
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(mode);
                }
              },
              items: AppThemeMode.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(_themeLabel(m))))
                  .toList(),
            ),
          ),
          SwitchListTile(
            title: const Text('Sound effects'),
            value: settings.soundEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier).toggleSound(v),
          ),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            value: settings.hapticsEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier).toggleHaptics(v),
          ),
          const _SectionHeader('Learning'),
          ListTile(
            title: const Text('Daily XP goal'),
            subtitle: Text('${progress.dailyGoalXp} XP / day'),
            trailing: DropdownButton<DailyGoalXp>(
              value: DailyGoalXp.values.firstWhere(
                (g) => g.xp == progress.dailyGoalXp,
                orElse: () => DailyGoalXp.twenty,
              ),
              underline: const SizedBox.shrink(),
              onChanged: (goal) {
                if (goal != null) {
                  ref.read(progressProvider.notifier).setDailyGoalXp(goal.xp);
                }
              },
              items: DailyGoalXp.values
                  .map((g) => DropdownMenuItem(value: g, child: Text('${g.xp} XP')))
                  .toList(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.notificationSettings),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Your details'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.accountSettings),
          ),
          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.star_outline_rounded),
            title: const Text('Rate LingoQuest'),
            subtitle: const Text('Leave a review on the App Store'),
            trailing: const Icon(Icons.open_in_new_rounded),
            // Opens the write-review page rather than requesting the
            // system prompt. iOS may show nothing at all in response to
            // a review request — it is rate-limited and can be switched
            // off entirely — and a button that silently does nothing is
            // a bug report waiting to happen. Someone who taps this has
            // asked for the page, so they get the page.
            onTap: () async {
              final opened =
                  await ref.read(reviewPromptProvider).openStoreListing();
              if (!context.mounted || opened) return;
              AppSnackBar.show(
                context,
                'The store listing goes live when LingoQuest ships.',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('Support'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => AppSnackBar.show(context, 'Support is coming soon.'),
          ),
          ListTile(
            leading: const Icon(Icons.apps_rounded),
            title: const Text('More Apps'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => AppSnackBar.show(context, 'More apps are coming soon.'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => AppSnackBar.show(context, 'Privacy Policy is coming soon.'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Use'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => AppSnackBar.show(context, 'Terms of Use are coming soon.'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: const Text('EULA'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => AppSnackBar.show(context, 'The EULA is coming soon.'),
          ),
          const _SectionHeader('Developer (testing only)'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  'These bypass real progression to make testing faster. '
                  "They don't change the actual unlock rules — a fresh "
                  'install still progresses normally.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_open_rounded, color: AppColors.info),
                  label: const Text('Unlock all Path units & lessons'),
                  onPressed: () {
                    ref.read(progressProvider.notifier).debugUnlockAllPathLevels();
                    AppSnackBar.show(context, 'Every Path unit and lesson is now open.');
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_open_rounded, color: AppColors.info),
                  label: const Text('Jump Fun difficulty to level 20'),
                  onPressed: () {
                    ref.read(funProgressProvider.notifier).debugUnlockAllFunLevels();
                    AppSnackBar.show(
                      context,
                      'Word Bubble & Word Rush are now level 20 (max question variety).',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  String _themeLabel(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => 'System',
        AppThemeMode.light => 'Light',
        AppThemeMode.dark => 'Dark',
      };
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
