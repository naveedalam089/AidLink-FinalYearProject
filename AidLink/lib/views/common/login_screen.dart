import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ⭐ added for platform detection
// Purpose: Login screen for all user roles (patient, doctor, admin).
// File: lib/views/common/login_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/constants/spacing.dart';
import '../../core/widgets/app_input_field.dart';
import '../../core/constants/app_values.dart';
import '../../core/localization/app_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String t(String english) => AppText.of(context, english);

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedGender;
  bool isLogin = true;
  String? errorMessage;

  String selectedRole = "patient";

  // --- Field validators for auth form ---
  bool validateEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  bool validatePassword(String password) =>
      RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$').hasMatch(password);

  bool validateName(String name) => RegExp(r'^[A-Za-z]{2,}$').hasMatch(name);

  bool validateAge(String age) =>
      RegExp(r'^(1[89]|[2-9]\d|100)$').hasMatch(age);

  bool validateCity(String city) => RegExp(r'^[A-Za-z ]{2,}$').hasMatch(city);

  String? emailError;
  String? passwordError;
  String? firstNameError;
  String? lastNameError;
  String? ageError;
  String? genderError;
  String? cityError;
  bool _isSubmitting = false;

  // --- Handle login/signup submit flow ---
  Future<void> handleSubmit() async {
    setState(() {
      emailError = null;
      passwordError = null;
      firstNameError = null;
      lastNameError = null;
      ageError = null;
      genderError = null;
      cityError = null;
      errorMessage = null;
      _isSubmitting = false;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (!validateEmail(email)) emailError = 'Invalid email format';

    if (!validatePassword(password)) {
      passwordError =
          'Password must be 8+ chars, include uppercase, number & special char';
    }

    if (!isLogin) {
      if (!validateName(firstNameController.text.trim())) {
        firstNameError = 'First name must be at least 2 letters';
      }

      if (!validateName(lastNameController.text.trim())) {
        lastNameError = 'Last name must be at least 2 letters';
      }

      if (!validateAge(ageController.text.trim())) {
        ageError = 'Age must be between 18 and 100';
      }

      if (selectedGender == null) genderError = 'Please select a gender';

      if (!validateCity(cityController.text.trim())) {
        cityError = 'City must contain only letters';
      }
    }

    if (emailError != null ||
        passwordError != null ||
        firstNameError != null ||
        lastNameError != null ||
        ageError != null ||
        genderError != null ||
        cityError != null) {
      setState(() => _isSubmitting = false);
      return;
    }

    if (mounted) {
      setState(() => _isSubmitting = true);
    }

    try {
      if (isLogin) {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final signedInUser = userCredential.user;

        if (signedInUser == null) {
          setState(() => errorMessage = 'User record not found');
          return;
        }

        // Email verification gate disabled for local/testing doctor accounts.
        // if (!signedInUser.emailVerified) {
        //   await signedInUser.sendEmailVerification();
        //   await _auth.signOut();
        //   setState(() {
        //     errorMessage = t(
        //       'Please verify your email before logging in. We sent a verification link too.',
        //     );
        //   });
        //   return;
        // }

        final uid = signedInUser.uid;

        final doc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .get();

        if (!doc.exists) {
          setState(() => errorMessage = "User record not found");
          return;
        }

        final userData = doc.data() ?? <String, dynamic>{};
        final isBlocked = userData['blocked'] == true;
        if (isBlocked) {
          await _auth.signOut();
          if (!mounted) return;
          setState(() {
            errorMessage =
                'Your account is blocked. Please contact support/admin.';
          });
          return;
        }

        var role = (userData['role'] ?? '').toString();

        if (role.isEmpty) {
          final doctorDoc = await _firestore
              .collection(FirestoreCollections.doctors)
              .doc(uid)
              .get();
          final doctorData = doctorDoc.data();
          final doctorStatus = doctorData?['status']?.toString();

          if (doctorData != null) {
            role = UserRoles.doctor;
          } else {
            role = selectedRole;
          }

          await _firestore.collection(FirestoreCollections.users).doc(uid).set({
            'role': role,
            'roleRecoveredAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          if (role == UserRoles.doctor && doctorStatus == null) {
            await _firestore
                .collection(FirestoreCollections.doctors)
                .doc(uid)
                .set({
                  'status': DoctorStatus.pending,
                  'statusRecoveredAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          }
        }

        // ⭐ PATIENT
        if (role == UserRoles.patient) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
        // ⭐ DOCTOR
        else if (role == UserRoles.doctor) {
          final doctorDoc = await _firestore
              .collection(FirestoreCollections.doctors)
              .doc(uid)
              .get();

          final doctorData = doctorDoc.data();
          final doctorStatus = doctorData?['status']?.toString();

          if (doctorStatus == DoctorStatus.approved) {
            if (kIsWeb) {
              Navigator.pushReplacementNamed(context, '/doctor-dashboard-web');
            } else {
              Navigator.pushReplacementNamed(context, '/doctor-dashboard');
            }
          } else if (doctorStatus == DoctorStatus.rejected) {
            if (kIsWeb) {
              Navigator.pushReplacementNamed(
                context,
                '/doctor-rejection-feedback-web',
              );
            } else {
              Navigator.pushReplacementNamed(
                context,
                '/doctor-rejection-feedback',
              );
            }
          } else {
            if (kIsWeb) {
              Navigator.pushReplacementNamed(
                context,
                '/doctor-verification-web',
              );
            } else {
              Navigator.pushReplacementNamed(context, '/doctor-verification');
            }
          }
        }
        // ⭐ ADMIN
        else if (role == UserRoles.admin) {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        }
      } else {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final signedUpUser = userCredential.user;
        if (signedUpUser == null) {
          setState(() => errorMessage = 'User record not found');
          return;
        }

        final uid = signedUpUser.uid;

        await _firestore.collection(FirestoreCollections.users).doc(uid).set({
          'firstName': firstNameController.text.trim(),
          'lastName': lastNameController.text.trim(),
          'age': ageController.text.trim(),
          'city': cityController.text.trim(),
          'gender': selectedGender,
          'email': email,
          'role': selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await signedUpUser.sendEmailVerification();
        await _auth.signOut();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('Verification email sent. Please check your inbox.'),
            ),
          ),
        );

        setState(() {
          errorMessage = t(
            'Your account was created. Please verify your email before logging in.',
          );
        });
        return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AidLink',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primaryGreen,
      ),
      backgroundColor: AppColors.backgroundWhite,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin ? 'Login' : 'Sign Up',
                    style: AppTypography.heading1.copyWith(
                      color: AppColors.primaryGreen,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  if (!isLogin) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Sign up as"),

                        Row(
                          children: [
                            Radio<String>(
                              value: "patient",
                              groupValue: selectedRole,
                              onChanged: (value) {
                                setState(() {
                                  selectedRole = value!;
                                });
                              },
                            ),

                            const Text("Patient"),

                            Radio<String>(
                              value: "doctor",
                              groupValue: selectedRole,
                              onChanged: (value) {
                                setState(() {
                                  selectedRole = value!;
                                });
                              },
                            ),

                            const Text("Doctor"),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppInputField(
                      hintText: 'First Name',
                      controller: firstNameController,
                      errorText: firstNameError,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppInputField(
                      hintText: 'Last Name',
                      controller: lastNameController,
                      errorText: lastNameError,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppInputField(
                      hintText: 'Age',
                      controller: ageController,
                      errorText: ageError,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedGender,
                          hint: const Text('Select Gender'),
                          items: ['Male', 'Female', 'Other']
                              .map(
                                (gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedGender = value),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: genderError != null
                                    ? Colors.red
                                    : AppColors.borderGray,
                              ),
                            ),
                          ),
                        ),
                        if (genderError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              genderError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppInputField(
                      hintText: 'City',
                      controller: cityController,
                      errorText: cityError,
                    ),

                    const SizedBox(height: AppSpacing.md),
                  ],

                  AppInputField(
                    hintText: 'Email',
                    controller: emailController,
                    errorText: emailError,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  AppInputField(
                    hintText: 'Password',
                    controller: passwordController,
                    isPassword: true,
                    errorText: passwordError,
                  ),

                  if (isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                Navigator.pushNamed(
                                  context,
                                  '/forgot-password',
                                  arguments: emailController.text.trim(),
                                );
                              },
                        child: Text(
                          t('Forgot Password?'),
                          style: AppTypography.bodyText.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  //login and signup button
                  AppButton(
                    text: isLogin ? 'Login' : 'Sign Up',
                    onPressed: _isSubmitting ? null : handleSubmit,
                    isLoading: _isSubmitting,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin
                          ? 'Create an account'
                          : 'Already have an account?',
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
