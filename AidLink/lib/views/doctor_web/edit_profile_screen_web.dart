import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Purpose: Doctor web profile editor (name, specialization, bio, photo, availability).
// File: lib/views/doctor_web/edit_profile_screen_web.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/colors.dart';
import '../../core/constants/doctor_specialties.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/widgets/app_input_field.dart';
import '../../core/widgets/searchable_dropdown_field.dart';

class EditProfileScreenWeb extends StatefulWidget {
  const EditProfileScreenWeb({Key? key}) : super(key: key);

  @override
  State<EditProfileScreenWeb> createState() => _EditProfileScreenWebState();
}

class _EditProfileScreenWebState extends State<EditProfileScreenWeb> {
  final user = FirebaseAuth.instance.currentUser;
  static const String imgbbApiKey = 'YOUR_IMGBB_API_KEY_HERE';
  static final RegExp _nameRegex = RegExp(r"^[A-Za-z][A-Za-z\s'-]{1,49}$");
  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
  static final RegExp _qualificationRegex = RegExp(
    r'^[A-Za-z0-9.,()\-/\s]{2,80}$',
  );
  static final RegExp _experienceRegex = RegExp(r'^(?:[0-9]|[1-6][0-9]|70)$');
  static final RegExp _hospitalRegex = RegExp(
    r"^[A-Za-z0-9 .,&'()\-/]{2,120}$",
  );
  static final RegExp _addressRegex = RegExp(
    r"^[A-Za-z0-9#.,'()\-/\s]{5,200}$",
  );
  static final RegExp _bioRegex = RegExp(r"^[A-Za-z0-9#.,'()\-/\s]{0,500}$");

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final specializationController = TextEditingController();
  final qualificationController = TextEditingController();
  final experienceController = TextEditingController();
  final hospitalController = TextEditingController();
  final addressController = TextEditingController();
  final bioController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _currentPhotoUrl;
  Uint8List? _pickedBytes;
  String? _pickedFileName;
  GeoPoint? _selectedLocation;
  String _locationStatus = 'Location not set';
  bool _isFetchingLocation = false;

  // Manual location input
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();
  String? _latitudeError;
  String? _longitudeError;
  bool _useManualLocation = false;

  String? firstNameError;
  String? lastNameError;
  String? phoneError;
  String? specializationError;
  String? qualificationError;
  String? experienceError;
  String? hospitalError;
  String? addressError;
  String? bioError;

  @override
  void initState() {
    super.initState();
    // --- Load existing doctor profile data ---
    _loadProfile();
  }

  @override
  void dispose() {
    // --- Cleanup form controllers ---
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    specializationController.dispose();
    qualificationController.dispose();
    experienceController.dispose();
    hospitalController.dispose();
    addressController.dispose();
    bioController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  // --- Load current profile values from Firestore ---
  Future<void> _loadProfile() async {
    if (user == null) return;

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final doctorSnap = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(user!.uid)
        .get();

    final u = userSnap.data() as Map<String, dynamic>? ?? {};
    final d = doctorSnap.data() as Map<String, dynamic>? ?? {};

    setState(() {
      firstNameController.text = u['firstName'] ?? '';
      lastNameController.text = u['lastName'] ?? '';
      phoneController.text = d['phone'] ?? '';
      specializationController.text =
          d['specialization'] ?? u['specialization'] ?? '';
      qualificationController.text = d['qualification'] ?? '';
      experienceController.text = d['experience'] ?? '';
      hospitalController.text = d['hospital'] ?? u['hospital'] ?? '';
      addressController.text = d['address'] ?? '';
      bioController.text = d['bio'] ?? '';
      _currentPhotoUrl = d['profilePhotoUrl'] ?? u['profilePhotoUrl'];
      final location = d['location'];
      if (location is GeoPoint) {
        _selectedLocation = location;
        latitudeController.text = location.latitude.toStringAsFixed(5);
        longitudeController.text = location.longitude.toStringAsFixed(5);
        _locationStatus =
            'Saved location: ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
      }
      _isLoading = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_isFetchingLocation) return;

    setState(() {
      _isFetchingLocation = true;
      _locationStatus = 'Fetching current location...';
      _useManualLocation = false;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('Location services are disabled.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw Exception('Location permission is required.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      final location = GeoPoint(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = location;
        _locationStatus =
            'Current location set: ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
        latitudeController.text = location.latitude.toStringAsFixed(5);
        longitudeController.text = location.longitude.toStringAsFixed(5);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current location saved for this profile.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  // ── Validate and set manual location ───────────────────────────────────────
  bool _validateManualLocation() {
    final latStr = latitudeController.text.trim();
    final lonStr = longitudeController.text.trim();

    setState(() {
      _latitudeError = null;
      _longitudeError = null;
    });

    if (latStr.isEmpty) {
      setState(() => _latitudeError = 'Latitude is required');
      return false;
    }
    if (lonStr.isEmpty) {
      setState(() => _longitudeError = 'Longitude is required');
      return false;
    }

    try {
      final lat = double.parse(latStr);
      final lon = double.parse(lonStr);

      if (lat < -90 || lat > 90) {
        setState(() => _latitudeError = 'Latitude must be between -90 and 90');
        return false;
      }
      if (lon < -180 || lon > 180) {
        setState(
          () => _longitudeError = 'Longitude must be between -180 and 180',
        );
        return false;
      }

      return true;
    } catch (e) {
      setState(() {
        if (latStr.isNotEmpty) {
          try {
            double.parse(latStr);
          } catch (_) {
            _latitudeError = 'Invalid latitude format';
          }
        }
        if (lonStr.isNotEmpty) {
          try {
            double.parse(lonStr);
          } catch (_) {
            _longitudeError = 'Invalid longitude format';
          }
        }
      });
      return false;
    }
  }

  void _setManualLocation() {
    if (!_validateManualLocation()) return;

    final lat = double.parse(latitudeController.text.trim());
    final lon = double.parse(longitudeController.text.trim());
    final location = GeoPoint(lat, lon);

    setState(() {
      _selectedLocation = location;
      _useManualLocation = true;
      _locationStatus =
          'Manual location set: ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Location set successfully')));
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    setState(() {
      _pickedFileName = picked.name;
      _pickedBytes = picked.bytes;
    });
  }

  Future<String?> _uploadPhoto(Uint8List bytes, String fileName) async {
    try {
      const int maxBytesForInlineStorage = 700 * 1024; // 700 KB
      if (bytes.length > maxBytesForInlineStorage) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File is too large (${(bytes.length / 1024).ceil()} KB). Please use a file under 700 KB.',
            ),
          ),
        );
        return null;
      }

      if (imgbbApiKey == 'YOUR_IMGBB_API_KEY_HERE') {
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {
          'image': base64Encode(bytes),
          'name': fileName,
          'key': imgbbApiKey,
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['data']?['url']?.toString();
      }

      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (_) {
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
  }

  bool _validate() {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final phone = phoneController.text.trim();
    final qualification = qualificationController.text.trim();
    final experience = experienceController.text.trim();
    final hospital = hospitalController.text.trim();
    final address = addressController.text.trim();
    final bio = bioController.text.trim();

    setState(() {
      firstNameError = _nameRegex.hasMatch(firstName)
          ? null
          : 'First name must be 2-50 letters only';
      lastNameError = _nameRegex.hasMatch(lastName)
          ? null
          : 'Last name must be 2-50 letters only';
      phoneError = _phoneRegex.hasMatch(phone)
          ? null
          : 'Enter a valid phone number (10-15 digits)';
      specializationError =
          DoctorSpecialties.all.contains(specializationController.text.trim())
          ? null
          : 'Please select a specialization';
      qualificationError =
          _qualificationRegex.hasMatch(qualification) &&
              qualification.isNotEmpty
          ? null
          : 'Qualification is required (2-80 valid chars)';
      experienceError = _experienceRegex.hasMatch(experience)
          ? null
          : 'Experience must be between 0 and 70';
      hospitalError = _hospitalRegex.hasMatch(hospital) && hospital.isNotEmpty
          ? null
          : 'Hospital name is required (2-120 valid chars)';
      addressError = _addressRegex.hasMatch(address) && address.isNotEmpty
          ? null
          : 'Address is required (5-200 valid chars)';
      bioError = _bioRegex.hasMatch(bio)
          ? null
          : 'Bio contains invalid characters';
    });

    return firstNameError == null &&
        lastNameError == null &&
        phoneError == null &&
        specializationError == null &&
        qualificationError == null &&
        experienceError == null &&
        hospitalError == null &&
        addressError == null &&
        bioError == null;
  }

  Future<void> _save() async {
    if (!_validate() || user == null) return;

    setState(() => _isSaving = true);

    try {
      String? photoUrl = _currentPhotoUrl;

      if (_pickedBytes != null) {
        photoUrl = await _uploadPhoto(
          _pickedBytes!,
          _pickedFileName ?? 'web_upload.jpg',
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
            'firstName': firstNameController.text.trim(),
            'lastName': lastNameController.text.trim(),
            if (photoUrl != null) 'profilePhotoUrl': photoUrl,
          });

      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user!.uid)
          .set({
            'phone': phoneController.text.trim(),
            'specialization': specializationController.text.trim(),
            'qualification': qualificationController.text.trim(),
            'experience': experienceController.text.trim(),
            'hospital': hospitalController.text.trim(),
            'address': addressController.text.trim(),
            'bio': bioController.text.trim(),
            if (_selectedLocation != null) 'location': _selectedLocation,
            if (_selectedLocation != null)
              'locationUpdatedAt': FieldValue.serverTimestamp(),
            if (photoUrl != null) 'profilePhotoUrl': photoUrl,
          }, SetOptions(merge: true));

      setState(() {
        _currentPhotoUrl = photoUrl;
        _pickedBytes = null;
        _pickedFileName = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 980;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white,
                            backgroundImage: _pickedBytes != null
                                ? MemoryImage(_pickedBytes!)
                                : (_currentPhotoUrl != null &&
                                      _currentPhotoUrl!.isNotEmpty)
                                ? (_currentPhotoUrl!.startsWith('data:image')
                                      ? MemoryImage(
                                          base64Decode(
                                            _currentPhotoUrl!.split(',').last,
                                          ),
                                        )
                                      : NetworkImage(_currentPhotoUrl!))
                                : const AssetImage(
                                    'assets/images/default_profile.jpg',
                                  ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Doctor Profile',
                                  style: AppTypography.heading2.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Update your personal and professional information',
                                  style: AppTypography.bodyText.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Change Photo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_pickedBytes != null)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          'New photo selected - click Save Changes to apply.',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.lg),

                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _sectionCard(
                              title: 'Personal Information',
                              child: Column(
                                children: [
                                  AppInputField(
                                    hintText: 'First Name',
                                    controller: firstNameController,
                                    errorText: firstNameError,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AppInputField(
                                    hintText: 'Last Name',
                                    controller: lastNameController,
                                    errorText: lastNameError,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AppInputField(
                                    hintText: 'Phone Number',
                                    controller: phoneController,
                                    errorText: phoneError,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AppInputField(
                                    hintText: 'Address',
                                    controller: addressController,
                                    errorText: addressError,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.borderGray,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Location',
                                          style: AppTypography.bodyText
                                              .copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _locationStatus,
                                          style: AppTypography.bodyText
                                              .copyWith(
                                                color: Colors.grey[700],
                                                fontSize: 12,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        // Current Location Button
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: _isFetchingLocation
                                                ? null
                                                : _useCurrentLocation,
                                            icon: _isFetchingLocation
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(Icons.my_location),
                                            label: const Text(
                                              'Use Current Location',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        // Manual Entry Section
                                        Divider(color: Colors.grey[300]),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          'Or enter coordinates manually:',
                                          style: AppTypography.bodyText
                                              .copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        // Latitude Input
                                        AppInputField(
                                          hintText: 'Latitude (-90 to 90)',
                                          controller: latitudeController,
                                          errorText: _latitudeError,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                signed: true,
                                                decimal: true,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        // Longitude Input
                                        AppInputField(
                                          hintText: 'Longitude (-180 to 180)',
                                          controller: longitudeController,
                                          errorText: _longitudeError,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                signed: true,
                                                decimal: true,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        // Set Manual Location Button
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _setManualLocation,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryGreen,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            child: const Text(
                                              'Set Manual Location',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _sectionCard(
                              title: 'Professional Information',
                              child: Column(
                                children: [
                                  SearchableDropdownField(
                                    controller: specializationController,
                                    label: 'Specialization',
                                    hintText: 'Select specialization',
                                    items: DoctorSpecialties.all,
                                    errorText: specializationError,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AppInputField(
                                    hintText: 'Qualification (MBBS, FCPS...)',
                                    controller: qualificationController,
                                    errorText: qualificationError,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AppInputField(
                                    hintText: 'Years of Experience',
                                    controller: experienceController,
                                    errorText: experienceError,
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AppInputField(
                                    hintText: 'Hospital / Clinic Name',
                                    controller: hospitalController,
                                    errorText: hospitalError,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _sectionCard(
                            title: 'Personal Information',
                            child: Column(
                              children: [
                                AppInputField(
                                  hintText: 'First Name',
                                  controller: firstNameController,
                                  errorText: firstNameError,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppInputField(
                                  hintText: 'Last Name',
                                  controller: lastNameController,
                                  errorText: lastNameError,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppInputField(
                                  hintText: 'Phone Number',
                                  controller: phoneController,
                                  errorText: phoneError,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppInputField(
                                  hintText: 'Address',
                                  controller: addressController,
                                  errorText: addressError,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _sectionCard(
                            title: 'Professional Information',
                            child: Column(
                              children: [
                                SearchableDropdownField(
                                  controller: specializationController,
                                  label: 'Specialization',
                                  hintText: 'Select specialization',
                                  items: DoctorSpecialties.all,
                                  errorText: specializationError,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppInputField(
                                  hintText: 'Qualification (MBBS, FCPS...)',
                                  controller: qualificationController,
                                  errorText: qualificationError,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppInputField(
                                  hintText: 'Years of Experience',
                                  controller: experienceController,
                                  errorText: experienceError,
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppInputField(
                                  hintText: 'Hospital / Clinic Name',
                                  controller: hospitalController,
                                  errorText: hospitalError,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: AppSpacing.md),

                    _sectionCard(
                      title: 'About',
                      child: TextField(
                        controller: bioController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Write a short bio about yourself...',
                          filled: true,
                          fillColor: AppColors.backgroundWhite,
                          contentPadding: const EdgeInsets.all(AppSpacing.md),
                          errorText: bioError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.borderGray,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 220,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
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
    );
  }
}
