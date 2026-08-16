import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/clock_entry.dart';
import '../providers/clocking_providers.dart';
import 'clock_action_widget.dart';

class ClockingTimelineView extends ConsumerStatefulWidget {
  const ClockingTimelineView({
    super.key,
    this.employeeId = 'EMP-001',
    this.embedded = false,
  });

  final String employeeId;
  final bool embedded;

  @override
  ConsumerState<ClockingTimelineView> createState() => _ClockingTimelineViewState();
}

class _ClockingTimelineViewState extends ConsumerState<ClockingTimelineView> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    const secondaryColor = Color(0xFF414A51);

    final entriesAsync = ref.watch(
      clockEntriesProvider((employeeId: widget.employeeId, date: _selectedDate)),
    );
    final workHoursAsync = ref.watch(
      totalWorkHoursProvider((employeeId: widget.employeeId, date: _selectedDate)),
    );
    final breakHoursAsync = ref.watch(
      totalBreakHoursProvider((employeeId: widget.employeeId, date: _selectedDate)),
    );

    final workHours = workHoursAsync.valueOrNull ?? 0.0;
    final breakHours = breakHoursAsync.valueOrNull ?? 0.0;
    final totalLogHours = workHours + breakHours;
    final isPresentQualified = workHours >= 8.0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClockActionWidget(
          employeeId: widget.employeeId,
          onClockChanged: () {
            ref.invalidate(clockEntriesProvider);
            ref.invalidate(totalWorkHoursProvider);
            ref.invalidate(totalBreakHoursProvider);
          },
        ),
        const SizedBox(height: 16),
        // Daily Summary Card with Utilization Progress
        _buildSummaryCard(
          context,
          workHours,
          breakHours,
          totalLogHours,
          isPresentQualified,
          primaryColor,
          secondaryColor,
        ),
        const SizedBox(height: 16),
        // Timeline Header and Logs
        _buildTimelineSection(context, entriesAsync, primaryColor, secondaryColor),
      ],
    );

    if (widget.embedded) {
      return SizedBox(
        height: 600,
        child: SingleChildScrollView(child: content),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: content,
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    double workHours,
    double breakHours,
    double totalLogHours,
    bool isPresentQualified,
    Color primaryColor,
    Color secondaryColor,
  ) {
    final targetHours = 8.0;
    final workProgress = (workHours / targetHours).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPresentQualified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPresentQualified ? const Color(0xFF81C784) : const Color(0xFFFFB74D),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPresentQualified ? Icons.check_circle : Icons.warning_amber_rounded,
                      size: 14,
                      color: isPresentQualified ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPresentQualified ? 'Attendance Verified: Present (≥8 hrs)' : 'Short Hours (<8 hrs)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPresentQualified ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${workHours.toStringAsFixed(1)} hrs',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    const Text('Productive Work', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${breakHours.toStringAsFixed(1)} hrs',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: secondaryColor),
                    ),
                    const Text('Breaks (Lunch / Tea)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${totalLogHours.toStringAsFixed(1)} hrs',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const Text('Total Logged Time', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: workProgress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(
    BuildContext context,
    AsyncValue<List<ClockEntry>> entriesAsync,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Activity Log & Timeline',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),
          entriesAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No clock entries recorded for this date.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final isBreak = entry.isBreak;
                  final color = isBreak ? secondaryColor : primaryColor;
                  final icon = isBreak ? Icons.coffee_outlined : Icons.work_outline;

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.entryType,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '${DateFormat('HH:mm').format(entry.startTime)} - ${entry.endTime != null ? DateFormat('HH:mm').format(entry.endTime!) : 'Active'}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${entry.durationInHours.toStringAsFixed(1)} hrs',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading clock entries: $err'),
          ),
        ],
      ),
    );
  }
}
