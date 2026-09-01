import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Purpose: Admin section for system-wide settings and configuration.
// File: lib/views/admin/sections/settings_section.dart

import 'package:flutter/material.dart';

import '../../../core/constants/app_values.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/app_button.dart';

class SettingsSection extends StatefulWidget {
  const SettingsSection({Key? key}) : super(key: key);

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  bool newDoctorRequestsEnabled = true;
  bool appointmentUpdatesEnabled = true;
  bool dailyDigestEnabled = false;
  bool systemAnnouncementsEnabled = true;

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  String? email;
  String? role;
  DateTime? createdAt;
  DateTime? updatedAt;

  @override
  void initState() {
    super.initState();
    // --- Load admin profile and notification settings ---
    _loadSettings();
  }

  @override
  void dispose() {
    // --- Cleanup controllers ---
    firstNameController.dispose();
    lastNameController.dispose();
    cityController.dispose();
    super.dispose();
  }

  // --- Read current admin settings from Firestore ---
  Future<void> _loadSettings() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'No admin session found. Please log in again.';
        isLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(currentUser.uid)
          .get();

      final data = snapshot.data() ?? <String, dynamic>{};
      final rawSettings = data['adminSettings'];
      final settings = rawSettings is Map
          ? Map<String, dynamic>.from(rawSettings)
          : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        firstNameController.text = (data['firstName'] ?? '').toString();
        lastNameController.text = (data['lastName'] ?? '').toString();
        cityController.text = (data['city'] ?? '').toString();
        email = (data['email'] ?? currentUser.email ?? '').toString();
        role = (data['role'] ?? UserRoles.admin).toString();
        newDoctorRequestsEnabled = settings['newDoctorRequestsEnabled'] ?? true;
        appointmentUpdatesEnabled =
            settings['appointmentUpdatesEnabled'] ?? true;
        dailyDigestEnabled = settings['dailyDigestEnabled'] ?? false;
        systemAnnouncementsEnabled =
            settings['systemAnnouncementsEnabled'] ?? true;

        createdAt = (data['createdAt'] is Timestamp)
            ? (data['createdAt'] as Timestamp).toDate()
            : null;
        updatedAt = (data['updatedAt'] is Timestamp)
            ? (data['updatedAt'] as Timestamp).toDate()
            : null;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to load admin settings.';
        isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (mounted) {
      setState(() {
        isSaving = true;
        errorMessage = null;
      });
    }

    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(currentUser.uid)
          .set({
            'firstName': firstNameController.text.trim(),
            'lastName': lastNameController.text.trim(),
            'city': cityController.text.trim(),
            'adminSettings': {
              'newDoctorRequestsEnabled': newDoctorRequestsEnabled,
              'appointmentUpdatesEnabled': appointmentUpdatesEnabled,
              'dailyDigestEnabled': dailyDigestEnabled,
              'systemAnnouncementsEnabled': systemAnnouncementsEnabled,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        isSaving = false;
        updatedAt = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin settings saved successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isSaving = false;
        errorMessage = 'Unable to save settings right now.';
      });
    }
  }

  Future<void> _sendPasswordReset() async {
    final currentEmail = _auth.currentUser?.email ?? email;
    if (currentEmail == null || currentEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email address found for this account.'),
        ),
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: currentEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $currentEmail.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send password reset email.')),
      );
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  String _displayName() {
    final name =
        '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
            .trim();
    return name.isEmpty ? 'Admin' : name;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: RefreshIndicator(
        onRefresh: _loadSettings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin Settings', style: AppTypography.heading1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Manage admin profile details, notification preferences, and account security.',
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (errorMessage != null)
                _buildMessageCard(
                  icon: Icons.error_outline,
                  title: 'Settings could not be loaded',
                  message: errorMessage!,
                  actionLabel: 'Retry',
                  onAction: _loadSettings,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    final profileCard = _buildProfileCard();
                    final preferencesCard = _buildPreferencesCard();
                    final securityCard = _buildSecurityCard();

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: profileCard),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                preferencesCard,
                                const SizedBox(height: AppSpacing.lg),
                                securityCard,
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        profileCard,
                        const SizedBox(height: AppSpacing.lg),
                        preferencesCard,
                        const SizedBox(height: AppSpacing.lg),
                        securityCard,
                      ],
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: isSaving ? 'Saving...' : 'Save Changes',
                      onPressed: isSaving ? () {} : _saveSettings,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      text: 'Reload',
                      isPrimary: false,
                      onPressed: isSaving ? () {} : _loadSettings,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return _buildSectionCard(
      icon: Icons.person,
      title: 'Profile Information',
      subtitle:
          'Update the public-facing details attached to this admin account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'First name',
                  controller: firstNameController,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildInputField(
                  label: 'Last name',
                  controller: lastNameController,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInputField(label: 'City', controller: cityController),
          const SizedBox(height: AppSpacing.md),
          _buildReadOnlyField(
            label: 'Email address',
            value: email ?? 'Not available',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildReadOnlyField(label: 'Role', value: role ?? UserRoles.admin),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  label: 'Display name',
                  value: _displayName(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildInfoChip(
                  label: 'Account created',
                  value: createdAt == null
                      ? 'Unknown'
                      : _formatDate(createdAt!),
                ),
              ),
            ],
          ),
          if (updatedAt != null) ...[
            const SizedBox(height: AppSpacing.md),
            _buildInfoChip(label: 'Last saved', value: _formatDate(updatedAt!)),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return _buildSectionCard(
      icon: Icons.notifications_active,
      title: 'Notification Preferences',
      subtitle:
          'Choose which admin events should trigger alerts and summaries.',
      child: Column(
        children: [
          _buildSwitchTile(
            title: 'New doctor requests',
            subtitle: 'Alert me when a doctor submits a verification request.',
            value: newDoctorRequestsEnabled,
            onChanged: (value) =>
                setState(() => newDoctorRequestsEnabled = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSwitchTile(
            title: 'Appointment updates',
            subtitle: 'Receive updates when appointments change status.',
            value: appointmentUpdatesEnabled,
            onChanged: (value) =>
                setState(() => appointmentUpdatesEnabled = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSwitchTile(
            title: 'Daily digest',
            subtitle: 'Get a daily summary of activity in AidLink.',
            value: dailyDigestEnabled,
            onChanged: (value) => setState(() => dailyDigestEnabled = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSwitchTile(
            title: 'System announcements',
            subtitle:
                'Show platform-wide announcements and maintenance notices.',
            value: systemAnnouncementsEnabled,
            onChanged: (value) =>
                setState(() => systemAnnouncementsEnabled = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return _buildSectionCard(
      icon: Icons.security,
      title: 'Security',
      subtitle: 'Keep the admin account protected and easy to recover.',
      child: Column(
        children: [
          AppButton(
            text: 'Send password reset email',
            isPrimary: false,
            onPressed: _sendPasswordReset,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.lg,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: _logout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.heading2),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.red),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTypography.heading2)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: AppTypography.bodyText),
          const SizedBox(height: AppSpacing.md),
          AppButton(text: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.bodyText),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodyText.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodyText),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAF7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Text(value, style: AppTypography.bodyText),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        title: Text(title, style: AppTypography.bodyText),
        subtitle: Text(subtitle, style: AppTypography.bodyText),
        value: value,
        activeColor: AppColors.primaryGreen,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodyText),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.backgroundWhite,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$day/$month/${dateTime.year}';
  }
}
