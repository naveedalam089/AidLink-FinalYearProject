import 'package:flutter/material.dart';
// Purpose: Patient screen for booking appointments with a doctor (date/time selection, symptoms, confirmation).
// File: lib/views/patient/appointment_booking_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/typography.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/app_values.dart';
import '../../core/localization/app_text.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/admin_activity_service.dart';

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentBookingScreen> createState() =>
      _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  String t(String english) => AppText.of(context, english);
  String? selectedDoctor;
  String? selectedDoctorId;
  String? selectedDoctorSpecialization;
  String _doctorSearchQuery = '';
  bool _didLoadRouteArgs = false;
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;
  String? _slotStateMessage;

  DateTime? selectedDate;
  int _selectedSlotDurationMinutes = 30;

  List<String> availableSlots = [];
  Set<String> bookedSlots = {};
  String? selectedSlot;

  List<String> selectedSymptoms = [];
  final TextEditingController notesController = TextEditingController();
  final TextEditingController _doctorSearchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoadRouteArgs) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      selectedDoctorId = args['doctorId']?.toString();
      selectedDoctor = args['doctorName']?.toString();
      selectedDoctorSpecialization = args['specialization']?.toString();
    }

    _didLoadRouteArgs = true;
  }

  @override
  void dispose() {
    notesController.dispose();
    _doctorSearchController.dispose();
    super.dispose();
  }

  final List<String> symptoms = [
    'Cough',
    'Fever',
    'Headache',
    'Chest Pain',
    'Back Pain',
    'Sore Throat',
    'Runny Nose',
    'Shortness of Breath',
    'Stomach Pain',
    'Nausea',
    'Vomiting',
    'Diarrhea',
    'Dizziness',
    'Fatigue',
    'Body Ache',
    'Joint Pain',
    'Skin Rash',
    'Anxiety',
    'Sleep Problems',
  ];

  // --- Helper methods: Parse and format time values ---
  TimeOfDay _parseTime(String time) {
    final value = time.trim();
    if (value.toUpperCase().contains('AM') ||
        value.toUpperCase().contains('PM')) {
      final parts = value.split(' ');
      final hm = parts.first.split(':');
      final meridian = parts.last.toUpperCase();
      int hour = int.parse(hm[0]) % 12;
      if (meridian == 'PM') hour += 12;
      final minute = hm.length > 1 ? int.parse(hm[1]) : 0;
      return TimeOfDay(hour: hour, minute: minute);
    }

    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return "$hour:$minute $period";
  }

  List<String> generateSlots({
    required String startTime,
    required String endTime,
    required int duration,
  }) {
    if (duration <= 0) return [];

    final List<String> slots = [];

    TimeOfDay start = _parseTime(startTime);
    TimeOfDay end = _parseTime(endTime);

    int startMinutes = start.hour * 60 + start.minute;
    int endMinutes = end.hour * 60 + end.minute;

    for (int i = startMinutes; i < endMinutes; i += duration) {
      int hour = i ~/ 60;
      int minute = i % 60;

      final time = TimeOfDay(hour: hour, minute: minute);
      slots.add(_formatTime(time));
    }

    return slots;
  }

  /// ---------------- LOAD SLOTS ----------------

  Future<void> loadAvailableSlots() async {
    if (selectedDoctorId == null || selectedDate == null) {
      setState(() {
        availableSlots = [];
      });
      return;
    }

    setState(() {
      _isLoadingSlots = true;
      _slotStateMessage = null;
      availableSlots = [];
      selectedSlot = null;
    });

    // --- Fetch doctor availability data ---
    try {
      final availabilitySnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.doctorAvailability)
          .doc(selectedDoctorId)
          .get();

      if (!availabilitySnap.exists) {
        setState(() {
          _slotStateMessage = t(
            'This doctor has not added availability yet. Please try another doctor.',
          );
        });
        return;
      }

      final data = availabilitySnap.data()!;

      final dayMap = {
        1: 'Monday',
        2: 'Tuesday',
        3: 'Wednesday',
        4: 'Thursday',
        5: 'Friday',
        6: 'Saturday',
        7: 'Sunday',
      };

      final selectedDayName = dayMap[selectedDate!.weekday];
      final workingDays = List<String>.from(data['workingDays'] ?? []);

      if (!workingDays.contains(selectedDayName)) {
        setState(() {
          _slotStateMessage =
              '$selectedDayName ${t('is not in this doctor\'s working days.')}';
        });
        return;
      }

      final slots = generateSlots(
        startTime: data['startTime'],
        endTime: data['endTime'],
        duration: (data['slotDuration'] ?? 30) as int,
      );
      final slotDurationMinutes = (data['slotDuration'] ?? 30) as int;

      final startOfDay = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final bookedSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.appointments)
          .where('doctorId', isEqualTo: selectedDoctorId)
          .where('appointmentDate', isGreaterThanOrEqualTo: startOfDay)
          .where('appointmentDate', isLessThan: endOfDay)
          .get();

      final bookedSlotsList = bookedSnap.docs
          .where((doc) {
            final status = (doc.data()['status'] ?? '').toString();
            return status != AppointmentStatus.cancelled &&
                status != AppointmentStatus.rejected &&
                status != AppointmentStatus.postponed;
          })
          .map((e) => e['slot'] as String)
          .toList();

      // Show all slots (available and booked), filter will happen in UI
      var finalSlots = slots;

      // If selected date is today, only include slots at or after now
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selDay = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      );
      if (selDay == today) {
        finalSlots = finalSlots.where((s) {
          final t = _parseTime(s);
          final slotDt = DateTime(
            selDay.year,
            selDay.month,
            selDay.day,
            t.hour,
            t.minute,
          );
          return slotDt.isAfter(now) || slotDt.isAtSameMomentAs(now);
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        _selectedSlotDurationMinutes = slotDurationMinutes;
        availableSlots = finalSlots;
        bookedSlots = bookedSlotsList.toSet();
        if (finalSlots.isEmpty) {
          _slotStateMessage = t('No slots available for the selected date.');
        }
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _slotStateMessage = e.code == 'permission-denied'
            ? t(
                'Unable to load slots due to permissions. Please try again in a moment.',
              )
            : t('Unable to load slots right now. Please try again.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slotStateMessage = t(
          'Unable to load slots right now. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
        });
      }
    }
  }

  /// ---------------- BOOK ----------------

  Future<void> _bookAppointment() async {
    if (_isSubmitting) return;

    if (selectedDoctorId == null ||
        selectedDate == null ||
        selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Please select doctor, date and slot'))),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('Please log in again.'))));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final userProfile = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .get();
    final userData = userProfile.data() ?? <String, dynamic>{};
    final patientName =
        '${(userData['firstName'] ?? '').toString()} ${(userData['lastName'] ?? '').toString()}'
            .trim();

    final startOfDay = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
    );

    final endOfDay = startOfDay.add(const Duration(days: 1));

    final appointmentsRef = FirebaseFirestore.instance.collection(
      FirestoreCollections.appointments,
    );
    String? createdAppointmentId;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final query = await appointmentsRef
            .where("doctorId", isEqualTo: selectedDoctorId)
            .where("appointmentDate", isGreaterThanOrEqualTo: startOfDay)
            .where("appointmentDate", isLessThan: endOfDay)
            .get();

        final alreadyBooked = query.docs.any(
          (doc) => doc['slot'] == selectedSlot,
        );

        if (alreadyBooked) {
          throw Exception("Slot already booked");
        }

        final newDoc = appointmentsRef.doc();
        createdAppointmentId = newDoc.id;

        transaction.set(newDoc, {
          "patientId": user.uid,
          "doctorId": selectedDoctorId,
          "patientName": patientName,
          "doctorName": selectedDoctor,
          "appointmentDate": selectedDate,
          "slot": selectedSlot,
          "scheduledSlotMinutes": _selectedSlotDurationMinutes,
          "status": AppointmentStatus.pending,
          "symptoms": selectedSymptoms.join(", "),
          "notes": notesController.text.trim(),
          "createdAt": FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      if (selectedDoctorId != null && selectedDoctorId!.isNotEmpty) {
        await NotificationService.createNotification(
          recipientId: selectedDoctorId!,
          recipientRole: UserRoles.doctor,
          title: 'New appointment request',
          body:
              '${patientName.isEmpty ? 'A patient' : patientName} requested an appointment.',
          type: 'appointment_request',
          data: {
            'appointmentId': createdAppointmentId,
            'patientId': user.uid,
            'doctorId': selectedDoctorId,
          },
        );
      }

      await NotificationService.createNotification(
        recipientId: user.uid,
        recipientRole: UserRoles.patient,
        title: 'Appointment requested',
        body: 'Your appointment request has been submitted successfully.',
        type: 'appointment_request_sent',
        data: {
          'appointmentId': createdAppointmentId,
          'doctorId': selectedDoctorId,
        },
      );

      await NotificationService.notifyAdmins(
        title: 'New appointment request',
        body: 'A new appointment request is waiting for doctor response.',
        type: 'admin_appointment_alert',
        data: {
          'appointmentId': createdAppointmentId,
          'patientId': user.uid,
          'doctorId': selectedDoctorId,
        },
      );

      await AdminActivityService.log(
        action: 'appointment_created',
        targetType: 'appointment',
        targetId: createdAppointmentId ?? '',
        summary:
            'Patient $patientName created appointment request with doctor $selectedDoctor',
        metadata: {
          'patientId': user.uid,
          'doctorId': selectedDoctorId,
          'appointmentDate': selectedDate?.toIso8601String(),
          'slot': selectedSlot,
          'symptoms': selectedSymptoms.join(', '),
        },
        actorId: user.uid,
        actorRole: UserRoles.patient,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Appointment requested successfully.'))),
      );

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? t(
              'Booking is blocked by Firestore permissions. Please contact support.',
            )
          : t('Unable to book right now. Please try another slot.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('Slot already taken. Please choose another.')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        title: Text(
          t('Book Appointment'),
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

      body: SingleChildScrollView(
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
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Book Your Consultation'),
                    style: AppTypography.heading2.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t(
                      'Pick a doctor, choose a time slot, and submit your request in seconds.',
                    ),
                    style: AppTypography.bodyText.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            _surfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(t('1. Select Doctor')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _doctorSearchController,
                    onChanged: (value) {
                      setState(() {
                        _doctorSearchQuery = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: t('Search by doctor or speciality...'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _doctorSearchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _doctorSearchController.clear();
                                setState(() {
                                  _doctorSearchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderGray,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.borderGray,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 182,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(FirestoreCollections.doctors)
                          .where('status', isEqualTo: DoctorStatus.approved)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final doctors = snapshot.data!.docs.where((doc) {
                          if (_doctorSearchQuery.isEmpty) return true;
                          final doctorData = doc.data() as Map<String, dynamic>;
                          final first = (doctorData['firstName'] ?? '')
                              .toString();
                          final last = (doctorData['lastName'] ?? '')
                              .toString();
                          final specialization =
                              (doctorData['specialization'] ?? '').toString();
                          final searchable = '$first $last $specialization'
                              .toLowerCase();
                          return searchable.contains(_doctorSearchQuery);
                        }).toList();

                        if (doctors.isEmpty) {
                          return Center(
                            child: Text(
                              t('No doctors match your search'),
                              style: AppTypography.bodyText.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: doctors.length,
                          itemBuilder: (context, index) {
                            final doctorDoc = doctors[index];

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(doctorDoc.id)
                                  .get(),
                              builder: (context, userSnap) {
                                if (!userSnap.hasData) return const SizedBox();

                                final data =
                                    userSnap.data!.data()
                                        as Map<String, dynamic>? ??
                                    {};

                                final first = (data['firstName'] ?? '')
                                    .toString();
                                final last = (data['lastName'] ?? '')
                                    .toString();
                                final name = [
                                  first,
                                  last,
                                ].where((e) => e.isNotEmpty).join(' ');
                                final doctorData =
                                    doctorDoc.data() as Map<String, dynamic>;
                                final specialization =
                                    (doctorData['specialization'] ??
                                            data['specialization'] ??
                                            t('General'))
                                        .toString();
                                final photoUrl =
                                    (doctorData['profilePhotoUrl'] ??
                                            data['profilePhotoUrl'] ??
                                            '')
                                        .toString();

                                final isSelected =
                                    selectedDoctorId == doctorDoc.id;

                                return GestureDetector(
                                  onTap: () async {
                                    setState(() {
                                      selectedDoctor = name.isEmpty
                                          ? t('Doctor')
                                          : '${t('Dr.')} $name';
                                      selectedDoctorId = doctorDoc.id;
                                      selectedDoctorSpecialization =
                                          specialization;
                                      selectedSlot = null;
                                      availableSlots = [];
                                    });
                                    await loadAvailableSlots();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(12),
                                    width: 170,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primaryGreen.withOpacity(
                                              0.1,
                                            )
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primaryGreen
                                            : AppColors.borderGray,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundImage: photoUrl.isNotEmpty
                                              ? NetworkImage(photoUrl)
                                              : const AssetImage(
                                                      'assets/images/default_profile.jpg',
                                                    )
                                                    as ImageProvider,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          name.isEmpty
                                              ? t('Doctor')
                                              : '${t('Dr.')} $name',
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodyText
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          specialization,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodyText
                                              .copyWith(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
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

            const SizedBox(height: AppSpacing.md),

            if (selectedDoctor != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FAF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedDoctor!,
                      style: AppTypography.bodyText.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    if ((selectedDoctorSpecialization ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          selectedDoctorSpecialization!,
                          style: AppTypography.bodyText.copyWith(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            _surfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(t('2. Select Date & Slot')),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3)),
                      );

                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                          selectedSlot = null;
                        });

                        await loadAvailableSlots();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null
                                ? t('Choose a date')
                                : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                            style: AppTypography.bodyText,
                          ),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (selectedDoctorId == null)
                    Text(t('Select a doctor first'))
                  else if (selectedDate == null)
                    Text(t('Select a date'))
                  else if (_isLoadingSlots)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(),
                    )
                  else if (_slotStateMessage != null)
                    Text(
                      _slotStateMessage!,
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  if (availableSlots.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: availableSlots.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 170,
                            mainAxisExtent: 64,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemBuilder: (context, index) {
                        final slot = availableSlots[index];
                        final isBooked = bookedSlots.contains(slot);
                        final isSelected = selectedSlot == slot && !isBooked;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: isBooked
                              ? null
                              : () {
                                  setState(() {
                                    selectedSlot = slot;
                                  });
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isBooked
                                  ? Colors.red.withOpacity(0.12)
                                  : isSelected
                                  ? AppColors.primaryGreen
                                  : AppColors.primaryGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isBooked
                                    ? Colors.red
                                    : isSelected
                                    ? AppColors.primaryGreen
                                    : AppColors.primaryGreen,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: isBooked
                                      ? Colors.red
                                      : isSelected
                                      ? Colors.white
                                      : AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    slot,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyText.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isBooked
                                          ? Colors.red
                                          : isSelected
                                          ? Colors.white
                                          : AppColors.primaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            _surfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(t('3. Symptoms & Notes')),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 108,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 50,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _symptomsForRow(0).length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final symptom = _symptomsForRow(0)[index];
                              return _symptomPill(symptom);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 50,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _symptomsForRow(1).length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final symptom = _symptomsForRow(1)[index];
                              return _symptomPill(symptom);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: t('Add any details for the doctor...'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.borderGray),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            /// 🔥 BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _bookAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  _isSubmitting ? t('Booking...') : t('Confirm Appointment'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 SECTION TITLE
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AppTypography.heading3.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _surfaceCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  IconData _symptomIcon(String symptom) {
    switch (symptom) {
      case 'Cough':
      case 'Sore Throat':
      case 'Runny Nose':
        return Icons.masks_outlined;
      case 'Fever':
        return Icons.thermostat;
      case 'Headache':
      case 'Dizziness':
        return Icons.psychology_alt_outlined;
      case 'Chest Pain':
      case 'Shortness of Breath':
        return Icons.favorite_outline;
      case 'Back Pain':
      case 'Body Ache':
      case 'Joint Pain':
        return Icons.accessibility_new;
      case 'Stomach Pain':
      case 'Nausea':
      case 'Vomiting':
      case 'Diarrhea':
        return Icons.sick_outlined;
      case 'Skin Rash':
        return Icons.spa_outlined;
      case 'Anxiety':
      case 'Sleep Problems':
        return Icons.self_improvement;
      case 'Fatigue':
        return Icons.bedtime_outlined;
      default:
        return Icons.health_and_safety_outlined;
    }
  }

  List<String> _symptomsForRow(int rowIndex) {
    final list = <String>[];
    for (int i = 0; i < symptoms.length; i++) {
      if (i % 2 == rowIndex) {
        list.add(symptoms[i]);
      }
    }
    return list;
  }

  Widget _symptomPill(String symptom) {
    final isSelected = selectedSymptoms.contains(symptom);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedSymptoms.remove(symptom);
          } else {
            selectedSymptoms.add(symptom);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : const Color(0xFFF7FBF8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderGray,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _symptomIcon(symptom),
              size: 16,
              color: isSelected ? Colors.white : AppColors.primaryGreen,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                t(symptom),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyText.copyWith(
                  fontSize: 13,
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
