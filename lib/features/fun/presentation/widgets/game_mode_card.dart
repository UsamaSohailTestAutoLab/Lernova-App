import 'package:flutter/material.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'game_mode_art.dart';

/// One game in the Fun Zone grid.
///
/// Each card is its own illustrated panel rather than a row of text on a
/// white tile, so the grid can be read by shape and colour before any of
/// the titles are — which is how somebody picks a game they have played
/// before without reading at all.
///
/// Three rules hold the design together:
///
/// * **Text never sits on artwork.** [GameModeArtwork] keeps its motif
///   low and lays a scrim over the top third. A handsome card whose
///   title you have to squint at is a worse card than a plain one.
/// * **Ink is computed, not chosen.** [inkOn] picks the text colour from
///   the ground's luminance, so all ten palettes stay legible in both
///   themes without ten hand-checked colours.
/// * **The two locks look different**, because they mean different
///   things — see [requiresPro].
class GameModeCard extends StatelessWidget {
  final FunGameMode mode;
  final int level;
  final bool unlocked;

  /// Behind the subscription rather than behind a Fun level.
  ///
  /// Kept apart from [unlocked] because the two locks want opposite
  /// treatments: a level lock tells the learner to go play more, which
  /// they can act on, so the card steps back; a Pro lock is an offer, so
  /// the card keeps its full colour, stays tappable, and opens the
  /// paywall. Showing the thing being sold in greyscale is a poor advert
  /// for it.
  final bool requiresPro;

  final VoidCallback? onTap;

  const GameModeCard({
    super.key,
    required this.mode,
    required this.level,
    required this.unlocked,
    required this.onTap,
    this.requiresPro = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playable = unlocked && mode.isImplemented && !requiresPro;
    final levelLocked = !playable && !requiresPro;

    final ground = artFor(mode).base(theme.brightness);
    final ink = inkOn(ground);
    final onGround = levelLocked ? ink.withValues(alpha: 0.62) : ink;

    final tappable = requiresPro || playable;

    return Semantics(
      button: tappable,
      label: requiresPro
          ? '${mode.title}, locked, unlock with Pro'
          : playable
              ? '${mode.title}, level $level'
              : '${mode.title}, locked until Fun level ${mode.unlockLevel}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Material(
          color: ground,
          child: InkWell(
            // Feedback on the whole card rather than a button inside it:
            // the card is the target, so the ripple should be the card.
            onTap: tappable ? onTap : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GameModeArtwork(mode: mode, muted: levelLocked),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mode.emoji, style: const TextStyle(fontSize: 26)),
                          const Spacer(),
                          _Badge(
                            level: level,
                            requiresPro: requiresPro,
                            levelLocked: levelLocked,
                            ink: ink,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        mode.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: onGround,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Flexible, not Expanded: at a large text size the
                      // title takes two lines and the subtitle gives way
                      // rather than the card overflowing.
                      Flexible(
                        child: Text(
                          _subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: requiresPro
                                ? _proInk(theme.brightness, ink)
                                : onGround.withValues(alpha: 0.8),
                            fontWeight:
                                requiresPro ? FontWeight.w800 : FontWeight.w500,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    if (requiresPro) return 'Unlock with Pro';
    if (!mode.isImplemented) return 'Coming soon';
    if (!unlocked) return 'Reach Fun level ${mode.unlockLevel}';
    return mode.blurb;
  }

  /// The Pro amber, adjusted to stay readable on a pale card.
  ///
  /// [AppColors.accent] is tuned for white and for dark surfaces. On the
  /// lighter grounds here it drops below a comfortable contrast, so it
  /// is deepened toward the card's own ink rather than used raw.
  static Color _proInk(Brightness brightness, Color ink) =>
      brightness == Brightness.dark
          ? AppColors.goldHeading
          : Color.lerp(AppColors.accent, ink, 0.4)!;
}

/// The top-right marker: a level, a Fun-level lock, or a Pro lock.
class _Badge extends StatelessWidget {
  final int level;
  final bool requiresPro;
  final bool levelLocked;
  final Color ink;

  const _Badge({
    required this.level,
    required this.requiresPro,
    required this.levelLocked,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    if (requiresPro) {
      // Gold, and a padlock rather than a medal. A medal says "premium";
      // only a padlock says "locked", and read quickly a lit gold card
      // beside dimmed ones otherwise looks like the *unlocked* one.
      return const _Pill(
        background: AppColors.accent,
        child: Icon(Icons.lock_rounded, size: 14, color: Colors.white),
      );
    }
    if (levelLocked) {
      return _Pill(
        background: ink.withValues(alpha: 0.14),
        child: Icon(
          Icons.lock_rounded,
          size: 14,
          color: ink.withValues(alpha: 0.62),
        ),
      );
    }
    return _Pill(
      background: ink.withValues(alpha: 0.12),
      child: Text(
        'Lv $level',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Color background;
  final Widget child;

  const _Pill({required this.background, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: child,
    );
  }
}
