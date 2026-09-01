import 'package:cloud_firestore/cloud_firestore.dart';
// Purpose: Patient screen for responding to postponed appointment offers (accept/decline).
// File: lib/views/patient/postponed_offer_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_values.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/localization/app_text.dart';
import '../../core/services/postponed_offer_service.dart';

class PostponedOfferScreen extends StatefulWidget {
  final String offerId;

  const PostponedOfferScreen({Key? key, required this.offerId})
    : super(key: key);

  @override
  State<PostponedOfferScreen> createState() => _PostponedOfferScreenState();
}

class _PostponedOfferScreenState extends State<PostponedOfferScreen> {
  String t(String english) => AppText.of(context, english);
  bool _isWorking = false;
  Map<String, dynamic>? _offerData;
  Map<String, dynamic>? _appointmentData;
  Map<String, dynamic>? _doctorData;
  String? _error;

  @override
  void initState() {
    super.initState();
    // --- Load postponed offer data on init ---
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    // --- Validate offer ID and fetch offer data ---
    if (widget.offerId.isEmpty) {
      setState(() => _error = 'Postponed offer not found.');
      return;
    }

    try {
      // Fetch offer document
      final offerDoc = await FirebaseFirestore.instance
          .collection('postponed_offers')
          .doc(widget.offerId)
          .get();

      if (!offerDoc.exists) {
        setState(() => _error = 'Postponed offer not found.');
        return;
      }

      // Extract offer details and fetch related documents
      final offer = offerDoc.data() ?? <String, dynamic>{};
      final appointmentId = (offer['appointmentId'] ?? '').toString();
      final doctorId = (offer['doctorId'] ?? '').toString();

      final appointmentDoc = appointmentId.isEmpty
          ? null
          : await FirebaseFirestore.instance
                .collection(FirestoreCollections.appointments)
                .doc(appointmentId)
                .get();

      final doctorDoc = doctorId.isEmpty
          ? null
          : await FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .doc(doctorId)
                .get();

      setState(() {
        _offerData = offer;
        _appointmentData = appointmentDoc?.data();
        _doctorData = doctorDoc?.data();
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await PostponedOfferService.expireStaleOffersForUser(currentUser.uid);
      }
    } catch (_) {
      setState(() => _error = 'Unable to load postponed offer right now.');
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _buildDoctorName() {
    final data = _doctorData ?? <String, dynamic>{};
    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Doctor' : 'Dr. $full';
  }

  Future<void> _processOffer(String action, String successMessage) async {
    if (_isWorking) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final offer = _offerData ?? <String, dynamic>{};
    final appointmentId = (offer['appointmentId'] ?? '').toString();
    final doctorId = (offer['doctorId'] ?? '').toString();
    final patientId = (offer['patientId'] ?? '').toString();

    if (appointmentId.isEmpty || doctorId.isEmpty || patientId.isEmpty) {
      setState(() => _error = 'Offer is incomplete.');
      return;
    }

    if (patientId != user.uid) {
      setState(() => _error = 'This offer is not assigned to your account.');
      return;
    }

    setState(() => _isWorking = true);

    try {
      final result = await PostponedOfferService.processOffer(
        offerId: widget.offerId,
        patientId: user.uid,
        action: action,
      );

      final message = action == 'accept'
          ? 'Appointment moved to next day.'
          : 'Postponed offer declined.';
      final resolvedMessage = (result['message'] ?? '').toString().isNotEmpty
          ? result['message'].toString()
          : successMessage;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resolvedMessage.isNotEmpty ? resolvedMessage : message),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _acceptOffer() =>
      _processOffer('accept', 'Appointment moved to next day.');

  Future<void> _declineOffer() =>
      _processOffer('decline', 'Postponed offer declined.');

  @override
  Widget build(BuildContext context) {
    final offer = _offerData;
    final appointment = _appointmentData;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: Text(
          t('Postponed Appointment'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(_error!, style: AppTypography.bodyText),
              ),
            )
          : offer == null || appointment == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF8F1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderGray),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('Your doctor postponed an appointment day.'),
                          style: AppTypography.heading3.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t(
                            'You can keep the same slot on the next day if it is still available, or decline and cancel the appointment.',
                          ),
                          style: AppTypography.bodyText,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _infoCard(title: t('Doctor'), value: _buildDoctorName()),
                  _infoCard(
                    title: t('Original date'),
                    value: offer['originalDate'] is Timestamp
                        ? _formatDate(
                            (offer['originalDate'] as Timestamp).toDate(),
                          )
                        : 'Unknown',
                  ),
                  _infoCard(
                    title: t('Slot'),
                    value: (offer['originalSlot'] ?? appointment['slot'] ?? '')
                        .toString(),
                  ),
                  _infoCard(
                    title: t('Status'),
                    value: (offer['status'] ?? 'pending').toString(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isWorking ? null : _declineOffer,
                          child: Text(t('Decline / Cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isWorking ? null : _acceptOffer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                          ),
                          child: _isWorking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  t('Accept next day'),
                                  style: const TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoCard({required String title, required String value}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyText.copyWith(
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: AppTypography.bodyText.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
