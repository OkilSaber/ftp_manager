import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract class AppTheme {
  static TextTheme _buildTextTheme(TextTheme base, Color bodyColor, Color displayColor) {
    final dmSans = GoogleFonts.dmSansTextTheme(base);
    return dmSans.copyWith(
      displayLarge: dmSans.displayLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 32, color: displayColor),
      titleLarge: dmSans.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 20, color: displayColor),
      titleMedium: dmSans.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16, color: displayColor),
      bodyMedium: dmSans.bodyMedium?.copyWith(fontWeight: FontWeight.w400, fontSize: 14, color: bodyColor),
      bodySmall: dmSans.bodySmall?.copyWith(fontWeight: FontWeight.w400, fontSize: 12, color: bodyColor),
      labelLarge: dmSans.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 14, color: displayColor),
      labelSmall: dmSans.labelSmall?.copyWith(fontWeight: FontWeight.w500, fontSize: 11, color: bodyColor),
    );
  }

  static ThemeData darkTheme() {
    const cs = ColorScheme.dark(
      surface: AppColors.darkSurface,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      primary: AppColors.mintAccent,
      onPrimary: AppColors.darkBackground,
      secondary: AppColors.iceBlue,
      onSecondary: AppColors.darkBackground,
      onSurface: AppColors.darkOnSurface,
      error: AppColors.errorRed,
    );

    final textTheme = _buildTextTheme(
      ThemeData.dark().textTheme,
      AppColors.darkOnSurface,
      AppColors.darkOnBackground,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: AppColors.darkOnBackground),
        iconTheme: const IconThemeData(color: AppColors.mintAccent),
        actionsIconTheme: const IconThemeData(color: AppColors.mintAccent),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.mintAccent,
        foregroundColor: AppColors.darkBackground,
        elevation: 0,
        shape: CircleBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: AppColors.iceBlue,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.mintAccent, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.darkOnSurface),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: AppColors.mintAccent),
        prefixIconColor: AppColors.iceBlue,
        suffixIconColor: AppColors.darkOnSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mintAccent,
          foregroundColor: AppColors.darkBackground,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.mintAccent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleMedium?.copyWith(color: AppColors.darkOnBackground),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.darkOnSurface),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorderDark,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.darkOnBackground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      iconTheme: const IconThemeData(color: AppColors.iceBlue, size: 22),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.mintAccent,
        linearTrackColor: AppColors.darkSurfaceVariant,
        circularTrackColor: AppColors.darkSurfaceVariant,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        labelStyle: textTheme.labelSmall?.copyWith(color: AppColors.iceBlue),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static ThemeData lightTheme() {
    const cs = ColorScheme.light(
      surface: AppColors.lightSurface,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
      primary: AppColors.forestGreen,
      onPrimary: Colors.white,
      secondary: AppColors.forestGreenLight,
      onSecondary: Colors.white,
      onSurface: AppColors.lightOnSurface,
      error: AppColors.errorRed,
    );

    final textTheme = _buildTextTheme(
      ThemeData.light().textTheme,
      AppColors.lightOnSurface,
      AppColors.lightOnBackground,
    );

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: AppColors.lightOnBackground),
        iconTheme: const IconThemeData(color: AppColors.forestGreen),
        actionsIconTheme: const IconThemeData(color: AppColors.forestGreen),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: CircleBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: AppColors.forestGreenLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.lightOnSurface),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: AppColors.forestGreen),
        prefixIconColor: AppColors.forestGreenLight,
        suffixIconColor: AppColors.lightOnSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forestGreen,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.forestGreen,
          textStyle: textTheme.labelLarge,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleMedium?.copyWith(color: AppColors.lightOnBackground),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.lightOnSurface),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorderLight,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightSurfaceVariant,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.lightOnBackground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      iconTheme: const IconThemeData(color: AppColors.forestGreenLight, size: 22),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.forestGreen,
        linearTrackColor: AppColors.lightSurfaceVariant,
        circularTrackColor: AppColors.lightSurfaceVariant,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceVariant,
        labelStyle: textTheme.labelSmall?.copyWith(color: AppColors.forestGreenLight),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
