import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_language.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_snackbar.dart';

class AllClubsMobileApp extends ConsumerWidget {
  const AllClubsMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final language = ref.watch(appLanguageProvider);
    final strings = AppStrings(language);

    return MaterialApp.router(
      title: strings.appTitle,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      locale: language.locale,
      supportedLocales: AppLanguage.values
          .map((item) => item.locale)
          .toList(growable: false),
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
