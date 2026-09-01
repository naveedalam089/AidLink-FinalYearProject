// Purpose: App onboarding flow (intro slides, walkthrough, role selection).
// File: lib/views/common/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/typography.dart';
import '../../core/widgets/app_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    // --- Build onboarding pager with navigation controls ---
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: Text(
                  'Skip',
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => isLastPage = index == 2);
                },
                children: [
                  buildPage(
                    'assets/animations/onboarding1.json',
                    'Find Doctors Easily',
                    'Search verified doctors near you.',
                  ),
                  buildPage(
                    'assets/animations/onboarding2.json',
                    'Book Appointments',
                    'Schedule in-clinic or home visits.',
                  ),
                  buildPage(
                    'assets/animations/onboarding3.json',
                    'Chat Securely',
                    'Communicate with doctors anytime.',
                  ),
                ],
              ),
            ),
            SmoothPageIndicator(
              controller: _controller,
              count: 3,
              effect: WormEffect(activeDotColor: AppColors.primaryGreen),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppButton(
                text: isLastPage ? 'Get Started' : 'Next',
                onPressed: () {
                  if (isLastPage) {
                    _finishOnboarding();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Build a single onboarding page ---
  Widget buildPage(String animationPath, String title, String subtitle) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Lottie.asset(animationPath, height: 250),
        const SizedBox(height: 20),
        Text(
          title,
          style: AppTypography.heading2.copyWith(color: AppColors.primaryGreen),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: AppTypography.bodyText,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
