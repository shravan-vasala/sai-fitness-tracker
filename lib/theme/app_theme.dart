import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorsLight().scaffoldBg,
      primaryColor: AppColorsLight().primary,
      colorScheme: ColorScheme.light(
        primary: AppColorsLight().primary,
        secondary: AppColorsLight().indigo,
        surface: AppColorsLight().white,
        error: AppColorsLight().red,
        onPrimary: AppColorsLight().white,
        onSecondary: AppColorsLight().white,
        onSurface: AppColorsLight().textDark,
        onError: AppColorsLight().white,
      ),
      textTheme: GoogleFonts.courierPrimeTextTheme(
        TextTheme(
          headlineLarge: GoogleFonts.lora(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColorsLight().textDark,
            letterSpacing: -0.5,
          ),
          headlineMedium: GoogleFonts.lora(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColorsLight().textDark,
            letterSpacing: -0.3,
          ),
          headlineSmall: GoogleFonts.lora(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColorsLight().textDark,
          ),
          titleLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColorsLight().textDark,
          ),
          titleMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColorsLight().textDark,
          ),
          titleSmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColorsLight().textMedium,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColorsLight().textDark,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColorsLight().textMedium,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColorsLight().textLight,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColorsLight().textDark,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColorsLight().textMedium,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColorsLight().textLight,
            letterSpacing: 0.5,
          ),
        ),
      ).apply(
        bodyColor: AppColorsLight().textDark,
        displayColor: AppColorsLight().textDark,
      ),
      cardTheme: CardThemeData(
        color: AppColorsLight().card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColorsLight().border, width: 1),
        ),
        shadowColor: AppColorsLight().textDark.withValues(alpha: 0.03),
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        backgroundColor: AppColorsLight().scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColorsLight().textDark,
        ),
        iconTheme: IconThemeData(color: AppColorsLight().textDark),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColorsLight().white,
        selectedItemColor: AppColorsLight().primary,
        unselectedItemColor: AppColorsLight().textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsLight().primary,
          foregroundColor: AppColorsLight().white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.courierPrime(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsLight().primary,
          side: BorderSide(color: AppColorsLight().primary, width: 1.5),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.courierPrime(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColorsLight().card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColorsLight().card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.zero),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsLight().textDark,
        contentTextStyle: GoogleFonts.courierPrime(color: AppColorsLight().white),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsLight().inputFill,
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
          borderSide: BorderSide(color: AppColorsLight().primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: TextStyle(
          color: AppColorsLight().textMedium,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: AppColorsLight().primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: AppColorsLight().textLight,
          fontSize: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColorsLight().divider,
        thickness: 1,
        space: 0,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColorsLight().green;
          }
          return Colors.transparent;
        }),
        shape: CircleBorder(),
        side: BorderSide(color: AppColorsLight().border, width: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColorsLight().card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.courierPrime(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColorsLight().textDark,
        ),
        contentTextStyle: GoogleFonts.courierPrime(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColorsLight().textMedium,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: AppColorsLight().textDark, fontSize: 14),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColorsLight().card),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: GoogleFonts.courierPrime(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColorsLight().textDark,
        ),
        subtitleTextStyle: GoogleFonts.courierPrime(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColorsLight().textMedium,
        ),
        iconColor: AppColorsLight().textMedium,
      ),
      canvasColor: AppColorsLight().card,
      popupMenuTheme: PopupMenuThemeData(
        color: AppColorsLight().card,
        textStyle: TextStyle(color: AppColorsLight().textDark),
      ),
    );
  }


  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColorsDark().scaffoldBg,
      primaryColor: AppColorsDark().primary,
      colorScheme: ColorScheme.dark(
        primary: AppColorsDark().primary,
        secondary: AppColorsDark().indigo,
        surface: AppColorsDark().surface,
        error: AppColorsDark().red,
        onPrimary: AppColorsDark().onPrimary,
        onSecondary: AppColorsDark().onPrimary,
        onSurface: AppColorsDark().onSurface,
        onError: AppColorsDark().onPrimary,
      ),
      textTheme: GoogleFonts.courierPrimeTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).apply(
        bodyColor: AppColorsDark().textDark,
        displayColor: AppColorsDark().textDark,
      ).copyWith(
        headlineLarge: GoogleFonts.lora(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColorsDark().textDark,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.lora(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColorsDark().textDark,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.lora(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColorsDark().textDark,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColorsDark().textDark,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColorsDark().textDark,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColorsDark().textMedium,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColorsDark().textDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColorsDark().textMedium,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColorsDark().textLight,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColorsDark().textDark,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColorsDark().textMedium,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColorsDark().textLight,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColorsDark().card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColorsDark().border, width: 1),
        ),
        shadowColor: AppColorsDark().textDark.withValues(alpha: 0.03),
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: AppColorsDark().scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColorsDark().textDark,
        ),
        iconTheme: IconThemeData(color: AppColorsDark().textDark),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColorsDark().card,
        selectedItemColor: AppColorsDark().primary,
        unselectedItemColor: AppColorsDark().textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsDark().primary,
          foregroundColor: AppColorsDark().white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.courierPrime(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsDark().primary,
          side: BorderSide(color: AppColorsDark().primary, width: 1.5),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.courierPrime(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColorsDark().card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColorsDark().card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.zero),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsDark().surface,
        contentTextStyle: GoogleFonts.courierPrime(color: AppColorsDark().textDark),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark().inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColorsDark().border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColorsDark().primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: TextStyle(
          color: AppColorsDark().textMedium,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: AppColorsDark().primaryLight,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: AppColorsDark().textLight,
          fontSize: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColorsDark().divider,
        thickness: 1,
        space: 0,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColorsDark().green;
          }
          return Colors.transparent;
        }),
        shape: CircleBorder(),
        side: BorderSide(color: AppColorsDark().border, width: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColorsDark().card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.courierPrime(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColorsDark().textDark,
        ),
        contentTextStyle: GoogleFonts.courierPrime(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColorsDark().textMedium,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: AppColorsDark().textDark, fontSize: 14),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColorsDark().card),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: GoogleFonts.courierPrime(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColorsDark().textDark,
        ),
        subtitleTextStyle: GoogleFonts.courierPrime(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColorsDark().textMedium,
        ),
        iconColor: AppColorsDark().textMedium,
      ),
      canvasColor: AppColorsDark().card,
      popupMenuTheme: PopupMenuThemeData(
        color: AppColorsDark().card,
        textStyle: TextStyle(color: AppColorsDark().textDark),
      ),
    );
  }
}
