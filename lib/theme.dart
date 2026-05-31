import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color Tokens ─────────────────────────────────────────────────────────────
const kAccent       = Color(0xFF007AFF); // Electric Blue
const kDarkBg       = Color(0xFF0D0D0D); // Deep Dark background
const kDarkSurface  = Color(0xFF1A1A1F); // Card / surface
const kDarkSurface2 = Color(0xFF252530); // Input / elevated surface
const kDarkBorder   = Color(0xFF2C2C38); // Dividers / borders
const kTextPrimary  = Color(0xFFFFFFFF);
const kTextSecondary= Color(0xFF9A9AAF);
const kTextMuted    = Color(0xFF5A5A6E);
const kRed          = Color(0xFFFF3B5C);
const kGreen        = Color(0xFF30D158);

// Gradient helpers
const kBgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF0D0D0D), Color(0xFF0A0A14)],
);

const kAccentGradient = LinearGradient(
  colors: [Color(0xFF007AFF), Color(0xFF0055CC)],
);

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: kAccent,
        secondary: kAccent,
        surface: kDarkSurface,
        onPrimary: kTextPrimary,
        onSurface: kTextPrimary,
        error: kRed,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: kDarkBg,

      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: kTextPrimary,
        displayColor: kTextPrimary,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: kDarkBg,
        foregroundColor: kTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: kTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        iconTheme: const IconThemeData(color: kTextPrimary),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: kDarkSurface,
        selectedItemColor: kAccent,
        unselectedItemColor: kTextMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: kDarkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kDarkBorder, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 14),
      ),

      dividerColor: kDarkBorder,
      dividerTheme: const DividerThemeData(color: kDarkBorder, thickness: 0.8),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kDarkSurface2,
        hintStyle: GoogleFonts.inter(color: kTextMuted, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: kTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDarkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDarkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccent,
          foregroundColor: kTextPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: kAccent),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: kDarkSurface2,
        contentTextStyle: GoogleFonts.inter(color: kTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: kDarkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.inter(
          color: kTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        contentTextStyle: GoogleFonts.inter(color: kTextSecondary, fontSize: 14),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: kDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kAccent,
        foregroundColor: kTextPrimary,
        elevation: 4,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: kAccent),
      iconTheme: const IconThemeData(color: kTextSecondary),

      listTileTheme: ListTileThemeData(
        iconColor: kTextSecondary,
        textColor: kTextPrimary,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Force dark as default for both modes
  static ThemeData get lightTheme => darkTheme;
}
