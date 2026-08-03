import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../leave/domain/leave_request.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/site_visit_record.dart';
import '../providers/site_visit_attendance_providers.dart';
import 'site_visit_camera_page.dart';

class SiteVisitAttendancePage extends ConsumerStatefulWidget {
  const SiteVisitAttendancePage({super.key});

  @override
  ConsumerState<SiteVisitAttendancePage> createState() => _SiteVisitAttendancePageState();
}

class _SiteVisitAttendancePageState extends ConsumerState<SiteVisitAttendancePage> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _showVisitForm = false;
  bool _saving = false;

  final _siteController = TextEditingController();
  final _notesController = TextEditingController();

  String _formatKey(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  @override
  void dispose() {
    _siteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    if (currentEmp == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFEFF3F6),
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

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 24, color: AppColors.active),
                  SizedBox(width: 8),
                  Text(
                    'Site Visit Attendance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTodayOverviewCard(todayVisitsAsync),
              const SizedBox(height: 20),
              leaveAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading leaves: $e'),
                data: (leaveRequests) => allVisitsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error loading site visits: $e'),
                  data: (allVisits) => _buildCalendar(
                    leaveRequests.cast<LeaveRequest>(),
                    allVisits,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildSelectedDaySection(selectedVisitsAsync),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showVisitForm ? _buildCaptureCard(currentEmp) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayOverviewCard(AsyncValue<List<SiteVisitRecord>> todayVisitsAsync) {
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(today);

    return todayVisitsAsync.when(
      loading: () => _cardShell(const Center(child: CircularProgressIndicator())),
      error: (e, _) => _cardShell(Text('Error loading today\'s site visits: $e')),
      data: (visits) {
        final firstVisit = visits.isNotEmpty ? visits.first : null;
        final lastVisit = visits.isNotEmpty ? visits.last : null;
        final hasCheckIn = visits.isNotEmpty;
        final hasCheckOut = visits.length > 1;
        final workHours = hasCheckIn && hasCheckOut ? _roughHoursBetween(firstVisit!.visitTime, lastVisit!.visitTime) : null;

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
                  _buildStatusChip(visits),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _showVisitForm = true),
                  icon: const Icon(Icons.fingerprint, size: 22),
                  label: const Text(
                    'Check In Attendance',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactStatChip(
                      icon: Icons.login,
                      iconColor: const Color(0xFF2E7D32),
                      label: 'Check In',
                      value: hasCheckIn ? firstVisit!.visitTime : '--:--',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactStatChip(
                      icon: Icons.logout,
                      iconColor: const Color(0xFFC62828),
                      label: 'Check Out',
                      value: hasCheckOut ? lastVisit!.visitTime : '--:--',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactStatChip(
                      icon: Icons.timelapse,
                      iconColor: AppColors.active,
                      label: 'Work Hrs',
                      value: workHours != null ? '${workHours.toStringAsFixed(1)} hrs' : '--',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCaptureCard(Employee employee) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selected Day Visits',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        selectedVisitsAsync.when(
          loading: () => _cardShell(const Center(child: CircularProgressIndicator())),
          error: (e, _) => _cardShell(Text('Error loading visits: $e')),
          data: (visits) {
            if (visits.isEmpty) {
              return _cardShell(const Center(child: Text('No visits for this day')));
            }
            return Column(children: visits.map(_buildVisitTile).toList());
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

  Widget _buildCompactStatChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(List<SiteVisitRecord> visits) {
    final label = visits.isEmpty
        ? 'Not Marked'
        : visits.length == 1
            ? 'Checked In'
            : 'Checked Out';
    final color = visits.isEmpty
        ? Colors.grey
        : visits.length == 1
            ? const Color(0xFF2E7D32)
            : const Color(0xFF414A51);

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
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
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
      final stampedPath = await repo.createVisitPhotoUrl(
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
          photoUrl: stampedPath,
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
}
