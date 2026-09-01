// Purpose: Patient screen for accessing help, FAQs, and submitting support requests.
// File: lib/views/patient/help_support_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_values.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/localization/app_text.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String t(String english) => AppText.of(context, english);
  static final RegExp _subjectRegex = RegExp(
    r"^[A-Za-z0-9][A-Za-z0-9 .,'()!?:\-/]{2,80}$",
  );
  static final RegExp _messageRegex = RegExp(
    r"^[A-Za-z0-9\s.,'()!?:\-/#&]{10,1000}$",
  );

  final _messageController = TextEditingController();
  final _subjectController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _name = 'Patient';
  String _email = '';
  String _selectedCategory = 'Account';
  String _searchQuery = '';

  final List<_FaqEntry> _faqs = const [
    _FaqEntry(
      category: 'Appointments',
      question: 'How do I book an appointment?',
      answer: 'Open the dashboard, choose a doctor, and tap Book Appointment.',
    ),
    _FaqEntry(
      category: 'Appointments',
      question: 'Can I cancel an appointment?',
      answer: 'Yes. Open Upcoming Appointments and tap Cancel on the card.',
    ),
    _FaqEntry(
      category: 'Prescriptions',
      question: 'Where are my prescriptions?',
      answer: 'Go to My Prescriptions to view the full prescription history.',
    ),
    _FaqEntry(
      category: 'Account',
      question: 'How do I update my details?',
      answer: 'Open Settings to change your profile and notification options.',
    ),
    _FaqEntry(
      category: 'Security',
      question: 'How do I reset my password?',
      answer: 'Use Settings > Send password reset email or Change password.',
    ),
    _FaqEntry(
      category: 'Technical',
      question: 'The app is behaving strangely. What should I do?',
      answer: 'Try signing out and back in, then send a support request below.',
    ),
  ];

  final List<String> _supportCategories = const [
    'Account',
    'Appointments',
    'Prescriptions',
    'Chats',
    'Technical',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // --- Listen for search query changes ---
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    // Load user info for support request
    _loadUserDetails();
  }

  @override
  void dispose() {
    // --- Cleanup controllers ---
    _messageController.dispose();
    _subjectController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Fetch user name and email for support context ---
  Future<void> _loadUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
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
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['lastName'] ?? '').toString().trim();
      final display = [
        first,
        last,
      ].where((part) => part.isNotEmpty).join(' ').trim();

      _name = display.isNotEmpty
          ? display
          : (user.displayName ?? user.email ?? 'Patient').toString();
      _email = (user.email ?? data['email'] ?? '').toString();
      _subjectController.text = 'Support request';

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<_FaqEntry> get _filteredFaqs {
    if (_searchQuery.isEmpty) return _faqs;
    return _faqs.where((faq) {
      return faq.question.toLowerCase().contains(_searchQuery) ||
          faq.answer.toLowerCase().contains(_searchQuery) ||
          faq.category.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label ${t('copied to clipboard.')}')),
    );
  }

  Future<void> _submitSupportRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.supportRequests)
          .add({
            SupportRequestFields.userId: user.uid,
            SupportRequestFields.name: _name,
            SupportRequestFields.email: _email,
            SupportRequestFields.category: _selectedCategory,
            SupportRequestFields.subject: _subjectController.text.trim(),
            SupportRequestFields.message: _messageController.text.trim(),
            SupportRequestFields.status: 'open',
            SupportRequestFields.source: 'mobile-app',
            'targetRole': UserRoles.admin,
            SupportRequestFields.createdAt: FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      _messageController.clear();
      _subjectController.text = 'Support request';
      setState(() => _selectedCategory = 'Account');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Your support request has been sent.'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Could not send your request right now.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F9F6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2ECE4)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.12),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF8),
      appBar: AppBar(
        title: Text(
          t('Help & Support'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('We are here to help'),
                  style: AppTypography.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    'Search answers, contact support, or send a request right from the app.',
                  ),
                  style: AppTypography.bodyText.copyWith(
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _infoPill(Icons.access_time, t('24h response target')),
                    _infoPill(Icons.security, t('Secure support requests')),
                    _infoPill(Icons.support_agent, t('Human support team')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: t('Search FAQs or topics'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(t('Quick Actions'), style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          _quickAction(
            icon: Icons.calendar_month,
            title: t('Book an appointment'),
            subtitle: t('Go directly to the booking flow.'),
            onTap: () => Navigator.pushNamed(context, '/appointment-booking'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _quickAction(
            icon: Icons.medical_services_outlined,
            title: t('View prescriptions'),
            subtitle: t('Open your saved prescriptions.'),
            onTap: () => Navigator.pushNamed(context, '/prescriptions'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _quickAction(
            icon: Icons.settings_outlined,
            title: t('Open settings'),
            subtitle: t('Update account and notification preferences.'),
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(t('Frequently Asked Questions'), style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          ..._filteredFaqs.map(
            (faq) => _sectionCard(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  t(faq.question),
                  style: AppTypography.bodyText.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  t(faq.category),
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.primaryGreen,
                    fontSize: 12,
                  ),
                ),
                children: [
                  const SizedBox(height: 4),
                  Text(
                    t(faq.answer),
                    style: AppTypography.bodyText.copyWith(
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_filteredFaqs.isEmpty)
            _sectionCard(
              child: Text(
                t(
                  'No FAQ matches your search. Try a different keyword or send a support request below.',
                ),
                style: AppTypography.bodyText.copyWith(color: Colors.grey[700]),
              ),
            ),
          Text(t('Send a Support Request'), style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          _sectionCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: _name,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: t('Name'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    initialValue: _email,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: t('Email'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: t('Category'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _supportCategories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(t(category)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: t('Subject'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final subject = value?.trim() ?? '';
                      if (subject.isEmpty) {
                        return t('Enter a subject');
                      }
                      if (!_subjectRegex.hasMatch(subject)) {
                        return t('Subject must be 3-80 valid characters');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _messageController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: t('Describe your issue'),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      final message = value?.trim() ?? '';
                      if (message.isEmpty) {
                        return t('Please enter a message');
                      }
                      if (message.length < 10) {
                        return t('Please provide a little more detail');
                      }
                      if (!_messageRegex.hasMatch(message)) {
                        return t('Message contains invalid characters');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitSupportRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      label: Text(
                        _isSubmitting ? t('Sending...') : t('Send Request'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(t('Contact Support'), style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.sm),
          _sectionCard(
            child: Column(
              children: [
                _contactRow(
                  icon: Icons.email_outlined,
                  label: 'support@aidlink.com',
                  actionLabel: 'Copy',
                  onTap: () => _copyToClipboard('support@aidlink.com', 'Email'),
                ),
                const Divider(height: AppSpacing.lg),
                _contactRow(
                  icon: Icons.phone_outlined,
                  label: '+1 234 567 890',
                  actionLabel: 'Copy',
                  onTap: () =>
                      _copyToClipboard('+1 234 567 890', 'Phone number'),
                ),
                const Divider(height: AppSpacing.lg),
                _contactRow(
                  icon: Icons.access_time,
                  label: 'Mon - Fri, 9:00 AM - 6:00 PM',
                  actionLabel: t('Hours'),
                  onTap: () {},
                ),
              ],
            ),
          ),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Emergency Notice'), style: AppTypography.heading3),
                const SizedBox(height: 6),
                Text(
                  t(
                    'AidLink support is for app-related issues only. For urgent medical emergencies, contact local emergency services immediately.',
                  ),
                  style: AppTypography.bodyText.copyWith(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyText.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _FaqEntry {
  final String category;
  final String question;
  final String answer;

  const _FaqEntry({
    required this.category,
    required this.question,
    required this.answer,
  });
}
