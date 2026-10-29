// Pins the things that went wrong in the theme before, and that nothing else
// would catch:
//
//  * `main.dart` built its own bare `ThemeData` and passed `ThemeData.dark()`,
//    so the palette in `ColorManager` was decoration -- the app ran on
//    Flutter's defaults. Nothing failed; it just looked wrong.
//  * the dark theme stopped after its colour scheme, app bar and text, leaving
//    every button, field, chip and sheet in it on Material's defaults.
//  * `AppTextStyles` named a font family (`Inter`) the app does not bundle, so
//    none of the shipped weights were ever used.
//  * passing a non-null `fontFamily` to `ThemeData` runs `TextTheme.apply`,
//    which overwrites the family on *every* style -- silently undoing the
//    display font on the headings.
//
// All four are invisible at runtime and none is a compile error, which is
// exactly what a test is for.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayco_mobile/core/theme/app_theme.dart';
import 'package:dayco_mobile/core/theme/dayco_colors.dart';
import 'package:dayco_mobile/core/theme/text_styles.dart';

/// WCAG relative luminance.
double _luminance(Color c) => c.computeLuminance();

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  final light = ColorManager.lightTheme;
  final dark = ColorManager.darkTheme;

  group('both themes carry the app palette', () {
    test('expose the DaycoColors extension', () {
      // Without this, every `context.dayco` in the app silently falls back to
      // the light set -- including in dark mode.
      expect(light.extension<DaycoColors>(), isNotNull);
      expect(dark.extension<DaycoColors>(), isNotNull);
    });

    test('the extension matches the theme it is attached to', () {
      expect(light.extension<DaycoColors>(), same(DaycoColors.light));
      expect(dark.extension<DaycoColors>(), same(DaycoColors.dark));
    });

    test('the primary colour is the brand blue, not Material purple', () {
      // ThemeData's own default seeds a purple scheme. If either of these
      // comes back purple, the theme is not being built from this palette.
      expect(light.colorScheme.primary, ColorManager.primaryColor);
      expect(dark.colorScheme.primary, ColorManager.darkPrimaryColor);
    });

    test('the app bar is brand-coloured in both', () {
      expect(light.appBarTheme.backgroundColor, ColorManager.primaryColor);
      expect(dark.appBarTheme.backgroundColor, ColorManager.primaryColor);
      // White contents in both, because the bar is brand-coloured in both.
      expect(light.appBarTheme.foregroundColor, ColorManager.white);
      expect(dark.appBarTheme.foregroundColor, ColorManager.white);
    });
  });

  group('the dark theme is complete', () {
    // The component themes the app actually uses. Every one of these was null
    // in the dark theme before, which is what made dark mode look like a
    // different application.
    test('sets every component theme the light one does', () {
      final checks = <String, bool>{
        'elevatedButton': dark.elevatedButtonTheme.style != null,
        'outlinedButton': dark.outlinedButtonTheme.style != null,
        'textButton': dark.textButtonTheme.style != null,
        'inputDecoration': dark.inputDecorationTheme.fillColor != null,
        'card': dark.cardTheme.color != null,
        'chip': dark.chipTheme.backgroundColor != null,
        'dialog': dark.dialogTheme.backgroundColor != null,
        'bottomSheet': dark.bottomSheetTheme.backgroundColor != null,
        'snackBar': dark.snackBarTheme.backgroundColor != null,
        'tabBar': dark.tabBarTheme.labelColor != null,
        'bottomNavigationBar':
            dark.bottomNavigationBarTheme.backgroundColor != null,
        'floatingActionButton':
            dark.floatingActionButtonTheme.backgroundColor != null,
        'progressIndicator': dark.progressIndicatorTheme.color != null,
        'divider': dark.dividerTheme.color != null,
        'listTile': dark.listTileTheme.textColor != null,
        'drawer': dark.drawerTheme.backgroundColor != null,
      };

      final missing = checks.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList();

      expect(missing, isEmpty, reason: 'unthemed in dark mode: $missing');
    });

    test('is actually dark, not a copy of the light theme', () {
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor,
          isNot(light.scaffoldBackgroundColor));
      expect(_luminance(dark.scaffoldBackgroundColor), lessThan(0.1));
      expect(_luminance(light.scaffoldBackgroundColor), greaterThan(0.9));
    });

    test('keeps the page transitions', () {
      // These used to be set only on the light theme in main.dart, so a page
      // opened in dark mode animated differently.
      expect(light.pageTransitionsTheme.builders, isNotEmpty);
      expect(dark.pageTransitionsTheme.builders, isNotEmpty);
    });
  });

  group('fonts', () {
    const bundled = {'Roboto', 'Montserrat', 'Cairo', 'Tajawal'};

    test('every text style names a font the app bundles', () {
      // `Inter` passed this file's predecessor by not existing. pubspec.yaml is
      // the authority: if a family is not declared there, Flutter silently uses
      // the platform font instead.
      expect(bundled, contains(AppTextStyles.bodyFont));
      expect(bundled, contains(AppTextStyles.titleFont));
      for (final family in AppTextStyles.fallbackFonts) {
        expect(bundled, contains(family));
      }
    });

    test('headings keep the display font through ThemeData', () {
      // The trap: a non-null `fontFamily` on ThemeData runs TextTheme.apply and
      // overwrites the family on every style. If that regresses, these come
      // back as the body font.
      for (final theme in [light, dark]) {
        expect(theme.textTheme.displayLarge?.fontFamily,
            AppTextStyles.titleFont);
        expect(theme.textTheme.headlineSmall?.fontFamily,
            AppTextStyles.titleFont);
        expect(theme.appBarTheme.titleTextStyle?.fontFamily,
            AppTextStyles.titleFont);
      }
    });

    test('body and labels stay on the body font', () {
      for (final theme in [light, dark]) {
        expect(theme.textTheme.bodyMedium?.fontFamily, AppTextStyles.bodyFont);
        expect(theme.textTheme.labelSmall?.fontFamily, AppTextStyles.bodyFont);
        expect(theme.textTheme.titleMedium?.fontFamily, AppTextStyles.bodyFont);
      }
    });

    test('Arabic has a fallback to fall back to', () {
      // Roboto and Montserrat have no Arabic coverage; without a fallback,
      // Arabic renders as boxes with the style otherwise intact.
      for (final theme in [light, dark]) {
        expect(theme.textTheme.bodyMedium?.fontFamilyFallback,
            containsAll(AppTextStyles.fallbackFonts));
      }
    });
  });

  group('colours are legible', () {
    test('body text clears 4.5:1 against the surface it sits on', () {
      for (final entry in {'light': light, 'dark': dark}.entries) {
        final theme = entry.value;
        final colors = theme.extension<DaycoColors>()!;

        for (final pair in {
          'textPrimary on card': (colors.textPrimary, colors.card),
          'textPrimary on page': (colors.textPrimary, colors.pageBackground),
          'textSecondary on card': (colors.textSecondary, colors.card),
        }.entries) {
          final (fg, bg) = pair.value;
          expect(
            _contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: ${pair.key} is '
                '${_contrast(fg, bg).toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('white-on-brand clears 3:1, which an app bar title needs', () {
      for (final colors in [DaycoColors.light, DaycoColors.dark]) {
        expect(_contrast(colors.onBrand, colors.brand),
            greaterThanOrEqualTo(3.0));
      }
    });

    test('the warning colour is the mustard, not the brand yellow', () {
      // `#FFED00` has a luminance around 0.9: white on it is invisible and
      // black on it glares. It stays a brand colour but is not a status fill.
      expect(ColorManager.warningColor, isNot(ColorManager.brandYellow));
      expect(_luminance(ColorManager.warningColor), lessThan(0.5));
    });

    test('each status colour reads against its own container', () {
      for (final colors in [DaycoColors.light, DaycoColors.dark]) {
        for (final status in DaycoStatus.values) {
          final (fg, bg) = colors.statusPair(status);
          expect(
            _contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$status pill: ${_contrast(fg, bg).toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('a divider is a hairline colour, not a text colour', () {
      // `dividerColor` used to hold the same value as `textSecondary`, which
      // draws a one-pixel rule as a hard black line.
      expect(ColorManager.dividerColor, isNot(ColorManager.textSecondary));
      expect(_luminance(ColorManager.dividerColor), greaterThan(0.6));
    });
  });

  group('the themes work in a real widget tree', () {
    for (final entry in {'light': ThemeMode.light, 'dark': ThemeMode.dark}
        .entries) {
      testWidgets('a screen of common widgets builds in ${entry.key} mode',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: light,
            darkTheme: dark,
            themeMode: entry.value,
            home: Scaffold(
              appBar: AppBar(title: const Text('DAYCO')),
              body: ListView(
                children: [
                  const TextField(
                    decoration: InputDecoration(labelText: 'Client'),
                  ),
                  const Card(child: ListTile(title: Text('Stock'))),
                  FilledButton(onPressed: () {}, child: const Text('Valider')),
                  OutlinedButton(onPressed: () {}, child: const Text('Annuler')),
                  Chip(label: const Text('En stock'), onDeleted: () {}),
                  Switch(value: true, onChanged: (_) {}),
                  const LinearProgressIndicator(),
                ],
              ),
              floatingActionButton:
                  FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        // The resolved theme is the app's, not a default: check it through the
        // tree rather than off the ThemeData, so this covers the wiring too.
        final context = tester.element(find.text('DAYCO'));
        expect(context.dayco, isNotNull);
        expect(Theme.of(context).colorScheme.primary,
            entry.value == ThemeMode.dark
                ? ColorManager.darkPrimaryColor
                : ColorManager.primaryColor);
      });
    }
  });
}
