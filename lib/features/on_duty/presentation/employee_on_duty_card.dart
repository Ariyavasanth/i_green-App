import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/on_duty_assignment.dart';
import '../providers/on_duty_providers.dart';

class EmployeeOnDutyCard extends ConsumerStatefulWidget {
  const EmployeeOnDutyCard({
    super.key,
    required this.assignment,
    this.onCheckoutRequested,
  });

  final OnDutyAssignment assignment;
  final VoidCallback? onCheckoutRequested;

  @override
  ConsumerState<EmployeeOnDutyCard> createState() => _EmployeeOnDutyCardState();
}

class _EmployeeOnDutyCardState extends ConsumerState<EmployeeOnDutyCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String? _capturedPhotoPath;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.assignment.status.toLowerCase() == 'active') {
      _startLiveTimer();
    }
  }

  @override
  void didUpdateWidget(covariant EmployeeOnDutyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assignment.status.toLowerCase() == 'active' && _timer == null) {
      _startLiveTimer();
    } else if (widget.assignment.status.toLowerCase() != 'active') {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLiveTimer() {
    _timer?.cancel();
    DateTime? startTime;
    if (widget.assignment.startedTime != null && widget.assignment.startedTime!.isNotEmpty) {
      try {
        final parsed = DateFormat('hh:mm a').parse(widget.assignment.startedTime!);
        final now = DateTime.now();
        startTime = DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
      } catch (_) {}
    }
    startTime ??= DateTime.now();

    _elapsed = DateTime.now().difference(startTime);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(startTime!);
        });
      }
    });
  }

  String _formatTimerDisplay(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatDurationSummary(int durationMinutes) {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.assignment.status.toLowerCase();

    if (status == 'assigned') {
      return _buildScreenAAssigned();
    } else if (status == 'active') {
      return _buildScreenBInProgress();
    } else if (status == 'completed') {
      if (widget.assignment.allowCheckoutFromDestination) {
        return _buildScreenCOutcome2AllowCheckout();
      } else {
        return _buildScreenCOutcome1ReturnToShift();
      }
    }

    return const SizedBox.shrink();
  }

  // ==========================================
  // Screen A: Notification & Task Banner (When Assigned)
  // ==========================================
  Widget _buildScreenAAssigned() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.directions_bus_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  '🔵 ON-DUTY ASSIGNED',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Banner Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetaRow(Icons.location_on_outlined, 'Destination', widget.assignment.destination, isBold: true),
                const SizedBox(height: 8),
                _buildMetaRow(Icons.assignment_outlined, 'Task', widget.assignment.task),
                const SizedBox(height: 8),
                _buildMetaRow(Icons.person_outline, 'Assigned By', widget.assignment.assignedBy),
                const SizedBox(height: 16),

                // Start Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActionLoading ? null : _handleStartOnDuty,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: _isActionLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      '▶ START ON-DUTY',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Screen B: Active On-Duty (Travel & Work in Progress)
  // ==========================================
  Widget _buildScreenBInProgress() {
    const darkTextColor = Color(0xFF414A51);
    final hasPhoto = _capturedPhotoPath != null && _capturedPhotoPath!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFD97706),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '🟡 ON-DUTY IN PROGRESS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatTimerDisplay(_elapsed),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Banner Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Started at: ${widget.assignment.startedTime ?? "Just now"} (Timer: ${_formatTimerDisplay(_elapsed)})',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _buildMetaRow(Icons.assignment_outlined, 'Task', widget.assignment.task, isBold: true),
                const SizedBox(height: 16),

                // Proof of Completion Camera Box
                const Text(
                  'Proof of Completion *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: darkTextColor),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _takePhotoProof,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: hasPhoto ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasPhoto ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasPhoto ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                          size: 28,
                          color: hasPhoto ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasPhoto ? 'Photo Proof Attached ✓' : '[ 📷 Take Photo Proof ]',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: hasPhoto ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Complete On-Duty Button (Disabled until photo proof is captured)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (hasPhoto && !_isActionLoading) ? _handleCompleteOnDuty : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: hasPhoto ? 2 : 0,
                    ),
                    icon: _isActionLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      hasPhoto ? '[ ✓ COMPLETE ON-DUTY ]' : '[ ✓ COMPLETE ON-DUTY ] (Photo Required)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Screen C — Outcome 1: "Return & Continue Shift"
  // ==========================================
  Widget _buildScreenCOutcome1ReturnToShift() {
    final durationMin = widget.assignment.durationMinutes > 0
        ? widget.assignment.durationMinutes
        : _elapsed.inMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🟢 On-Duty Complete! (${_formatDurationSummary(durationMin)} recorded)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please return to ${widget.assignment.fromLocation} site and continue your shift.',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF166534)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Screen C — Outcome 2: "Allow Checkout from Destination"
  // ==========================================
  Widget _buildScreenCOutcome2AllowCheckout() {
    final durationMin = widget.assignment.durationMinutes > 0
        ? widget.assignment.durationMinutes
        : _elapsed.inMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.task_alt_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  '🟢 On-Duty Completed',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Banner Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Task Duration: ${_formatDurationSummary(durationMin)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text(
                          'Photo Proof: Uploaded ✓',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Text(
                    'You are authorized to end your shift from this destination.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                  ),
                ),
                const SizedBox(height: 16),

                // Direct Checkout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onCheckoutRequested,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 20),
                    label: const Text(
                      '🛑 CHECK OUT NOW',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              color: const Color(0xFF1E293B),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _takePhotoProof() {
    setState(() {
      _capturedPhotoPath = 'simulated_camera_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📷 Photo proof captured successfully!'),
        backgroundColor: Color(0xFF2E7D32),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleStartOnDuty() async {
    setState(() => _isActionLoading = true);
    try {
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final repo = ref.read(onDutyRepositoryProvider);
      await repo.updateAssignmentStatus(
        id: widget.assignment.id,
        status: 'active',
        startedTime: nowStr,
      );

      ref.invalidate(activeOnDutyAssignmentProvider(widget.assignment.employeeId));
      ref.invalidate(allOnDutyAssignmentsProvider);
      _startLiveTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start on-duty: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleCompleteOnDuty() async {
    if (_capturedPhotoPath == null || _capturedPhotoPath!.isEmpty) return;

    setState(() => _isActionLoading = true);
    try {
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      final repo = ref.read(onDutyRepositoryProvider);
      final durationMins = _elapsed.inMinutes > 0 ? _elapsed.inMinutes : 60;

      final updated = widget.assignment.copyWith(
        status: 'completed',
        completedTime: nowStr,
        durationMinutes: durationMins,
        photoProofPath: _capturedPhotoPath,
      );

      await repo.updateAssignment(updated);

      ref.invalidate(activeOnDutyAssignmentProvider(widget.assignment.employeeId));
      ref.invalidate(allOnDutyAssignmentsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete on-duty: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }
}
