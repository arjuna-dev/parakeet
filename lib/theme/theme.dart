import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The [AppTheme] defines light and dark themes for the app.
///
/// Theme setup for FlexColorScheme package v8.
/// Use same major flex_color_scheme package version. If you use a
/// lower minor version, some properties may not be supported.
/// In that case, remove them after copying this theme to your
/// app or upgrade package to version 8.0.0.
///
/// Use in [MaterialApp] like this:
///
/// MaterialApp(
///  theme: AppTheme.light,
///  darkTheme: AppTheme.dark,
///  :
/// );
sealed class AppTheme {
  // The defined light theme.
  static ThemeData light = FlexThemeData.light(
    scheme: FlexScheme.material,
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      useM2StyleDividerInM3: true,
      defaultRadius: 50.0,
      inputDecoratorIsFilled: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorRadiusAdaptive: 40.0,
      alignedDropdown: true,
      bottomNavigationBarMutedUnselectedLabel: false,
      bottomNavigationBarMutedUnselectedIcon: false,
      navigationRailUseIndicator: true,
      navigationRailLabelType: NavigationRailLabelType.all,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );
  // The defined dark theme.
  static ThemeData dark = FlexThemeData.dark(
    scheme: FlexScheme.material,
    surfaceMode: FlexSurfaceMode.level,
    blendLevel: 40,
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnColors: true,
      useM2StyleDividerInM3: true,
      defaultRadius: 50.0,
      inputDecoratorIsFilled: true,
      inputDecoratorBackgroundAlpha: 81,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorRadiusAdaptive: 40.0,
      alignedDropdown: true,
      bottomNavigationBarMutedUnselectedLabel: false,
      bottomNavigationBarMutedUnselectedIcon: false,
      navigationRailUseIndicator: true,
      navigationRailLabelType: NavigationRailLabelType.all,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );

  // Custom theme method to modify a specific color in the ThemeData object
  static ThemeData customTheme() {
    return dark.copyWith(
      colorScheme: dark.colorScheme.copyWith(
        // Dark green background
        surface: const Color(0xFF0A2F2A), // Deep forest green
        surfaceContainerHighest:
            const Color(0xFF0F3D37), // Slightly lighter green
        surfaceBright: const Color(0xFF0A2F2A),
        surfaceDim: const Color(0xFF061F1C),

        // Bright green accents
        primary: const Color(0xFF3FFF8F), // Vibrant lime green
        primaryContainer:
            const Color(0xFF1A4D3A), // Darker green for containers
        primaryFixed: const Color(0xFF3FFF8F),
        primaryFixedDim: const Color(0xFF2EE67D),

        // Secondary colors
        secondary: const Color(0xFF3FFF8F),
        secondaryContainer: const Color(0xFF1A4D3A),

        // Text colors
        onSurface: const Color(0xFFFFFFFF), // White text
        onSurfaceVariant:
            const Color(0xFFB0B0B0), // Light gray for secondary text
        onPrimary: const Color(0xFF0A2F2A), // Dark text on bright green

        // Other colors
        inversePrimary: const Color(0xFF1A4D3A),
        surfaceTint: const Color(0xFF3FFF8F),
        outline: const Color(0xFF2EE67D),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A2F2A),
      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: const Color(0xFF3FFF8F),
        inactiveTrackColor: const Color(0xFF1A4D3A),
        thumbColor: const Color(0xFF3FFF8F),
        overlayColor: const Color(0xFF3FFF8F).withOpacity(0.2),
        valueIndicatorColor: const Color(0xFF3FFF8F),
      ),
      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0A2F2A),
        selectedItemColor: Color(0xFF3FFF8F),
        unselectedItemColor: Color(0xFFB0B0B0),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF3FFF8F),
          side: const BorderSide(color: Color(0xFF3FFF8F)),
        ),
      ),
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3FFF8F),
          foregroundColor: const Color(0xFF0A2F2A),
        ),
      ),
      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF3FFF8F),
        linearTrackColor: Color(0xFF1A4D3A),
      ),
      // Text selection theme
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: const Color(0xFF3FFF8F),
        selectionColor: const Color(0xFF3FFF8F).withOpacity(0.3),
        selectionHandleColor: const Color(0xFF3FFF8F),
      ),
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A2F2A),
        foregroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
        titleTextStyle: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      // SnackBar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0F3D37), // Dark green background
        contentTextStyle: const TextStyle(
          color: Color(0xFFFFFFFF), // White text
          fontSize: 14,
        ),
        actionTextColor: const Color(0xFF3FFF8F), // Bright green for action buttons
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Shared dialog styling for [AppTheme.customTheme] (forest surface + lime accent).
class ParakeetDialogTheme {
  ParakeetDialogTheme._();

  static Color background(ColorScheme scheme) => scheme.surfaceContainerHighest;

  static ShapeBorder alertShape(ColorScheme scheme) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: scheme.outline.withOpacity(0.35),
          width: 1,
        ),
      );
}
