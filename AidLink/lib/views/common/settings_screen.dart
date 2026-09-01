import 'dart:convert';
import 'dart:typed_data';

// Purpose: User settings (notifications, language, password, profile, account).
// File: lib/views/common/settings_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_values.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/localization/app_language_controller.dart';
import '../../core/localization/app_text.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isUpdatingPreferences = false;
  bool _isSigningOut = false;
  bool _isUploadingPhoto = false;
  DateTime? _lastPreferenceSyncAt;

  String _email = '';
  String _role = 'user';
  String _displayName = 'Account';
  String _profilePhotoUrl = '';
  bool _notificationsEnabled = true;
  bool _emailUpdatesEnabled = true;
  bool _appointmentRemindersEnabled = true;
  String _selectedLanguageCode = 'en';

  static const String imgbbApiKey = 'YOUR_IMGBB_API_KEY_HERE';
  static final RegExp _nameRegex = RegExp(r"^[A-Za-z][A-Za-z\s'-]{1,49}$");
  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String t(String english) => AppText.of(context, english);

  // --- Profile field validators ---
  String? _validateFirstName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter first name';
    if (!_nameRegex.hasMatch(v)) {
      return 'Use 2-50 letters only';
    }
    return null;
  }

  String? _validateLastName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter last name';
    if (!_nameRegex.hasMatch(v)) {
      return 'Use 2-50 letters only';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter phone number';
    if (!_phoneRegex.hasMatch(v)) {
      return 'Enter valid phone (10-15 digits)';
    }
    return null;
  }

  void _handleBackNavigation() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
  }

  @override
  void initState() {
    super.initState();
    // --- Load user settings on screen start ---
    _loadSettings();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<String?> _uploadProfilePhoto(
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      const int maxBytesForInlineStorage = 700 * 1024; // 700 KB
      if (fileBytes.length > maxBytesForInlineStorage) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File is too large (${(fileBytes.length / 1024).ceil()} KB). Please use a file under 700 KB.',
            ),
          ),
        );
        return null;
      }

      if (imgbbApiKey == 'YOUR_IMGBB_API_KEY_HERE') {
        return 'data:image/png;base64,${base64Encode(fileBytes)}';
      }

      final base64Image = base64Encode(fileBytes);
      final response = await http
          .post(
            Uri.parse('https://api.imgbb.com/1/upload'),
            body: {'image': base64Image, 'name': fileName, 'key': imgbbApiKey},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return jsonResponse['data']['url'] as String?;
      }

      // Fallback: Use Base64
      return 'data:image/png;base64,$base64Image';
    } catch (e) {
      // Fallback: Use Base64
      return 'data:image/png;base64,${base64Encode(fileBytes)}';
    }
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() => _isUploadingPhoto = true);

      final url = await _uploadProfilePhoto(bytes, file.name);
      if (url == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('Failed to upload profile photo.'))),
        );
        setState(() => _isUploadingPhoto = false);
        return;
      }

      final user = _currentUser;
      if (user == null) {
        setState(() => _isUploadingPhoto = false);
        return;
      }

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .set({
            'profilePhotoUrl': url,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = url;
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Profile photo updated successfully.'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Error uploading profile photo.'))),
      );
    }
  }

  Widget _buildProfilePhoto() {
    if (_profilePhotoUrl.isNotEmpty) {
      if (_profilePhotoUrl.startsWith('data:')) {
        // Base64 image
        final base64String = _profilePhotoUrl.split(',').last;
        return CircleAvatar(
          radius: 28,
          backgroundImage: MemoryImage(base64Decode(base64String)),
        );
      } else {
        // URL image
        return CircleAvatar(
          radius: 28,
          backgroundImage: NetworkImage(_profilePhotoUrl),
        );
      }
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final initials = _initials(firstName, lastName, _email);

    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.white.withOpacity(0.18),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  String _safeText(dynamic value, [String fallback = '']) {
    final text = (value ?? fallback).toString().trim();
    return text;
  }

  String _buildDisplayName(String firstName, String lastName) {
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();
    return fullName.isEmpty ? 'Account' : fullName;
  }

  String _initials(String firstName, String lastName, String email) {
    final parts = [
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) {
      return parts
          .take(2)
          .map((part) => part.trim().characters.first.toUpperCase())
          .join();
    }

    if (email.isNotEmpty) {
      return email.characters.first.toUpperCase();
    }

    return 'A';
  }

  bool _hasPasswordProvider(User user) {
    return user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
  }

  String _friendlyPasswordError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
        return 'Current password is incorrect.';
      case 'invalid-credential':
        return 'Current password is incorrect or this account does not use email/password sign-in.';
      case 'requires-recent-login':
        return 'For security, please sign in again and retry changing your password.';
      case 'weak-password':
        return 'New password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return error.message ?? 'Could not change password right now.';
    }
  }

  Future<void> _loadSettings() async {
    final user = _currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();

      final data = snapshot.data() ?? <String, dynamic>{};
      final settings = data[UserSettingsFields.settings] is Map
          ? Map<String, dynamic>.from(data[UserSettingsFields.settings] as Map)
          : <String, dynamic>{};

      final firstName = _safeText(data['firstName']);
      final lastName = _safeText(data['lastName']);
      final phoneNumber = _safeText(data['phoneNumber']);

      _firstNameController.text = firstName;
      _lastNameController.text = lastName;
      _phoneController.text = phoneNumber;

      _email = _safeText(user.email);
      _role = _safeText(data['role'], 'user');
      _displayName = _buildDisplayName(firstName, lastName);
      _profilePhotoUrl = _safeText(data['profilePhotoUrl']);
      _notificationsEnabled =
          settings[UserSettingsFields.notificationsEnabled] ?? true;
      _emailUpdatesEnabled =
          settings[UserSettingsFields.emailUpdatesEnabled] ?? true;
      _appointmentRemindersEnabled =
          settings[UserSettingsFields.appointmentRemindersEnabled] ?? true;
      final savedLanguage = (settings[UserSettingsFields.language] ?? 'en')
          .toString();
      _selectedLanguageCode = savedLanguage == 'ur' ? 'ur' : 'en';

      final updatedAt = data['updatedAt'];
      if (updatedAt is Timestamp) {
        _lastPreferenceSyncAt = updatedAt.toDate();
      }

      await AppLanguageController.instance.setLanguageCode(
        _selectedLanguageCode,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Could not load settings right now.'))),
      );
    }
  }

  Future<void> _saveProfile() async {
    final user = _currentUser;
    if (user == null) return;

    if (!_profileFormKey.currentState!.validate()) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final displayName = _buildDisplayName(firstName, lastName);

    setState(() => _isSavingProfile = true);

    try {
      await user.updateDisplayName(displayName);
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .set({
            'firstName': firstName,
            'lastName': lastName,
            'phoneNumber': phone,
            'displayName': displayName,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _displayName = displayName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Profile updated successfully.'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('Could not update profile.'))));
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _savePreferences({
    bool? notificationsEnabled,
    bool? emailUpdatesEnabled,
    bool? appointmentRemindersEnabled,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    final nextNotifications = notificationsEnabled ?? _notificationsEnabled;
    final nextEmailUpdates = emailUpdatesEnabled ?? _emailUpdatesEnabled;
    final nextAppointmentReminders =
        appointmentRemindersEnabled ?? _appointmentRemindersEnabled;

    setState(() {
      _isUpdatingPreferences = true;
      _notificationsEnabled = nextNotifications;
      _emailUpdatesEnabled = nextEmailUpdates;
      _appointmentRemindersEnabled = nextAppointmentReminders;
    });

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .set({
            UserSettingsFields.settings: {
              UserSettingsFields.notificationsEnabled: nextNotifications,
              UserSettingsFields.emailUpdatesEnabled: nextEmailUpdates,
              UserSettingsFields.appointmentRemindersEnabled:
                  nextAppointmentReminders,
              UserSettingsFields.language: _selectedLanguageCode,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _lastPreferenceSyncAt = DateTime.now();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('Preferences saved.'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('Could not save preferences.'))));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPreferences = false);
      }
    }
  }

  Future<void> _updateLanguage(String code) async {
    final normalized = code == 'ur' ? 'ur' : 'en';
    setState(() => _selectedLanguageCode = normalized);
    await AppLanguageController.instance.setLanguageCode(normalized);
    await _savePreferences();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t('Language updated.'))));
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('No email address found for this account.'))),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t('Password reset email sent to')} $_email')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Could not send password reset email.'))),
      );
    }
  }

  Future<void> _showChangePasswordSheet() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    Future<void> submitSheet(
      BuildContext sheetContext,
      void Function(void Function()) setSheetState,
    ) async {
      final user = _currentUser;
      if (user == null) return;

      final email = (user.email ?? _email).trim();
      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('No email found for this account.'))),
        );
        return;
      }

      if (!_hasPasswordProvider(user)) {
        Navigator.of(sheetContext).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This account is signed in with a social provider. Use password reset email instead.',
            ),
          ),
        );
        return;
      }

      if (!formKey.currentState!.validate()) return;

      setSheetState(() => submitting = true);
      try {
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentPasswordController.text.trim(),
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPasswordController.text.trim());
        Navigator.of(sheetContext).pop(true);
        return;
      } on FirebaseAuthException catch (error) {
        setSheetState(() => submitting = false);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyPasswordError(error))));
      } catch (_) {
        setSheetState(() => submitting = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('Could not change password.'))),
        );
      }
    }

    final passwordUpdated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Change Password', style: AppTypography.heading2),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Confirm your current password before setting a new one.',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: currentPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Current password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your current password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 6) {
                              return 'Use at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm new password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Confirm your new password';
                            }
                            if (value.trim() !=
                                newPasswordController.text.trim()) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () =>
                                      submitSheet(sheetContext, setSheetState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Update Password',
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();

    if (passwordUpdated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Password updated successfully.'))),
      );
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EEE8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primaryGreen).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.primaryGreen),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyText.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodyText.copyWith(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _preferenceSwitchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FAF3) : const Color(0xFFF7F8F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? const Color(0xFFBFE7CA) : const Color(0xFFE3E8E4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(value ? 0.16 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyText.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodyText.copyWith(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.primaryGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _syncLabel(DateTime? syncedAt) {
    if (syncedAt == null) return t('Not synced yet');
    final now = DateTime.now();
    final diff = now.difference(syncedAt);
    if (diff.inSeconds < 60) return t('Synced just now');
    if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
    return 'Synced on ${syncedAt.day}/${syncedAt.month}/${syncedAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            t('Settings'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBackNavigation,
          ),
          backgroundColor: AppColors.primaryGreen,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final initials = _initials(firstName, lastName, _email);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF8),
      appBar: AppBar(
        title: Text(
          t('Settings'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBackNavigation,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryGreen, Color(0xFF1AA24A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      _buildProfilePhoto(),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploadingPhoto
                              ? null
                              : _pickAndUploadProfilePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryGreen,
                                width: 2,
                              ),
                            ),
                            child: _isUploadingPhoto
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryGreen,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: AppColors.primaryGreen,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: AppTypography.heading2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email.isEmpty ? t('No email found') : _email,
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.white.withOpacity(0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _role.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _sectionCard(
              child: Form(
                key: _profileFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('Profile'), style: AppTypography.heading2),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Keep your account details up to date.',
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First name',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validateFirstName,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last name',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validateLastName,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingProfile ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _isSavingProfile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save, color: Colors.white),
                        label: Text(
                          _isSavingProfile ? t('Saving...') : t('Save Profile'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Preferences'), style: AppTypography.heading2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    t('Choose how AidLink keeps you informed.'),
                    style: AppTypography.bodyText.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguageCode,
                    decoration: InputDecoration(
                      labelText: t('Language'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.language),
                    ),
                    items: [
                      DropdownMenuItem(value: 'en', child: Text(t('English'))),
                      DropdownMenuItem(value: 'ur', child: Text(t('Urdu'))),
                    ],
                    onChanged: _isUpdatingPreferences
                        ? null
                        : (value) {
                            if (value == null) return;
                            _updateLanguage(value);
                          },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _preferenceSwitchCard(
                    icon: Icons.notifications_active_outlined,
                    title: t('Push notifications'),
                    subtitle: 'Receive alerts for appointments and updates.',
                    value: _notificationsEnabled,
                    onChanged: _isUpdatingPreferences
                        ? null
                        : (value) =>
                              _savePreferences(notificationsEnabled: value),
                  ),
                  _preferenceSwitchCard(
                    icon: Icons.mark_email_unread_outlined,
                    title: t('Email updates'),
                    subtitle: 'Get summary emails and reminders.',
                    value: _emailUpdatesEnabled,
                    onChanged: _isUpdatingPreferences
                        ? null
                        : (value) =>
                              _savePreferences(emailUpdatesEnabled: value),
                  ),
                  _preferenceSwitchCard(
                    icon: Icons.alarm_on_outlined,
                    title: t('Appointment reminders'),
                    subtitle: 'Stay on top of upcoming visits.',
                    value: _appointmentRemindersEnabled,
                    onChanged: _isUpdatingPreferences
                        ? null
                        : (value) => _savePreferences(
                            appointmentRemindersEnabled: value,
                          ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _syncLabel(_lastPreferenceSyncAt),
                        style: AppTypography.bodyText.copyWith(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Security'), style: AppTypography.heading2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Protect your account and keep access secure.',
                    style: AppTypography.bodyText.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _settingTile(
                    icon: Icons.lock_outline,
                    title: t('Change password'),
                    subtitle: 'Use your current password to create a new one.',
                    onTap: _showChangePasswordSheet,
                  ),
                  const Divider(height: AppSpacing.lg),
                  _settingTile(
                    icon: Icons.email_outlined,
                    title: t('Send password reset email'),
                    subtitle:
                        'We will send a reset link to your email address.',
                    onTap: _sendPasswordResetEmail,
                  ),
                ],
              ),
            ),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Account'), style: AppTypography.heading2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Need a quick action? Use these shortcuts.',
                    style: AppTypography.bodyText.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _settingTile(
                    icon: Icons.help_outline,
                    title: t('Help & Support'),
                    subtitle: 'Read FAQs or send a support request.',
                    onTap: () => Navigator.pushNamed(context, '/help-support'),
                  ),
                  const Divider(height: AppSpacing.lg),
                  _settingTile(
                    icon: Icons.logout,
                    title: t('Sign out'),
                    subtitle: 'End your session on this device.',
                    iconColor: Colors.red,
                    onTap: _isSigningOut ? () {} : _signOut,
                  ),
                  if (_isSigningOut) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
