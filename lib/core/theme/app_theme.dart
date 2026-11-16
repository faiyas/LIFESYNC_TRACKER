import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0284C7); // Vibrant Ocean Blue
  static const Color secondaryColor = Color(0xFF8B5CF6); // Electric Purple
  static const Color tertiaryColor = Color(0xFF06B6D4); // Cyan Accent
  static const Color errorColor = Color(0xFFEF4444); // Red Error
  static const Color successColor = Color(0xFF10B981); // Emerald Green

  static const Color lightBackground = Color(0xFFF8FAFC); // Clean Slate-50 background
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White Card Surface
  static const Color lightBorder = Color(0xFFE2E8F0); // Subtle Border

  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF161F33);
  static const Color darkSurfaceContainer = Color(0xFF1E2942);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: tertiaryColor,
      error: errorColor,
      surface: lightSurface,
      onSurface: const Color(0xFF0F172A),
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: lightBackground,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Color(0xFF0F172A)),
      bodyMedium: TextStyle(color: Color(0xFF1E293B)),
      bodySmall: TextStyle(color: Color(0xFF475569)),
      labelLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: Color(0xFF334155)),
      labelSmall: TextStyle(color: Color(0xFF64748B)),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: lightBackground,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: lightBorder, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: primaryColor.withOpacity(0.18),
      disabledColor: const Color(0xFFE2E8F0),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
      secondaryLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 14),
      floatingLabelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 6,
      indicatorColor: primaryColor.withOpacity(0.15),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryColor, size: 24);
        }
        return const IconThemeData(color: Color(0xFF64748B), size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12);
        }
        return const TextStyle(color: Color(0xFF64748B), fontSize: 11);
      }),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: tertiaryColor,
      error: errorColor,
      surface: darkSurface,
    ),
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: primaryColor.withOpacity(0.18), width: 1),
      ),
    ),
  );

  static ThemeData highContrastTheme = lightTheme;
}
