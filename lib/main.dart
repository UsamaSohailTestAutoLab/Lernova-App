import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/service_providers.dart';
import 'core/theme/app_theme.dart';
import 'data/models/app_settings.dart';
import 'features/settings/application/purchase_controller.dart';
import 'features/settings/application/settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await LocalStorageService.create();

  runApp(
    ProviderScope(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      child: const LernovaApp(),
    ),
  );
}

class LernovaApp extends ConsumerWidget {
  const LernovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));

    // The purchase stream is opened at launch, not when the Pro screen
    // opens: a store can deliver a transaction that completed while the
    // app was closed — a pending purchase that later cleared, or a
    // subscription bought on another device. Missing those would leave
    // someone paying for Pro without having it.
    ref.watch(purchaseProvider);

    return MaterialApp.router(
      title: 'Lernova',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: router,
    );
  }
}
