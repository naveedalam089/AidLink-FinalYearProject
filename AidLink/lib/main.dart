// Purpose: Entry point of the AidLink application (Firebase init, routing, localization).
// File: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/push_notification_service.dart';
import 'views/common/splash_screen.dart';
import 'views/common/onboarding_screen.dart';
import 'views/common/login_screen.dart';
import 'views/common/forgot_password_screen.dart';
import 'views/patient/dashboard_screen.dart';
import 'views/patient/doctor_detail_screen.dart';
import 'views/patient/appointment_booking_screen.dart';
import 'views/patient/upcoming_appointments_screen.dart';
import 'views/patient/appointment_history_screen.dart';
import 'views/patient/my_prescriptions_screen.dart';
import 'views/patient/postponed_offer_screen.dart';
import 'views/common/settings_screen.dart';
import 'views/common/notifications_screen.dart';
import 'views/patient/help_support_screen.dart';
import 'views/patient/nearby_map_screen.dart';
import 'views/patient/pescription_detail_screen.dart';
import 'views/doctor_mobile/dashboard_screen.dart';
import 'views/doctor_mobile/verification_screen.dart';
import 'views/doctor_mobile/edit_profile_screen.dart';
import 'views/doctor_mobile/doctor_rejection_feedback_screen.dart';
import 'views/doctor_web/dashboard_screen.dart';
import 'views/doctor_web/verification_screen_web.dart';
import 'views/doctor_web/edit_profile_screen_web.dart';
import 'views/admin/dashboard_screen.dart';
import 'views/doctor_mobile/doctor_chats_screen.dart';
import 'views/doctor_mobile/doctor_chat_screen.dart';
import 'views/patient/patient_chats_screen.dart';
import 'views/patient/patient_chat_screen.dart';

// firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/localization/app_language_controller.dart';

// --- App startup: Firebase, localization, and root widget ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppLanguageController.instance.load();
  await PushNotificationService.initialize();

  runApp(const AidLinkApp());
}

class AidLinkApp extends StatelessWidget {
  const AidLinkApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- Root app shell with localization and named routes ---
    return AnimatedBuilder(
      animation: AppLanguageController.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AidLink',
          locale: AppLanguageController.instance.locale,
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            primaryColor: const Color(0xFF18D948),
            scaffoldBackgroundColor: Colors.white,
            fontFamily: 'Roboto',
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/doctor-detail': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              return DoctorDetailScreen.fromArgs(args);
            },
            '/appointment-booking': (context) =>
                const AppointmentBookingScreen(),
            '/upcoming-appointments': (context) =>
                const UpcomingAppointmentsScreen(),
            '/appointment-history': (context) =>
                const AppointmentHistoryScreen(),
            '/prescriptions': (context) => const MyPrescriptionsScreen(),
            '/postponed-offer': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              return PostponedOfferScreen(
                offerId: (args?['offerId'] ?? '').toString(),
              );
            },
            '/settings': (context) => const SettingsScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            '/help-support': (context) => const HelpSupportScreen(),
            '/nearby-map': (context) => const NearbyMapScreen(),
            '/prescription-detail': (context) =>
                const PrescriptionDetailScreen(),
            '/patient-chats': (context) => const PatientChatsScreen(),
            '/patient-chat': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              return PatientChatScreen.fromArgs(args);
            },
            //'/doctor-category': (context) => const DoctorCategoryScreen(),

            // Doctor flow
            '/doctor-dashboard': (context) => const DoctorDashboardScreen(),
            '/doctor-verification': (context) =>
                const DoctorVerificationScreen(),
            '/doctor-verification-web': (context) =>
                const DoctorVerificationScreenWeb(),
            '/doctor-edit-profile': (context) => const EditProfileScreen(),
            '/doctor-edit-profile-web': (context) =>
                const EditProfileScreenWeb(),
            '/doctor-chats': (_) => const DoctorChatsScreen(),
            '/doctor-chat': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              return DoctorChatScreen.fromArgs(args);
            },
            '/doctor-rejection-feedback': (context) =>
                const DoctorRejectionFeedbackScreen(),
            '/doctor-rejection-feedback-web': (context) =>
                const DoctorRejectionFeedbackScreen(),

            // doctor flow web
            '/doctor-dashboard-web': (context) => const DashboardScreenWeb(),

            // admin web
            '/admin-dashboard': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              final initialIndex = args?['initialIndex'];
              return AdminDashboardScreen(
                initialIndex: initialIndex is int ? initialIndex : 0,
              );
            },
          },
        );
      },
    );
  }
}
