import 'package:dayco_mobile/core/theme/animation_config.dart';
import 'package:dayco_mobile/core/theme/app_theme.dart';
import 'package:dayco_mobile/localization/app_localizations.dart';
import 'package:dayco_mobile/routes/app_pages.dart';
import 'package:dayco_mobile/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/services/language_service.dart';
import 'core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The dependency graph is deliberately *not* built here. Awaiting it before
  // `runApp` blocked the first frame on secure-storage reads and session
  // restore, which measurably delayed cold start. The splash route builds it
  // instead, so the branding is on screen while that work happens.
  //
  // This is safe because the splash is the initial route and does not navigate
  // until `configureDependencies()` has completed, so no other route can reach
  // the locator before it is ready.

  // The language service only needs preferences and decides the initial locale
  // and text direction, so it is resolved before the first build. A failure
  // must not stop the app, but it is logged rather than swallowed.
  try {
    final languageService = LanguageService();
    await languageService.onInit();
    Get.put(languageService, permanent: true);
  } on Object catch (error, stackTrace) {
    AppLogger.error(
      'Language service failed to initialise; falling back to default locale',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Exactly one `runApp`. The previous version called it a second time from a
  // `catch`, which could mount the app twice.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Deliberately *not* wrapped in a SafeArea. Wrapping the whole app inset
    // every screen from the system bars, which letterboxed the application in
    // black and stopped the map from reaching the edges of the display.
    // Each screen handles its own insets — the map and login with their own
    // `SafeArea`, the list screens via `Scaffold`/`AppBar`.
    return GetMaterialApp(
      darkTheme: ThemeData.dark(),
      locale: _getLocale(),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      debugShowCheckedModeBanner: false,
      // `ColorManager.lightTheme` carries the button, input, chip and app-bar
      // themes. It used to be defined and then never applied — this was a
      // bare `ThemeData(useMaterial3: true)`, so every screen fell back to
      // Material's defaults and hand-styled its own buttons to compensate.
      // That is why nothing looked like it came from one app.
      theme: ColorManager.lightTheme.copyWith(
        pageTransitionsTheme: AppAnimationConfig.pageTransitionsTheme,
        splashFactory: InkRipple.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.black.withValues(alpha: 0.1),
      ),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.routes,
      builder: (context, child) {
        final languageCode =
            Get.locale?.languageCode ?? _getLocale().languageCode;
        final textDirection = languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr;
        return Directionality(textDirection: textDirection, child: child!);
      },
    );
  }

  Locale _getLocale() {
    try {
      final languageService = Get.find<LanguageService>();
      return Locale(languageService.getCurrentLanguage());
    } catch (e) {
      // Fallback to English if language service is not available
      return const Locale('en');
    }
  }
}
