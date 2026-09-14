import 'package:flutter/material.dart';

/// Centralized dimensions and spacing constants
///
/// Usage:
/// ```dart
/// Padding(padding: AppDimensions.paddingAll)
/// SizedBox(height: AppDimensions.spacingMedium)
/// BorderRadius.circular(AppDimensions.radiusMedium)
/// ```
class AppDimensions {
  // Spacing (for SizedBox, gaps between elements)
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Padding (for Container, Card, etc.)
  static const double paddingValue = 16.0;
  static const double paddingSmall = 8.0;
  static const double paddingLarge = 24.0;

  static const EdgeInsets paddingAll = EdgeInsets.all(paddingValue);
  static const EdgeInsets paddingAllSmall = EdgeInsets.all(paddingSmall);
  static const EdgeInsets paddingAllLarge = EdgeInsets.all(paddingLarge);
  static const EdgeInsets paddingAllMedium = EdgeInsets.all(paddingValue);
  static const EdgeInsets paddingAllXLarge = EdgeInsets.all(spacingXLarge);

  static const EdgeInsets paddingHorizontal = EdgeInsets.symmetric(
    horizontal: paddingValue,
  );

  static const EdgeInsets paddingVertical = EdgeInsets.symmetric(
    vertical: paddingValue,
  );

  static const EdgeInsets paddingSymmetric = EdgeInsets.symmetric(
    horizontal: paddingValue,
    vertical: paddingSmall,
  );

  static const EdgeInsets paddingCard = EdgeInsets.all(16.0);
  static const EdgeInsets paddingScreen = EdgeInsets.all(16.0);
  static const EdgeInsets paddingDialog = EdgeInsets.all(24.0);

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  static const BorderRadius borderRadiusSmall = BorderRadius.all(
    Radius.circular(radiusSmall),
  );

  static const BorderRadius borderRadiusMedium = BorderRadius.all(
    Radius.circular(radiusMedium),
  );

  static const BorderRadius borderRadiusLarge = BorderRadius.all(
    Radius.circular(radiusLarge),
  );

  static const BorderRadius borderRadiusXLarge = BorderRadius.all(
    Radius.circular(radiusXLarge),
  );

  // Icon Sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;

  // Button Heights
  static const double buttonHeightSmall = 40.0;
  static const double buttonHeightMedium = 50.0;
  static const double buttonHeightLarge = 56.0;

  // Button Radius (specific for buttons to override default)
  static const double buttonRadiusMedium = 12.0;

  // Margins (for spacing between cards/sections)
  static const EdgeInsets marginCard = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  static const EdgeInsets marginCardHorizontal = EdgeInsets.symmetric(
    horizontal: 16,
  );

  static const EdgeInsets marginBottom = EdgeInsets.only(bottom: 16);
  static const EdgeInsets marginTop = EdgeInsets.only(top: 16);

  // Elevation
  static const double elevationLow = 1.0;
  static const double elevationMedium = 2.0;
  static const double elevationHigh = 4.0;
  static const double elevationXHigh = 8.0;
}
