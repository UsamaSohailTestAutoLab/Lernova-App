import 'package:flutter/foundation.dart';
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
import '../../../data/models/pro_entitlement.dart';
import '../../languages/application/language_switch_controller.dart';
import '../../progress/application/progress_controller.dart';
import '../../../core/services/purchase_service.dart';
import '../application/purchase_controller.dart';
import '../application/settings_controller.dart';
import '../../../core/services/store_links.dart';
import '../../reviews/application/review_prompt_controller.dart';
import 'package:url_launcher/url_launcher.dart';

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
          //
          // Branches on `progress.isPremium` — the same flag the rest of
          // the app (PremiumScreen, the debug tools below) treats as the
          // single source of truth for "does this learner have Pro?".
          // `entitlement.isActive` is read only for display details
          // (trial countdown, plan name) once we already know which
          // branch we're in, never to decide the branch itself — two
          // flags deciding the same on/off state is how they end up
          // disagreeing.
          Consumer(
            builder: (context, ref, _) {
              final progress = ref.watch(progressProvider);
              final entitlement = progress.proEntitlement;
              if (!progress.isPremium) {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.workspace_premium_rounded,
                          color: AppColors.accent),
                      title: const Text('Upgrade to Pro'),
                      subtitle: const Text(
                          'Unlock every level on the  klkjPath and in the Fun Zone'),
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

              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      entitlement.isTrial
                          ? Icons.hourglass_top_rounded
                          : Icons.verified_rounded,
                      color: AppColors.success,
                    ),
                    title: const Text('LingoQuest Pro'),
                    // Subscription *status*, which both stores expect an
                    // app selling a subscription to show somewhere. Not
                    // an upsell: there is nothing here to buy.
                    subtitle: Text(_statusLine(entitlement)),
                    trailing: const Icon(Icons.chevron_right_rounded),
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
            subtitle: Text(
              defaultTargetPlatform == TargetPlatform.android
                  ? 'Leave a review on Google Play'
                  : 'Leave a review on the App Store',
            ),
            trailing: const Icon(Icons.open_in_new_rounded),
            // Opens the write-review page rather than requesting the
            // system prompt. iOS may show nothing at all in response to
            // a review request — it is rate-limited and can be switched
            // off entirely — and a button that silently does nothing is
            // a bug report waiting to happen. Someone who taps this has
            // asked for the page, so they get the page.
            //
            // Routed through ReviewService rather than a hard-coded URL.
            // That is what makes an Android build open Play: the plugin
            // addresses each store the way that store expects — by
            // application id on Android, by numeric id on iOS — and a
            // URL written once is a URL written for whichever platform
            // the author had in mind. This row used to hold an App Store
            // link built from the *developer* id, which opened "The page
            // you're looking for can't be found" on both platforms.
            onTap: () async {
              final opened =
                  await ref.read(reviewPromptProvider).openStoreListing();
              if (opened || !context.mounted) return;
              // iOS before the app exists in App Store Connect: there is
              // genuinely no listing to open yet.
              AppSnackBar.show(
                context,
                'The store listing is not available yet.',
              );
            },
          ),
ListTile(
  leading: const Icon(Icons.support_agent_rounded),
  title: const Text('Support'),
  subtitle: const Text('Contact us for help or feedback'),
  trailing: const Icon(Icons.email_outlined),
  onTap: () => _open(
    context,
    Uri(
      scheme: 'mailto',
      path: 'usamaa.sohaiil@icloud.com',
      queryParameters: {'subject': 'LingoQuest Support'},
    ),
    // Not externalApplication: a mailto: has no browser to hand off to,
    // and forcing that mode fails on a device whose mail client is not
    // registered as an external handler.
    external: false,
    whenUnavailable: 'No email app is set up on this device.',
  ),
),

// Hidden rather than pointed at the wrong shop. On Android this needs
// the Play publisher name, which is not set yet — see
// StoreLinks.playDeveloperName. A row that opens a 404 is worse than
// one that is not there.
if (StoreLinks.hasDeveloperPage)
  ListTile(
    leading: const Icon(Icons.apps_rounded),
    title: const Text('More Apps'),
    subtitle: const Text('Explore our other apps'),
    trailing: const Icon(Icons.open_in_new_rounded),
    onTap: () => _open(
      context,
      StoreLinks.developerPage!,
      whenUnavailable: 'Could not open the store.',
    ),
  ),


            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _open(
                context,
                Uri.parse(
                  'https://www.termsfeed.com/live/7b4e0d1f-580d-4260-9010-91d45f926bc1',
                ),
              ),
            ),
ListTile(
  leading: const Icon(Icons.description_outlined),
  title: const Text('Terms of Use'),
  trailing: const Icon(Icons.open_in_new_rounded),
  onTap: () => _open(
    context,
    Uri.parse(
      'https://www.termsfeed.com/live/bc5a80c1-42f4-4167-9cc0-2e7fc82324be',
    ),
  ),
),

// iOS only. Apple's Licensed Application End User Licence Agreement is
// a term of *its* distribution agreement; showing it in a Play build
// hands an Android user a contract that has nothing to do with how they
// got the app.
if (StoreLinks.showsAppleEula)
  ListTile(
    leading: const Icon(Icons.gavel_rounded),
    title: const Text('EULA'),
    trailing: const Icon(Icons.open_in_new_rounded),
    onTap: () => _open(context, Uri.parse(StoreLinks.appleEulaUrl)),
  ),
          // const _SectionHeader('Developer (testing only)'),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          //   child: Column(
          //     children: [
          //       Text(
          //         'These bypass real progression to make testing faster. '
          //         "They don't change the actual unlock rules — a fresh "
          //         'install still progresses normally.',
          //         style: Theme.of(context).textTheme.bodySmall,
          //       ),
          //       const SizedBox(height: AppSpacing.md),
          //       // What the paywall is actually reading.
          //       //
          //       // A local entitlement outlives the build that granted it
          //       // — the old mock "purchase" button set this and it is
          //       // still in storage — so "why is everything unlocked?" is
          //       // usually this flag, not the gate. Worth being able to
          //       // see and clear rather than guess at.
          //       Consumer(
          //         builder: (context, ref, _) {
          //           final progress = ref.watch(progressProvider);
          //           final entitlement = progress.proEntitlement;
          //           final source = entitlement.isActive
          //               ? entitlement.source.name
          //               : 'none';
          //           return Column(
          //             crossAxisAlignment: CrossAxisAlignment.stretch,
          //             children: [
          //               Container(
          //                 padding: const EdgeInsets.all(AppSpacing.md),
          //                 decoration: BoxDecoration(
          //                   color: context.decor.tint(
          //                     progress.isPremium
          //                         ? AppColors.accent
          //                         : AppColors.info,
          //                   ),
          //                   borderRadius: BorderRadius.circular(AppRadius.md),
          //                 ),
          //                 child: Row(
          //                   children: [
          //                     Icon(
          //                       progress.isPremium
          //                           ? Icons.workspace_premium_rounded
          //                           : Icons.lock_outline_rounded,
          //                       size: 18,
          //                       color: progress.isPremium
          //                           ? AppColors.accent
          //                           : AppColors.info,
          //                     ),
          //                     const SizedBox(width: AppSpacing.sm),
          //                     Expanded(
          //                       child: Text(
          //                         progress.isPremium
          //                             ? 'Pro is ACTIVE (source: $source) — '
          //                                 'the paywall is off for this account.'
          //                             : 'Pro is OFF — free tier: Say Hello, '
          //                                 'and Word Bubble level 1.',
          //                         style: Theme.of(context).textTheme.bodySmall,
          //                       ),
          //                     ),
          //                   ],
          //                 ),
          //               ),
          //               const SizedBox(height: AppSpacing.sm),
          //               // Both directions, because testing the paywall
          //               // means going back and forth across it, and a
          //               // sandbox purchase is a slow way to do that.
          //               //
          //               // A granted entitlement is recorded as
          //               // [ProSource.debug], which launch verification
          //               // deliberately skips — no store will ever replay
          //               // it, so checking would revoke it every time the
          //               // app started.
          //               OutlinedButton.icon(
          //                 icon: Icon(
          //                   progress.isPremium
          //                       ? Icons.lock_reset_rounded
          //                       : Icons.workspace_premium_rounded,
          //                   color: AppColors.info,
          //                 ),
          //                 label: Text(
          //                   progress.isPremium
          //                       ? 'Clear Pro entitlement'
          //                       : 'Grant Pro entitlement',
          //                 ),
          //                 onPressed: () {
          //                   final on = !progress.isPremium;
          //                   ref.read(progressProvider.notifier).setPremium(on);
          //                   AppSnackBar.show(
          //                     context,
          //                     on
          //                         ? 'Pro granted. Everything is unlocked.'
          //                         : 'Pro cleared. The paywall is back on.',
          //                   );
          //                 },
          //               ),
          //             ],
          //           );
          //         },
          //       ),
          //       const SizedBox(height: AppSpacing.sm),
          //       OutlinedButton.icon(
          //         icon: const Icon(Icons.lock_open_rounded, color: AppColors.info),
          //         label: const Text('Unlock all Path units & lessons'),
          //         onPressed: () {
          //           ref.read(progressProvider.notifier).debugUnlockAllPathLevels();
          //           AppSnackBar.show(context, 'Every Path unit and lesson is now open.');
          //         },
          //       ),
          //       const SizedBox(height: AppSpacing.sm),
          //       OutlinedButton.icon(
          //         icon: const Icon(Icons.lock_open_rounded, color: AppColors.info),
          //         label: const Text('Jump Fun difficulty to level 20'),
          //         onPressed: () {
          //           ref.read(funProgressProvider.notifier).debugUnlockAllFunLevels();
          //           AppSnackBar.show(
          //             context,
          //             'Word Bubble & Word Rush are now level 20 (max question variety).',
          //           );
          //         },
          //       ),
          //     ],
          //   ),
          // ),
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

/// Opens [uri], and says so when it cannot.
///
/// Every link in Settings > About used to be its own copy of
/// "if (await canLaunchUrl(x)) launchUrl(x)" — which does nothing at all
/// when the check fails, on a screen made entirely of links. That is the
/// failure the Rate row's own comment warns about, and it was happening
/// to all six: `canLaunchUrl` returns false on Android 11+ for any
/// scheme the manifest has not declared in `<queries>`, so on a modern
/// phone the browser was installed and the app could not be told so.
///
/// The manifest declares them now. This is the other half: if a launch
/// still fails, the learner is told, rather than tapping a dead row and
/// concluding the app is broken.
Future<void> _open(
  BuildContext context,
  Uri uri, {
  bool external = true,
  String whenUnavailable = 'Could not open that link.',
}) async {
  try {
    final opened = await launchUrl(
      uri,
      mode: external ? LaunchMode.externalApplication : LaunchMode.platformDefault,
    );
    if (opened || !context.mounted) return;
  } catch (_) {
    if (!context.mounted) return;
  }
  AppSnackBar.show(context, whenUnavailable);
}

/// One line describing where a member stands.
///
/// Trial-versus-paid is inferred rather than reported by the store (see
/// [ProEntitlement.isTrial]), which is exactly why it appears here and
/// nowhere that grants access: being wrong costs a word in Settings.
String _statusLine(ProEntitlement entitlement) {
  final plan = ProProducts.planLabel(entitlement.productId);
  final planSuffix = plan == null ? '' : ' · $plan plan';

  if (entitlement.isTrial) {
    final endsAt = entitlement.trialEndsAt;
    final daysLeft = endsAt == null
        ? null
        : endsAt.difference(DateTime.now()).inHours / 24.0;
    if (daysLeft != null && daysLeft > 0) {
      final days = daysLeft.ceil();
      return 'Free trial · $days day${days == 1 ? '' : 's'} left$planSuffix';
    }
    return 'Free trial$planSuffix';
  }

  return 'Active$planSuffix';
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