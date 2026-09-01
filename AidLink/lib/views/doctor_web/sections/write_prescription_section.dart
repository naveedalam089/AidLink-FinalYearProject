import 'package:flutter/material.dart';
// Purpose: Doctor web section for writing and submitting prescriptions.
// File: lib/views/doctor_web/sections/write_prescription_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/admin_activity_service.dart';

class WritePrescriptionSection extends StatefulWidget {
  final String patientId;
  final String appointmentId;

  const WritePrescriptionSection({
    Key? key,
    required this.patientId,
    required this.appointmentId,
  }) : super(key: key);

  @override
  State<WritePrescriptionSection> createState() =>
      _WritePrescriptionSectionState();
}

class _WritePrescriptionSectionState extends State<WritePrescriptionSection> {
  final diagnosisController = TextEditingController();
  final adviceController = TextEditingController();

  DateTime? followUpDate;

  List<Map<String, dynamic>> medicines = [];

  final List<String> suggestions = [
    "Paracetamol",
    "Ibuprofen",
    "Amoxicillin",
    "Azithromycin",
    "Vitamin C",
  ];

  // --- Add empty medicine row ---
  void addMedicine() {
    setState(() {
      medicines.add({
        "name": "",
        "dosage": "",
        "frequency": "",
        "duration": "",
      });
    });
  }

  // --- Add medicine from quick suggestions ---
  void addQuickMedicine(String name) {
    setState(() {
      medicines.add({
        "name": name,
        "dosage": "",
        "frequency": "",
        "duration": "",
      });
    });
  }

  // --- Remove medicine row by index ---
  void removeMedicine(int index) {
    setState(() {
      medicines.removeAt(index);
    });
  }

  // --- Save prescription and notify patient/admin ---
  Future<void> savePrescription() async {
    final doctor = FirebaseAuth.instance.currentUser;

    if (doctor == null) return;

    final newPrescription = await FirebaseFirestore.instance
        .collection(FirestoreCollections.prescriptions)
        .add({
          "doctorId": doctor.uid,
          "patientId": widget.patientId,
          "appointmentId": widget.appointmentId,
          "diagnosis": diagnosisController.text,
          "medicines": medicines,
          PrescriptionFields.advice: adviceController.text,
          "followUpDate": followUpDate,
          "createdAt": FieldValue.serverTimestamp(),
        });

    await NotificationService.createNotification(
      recipientId: widget.patientId,
      recipientRole: UserRoles.patient,
      title: 'New prescription added',
      body: 'Your doctor uploaded a new prescription for you.',
      type: 'prescription_added',
      data: {
        'prescriptionId': newPrescription.id,
        'appointmentId': widget.appointmentId,
      },
    );

    await NotificationService.notifyAdmins(
      title: 'Prescription added',
      body: 'A doctor uploaded a new prescription for a patient.',
      type: 'admin_prescription_added',
      data: {
        'prescriptionId': newPrescription.id,
        'appointmentId': widget.appointmentId,
        'doctorId': doctor.uid,
        'patientId': widget.patientId,
      },
    );

    await AdminActivityService.log(
      action: 'prescription_created',
      targetType: 'prescription',
      targetId: newPrescription.id,
      summary: 'Doctor created prescription for patient',
      metadata: {
        'doctorId': doctor.uid,
        'patientId': widget.patientId,
        'appointmentId': widget.appointmentId,
        'medicines': medicines.length,
        'hasDiagnosis': diagnosisController.text.trim().isNotEmpty,
        'hasFollowUp': followUpDate != null,
      },
      actorId: doctor.uid,
      actorRole: UserRoles.doctor,
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Prescription saved")));
  }

  Widget medicineRow(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderGray),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: TextEditingController(text: medicines[index]["name"]),
              decoration: const InputDecoration(
                hintText: "Medicine",
                border: InputBorder.none,
              ),
              onChanged: (v) => medicines[index]["name"] = v,
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Dosage",
                border: InputBorder.none,
              ),
              onChanged: (v) => medicines[index]["dosage"] = v,
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Freq",
                border: InputBorder.none,
              ),
              onChanged: (v) => medicines[index]["frequency"] = v,
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Duration",
                border: InputBorder.none,
              ),
              onChanged: (v) => medicines[index]["duration"] = v,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => removeMedicine(index),
          ),
        ],
      ),
    );
  }

  Widget suggestionChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: suggestions.map((m) {
        return InkWell(
          onTap: () => addQuickMedicine(m),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryGreen),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 16, color: AppColors.primaryGreen),
                const SizedBox(width: 6),
                Text(
                  m,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget sectionCard(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.borderGray),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.heading3),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Write Prescription", style: AppTypography.heading2),

        const SizedBox(height: AppSpacing.lg),

        sectionCard(
          "Diagnosis",
          TextField(
            controller: diagnosisController,
            decoration: const InputDecoration(hintText: "Enter diagnosis"),
          ),
        ),

        sectionCard("Quick Medicines", suggestionChips()),

        sectionCard(
          "Medicines",
          Column(
            children: [
              ...List.generate(medicines.length, medicineRow),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: addMedicine,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Medicine"),
                ),
              ),
            ],
          ),
        ),

        sectionCard(
          "Doctor Advice",
          TextField(
            controller: adviceController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: "Enter patient advice"),
          ),
        ),

        sectionCard(
          "Follow Up",
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );

                  if (picked != null) {
                    setState(() {
                      followUpDate = picked;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: const Text(
                  "Select Date",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              if (followUpDate != null)
                Text(
                  "${followUpDate!.day}/${followUpDate!.month}/${followUpDate!.year}",
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: savePrescription,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              "Save Prescription",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
