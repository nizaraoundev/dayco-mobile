import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Every gradient in the app, in one place.
///
/// The app leans on gradients for its brand surfaces — the login brand panel,
/// section headers, the speed-dial buttons, status pills. Left to each page
/// they drifted: different angles, different lightness steps, some of them
/// flat-to-flat pairs that read as a seam rather than a gradient. They are
/// derived here from a single formula instead, so a new surface matches the
/// existing ones without anyone having to pick two colours by eye.
///
/// The direction is always top-left to bottom-right. That is the one the login
/// panel established, and a gradient that changes direction between two
/// adjacent surfaces reads as a lighting mistake.
class AppGradients {
  AppGradients._();

  static const Alignment _begin = Alignment.topLeft;
  static const Alignment _end = Alignment.bottomRight;

  /// How far either end of a derived gradient moves away from its base colour.
  ///
  /// Lightening less than darkening keeps the gradient's perceived colour on
  /// the base rather than washing it out, which matters because the base is
  /// usually the colour that carries the meaning (a stock level, an order
  /// status, a client kind).
  static const double _lighten = 0.08;
  static const double _darken = 0.14;

  /// A gradient built from one meaningful colour.
  ///
  /// This is the formula `ClientPalette.gradient` used, promoted here so stock
  /// levels, order statuses and client kinds all derive theirs the same way.
  static LinearGradient fromColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return LinearGradient(
      begin: _begin,
      end: _end,
      colors: [
        hsl.withLightness((hsl.lightness + _lighten).clamp(0.0, 1.0)).toColor(),
        hsl.withLightness((hsl.lightness - _darken).clamp(0.0, 1.0)).toColor(),
      ],
    );
  }

  /// The house gradient: product blue into environmental blue.
  ///
  /// Not derived from a single colour — these are two brand
  /// colours in their own right, and the pair is what the login panel and the
  /// app bars already show.
  static const LinearGradient brand = LinearGradient(
    begin: _begin,
    end: _end,
    colors: [ColorManager.primaryColor, ColorManager.primaryVariant],
  );

  /// The brand gradient with the two ends pulled apart, for surfaces tall
  /// enough that [brand] would look almost flat — a full-height side panel,
  /// a sheet header that runs the width of the screen.
  static const LinearGradient brandWide = LinearGradient(
    begin: _begin,
    end: _end,
    colors: [
      Color(0xFF00A3E8),
      ColorManager.primaryColor,
      ColorManager.primaryVariant,
    ],
    stops: [0.0, 0.45, 1.0],
  );

  /// A page backdrop: white falling into a tint of the brand blue. Light
  /// enough to put body text straight on top of.
  static const LinearGradient pageLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      ColorManager.backgroundColor,
      Color(0xFFF2F8FC),
      Color(0xFFE4F1F9),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  /// The same backdrop for dark mode. The brand tint survives as a cool cast
  /// in the lower half rather than a visible blue, because on a dark screen a
  /// tinted backdrop that is actually blue competes with the content.
  static const LinearGradient pageDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      ColorManager.darkBackgroundColor,
      Color(0xFF101A21),
      Color(0xFF12222C),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  /// Status gradients, derived so they stay in step with the flat colours the
  /// palettes expose.
  static LinearGradient get success => fromColor(ColorManager.successColor);
  static LinearGradient get warning => fromColor(ColorManager.warningColor);
  static LinearGradient get danger => fromColor(ColorManager.errorColor);
  static LinearGradient get info => fromColor(ColorManager.infoColor);

  /// A scrim for content laid over a photo or a map: transparent at the top,
  /// opaque enough at the bottom to read white text against.
  static const LinearGradient overlayScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x40000000), Color(0x99000000)],
    stops: [0.0, 0.5, 1.0],
  );

  /// The faint top-to-bottom wash on a card that needs to lift off the page
  /// without a border. Both ends are near-white, so it survives being put next
  /// to a flat white card.
  static const LinearGradient cardSheen = LinearGradient(
    begin: _begin,
    end: _end,
    colors: [Color(0xFFFFFFFF), Color(0xFFF7FAFC)],
  );

  static const LinearGradient cardSheenDark = LinearGradient(
    begin: _begin,
    end: _end,
    colors: [Color(0xFF1B242C), Color(0xFF161F26)],
  );
}
