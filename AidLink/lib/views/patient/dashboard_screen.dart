import 'package:flutter/material.dart';
// Purpose: Patient main dashboard (upcoming appointments, nearby doctors, quick actions).
// File: lib/views/patient/dashboard_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

import '../../core/constants/app_values.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/typography.dart';
import '../../core/constants/spacing.dart';
import '../../core/localization/app_text.dart';
import 'widgets/nearby_providers_map_card.dart';
import 'doctor_category_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;
  String _patientName = 'Patient';
  String _searchQuery = '';

  final List<Map<String, dynamic>> dashboardSymptoms = [
    {
      'label': 'Cough',
      'hint': 'Dry or wet cough',
      'icon': Icons.air,
      'color': Color(0xFF4B8F8C),
    },
    {
      'label': 'Fever',
      'hint': 'Body feels hot or chills',
      'icon': Icons.thermostat,
      'color': Color(0xFFE76F51),
    },
    {
      'label': 'Headache',
      'hint': 'Head feels heavy or painful',
      'icon': Icons.psychology_alt_outlined,
      'color': Color(0xFF8E6CFF),
    },
    {
      'label': 'Chest Pain',
      'hint': 'Pain or pressure in chest',
      'icon': Icons.favorite_border,
      'color': Color(0xFFDA4453),
    },
    {
      'label': 'Back Pain',
      'hint': 'Pain in lower or upper back',
      'icon': Icons.accessibility_new,
      'color': Color(0xFF7C5A3A),
    },
    {
      'label': 'Sore Throat',
      'hint': 'Pain or scratchiness in throat',
      'icon': Icons.hearing,
      'color': Color(0xFF2D9CDB),
    },
    {
      'label': 'Runny Nose',
      'hint': 'Blocked or watery nose',
      'icon': Icons.air,
      'color': Color(0xFF56CCF2),
    },
    {
      'label': 'Stomach Pain',
      'hint': 'Belly ache or cramps',
      'icon': Icons.sick,
      'color': Color(0xFFF2994A),
    },
    {
      'label': 'Skin Rash',
      'hint': 'Red spots or itching skin',
      'icon': Icons.spa_outlined,
      'color': Color(0xFF27AE60),
    },
    {
      'label': 'Fatigue',
      'hint': 'Feeling very tired',
      'icon': Icons.bedtime_outlined,
      'color': Color(0xFF607D8B),
    },
    {
      'label': 'Anxiety',
      'hint': 'Worried, tense, or restless',
      'icon': Icons.self_improvement,
      'color': Color(0xFF9B59B6),
    },
    {
      'label': 'Joint Pain',
      'hint': 'Pain in knees, elbows, or wrists',
      'icon': Icons.accessible_forward,
      'color': Color(0xFF6D4C41),
    },
  ];

  final Set<String> _selectedSymptoms = {};

  final Map<String, String> _symptomImageMap = {
    'Cough': 'assets/images/cough.png',
    'Fever': 'assets/images/fever.png',
    'Headache': 'assets/images/headache.png',
    'Chest Pain': 'assets/images/chest_pain.png',
    'Back Pain': 'assets/images/back_pain.png',
  };

  final Map<String, List<String>> _symptomToSpecializations = {
    'Fever': ['General Physician', 'Pediatrician'],
    'Cough': ['General Physician', 'ENT Specialist', 'Pediatrician'],
    'Headache': ['General Physician', 'Neurologist'],
    'Chest Pain': ['Cardiologist', 'General Physician'],
    'Back Pain': ['Orthopedic', 'General Physician'],
    'Sore Throat': ['ENT Specialist', 'General Physician'],
    'Runny Nose': ['ENT Specialist', 'General Physician'],
    'Stomach Pain': ['General Physician'],
    'Skin Rash': ['Dermatologist', 'General Physician'],
    'Fatigue': ['General Physician', 'Psychiatrist'],
    'Anxiety': ['Psychiatrist', 'General Physician'],
    'Joint Pain': ['Orthopedic', 'General Physician'],
  };

  String t(String english) => AppText.of(context, english);

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

  Widget _buildDrawerProfilePicture(Map<String, dynamic> data) {
    return CircleAvatar(
      backgroundImage: _profileImageProvider(data['profilePhotoUrl']),
    );
  }

  final List<Map<String, dynamic>> categories = [
    {'label': 'General Physician', 'icon': Icons.person},
    {'label': 'Cardiologist', 'icon': Icons.favorite},
    {'label': 'Dermatologist', 'icon': Icons.face},
    {'label': 'Dentist', 'icon': Icons.medical_services},
    {'label': 'Neurologist', 'icon': Icons.psychology},
    {'label': 'Orthopedic', 'icon': Icons.accessibility},
    {'label': 'Pediatrician', 'icon': Icons.child_care},
    {'label': 'Gynecologist', 'icon': Icons.pregnant_woman},
    {'label': 'ENT Specialist', 'icon': Icons.hearing},
    {'label': 'Psychiatrist', 'icon': Icons.self_improvement},
  ];

  bool _doctorMatchesSelectedSymptoms(Map<String, dynamic> data) {
    if (_selectedSymptoms.isEmpty) return true;

    final doctorSymptoms = (data['symptoms'] is List)
        ? List<dynamic>.from(data['symptoms'])
        : <dynamic>[];
    final hasDirectSymptomMatch = doctorSymptoms.any(
      (s) => _selectedSymptoms.contains(s.toString()),
    );
    if (hasDirectSymptomMatch) return true;

    final specialization = (data['specialization'] ?? '')
        .toString()
        .toLowerCase();
    for (final symptom in _selectedSymptoms) {
      final mapped =
          _symptomToSpecializations[symptom] ?? const ['General Physician'];
      final hasSpecializationMatch = mapped.any(
        (speciality) => specialization.contains(speciality.toLowerCase()),
      );
      if (hasSpecializationMatch) return true;
    }

    return false;
  }

  List<String> _suggestedSpecializations() {
    if (_selectedSymptoms.isEmpty) return const [];

    final suggestions = <String>{};
    for (final symptom in _selectedSymptoms) {
      final mapped =
          _symptomToSpecializations[symptom] ?? const ['General Physician'];
      suggestions.addAll(mapped);
    }
    return suggestions.toList();
  }

  @override
  void initState() {
    super.initState();
    // --- Load patient name and setup animations ---
    _loadPatientName();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    // Pulse animation for symptom icons
    // Removed pulse animation for symptom icons
  }

  @override
  void dispose() {
    // --- Cleanup resources ---
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // --- Navigate to doctor list by category ---
  void onCategoryTap(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorCategoryScreen(category: category),
      ),
    );
  }

  // --- Toggle symptom selection ---
  void onSymptomTap(String symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        _selectedSymptoms.remove(symptom);
      } else {
        _selectedSymptoms.add(symptom);
      }
    });
  }

  Future<void> _loadPatientName() async {
    final uid = user?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();

      if (!mounted) return;

      final data = snapshot.data() ?? <String, dynamic>{};
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['lastName'] ?? '').toString().trim();
      final fullName = [
        first,
        last,
      ].where((part) => part.isNotEmpty).join(' ').trim();

      if (fullName.isNotEmpty) {
        setState(() {
          _patientName = fullName;
        });
      }
    } catch (_) {
      // Keep fallback name when Firestore read fails.
    }
  }

  Map<String, dynamic> _toDoctorViewModel(
    QueryDocumentSnapshot doc, {
    Map<String, dynamic>? userData,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final profile = userData ?? <String, dynamic>{};

    final firstName = (data['firstName'] ?? profile['firstName'] ?? '')
        .toString();
    final lastName = (data['lastName'] ?? profile['lastName'] ?? '').toString();
    final rawName = (data['name'] ?? profile['name'] ?? '').toString().trim();
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();

    final displayName = fullName.isNotEmpty ? fullName : rawName;
    final name = displayName.isEmpty
        ? 'Doctor'
        : (displayName.startsWith('Dr.') ? displayName : 'Dr. $displayName');

    return {
      'doctorId': doc.id,
      'name': name,
      'specialization':
          (data['specialization'] ?? profile['specialization'] ?? 'General')
              .toString(),
      'imageUrl': (data['profilePhotoUrl'] ?? profile['profilePhotoUrl'] ?? '')
          .toString(),
      'rating': double.tryParse((data['rating'] ?? '0').toString()) ?? 0.0,
      'totalReviews':
          int.tryParse((data['totalReviews'] ?? '0').toString()) ?? 0,
      'experience': (data['experience'] ?? profile['experience'])?.toString(),
      'bio': (data['bio'] ?? profile['bio'])?.toString(),
      'symptoms': data['symptoms'] is List
          ? List<dynamic>.from(data['symptoms'])
          : <dynamic>[],
    };
  }

  void _openDoctorDetail(Map<String, dynamic> doctor) {
    Navigator.pushNamed(
      context,
      '/doctor-detail',
      arguments: {
        'doctorId': doctor['doctorId'],
        'name': doctor['name'],
        'specialization': doctor['specialization'],
        'imageUrl': doctor['imageUrl'],
        'rating': doctor['rating'],
        'experience': doctor['experience'],
        'bio': doctor['bio'],
      },
    );
  }

  TextSpan _highlightSpan(String text, String query, TextStyle baseStyle) {
    if (query.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final matchIndex = lowerText.indexOf(lowerQuery, start);
      if (matchIndex < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }

      if (matchIndex > start) {
        spans.add(
          TextSpan(text: text.substring(start, matchIndex), style: baseStyle),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchIndex + lowerQuery.length),
          style: baseStyle.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

      start = matchIndex + lowerQuery.length;
    }

    return TextSpan(children: spans);
  }

  Map<String, Map<String, dynamic>> _doctorUsersMap(QuerySnapshot snapshot) {
    final map = <String, Map<String, dynamic>>{};
    for (final doc in snapshot.docs) {
      map[doc.id] = doc.data() as Map<String, dynamic>;
    }
    return map;
  }

  Widget _buildNotificationBell() {
    final uid = user?.uid;
    if (uid == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.white),
        onPressed: () => Navigator.pushNamed(context, '/notifications'),
      );
    }

    return IconButton(
      onPressed: () => Navigator.pushNamed(context, '/notifications'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: Colors.white),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.notifications)
                .where(NotificationFields.recipientId, isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              final count = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data[NotificationFields.isRead] ?? false) != true;
              }).length;

              if (count == 0) return const SizedBox.shrink();

              return Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatIconWithUnreadBadge(String? uid) {
    if (uid == null || uid.isEmpty) {
      return const Icon(Icons.chat_bubble_outline);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chat_bubble_outline),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .where('participants', arrayContains: uid)
              .snapshots(),
          builder: (context, snapshot) {
            final total = (snapshot.data?.docs ?? const []).fold<int>(0, (
              sum,
              doc,
            ) {
              final data = doc.data() as Map<String, dynamic>;
              final unreadCounts = Map<String, dynamic>.from(
                data['unreadCounts'] ?? {},
              );
              final count = unreadCounts[uid];
              return sum + (count is num ? count.toInt() : 0);
            });

            if (total <= 0) return const SizedBox.shrink();

            return Positioned(
              right: -8,
              top: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: total > 9 ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: total > 9 ? BorderRadius.circular(9) : null,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    total > 99 ? '99+' : '$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text(
          t('AidLink'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [_buildNotificationBell()],
      ),

      // 🔥 DRAWER WITH REAL USER DATA
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(height: 150);
                  }

                  final data =
                      snapshot.data!.data() as Map<String, dynamic>? ?? {};

                  return UserAccountsDrawerHeader(
                    decoration: BoxDecoration(color: AppColors.primaryGreen),
                    accountName: Text(
                      "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}",
                      style: AppTypography.heading3.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    accountEmail: Text(
                      data['email'] ?? '',
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    currentAccountPicture: _buildDrawerProfilePicture(data),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.home),
                title: Text(t('Dashboard')),
                onTap: () => Navigator.pop(context),
              ),

              // ✅ BOOK APPOINTMENT ADDED
              ListTile(
                leading: const Icon(Icons.add_circle),
                title: Text(t('Book Appointment')),
                onTap: () {
                  Navigator.pushNamed(context, '/appointment-booking');
                },
              ),

              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(t('Upcoming Appointments')),
                onTap: () =>
                    Navigator.pushNamed(context, '/upcoming-appointments'),
              ),

              ListTile(
                leading: const Icon(Icons.history),
                title: Text(t('Appointment History')),
                onTap: () =>
                    Navigator.pushNamed(context, '/appointment-history'),
              ),

              ListTile(
                leading: const Icon(Icons.medical_services),
                title: Text(t('My Prescriptions')),
                onTap: () => Navigator.pushNamed(context, '/prescriptions'),
              ),

              ListTile(
                leading: _buildChatIconWithUnreadBadge(user?.uid),
                title: Text(t('Chats')),
                onTap: () => Navigator.pushNamed(context, '/patient-chats'),
              ),

              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(t('Nearby Map')),
                onTap: () => Navigator.pushNamed(context, '/nearby-map'),
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.settings),
                title: Text(t('Settings')),
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),

              ListTile(
                leading: const Icon(Icons.notifications_none),
                title: Text(t('Notifications')),
                trailing: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(FirestoreCollections.notifications)
                      .where(
                        NotificationFields.recipientId,
                        isEqualTo: user?.uid,
                      )
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? const [];
                    final count = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data[NotificationFields.isRead] ?? false) != true;
                    }).length;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),

              ListTile(
                leading: const Icon(Icons.help_outline),
                title: Text(t('Help & Support')),
                onTap: () => Navigator.pushNamed(context, '/help-support'),
              ),

              const Divider(height: 24),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  t('Logout'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  FirebaseAuth.instance.signOut().then((_) {
                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  });
                },
              ),
            ],
          ),
        ),
      ),

      backgroundColor: AppColors.backgroundWhite,

      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: AppSpacing.md),

                  // ── Feedback nudge: show if there's a completed appointment without a review ──
                  if (user != null) _buildFeedbackNudge(user!.uid),
                  const SizedBox(
                    height: 0,
                  ), // spacer if nudge is visible is handled inside
                  // SEARCH
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderGray),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x11000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim().toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: t('Search by doctor or speciality...'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(
                            color: AppColors.primaryGreen,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  if (_searchQuery.isNotEmpty) ...[
                    _buildSectionHeader(
                      title: t('Search Results'),
                      subtitle:
                          '${t('Doctors matching')} "${_searchController.text.trim()}"',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildSearchResults(),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // CATEGORIES
                  Text(t('Categories'), style: AppTypography.heading3),
                  const SizedBox(height: AppSpacing.sm),

                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final label = category['label'] as String;
                        final icon = category['icon'] as IconData;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => onCategoryTap(label),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.borderGray),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0E000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    icon,
                                    color: AppColors.primaryGreen,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    t(label),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyText.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  _buildSectionHeader(
                    title: t('Nearby Doctors & Clinics'),
                    subtitle: t('Free live map powered by OpenStreetMap'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  NearbyProvidersMapCard(
                    compact: true,
                    showTitle: false,
                    onOpenFullMap: () =>
                        Navigator.pushNamed(context, '/nearby-map'),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ✅ SYMPTOMS (RESTORED)
                  Text(t('Symptoms'), style: AppTypography.heading3),
                  const SizedBox(height: AppSpacing.sm),

                  SizedBox(
                    height: 136,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: dashboardSymptoms
                          .where(
                            (item) => _symptomImageMap.containsKey(
                              item['label'] as String,
                            ),
                          )
                          .length,
                      itemBuilder: (context, index) {
                        final visibleSymptoms = dashboardSymptoms
                            .where(
                              (item) => _symptomImageMap.containsKey(
                                item['label'] as String,
                              ),
                            )
                            .toList();
                        final symptomItem = visibleSymptoms[index];
                        final symptom = symptomItem['label'] as String;
                        final color = symptomItem['color'] as Color;
                        final isSelected = _selectedSymptoms.contains(symptom);

                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => onSymptomTap(symptom),
                            child: Container(
                              width: 150,
                              height: 170,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSelected
                                      ? [
                                          AppColors.primaryGreen,
                                          AppColors.primaryGreen.withValues(
                                            alpha: 0.82,
                                          ),
                                        ]
                                      : [Colors.white, const Color(0xFFF4FAF6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : AppColors.borderGray,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x10000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: _symptomIllustration(
                                      symptom,
                                      color,
                                      isSelected,
                                    ),
                                  ),
                                  Positioned(
                                    left: 8,
                                    right: 8,
                                    bottom: 8,
                                    child: Text(
                                      t(symptom),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyText.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 6,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : color.withValues(alpha: 0.14),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isSelected ? Icons.check : Icons.add,
                                        size: 14,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  if (_selectedSymptoms.isNotEmpty) ...[
                    _buildSectionHeader(
                      title: t('Suggested Specialities'),
                      subtitle: t(
                        'Doctors are suggested based on selected symptoms',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedSpecializations()
                          .map(
                            (speciality) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF8F1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryGreen.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                t(speciality),
                                style: AppTypography.bodyText.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 🔥 DOCTORS FROM FIRESTORE (WITH FILTER)
                  _buildSectionHeader(
                    title: t('Top Doctors'),
                    subtitle: t(
                      'Approved doctors matching your search and symptoms',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderGray),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0E000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(FirestoreCollections.doctors)
                          .where('status', isEqualTo: DoctorStatus.approved)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(t('Unable to load doctors right now.')),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final specialization = (data['specialization'] ?? '')
                              .toString()
                              .toLowerCase();

                          final firstName = (data['firstName'] ?? '')
                              .toString()
                              .toLowerCase();
                          final lastName = (data['lastName'] ?? '')
                              .toString()
                              .toLowerCase();
                          final fullName = '$firstName $lastName'.trim();

                          final matchesSymptoms =
                              _doctorMatchesSelectedSymptoms(data);

                          final matchesSearch = _searchQuery.isEmpty
                              ? true
                              : fullName.contains(_searchQuery) ||
                                    specialization.contains(_searchQuery);

                          return matchesSymptoms && matchesSearch;
                        }).toList();

                        if (docs.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(t('No doctors match your filters')),
                            ),
                          );
                        }

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection(FirestoreCollections.users)
                              .where('role', isEqualTo: UserRoles.doctor)
                              .snapshots(),
                          builder: (context, usersSnapshot) {
                            if (!usersSnapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final userMap = _doctorUsersMap(
                              usersSnapshot.data!,
                            );

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final doctor = _toDoctorViewModel(
                                  docs[index],
                                  userData: userMap[docs[index].id],
                                );
                                final rating = doctor['rating'] as double;
                                final totalReviews =
                                    (doctor['totalReviews'] as int?) ?? 0;
                                final hasRating =
                                    totalReviews > 0 && rating > 0;
                                final experience = (doctor['experience'] ?? '')
                                    .toString();

                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _openDoctorDetail(doctor),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FCF9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.borderGray,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundImage:
                                              _profileImageProvider(
                                                doctor['imageUrl'] as String?,
                                              ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                doctor['name'] as String,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.bodyText
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors
                                                          .primaryGreen,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                doctor['specialization']
                                                    as String,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.bodyText
                                                    .copyWith(
                                                      fontSize: 13,
                                                      color: Colors.grey[700],
                                                    ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  if (hasRating) ...[
                                                    const Icon(
                                                      Icons.star,
                                                      color: Colors.amber,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      rating.toStringAsFixed(1),
                                                      style: AppTypography
                                                          .bodyText
                                                          .copyWith(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ] else
                                                    Text(
                                                      'No reviews',
                                                      style: AppTypography
                                                          .bodyText
                                                          .copyWith(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[700],
                                                          ),
                                                    ),
                                                  const SizedBox(width: 10),
                                                  Icon(
                                                    Icons.work_outline,
                                                    color: Colors.grey[700],
                                                    size: 15,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      experience.isEmpty
                                                          ? 'Experience not set'
                                                          : '$experience years',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: AppTypography
                                                          .bodyText
                                                          .copyWith(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey[700],
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: AppColors.primaryGreen,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Banner shown when patient has completed appointments they haven't reviewed yet.
  Widget _buildFeedbackNudge(String patientId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .where('status', isEqualTo: 'completed')
          .limit(10)
          .snapshots(),
      builder: (context, apptSnap) {
        if (!apptSnap.hasData || apptSnap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final appointments = apptSnap.data!.docs;
        // Check which appointments already have a review from this patient
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('reviews')
              .where('patientId', isEqualTo: patientId)
              .get(),
          builder: (context, reviewSnap) {
            if (!reviewSnap.hasData) return const SizedBox.shrink();
            final reviewedAppointmentIds = reviewSnap.data!.docs
                .map(
                  (d) => (d.data() as Map)['appointmentId']?.toString() ?? '',
                )
                .toSet();
            final unreviewed = appointments
                .where((a) => !reviewedAppointmentIds.contains(a.id))
                .toList();
            if (unreviewed.isEmpty) return const SizedBox.shrink();

            return GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/appointment-history'),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x222E7D32),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.rate_review,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unreviewed.length == 1
                                ? 'Rate your recent consultation'
                                : 'You have ${unreviewed.length} appointments to review',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Your feedback helps other patients',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeroCard() {
    final displayName = _patientName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF256D38), Color(0xFF3F9A56)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $displayName',
                      style: AppTypography.heading2.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find the right specialist, book care fast, and keep everything in one place.',
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.calendar_month,
                  label: 'Appointments',
                  value: 'Manage',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.local_hospital,
                  label: 'Doctors',
                  value: 'Browse',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.medication_outlined,
                  label: 'Prescriptions',
                  value: 'Track',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.bodyText.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodyText.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.heading3),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodyText.copyWith(
            color: Colors.grey[700],
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _symptomIllustration(String label, Color color, bool isSelected) {
    final imagePath = _symptomImageMap[label] ?? 'assets/images/fever.png';

    return Image.asset(
      imagePath,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }

  Widget _buildSearchResults() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.doctors)
            .where('status', isEqualTo: DoctorStatus.approved)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(t('Search is unavailable right now.'));
          }

          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .where('role', isEqualTo: UserRoles.doctor)
                .snapshots(),
            builder: (context, usersSnapshot) {
              if (!usersSnapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final userMap = _doctorUsersMap(usersSnapshot.data!);
              final results = snapshot.data!.docs
                  .map(
                    (doc) => _toDoctorViewModel(doc, userData: userMap[doc.id]),
                  )
                  .where((doctor) {
                    final name = (doctor['name'] as String).toLowerCase();
                    final specialization = (doctor['specialization'] as String)
                        .toLowerCase();
                    final query = _searchQuery.toLowerCase();
                    return name.contains(query) ||
                        specialization.contains(query);
                  })
                  .take(6)
                  .toList();

              if (results.isEmpty) {
                return Text(t('No doctors found for this search.'));
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 18),
                itemBuilder: (context, index) {
                  final doctor = results[index];
                  final name = doctor['name'] as String;
                  final specialization = doctor['specialization'] as String;
                  final rating = doctor['rating'] as double;
                  final totalReviews = (doctor['totalReviews'] as int?) ?? 0;
                  final hasRating = totalReviews > 0 && rating > 0;

                  return InkWell(
                    onTap: () => _openDoctorDetail(doctor),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: _profileImageProvider(
                              doctor['imageUrl'] as String?,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: _highlightSpan(
                                    name,
                                    _searchQuery,
                                    AppTypography.bodyText.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: _highlightSpan(
                                    specialization,
                                    _searchQuery,
                                    AppTypography.bodyText.copyWith(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              if (hasRating) ...[
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: AppTypography.bodyText.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ] else
                                Text(
                                  'No reviews',
                                  style: AppTypography.bodyText.copyWith(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                            ],
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
