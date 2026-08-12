import 'package:flutter/material.dart';

/// Clearance for the floating pill bottom nav in [ScaffoldWithNavBar].
///
/// Body uses [extendBody], so scrollables must leave this much room at the
/// bottom or the last content sits under the nav and cannot be reached.
const double kFloatingNavClearance = 100;

/// Extra space below page content inside tab shells (nav + breathing room).
const double kShellScrollBottomPadding = kFloatingNavClearance + 16;

/// Horizontal inset for main-shell screens (Home / Progress / Profile).
const double kScreenPadding = 20;

/// Default surface card corner radius (matches [CardTheme]).
const double kCardRadius = 0;

/// Modal bottom sheet top corner radius (matches [BottomSheetTheme]).
const double kSheetRadius = 0;

/// Primary / elevated button corner radius.
const double kButtonRadius = 0;

/// Outlined button corner radius (theme default).
const double kOutlinedButtonRadius = 0;

/// Full-width primary save CTA height.
const double kPrimaryButtonHeight = 52;

/// Compact row action height (Photo / Describe / Adjust).
const double kCompactButtonHeight = 40;

EdgeInsets shellScrollPadding(BuildContext context, {double horizontal = 0}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    0,
    horizontal,
    kShellScrollBottomPadding,
  );
}
