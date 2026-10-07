import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A placeholder for app localizations until proper l10n is set up
class S {
  const S();

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en', ''),
    Locale('ar', ''),
    Locale('fr', ''),
  ];

  String get appName => 'NEOS Client';
  String get login => 'Login';
  String get register => 'Register';
  String get home => 'Home';
  String get profile => 'Profile';
  String get settings => 'Settings';
  String get logout => 'Logout';
  
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => S.supportedLocales.contains(locale);

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(const S());
  }

  @override
  bool shouldReload(AppLocalizationDelegate old) => false;
}
