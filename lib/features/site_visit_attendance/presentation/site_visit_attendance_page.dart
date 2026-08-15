import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../leave/domain/leave_request.dart';
import '../../leave/domain/leave_type.dart';
import '../../leave/providers/leave_providers.dart';
import '../../leave/presentation/my_leave_requests_page.dart';
import '../domain/site_visit_record.dart';
import '../providers/site_visit_attendance_providers.dart';
import 'site_visit_camera_page.dart';

class SiteVisitAttendancePage extends ConsumerStatefulWidget {
  const SiteVisitAttendancePage({super.key});

  @override
  ConsumerState<SiteVisitAttendancePage> createState() => _SiteVisitAttendancePageState();
}

class _SiteVisitAttendancePageState extends ConsumerState<SiteVisitAttendancePage> {
  int _activeTab = 0; // 0: Home, 1: Calendar, 2: Leave
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _showVisitForm = false;
  bool _saving = false;
  final _scrollController = ScrollController();
  final _captureCardKey = GlobalKey();

  final _siteController = TextEditingController();
  final _notesController = TextEditingController();

  String _statusFilter = 'All';
  String _requestTypeFilter = 'All';
  String _leaveTypeFilter = 'All';
  DateTime? _filterFromDate;
  DateTime? _filterToDate;

  String _formatKey(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  @override
  void dispose() {
    _scrollController.dispose();
    _siteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    if (currentEmp == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: Text('No employee profile found.')),
      );
    }

    final todayKey = _formatKey(DateTime.now());
    final selectedKey = _formatKey(_selectedDate);
    final todayVisitsAsync = ref.watch(
      siteVisitRecordsProvider((employeeId: currentEmp.id, visitDate: todayKey)),
    );
    final selectedVisitsAsync = ref.watch(
      siteVisitRecordsProvider((employeeId: currentEmp.id, visitDate: selectedKey)),
    );
    final allVisitsAsync = ref.watch(allSiteVisitRecordsProvider(null));
    final leaveAsync = ref.watch(leaveRequestsProvider(currentEmp.id));

    Widget bodyContent;
    if (_activeTab == 0) {
      bodyContent = _buildSiteVisitHomeTab(currentEmp, todayVisitsAsync, selectedVisitsAsync);
    } else if (_activeTab == 1) {
      bodyContent = leaveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
        error: (e, _) => Text('Error loading leaves: $e'),
        data: (leaveRequests) => allVisitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
          error: (e, _) => Text('Error loading site visits: $e'),
          data: (allVisits) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCalendar(leaveRequests.cast<LeaveRequest>(), allVisits),
                const SizedBox(height: 20),
                _buildSelectedDaySection(selectedVisitsAsync),
              ],
            ),
          ),
        ),
      );
    } else {
      bodyContent = _buildLeaveTab(currentEmp, leaveAsync);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        bottom: true,
        child: bodyContent,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: BottomNavigationBar(
          currentIndex: _activeTab,
          onTap: (index) => setState(() => _activeTab = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF9CC70A),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note),
              label: 'Leave',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteVisitHomeTab(
    Employee currentEmp,
    AsyncValue<List<SiteVisitRecord>> todayVisitsAsync,
    AsyncValue<List<SiteVisitRecord>> selectedVisitsAsync,
  ) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9CC70A).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF414A51)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Site Visit Attendance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTodayOverviewCard(currentEmp, todayVisitsAsync),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _showVisitForm ? _buildCaptureCard(currentEmp) : const SizedBox.shrink(),
          ),
          if (_showVisitForm) const SizedBox(height: 20),
          _buildSelectedDaySection(selectedVisitsAsync),
        ],
      ),
    );
  }

  Widget _buildTodayOverviewCard(Employee employee, AsyncValue<List<SiteVisitRecord>> todayVisitsAsync) {
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(today);

    return todayVisitsAsync.when(
      loading: () => _cardShell(const Center(child: CircularProgressIndicator())),
      error: (e, _) => _cardShell(Text('Error loading today\'s site visits: $e')),
      data: (visits) {
        final statusText = visits.isEmpty
            ? 'No site visit logged yet'
            : 'At ${visits.last.siteName} since ${visits.last.visitTime}';
        final visitCountLabel = visits.isEmpty ? '0 sites today' : '${visits.length} sites today';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.active, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Site Visit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          dateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildCountChip(visitCountLabel),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: const Color(0xFF414A51),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _openCaptureForm,
                  icon: const Icon(Icons.fingerprint, size: 22),
                  label: const Text(
                    'Capture attendance',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF414A51),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    _openCheckoutAndSave(employee);
                  },
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text(
                    'Check Out for the day',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tooltip: capture the image to take attendance.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _confirmRemoveAttendance(visits),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(
                    'Remove attendance',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCaptureCard(Employee employee) {
    return Container(
      key: _captureCardKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera_outlined, color: AppColors.active),
              const SizedBox(width: 8),
              const Text(
                'Site Visit Form',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _showVisitForm = false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _siteController,
            decoration: const InputDecoration(
              labelText: 'Site name',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.active,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving ? null : () => _openCameraAndSave(employee),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_saving ? 'Saving...' : 'Open Camera'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(List<LeaveRequest> leaveRequests, List<SiteVisitRecord> allVisits) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final totalGridCells = ((startWeekday + daysInMonth) / 7).ceil() * 7;
    final todayKey = _formatKey(DateTime.now());
    final leaveDates = <String>{};
    for (final leave in leaveRequests) {
      final start = _parseDateKey(leave.fromDate);
      final end = _parseDateKey(leave.toDate);
      if (start == null || end == null) continue;
      var cursor = DateTime(start.year, start.month, start.day);
      final last = DateTime(end.year, end.month, end.day);
      while (!cursor.isAfter(last)) {
        leaveDates.add(_formatKey(cursor));
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    final visitsByDate = <String, List<SiteVisitRecord>>{};
    for (final visit in allVisits) {
      visitsByDate.putIfAbsent(visit.visitDate, () => []).add(visit);
    }
    for (final list in visitsByDate.values) {
      list.sort((a, b) => a.visitTime.compareTo(b.visitTime));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _focusedMonth = DateTime(year, month - 1, 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_focusedMonth),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _focusedMonth = DateTime(year, month + 1, 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalGridCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - startWeekday + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(year, month, dayNumber);
              final key = _formatKey(date);
              final isToday = key == todayKey;
              final isLeave = leaveDates.contains(key);
              final visitCount = visitsByDate[key]?.length ?? 0;
              final record = visitsByDate[key]?.isNotEmpty == true ? visitsByDate[key]!.last : null;

              Color? bg;
              if (isLeave) {
                bg = const Color(0xFFE53935);
              } else if (visitCount > 0) {
                bg = visitCount > 1 ? const Color(0xFF414A51) : const Color(0xFF2E7D32);
              } else if (isToday) {
                bg = const Color(0xFFD6ECFF);
              }

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && bg == null
                        ? Border.all(color: AppColors.active, width: 1.5)
                        : isLeave
                            ? Border.all(color: const Color(0xFFE53935), width: 1.2)
                            : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isLeave || visitCount > 0 || isToday ? FontWeight.bold : FontWeight.w500,
                            color: visitCount > 0 || isLeave ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      if (visitCount > 0)
                        Positioned(
                          right: 3,
                          bottom: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$visitCount',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: bg == const Color(0xFF414A51) ? const Color(0xFF414A51) : const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                _legend(const Color(0xFFD6ECFF), 'Today'),
                _legend(const Color(0xFFE53935), 'Leave'),
                _legend(const Color(0xFF2E7D32), 'Present'),
                _legend(const Color(0xFF414A51), 'Late'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDaySection(AsyncValue<List<SiteVisitRecord>> selectedVisitsAsync) {
    final title = DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate);
    final isToday = _formatKey(_selectedDate) == _formatKey(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Day Records',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isToday ? 'Today' : DateFormat('dd MMM yyyy').format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF414A51)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        selectedVisitsAsync.when(
          loading: () => _cardShell(const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A)))),
          error: (e, _) => _cardShell(Text('Error loading visits: $e')),
          data: (visits) {
            if (visits.isEmpty) {
              return _cardShell(
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('No site visit records for this day.', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                ),
              );
            }
            return Column(children: visits.map((visit) => _buildVisitTile(visit)).toList());
          },
        ),
      ],
    );
  }

  Widget _buildVisitTile(SiteVisitRecord visit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56,
              height: 56,
              color: const Color(0xFFF1F5F9),
              child: visit.photoUrl.isEmpty
                  ? const Icon(Icons.image_outlined, color: AppColors.textSecondary)
                  : Image.network(visit.photoUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.siteName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  visit.notes.isEmpty ? 'No notes added' : visit.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      visit.visitTime,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCaptureForm() {
    setState(() => _showVisitForm = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _captureCardKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      } else {
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _cardShell(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCountChip(String label) {
    final color = AppColors.active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Future<void> _confirmRemoveAttendance(List<SiteVisitRecord> visits) async {
    if (visits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance record to remove.')),
      );
      return;
    }

    final record = visits.last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove attendance?'),
        content: Text('Delete the latest entry for ${record.siteName} at ${record.visitTime}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(siteVisitAttendanceRepositoryProvider).deleteVisit(record.id);
    ref.invalidate(allSiteVisitRecordsProvider(null));
    ref.invalidate(siteVisitRecordsProvider((employeeId: record.employeeId, visitDate: record.visitDate)));
    ref.invalidate(siteVisitRecordsProvider((employeeId: ref.read(currentEmployeeProvider)!.id, visitDate: _formatKey(DateTime.now()))));
    ref.invalidate(siteVisitRecordsProvider((employeeId: ref.read(currentEmployeeProvider)!.id, visitDate: _formatKey(_selectedDate))));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance removed.')),
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      );

  int _roughHoursBetween(String start, String end) {
    int minutes(String value) {
      final parsed = DateFormat('hh:mm a').parse(value);
      return parsed.hour * 60 + parsed.minute;
    }

    final diff = minutes(end) - minutes(start);
    return diff < 0 ? 0 : diff ~/ 60;
  }

  DateTime? _parseDateKey(String value) {
    if (value.isEmpty) return null;
    try {
      final isoDate = DateTime.tryParse(value);
      if (isoDate != null) return isoDate;
      final parts = value.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openCameraAndSave(Employee employee) async {
    final siteName = _siteController.text.trim();
    if (siteName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a site name before opening the camera.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        throw Exception('Camera permission is required to capture a site visit photo.');
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera is available on this device.');
      }

      final pickedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => SiteVisitCameraPage(camera: cameras.first)),
      );
      if (pickedPath == null || pickedPath.isEmpty) {
        throw Exception('Camera was closed without taking a photo.');
      }

      final position = await _getCurrentLocationWithPermissionPrompt();
      final now = DateTime.now();
      final visitDate = DateFormat('dd-MM-yyyy').format(now);
      final visitTime = DateFormat('hh:mm a').format(now);
      final repo = ref.read(siteVisitAttendanceRepositoryProvider);
      final stampedAsset = await repo.createVisitPhotoUrl(
        localImagePath: pickedPath,
        employeeName: employee.fullName,
        siteName: siteName,
        visitDate: visitDate,
        visitTime: visitTime,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await repo.saveVisit(
        SiteVisitRecord(
          id: 0,
          employeeId: employee.id,
          employeeName: employee.fullName,
          siteName: siteName,
          visitDate: visitDate,
          visitTime: visitTime,
          photoUrl: stampedAsset.url,
          photoPublicId: stampedAsset.publicId,
          latitude: position.latitude,
          longitude: position.longitude,
          address: '',
          notes: _notesController.text.trim(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      ref.invalidate(siteVisitRecordsProvider((employeeId: employee.id, visitDate: _formatKey(DateTime.now()))));
      ref.invalidate(siteVisitRecordsProvider((employeeId: employee.id, visitDate: _formatKey(_selectedDate))));
      ref.invalidate(allSiteVisitRecordsProvider(null));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site visit saved successfully.')),
        );
        setState(() {
          _saving = false;
          _showVisitForm = false;
          _siteController.clear();
          _notesController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openCheckoutAndSave(Employee employee) async {
    setState(() => _saving = true);
    try {
      final position = await _getCurrentLocationWithPermissionPrompt();
      final now = DateTime.now();
      final visitDate = DateFormat('dd-MM-yyyy').format(now);
      final visitTime = DateFormat('hh:mm a').format(now);
      final repo = ref.read(siteVisitAttendanceRepositoryProvider);

      await repo.saveDayCheckout(
        employeeId: employee.id,
        employeeName: employee.fullName,
        visitDate: visitDate,
        visitTime: visitTime,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      ref.invalidate(siteVisitRecordsProvider((employeeId: employee.id, visitDate: _formatKey(DateTime.now()))));
      ref.invalidate(siteVisitRecordsProvider((employeeId: employee.id, visitDate: _formatKey(_selectedDate))));
      ref.invalidate(allSiteVisitRecordsProvider(null));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day checkout saved successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Position> _getCurrentLocationWithPermissionPrompt() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are turned off. Please enable location from your phone settings and try again.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission is denied. Please allow location access when the phone prompt appears.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Open system settings and allow location access for this app.',
      );
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // ==========================================
  // TAB 2: LEAVE TAB FOR SITE VISIT ATTENDANCE
  // ==========================================
  Widget _buildLeaveTab(Employee currentEmp, AsyncValue<List<LeaveRequest>> userLeaveRequestsAsync) {
    return userLeaveRequestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
      error: (e, _) => Center(child: Text('Error loading leave requests: $e')),
      data: (requests) {
        final filteredRequests = _getFilteredRequests(requests);
        final totalRequests = requests.length;
        final pendingCount = requests.where((r) => r.status == 'Pending').length;
        final approvedCount = requests.where((r) => r.status == 'Approved').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildLeaveStatCard(
                      'Total Requests',
                      '$totalRequests',
                      Icons.folder_outlined,
                      const Color(0xFF0288D1),
                      const Color(0xFFE1F5FE),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLeaveStatCard(
                      'Pending Requests',
                      '$pendingCount',
                      Icons.hourglass_top_outlined,
                      const Color(0xFFE65100),
                      const Color(0xFFFFF3E0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildLeaveStatCard(
                      'Approved Leaves',
                      '$approvedCount',
                      Icons.check_circle_outline,
                      const Color(0xFF2E7D32),
                      const Color(0xFFE8F5E9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Leave Requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF414A51),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (context) => MyLeaveRequestsPage(currentEmp: currentEmp),
                          ),
                        ),
                        icon: const Icon(Icons.list_alt, size: 16, color: Color(0xFF414A51)),
                        label: const Text(
                          'My Requests',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9CC70A),
                          foregroundColor: const Color(0xFF414A51),
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showApplyLeaveDialog(currentEmp),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Apply Leave',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          isDense: true,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                          items: ['All', 'Pending', 'Approved', 'Denied', 'Cancelled'].map((st) {
                            return DropdownMenuItem(
                              value: st,
                              child: Text(st == 'All' ? 'All Status' : st),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _statusFilter = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF414A51),
                        side: BorderSide(
                          color: (_filterFromDate != null || _filterToDate != null)
                              ? const Color(0xFF9CC70A)
                              : const Color(0xFFCBD5E1),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: _showDateFilterBottomSheet,
                      icon: const Icon(Icons.calendar_today_outlined, size: 14),
                      label: Text(
                        (_filterFromDate != null || _filterToDate != null)
                            ? 'Date Filter Active'
                            : 'Date',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF414A51),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: _showAdvancedFiltersBottomSheet,
                      icon: const Icon(Icons.tune_outlined, size: 14),
                      label: const Text('Filters', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filteredRequests.length} requests',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  if (_statusFilter != 'All' || _requestTypeFilter != 'All' || _leaveTypeFilter != 'All' || _filterFromDate != null || _filterToDate != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _statusFilter = 'All';
                          _requestTypeFilter = 'All';
                          _leaveTypeFilter = 'All';
                          _filterFromDate = null;
                          _filterToDate = null;
                        });
                      },
                      child: const Text(
                        'Reset Filters',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0288D1)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              if (filteredRequests.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('No leave requests match your criteria.', style: TextStyle(color: Color(0xFF64748B))),
                    ],
                  ),
                )
              else
                Column(
                  children: filteredRequests.map((req) => _buildLeaveActivityCard(req, currentEmp)).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  List<LeaveRequest> _getFilteredRequests(List<LeaveRequest> requests) {
    return requests.where((req) {
      if (_statusFilter != 'All' && req.status.toLowerCase() != _statusFilter.toLowerCase()) {
        return false;
      }
      final isPerm = req.leaveType.toLowerCase().startsWith('permission');
      if (_requestTypeFilter == 'Leave' && isPerm) return false;
      if (_requestTypeFilter == 'Permission' && !isPerm) return false;
      if (_leaveTypeFilter != 'All' && !req.leaveType.toLowerCase().contains(_leaveTypeFilter.toLowerCase())) {
        return false;
      }
      if (_filterFromDate != null || _filterToDate != null) {
        final reqFrom = _parseDateKey(req.fromDate);
        final reqTo = _parseDateKey(req.toDate) ?? reqFrom;
        if (reqFrom != null && reqTo != null) {
          if (_filterFromDate != null && reqTo.isBefore(_filterFromDate!)) return false;
          if (_filterToDate != null && reqFrom.isAfter(_filterToDate!)) return false;
        }
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFE65100);
      case 'denied':
      case 'rejected':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF414A51);
    }
  }

  String _formatDateStr(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final isoDate = DateTime.tryParse(dateStr);
      if (isoDate != null) return DateFormat('dd MMM yyyy').format(isoDate);
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return DateFormat('dd MMM yyyy').format(DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])));
        } else {
          return DateFormat('dd MMM yyyy').format(DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])));
        }
      }
    } catch (_) {}
    return dateStr;
  }

  String _formatDurationDisplay(LeaveRequest req) {
    if (req.leaveType.toLowerCase().startsWith('permission')) {
      if (req.leaveType.contains('(') && req.leaveType.contains(')')) {
        final timePart = req.leaveType.substring(req.leaveType.indexOf('(') + 1, req.leaveType.indexOf(')'));
        return 'Permission ($timePart)';
      }
      final hours = req.numDays * 8.0;
      if (hours > 0) {
        final h = hours.floor();
        final m = ((hours - h) * 60).round();
        if (h > 0 && m > 0) return '$h Hr $m Mins';
        if (h > 0) return '$h Hour${h > 1 ? 's' : ''}';
        return '$m Mins';
      }
      return 'Permission';
    }
    final isWhole = (req.numDays == req.numDays.roundToDouble());
    final daysStr = isWhole ? req.numDays.toInt().toString() : req.numDays.toStringAsFixed(1);
    return '$daysStr Day${req.numDays == 1.0 ? '' : 's'}';
  }

  Widget _buildLeaveStatCard(String title, String countStr, IconData icon, Color iconColor, Color iconBg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(countStr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildLeaveActivityCard(LeaveRequest req, Employee currentEmp) {
    final isPending = req.status.toLowerCase() == 'pending';
    final statusColor = _getStatusColor(req.status);
    final isPermission = req.leaveType.toLowerCase().startsWith('permission');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPermission
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                      : const Color(0xFF9CC70A).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPermission ? Icons.access_time : Icons.event_note,
                  size: 18,
                  color: isPermission ? const Color(0xFF2563EB) : const Color(0xFF414A51),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.leaveType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Submitted: ${_formatDateStr(req.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      req.status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (isPending)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0288D1)),
                      tooltip: 'Edit Request',
                      onPressed: () => _showApplyLeaveDialog(currentEmp, existingRequest: req),
                    )
                  else
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                      tooltip: 'View Details',
                      onPressed: () => _showViewLeaveDialog(req),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_formatDateStr(req.fromDate)} → ${_formatDateStr(req.toDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDurationDisplay(req),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isPermission ? const Color(0xFF2563EB) : const Color(0xFF9CC70A),
                ),
              ),
            ],
          ),
          if (req.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${req.reason}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _showViewLeaveDialog(LeaveRequest req) {
    final statusColor = _getStatusColor(req.status);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  req.leaveType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  req.status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Submitted On', _formatDateStr(req.createdAt)),
                  const SizedBox(height: 12),
                  _detailRow('Date Range', '${_formatDateStr(req.fromDate)} → ${_formatDateStr(req.toDate)}'),
                  const SizedBox(height: 12),
                  _detailRow('Duration', _formatDurationDisplay(req)),
                  const SizedBox(height: 12),
                  _detailRow('Reason', req.reason.isNotEmpty ? req.reason : 'N/A'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      ],
    );
  }

  void _showDateFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter by Date',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9CC70A),
                            foregroundColor: const Color(0xFF414A51),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(sheetCtx);
                          },
                          child: const Text('Apply Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAdvancedFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: const Color(0xFF414A51),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(sheetCtx);
                    },
                    child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showApplyLeaveDialog(Employee currentEmp, {LeaveRequest? existingRequest}) {
    final isEditing = existingRequest != null;
    final reasonController = TextEditingController(text: isEditing ? existingRequest.reason : '');
    final leaveTypesAsync = ref.read(leaveTypesProvider);
    LeaveType? selectedType;
    if (isEditing) {
      leaveTypesAsync.whenData((types) {
        selectedType = types.where((t) => t.name == existingRequest.leaveType).firstOrNull;
      });
    }

    DateTime fromDate = isEditing
        ? (_parseDateKey(existingRequest.fromDate) ?? DateTime.now())
        : DateTime.now();
    DateTime toDate = isEditing
        ? (_parseDateKey(existingRequest.toDate) ?? DateTime.now())
        : DateTime.now();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isEditing ? 'Edit Leave Request' : 'Apply for Leave',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      leaveTypesAsync.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (e, _) => Text('Error loading leave types: $e'),
                        data: (types) => DropdownButtonFormField<LeaveType>(
                          value: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Leave Type',
                            border: OutlineInputBorder(),
                          ),
                          items: types.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                          onChanged: (val) => setDialogState(() => selectedType = val),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: const Color(0xFF414A51),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          if (selectedType == null) return;
                          setDialogState(() => submitting = true);
                          final repo = ref.read(leaveRepositoryProvider);
                          final nowStr = DateTime.now().toIso8601String();
                          final fromStr = DateFormat('yyyy-MM-dd').format(fromDate);
                          final toStr = DateFormat('yyyy-MM-dd').format(toDate);

                          if (isEditing) {
                            final updated = LeaveRequest(
                              id: existingRequest.id,
                              employeeId: currentEmp.id,
                              employeeName: currentEmp.fullName,
                              employeeCustomId: currentEmp.employeeId,
                              leaveType: selectedType!.name,
                              fromDate: fromStr,
                              toDate: toStr,
                              reason: reasonController.text.trim(),
                              status: 'Pending',
                              createdAt: existingRequest.createdAt,
                              numDays: toDate.difference(fromDate).inDays + 1.0,
                            );
                            await repo.updateLeaveRequest(updated);
                          } else {
                            final newReq = LeaveRequest(
                              id: 0,
                              employeeId: currentEmp.id,
                              employeeName: currentEmp.fullName,
                              employeeCustomId: currentEmp.employeeId,
                              leaveType: selectedType!.name,
                              fromDate: fromStr,
                              toDate: toStr,
                              reason: reasonController.text.trim(),
                              status: 'Pending',
                              createdAt: nowStr,
                              numDays: toDate.difference(fromDate).inDays + 1.0,
                            );
                            await repo.submitLeaveRequest(newReq);
                          }

                          ref.invalidate(leaveRequestsProvider(currentEmp.id));
                          if (mounted) Navigator.pop(dialogCtx);
                        },
                  child: Text(submitting ? 'Submitting...' : (isEditing ? 'Update' : 'Submit')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}



