import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color backgroundLight = Color(0xFFE0E5EC);
  static const Color backgroundDark = Color(0xFF292D32);
  
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF60A5FA);

  static const Color textLight = Color(0xFF1E293B);
  static const Color textDark = Color(0xFFF8FAFC);
  
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primaryColor: AppColors.primaryLight,
      textTheme: GoogleFonts.dotGothic16TextTheme(
        ThemeData.light().textTheme.copyWith(
          bodyLarge: const TextStyle(color: AppColors.textLight, fontSize: 16),
          bodyMedium: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14),
          titleLarge: const TextStyle(color: AppColors.textLight, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textLight),
        titleTextStyle: GoogleFonts.dotGothic16(color: AppColors.textLight, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primaryDark,
      textTheme: GoogleFonts.dotGothic16TextTheme(
        ThemeData.dark().textTheme.copyWith(
          bodyLarge: const TextStyle(color: AppColors.textDark, fontSize: 16),
          bodyMedium: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
          titleLarge: const TextStyle(color: AppColors.textDark, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        titleTextStyle: GoogleFonts.dotGothic16(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}
