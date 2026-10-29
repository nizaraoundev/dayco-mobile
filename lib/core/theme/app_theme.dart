import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'animation_config.dart';
import 'app_gradients.dart';
import 'dayco_colors.dart';
import 'text_styles.dart';

/// The DAYCO palette, and the two [ThemeData]s built from it.
///
/// Both themes come out of one builder, [_build], so light and dark cannot
/// drift apart — the dark theme used to stop after its colour scheme, app bar
/// and text, which left every button, field, chip, sheet, dialog and snackbar
/// in it falling back to Flutter's defaults.
class ColorManager {
  ColorManager._();

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------

  /// Product blue: the DAYCO logo's own colour, and the app's primary.
  static const Color primaryColor = Color(0xFF008DD2);

  /// Environmental blue. The deep end of the brand gradient, and the colour of
  /// a second-rank brand surface.
  static const Color primaryVariant = Color(0xFF395EA7);

  /// Product teal.
  static const Color secondaryColor = Color(0xFF7ED6C9);

  /// Environmental green. Doubles as the success colour.
  static const Color secondaryVariant = Color(0xFF009846);

  /// Product yellow.
  static const Color tertiaryColor = Color(0xFFFBCB07);

  /// Environmental yellow. A brand colour, not a usable fill: nothing is
  /// legible on it. See [warningColor] for the one to draw a status in.
  static const Color tertiaryVariant = Color(0xFFFFED00);

  /// The brand yellow under a clearer name, for the rare surface that really
  /// wants it — a highlight band, a logo lockup.
  static const Color brandYellow = tertiaryVariant;

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Done, delivered, in stock.
  static const Color successColor = Color(0xFF009846);

  /// Needs attention: stock running low, an order waiting, a prospect.
  ///
  /// Mustard, not the brand's environmental yellow. `#FFED00` has a luminance
  /// of about 0.9 — white text on it is invisible and black text on it glares
  /// — so every feature that needed a warning colour had already picked this
  /// mustard for itself. It is the real token; the brand yellow stays
  /// available as [brandYellow].
  static const Color warningColor = Color(0xFFD4A017);

  /// Environmental red: failed, cancelled, out of stock.
  static const Color errorColor = Color(0xFFE31E24);

  /// Neutral information. A brighter blue than [primaryColor] on purpose, so
  /// an informational badge is not mistaken for a primary action.
  static const Color infoColor = Color(0xFF2F80ED);

  /// The pale containers the four status colours are read against — the fill
  /// of a status pill, the background of a warning row.
  ///
  /// These exist as plain constants, not only on [DaycoColors], because plenty
  /// of the code that needs them runs where there is no [BuildContext]: a
  /// helper that builds a marker, a `const` decoration. They are the light
  /// values; a widget that can reach a context should prefer `context.dayco`,
  /// which also has the dark ones.
  static const Color successSurface = Color(0xFFE3F6EB);
  static const Color warningSurface = Color(0xFFFBF1DC);
  static const Color errorSurface = Color(0xFFFDE8E8);
  static const Color infoSurface = Color(0xFFE4F2FB);

  /// The *text* colour on each of those pale containers.
  ///
  /// Not the status colour itself. A status colour is tuned to fill and stroke
  /// large shapes, and on its own pale container none of the four reaches the
  /// 4.5:1 that small text needs — the mustard manages only 2.1:1. These are
  /// the same four hues taken darker, between 5:1 and 6.7:1.
  static const Color onSuccessSurface = Color(0xFF007535);
  static const Color onWarningSurface = Color(0xFF7A5410);
  static const Color onErrorSurface = Color(0xFFA3161B);
  static const Color onInfoSurface = Color(0xFF1565C0);

  /// A pale wash of the brand, for the background of something selected.
  static const Color brandSurface = Color(0xFFE4F2FB);

  // ---------------------------------------------------------------------------
  // Light neutrals
  // ---------------------------------------------------------------------------

  /// Environmental white: the page behind everything.
  static const Color backgroundColor = Color(0xFFFEFEFE);

  /// A recessed surface — a field fill, a toolbar strip, a grouped section.
  /// Cool rather than the old neutral grey, so it sits under the brand blue
  /// without looking dirty next to it.
  static const Color surfaceColor = Color(0xFFF1F5F8);

  /// A card.
  static const Color cardColor = Color(0xFFFFFFFF);

  /// A hairline. This used to hold the environmental grey `#626D77` — the same
  /// value as [textSecondary] — which is a text colour: a one-pixel rule in it
  /// reads as a hard black line, and it was also doing duty as the resting
  /// border of every text field. Borders are this instead.
  static const Color dividerColor = Color(0xFFDCE3E8);

  /// Environmental grey. Still the right colour for secondary *text*, which is
  /// what it always was; kept under its own name now that [dividerColor] no
  /// longer points at it.
  static const Color neutralGray = Color(0xFF626D77);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// A neutral page or tile fill. Same value as [surfaceColor]; kept because a
  /// good deal of the stock and order UI asks for it by this name.
  static const Color greybg = Color(0xFFF1F5F8);

  /// A light border.
  static const Color lightGrey2 = Color(0xFFDCE3E8);

  /// Near-black text that is not quite a heading.
  static const Color blackLight = Color(0xFF26323B);

  // ---------------------------------------------------------------------------
  // Light text
  // ---------------------------------------------------------------------------

  /// Headings and primary content. A cool near-black rather than pure black:
  /// `#000000` against a white page is harsher than any of the brand colours,
  /// and nothing else in the palette is neutral.
  static const Color textPrimary = Color(0xFF0F1A21);

  /// Subtitles, units, dates.
  static const Color textSecondary = Color(0xFF626D77);

  /// Hints, captions, placeholders.
  static const Color textTertiary = Color(0xFF8A97A3);

  /// On a brand fill.
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// On the teal and yellow brand colours, which are too light for white.
  static const Color textOnSecondary = Color(0xFF0F1A21);

  // ---------------------------------------------------------------------------
  // Dark
  // ---------------------------------------------------------------------------

  /// The dark page. Cooled towards the brand hue rather than neutral `#121212`,
  /// so the blue of the UI reads as deliberate instead of tinted.
  static const Color darkBackgroundColor = Color(0xFF0D141A);
  static const Color darkSurfaceColor = Color(0xFF141E26);
  static const Color darkCardColor = Color(0xFF1A242D);
  static const Color darkDividerColor = Color(0xFF2A3741);
  static const Color darkTextPrimary = Color(0xFFECF2F6);
  static const Color darkTextSecondary = Color(0xFFA8B6C1);
  static const Color darkTextTertiary = Color(0xFF7A8893);

  /// The brand blue lifted for dark mode.
  ///
  /// `#008DD2` on a dark page clears the contrast bar for a large fill but not
  /// for a 12sp label or a 2px icon stroke, which is most of what an accent
  /// colour is used for. Fills keep [primaryColor]; text and icons get this.
  static const Color darkPrimaryColor = Color(0xFF38AEE8);

  /// The status colours, lifted the same way.
  static const Color darkSuccessColor = Color(0xFF2BB673);
  static const Color darkWarningColor = Color(0xFFE8B534);
  static const Color darkErrorColor = Color(0xFFF4565B);
  static const Color darkInfoColor = Color(0xFF4F9DF5);

  // ---------------------------------------------------------------------------
  // Shadows
  // ---------------------------------------------------------------------------

  static const Color shadowColor = Color(0x1A000000);
  static const Color lightShadowColor = Color(0x0D000000);

  // ---------------------------------------------------------------------------
  // Themes
  // ---------------------------------------------------------------------------

  /// The light theme.
  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        c: DaycoColors.light,
        scheme: _lightScheme,
      );

  /// The dark theme.
  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        c: DaycoColors.dark,
        scheme: _darkScheme,
      );

  static const ColorScheme _lightScheme = ColorScheme.light(
    primary: primaryColor,
    onPrimary: textOnPrimary,
    primaryContainer: Color(0xFFE4F2FB),
    onPrimaryContainer: Color(0xFF00405F),
    secondary: secondaryColor,
    onSecondary: textOnSecondary,
    secondaryContainer: Color(0xFFDFF4F0),
    onSecondaryContainer: Color(0xFF00504A),
    tertiary: tertiaryColor,
    onTertiary: textOnSecondary,
    tertiaryContainer: Color(0xFFFEF3CF),
    onTertiaryContainer: Color(0xFF5C4A00),
    error: errorColor,
    onError: textOnPrimary,
    errorContainer: Color(0xFFFDE8E8),
    onErrorContainer: Color(0xFF7F0F13),
    surface: cardColor,
    onSurface: textPrimary,
    surfaceContainerLowest: white,
    surfaceContainerLow: Color(0xFFF8FAFC),
    surfaceContainer: surfaceColor,
    surfaceContainerHigh: Color(0xFFE8EEF3),
    surfaceContainerHighest: Color(0xFFDFE7ED),
    onSurfaceVariant: textSecondary,
    outline: Color(0xFFC3CDD5),
    outlineVariant: dividerColor,
    shadow: shadowColor,
    scrim: Color(0x80000000),
    inverseSurface: Color(0xFF1A242D),
    onInverseSurface: Color(0xFFECF2F6),
    inversePrimary: darkPrimaryColor,
  );

  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: darkPrimaryColor,
    onPrimary: Color(0xFF00283C),
    primaryContainer: Color(0xFF13303F),
    onPrimaryContainer: Color(0xFFC8E8F8),
    secondary: secondaryColor,
    onSecondary: Color(0xFF00332F),
    secondaryContainer: Color(0xFF11352F),
    onSecondaryContainer: Color(0xFFBFEDE5),
    tertiary: tertiaryColor,
    onTertiary: Color(0xFF3A2D00),
    tertiaryContainer: Color(0xFF352B08),
    onTertiaryContainer: Color(0xFFFBE9A8),
    error: darkErrorColor,
    onError: Color(0xFF42080A),
    errorContainer: Color(0xFF3A1618),
    onErrorContainer: Color(0xFFFFD6D7),
    surface: darkCardColor,
    onSurface: darkTextPrimary,
    surfaceContainerLowest: Color(0xFF0A1015),
    surfaceContainerLow: Color(0xFF141E26),
    surfaceContainer: Color(0xFF1A242D),
    surfaceContainerHigh: Color(0xFF212D37),
    surfaceContainerHighest: Color(0xFF27343F),
    onSurfaceVariant: darkTextSecondary,
    outline: Color(0xFF3A4A56),
    outlineVariant: darkDividerColor,
    shadow: Color(0x66000000),
    scrim: Color(0xB3000000),
    inverseSurface: Color(0xFFECF2F6),
    onInverseSurface: Color(0xFF0F1A21),
    inversePrimary: primaryColor,
  );

  /// Builds a complete theme from one set of colour roles.
  ///
  /// Every component theme the app touches is set here. Anything left out of
  /// this method is a component drawn in Flutter's default purple-ish Material
  /// palette the first time someone uses it, which is exactly what this file
  /// exists to prevent.
  static ThemeData _build({
    required Brightness brightness,
    required DaycoColors c,
    required ColorScheme scheme,
  }) {
    final isDark = brightness == Brightness.dark;

    // The app bar carries the brand, so its contents are always white — the
    // status-bar icons above it have to be light in both themes.
    const appBarOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    final textTheme = _textTheme(c);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[c],

      scaffoldBackgroundColor: c.pageBackground,
      canvasColor: c.pageBackground,
      dividerColor: c.divider,
      shadowColor: c.shadow,
      splashFactory: InkRipple.splashFactory,
      splashColor: c.brand.withValues(alpha: 0.10),
      highlightColor: Colors.transparent,
      hoverColor: c.brand.withValues(alpha: 0.04),
      focusColor: c.brand.withValues(alpha: 0.12),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      // Only the fallback list, deliberately: ThemeData runs `TextTheme.apply`
      // whenever either font field is set, and a non-null `fontFamily` there
      // overwrites the family on every style — which would put the body font
      // back on the headings. Passing the fallback alone leaves each style's
      // own family alone and still gives Arabic somewhere to go.
      fontFamilyFallback: AppTextStyles.fallbackFonts,
      visualDensity: VisualDensity.standard,
      // Carried over from the theme this replaced. It forces Material
      // scrolling and widget behaviour everywhere, which is what the app has
      // always shipped; it is a platform decision rather than a colour one, so
      // it is left as it was.
      platform: TargetPlatform.android,
      // Set here rather than in main, so both themes keep the transitions and
      // a page shown under the dark theme animates like the rest of the app.
      pageTransitionsTheme: AppAnimationConfig.pageTransitionsTheme,

      // The brand blue, which is what every page was already setting by hand.
      appBarTheme: AppBarTheme(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: c.shadow,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTextStyles.appBarTitle.copyWith(color: c.onBrand),
        toolbarTextStyle: AppTextStyles.bodyMedium.copyWith(color: c.onBrand),
        iconTheme: IconThemeData(color: c.onBrand, size: iconSizeM),
        actionsIconTheme: IconThemeData(color: c.onBrand, size: iconSizeM),
        systemOverlayStyle: appBarOverlay,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.card,
        selectedItemColor: c.brandAccent,
        unselectedItemColor: c.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTextStyles.tabText,
        unselectedLabelStyle: AppTextStyles.tabText,
        showUnselectedLabels: true,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.card,
        indicatorColor: c.brandSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.tabText.copyWith(
            color: selected ? c.brandAccent : c.textTertiary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? c.brandAccent : c.textTertiary,
            size: iconSizeM,
          );
        }),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        scrimColor: c.scrim,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),

      cardTheme: CardThemeData(
        color: c.card,
        elevation: isDark ? 0 : 2,
        shadowColor: c.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: cardBorderRadius,
          // A dark card cannot rely on a shadow to separate it from the page,
          // so it gets an outline there and none in light mode.
          side: isDark ? BorderSide(color: c.border) : BorderSide.none,
        ),
        margin: const EdgeInsets.all(spacingXS),
        clipBehavior: Clip.antiAlias,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(color: c.textPrimary),
        subtitleTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: c.textSecondary),
        leadingAndTrailingTextStyle:
            AppTextStyles.labelMedium.copyWith(color: c.textTertiary),
        selectedColor: c.brandAccent,
        selectedTileColor: c.brandSurface,
        shape: const RoundedRectangleBorder(borderRadius: cardBorderRadius),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingM,
          vertical: spacingXXS,
        ),
      ),

      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: c.surface,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: c.brandAccent,
        collapsedIconColor: c.textSecondary,
        textColor: c.textPrimary,
        collapsedTextColor: c.textPrimary,
        shape: const RoundedRectangleBorder(borderRadius: cardBorderRadius),
        collapsedShape:
            const RoundedRectangleBorder(borderRadius: cardBorderRadius),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.textDisabled,
          elevation: 2,
          shadowColor: c.shadow,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: buttonBorderRadius),
          textStyle: AppTextStyles.buttonText,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingS,
          ),
          minimumSize: const Size(120, 48),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.textDisabled,
          shape: const RoundedRectangleBorder(borderRadius: buttonBorderRadius),
          textStyle: AppTextStyles.buttonText,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingS,
          ),
          minimumSize: const Size(120, 48),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.brandAccent,
          disabledForegroundColor: c.textDisabled,
          side: BorderSide(color: c.brandAccent, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: buttonBorderRadius),
          textStyle: AppTextStyles.buttonText,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingS,
          ),
          minimumSize: const Size(120, 48),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brandAccent,
          disabledForegroundColor: c.textDisabled,
          textStyle: AppTextStyles.buttonText,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingM,
            vertical: spacingXS,
          ),
          shape: const RoundedRectangleBorder(borderRadius: buttonBorderRadius),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textSecondary,
          highlightColor: c.brand.withValues(alpha: 0.10),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(AppTextStyles.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return c.brand;
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return c.onBrand;
            return c.textSecondary;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: c.border)),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        splashColor: Colors.white24,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        highlightElevation: 8,
        extendedTextStyle: AppTextStyles.buttonText.copyWith(color: c.onBrand),
        shape: const CircleBorder(),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        border: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(color: c.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(color: c.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(color: c.brandAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(color: c.danger, width: 2),
        ),
        labelStyle: AppTextStyles.labelMedium.copyWith(color: c.textSecondary),
        floatingLabelStyle:
            AppTextStyles.labelMedium.copyWith(color: c.brandAccent),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: c.textTertiary),
        helperStyle: AppTextStyles.bodySmall.copyWith(color: c.textTertiary),
        errorStyle: AppTextStyles.bodySmall.copyWith(color: c.danger),
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
        iconColor: c.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingM,
          vertical: spacingS,
        ),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.brandAccent,
        selectionColor: c.brand.withValues(alpha: 0.26),
        selectionHandleColor: c.brandAccent,
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.cardElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(4),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: cardBorderRadius),
          ),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.cardElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: cardBorderRadius),
        textStyle: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
        labelTextStyle:
            WidgetStatePropertyAll(AppTextStyles.bodyMedium.copyWith(
          color: c.textPrimary,
        )),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.cardElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: cardBorderRadius),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.sheet,
        elevation: 8,
        shadowColor: c.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle:
            AppTextStyles.headlineSmall.copyWith(color: c.textPrimary),
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: c.textSecondary),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.sheet,
        modalBackgroundColor: c.sheet,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        modalElevation: 12,
        shadowColor: c.shadow,
        dragHandleColor: c.borderStrong,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: bottomSheetBorderRadius,
        ),
        // Material 3 caps modal sheets at 640px, which leaves them floating in
        // the middle of a tablet or a landscape phone. Sheets here are
        // full-bleed instead.
        constraints: const BoxConstraints(),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? c.cardElevated : const Color(0xFF1A242D),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: isDark ? c.textPrimary : Colors.white,
        ),
        actionTextColor: c.brandAccent,
        closeIconColor: isDark ? c.textSecondary : Colors.white70,
        shape: const RoundedRectangleBorder(borderRadius: buttonBorderRadius),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(spacingM),
        elevation: 4,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? c.cardElevated : const Color(0xFF1A242D),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: AppTextStyles.labelMedium.copyWith(
          color: isDark ? c.textPrimary : Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: spacingXS, vertical: 6),
      ),

      bannerTheme: MaterialBannerThemeData(
        backgroundColor: c.infoSurface,
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.brandAccent,
        unselectedLabelColor: c.textTertiary,
        labelStyle: AppTextStyles.labelLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTextStyles.labelLarge,
        dividerColor: c.divider,
        indicatorSize: TabBarIndicatorSize.tab,
        overlayColor: WidgetStatePropertyAll(c.brand.withValues(alpha: 0.08)),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: c.brandAccent, width: 2.5),
          insets: const EdgeInsets.symmetric(horizontal: spacingM),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.chipFill,
        disabledColor: c.surface,
        selectedColor: c.brand,
        secondarySelectedColor: c.brand,
        checkmarkColor: c.onBrand,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: c.border),
        labelStyle: AppTextStyles.labelMedium.copyWith(color: c.textPrimary),
        secondaryLabelStyle:
            AppTextStyles.labelMedium.copyWith(color: c.onBrand),
        padding: const EdgeInsets.symmetric(horizontal: spacingS, vertical: 6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        elevation: 0,
        pressElevation: 1,
      ),

      badgeTheme: BadgeThemeData(
        backgroundColor: c.danger,
        textColor: Colors.white,
        textStyle: AppTextStyles.labelSmall.copyWith(color: Colors.white),
      ),

      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
        space: 1,
      ),

      iconTheme: IconThemeData(color: c.textSecondary, size: iconSizeM),
      primaryIconTheme: IconThemeData(color: c.onBrand, size: iconSizeM),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.brandAccent,
        linearTrackColor: c.border,
        circularTrackColor: c.border,
        refreshBackgroundColor: c.card,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.textDisabled;
          if (states.contains(WidgetState.selected)) return c.onBrand;
          return c.card;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.surface;
          if (states.contains(WidgetState.selected)) return c.brand;
          return c.border;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return c.borderStrong;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.surface;
          if (states.contains(WidgetState.selected)) return c.brand;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(c.onBrand),
        side: BorderSide(color: c.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.textDisabled;
          if (states.contains(WidgetState.selected)) return c.brand;
          return c.borderStrong;
        }),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: c.brand,
        inactiveTrackColor: c.border,
        thumbColor: c.brand,
        overlayColor: c.brand.withValues(alpha: 0.18),
        valueIndicatorColor: c.brand,
        activeTickMarkColor: c.onBrand,
        inactiveTickMarkColor: c.textTertiary,
        valueIndicatorTextStyle:
            AppTextStyles.labelSmall.copyWith(color: c.onBrand),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.sheet,
        hourMinuteColor: c.brandSurface,
        hourMinuteTextColor: c.textPrimary,
        dialBackgroundColor: c.surface,
        dialHandColor: c.brand,
        dialTextColor: c.textPrimary,
        dayPeriodColor: c.brand,
        dayPeriodTextColor: c.textPrimary,
        entryModeIconColor: c.brandAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.sheet,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: c.brand,
        headerForegroundColor: c.onBrand,
        todayBorder: BorderSide(color: c.brandAccent),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.onBrand;
          if (states.contains(WidgetState.disabled)) return c.textDisabled;
          return c.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.brand;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.card,
        indicatorColor: c.brandSurface,
        selectedIconTheme: IconThemeData(color: c.brandAccent, size: iconSizeM),
        unselectedIconTheme:
            IconThemeData(color: c.textTertiary, size: iconSizeM),
        selectedLabelTextStyle:
            AppTextStyles.labelMedium.copyWith(color: c.brandAccent),
        unselectedLabelTextStyle:
            AppTextStyles.labelMedium.copyWith(color: c.textTertiary),
      ),

      bottomAppBarTheme: BottomAppBarThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: c.shadow,
        elevation: 8,
      ),

      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(c.inputFill),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide(color: c.border)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: cardBorderRadius),
        ),
        hintStyle: WidgetStatePropertyAll(
          AppTextStyles.bodyMedium.copyWith(color: c.textTertiary),
        ),
        textStyle: WidgetStatePropertyAll(
          AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
        ),
      ),

      searchViewTheme: SearchViewThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        dividerColor: c.divider,
        headerHintStyle:
            AppTextStyles.bodyMedium.copyWith(color: c.textTertiary),
        headerTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
      ),
    );
  }

  /// The text theme, coloured for one brightness.
  ///
  /// Display and headline text is the only text given [AppTextStyles.titleFont];
  /// everything smaller stays on the body font, which is the legible one at
  /// 12sp in a van.
  static TextTheme _textTheme(DaycoColors c) {
    return TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(color: c.textPrimary),
      displayMedium: AppTextStyles.displayMedium.copyWith(color: c.textPrimary),
      displaySmall: AppTextStyles.displaySmall.copyWith(color: c.textPrimary),
      headlineLarge: AppTextStyles.headlineLarge.copyWith(color: c.textPrimary),
      headlineMedium:
          AppTextStyles.headlineMedium.copyWith(color: c.textPrimary),
      headlineSmall: AppTextStyles.headlineSmall.copyWith(color: c.textPrimary),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: c.textPrimary),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: c.textPrimary),
      titleSmall: AppTextStyles.titleSmall.copyWith(color: c.textPrimary),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: c.textPrimary),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: c.textSecondary),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: c.textSecondary),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: c.textPrimary),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: c.textSecondary),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: c.textTertiary),
    );
  }

  // ---------------------------------------------------------------------------
  // Shape, spacing and size tokens
  // ---------------------------------------------------------------------------

  static const BorderRadius cardBorderRadius =
      BorderRadius.all(Radius.circular(12));
  static const BorderRadius buttonBorderRadius =
      BorderRadius.all(Radius.circular(8));
  static const BorderRadius inputBorderRadius =
      BorderRadius.all(Radius.circular(8));
  static const BorderRadius pillBorderRadius =
      BorderRadius.all(Radius.circular(999));
  static const BorderRadius bottomSheetBorderRadius =
      BorderRadius.vertical(top: Radius.circular(20));

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: shadowColor,
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  static const List<BoxShadow> lightCardShadow = [
    BoxShadow(
      color: lightShadowColor,
      offset: Offset(0, 1),
      blurRadius: 4,
    ),
  ];

  /// For a panel that floats over the map, which needs to read as lifted above
  /// imagery rather than resting on a page.
  static const List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Color(0x26000000),
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// A shadow tinted with the brand blue, for a brand-coloured surface. A grey
  /// shadow under a saturated blue panel reads as dirt.
  static const List<BoxShadow> brandShadow = [
    BoxShadow(
      color: Color(0x33008DD2),
      offset: Offset(0, 6),
      blurRadius: 18,
    ),
  ];

  static const double spacingXXS = 4.0;
  static const double spacingXS = 8.0;
  static const double spacingS = 12.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  static const double iconSizeXS = 16.0;
  static const double iconSizeS = 20.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;

  /// The brand gradient, re-exported so a caller that already has
  /// [ColorManager] imported does not need a second import for it.
  static const LinearGradient brandGradient = AppGradients.brand;
}
