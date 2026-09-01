// Purpose: Reusable app-wide button widget with consistent styling.
// File: lib/core/widgets/app_button.dart

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../constants/spacing.dart';

// --- Reusable button with primary/secondary styles and loading state ---
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;

  const AppButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- Determine text color based on button style ---
    final Color textColor = isPrimary ? Colors.white : AppColors.primaryGreen;

    // --- Build button with style configuration ---
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? AppColors.primaryGreen
            : AppColors.backgroundWhite,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        // Secondary button has border, primary is filled
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: AppColors.primaryGreen),
        ),
      ),
      onPressed: onPressed,
      // Show loading spinner or text
      child: isLoading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(textColor),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: AppTypography.buttonText.copyWith(color: textColor),
                ),
              ],
            )
          : Text(
              text,
              style: AppTypography.buttonText.copyWith(color: textColor),
            ),
    );
  }
}
