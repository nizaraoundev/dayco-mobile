import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_tokens.dart';
import 'text_styles.dart';

class ColorManager {
  ColorManager._();

  // Product Colors (couleur produit)
  static const Color primaryColor = Color(0xFF008DD2); // Blue
  static const Color primaryVariant = Color(0xFF395EA7); // Environmental Blue
  static const Color secondaryColor = Color(0xFF7ED6C9); // Teal
  static const Color secondaryVariant = Color(
    0xFF009846,
  ); // Environmental Green
  static const Color tertiaryColor = Color(0xFFFBCB07); // Yellow
  static const Color tertiaryVariant = Color(
    0xFFFFED00,
  ); // Environmental Yellow

  // Status colors using updated palette
  static const Color successColor = Color(0xFF009846); // Environmental Green
  static const Color warningColor = Color(0xFFFFED00); // Environmental Yellow
  static const Color errorColor = Color(0xFFE31E24); // Environmental Red
  static const Color infoColor = Color(0xFF008DD2); // Product Blue

  // Neutral colors
  static const Color backgroundColor = Color(0xFFFEFEFE); // Environmental White
  static const Color surfaceColor = Color(
    0xFFE7EBEB,
  ); // Environmental Light Gray
  static const Color cardColor = Color(0xFFFFFFFF); // Pure White
  static const Color dividerColor = Color(0xFF626D77); // Environmental Gray

  // Additional colors for profile page
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color greybg = Color(0xFFF5F5F5);
  static const Color lightGrey2 = Color(0xFFE0E0E0);
  static const Color blackLight = Color(0xFF333333);

  // Text colors
  static const Color textPrimary = Color(0xFF000000); // Environmental Black
  static const Color textSecondary = Color(0xFF626D77); // Environmental Gray
  static const Color textTertiary = Color(0xFF898989); // Product Gray
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White on primary
  static const Color textOnSecondary = Color(0xFF000000); // Black on secondary

  // Dark theme colors
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color darkCardColor = Color(0xFF2D2D2D);
  static const Color darkDividerColor = Color(0xFF404040);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextTertiary = Color(0xFF808080);

  // Shadow colors
  static const Color shadowColor = Color(0x1A000000);
  static const Color lightShadowColor = Color(0x0D000000);

  /// Light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color scheme
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: textOnPrimary,
        primaryContainer: Color(0xFFE1F5FE),
        onPrimaryContainer: Color(0xFF01579B),
        secondary: secondaryColor,
        onSecondary: textOnSecondary,
        secondaryContainer: Color(0xFFE0F7FA),
        onSecondaryContainer: Color(0xFF00695C),
        tertiary: tertiaryColor,
        onTertiary: Color(0xFF212529),
        tertiaryContainer: Color(0xFFFFF3C4),
        onTertiaryContainer: Color(0xFF8A6914),
        error: errorColor,
        onError: textOnPrimary,
        errorContainer: Color(0xFFFFEBEE),
        onErrorContainer: Color(0xFFB71C1C),
        surface: surfaceColor,
        onSurface: textPrimary,
        surfaceContainerHighest: backgroundColor,
        onSurfaceVariant: textSecondary,
        outline: dividerColor,
        outlineVariant: Color(0xFFDEE2E6),
        shadow: shadowColor,
        scrim: Color(0x80000000),
      ),

      // Scaffold
      scaffoldBackgroundColor: backgroundColor,

      // App bar theme
      // The brand bar, defined once.
      //
      // This used to be a white bar with dark text, but it never took effect
      // (the theme was not applied), so four pages each hand-set a blue
      // `AppBar` instead and one did not — the app had two different bar
      // styles depending on the screen. Blue is the de facto standard, so it
      // lives here now and the per-page overrides are gone.
      //
      // `brandStrong` rather than `primaryColor`: white title text on
      // #008DD2 is 3.66:1 and fails AA; on #007DBB it is 4.52:1.
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.brandStrong,
        foregroundColor: AppPalette.onBrand,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: shadowColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.appBarTitle.copyWith(
          color: AppPalette.onBrand,
        ),
        toolbarTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppPalette.onBrand,
        ),
        iconTheme: const IconThemeData(color: AppPalette.onBrand, size: 24),
        actionsIconTheme: const IconThemeData(
          color: AppPalette.onBrand,
          size: 24,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          // Light icons, because the bar behind them is now dark.
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTextStyles.tabText,
        unselectedLabelStyle: AppTextStyles.tabText,
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: shadowColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(8),
      ),

      // Button themes
      // Button themes.
      //
      // These use the accessible colour roles, not the raw brand blue: white
      // on `primaryColor` (#008DD2) measures 3.66:1 and fails WCAG AA, while
      // `brandStrong` clears it at 4.52:1 in the same hue. Radius is the
      // shared `AppRadius.md` (12) so a themed button matches an `AppButton`
      // sitting next to it — they were 8 and 12 before, which is why buttons
      // never looked like they came from the same app.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.brandStrong,
          foregroundColor: AppPalette.onBrand,
          elevation: 0,
          shadowColor: shadowColor,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppTextStyles.buttonText,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          minimumSize: const Size(0, AppA11y.minTouchTarget),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.brandInk,
          side: const BorderSide(color: AppPalette.brandInk, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppTextStyles.buttonText,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          minimumSize: const Size(0, AppA11y.minTouchTarget),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.brandInk,
          textStyle: AppTextStyles.buttonText,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          minimumSize: const Size(0, AppA11y.minTouchTarget),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppPalette.brandStrong,
        foregroundColor: AppPalette.onBrand,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: AppTextStyles.labelMedium.copyWith(color: textSecondary),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: textTertiary),
        errorStyle: AppTextStyles.bodySmall.copyWith(color: errorColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        elevation: 8,
        shadowColor: shadowColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: AppTextStyles.headlineSmall.copyWith(
          color: textPrimary,
        ),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: textSecondary,
        ),
      ),

      // Bottom sheet theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        elevation: 8,
        shadowColor: shadowColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Snack bar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: textOnPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // Tab bar theme
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: textTertiary,
        labelStyle: AppTextStyles.labelMedium,
        unselectedLabelStyle: AppTextStyles.labelMedium,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primaryColor, width: 2),
          insets: EdgeInsets.symmetric(horizontal: 16),
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: Color(0xFFF1F3F4),
        selectedColor: primaryColor,
        labelStyle: AppTextStyles.labelSmall.copyWith(color: textPrimary),
        secondaryLabelStyle: AppTextStyles.labelSmall.copyWith(
          color: textOnPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        pressElevation: 2,
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: textSecondary, size: 24),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        displaySmall: AppTextStyles.displaySmall,
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: AppTextStyles.titleSmall,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: dividerColor,
        circularTrackColor: dividerColor,
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.5);
          }
          return Colors.grey.withValues(alpha: 0.3);
        }),
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(textOnPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return textTertiary;
        }),
      ),

      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: dividerColor,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withValues(alpha: 0.2),
        valueIndicatorColor: primaryColor,
        valueIndicatorTextStyle: AppTextStyles.labelSmall.copyWith(
          color: textOnPrimary,
        ),
      ),
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: primaryColor,
        onPrimary: textOnPrimary,
        primaryContainer: Color(0xFF1A365D),
        onPrimaryContainer: Color(0xFFE3F2FD),
        secondary: secondaryColor,
        onSecondary: darkTextPrimary,
        secondaryContainer: Color(0xFF004D40),
        onSecondaryContainer: Color(0xFFE0F7FA),
        tertiary: Color(0xFFBA68C8),
        onTertiary: textOnPrimary,
        tertiaryContainer: Color(0xFF6A1B9A),
        onTertiaryContainer: Color(0xFFF3E5F5),
        error: errorColor,
        onError: textOnPrimary,
        errorContainer: Color(0xFF8C1D18),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: darkSurfaceColor,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: darkBackgroundColor,
        onSurfaceVariant: darkTextSecondary,
        outline: darkDividerColor,
        outlineVariant: Color(0xFF555555),
        shadow: shadowColor,
        scrim: Color(0x80000000),
      ),

      // Scaffold
      scaffoldBackgroundColor: darkBackgroundColor,

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurfaceColor,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: shadowColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.appBarTitle.copyWith(
          color: darkTextPrimary,
        ),
        toolbarTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: darkTextPrimary,
        ),
        iconTheme: const IconThemeData(color: darkTextPrimary, size: 24),
        actionsIconTheme: const IconThemeData(color: darkTextPrimary, size: 24),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      // Apply similar theming as light theme but with dark colors
      // ... (continuing with dark theme configurations)
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge.copyWith(
          color: darkTextPrimary,
        ),
        displayMedium: AppTextStyles.displayMedium.copyWith(
          color: darkTextPrimary,
        ),
        displaySmall: AppTextStyles.displaySmall.copyWith(
          color: darkTextPrimary,
        ),
        headlineLarge: AppTextStyles.headlineLarge.copyWith(
          color: darkTextPrimary,
        ),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(
          color: darkTextPrimary,
        ),
        headlineSmall: AppTextStyles.headlineSmall.copyWith(
          color: darkTextPrimary,
        ),
        titleLarge: AppTextStyles.titleLarge.copyWith(color: darkTextPrimary),
        titleMedium: AppTextStyles.titleMedium.copyWith(color: darkTextPrimary),
        titleSmall: AppTextStyles.titleSmall.copyWith(color: darkTextPrimary),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: darkTextPrimary),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: darkTextSecondary),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: darkTextSecondary),
        labelLarge: AppTextStyles.labelLarge.copyWith(color: darkTextSecondary),
        labelMedium: AppTextStyles.labelMedium.copyWith(
          color: darkTextSecondary,
        ),
        labelSmall: AppTextStyles.labelSmall.copyWith(color: darkTextTertiary),
      ),
    );
  }

  /// NEOS app-specific color extensions
  /// Using the updated color palette: Product and Environmental colors
  static const Map<String, Color> appColors = {
    'rideActive': Color(0xFF7ED6C9), // Product Teal for active rides
    'rideWaiting': Color(0xFFFFED00), // Environmental Yellow for waiting states
    'rideCancelled': Color(0xFFE31E24), // Environmental Red for cancelled
    'rideCompleted': Color(0xFF009846), // Environmental Green for completion
    'walletPositive': Color(
      0xFF009846,
    ), // Environmental Green for positive balance
    'walletNegative': Color(0xFFE31E24), // Environmental Red for negative
    'driverOnline': Color(0xFF009846), // Environmental Green for online status
    'driverOffline': Color(0xFF898989), // Product Gray for offline
    'vehicleEconomy': Color(0xFF7ED6C9), // Product Teal for economy
    'vehicleComfort': Color(0xFF008DD2), // Product Blue for comfort
    'vehiclePremium': Color(0xFFFBCB07), // Product Yellow for premium
    'vehicleLuxury': Color(0xFF395EA7), // Environmental Blue for luxury
    'businessPortal': Color(0xFF008DD2), // Product Blue for business
    'supportTicket': Color(0xFF395EA7), // Environmental Blue for support
    'notification': Color(0xFFFFED00), // Environmental Yellow for notifications
    'neosBlue': Color(0xFF008DD2), // Product Blue
    'neosTeal': Color(0xFF7ED6C9), // Product Teal
    'neosYellow': Color(0xFFFBCB07), // Product Yellow
    'neosGray': Color(0xFF898989), // Product Gray
    'envBlue': Color(0xFF395EA7), // Environmental Blue
    'envGreen': Color(0xFF009846), // Environmental Green
    'envRed': Color(0xFFE31E24), // Environmental Red
    'envYellow': Color(0xFFFFED00), // Environmental Yellow
    'envBlack': Color(0xFF000000), // Environmental Black
    'envGray': Color(0xFF626D77), // Environmental Gray
    'envLightGray': Color(0xFFE7EBEB), // Environmental Light Gray
    'envWhite': Color(0xFFFEFEFE), // Environmental White
  };

  /// Get app-specific color
  static Color getAppColor(String colorName) {
    return appColors[colorName] ?? primaryColor;
  }

  /// Common border radius
  static const BorderRadius cardBorderRadius = BorderRadius.all(
    Radius.circular(12),
  );
  static const BorderRadius buttonBorderRadius = BorderRadius.all(
    Radius.circular(8),
  );
  static const BorderRadius inputBorderRadius = BorderRadius.all(
    Radius.circular(8),
  );
  static const BorderRadius bottomSheetBorderRadius = BorderRadius.vertical(
    top: Radius.circular(16),
  );

  /// Common shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: shadowColor,
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> lightCardShadow = [
    BoxShadow(
      color: lightShadowColor,
      offset: Offset(0, 1),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Common spacings
  static const double spacingXXS = 4.0;
  static const double spacingXS = 8.0;
  static const double spacingS = 12.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  /// Icon sizes
  static const double iconSizeXS = 16.0;
  static const double iconSizeS = 20.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;
}
