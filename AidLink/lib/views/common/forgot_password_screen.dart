// Purpose: Forgot password recovery flow (email verification, password reset).
// File: lib/views/common/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/localization/app_text.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  String? errorMessage;
  bool _isSending = false;
  String? _prefilledEmail;

  String t(String english) => AppText.of(context, english);

  // --- Validate email format ---
  bool validateEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  // --- Trigger Firebase password reset flow ---
  Future<void> handleReset() async {
    final email = emailController.text.trim();

    if (!validateEmail(email)) {
      setState(() => errorMessage = t('Invalid email format'));
      return;
    }

    setState(() {
      errorMessage = null;
      _isSending = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'If an account exists for this email, a reset link has been sent.',
            ),
          ),
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        // Keep a generic message to avoid leaking whether an account exists.
        errorMessage = e.code == 'invalid-email'
            ? t('Invalid email format')
            : t('Could not send password reset email.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = t('Something went wrong. Please try again.');
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final initialEmail = ModalRoute.of(context)?.settings.arguments as String?;
    if (_prefilledEmail == initialEmail) return;
    _prefilledEmail = initialEmail;
    if (initialEmail != null && emailController.text.isEmpty) {
      emailController.text = initialEmail;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400), // ✅ Limit width
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t('Forgot Password'),
                    style: AppTypography.heading1.copyWith(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: t('Enter your email'),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 24),
                  AppButton(
                    text: _isSending ? t('Sending...') : t('Send Reset Link'),
                    onPressed: _isSending ? null : handleReset,
                    isLoading: _isSending,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      t('Back to Login'),
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
