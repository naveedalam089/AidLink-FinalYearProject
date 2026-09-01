import 'dart:convert';

// Purpose: Doctor verification form and status display.
// File: lib/views/doctor_mobile/verification_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/colors.dart';
import '../../core/constants/app_values.dart';
import '../../core/constants/doctor_specialties.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/app_input_field.dart';
import '../../core/widgets/searchable_dropdown_field.dart';

class DoctorVerificationScreen extends StatefulWidget {
  const DoctorVerificationScreen({Key? key}) : super(key: key);

  @override
  State<DoctorVerificationScreen> createState() =>
      _DoctorVerificationScreenState();
}

class _DoctorVerificationScreenState extends State<DoctorVerificationScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final cnicController = TextEditingController();
  final licenseController = TextEditingController();
  final specializationController = TextEditingController();
  final qualificationController = TextEditingController();
  final experienceController = TextEditingController();
  final hospitalController = TextEditingController();
  final addressController = TextEditingController();
  final emergencyContactController = TextEditingController();
  final bankAccountController = TextEditingController();

  // Error message state variables
  String? nameError;
  String? emailError;
  String? phoneError;
  String? cnicError;
  String? licenseError;
  String? qualificationError;
  String? experienceError;
  String? hospitalError;
  String? addressError;
  String? emergencyContactError;
  String? bankAccountError;

  String? gender;
  DateTime? dob;
  bool isSubmitting = false;

  // Regex patterns for validation
  static const String namePattern = r'^[a-zA-Z\s]{3,50}$';
  static const String emailPattern =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phonePattern = r'^\+92[0-9]{10}$|^0[0-9]{10}$';
  static const String cnicPattern = r'^\d{5}-\d{7}-\d{1}$';
  static const String licensePattern = r'^[A-Za-z0-9\-]{3,20}$';
  static const String qualificationPattern = r'^[A-Za-z\s]{3,50}$';
  static const String experiencePattern = r'^[0-9]{1,2}$';
  static const String hospitalPattern = r'^[a-zA-Z0-9\s\-.,&]{3,100}$';
  static const String addressPattern = r'^[a-zA-Z0-9\s,.\-]{5,200}$';
  static const String emergencyContactPattern = r'^[0-9+\s\-()]{10,}$';
  static const String bankAccountPattern = r'^[A-Za-z0-9\-]{8,24}$';

  final Map<String, Map<String, dynamic>> _files = {
    'cnicFront': {
      'label': 'CNIC Front',
      'bytes': null,
      'path': null,
      'name': null,
      'uploading': false,
      'url': null,
    },
    'cnicBack': {
      'label': 'CNIC Back',
      'bytes': null,
      'path': null,
      'name': null,
      'uploading': false,
      'url': null,
    },
    'license': {
      'label': 'Medical License',
      'bytes': null,
      'path': null,
      'name': null,
      'uploading': false,
      'url': null,
    },
    'degree': {
      'label': 'Degree Certificate',
      'bytes': null,
      'path': null,
      'name': null,
      'uploading': false,
      'url': null,
    },
  };

  final List<String> _requiredDocs = [
    'cnicFront',
    'cnicBack',
    'license',
    'degree',
  ];

  late final Map<String, TextEditingController> _documentLinkControllers = {
    'cnicFront': TextEditingController(),
    'cnicBack': TextEditingController(),
    'license': TextEditingController(),
    'degree': TextEditingController(),
  };

  Future<void> _pickFile(String key) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _files[key]!['name'] = file.name;
      _files[key]!['url'] = null;
      _files[key]!['bytes'] = file.bytes;
      _files[key]!['path'] = file.path;
    });
  }

  Future<String?> _uploadFile(String key) async {
    final fileData = _files[key]!;
    final fileName = fileData['name'] as String?;
    final bytes = fileData['bytes'] as Uint8List?;

    if (fileName == null || bytes == null) return null;

    setState(() => _files[key]!['uploading'] = true);

    try {
      // Use imgbb free tier (alternatively use Cloudinary)
      // For imgbb: get API key from https://imgbb.com/api
      // For now, returning a placeholder - user must configure this
      const String imgbbApiKey = 'YOUR_IMGBB_API_KEY_HERE';

      const int maxBytesForInlineStorage = 700 * 1024; // 700 KB
      if (bytes.length > maxBytesForInlineStorage) {
        _showSnack(
          'File is too large (${(bytes.length / 1024).ceil()} KB). Please use a file under 700 KB, or paste a document link instead.',
        );
        setState(() => _files[key]!['uploading'] = false);
        return null;
      }

      if (imgbbApiKey == 'YOUR_IMGBB_API_KEY_HERE') {
        final base64String = base64Encode(bytes);
        setState(() {
          _files[key]!['url'] =
              'data:application/octet-stream;base64,$base64String';
          _files[key]!['uploading'] = false;
        });
        return _files[key]!['url'];
      }

      // Upload to imgbb
      final uri = Uri.parse('https://api.imgbb.com/1/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['key'] = imgbbApiKey
        ..files.add(
          http.MultipartFile.fromBytes('image', bytes, filename: fileName),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final url = jsonResponse['data']['url'] as String?;
        if (url != null) {
          setState(() {
            _files[key]!['url'] = url;
            _files[key]!['uploading'] = false;
          });
          return url;
        }
      }

      setState(() => _files[key]!['uploading'] = false);
      return null;
    } catch (e) {
      setState(() => _files[key]!['uploading'] = false);
      return null;
    }
  }

  String? _validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Name is required';
    if (trimmed.length < 3) return 'Name must be at least 3 characters';
    if (!RegExp(namePattern).hasMatch(trimmed)) {
      return 'Name must contain only letters and spaces';
    }
    return null;
  }

  String? _validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Email is required';
    if (!RegExp(emailPattern).hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Phone is required';
    if (!RegExp(phonePattern).hasMatch(trimmed)) {
      return 'Enter valid phone (+92XXXXXXXXXX or 0XXXXXXXXXX)';
    }
    return null;
  }

  String? _validateCNIC(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'CNIC is required';
    if (!RegExp(cnicPattern).hasMatch(trimmed)) {
      return 'CNIC format: XXXXX-XXXXXXX-X';
    }
    return null;
  }

  String? _validateLicense(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'License number is required';
    if (trimmed.length < 3)
      return 'License number must be at least 3 characters';
    if (!RegExp(licensePattern).hasMatch(trimmed)) {
      return 'License contains invalid characters';
    }
    return null;
  }

  String? _validateQualification(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Qualification is required';
    if (trimmed.length < 3)
      return 'Qualification must be at least 3 characters';
    if (!RegExp(qualificationPattern).hasMatch(trimmed)) {
      return 'Qualification contains invalid characters';
    }
    return null;
  }

  String? _validateExperience(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Experience is required';
    if (!RegExp(experiencePattern).hasMatch(trimmed)) {
      return 'Experience must be a number (0-99 years)';
    }
    final years = int.tryParse(trimmed);
    if (years == null || years > 70) return 'Enter valid years of experience';
    return null;
  }

  String? _validateHospital(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Hospital/Clinic name is required';
    if (trimmed.length < 3)
      return 'Hospital name must be at least 3 characters';
    if (!RegExp(hospitalPattern).hasMatch(trimmed)) {
      return 'Hospital name contains invalid characters';
    }
    return null;
  }

  String? _validateAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Address is required';
    if (trimmed.length < 5) return 'Address must be at least 5 characters';
    if (!RegExp(addressPattern).hasMatch(trimmed)) {
      return 'Address contains invalid characters';
    }
    return null;
  }

  String? _validateEmergencyContact(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Emergency contact is required';
    if (trimmed.length < 10)
      return 'Emergency contact must be at least 10 characters';
    if (!RegExp(emergencyContactPattern).hasMatch(trimmed)) {
      return 'Enter valid phone number or format';
    }
    return null;
  }

  String? _validateBankAccount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Bank account is required';
    if (trimmed.length < 8) return 'Bank account must be at least 8 characters';
    if (!RegExp(bankAccountPattern).hasMatch(trimmed)) {
      return 'Bank account contains invalid characters';
    }
    return null;
  }

  bool _validateAllFields() {
    nameError = _validateName(nameController.text);
    emailError = _validateEmail(emailController.text);
    phoneError = _validatePhone(phoneController.text);
    cnicError = _validateCNIC(cnicController.text);
    licenseError = _validateLicense(licenseController.text);
    qualificationError = _validateQualification(qualificationController.text);
    experienceError = _validateExperience(experienceController.text);
    hospitalError = _validateHospital(hospitalController.text);
    addressError = _validateAddress(addressController.text);
    emergencyContactError = _validateEmergencyContact(
      emergencyContactController.text,
    );
    bankAccountError = _validateBankAccount(bankAccountController.text);

    if (specializationController.text.trim().isEmpty) return false;
    if (!DoctorSpecialties.all.contains(specializationController.text.trim())) {
      return false;
    }
    if (gender == null) return false;
    if (dob == null) return false;

    return nameError == null &&
        emailError == null &&
        phoneError == null &&
        cnicError == null &&
        licenseError == null &&
        qualificationError == null &&
        experienceError == null &&
        hospitalError == null &&
        addressError == null &&
        emergencyContactError == null &&
        bankAccountError == null;
  }

  bool _anyDocumentsProvided() {
    // Check if ANY document was picked via file picker
    for (final key in _requiredDocs) {
      if (_files[key]!['name'] != null) return true;
    }
    // Check if ANY link was entered manually
    for (final key in _requiredDocs) {
      final link = _documentLinkControllers[key]!.text.trim();
      if (link.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _submitForm() async {
    if (!_validateAllFields()) {
      setState(() {});
      _showSnack('Please fix the errors in the form');
      return;
    }
    if (!_anyDocumentsProvided()) {
      _showSnack(
        'Please provide documents (upload files or enter links or both)',
      );
      return;
    }
    setState(() => isSubmitting = true);
    try {
      final Map<String, String?> uploadedFileUrls = {};
      final Map<String, String?> manualDocumentLinks = {};

      // Process picked files
      for (final key in _requiredDocs) {
        if (_files[key]!['name'] != null) {
          final url = _files[key]!['url'] ?? await _uploadFile(key);
          if (url == null) {
            _showSnack('Failed to upload ${_files[key]!['label']}. Try again.');
            setState(() => isSubmitting = false);
            return;
          }
          uploadedFileUrls[key] = url;
        }
      }

      // Process manually entered links
      for (final key in _requiredDocs) {
        final manualLink = _documentLinkControllers[key]!.text.trim();
        if (manualLink.isNotEmpty) {
          manualDocumentLinks[key] = manualLink;
        }
      }

      // Ensure at least one document was provided
      if (uploadedFileUrls.isEmpty && manualDocumentLinks.isEmpty) {
        _showSnack(
          'No documents were provided. Please upload files or enter links.',
        );
        setState(() => isSubmitting = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Build doctor record with document URLs
      final doctorData = {
        'status': 'pending',
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'cnic': cnicController.text.trim(),
        'licenseNumber': licenseController.text.trim(),
        'specialization': specializationController.text.trim(),
        'qualification': qualificationController.text.trim(),
        'experience': experienceController.text.trim(),
        'hospital': hospitalController.text.trim(),
        'address': addressController.text.trim(),
        'emergencyContact': emergencyContactController.text.trim(),
        'bankAccount': bankAccountController.text.trim(),
        'gender': gender,
        'dob': dob?.toIso8601String(),
        'submittedAt': FieldValue.serverTimestamp(),
      };

      // Save file-picker uploads and manual links separately, plus legacy combined URL field.
      if (uploadedFileUrls.containsKey('cnicFront')) {
        doctorData['cnicFrontFileUrl'] = uploadedFileUrls['cnicFront'];
      }
      if (manualDocumentLinks.containsKey('cnicFront')) {
        doctorData['cnicFrontLinkUrl'] = manualDocumentLinks['cnicFront'];
      }
      if (uploadedFileUrls.containsKey('cnicFront') ||
          manualDocumentLinks.containsKey('cnicFront')) {
        doctorData['cnicFrontUrl'] =
            uploadedFileUrls['cnicFront'] ?? manualDocumentLinks['cnicFront'];
      }

      if (uploadedFileUrls.containsKey('cnicBack')) {
        doctorData['cnicBackFileUrl'] = uploadedFileUrls['cnicBack'];
      }
      if (manualDocumentLinks.containsKey('cnicBack')) {
        doctorData['cnicBackLinkUrl'] = manualDocumentLinks['cnicBack'];
      }
      if (uploadedFileUrls.containsKey('cnicBack') ||
          manualDocumentLinks.containsKey('cnicBack')) {
        doctorData['cnicBackUrl'] =
            uploadedFileUrls['cnicBack'] ?? manualDocumentLinks['cnicBack'];
      }

      if (uploadedFileUrls.containsKey('license')) {
        doctorData['licenseFileUrl'] = uploadedFileUrls['license'];
      }
      if (manualDocumentLinks.containsKey('license')) {
        doctorData['licenseLinkUrl'] = manualDocumentLinks['license'];
      }
      if (uploadedFileUrls.containsKey('license') ||
          manualDocumentLinks.containsKey('license')) {
        doctorData['licenseUrl'] =
            uploadedFileUrls['license'] ?? manualDocumentLinks['license'];
      }

      if (uploadedFileUrls.containsKey('degree')) {
        doctorData['degreeFileUrl'] = uploadedFileUrls['degree'];
      }
      if (manualDocumentLinks.containsKey('degree')) {
        doctorData['degreeLinkUrl'] = manualDocumentLinks['degree'];
      }
      if (uploadedFileUrls.containsKey('degree') ||
          manualDocumentLinks.containsKey('degree')) {
        doctorData['degreeUrl'] =
            uploadedFileUrls['degree'] ?? manualDocumentLinks['degree'];
      }

      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .set(doctorData, SetOptions(merge: true));

      // Update user profile with non-document doctor fields.
      final userUpdate = <String, dynamic>{
        'specialization': specializationController.text.trim(),
        'hospital': hospitalController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(userUpdate);

      await NotificationService.notifyAdmins(
        title: 'New doctor verification request',
        body: '${nameController.text.trim()} submitted a verification request.',
        type: 'doctor_request_submitted',
        data: {
          'doctorId': user.uid,
          'doctorName': nameController.text.trim(),
          'doctorEmail': emailController.text.trim(),
          'specialization': specializationController.text.trim(),
          'recipientRole': UserRoles.admin,
        },
      );

      _showSnack('Verification request submitted successfully!');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showSnack('Something went wrong. Please try again.');
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    // --- Attach live validators to form fields ---
    nameController.addListener(() {
      setState(() => nameError = _validateName(nameController.text));
    });
    emailController.addListener(() {
      setState(() => emailError = _validateEmail(emailController.text));
    });
    phoneController.addListener(() {
      setState(() => phoneError = _validatePhone(phoneController.text));
    });
    cnicController.addListener(() {
      setState(() => cnicError = _validateCNIC(cnicController.text));
    });
    licenseController.addListener(() {
      setState(() => licenseError = _validateLicense(licenseController.text));
    });
    qualificationController.addListener(() {
      setState(
        () => qualificationError = _validateQualification(
          qualificationController.text,
        ),
      );
    });
    experienceController.addListener(() {
      setState(
        () => experienceError = _validateExperience(experienceController.text),
      );
    });
    hospitalController.addListener(() {
      setState(
        () => hospitalError = _validateHospital(hospitalController.text),
      );
    });
    addressController.addListener(() {
      setState(() => addressError = _validateAddress(addressController.text));
    });
    emergencyContactController.addListener(() {
      setState(
        () => emergencyContactError = _validateEmergencyContact(
          emergencyContactController.text,
        ),
      );
    });
    bankAccountController.addListener(() {
      setState(
        () =>
            bankAccountError = _validateBankAccount(bankAccountController.text),
      );
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    // --- Validate form, upload docs, save doctor record, notify admins ---
    emailController.dispose();
    phoneController.dispose();
    cnicController.dispose();
    licenseController.dispose();
    specializationController.dispose();
    qualificationController.dispose();
    experienceController.dispose();
    hospitalController.dispose();
    addressController.dispose();
    emergencyContactController.dispose();
    bankAccountController.dispose();
    for (final controller in _documentLinkControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Doctor Verification',
          style: AppTypography.heading2.copyWith(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Personal Information'),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'Full Name',
                controller: nameController,
                errorText: nameError,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'Email',
                controller: emailController,
                errorText: emailError,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'Phone (+92...)',
                controller: phoneController,
                errorText: phoneError,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'CNIC (xxxxx-xxxxxxx-x)',
                controller: cnicController,
                errorText: cnicError,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Gender', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: gender,
                hint: const Text('Select Gender'),
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (value) => setState(() => gender = value),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Date of Birth', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(1990),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => dob = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderGray),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dob == null
                            ? 'Select Date of Birth'
                            : '${dob!.day}/${dob!.month}/${dob!.year}',
                        style: AppTypography.bodyText.copyWith(
                          color: dob == null ? Colors.grey : Colors.black,
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _sectionTitle('Professional Information'),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'Medical License Number',
                controller: licenseController,
                errorText: licenseError,
              ),
              const SizedBox(height: AppSpacing.sm),
              SearchableDropdownField(
                controller: specializationController,
                label: 'Specialization',
                hintText: 'Select specialization',
                items: DoctorSpecialties.all,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'Qualification (MBBS, FCPS...)',
                controller: qualificationController,
                errorText: qualificationError,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'Years of Experience',
                controller: experienceController,
                errorText: experienceError,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'Hospital / Clinic Name',
                controller: hospitalController,
                errorText: hospitalError,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'Address',
                controller: addressController,
                errorText: addressError,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'Emergency Contact',
                controller: emergencyContactController,
                errorText: emergencyContactError,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppInputField(
                hintText: 'Bank Account Details',
                controller: bankAccountController,
                errorText: bankAccountError,
              ),
              const SizedBox(height: AppSpacing.lg),
              _sectionTitle('Upload Documents'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'All documents required. Accepted: JPG, PNG, PDF',
                style: AppTypography.bodyText.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._requiredDocs.map((key) => _buildUploadTile(key)),
              const SizedBox(height: AppSpacing.lg),
              _sectionTitle('Document Links (Optional)'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Or paste document links/URLs directly',
                style: AppTypography.bodyText.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._requiredDocs.map((key) => _buildLinkField(key)),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit for Verification',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // --- Logout Button ---
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadTile(String key) {
    final file = _files[key]!;
    final label = file['label'] as String;
    final name = file['name'] as String?;
    final isUploading = file['uploading'] as bool;
    final isUploaded = file['url'] != null;

    Color borderColor = isUploaded
        ? AppColors.primaryGreen
        : AppColors.borderGray;

    Widget trailing;
    if (isUploading) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (isUploaded) {
      trailing = const Icon(Icons.check_circle, color: Colors.green);
    } else if (name != null) {
      trailing = const Icon(Icons.cloud_upload, color: AppColors.primaryGreen);
    } else {
      trailing = const Icon(Icons.upload_file, color: Colors.grey);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          _iconForKey(key),
          color: isUploaded ? Colors.green : AppColors.primaryGreen,
        ),
        title: Text(
          label,
          style: AppTypography.bodyText.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          name == null
              ? 'Tap to upload'
              : isUploaded
              ? 'Uploaded ✓'
              : name,
          style: AppTypography.bodyText.copyWith(
            fontSize: 12,
            color: isUploaded ? Colors.green : Colors.grey[700],
          ),
        ),
        trailing: trailing,
        onTap: isUploading ? null : () => _pickFile(key),
      ),
    );
  }

  Widget _buildLinkField(String key) {
    final label = _files[key]!['label'] as String;
    final controller = _documentLinkControllers[key]!;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppInputField(
        hintText: 'Paste link or URL for $label',
        controller: controller,
      ),
    );
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'cnicFront':
      case 'cnicBack':
        return Icons.credit_card;
      case 'license':
        return Icons.verified;
      case 'degree':
        return Icons.school;
      default:
        return Icons.upload_file;
    }
  }

  Widget _sectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.heading2),
        const Divider(),
      ],
    );
  }
}
