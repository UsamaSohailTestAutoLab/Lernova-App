import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';

enum LeaveSessionChoice {
  /// Leave the session and go back where they came from.
  exit,

  /// Leave the session and open the language list.
  switchLanguage,
}

/// The sheet shown when someone tries to leave a lesson or a Fun round.
///
/// It exists because "switch language" has to be reachable *mid-level*,
/// and a running session cannot simply be abandoned underneath a
/// language change — the session has to be torn down first. Offering
/// both exits in one place makes that ordering the only possible one,
/// rather than something each screen has to remember.
///
/// Returns null when the learner decides to stay.
Future<LeaveSessionChoice?> showLeaveSessionSheet(
  BuildContext context, {
  required String title,
  required String message,
  String exitLabel = 'Exit',
}) {
  return showModalBottomSheet<LeaveSessionChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Keep going',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: 'Switch language',
                icon: Icons.translate_rounded,
                onPressed: () => Navigator.of(sheetContext)
                    .pop(LeaveSessionChoice.switchLanguage),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () =>
                    Navigator.of(sheetContext).pop(LeaveSessionChoice.exit),
                child: Text(exitLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
}
