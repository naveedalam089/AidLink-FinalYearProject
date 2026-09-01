import 'dart:convert';

import 'package:flutter/material.dart';
// Purpose: Patient screen for viewing doctor details (profile, specialization, schedule, reviews).
// File: lib/views/patient/doctor_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_values.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/typography.dart';
import '../../core/constants/spacing.dart';
import '../../core/localization/app_text.dart';

class DoctorDetailScreen extends StatefulWidget {
  final String name;
  final String specialization;
  final String? imageUrl;
  final String? doctorId;
  final String? bio;
  final String? experience;
  final double rating;

  const DoctorDetailScreen({
    Key? key,
    required this.name,
    required this.specialization,
    this.imageUrl,
    this.doctorId,
    this.bio,
    this.experience,
    this.rating = 0.0,
  }) : super(key: key);

  factory DoctorDetailScreen.fromArgs(Map<String, dynamic>? args) {
    final data = args ?? <String, dynamic>{};
    return DoctorDetailScreen(
      doctorId: data['doctorId']?.toString(),
      name: data['name']?.toString() ?? 'Doctor',
      specialization: data['specialization']?.toString() ?? 'Specialist',
      imageUrl: data['imageUrl']?.toString(),
      bio: data['bio']?.toString(),
      experience: data['experience']?.toString(),
      rating: double.tryParse(data['rating']?.toString() ?? '') ?? 0.0,
    );
  }

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  final ScrollController _reviewScrollController = ScrollController();

  @override
  void dispose() {
    _reviewScrollController.dispose();
    super.dispose();
  }

  // --- Helper: Parse image from base64, network, or asset ---
  ImageProvider _profileImageProvider(String? rawValue) {
    final value = (rawValue ?? '').toString().trim();

    if (value.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(value.split(',').last));
      } catch (_) {
        return const AssetImage('assets/images/default_profile.jpg');
      }
    }

    if (value.isNotEmpty) {
      return NetworkImage(value);
    }

    return const AssetImage('assets/images/default_profile.jpg');
  }

  // --- Fetch doctor profile from Firestore or use provided data ---
  Future<Map<String, dynamic>> _loadDoctorProfile() async {
    final String? doctorId = widget.doctorId;
    if (doctorId == null || doctorId.isEmpty) {
      return {
        'name': widget.name,
        'specialization': widget.specialization,
        'imageUrl': widget.imageUrl ?? '',
        'bio': widget.bio,
        'experience': widget.experience,
        'rating': widget.rating,
        'workingDays': <String>[],
        'startTime': null,
        'endTime': null,
      };
    }

    final firestore = FirebaseFirestore.instance;

    final results = await Future.wait([
      firestore.collection(FirestoreCollections.doctors).doc(doctorId).get(),
      firestore.collection(FirestoreCollections.users).doc(doctorId).get(),
      firestore
          .collection(FirestoreCollections.doctorAvailability)
          .doc(doctorId)
          .get(),
    ]);

    final doctorDoc = results[0];
    final userDoc = results[1];
    final availabilityDoc = results[2];

    final doctorData = doctorDoc.data() as Map<String, dynamic>? ?? {};
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final availabilityData =
        availabilityDoc.data() as Map<String, dynamic>? ?? {};

    final firstName = (doctorData['firstName'] ?? userData['firstName'] ?? '')
        .toString();
    final lastName = (doctorData['lastName'] ?? userData['lastName'] ?? '')
        .toString();
    final composedName = [
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();
    final rawName = (doctorData['name'] ?? userData['name'] ?? widget.name)
        .toString();

    final finalName = composedName.isNotEmpty ? composedName : rawName;
    final displayName = finalName.startsWith('Dr.')
        ? finalName
        : 'Dr. $finalName';

    return {
      'doctorId': doctorId,
      'name': displayName,
      'specialization':
          (doctorData['specialization'] ??
                  userData['specialization'] ??
                  widget.specialization)
              .toString(),
      'imageUrl':
          (doctorData['profilePhotoUrl'] ??
                  userData['profilePhotoUrl'] ??
                  widget.imageUrl ??
                  '')
              .toString(),
      'bio': (doctorData['bio'] ?? userData['bio'] ?? widget.bio)?.toString(),
      'experience':
          (doctorData['experience'] ??
                  userData['experience'] ??
                  widget.experience)
              ?.toString(),
      'rating':
          double.tryParse(
            (doctorData['rating'] ?? userData['rating'] ?? widget.rating)
                .toString(),
          ) ??
          0.0,
      'workingDays': availabilityData['workingDays'] is List
          ? List<String>.from(availabilityData['workingDays'])
          : <String>[],
      'startTime': availabilityData['startTime']?.toString(),
      'endTime': availabilityData['endTime']?.toString(),
    };
  }

  Stream<QuerySnapshot>? _approvedReviewsStream(String? doctorId) {
    if (doctorId == null || doctorId.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.reviews)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'approved')
        .limit(20)
        .snapshots();
  }

  double _averageRatingFromReviews(List<QueryDocumentSnapshot> reviews) {
    if (reviews.isEmpty) return 0.0;
    double sum = 0;
    for (final doc in reviews) {
      final data = doc.data() as Map<String, dynamic>;
      final rating = data['rating'];
      if (rating is num) {
        sum += rating.toDouble();
      }
    }
    return sum / reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    String t(String english) => AppText.of(context, english);

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        title: Text(
          t('Doctor Details'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadDoctorProfile(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data!;
          final displayName = profile['name'] as String;
          final docSpecialization = profile['specialization'] as String;
          final photoUrl = profile['imageUrl'] as String;
          final baseDoctorRating = profile['rating'] as double;
          final docExperience = (profile['experience'] ?? '').toString();
          final docBio = (profile['bio'] ?? '').toString();
          final workingDays =
              (profile['workingDays'] as List<String>? ?? <String>[]);
          final startTime = profile['startTime']?.toString();
          final endTime = profile['endTime']?.toString();
          final effectiveBio = docBio.isEmpty
              ? '$displayName is a highly experienced $docSpecialization with a strong track record of patient care and successful treatments.'
              : docBio;

          return StreamBuilder<QuerySnapshot>(
            stream: _approvedReviewsStream(profile['doctorId']?.toString()),
            builder: (context, reviewSnapshot) {
              final approvedReviews =
                  List<QueryDocumentSnapshot>.from(
                    reviewSnapshot.hasData
                        ? reviewSnapshot.data!.docs
                        : <QueryDocumentSnapshot>[],
                  )..sort((a, b) {
                    final adata = a.data() as Map<String, dynamic>;
                    final bdata = b.data() as Map<String, dynamic>;
                    final ats = adata['createdAt'] as Timestamp?;
                    final bts = bdata['createdAt'] as Timestamp?;
                    final ad =
                        ats?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bd =
                        bts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bd.compareTo(ad);
                  });
              final hasApprovedReviews = approvedReviews.isNotEmpty;
              final docRating = approvedReviews.isNotEmpty
                  ? _averageRatingFromReviews(approvedReviews)
                  : baseDoctorRating;
              final screenWidth = MediaQuery.of(context).size.width;
              final reviewBoxHeight = screenWidth >= 700
                  ? 360.0
                  : screenWidth >= 500
                  ? 300.0
                  : 240.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF256D38), Color(0xFF3F9A56)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundImage: _profileImageProvider(photoUrl),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: AppTypography.heading2.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  docSpecialization,
                                  style: AppTypography.bodyText.copyWith(
                                    color: Colors.white.withOpacity(0.92),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _statChip(
                                      icon: Icons.star,
                                      label: hasApprovedReviews
                                          ? docRating.toStringAsFixed(1)
                                          : 'No reviews',
                                    ),
                                    _statChip(
                                      icon: Icons.work,
                                      label: docExperience.isEmpty
                                          ? 'Experience N/A'
                                          : '$docExperience yrs',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _infoCard(
                      title: t('About Doctor'),
                      child: Text(effectiveBio, style: AppTypography.bodyText),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _infoCard(
                      title: t('Consultation Availability'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (workingDays.isEmpty)
                            Text(
                              t('Schedule not available yet.'),
                              style: AppTypography.bodyText,
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: workingDays
                                  .map(
                                    (day) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF8F1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        day,
                                        style: AppTypography.bodyText,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          const SizedBox(height: 8),
                          if (startTime != null && endTime != null)
                            Text(
                              '${t('Time')}: $startTime - $endTime',
                              style: AppTypography.bodyText.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _infoCard(
                      title: t('Patient Reviews'),
                      child: approvedReviews.isEmpty
                          ? Text(
                              t('No public reviews yet.'),
                              style: AppTypography.bodyText,
                            )
                          : SizedBox(
                              height: reviewBoxHeight,
                              child: Scrollbar(
                                controller: _reviewScrollController,
                                thumbVisibility: true,
                                child: ListView.separated(
                                  controller: _reviewScrollController,
                                  primary: false,
                                  itemCount: approvedReviews.length,
                                  separatorBuilder: (_, separatorIndex) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final review =
                                        approvedReviews[index].data()
                                            as Map<String, dynamic>;
                                    final rating =
                                        (review['rating'] as num?)
                                            ?.toDouble() ??
                                        0;
                                    final comment = (review['comment'] ?? '')
                                        .toString();
                                    final patientName =
                                        (review['patientName'] ?? 'Patient')
                                            .toString();

                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7FBF8),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.borderGray,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  patientName,
                                                  style: AppTypography.bodyText
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              Row(
                                                children: List.generate(5, (
                                                  index,
                                                ) {
                                                  return Icon(
                                                    index < rating.round()
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  );
                                                }),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            comment,
                                            style: AppTypography.bodyText,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/patient-chat',
                            arguments: {
                              'doctorId': profile['doctorId'],
                              'doctorName': displayName,
                              'specialization': docSpecialization,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.message, color: Colors.white),
                        label: Text(
                          t('Message Doctor'),
                          style: AppTypography.buttonText,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/appointment-history',
                            arguments: {'doctorId': profile['doctorId']},
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.rate_review),
                        label: Text(
                          'Leave a Review',
                          style: AppTypography.buttonText.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/appointment-booking',
                            arguments: {
                              'doctorId': profile['doctorId'],
                              'doctorName': displayName,
                              'specialization': docSpecialization,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.calendar_month,
                          color: Colors.white,
                        ),
                        label: Text(
                          t('Book Appointment'),
                          style: AppTypography.buttonText,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.heading3),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _statChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.bodyText.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
