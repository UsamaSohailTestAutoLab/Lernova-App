import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../data/models/vocab_preview_item.dart';
import '../../../data/models/vocab_preview_nav_args.dart';

/// Sends a retry through the shared Review Words step on its way back
/// into play.
///
/// Every "Play Again" / "Try Again" / "Practice Mistakes" button used to
/// jump straight to the gameplay route, which meant a learner who had
/// just got words wrong was asked the same questions again with nothing
/// new to answer them *with*. Re-showing the words is the part that
/// makes a retry worth taking.
///
/// Deliberately passes no `previewKey`. That key exists to make a
/// level's *first* review compulsory and later ones skippable; a retry's
/// review is always skippable, and its word set can differ every time
/// (Practice Mistakes covers only what was just missed), so there is
/// nothing stable to remember as "already seen".
void pushRetryPreview(
  BuildContext context, {
  required List<VocabPreviewItem> items,
  required String levelLabel,
  required String onStartRoute,
  Object? onStartExtra,
}) {
  // Nothing resolvable to show (an unrecognised id, an empty pool) —
  // never strand the player on an empty review screen.
  if (items.isEmpty) {
    context.pushReplacement(onStartRoute, extra: onStartExtra);
    return;
  }
  context.pushReplacement(
    AppRoutes.vocabPreview,
    extra: VocabPreviewNavArgs(
      items: items,
      levelLabel: levelLabel,
      onStartRoute: onStartRoute,
      onStartExtra: onStartExtra,
    ),
  );
}
