import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppTheme {
  // Primary LifeSync Brand Colors
  static const Color primaryColor = Color(0xFF0284C7); // LifeSync Cyan / Ocean Blue
  static const Color primaryLight = Color(0xFF38BDF8); // Light Cyan
  static const Color primaryAccent = Color(0xFF00F2FE); // Cyan Glow
  
  // Semantic Colors
  static const Color positiveColor = Color(0xFF10B981); // Emerald Green (Income / Completed)
  static const Color negativeColor = Color(0xFFEF4444); // Coral Red (Expenses / Overdue)
  static const Color warningColor = Color(0xFFF59E0B);  // Amber (Due Soon / High Priority)
  static const Color infoColor = Color(0xFF0EA5E9);     // Sky Blue (Info / General)
  static const Color purpleAccent = Color(0xFF8B5CF6);  // Purple (Focus / Routine)

  // Surface Tokens
  static const Color lightScaffold = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  static const Color darkScaffold = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Formatting Utilities
  static String formatCurrency(double amount, {bool showSign = false, bool isIncome = false}) {
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    final formatted = formatter.format(amount.abs());
    if (showSign) {
      if (isIncome || amount > 0) return '+₹$formatted';
      if (amount < 0) return '-₹$formatted';
      return '₹$formatted';
    }
    return '₹$formatted';
  }

  static String formatCurrencyDouble(double amount) {
    if (amount % 1 == 0) {
      return NumberFormat('#,##,##0', 'en_IN').format(amount.toInt());
    }
    return NumberFormat('#,##,##0.00', 'en_IN').format(amount);
  }

  static String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: positiveColor,
        surface: lightSurface,
        surfaceContainerHighest: Color(0xFFF1F5F9),
        error: negativeColor,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      scaffoldBackgroundColor: lightScaffold,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: lightBorder, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // Dark Theme (Default sleek dark mode)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        secondary: positiveColor,
        surface: darkSurface,
        surfaceContainerHighest: Color(0xFF334155),
        error: negativeColor,
        onPrimary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkScaffold,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: darkBorder, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.black,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryLight,
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // High Contrast Theme
  static ThemeData get highContrastTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF38BDF8),
        secondary: Color(0xFF34D399),
        surface: Color(0xFF000000),
        surfaceContainerHighest: Color(0xFF18181B),
        error: Color(0xFFF87171),
        onPrimary: Colors.black,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF18181B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.white, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF38BDF8),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: Color(0xFF38BDF8),
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
