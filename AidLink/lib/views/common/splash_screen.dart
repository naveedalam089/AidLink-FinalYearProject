// Purpose: Splash/loading screen shown on app startup before routing to next screen.
// File: lib/views/common/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_values.dart';
import '../../core/constants/colors.dart';
import '../../core/services/push_notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // --- Decide where to route after splash ---
    _decideNextRoute();
  }

  Future<void> _decideNextRoute() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Request runtime notification permission after the first visible frame,
    // when the splash screen is already on-screen.
    await PushNotificationService.requestRuntimePermissions();

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      final route = await _routeForUser(currentUser.uid);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      hasSeenOnboarding ? '/login' : '/onboarding',
    );
  }

  Future<String> _routeForUser(String uid) async {
    final userDoc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();

    final role = (userDoc.data()?['role'] ?? '').toString();
    if (role == UserRoles.doctor) {
      final doctorDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.doctors)
          .doc(uid)
          .get();

      final status = (doctorDoc.data()?['status'] ?? '').toString();
      if (status == DoctorStatus.approved) {
        return '/doctor-dashboard';
      }
      return '/doctor-verification';
    }

    if (role == UserRoles.admin) {
      return '/admin-dashboard';
    }

    return '/dashboard';
  }

  @override
  Widget build(BuildContext context) {
    // --- Build splash animation and app branding ---
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie Animation
            Lottie.asset(
              'assets/animations/Loading.json',
              width: 200,
              height: 100,
            ),
            const SizedBox(height: 5),
            // App Name
            Text(
              'AidLink',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
