// Replaces the Flutter template's "Counter increments smoke test", which was
// never adapted to this app: it pumped `MyApp` and looked for a '0' counter and
// a '+' button that DAYCO does not have, so it could only ever fail.
//
// What is worth pinning instead is `AppAnimationConfig.pageTransitionsTheme`.
// It is a `const` map built from four different `PageTransitionsBuilder`
// classes that live in three different Flutter libraries, and the app failed to
// compile outright when one of them (`CupertinoPageTransitionsBuilder`, exported
// only by package:flutter/cupertino.dart) was referenced without its import.
// Being const, a mistake there is a build failure rather than a runtime one, so
// this test is really a compile-time guard with assertions attached.

// The same import the app needs: material does not re-export this builder.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayco_mobile/core/theme/animation_config.dart';

void main() {
  group('AppAnimationConfig.pageTransitionsTheme', () {
    const theme = AppAnimationConfig.pageTransitionsTheme;

    test('defines a transition for every platform the app ships on', () {
      // A missing entry silently falls back to Flutter's default builder, which
      // is how a platform ends up animating differently from the rest.
      // Fuchsia is deliberately absent -- DAYCO does not target it -- so this
      // asserts the five that are configured rather than TargetPlatform.values.
      expect(
        theme.builders.keys.toSet(),
        {
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.linux,
          TargetPlatform.macOS,
          TargetPlatform.windows,
        },
      );
      expect(theme.builders.containsKey(TargetPlatform.fuchsia), isFalse);
    });

    test('uses the Cupertino builder on the platforms that expect it', () {
      // This is the class whose missing import broke the build.
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        expect(
          theme.builders[platform],
          isA<CupertinoPageTransitionsBuilder>(),
          reason: '$platform should slide like Cupertino',
        );
      }
    });

    test('falls back to a fade on desktop platforms', () {
      for (final platform in const [
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          theme.builders[platform],
          isA<FadeUpwardsPageTransitionsBuilder>(),
          reason: '$platform has no Cupertino idiom to match',
        );
      }
    });

    test('is usable as a const in a ThemeData', () {
      // Guards the property the app actually relies on: ThemeData accepts it
      // without throwing, which is what main.dart does at startup.
      final data = ThemeData(pageTransitionsTheme: theme);

      expect(data.pageTransitionsTheme.builders, isNotEmpty);
    });
  });
}
