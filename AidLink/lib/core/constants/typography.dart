// Purpose: Central text styles used across the application for consistency.
// File: lib/core/constants/typography.dart

import 'package:flutter/material.dart';
import 'colors.dart';

class AppTypography {
  // --- Shared font family ---
  static const String fontFamily = 'Roboto';

  // --- Heading and body text styles ---
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
    fontFamily: fontFamily,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
    fontFamily: fontFamily,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    fontFamily: fontFamily,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark,
    fontFamily: fontFamily,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    fontFamily: fontFamily,
  );
}
