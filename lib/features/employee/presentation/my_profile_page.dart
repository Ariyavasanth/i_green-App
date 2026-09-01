import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/employee.dart';
import '../providers/employee_providers.dart';

class MyProfilePage extends ConsumerStatefulWidget {
  const MyProfilePage({super.key});

  @override
  ConsumerState<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends ConsumerState<MyProfilePage> {
  bool _isSaving = false;
  Uint8List? _selectedPhotoBytes;
  String _profileImageUrl = '';
  bool _isPhotoRemoved = false;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _personalMobileController;
  late TextEditingController _presentAddressController;

  Employee? _lastEmployee;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _personalMobileController = TextEditingController();
    _presentAddressController = TextEditingController();
  }

  void _syncEmployeeData(Employee emp) {
    if (_lastEmployee?.id == emp.id && _profileImageUrl.isNotEmpty) return;
    _lastEmployee = emp;
    _profileImageUrl = emp.profileImageUrl;
    _firstNameController.text = emp.firstName;
    _lastNameController.text = emp.lastName;
    _phoneController.text = emp.phoneNumber;
    _personalMobileController.text = emp.personalMobile;
    _presentAddressController.text = emp.presentAddress;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _personalMobileController.dispose();
    _presentAddressController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final file = result?.files.isNotEmpty == true ? result!.files.first : null;
      if (file == null || file.bytes == null) return;

      final bytes = file.bytes!;
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'bmp' => 'image/bmp',
        _ => 'image/jpeg',
      };

      setState(() {
        _selectedPhotoBytes = bytes;
        _profileImageUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
        _isPhotoRemoved = false;
      });

      await _saveProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick photo: $e')),
      );
    }
  }

  Future<void> _removePhoto() async {
    setState(() {
      _selectedPhotoBytes = null;
      _profileImageUrl = '';
      _isPhotoRemoved = true;
    });
    await _saveProfile();
  }

  Future<void> _saveProfile() async {
    final currentEmp = ref.read(currentEmployeeProvider);
    if (currentEmp == null) return;

    setState(() => _isSaving = true);
    try {
      final updated = currentEmp.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        personalMobile: _personalMobileController.text.trim(),
        presentAddress: _presentAddressController.text.trim(),
        profileImageUrl: _isPhotoRemoved ? '' : _profileImageUrl,
      );

      final repo = ref.read(employeeRepositoryProvider);
      await repo.updateEmployee(updated);

      ref.invalidate(currentEmployeeProvider);
      ref.invalidate(allEmployeesProvider);
      ref.invalidate(employeesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = ref.watch(currentEmployeeProvider);

    if (emp == null) {
      return const Center(child: CircularProgressIndicator());
    }

    _syncEmployeeData(emp);

    final role = emp.designation.isNotEmpty
        ? emp.designation
        : (emp.userType.isNotEmpty ? emp.userType : 'Administrator');
    final initial = emp.fullName.trim().isNotEmpty
        ? emp.fullName.trim()[0].toUpperCase()
        : (emp.firstName.trim().isNotEmpty ? emp.firstName.trim()[0].toUpperCase() : 'A');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final hasPhoto = _selectedPhotoBytes != null || (_profileImageUrl.isNotEmpty && !_isPhotoRemoved);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 12 : 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Photo Card
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Profile Photo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const Spacer(),
                            if (_isSaving)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (isMobile) ...[
                          // Mobile Layout: Avatar + Buttons row below
                          Row(
                            children: [
                              _buildAvatarDisplay(emp, initial, radius: 36),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _isSaving ? null : _pickPhoto,
                                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                      label: const Text('Change Photo'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF414A51),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        minimumSize: const Size(double.infinity, 38),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                    if (hasPhoto) ...[
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: _isSaving ? null : _removePhoto,
                                        icon: const Icon(Icons.delete_outline, size: 16),
                                        label: const Text('Remove Photo'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFE53935),
                                          side: const BorderSide(color: Color(0xFFFFCDD2)),
                                          minimumSize: const Size(double.infinity, 38),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Allowed formats: JPG, PNG, WEBP. Recommended size: 400x400px.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ] else ...[
                          // Desktop / Tablet Layout
                          Row(
                            children: [
                              _buildAvatarDisplay(emp, initial, radius: 38),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: _isSaving ? null : _pickPhoto,
                                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                          label: const Text('Change Photo'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF414A51),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        if (hasPhoto) ...[
                                          const SizedBox(width: 12),
                                          OutlinedButton.icon(
                                            onPressed: _isSaving ? null : _removePhoto,
                                            icon: const Icon(Icons.delete_outline, size: 16),
                                            label: const Text('Remove Photo'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFE53935),
                                              side: const BorderSide(color: Color(0xFFFFCDD2)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Allowed formats: JPG, PNG, WEBP. Recommended size: 400x400px.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Basic Information Card
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoGrid(isMobile, [
                          _InfoTile(label: 'Employee ID', value: emp.employeeId.isNotEmpty ? emp.employeeId : 'EMP-${emp.id}'),
                          _InfoTile(label: 'Role / Designation', value: role),
                          _InfoTile(label: 'Department', value: emp.department.isNotEmpty ? emp.department : 'Finance & Accounts'),
                          _InfoTile(label: 'Organization', value: emp.organizationName.isNotEmpty ? emp.organizationName : 'IGreentec Engg. India Pvt. Ltd.'),
                          _InfoTile(label: 'Employment Type', value: emp.employmentType.isNotEmpty ? emp.employmentType : 'Full-Time'),
                          _InfoTile(label: 'Joining Date', value: emp.joiningDate.isNotEmpty ? emp.joiningDate : '—'),
                          _InfoTile(label: 'Gender', value: emp.gender.isNotEmpty ? emp.gender : '—'),
                          _InfoTile(label: 'Date of Birth', value: emp.dob.isNotEmpty ? emp.dob : '—'),
                          _InfoTile(label: 'Blood Group', value: emp.bloodGroup.isNotEmpty ? emp.bloodGroup : '—'),
                          _InfoTile(label: 'Status', value: emp.status.isNotEmpty ? emp.status : 'Active'),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact Information Card
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoGrid(isMobile, [
                          _InfoTile(label: 'Email Address', value: emp.emailAddress.isNotEmpty ? emp.emailAddress : '—'),
                          _InfoTile(label: 'Work Phone', value: emp.phoneNumber.isNotEmpty ? emp.phoneNumber : '—'),
                          _InfoTile(label: 'Personal Mobile', value: emp.personalMobile.isNotEmpty ? emp.personalMobile : '—'),
                          _InfoTile(label: 'Present Address', value: emp.presentAddress.isNotEmpty ? emp.presentAddress : '—'),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarDisplay(Employee employee, String initial, {required double radius}) {
    if (_selectedPhotoBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF414A51),
        backgroundImage: MemoryImage(_selectedPhotoBytes!),
      );
    }
    if (_profileImageUrl.isNotEmpty && !_isPhotoRemoved) {
      if (_profileImageUrl.startsWith('data:')) {
        try {
          final commaIdx = _profileImageUrl.indexOf(',');
          final bytes = base64Decode(commaIdx != -1 ? _profileImageUrl.substring(commaIdx + 1) : _profileImageUrl);
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF414A51),
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {}
      } else if (_profileImageUrl.startsWith('http://') || _profileImageUrl.startsWith('https://')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF414A51),
          backgroundImage: NetworkImage(_profileImageUrl),
        );
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF414A51),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  Widget _buildInfoGrid(bool isMobile, List<_InfoTile> tiles) {
    if (isMobile) {
      return Column(
        children: tiles.map((tile) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildTileContainer(tile, isFullWidth: true),
        )).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final halfWidth = (constraints.maxWidth - 14) / 2;
        return Wrap(
          spacing: 14,
          runSpacing: 12,
          children: tiles.map((tile) => SizedBox(
            width: halfWidth,
            child: _buildTileContainer(tile, isFullWidth: false),
          )).toList(),
        );
      },
    );
  }

  Widget _buildTileContainer(_InfoTile tile, {required bool isFullWidth}) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tile.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tile.value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;
}
