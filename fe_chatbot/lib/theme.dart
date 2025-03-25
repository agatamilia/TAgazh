import 'package:flutter/material.dart';

// App color scheme
final ColorScheme colorScheme = ColorScheme(
  primary: const Color(0xFF2E7D32),         // Dark Green
  primaryContainer: const Color(0xFFAED581), // Light Green
  secondary: const Color(0xFFFFA000),        // Amber
  secondaryContainer: const Color(0xFFFFE082), // Light Amber
  surface: Colors.white,
  background: const Color(0xFFF1F8E9),      // Off-White with Green Tint
  error: const Color(0xFFB71C1C),
  onPrimary: Colors.white,
  onSecondary: Colors.black,
  onSurface: const Color(0xFF212121),        // Nearly Black
  onBackground: const Color(0xFF212121),
  onError: Colors.white,
  brightness: Brightness.light,
);

// App theme
final ThemeData appTheme = ThemeData(
  colorScheme: colorScheme,
  useMaterial3: true,
  scaffoldBackgroundColor: colorScheme.background,
  appBarTheme: AppBarTheme(
    backgroundColor: colorScheme.primary,
    foregroundColor: colorScheme.onPrimary,
    elevation: 0,
  ),
  cardTheme: CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 20,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
    ),
    labelLarge: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
    ),
  ),
);

