import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/clock_entry.dart';
import '../providers/clocking_providers.dart';
import '../../attendance/providers/attendance_providers.dart';

class ClockActionWidget extends ConsumerWidget {
  const ClockActionWidget({
    super.key,
    this.employeeId = 'EMP-001',
    this.onClockChanged,
  });

  final String employeeId;
  final VoidCallback? onClockChanged;

  Future<void> _startActivity(BuildContext context, WidgetRef ref, String type, {String? notes}) async {
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final empIdStr = employeeId == 'EMP-0001' ? 'EMP-001' : employeeId;
    final digits = empIdStr.replaceAll(RegExp(r'[^0-9]'), '');
    final empIdInt = int.tryParse(digits) ?? 1;
    final attendanceRecord = await attendanceRepo.getAttendanceRecordForDate(empIdInt, today);

    if (attendanceRecord == null || attendanceRecord.effectiveCheckInTime.trim().isEmpty) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Check In Required',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: const Text(
              'You need to check in before starting any clocking activity.',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (attendanceRecord.status == 'Absent') {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Attendance Marked Absent',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Your attendance status is marked Absent for today because check-in exceeded the late limit cutoff. You cannot start clocking activities.',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (attendanceRecord.checkOutTime.trim().isNotEmpty || attendanceRecord.status == 'Checked Out') {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Already Checked Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: const Text(
              'You have already checked out for today. You cannot start a clocking activity after checking out.',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    final repo = ref.read(clockingRepositoryProvider);
    final entry = ClockEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      employeeId: employeeId,
      entryType: type,
      startTime: DateTime.now(),
      notes: notes,
    );

    await repo.startClockEntry(entry);
    ref.invalidate(activeClockEntryProvider);
    ref.invalidate(clockEntriesProvider);
    ref.invalidate(totalWorkHoursProvider);
    ref.invalidate(totalBreakHoursProvider);

    if (onClockChanged != null) onClockChanged!();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Started: $type'),
          backgroundColor: const Color(0xFF9CC70A),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clockOut(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(clockingRepositoryProvider);
    await repo.clockOutActiveEntry(employeeId);

    ref.invalidate(activeClockEntryProvider);
    ref.invalidate(clockEntriesProvider);
    ref.invalidate(totalWorkHoursProvider);
    ref.invalidate(totalBreakHoursProvider);

    if (onClockChanged != null) onClockChanged!();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clocked out successfully'),
          backgroundColor: Color(0xFF414A51),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryColor = Color(0xFF9CC70A);
    const secondaryColor = Color(0xFF414A51);

    final activeEntryAsync = ref.watch(activeClockEntryProvider(employeeId));
    final activeEntry = activeEntryAsync.valueOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: activeEntry != null ? primaryColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  activeEntry != null ? Icons.play_circle_fill : Icons.pause_circle_filled,
                  color: activeEntry != null ? primaryColor : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeEntry == null ? 'Currently Idle' : 'Active: ${activeEntry.entryType}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    activeEntry == null ? 'Select an action to begin clocking' : 'Started at ${_formatTime(activeEntry.startTime)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              if (activeEntry == null || activeEntry.isBreak)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _startActivity(context, ref, 'WORK'),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text(activeEntry == null ? '⏱️ Start Work' : 'Resume Work'),
                ),
              if (activeEntry != null && !activeEntry.isBreak) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: secondaryColor,
                    side: const BorderSide(color: secondaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _startActivity(context, ref, 'LUNCH_BREAK'),
                  icon: const Icon(Icons.restaurant, size: 16),
                  label: const Text('☕ Lunch Break'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: secondaryColor,
                    side: const BorderSide(color: secondaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _startActivity(context, ref, 'TEA_BREAK'),
                  icon: const Icon(Icons.coffee, size: 16),
                  label: const Text('Tea Break'),
                ),
              ],
              if (activeEntry != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _clockOut(context, ref),
                  icon: const Icon(Icons.stop, size: 16),
                  label: const Text('Clock Out'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
