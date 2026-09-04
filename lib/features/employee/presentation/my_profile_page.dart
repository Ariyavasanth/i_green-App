import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../authentication/providers/authentication_providers.dart';
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFE53935), size: 22),
            SizedBox(width: 10),
            Text('Log Out', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    ref.read(currentUserEmailProvider.notifier).state = null;
    await ref.read(authSessionStorageProvider).writeUserEmail(null);
    await ref.read(authenticationRepositoryProvider).signOut();
    ref.invalidate(employeesProvider);
    ref.invalidate(allEmployeesProvider);
    ref.invalidate(currentEmployeeProvider);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final emp = ref.watch(currentEmployeeProvider);

    if (emp == null) {
      return const Center(child: CircularProgressIndicator());
    }

    _syncEmployeeData(emp);

    final fullName = emp.fullName.trim().isNotEmpty
        ? emp.fullName.trim()
        : '${emp.firstName} ${emp.lastName}'.trim();
    final displayName = fullName.isNotEmpty ? fullName : 'User';
    final role = emp.designation.isNotEmpty
        ? emp.designation
        : (emp.userType.isNotEmpty ? emp.userType : 'Employee');
    final employeeId = emp.employeeId.isNotEmpty
        ? emp.employeeId
        : (emp.id != 0 ? 'EMP-00${emp.id}' : '-');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final hasPhoto = _selectedPhotoBytes != null || (_profileImageUrl.isNotEmpty && !_isPhotoRemoved);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 28,
            vertical: isMobile ? 16 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero Profile Card ──
                  Container(
                    padding: EdgeInsets.all(isMobile ? 18 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFE5E8E2),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.025),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (isMobile) ...[
                          // Mobile Hero Layout
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildAvatarWithBadge(initial, radius: 42),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      role,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _buildIdBadge(employeeId),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _buildChangePhotoButton(),
                              ),
                              if (hasPhoto) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildRemovePhotoButton(),
                                ),
                              ],
                            ],
                          ),
                        ] else ...[
                          // Desktop / Tablet Hero Layout
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildAvatarWithBadge(initial, radius: 46),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      role,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildIdBadge(employeeId),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildChangePhotoButton(),
                                  if (hasPhoto) ...[
                                    const SizedBox(height: 10),
                                    _buildRemovePhotoButton(),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        // Photo helper info line
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FBF7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFEBEFE6),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Allowed formats: JPG, PNG, WEBP. Recommended size: 400x400px.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Basic Information Card ──
                  Container(
                    padding: EdgeInsets.all(isMobile ? 18 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFE5E8E2),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.025),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.people_alt_outlined,
                                  color: AppColors.primary,
                                  size: 21,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Basic Information',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Your personal and employment details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Details List
                        _buildDetailItem(
                          icon: Icons.badge_outlined,
                          iconBg: const Color(0xFFF3E8FF),
                          iconColor: const Color(0xFF7C3AED),
                          label: 'Employee ID',
                          value: employeeId,
                        ),
                        _buildDetailItem(
                          icon: Icons.business_center_outlined,
                          iconBg: const Color(0xFFECFCCB),
                          iconColor: const Color(0xFF65A30D),
                          label: 'Role / Designation',
                          value: role,
                        ),
                        _buildDetailItem(
                          icon: Icons.corporate_fare_outlined,
                          iconBg: const Color(0xFFEDE9FE),
                          iconColor: const Color(0xFF8B5CF6),
                          label: 'Department',
                          value: emp.department.isNotEmpty
                              ? emp.department
                              : '-',
                        ),
                        _buildDetailItem(
                          icon: Icons.domain_outlined,
                          iconBg: const Color(0xFFE0F2FE),
                          iconColor: const Color(0xFF0284C7),
                          label: 'Organization',
                          value: emp.organizationName.isNotEmpty
                              ? emp.organizationName
                              : '-',
                        ),
                        _buildDetailItem(
                          icon: Icons.person_outline_rounded,
                          iconBg: const Color(0xFFFFEDD5),
                          iconColor: const Color(0xFFEA580C),
                          label: 'Work Schedule Type',
                          value: emp.workScheduleType.isNotEmpty
                              ? emp.workScheduleType
                              : (emp.isDynamicEmployee
                                  ? 'Flexible Schedule'
                                  : 'Fixed Schedule'),
                        ),
                        _buildDetailItem(
                          icon: Icons.calendar_today_outlined,
                          iconBg: const Color(0xFFCCFBF1),
                          iconColor: const Color(0xFF0D9488),
                          label: 'Date of Joining',
                          value: emp.joiningDate.isNotEmpty
                              ? emp.joiningDate
                              : '-',
                        ),
                        _buildDetailItem(
                          icon: Icons.mail_outline_rounded,
                          iconBg: const Color(0xFFFEF3C7),
                          iconColor: const Color(0xFFD97706),
                          label: 'Official Email',
                          value: emp.emailAddress.isNotEmpty
                              ? emp.emailAddress
                              : '-',
                        ),
                        _buildDetailItem(
                          icon: Icons.phone_outlined,
                          iconBg: const Color(0xFFF1F5F9),
                          iconColor: const Color(0xFF475569),
                          label: 'Phone Number',
                          value: emp.phoneNumber.isNotEmpty
                              ? emp.phoneNumber
                              : (emp.personalMobile.isNotEmpty
                                  ? emp.personalMobile
                                  : '-'),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Account / Log Out Card ──
                  Container(
                    padding: EdgeInsets.all(isMobile ? 18 : 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFE5E8E2),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.025),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Session',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Sign out of your account on this device',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text('Log Out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE53935),
                            side: const BorderSide(color: Color(0xFFFFCDD2)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
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

  Widget _buildAvatarWithBadge(String initial, {required double radius}) {
    Widget avatarChild;
    if (_selectedPhotoBytes != null) {
      avatarChild = CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary,
        backgroundImage: MemoryImage(_selectedPhotoBytes!),
      );
    } else if (_profileImageUrl.isNotEmpty && !_isPhotoRemoved) {
      if (_profileImageUrl.startsWith('data:')) {
        try {
          final commaIdx = _profileImageUrl.indexOf(',');
          final bytes = base64Decode(
            commaIdx != -1
                ? _profileImageUrl.substring(commaIdx + 1)
                : _profileImageUrl,
          );
          avatarChild = CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {
          avatarChild = _buildDefaultInitialAvatar(initial, radius);
        }
      } else if (_profileImageUrl.startsWith('http')) {
        avatarChild = CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary,
          backgroundImage: NetworkImage(_profileImageUrl),
        );
      } else {
        avatarChild = _buildDefaultInitialAvatar(initial, radius);
      }
    } else {
      avatarChild = _buildDefaultInitialAvatar(initial, radius);
    }

    return Stack(
      children: [
        avatarChild,
        Positioned(
          right: 0,
          bottom: 0,
          child: InkWell(
            onTap: _pickPhoto,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE5E8E2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultInitialAvatar(String initial, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: radius * 0.75,
          ),
        ),
      ),
    );
  }

  Widget _buildIdBadge(String id) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8E5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Text(
        id,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B8B06),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildChangePhotoButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _pickPhoto,
      icon: _isSaving
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.photo_camera_outlined, size: 16),
      label: const Text(
        'Change Photo',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildRemovePhotoButton() {
    return OutlinedButton.icon(
      onPressed: _isSaving ? null : _removePhoto,
      icon: const Icon(Icons.delete_outline_rounded, size: 16),
      label: const Text(
        'Remove Photo',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE53935),
        side: const BorderSide(color: Color(0xFFFFCDD2)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEEF2EA),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
        ],
      ),
    );
  }
}
