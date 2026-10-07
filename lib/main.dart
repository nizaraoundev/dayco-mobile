import 'package:dayco_mobile/core/theme/animation_config.dart';
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
    return SafeArea(
      child: GetMaterialApp(
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
        theme: ThemeData(
          useMaterial3: true,
          pageTransitionsTheme: AppAnimationConfig.pageTransitionsTheme,
          // Enhanced visual feedback for interactions
          splashFactory: InkRipple.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.black.withOpacity(0.1),
          // Smooth curves for all animations
          platform: TargetPlatform.android,
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
