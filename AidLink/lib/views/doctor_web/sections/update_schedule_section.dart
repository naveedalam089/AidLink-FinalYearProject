// Purpose: Doctor web section for managing availability schedule (update hours, postpone days).
// File: lib/views/doctor_web/sections/update_schedule_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_values.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/admin_activity_service.dart';
import '../../../core/services/notification_service.dart';

class UpdateScheduleSection extends StatefulWidget {
  const UpdateScheduleSection({Key? key}) : super(key: key);

  @override
  State<UpdateScheduleSection> createState() => _UpdateScheduleSectionState();
}

class _UpdateScheduleSectionState extends State<UpdateScheduleSection> {
  final user = FirebaseAuth.instance.currentUser;

  final List<String> days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Set<String> selectedDays = {};
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  int slotDuration = 30;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // --- Load existing schedule on section start ---
    _loadExistingSchedule();
  }

  // --- Fetch existing schedule data from Firestore ---
  Future<void> _loadExistingSchedule() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('doctor_availability')
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        selectedDays = Set<String>.from(data['workingDays'] ?? []);
        startTime = _parseTime((data['startTime'] ?? '09:00').toString());
        endTime = _parseTime((data['endTime'] ?? '17:00').toString());
        slotDuration = (data['slotDuration'] ?? 30) as int;
      });
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _dayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      default:
        return 'Sunday';
    }
  }

  Future<void> _saveSchedule() async {
    if (user == null) return;

    if (selectedDays.isEmpty || startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('doctor_availability')
        .doc(user!.uid)
        .set({
          'doctorId': user!.uid,
          'workingDays': selectedDays.toList(),
          'startTime': _formatTime(startTime!),
          'endTime': _formatTime(endTime!),
          'slotDuration': slotDuration,
          'createdAt': FieldValue.serverTimestamp(),
        });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule updated successfully')),
    );
  }

  Future<void> _postponeDay(String day) async {
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Postpone day'),
        content: Text(
          'Are you sure you want to postpone $day? This will notify affected patients and offer reschedule options.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final now = DateTime.now();
    final targetDates = List<DateTime>.generate(
      7,
      (index) => now.add(Duration(days: index)),
    ).where((date) => _dayName(date.weekday) == day).toList();

    final batch = FirebaseFirestore.instance.batch();
    final List<Map<String, String>> offersToNotify = [];

    for (final date in targetDates) {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final appts = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user!.uid)
          .where('appointmentDate', isGreaterThanOrEqualTo: start)
          .where('appointmentDate', isLessThan: end)
          .get();

      for (final appt in appts.docs) {
        final data = appt.data();
        final patientId = (data['patientId'] ?? '').toString();

        batch.update(appt.reference, {
          'status': AppointmentStatus.postponed,
          'postponedAt': FieldValue.serverTimestamp(),
          'postponedForDay': day,
        });

        final offerRef = FirebaseFirestore.instance
            .collection('postponed_offers')
            .doc();
        batch.set(offerRef, {
          'appointmentId': appt.id,
          'patientId': patientId,
          'doctorId': user!.uid,
          'originalDate': appt['appointmentDate'],
          'originalSlot': appt['slot'] ?? '',
          'offerType': 'next_day_or_cancel',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24)),
          ),
        });

        offersToNotify.add({
          'patientId': patientId,
          'offerId': offerRef.id,
          'appointmentId': appt.id,
        });
      }
    }

    await batch.commit();

    for (final offer in offersToNotify) {
      try {
        await NotificationService.createNotification(
          recipientId: offer['patientId']!,
          recipientRole: UserRoles.patient,
          title: 'Appointment postponed',
          body:
              'Your appointment has been postponed by the doctor. You can accept the same slot next day or reschedule.',
          type: 'postpone_offer',
          data: {
            'offerId': offer['offerId'],
            'appointmentId': offer['appointmentId'],
            'suggestedSameSlotNextDay': true,
          },
        );
      } catch (_) {}
    }

    await AdminActivityService.log(
      action: 'postponement_created',
      targetType: 'doctor_availability',
      targetId: user!.uid,
      summary: 'Doctor postponed a working day and notified affected patients.',
      metadata: {'day': day, 'affectedAppointments': offersToNotify.length},
      actorId: user!.uid,
      actorRole: UserRoles.doctor,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Day postponed and patients notified.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Update Schedule', style: AppTypography.heading2),
        const SizedBox(height: AppSpacing.md),
        Text('Working Days', style: AppTypography.heading3),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          children: days.map((day) {
            final isSelected = selectedDays.contains(day);

            return ChoiceChip(
              label: Text(day),
              selected: isSelected,
              selectedColor: AppColors.primaryGreen,
              onSelected: (_) {
                setState(() {
                  if (isSelected) {
                    selectedDays.remove(day);
                  } else {
                    selectedDays.add(day);
                  }
                });
              },
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Start Time', style: AppTypography.heading3),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
            );
            if (picked != null) {
              setState(() => startTime = picked);
            }
          },
          child: _timeBox(startTime, 'Select start time'),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('End Time', style: AppTypography.heading3),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: endTime ?? const TimeOfDay(hour: 17, minute: 0),
            );
            if (picked != null) {
              setState(() => endTime = picked);
            }
          },
          child: _timeBox(endTime, 'Select end time'),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Slot Duration (minutes)', style: AppTypography.heading3),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<int>(
          value: slotDuration,
          items: [15, 30, 45, 60]
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text('$value minutes'),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => slotDuration = value!);
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Save Schedule',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              if (selectedDays.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No working days selected')),
                );
                return;
              }

              final day = await showDialog<String?>(
                context: context,
                builder: (dialogContext) {
                  String? pick = selectedDays.first;
                  return AlertDialog(
                    title: const Text('Pick day to postpone'),
                    content: DropdownButtonFormField<String>(
                      value: pick,
                      items: selectedDays
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => pick = value,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, pick),
                        child: const Text('Postpone'),
                      ),
                    ],
                  );
                },
              );

              if (day != null && day.isNotEmpty) {
                await _postponeDay(day);
              }
            },
            child: const Text('Postpone Day'),
          ),
        ),
      ],
    );
  }

  Widget _timeBox(TimeOfDay? time, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderGray),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        time == null ? hint : time.format(context),
        style: AppTypography.bodyText,
      ),
    );
  }
}
