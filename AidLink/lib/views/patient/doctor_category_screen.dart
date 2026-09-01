import 'dart:convert';

// Purpose: Patient screen for browsing doctors by specialty category.
// File: lib/views/patient/doctor_category_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_values.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/localization/app_text.dart';

class DoctorCategoryScreen extends StatelessWidget {
  final String category;

  const DoctorCategoryScreen({Key? key, required this.category})
    : super(key: key);

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

  // --- Normalize specialty name for case-insensitive matching ---
  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    // --- Build doctor list filtered by selected category ---
    String t(String english) => AppText.of(context, english);

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        title: Text(
          t(category),
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

      // --- Stream doctor list filtered by specialization ---
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.doctors)
            .where('status', isEqualTo: DoctorStatus.approved)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                t('Could not load doctors right now.'),
                style: AppTypography.bodyText,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doctors = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final specialization = (data['specialization'] ?? '').toString();
            return _normalize(specialization) == _normalize(category);
          }).toList();

          if (doctors.isEmpty) {
            return Center(
              child: Text(
                '${t('No doctors found for this search.')} "${t(category)}"',
                style: AppTypography.heading3.copyWith(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctorDoc = doctors[index];
              final doctorData = doctorDoc.data() as Map<String, dynamic>;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection(FirestoreCollections.users)
                    .doc(doctorDoc.id)
                    .get(),
                builder: (context, userSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

                  final firstName = (userData['firstName'] ?? '').toString();
                  final lastName = (userData['lastName'] ?? '').toString();
                  final doctorName = [
                    firstName,
                    lastName,
                  ].where((part) => part.trim().isNotEmpty).join(' ');
                  final displayName = doctorName.isEmpty
                      ? 'Dr. ${(doctorData['specialization'] ?? 'Doctor').toString()}'
                      : doctorName.startsWith('Dr.')
                      ? doctorName
                      : 'Dr. $doctorName';

                  final specialization =
                      (doctorData['specialization'] ?? 'Doctor').toString();
                  final photoUrl =
                      (doctorData['profilePhotoUrl'] ??
                              userData['profilePhotoUrl'] ??
                              '')
                          .toString();
                  final rating =
                      double.tryParse(
                        (doctorData['rating'] ?? userData['rating'] ?? '4.8')
                            .toString(),
                      ) ??
                      4.8;
                  final experience = (doctorData['experience'] ?? 'Not set')
                      .toString();
                  final bio = (doctorData['bio'] ?? '').toString();

                  return Card(
                    color: AppColors.backgroundWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.primaryGreen),
                    ),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image(
                              image: _profileImageProvider(photoUrl),
                              height: 60,
                              width: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: AppTypography.heading3.copyWith(
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t(specialization),
                                  style: AppTypography.bodyText.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    ...List.generate(5, (starIndex) {
                                      if (starIndex < rating.floor()) {
                                        return const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 18,
                                        );
                                      } else if (starIndex < rating &&
                                          rating - starIndex >= 0.5) {
                                        return const Icon(
                                          Icons.star_half,
                                          color: Colors.amber,
                                          size: 18,
                                        );
                                      } else {
                                        return const Icon(
                                          Icons.star_border,
                                          color: Colors.amber,
                                          size: 18,
                                        );
                                      }
                                    }),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${rating.toStringAsFixed(1)} / 5',
                                      style: AppTypography.bodyText.copyWith(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                if (experience != 'Not set') ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '$experience years experience',
                                    style: AppTypography.bodyText.copyWith(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    bio,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyText.copyWith(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/doctor-detail',
                                arguments: {
                                  'doctorId': doctorDoc.id,
                                  'name': displayName,
                                  'specialization': specialization,
                                  'imageUrl': photoUrl,
                                  'rating': rating,
                                  'experience': experience,
                                  'bio': bio,
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                            ),
                            child: Text(
                              t('View'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
