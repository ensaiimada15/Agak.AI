import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.navy,
      ),
      scaffoldBackgroundColor: AppColors.pageBg,
      fontFamily: GoogleFonts.rubik().fontFamily,
    );

    return base.copyWith(
      textTheme: GoogleFonts.rubikTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
    );
  }

  /// Bold display font standing in for the design's "LINE Seed Sans" headings.
  static TextStyle headline({double size = 28, Color color = AppColors.ink}) {
    return GoogleFonts.rubik(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      height: 1.2,
    );
  }
}