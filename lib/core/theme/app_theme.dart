import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B5E3C),
        inputDecorationTheme: const InputDecorationTheme(filled: true),
      );
}
