import 'package:flutter/material.dart';

/// Animation and transition configuration for the app
class AppAnimationConfig {
  AppAnimationConfig._();

  /// Default page transition theme
  static const PageTransitionsTheme pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  /// Enhanced page route configuration
  static Route<T> createRoute<T extends Object?>({
    required Widget page,
    RouteSettings? settings,
    Curve curve = Curves.easeInOutCubic,
    Duration duration = const Duration(milliseconds: 350),
    TransitionType type = TransitionType.slideRight,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration:
          Duration(milliseconds: duration.inMilliseconds ~/ 1.2),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
          reverseCurve: curve.flipped,
        );

        switch (type) {
          case TransitionType.slideRight:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );

          case TransitionType.slideLeft:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.0, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );

          case TransitionType.slideUp:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );

          case TransitionType.slideDown:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, -1.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );

          case TransitionType.fade:
            return FadeTransition(
              opacity: curvedAnimation,
              child: child,
            );

          case TransitionType.scale:
            return ScaleTransition(
              scale: Tween<double>(
                begin: 0.8,
                end: 1.0,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: curvedAnimation,
                child: child,
              ),
            );

          case TransitionType.rotation:
            return RotationTransition(
              turns: Tween<double>(
                begin: 0.8,
                end: 1.0,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: curvedAnimation,
                child: child,
              ),
            );
        }
      },
    );
  }

  /// Hero animation configuration
  static Widget createHeroTransition({
    required String tag,
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (
        BuildContext flightContext,
        Animation<double> animation,
        HeroFlightDirection flightDirection,
        BuildContext fromHeroContext,
        BuildContext toHeroContext,
      ) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.scale(
              scale: Tween<double>(
                begin: 0.8,
                end: 1.0,
              )
                  .animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ))
                  .value,
              child: child,
            );
          },
          child: toHeroContext.widget,
        );
      },
      child: child,
    );
  }
}

/// Types of page transitions available
enum TransitionType {
  slideRight,
  slideLeft,
  slideUp,
  slideDown,
  fade,
  scale,
  rotation,
}

/// Custom curve definitions for specific use cases
class AppTransitionCurves {
  AppTransitionCurves._();

  /// Smooth entry for auth flows
  static const Curve authEntry = Curves.easeOutCubic;

  /// Dashboard transition curve
  static const Curve dashboard = Curves.fastOutSlowIn;

  /// Modal presentation curve
  static const Curve modal = Curves.elasticOut;

  /// Form slide-up curve
  static const Curve form = Curves.easeOutBack;

  /// Quick feedback curve
  static const Curve feedback = Curves.decelerate;

  /// Bouncy interaction curve
  static const Curve bouncy = Curves.bounceOut;

  /// Natural motion curve
  static const Curve natural = Curves.easeInOutCubic;
}

/// Predefined animation durations
class AppTransitionDurations {
  AppTransitionDurations._();

  /// Instant feedback (200ms)
  static const Duration instant = Duration(milliseconds: 200);

  /// Quick transition (300ms)
  static const Duration quick = Duration(milliseconds: 300);

  /// Standard transition (350ms)
  static const Duration standard = Duration(milliseconds: 350);

  /// Smooth transition (500ms)
  static const Duration smooth = Duration(milliseconds: 500);

  /// Slow transition (600ms)
  static const Duration slow = Duration(milliseconds: 600);

  /// Extra slow for special cases (800ms)
  static const Duration extraSlow = Duration(milliseconds: 800);
}
