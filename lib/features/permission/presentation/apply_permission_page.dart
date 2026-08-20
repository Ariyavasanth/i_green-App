import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../leave/providers/leave_providers.dart';
import '../domain/permission_enums.dart';
import '../domain/permission_request.dart';
import '../providers/permission_providers.dart';
import 'apply_emergency_permission_page.dart';

class ApplyPermissionPage extends ConsumerStatefulWidget {
  const ApplyPermissionPage({super.key});

  static const Color primaryGreen = Color(0xFF9CC70A);
  static const Color darkNeutral = Color(0xFF414A51);

  @override
  ConsumerState<ApplyPermissionPage> createState() => _ApplyPermissionPageState();
}

class _ApplyPermissionPageState extends ConsumerState<ApplyPermissionPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  PermissionType _selectedType = PermissionType.lateArrival;
  TimeOfDay _fromTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _toTime = const TimeOfDay(hour: 9, minute: 30);
  final _reasonController = TextEditingController();

  bool _isSubmitting = false;

  int get _durationMinutes {
    final startMinutes = _fromTime.hour * 60 + _fromTime.minute;
    final endMinutes = _toTime.hour * 60 + _toTime.minute;
    final diff = endMinutes - startMinutes;
    return diff > 0 ? diff : 0;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickFromTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _fromTime,
    );
    if (picked != null) {
      setState(() {
        _fromTime = picked;
        // Auto set toTime 30 mins after fromTime if toTime <= fromTime
        final fromMins = _fromTime.hour * 60 + _fromTime.minute;
        final toMins = _toTime.hour * 60 + _toTime.minute;
        if (toMins <= fromMins) {
          final newToMins = fromMins + 30;
          _toTime = TimeOfDay(hour: (newToMins ~/ 60) % 24, minute: newToMins % 60);
        }
      });
    }
  }

  Future<void> _pickToTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _toTime,
    );
    if (picked != null) {
      setState(() {
        _toTime = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
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

    final emp = ref.read(currentEmployeeProvider);
    final employeeId = emp?.id ?? 1;
    final repo = ref.read(permissionRepositoryProvider);

    final balance = await repo.getPermissionBalance(employeeId, _selectedDate);

    // Validation Check: Does request exceed today's remaining or monthly remaining?
    if (_durationMinutes > balance.todayRemainingMinutes ||
        _durationMinutes > balance.monthlyRemainingMinutes) {
      if (!mounted) return;
      _showEmergencyExceededDialog(balance);
      return;
    }

    // Normal Submission
    setState(() {
      _isSubmitting = true;
    });

    try {
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
        reason: _reasonController.text.trim(),
        status: PermissionStatus.pending,
        submittedAt: DateTime.now(),
      );

      await repo.submitRequest(req);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permission request submitted successfully'),
          backgroundColor: ApplyPermissionPage.primaryGreen,
        ),
      );
      context.go('/permission');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
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

  void _showEmergencyExceededDialog(balance) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.all(16),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Allowance Exceeded',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your request exceeds your normal permission allowance.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Requested: $_durationMinutes mins', style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('• Today remaining: ${balance.todayRemainingMinutes} mins', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                  const SizedBox(height: 2),
                  Text('• Month remaining: ${balance.monthlyRemainingMinutes} mins', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'If this is an emergency, you can submit an Emergency Exception Request for Admin review.',
              style: TextStyle(fontSize: 13, color: ApplyPermissionPage.darkNeutral),
            ),
          ],
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go(
                    '/permission/emergency',
                    extra: {
                      'date': _selectedDate,
                      'fromTime': _fromTime,
                      'toTime': _toTime,
                      'type': _selectedType,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Request Emergency Exception',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emp = ref.watch(currentEmployeeProvider);
    final employeeId = emp?.id ?? 1;
    final balanceAsync = ref.watch(employeePermissionBalanceProvider(employeeId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Indicator Banner
              balanceAsync.maybeWhen(
                data: (bal) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: ApplyPermissionPage.primaryGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Remaining: ${bal.todayRemainingMinutes} min",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: ApplyPermissionPage.darkNeutral,
                              ),
                            ),
                            Text(
                              "Monthly Remaining: ${bal.monthlyRemainingMinutes} min (${bal.monthlyRemainingHours.toStringAsFixed(1)} hrs)",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              // Date Selection
              const Text(
                'Date',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ApplyPermissionPage.darkNeutral),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy (EEEE)').format(_selectedDate),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ApplyPermissionPage.darkNeutral),
                      ),
                      const Icon(Icons.calendar_today, size: 18, color: ApplyPermissionPage.darkNeutral),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Permission Type Selection
              const Text(
                'Permission Type',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ApplyPermissionPage.darkNeutral),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PermissionType>(
                    value: _selectedType,
                    isExpanded: true,
                    items: PermissionType.values.map((type) {
                      return DropdownMenuItem<PermissionType>(
                        value: type,
                        child: Text(type.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedType = val;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Time Selection (From & To)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'From Time',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ApplyPermissionPage.darkNeutral),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickFromTime,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fromTime.format(context),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ApplyPermissionPage.darkNeutral),
                                ),
                                const Icon(Icons.access_time, size: 18, color: ApplyPermissionPage.darkNeutral),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'To Time',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ApplyPermissionPage.darkNeutral),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickToTime,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _toTime.format(context),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ApplyPermissionPage.darkNeutral),
                                ),
                                const Icon(Icons.access_time, size: 18, color: ApplyPermissionPage.darkNeutral),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Duration Badge Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ApplyPermissionPage.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: ApplyPermissionPage.darkNeutral, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Requested Duration: $_durationMinutes minutes',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ApplyPermissionPage.darkNeutral,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reason Text Input
              const Text(
                'Reason',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ApplyPermissionPage.darkNeutral),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter mandatory reason for permission...',
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
                    return 'Please specify reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ApplyPermissionPage.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Permission Request',
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
