import 'package:flutter/material.dart';

abstract class AppColorsPalette {
  Color get primary;
  Color get primaryLight;
  Color get primaryDark;
  Color get indigo;
  Color get lavender;
  Color get scaffoldBg;
  Color get background;
  /// Literal white — only for text/icons on primary gradients / colored CTAs.
  Color get white;
  /// Fill for text fields sitting on [card] / [surface] (never literal white in dark).
  Color get inputFill;
  Color get surface;
  Color get card;
  Color get onPrimary;
  Color get onSurface;
  Color get orange;
  Color get green;
  Color get greenLight;
  Color get red;
  Color get redLight;
  Color get pink;
  Color get pinkIcon;
  Color get mint;
  Color get mintIcon;
  Color get lavenderCard;
  Color get textDark;
  Color get textMedium;
  Color get textLight;
  Color get border;
  Color get divider;
  LinearGradient get primaryGradient;
  LinearGradient get primaryGradientVertical;
}

class AppColorsLight implements AppColorsPalette {
  @override Color get primary => const Color(0xFF111111);
  @override Color get primaryLight => const Color(0xFF333333);
  @override Color get primaryDark => const Color(0xFF000000);
  @override Color get indigo => const Color(0xFF111111);
  @override Color get lavender => const Color(0xFFEBEBE6);
  @override Color get scaffoldBg => const Color(0xFFEBEBE6);
  @override Color get background => scaffoldBg;
  @override Color get white => const Color(0xFFFFFFFF);
  @override Color get inputFill => const Color(0xFFEBEBE6);
  @override Color get surface => const Color(0xFFEBEBE6);
  @override Color get card => const Color(0xFFEBEBE6);
  @override Color get onPrimary => const Color(0xFFEBEBE6); 
  @override Color get onSurface => const Color(0xFF111111);
  @override Color get orange => const Color(0xFF444444);
  @override Color get green => const Color(0xFF333333);
  @override Color get greenLight => const Color(0xFFDDDDDD);
  @override Color get red => const Color(0xFF555555);
  @override Color get redLight => const Color(0xFFEEEEEE);
  @override Color get pink => const Color(0xFFDDDDDD);
  @override Color get pinkIcon => const Color(0xFF333333);
  @override Color get mint => const Color(0xFFDDDDDD);
  @override Color get mintIcon => const Color(0xFF444444);
  @override Color get lavenderCard => const Color(0xFFEBEBE6);
  @override Color get textDark => const Color(0xFF111111);
  @override Color get textMedium => const Color(0xFF333333);
  @override Color get textLight => const Color(0xFF555555);
  @override Color get border => const Color(0xFF111111);
  @override Color get divider => const Color(0xFF111111);
  @override LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFF333333), Color(0xFF111111)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
  @override LinearGradient get primaryGradientVertical => const LinearGradient(
        colors: [Color(0xFF333333), Color(0xFF111111)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

class AppColorsDark implements AppColorsPalette {
  @override Color get primary => const Color(0xFFEBEBE6);
  @override Color get primaryLight => const Color(0xFFDDDDDD);
  @override Color get primaryDark => const Color(0xFFFFFFFF);
  @override Color get indigo => const Color(0xFFEBEBE6);
  @override Color get lavender => const Color(0xFF111111); 
  @override Color get scaffoldBg => const Color(0xFF111111); 
  @override Color get background => scaffoldBg;
  @override Color get white => const Color(0xFF111111); 
  @override Color get inputFill => const Color(0xFF111111);
  @override Color get surface => const Color(0xFF111111);
  @override Color get card => const Color(0xFF111111);
  @override Color get onPrimary => const Color(0xFF111111); 
  @override Color get onSurface => const Color(0xFFEBEBE6);
  @override Color get orange => const Color(0xFFBBBBBB);
  @override Color get green => const Color(0xFFCCCCCC);
  @override Color get greenLight => const Color(0xFF222222); 
  @override Color get red => const Color(0xFFAAAAAA);
  @override Color get redLight => const Color(0xFF333333); 
  @override Color get pink => const Color(0xFF333333); 
  @override Color get pinkIcon => const Color(0xFFCCCCCC);
  @override Color get mint => const Color(0xFF222222); 
  @override Color get mintIcon => const Color(0xFFBBBBBB);
  @override Color get lavenderCard => const Color(0xFF111111); 
  @override Color get textDark => const Color(0xFFEBEBE6); 
  @override Color get textMedium => const Color(0xFFCCCCCC);
  @override Color get textLight => const Color(0xFFAAAAAA);
  @override Color get border => const Color(0xFFEBEBE6); 
  @override Color get divider => const Color(0xFFEBEBE6); 
  @override LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFFCCCCCC), Color(0xFFEBEBE6)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
  @override LinearGradient get primaryGradientVertical => const LinearGradient(
        colors: [Color(0xFFCCCCCC), Color(0xFFEBEBE6)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

class AppColors {
  static final light = AppColorsLight();
  static final dark = AppColorsDark();
}

extension AppColorsExt on BuildContext {
  AppColorsPalette get colors => Theme.of(this).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
}
