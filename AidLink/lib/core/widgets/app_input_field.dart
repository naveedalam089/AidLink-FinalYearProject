// Purpose: Reusable text input field widget with validation and consistent styling.
// File: lib/core/widgets/app_input_field.dart

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/spacing.dart';

class AppInputField extends StatefulWidget {
  final String hintText;
  final TextEditingController controller;
  final bool isPassword;
  final String? errorText;
  final TextInputType? keyboardType;

  const AppInputField({
    Key? key,
    required this.hintText,
    required this.controller,
    this.isPassword = false,
    this.errorText,
    this.keyboardType,
  }) : super(key: key);

  @override
  State<AppInputField> createState() => _AppInputFieldState();
}

class _AppInputFieldState extends State<AppInputField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    // --- Determine if field has validation error ---
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    // Build text field with dynamic borders
    return TextField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _obscure : false,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        hintText: widget.hintText,
        filled: true,
        fillColor: AppColors.backgroundWhite,
        contentPadding: const EdgeInsets.all(AppSpacing.md),

        // Error message shown below field
        errorText: widget.errorText,
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        errorMaxLines: 2,

        // Border changes to red when there's an error
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: hasError ? Colors.red : AppColors.borderGray,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: hasError ? Colors.red : AppColors.primaryGreen,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),

        // Password visibility toggle
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}
