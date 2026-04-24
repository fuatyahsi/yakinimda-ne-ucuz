import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFFEF4E9B);
  static const secondary = Color(0xFFB843D8);
  static const coral = Color(0xFFFF866E);
  static const apricot = Color(0xFFFFD469);
  static const ink = Color(0xFF5B2346);
  static const inkSoft = Color(0xFF8F6380);
  static const shellBackground = Color(0xFFFFF5F2);
  static const surfaceTint = Color(0xFFFFEEF5);
  static const surfaceSoft = Color(0xFFFFFAFC);
  static const cardSurface = Color(0xFFFFFFFF);
  static const warmSurface = Color(0xFFFFF7F2);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEF4E9B),
      Color(0xFFFF866E),
      Color(0xFFFFD469),
    ],
  );

  static const panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF8FB),
      Color(0xFFFFF3EC),
    ],
  );

  static const navigationGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFFFBFD),
      Color(0xFFFFF7F2),
    ],
  );

  static const showcaseGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF1F8),
      Color(0xFFFFF7F2),
      Color(0xFFFFFFFF),
    ],
  );

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.18),
          blurRadius: 38,
          offset: const Offset(0, 22),
          spreadRadius: -18,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 10),
          spreadRadius: -12,
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.14),
          blurRadius: 28,
          offset: const Offset(0, 16),
          spreadRadius: -16,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 8),
          spreadRadius: -12,
        ),
      ];

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      tertiary: apricot,
      onTertiary: ink,
      surface: surfaceSoft,
      onSurface: ink,
      primaryContainer: const Color(0xFFFFD9E7),
      onPrimaryContainer: ink,
      secondaryContainer: const Color(0xFFF2DFFF),
      onSecondaryContainer: ink,
      outline: const Color(0xFFF1CAD8),
      outlineVariant: const Color(0xFFF8DFE8),
      surfaceTint: Colors.transparent,
      onSurfaceVariant: inkSoft,
    );

    final baseTextTheme = ThemeData(brightness: Brightness.light).textTheme;
    final textTheme = baseTextTheme.copyWith(
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: ink,
        fontWeight: FontWeight.w800,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        color: ink,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: ink,
        height: 1.35,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: ink,
        height: 1.35,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: inkSoft,
        height: 1.3,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        color: ink,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        color: inkSoft,
        fontWeight: FontWeight.w700,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: shellBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceTint,
        selectedColor: primary.withValues(alpha: 0.16),
        secondarySelectedColor: primary.withValues(alpha: 0.16),
        disabledColor: const Color(0xFFF8E6EF),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(
          color: inkSoft,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: primary,
        suffixIconColor: inkSoft,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: inkSoft,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: heroGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: softShadow,
        ),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: Colors.white,
          side: BorderSide(color: primary.withValues(alpha: 0.14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w700,
            color: states.contains(WidgetState.selected) ? ink : inkSoft,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : inkSoft,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: primary.withValues(alpha: 0.08),
        thickness: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData darkTheme() {
    final base = lightTheme();
    final darkScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFFF8FC7),
      onPrimary: const Color(0xFF2E1325),
      secondary: const Color(0xFFD3A0FF),
      onSecondary: const Color(0xFF2A1234),
      tertiary: apricot,
      onTertiary: const Color(0xFF2C2011),
      surface: const Color(0xFF241428),
      onSurface: const Color(0xFFFFEDF6),
      primaryContainer: const Color(0xFF5C2244),
      onPrimaryContainer: const Color(0xFFFFE6F1),
      secondaryContainer: const Color(0xFF4A2B62),
      onSecondaryContainer: const Color(0xFFF5E8FF),
      outline: const Color(0xFF6B4D61),
      outlineVariant: const Color(0xFF4A3142),
      surfaceTint: Colors.transparent,
      onSurfaceVariant: const Color(0xFFD2B6C6),
    );

    return base.copyWith(
      colorScheme: darkScheme,
      scaffoldBackgroundColor: const Color(0xFF160E1A),
      cardTheme: base.cardTheme.copyWith(color: const Color(0xFF241428)),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: const Color(0xFF241428),
      ),
      appBarTheme: base.appBarTheme.copyWith(foregroundColor: Colors.white),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: const Color(0xFF2A1931),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF2D1B33),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFFFFEDF6),
        displayColor: const Color(0xFFFFEDF6),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: const Color(0xFF34203B),
      ),
    );
  }
}
