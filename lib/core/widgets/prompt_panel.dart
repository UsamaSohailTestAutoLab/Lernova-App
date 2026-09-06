import 'package:flutter/material.dart';

import '../theme/app_decor.dart';
import '../theme/app_spacing.dart';

/// - [normal] — today's muted panel look (this replaces 4 copy-pasted
///   `surfaceContainerHighest` + radius-16 containers).
/// - [large] — a bigger, more prominent reading panel.
/// - [quote] — a left accent bar, for a source sentence being translated.
enum PromptEmphasis { normal, large, quote }

/// The "source text" panel shown inside translation/fill-in-blank/
/// sentence-arrangement/speaking exercises — previously reimplemented
/// independently in each of those four files.
class PromptPanel extends StatelessWidget {
  final String text;
  final PromptEmphasis emphasis;
  final Widget? leading;
  final Widget? trailing;
  final Color? tint;

  const PromptPanel({
    super.key,
    required this.text,
    this.emphasis = PromptEmphasis.normal,
    this.leading,
    this.trailing,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = context.decor;
    final bg = tint != null ? decor.tint(tint!) : decor.cardSurfaceRaised;
    final style = emphasis == PromptEmphasis.large
        ? theme.textTheme.titleLarge
        : theme.textTheme.titleMedium;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: emphasis == PromptEmphasis.quote
            ? Border(left: BorderSide(color: theme.colorScheme.primary, width: 4))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ?leading,
          if (leading != null) const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: style)),
          if (trailing != null) ...[const SizedBox(width: AppSpacing.md), trailing!],
        ],
      ),
    );
  }
}
