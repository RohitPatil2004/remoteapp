import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Core Colors ──────────────────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color bgCard = Color(0xFF13131A);
  static const Color bgSurface = Color(0xFF1C1C26);
  static const Color accent = Color(0xFFFF8C00); // amber/orange
  static const Color accentLight = Color(0xFFFFB347);
  static const Color accentGlow = Color(0x33FF8C00);
  static const Color glassWhite = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x22FFFFFF);
  static const Color textPrimary = Color(0xFFEEEEF4);
  static const Color textSecondary = Color(0xFF8A8A9E);
  static const Color textHint = Color(0xFF55556A);
  static const Color error = Color(0xFFFF4C6A);
  static const Color success = Color(0xFF00D68F);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentLight,
        surface: bgCard,
        error: error,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme()
          .apply(bodyColor: textPrimary, displayColor: textPrimary)
          .copyWith(
            displayLarge: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
            displayMedium: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            titleLarge: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            bodyLarge: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: textPrimary,
            ),
            bodyMedium: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: textSecondary,
            ),
            labelLarge: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: bgDark,
              letterSpacing: 0.5,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        hintStyle: GoogleFonts.spaceGrotesk(color: textHint, fontSize: 15),
        labelStyle: GoogleFonts.spaceGrotesk(
          color: textSecondary,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: bgDark,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
