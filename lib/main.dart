import 'package:dayco_mobile/core/theme/app_theme.dart';
import 'package:dayco_mobile/localization/app_localizations.dart';
import 'package:dayco_mobile/routes/app_pages.dart';
import 'package:dayco_mobile/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/services/language_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugProfileBuildsEnabled = true;

  try {
    // Initialize language service before running the app
    final languageService = LanguageService();
    await languageService.onInit();
    Get.put(languageService, permanent: true);

    runApp(const MyApp());
  } catch (e) {
    print('Error during app initialization: $e');
    // Run app anyway with minimal setup
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // `top: false` so a page's own app bar paints behind the status bar, which
    // is what the brand-coloured app bar and its transparent-status-bar overlay
    // style both assume. Every page already wraps what it needs in its own
    // SafeArea; the root one is here for the bottom inset.
    return SafeArea(
      top: false,
      child: GetMaterialApp(
        theme: ColorManager.lightTheme,
        darkTheme: ColorManager.darkTheme,
        // Unchanged behaviour: with a dark theme supplied and no mode set,
        // GetMaterialApp already followed the system. The difference is that
        // the dark theme is now the app's own rather than Flutter's.
        themeMode: ThemeMode.system,
        locale: _getLocale(),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        debugShowCheckedModeBanner: false,
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
      ),
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
