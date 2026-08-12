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
  @override Color get primary => const Color(0xFFE29B65);
  @override Color get primaryLight => const Color(0xFFEDBA94);
  @override Color get primaryDark => const Color(0xFFC57A42);
  @override Color get indigo => const Color(0xFF8C593C);
  @override Color get lavender => const Color(0xFFF2E2D3);
  @override Color get scaffoldBg => const Color(0xFFFAF2EA);
  @override Color get background => scaffoldBg;
  @override Color get white => const Color(0xFFFFFFFF);
  @override Color get inputFill => const Color(0xFFFDF8F3);
  @override Color get surface => const Color(0xFFFFFFFF);
  @override Color get card => const Color(0xFFFFFFFF);
  @override Color get onPrimary => const Color(0xFF2D1A25); // Dark text on the sandy button
  @override Color get onSurface => const Color(0xFF2D1A25);
  @override Color get orange => const Color(0xFFF97316);
  @override Color get green => const Color(0xFF22C55E);
  @override Color get greenLight => const Color(0xFFDCFCE7);
  @override Color get red => const Color(0xFFEF4444);
  @override Color get redLight => const Color(0xFFFEE2E2);
  @override Color get pink => const Color(0xFFFCE7F3);
  @override Color get pinkIcon => const Color(0xFFEC4899);
  @override Color get mint => const Color(0xFFD1FAE5);
  @override Color get mintIcon => const Color(0xFF10B981);
  @override Color get lavenderCard => const Color(0xFFF5EBE1);
  @override Color get textDark => const Color(0xFF2D1A25);
  @override Color get textMedium => const Color(0xFF8C593C);
  @override Color get textLight => const Color(0xFFBA9C8A);
  @override Color get border => const Color(0xFFEADBD1);
  @override Color get divider => const Color(0xFFF3E8DF);
  @override LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFFE7A473), Color(0xFFE29B65)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
  @override LinearGradient get primaryGradientVertical => const LinearGradient(
        colors: [Color(0xFFE7A473), Color(0xFFE29B65)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

class AppColorsDark implements AppColorsPalette {
  @override Color get primary => const Color(0xFFE29B65);
  @override Color get primaryLight => const Color(0xFFEDBA94);
  @override Color get primaryDark => const Color(0xFFC57A42);
  @override Color get indigo => const Color(0xFF8C593C);
  @override Color get lavender => const Color(0xFF251E1C); 
  @override Color get scaffoldBg => const Color(0xFF0D0B0D); 
  @override Color get background => scaffoldBg;
  @override Color get white => const Color(0xFFFFFFFF); 
  @override Color get inputFill => const Color(0xFF191518);
  @override Color get surface => const Color(0xFF120E11);
  @override Color get card => const Color(0xFF120E11);
  @override Color get onPrimary => const Color(0xFF2D1A25); 
  @override Color get onSurface => const Color(0xFFEFE8EA);
  @override Color get orange => const Color(0xFFF97316);
  @override Color get green => const Color(0xFF22C55E);
  @override Color get greenLight => const Color(0xFF14532D); 
  @override Color get red => const Color(0xFFEF4444);
  @override Color get redLight => const Color(0xFF7F1D1D); 
  @override Color get pink => const Color(0xFF501831); 
  @override Color get pinkIcon => const Color(0xFFF472B6);
  @override Color get mint => const Color(0xFF064E3B); 
  @override Color get mintIcon => const Color(0xFF34D399);
  @override Color get lavenderCard => const Color(0xFF2B2326); 
  @override Color get textDark => const Color(0xFFEFE8EA); 
  @override Color get textMedium => const Color(0xFFB5A5AA);
  @override Color get textLight => const Color(0xFF807075);
  @override Color get border => const Color(0xFF332A2F); 
  @override Color get divider => const Color(0xFF221C1F); 
  @override LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFFE7A473), Color(0xFFE29B65)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
  @override LinearGradient get primaryGradientVertical => const LinearGradient(
        colors: [Color(0xFFE7A473), Color(0xFFE29B65)],
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
