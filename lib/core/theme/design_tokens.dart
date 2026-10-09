import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Design tokens for the DAYCO UI.
///
/// Every spacing, radius, elevation and touch-target value in the app should
/// come from here rather than being typed inline. Before this file existed the
/// same screen mixed radii of 8, 10, 12, 14, 16 and 20 and elevations of 4 and
/// 6 with no rule behind the choice, which is why surfaces never looked like
/// they belonged to one product.
///
/// The scale is a 4pt grid. Use the named steps; if a value is not on the
/// scale, the layout is usually what needs fixing, not the token.
abstract final class AppSpacing {
  /// 4 — hairline gaps inside a chip or between an icon and its label.
  static const double xxs = 4;

  /// 8 — gap between tightly related items (icon ➜ text).
  static const double xs = 8;

  /// 12 — gap between fields in a form row.
  static const double sm = 12;

  /// 16 — the default gutter. Screen padding and the gap between form fields.
  static const double md = 16;

  /// 20 — gap between a section's heading and its body.
  static const double lg = 20;

  /// 24 — gap between major sections.
  static const double xl = 24;

  /// 32 — gap before a terminal action (submit button).
  static const double xxl = 32;
}

/// Corner radii. Three steps only — more than that reads as inconsistency.
abstract final class AppRadius {
  /// 8 — chips, badges, small inline surfaces.
  static const double sm = 8;

  /// 12 — the default. Buttons, fields, tiles, cards.
  static const double md = 12;

  /// 20 — sheets and full-screen overlays that need to feel like a layer.
  static const double lg = 20;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);

  /// Top-only rounding for bottom sheets.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}

/// Shadow presets.
///
/// Elevation carries meaning: [surface] for things resting on the page,
/// [raised] for things floating over the map, [overlay] for modal layers.
/// Picking by meaning instead of by number is what keeps depth consistent.
abstract final class AppElevation {
  static List<BoxShadow> get surface => const [
    BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2)),
  ];

  static List<BoxShadow> get raised => const [
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> get overlay => const [
    BoxShadow(color: Color(0x26000000), blurRadius: 28, offset: Offset(0, 8)),
  ];
}

/// Accessibility constants that are requirements, not preferences.
abstract final class AppA11y {
  /// WCAG 2.1 AA §2.5.5 Target Size: 44x44 CSS px. Material's own guidance is
  /// 48dp, so we take the stricter of the two. Any tappable control must be at
  /// least this tall, even when its visual box looks smaller — pad it out.
  static const double minTouchTarget = 48;

  /// The smallest type we allow. Below this, text fails at the 200% zoom check
  /// on small devices.
  static const double minFontSize = 12;
}

/// The semantic colour roles.
///
/// [ColorManager] holds the raw brand palette and stays the source of brand
/// identity. This layer says *where a colour may be used*, which the raw
/// palette cannot express — and that distinction is what fixes the contrast
/// failures.
///
/// Measured against white (#FFFFFF) with the WCAG relative-luminance formula:
///
/// | Role             | Hex      | On white | Verdict              |
/// |------------------|----------|----------|----------------------|
/// | `brand`          | #008DD2  | 3.66:1   | fills/large text only|
/// | `brandInk`       | #00689B  | 6.08:1   | AA for body text     |
/// | `brandStrong`    | #007DBB  | 4.52:1   | AA for white-on-fill |
/// | `success`        | #009846  | 3.76:1   | fills only           |
/// | `successStrong`  | #00893F  | 4.52:1   | AA for white-on-fill |
/// | `danger`         | #E31E24  | 4.69:1   | AA both ways         |
/// | `textSecondary`  | #626D77  | 5.29:1   | AA                   |
/// | `textTertiary`   | #6B7680  | 4.64:1   | AA                   |
///
/// The rule: **never put `brand` on white as text.** It is a fill colour. Use
/// `brandInk` for anything a user has to read, `brandStrong` behind white text.
abstract final class AppPalette {
  // --- Brand -------------------------------------------------------------
  /// Raw brand blue. Large icons, fills, decorative accents — never body text
  /// on a light surface (3.66:1 fails AA's 4.5:1).
  static const Color brand = ColorManager.primaryColor;

  /// Brand blue darkened to 6.08:1 on white. This is the one to use for text,
  /// links and any icon that carries meaning on a light background.
  static const Color brandInk = Color(0xFF00689B);

  /// Brand blue darkened to exactly clear 4.5:1 with white on top. Use as the
  /// fill behind white label text (primary buttons).
  static const Color brandStrong = Color(0xFF007DBB);

  /// 12% brand tint for selected rows and icon chips. Decorative only.
  static Color get brandSurface => brand.withValues(alpha: 0.12);

  // --- Status ------------------------------------------------------------
  static const Color success = ColorManager.successColor;

  /// Replaces the bare `Colors.green` used on the confirm-position button,
  /// which was 2.78:1 with white text — the worst contrast in the app.
  static const Color successStrong = Color(0xFF00893F);

  static const Color danger = ColorManager.errorColor;

  /// Amber darkened to 4.53:1 on white.
  ///
  /// Replaces the raw `Colors.orange` (#FF9800) that `ProductModel` used for
  /// the "low stock" badge — at **2.16:1** it was the worst contrast in the
  /// app, and amber is the hardest hue to make readable on white.
  static const Color warningInk = Color(0xFFAB6600);

  /// 12% tints, for status badge backgrounds. Decorative: the label on top
  /// supplies the contrast, and the matching `*Ink` colour is what to use for
  /// it.
  static Color tintOf(Color base) => base.withValues(alpha: 0.12);

  // --- Text --------------------------------------------------------------
  static const Color textPrimary = ColorManager.textPrimary;
  static const Color textSecondary = ColorManager.textSecondary;

  /// Lightened grey that still clears AA. The old #898989 was 3.50:1 and
  /// failed for the metadata text it was used on.
  static const Color textTertiary = Color(0xFF6B7680);

  static const Color onBrand = Colors.white;

  // --- Surfaces ----------------------------------------------------------
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF5F7F9);
  static const Color border = Color(0xFFDDE3E8);

  /// Scrim behind modal overlays. 0.55 keeps the map legible underneath while
  /// still passing a 3:1 boundary against the dialog surface.
  static Color get scrim => Colors.black.withValues(alpha: 0.55);
}
