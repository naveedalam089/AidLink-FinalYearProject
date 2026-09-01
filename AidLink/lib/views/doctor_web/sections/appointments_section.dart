import 'package:flutter/material.dart';
// Purpose: Doctor web section for viewing appointment requests with approve/reject actions.
// File: lib/views/doctor_web/sections/appointments_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/app_values.dart';

class AppointmentsSection extends StatefulWidget {
  final Function(String patientId, String appointmentId, String patientName)
  onChatOpen;

  const AppointmentsSection({Key? key, required this.onChatOpen})
    : super(key: key);

  @override
  State<AppointmentsSection> createState() => _AppointmentsSectionState();
}

class _AppointmentsSectionState extends State<AppointmentsSection> {
  String selectedFilter = 'all';

  final List<String> _statusFilters = const [
    'all',
    AppointmentStatus.pending,
    AppointmentStatus.approved,
    AppointmentStatus.checkedIn,
    AppointmentStatus.inConsultation,
    AppointmentStatus.completed,
    AppointmentStatus.cancelled,
    AppointmentStatus.cancelledLate,
    AppointmentStatus.noShow,
    AppointmentStatus.rejected,
  ];

  // --- Format internal status key for dropdown labels ---
  String _statusLabel(String status) {
    if (status.isEmpty) return status;
    return '${status[0].toUpperCase()}${status.substring(1)}';
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // --- Update appointment status in Firestore ---
  Future<void> _updateStatus(String appointmentId, String status) async {
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .doc(appointmentId)
        .update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    // --- Build appointments table with status filtering ---
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Doctor not logged in'));
    }

    final stream = selectedFilter == 'all'
        ? FirebaseFirestore.instance
              .collection(FirestoreCollections.appointments)
              .where('doctorId', isEqualTo: user.uid)
              .snapshots()
        : FirebaseFirestore.instance
              .collection(FirestoreCollections.appointments)
              .where('doctorId', isEqualTo: user.uid)
              .where('status', isEqualTo: selectedFilter)
              .snapshots();

    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appointments', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.md),

          // Filter Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              DropdownButton<String>(
                value: selectedFilter,
                items: _statusFilters
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(
                          status == 'all' ? 'All' : _statusLabel(status),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedFilter = value!;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Appointments Table
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    'Failed to load appointments: ${snapshot.error}',
                    style: AppTypography.bodyText.copyWith(color: Colors.red),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = [...snapshot.data!.docs];
              docs.sort((a, b) {
                final aTs =
                    (a.data() as Map<String, dynamic>)['appointmentDate']
                        as Timestamp?;
                final bTs =
                    (b.data() as Map<String, dynamic>)['appointmentDate']
                        as Timestamp?;
                final aMs = aTs?.millisecondsSinceEpoch ?? 0;
                final bMs = bTs?.millisecondsSinceEpoch ?? 0;
                return bMs.compareTo(aMs);
              });

              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Text('No appointments found'),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    AppColors.primaryGreen.withOpacity(0.1),
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'ID',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Patient Name',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Time',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Symptoms',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Actions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final patientId = data['patientId'] as String? ?? '';
                    final status =
                        (data['status'] as String? ?? AppointmentStatus.pending)
                            .toLowerCase();
                    final symptoms = (data['symptoms'] as String? ?? '').trim();
                    final ts = data['appointmentDate'] as Timestamp?;
                    final date = ts?.toDate();
                    final time = (data['slot'] as String?)?.trim();

                    return DataRow(
                      cells: [
                        DataCell(Text('#${doc.id.substring(0, 6)}')),
                        DataCell(
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection(FirestoreCollections.users)
                                .doc(patientId)
                                .get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData) {
                                return const Text('Loading...');
                              }
                              final userData =
                                  userSnap.data!.data()
                                      as Map<String, dynamic>? ??
                                  {};
                              final patientName =
                                  '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                                      .trim();
                              return Text(
                                patientName.isEmpty ? 'Unknown' : patientName,
                              );
                            },
                          ),
                        ),
                        DataCell(Text(date == null ? '-' : _formatDate(date))),
                        DataCell(
                          Text(
                            (time == null || time.isEmpty)
                                ? (date == null
                                      ? '-'
                                      : TimeOfDay.fromDateTime(
                                          date,
                                        ).format(context))
                                : time,
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              symptoms.isEmpty ? '-' : symptoms,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_buildStatusBadge(status)),
                        DataCell(
                          Row(
                            children: [
                              if (status == AppointmentStatus.pending) ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: AppColors.primaryGreen,
                                  ),
                                  tooltip: 'Approve',
                                  onPressed: () => _updateStatus(
                                    doc.id,
                                    AppointmentStatus.approved,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Reject',
                                  onPressed: () => _updateStatus(
                                    doc.id,
                                    AppointmentStatus.rejected,
                                  ),
                                ),
                              ],
                              if (status == AppointmentStatus.approved) ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.task_alt,
                                    color: Colors.green,
                                  ),
                                  tooltip: 'Complete',
                                  onPressed: () => _updateStatus(
                                    doc.id,
                                    AppointmentStatus.completed,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Cancel',
                                  onPressed: () => _updateStatus(
                                    doc.id,
                                    AppointmentStatus.cancelled,
                                  ),
                                ),
                              ],
                              IconButton(
                                icon: const Icon(
                                  Icons.chat,
                                  color: AppColors.primaryGreen,
                                ),
                                tooltip: 'Chat',
                                onPressed: () async {
                                  final userDoc = await FirebaseFirestore
                                      .instance
                                      .collection(FirestoreCollections.users)
                                      .doc(patientId)
                                      .get();
                                  final userData = userDoc.data() ?? {};
                                  final patientName =
                                      '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                                          .trim();
                                  widget.onChatOpen(
                                    patientId,
                                    doc.id,
                                    patientName.isEmpty
                                        ? 'Patient'
                                        : patientName,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    switch (status) {
      case AppointmentStatus.pending:
        bgColor = Colors.orange;
        break;
      case AppointmentStatus.approved:
        bgColor = Colors.blue;
        break;
      case AppointmentStatus.completed:
        bgColor = Colors.green;
        break;
      case AppointmentStatus.checkedIn:
        bgColor = Colors.teal;
        break;
      case AppointmentStatus.inConsultation:
        bgColor = Colors.indigo;
        break;
      case AppointmentStatus.noShow:
        bgColor = Colors.deepOrange;
        break;
      case AppointmentStatus.cancelledLate:
        bgColor = Colors.redAccent;
        break;
      case AppointmentStatus.cancelled:
      case AppointmentStatus.rejected:
        bgColor = Colors.red;
        break;
      default:
        bgColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: bgColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
