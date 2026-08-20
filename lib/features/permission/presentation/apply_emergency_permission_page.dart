import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../leave/providers/leave_providers.dart';
import '../domain/permission_enums.dart';
import '../domain/permission_request.dart';
import '../providers/permission_providers.dart';

class ApplyEmergencyPermissionPage extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialFromTime;
  final TimeOfDay? initialToTime;
  final PermissionType? initialType;

  const ApplyEmergencyPermissionPage({
    super.key,
    this.initialDate,
    this.initialFromTime,
    this.initialToTime,
    this.initialType,
  });

  static const Color primaryGreen = Color(0xFF9CC70A);
  static const Color darkNeutral = Color(0xFF414A51);

  @override
  ConsumerState<ApplyEmergencyPermissionPage> createState() => _ApplyEmergencyPermissionPageState();
}

class _ApplyEmergencyPermissionPageState extends ConsumerState<ApplyEmergencyPermissionPage> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late PermissionType _selectedType;
  late TimeOfDay _fromTime;
  late TimeOfDay _toTime;

  final _emergencyReasonController = TextEditingController();
  final _attachmentController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedType = widget.initialType ?? PermissionType.personalWork;
    _fromTime = widget.initialFromTime ?? const TimeOfDay(hour: 14, minute: 0);
    _toTime = widget.initialToTime ?? const TimeOfDay(hour: 17, minute: 0);
  }

  int get _durationMinutes {
    final startMinutes = _fromTime.hour * 60 + _fromTime.minute;
    final endMinutes = _toTime.hour * 60 + _toTime.minute;
    final diff = endMinutes - startMinutes;
    return diff > 0 ? diff : 0;
  }

  @override
  void dispose() {
    _emergencyReasonController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitEmergency() async {
    if (!_formKey.currentState!.validate()) return;

    if (_durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('To Time must be later than From Time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final emp = ref.read(currentEmployeeProvider);
      final employeeId = emp?.id ?? 1;
      final repo = ref.read(permissionRepositoryProvider);

      final req = PermissionRequest(
        employeeId: employeeId,
        employeeName: '${emp?.firstName ?? "Admin"} ${emp?.lastName ?? "User"}',
        employeeCode: emp?.employeeId ?? 'EMP-001',
        department: emp?.department ?? 'Management',
        date: _selectedDate,
        fromTime: _fromTime.format(context),
        toTime: _toTime.format(context),
        durationMinutes: _durationMinutes,
        permissionType: _selectedType,
        reason: 'Emergency Exception: ${_emergencyReasonController.text.trim()}',
        status: PermissionStatus.emergencyPending,
        isEmergency: true,
        emergencyReason: _emergencyReasonController.text.trim(),
        attachmentUrl: _attachmentController.text.trim(),
        submittedAt: DateTime.now(),
      );

      await repo.submitEmergencyRequest(req);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Emergency Permission Request submitted for Admin Review'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      context.go('/permission');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: $e'),
          backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.report_problem_outlined, color: Colors.orange.shade900, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Exception Request',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Emergency requests bypass standard limit checks but require mandatory Admin/Manager review. Management will decide whether this duration is approved as Paid or Loss of Pay (LOP).',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Request Summary Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Requested Duration:', style: TextStyle(color: Colors.grey.shade700)),
                        Text('$_durationMinutes mins', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Time Range:', style: TextStyle(color: Colors.grey.shade700)),
                        Text('${_fromTime.format(context)} - ${_toTime.format(context)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Emergency Reason Input
              const Text(
                'Emergency Reason (Mandatory)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ApplyEmergencyPermissionPage.darkNeutral),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emergencyReasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Detailed explanation of the emergency situation...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter detailed emergency reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Supporting Document / Attachment
              const Text(
                'Supporting Document / Document Reference (Optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ApplyEmergencyPermissionPage.darkNeutral),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _attachmentController,
                decoration: InputDecoration(
                  hintText: 'Document link, medical slip reference, or notes...',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.attach_file, color: ApplyEmergencyPermissionPage.darkNeutral),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmitEmergency,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Emergency Exception Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
