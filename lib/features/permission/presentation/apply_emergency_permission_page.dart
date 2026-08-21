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

      ref.invalidate(myPermissionRequestsProvider(employeeId));
      ref.invalidate(employeePermissionBalanceProvider(employeeId));
      ref.invalidate(allPermissionRequestsProvider);

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

  void _showCompanyRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Company Permission Rules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ruleItem('1. Daily Allowance', 'Maximum 1.0 Hour (60 minutes) per day.'),
              _ruleItem('2. Monthly Allowance', 'Maximum 3.0 Hours (180 minutes) per month.'),
              _ruleItem('3. Approval Required', 'All normal permissions require Manager / Admin approval.'),
              _ruleItem('4. Emergency Exception', 'Requests exceeding standard allowances can be submitted as Emergency Requests for Admin review.'),
              _ruleItem('5. Payroll Treatment', 'Management reviews emergency requests to decide Paid vs Loss of Pay (LOP) treatment.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _ruleItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
          ),
        ],
      ),
    );
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
                    IconButton(
                      icon: Icon(Icons.info_outline, color: Colors.orange.shade900, size: 22),
                      tooltip: 'Company Permission Rules',
                      onPressed: () => _showCompanyRulesDialog(context),
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
