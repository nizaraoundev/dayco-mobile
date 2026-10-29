import 'package:flutter/material.dart';

import 'app_gradients.dart';
import 'app_theme.dart';

/// The app's own colour roles, carried on [ThemeData] so a widget can read
/// them without knowing which brightness it is being drawn in.
///
/// Material's [ColorScheme] covers primary/surface/error and little else. The
/// roles this app actually reaches for every day — the fill behind a search
/// field, the soft tint behind a selected filter chip, the four status colours
/// and the pale containers they sit in, the three text tiers, the white panel
/// floating over the map — have no slot there. Without somewhere to put them
/// every page invented its own, which is how the UI ended up with
/// `Colors.grey[600]` as its secondary text colour and `Colors.orange` as its
/// warning: both of them Flutter's palette rather than ours, and neither of
/// them legible once the screen goes dark.
///
/// Read these through `context.dayco` rather than the static light/dark
/// instances, so a screen keeps working when the theme flips.
@immutable
class DaycoColors extends ThemeExtension<DaycoColors> {
  const DaycoColors({
    required this.brand,
    required this.brandVariant,
    required this.brandAccent,
    required this.brandSurface,
    required this.onBrand,
    required this.pageBackground,
    required this.surface,
    required this.card,
    required this.cardElevated,
    required this.sheet,
    required this.inputFill,
    required this.chipFill,
    required this.selectedFill,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.success,
    required this.successSurface,
    required this.onSuccessSurface,
    required this.warning,
    required this.warningSurface,
    required this.onWarningSurface,
    required this.danger,
    required this.dangerSurface,
    required this.onDangerSurface,
    required this.info,
    required this.infoSurface,
    required this.onInfoSurface,
    required this.mapPanel,
    required this.mapControl,
    required this.scrim,
    required this.shadow,
    required this.brandGradient,
    required this.pageGradient,
    required this.cardGradient,
  });

  // --- Brand -----------------------------------------------------------------

  /// The house blue. Fills, selected states, the colour of anything primary.
  final Color brand;

  /// The deeper blue the brand gradient runs into.
  final Color brandVariant;

  /// The brand blue as *text or an icon*. On a dark screen the fill blue is
  /// too dim to read small, so this one is lifted; in light mode the two are
  /// the same colour.
  final Color brandAccent;

  /// A pale wash of the brand, for the background of something selected.
  final Color brandSurface;

  /// What goes on top of a brand fill.
  final Color onBrand;

  // --- Surfaces --------------------------------------------------------------

  /// The scaffold behind everything.
  final Color pageBackground;

  /// A recessed area inside a page: a toolbar strip, a grouped section.
  final Color surface;

  /// A card at rest.
  final Color card;

  /// A card that has been lifted — a dragged item, a menu, a popup.
  final Color cardElevated;

  /// A bottom sheet or dialog.
  final Color sheet;

  /// The fill of a text field, a search box, a dropdown.
  final Color inputFill;

  /// An unselected chip.
  final Color chipFill;

  /// The fill behind a selected row or tile, when the brand tint would be too
  /// loud — a neutral highlight rather than a coloured one.
  final Color selectedFill;

  // --- Lines -----------------------------------------------------------------

  /// The default hairline: card outlines, field borders.
  final Color border;

  /// A border that has to be seen — a focused field's resting state, the edge
  /// of a control sitting on a photo or a map.
  final Color borderStrong;

  /// A line *between* two things in a list. Lighter than [border] on purpose:
  /// a divider repeated down a list adds up to a lot of ink.
  final Color divider;

  // --- Text ------------------------------------------------------------------

  /// Headings and anything the user is reading to get the answer.
  final Color textPrimary;

  /// Supporting text: a subtitle, a unit, a date.
  final Color textSecondary;

  /// Text that is nearly metadata — a hint, a caption, a placeholder.
  final Color textTertiary;

  /// Text in a control that cannot be used.
  final Color textDisabled;

  // --- Status ----------------------------------------------------------------

  // Each status has three colours, not two, and the distinction matters:
  //
  //  * the status colour itself fills and strokes *large* shapes — a level bar,
  //    a dot, an icon, a 2px left border. It only has to clear 3:1.
  //  * the pale surface is what a pill or a highlighted row is filled with.
  //  * the on-surface colour is the *text* on that pale fill, and it has to
  //    clear 4.5:1 because the text is small.
  //
  // Using the status colour as the text on its own surface is the obvious
  // thing to do and it fails: the mustard on its own pale fill measures
  // 2.1:1, and none of the four light statuses reaches 4.5:1 that way. Hence
  // this third role, which is just the same hue taken darker.

  /// Done, delivered, in stock, online. A fill and stroke colour.
  final Color success;

  /// The pale container a success pill is filled with.
  final Color successSurface;

  /// Text and icons on [successSurface].
  final Color onSuccessSurface;

  /// Needs attention but nothing has gone wrong: stock running low, an order
  /// waiting on someone, a prospect.
  ///
  /// Mustard rather than the brand's pure yellow, which no text is legible on.
  final Color warning;

  /// The pale container a warning pill is filled with.
  final Color warningSurface;

  /// Text and icons on [warningSurface].
  final Color onWarningSurface;

  /// Failed, cancelled, out of stock, over the limit.
  final Color danger;

  /// The pale container a danger pill is filled with.
  final Color dangerSurface;

  /// Text and icons on [dangerSurface].
  final Color onDangerSurface;

  /// Neutral information — a resupply announced, an order moving through.
  final Color info;

  /// The pale container an info pill is filled with.
  final Color infoSurface;

  /// Text and icons on [infoSurface].
  final Color onInfoSurface;

  // --- Map and overlays ------------------------------------------------------

  /// The floating panel over the map: the client sheet, the route summary.
  /// Kept separate from [card] because it is drawn over map tiles and has to
  /// stay opaque in both brightnesses.
  final Color mapPanel;

  /// A round map button — locate me, zoom, layers.
  final Color mapControl;

  /// Behind a modal, and under text laid over an image.
  final Color scrim;

  /// What shadows are tinted with.
  final Color shadow;

  // --- Gradients -------------------------------------------------------------

  /// The house gradient, for brand surfaces.
  final LinearGradient brandGradient;

  /// The page backdrop.
  final LinearGradient pageGradient;

  /// The faint wash on a card that lifts off the page without a border.
  final LinearGradient cardGradient;

  /// Everything needed to draw a status pill: the text colour and the fill it
  /// goes on, in that order.
  ///
  /// Returns the on-surface colour rather than the status colour, because this
  /// pair is for text on a pale fill — see the note above the status fields.
  (Color, Color) statusPair(DaycoStatus status) {
    switch (status) {
      case DaycoStatus.success:
        return (onSuccessSurface, successSurface);
      case DaycoStatus.warning:
        return (onWarningSurface, warningSurface);
      case DaycoStatus.danger:
        return (onDangerSurface, dangerSurface);
      case DaycoStatus.info:
        return (onInfoSurface, infoSurface);
    }
  }

  /// The status colour on its own, for a bar, a dot, an icon or a border.
  Color statusColor(DaycoStatus status) {
    switch (status) {
      case DaycoStatus.success:
        return success;
      case DaycoStatus.warning:
        return warning;
      case DaycoStatus.danger:
        return danger;
      case DaycoStatus.info:
        return info;
    }
  }

  static const DaycoColors light = DaycoColors(
    brand: ColorManager.primaryColor,
    brandVariant: ColorManager.primaryVariant,
    brandAccent: ColorManager.primaryColor,
    brandSurface: Color(0xFFE4F2FB),
    onBrand: ColorManager.white,
    pageBackground: ColorManager.backgroundColor,
    surface: Color(0xFFF1F5F8),
    card: ColorManager.white,
    cardElevated: ColorManager.white,
    sheet: ColorManager.white,
    inputFill: Color(0xFFF1F5F8),
    chipFill: Color(0xFFF1F5F8),
    selectedFill: Color(0xFFE8EEF3),
    border: Color(0xFFDCE3E8),
    borderStrong: Color(0xFFC3CDD5),
    divider: Color(0xFFE8EDF1),
    textPrimary: ColorManager.textPrimary,
    textSecondary: ColorManager.textSecondary,
    textTertiary: ColorManager.textTertiary,
    textDisabled: Color(0xFFB3BDC6),
    success: ColorManager.successColor,
    successSurface: Color(0xFFE3F6EB),
    onSuccessSurface: ColorManager.onSuccessSurface,
    warning: ColorManager.warningColor,
    warningSurface: Color(0xFFFBF1DC),
    onWarningSurface: ColorManager.onWarningSurface,
    danger: ColorManager.errorColor,
    dangerSurface: Color(0xFFFDE8E8),
    onDangerSurface: ColorManager.onErrorSurface,
    info: ColorManager.infoColor,
    infoSurface: Color(0xFFE4F2FB),
    onInfoSurface: ColorManager.onInfoSurface,
    mapPanel: ColorManager.white,
    mapControl: ColorManager.white,
    scrim: Color(0x80000000),
    shadow: ColorManager.shadowColor,
    brandGradient: AppGradients.brand,
    pageGradient: AppGradients.pageLight,
    cardGradient: AppGradients.cardSheen,
  );

  static const DaycoColors dark = DaycoColors(
    brand: ColorManager.primaryColor,
    brandVariant: ColorManager.primaryVariant,
    brandAccent: ColorManager.darkPrimaryColor,
    brandSurface: Color(0xFF13303F),
    onBrand: ColorManager.white,
    pageBackground: ColorManager.darkBackgroundColor,
    surface: ColorManager.darkSurfaceColor,
    card: ColorManager.darkCardColor,
    cardElevated: Color(0xFF212D37),
    sheet: Color(0xFF1A242D),
    inputFill: Color(0xFF1A242D),
    chipFill: Color(0xFF1C2831),
    selectedFill: Color(0xFF243139),
    border: Color(0xFF2A3741),
    borderStrong: Color(0xFF3A4A56),
    divider: Color(0xFF22303A),
    textPrimary: ColorManager.darkTextPrimary,
    textSecondary: ColorManager.darkTextSecondary,
    textTertiary: ColorManager.darkTextTertiary,
    textDisabled: Color(0xFF5A6873),
    success: ColorManager.darkSuccessColor,
    successSurface: Color(0xFF123326),
    onSuccessSurface: ColorManager.darkSuccessColor,
    warning: ColorManager.darkWarningColor,
    warningSurface: Color(0xFF342814),
    onWarningSurface: ColorManager.darkWarningColor,
    danger: ColorManager.darkErrorColor,
    dangerSurface: Color(0xFF3A1618),
    onDangerSurface: ColorManager.darkErrorColor,
    info: ColorManager.darkInfoColor,
    infoSurface: Color(0xFF13303F),
    onInfoSurface: ColorManager.darkInfoColor,
    mapPanel: Color(0xFF1A242D),
    mapControl: Color(0xFF212D37),
    scrim: Color(0xB3000000),
    shadow: Color(0x66000000),
    brandGradient: AppGradients.brand,
    pageGradient: AppGradients.pageDark,
    cardGradient: AppGradients.cardSheenDark,
  );

  @override
  DaycoColors copyWith({
    Color? brand,
    Color? brandVariant,
    Color? brandAccent,
    Color? brandSurface,
    Color? onBrand,
    Color? pageBackground,
    Color? surface,
    Color? card,
    Color? cardElevated,
    Color? sheet,
    Color? inputFill,
    Color? chipFill,
    Color? selectedFill,
    Color? border,
    Color? borderStrong,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? success,
    Color? successSurface,
    Color? onSuccessSurface,
    Color? warning,
    Color? warningSurface,
    Color? onWarningSurface,
    Color? danger,
    Color? dangerSurface,
    Color? onDangerSurface,
    Color? info,
    Color? infoSurface,
    Color? onInfoSurface,
    Color? mapPanel,
    Color? mapControl,
    Color? scrim,
    Color? shadow,
    LinearGradient? brandGradient,
    LinearGradient? pageGradient,
    LinearGradient? cardGradient,
  }) {
    return DaycoColors(
      brand: brand ?? this.brand,
      brandVariant: brandVariant ?? this.brandVariant,
      brandAccent: brandAccent ?? this.brandAccent,
      brandSurface: brandSurface ?? this.brandSurface,
      onBrand: onBrand ?? this.onBrand,
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      cardElevated: cardElevated ?? this.cardElevated,
      sheet: sheet ?? this.sheet,
      inputFill: inputFill ?? this.inputFill,
      chipFill: chipFill ?? this.chipFill,
      selectedFill: selectedFill ?? this.selectedFill,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      onSuccessSurface: onSuccessSurface ?? this.onSuccessSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      onWarningSurface: onWarningSurface ?? this.onWarningSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      onDangerSurface: onDangerSurface ?? this.onDangerSurface,
      info: info ?? this.info,
      infoSurface: infoSurface ?? this.infoSurface,
      onInfoSurface: onInfoSurface ?? this.onInfoSurface,
      mapPanel: mapPanel ?? this.mapPanel,
      mapControl: mapControl ?? this.mapControl,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
      brandGradient: brandGradient ?? this.brandGradient,
      pageGradient: pageGradient ?? this.pageGradient,
      cardGradient: cardGradient ?? this.cardGradient,
    );
  }

  @override
  DaycoColors lerp(ThemeExtension<DaycoColors>? other, double t) {
    if (other is! DaycoColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    LinearGradient g(LinearGradient a, LinearGradient b) =>
        LinearGradient.lerp(a, b, t) ?? (t < 0.5 ? a : b);

    return DaycoColors(
      brand: c(brand, other.brand),
      brandVariant: c(brandVariant, other.brandVariant),
      brandAccent: c(brandAccent, other.brandAccent),
      brandSurface: c(brandSurface, other.brandSurface),
      onBrand: c(onBrand, other.onBrand),
      pageBackground: c(pageBackground, other.pageBackground),
      surface: c(surface, other.surface),
      card: c(card, other.card),
      cardElevated: c(cardElevated, other.cardElevated),
      sheet: c(sheet, other.sheet),
      inputFill: c(inputFill, other.inputFill),
      chipFill: c(chipFill, other.chipFill),
      selectedFill: c(selectedFill, other.selectedFill),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      divider: c(divider, other.divider),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textDisabled: c(textDisabled, other.textDisabled),
      success: c(success, other.success),
      successSurface: c(successSurface, other.successSurface),
      onSuccessSurface: c(onSuccessSurface, other.onSuccessSurface),
      warning: c(warning, other.warning),
      warningSurface: c(warningSurface, other.warningSurface),
      onWarningSurface: c(onWarningSurface, other.onWarningSurface),
      danger: c(danger, other.danger),
      dangerSurface: c(dangerSurface, other.dangerSurface),
      onDangerSurface: c(onDangerSurface, other.onDangerSurface),
      info: c(info, other.info),
      infoSurface: c(infoSurface, other.infoSurface),
      onInfoSurface: c(onInfoSurface, other.onInfoSurface),
      mapPanel: c(mapPanel, other.mapPanel),
      mapControl: c(mapControl, other.mapControl),
      scrim: c(scrim, other.scrim),
      shadow: c(shadow, other.shadow),
      brandGradient: g(brandGradient, other.brandGradient),
      pageGradient: g(pageGradient, other.pageGradient),
      cardGradient: g(cardGradient, other.cardGradient),
    );
  }
}

/// The four status roles, for callers that carry a status around and only
/// resolve it to colours at the point of drawing.
enum DaycoStatus { success, warning, danger, info }

/// Reaching the app's colours and text styles off a [BuildContext].
///
/// `context.dayco.textSecondary` is short enough to be used instead of
/// `Colors.grey[600]`, which is the whole point: a token nobody reaches for
/// loses to the shortcut.
extension DaycoThemeContext on BuildContext {
  /// The app's colour roles for the brightness this widget is drawn in.
  ///
  /// Falls back to the light set rather than throwing, so a widget pumped in a
  /// bare [MaterialApp] — a test, a preview — still renders.
  DaycoColors get dayco =>
      Theme.of(this).extension<DaycoColors>() ?? DaycoColors.light;

  /// Material's own scheme, for the roles it does cover.
  ColorScheme get scheme => Theme.of(this).colorScheme;

  /// The app's text styles, already coloured for this brightness.
  TextTheme get texts => Theme.of(this).textTheme;

  /// Whether this widget is being drawn in the dark theme.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
