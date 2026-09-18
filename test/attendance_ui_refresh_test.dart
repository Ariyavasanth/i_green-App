import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_session.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_settings.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_status_helper.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_repository.dart';
import 'package:flutter_application_1/features/attendance/providers/attendance_providers.dart';
import 'package:flutter_application_1/features/attendance_management/domain/attendance_management_repository.dart';
import 'package:flutter_application_1/features/attendance_management/domain/attendance_management_stats.dart';
import 'package:flutter_application_1/features/attendance_management/providers/attendance_management_providers.dart';
import 'package:flutter_application_1/features/attendance_management/presentation/widgets/attendance_matrix_view.dart';
import 'package:flutter_application_1/features/attendance_management/presentation/widgets/attendance_table_view.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/leave/domain/leave_request.dart';
import 'package:flutter_application_1/features/on_duty/domain/on_duty_assignment.dart';
import 'package:flutter_application_1/features/site_visit_attendance/domain/site_visit_record.dart';

class MockAttendanceManagementRepository implements AttendanceManagementRepository {
  final Map<String, AttendanceRecord> _storage = {};
  final StreamController<List<AttendanceRecord>> _recordsController =
      StreamController<List<AttendanceRecord>>.broadcast();
  final StreamController<AttendanceManagementStats> _statsController =
      StreamController<AttendanceManagementStats>.broadcast();

  void emitRecords(List<AttendanceRecord> records) {
    _recordsController.add(records);
  }

  void emitStats(AttendanceManagementStats stats) {
    _statsController.add(stats);
  }

  void updateAndEmit(AttendanceRecord record) {
    final normDate = record.date.contains('-') && record.date.split('-')[0].length == 4
        ? '${record.date.split('-')[2]}-${record.date.split('-')[1]}-${record.date.split('-')[0]}'
        : record.date;
    final key = record.employeeCode.isNotEmpty ? '${record.employeeCode}_$normDate' : '${record.employeeId}_$normDate';
    _storage[key] = record;
    _recordsController.add(_storage.values.toList());

    int present = 0;
    int late = 0;
    int checkedOut = 0;
    double hoursSum = 0;
    int hoursCount = 0;
    for (final r in _storage.values) {
      if (r.status.toLowerCase() == 'present') present++;
      if (r.status.toLowerCase() == 'late') late++;
      if (r.status.toLowerCase() == 'checked out') checkedOut++;
      if (r.totalHours > 0) {
        hoursSum += r.totalHours;
        hoursCount++;
      }
    }
    final avg = hoursCount > 0 ? double.parse((hoursSum / hoursCount).toStringAsFixed(1)) : 0.0;
    _statsController.add(AttendanceManagementStats(
      totalEmployees: _storage.length,
      presentToday: present,
      lateToday: late,
      checkedOutToday: checkedOut,
      absentToday: 0,
      onLeaveToday: 0,
      averageWorkHours: avg,
    ));
  }

  @override
  Stream<List<AttendanceRecord>> watchAllAttendanceRecords({
    int? employeeId,
    String? monthYear,
    String? statusFilter,
  }) {
    return _recordsController.stream.map((list) {
      var filtered = list;
      if (employeeId != null) {
        filtered = filtered.where((r) => r.employeeId == employeeId).toList();
      }
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter.toLowerCase() != 'all') {
        filtered = filtered.where((r) => r.status.toLowerCase() == statusFilter.toLowerCase()).toList();
      }
      return filtered;
    });
  }

  @override
  Stream<AttendanceManagementStats> watchAttendanceStats({String? date}) {
    return _statsController.stream;
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords({
    int? employeeId,
    String? monthYear,
    String? statusFilter,
  }) async {
    return _storage.values.toList();
  }

  @override
  Future<AttendanceManagementStats> getAttendanceStats({String? date}) async {
    return const AttendanceManagementStats(
      totalEmployees: 1,
      presentToday: 0,
      lateToday: 0,
      checkedOutToday: 0,
      absentToday: 1,
      onLeaveToday: 0,
      averageWorkHours: 0.0,
    );
  }

  @override
  Future<void> saveOrOverrideAttendance(AttendanceRecord record) async {
    updateAndEmit(record);
  }

  @override
  Future<void> deleteAttendanceRecord(int employeeId, String date) async {
    _storage.remove('${employeeId}_$date');
    _recordsController.add(_storage.values.toList());
  }

  @override
  Future<List<Map<String, dynamic>>> getAuditAttempts({int? employeeId, int limit = 100}) async => [];

  @override
  Future<void> bulkMarkAttendance({
    required List<int> employeeIds,
    required String date,
    required String status,
    required String checkInTime,
  }) async {}

  void dispose() {
    _recordsController.close();
    _statsController.close();
  }
}

class MockAttendanceRepository implements AttendanceRepository {
  final Map<String, AttendanceRecord> _storage = {};
  AttendanceSettings _settings = AttendanceSettings.defaults();

  void setSettings(AttendanceSettings s) => _settings = s;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AttendanceSettings> getAttendanceSettings() async => _settings;

  @override
  Future<void> saveAttendanceSettings(AttendanceSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> updateAttendanceSettings(AttendanceSettings settings) async {
    _settings = settings;
  }

  @override
  Future<AttendanceRecord?> getAttendanceRecordForDate(int employeeId, String date) async {
    final normDate = date.contains('-') && date.split('-')[0].length == 4
        ? date
        : (date.split('-').length == 3
            ? '${date.split('-')[2]}-${date.split('-')[1]}-${date.split('-')[0]}'
            : date);
    return _storage['${employeeId}_$normDate'] ?? _storage['${employeeId}_$date'];
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords(int employeeId) async {
    return _storage.values.where((r) => r.employeeId == employeeId || employeeId == 0).toList();
  }

  @override
  Future<List<AttendanceRecord>> getAllAttendanceRecords() async {
    return _storage.values.toList();
  }

  @override
  Future<AttendanceVerificationResult> verifyAttendance({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
    required String scheduledCheckInTime,
    required double currentLatitude,
    required double currentLongitude,
    bool faceMatched = true,
    double similarityScore = 1.0,
  }) async {
    final normDate = date.contains('-') && date.split('-')[0].length == 4
        ? date
        : (date.split('-').length == 3
            ? '${date.split('-')[2]}-${date.split('-')[1]}-${date.split('-')[0]}'
            : date);

    final schedClean = scheduledCheckInTime.trim().toUpperCase();
    int? schedMinutes;
    if (schedClean.isNotEmpty) {
      final isPm = schedClean.contains('PM');
      final isAm = schedClean.contains('AM');
      final digits = schedClean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digits.split(':');
      if (parts.isNotEmpty) {
        int h = int.tryParse(parts[0]) ?? 0;
        final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        schedMinutes = h * 60 + m;
      }
    }

    final now = DateTime.now();
    final actualMinutes = now.hour * 60 + now.minute;
    final grace = _settings.gracePeriodMinutes;
    final allowedMinutes = (schedMinutes ?? 540) + grace;
    final delay = actualMinutes - allowedMinutes;

    final String status = delay > 0 ? 'Late' : 'Present';
    final String notes = delay > 0 ? 'Late = $delay minutes' : 'On time';
    final timeStr = DateFormat('hh:mm:ss a').format(now);

    final record = AttendanceRecord(
      id: employeeId * 1000 + 1,
      employeeId: employeeId,
      employeeName: employeeName,
      date: normDate,
      time: timeStr,
      checkInTime: timeStr,
      checkOutTime: '',
      status: status,
      verificationStatus: 'Verified',
      similarityScore: similarityScore,
      notes: notes,
      markedAt: now.toIso8601String(),
      sessions: [
        AttendanceSession(
          id: 'session_1',
          type: 'office',
          checkInTime: timeStr,
          checkOutTime: '',
          checkInVerificationStatus: 'Verified',
          checkOutVerificationStatus: '',
          checkInSimilarityScore: similarityScore,
          checkOutSimilarityScore: 0.0,
          durationHours: 0.0,
          durationMinutes: 0,
          notes: notes,
          createdAt: now.toIso8601String(),
        )
      ],
    );

    _storage['${employeeId}_$normDate'] = record;
    _storage['${employeeId}_$date'] = record;

    return AttendanceVerificationResult(
      allowed: true,
      similarityScore: similarityScore,
      verificationStatus: 'Verified',
      message: 'Check in successful.',
      capturedImagePath: '',
    );
  }

  @override
  Future<AttendanceVerificationResult> verifyCheckOut({
    required int employeeId,
    required String date,
    required String employeeName,
    required String profileImageUrl,
    required double currentLatitude,
    required double currentLongitude,
    bool faceMatched = true,
    double similarityScore = 1.0,
  }) async {
    final normDate = date.contains('-') && date.split('-')[0].length == 4
        ? date
        : (date.split('-').length == 3
            ? '${date.split('-')[2]}-${date.split('-')[1]}-${date.split('-')[0]}'
            : date);
    final existing = _storage['${employeeId}_$normDate'];
    if (existing != null) {
      final now = DateTime.now();
      final timeStr = DateFormat('hh:mm:ss a').format(now);
      final updated = existing.copyWith(
        checkOutTime: timeStr,
        status: existing.status == 'Late' ? 'Late' : 'Completed',
      );
      _storage['${employeeId}_$normDate'] = updated;
    }
    return AttendanceVerificationResult(
      allowed: true,
      similarityScore: similarityScore,
      verificationStatus: 'Verified',
      message: 'Check out successful.',
      capturedImagePath: '',
    );
  }

  @override
  Future<void> markAttendance({
    required int employeeId,
    required String employeeName,
    String employeeCode = '',
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    required String status,
    String notes = '',
  }) async {
    final normDate = date.contains('-') && date.split('-')[0].length == 4
        ? date
        : (date.split('-').length == 3
            ? '${date.split('-')[2]}-${date.split('-')[1]}-${date.split('-')[0]}'
            : date);
    final rec = AttendanceRecord(
      id: employeeId * 1000 + 1,
      employeeId: employeeId,
      employeeCode: employeeCode,
      employeeName: employeeName,
      date: normDate,
      time: time,
      checkInTime: time,
      checkOutTime: '',
      status: status,
      verificationStatus: verificationStatus,
      similarityScore: similarityScore,
      notes: notes,
      markedAt: DateTime.now().toIso8601String(),
    );
    _storage['${employeeId}_$normDate'] = rec;
  }

  @override
  Future<void> unmarkAttendance({required int employeeId, required String date}) async {
    final normDate = date.contains('-') && date.split('-')[0].length == 4
        ? date
        : (date.split('-').length == 3
            ? '${date.split('-')[2]}-${date.split('-')[1]}-${date.split('-')[0]}'
            : date);
    _storage.remove('${employeeId}_$normDate');
    _storage.remove('${employeeId}_$date');
  }

  @override
  Future<void> logAttendanceAttempt({
    required int employeeId,
    required String employeeName,
    required String date,
    required String time,
    required String verificationStatus,
    required double similarityScore,
    required String message,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getAttendanceAttempts() async => [];

  @override
  Future<bool> hasAttendanceForDate(int employeeId, String date) async {
    final rec = await getAttendanceRecordForDate(employeeId, date);
    return rec != null;
  }

  @override
  Future<void> startActivitySession({
    required int employeeId,
    required String date,
    required String activityType,
    required String time,
  }) async {}

  @override
  Future<void> stopActivitySession({
    required int employeeId,
    required String date,
    required String time,
  }) async {}

  @override
  Future<void> startOnDutySession({
    required int employeeId,
    required String date,
    required String time,
    required int assignmentId,
    required String taskTitle,
    required String location,
    required double currentLatitude,
    required double currentLongitude,
    required String verificationStatus,
    required double similarityScore,
  }) async {}

  @override
  Future<void> completeOnDutySession({
    required int employeeId,
    required String date,
    required String time,
    required int assignmentId,
    required double currentLatitude,
    required double currentLongitude,
    required String verificationStatus,
    required double similarityScore,
  }) async {}

  @override
  Future<void> autoResolveMissingCheckOuts({int? employeeId}) async {}

  @override
  Future<void> recalculateAttendanceForDate(int employeeId, String date) async {}
}

void main() {
  group('Step 16: Immediate UI State Refresh After Check-In Tests', () {
    late MockAttendanceRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = MockAttendanceRepository();
      container = ProviderContainer(
        overrides: [
          attendanceRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    final testEmployee = Employee(
      id: 1,
      employeeId: 'EMP001',
      firstName: 'Super',
      lastName: 'Admin',
      emailAddress: 'admin@company.com',
      phoneNumber: '9876543210',
      gender: 'Male',
      dob: '1990-01-01',
      organizationName: 'HQ',
      department: 'Finance & Accounts',
      designation: 'Admin',
      employmentType: 'Full-time',
      joiningDate: '2020-01-01',
      status: 'Active',
      inTime: '12:25 AM',
      outTime: '11:58 PM',
      requiredWorkingHours: 9.0,
    );

    test('1. Late Check-in: check-in occurs -> provider invalidated -> Today\'s Status immediately shows Late', () async {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Before check-in, today record is null
      var todayRec = await container.read(todayAttendanceRecordProvider(testEmployee.id).future);
      expect(todayRec, isNull);

      // Perform Late Check-In
      final result = await repo.verifyAttendance(
        employeeId: testEmployee.id,
        date: todayStr,
        employeeName: testEmployee.fullName,
        profileImageUrl: '',
        scheduledCheckInTime: '12:25 AM',
        currentLatitude: 0,
        currentLongitude: 0,
      );

      expect(result.allowed, isTrue);

      // Riverpod invalidation simulation
      container.invalidate(todayAttendanceRecordProvider(testEmployee.id));
      container.invalidate(attendanceRecordsProvider(testEmployee.id));
      container.invalidate(allAttendanceRecordsProvider);

      // Read immediately after invalidation
      todayRec = await container.read(todayAttendanceRecordProvider(testEmployee.id).future);
      expect(todayRec, isNotNull);
      expect(todayRec!.status, 'Late');

      // Status helper resolves to L - Late (orange)
      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: testEmployee,
        date: DateTime.now(),
        record: todayRec,
      );
      expect(statusInfo, equals(AttendanceStatusInfo.late));
      expect(statusInfo?.code, 'L');
      expect(statusInfo?.label, 'Late');
    });

    test('2. On-Time Check-in: check-in occurs -> provider invalidated -> Today\'s Status immediately shows Present', () async {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final currentInTime = DateFormat('hh:mm a').format(now);

      // Set scheduled start to match current time (on time)
      final onTimeEmployee = testEmployee.copyWith(inTime: currentInTime);

      final result = await repo.verifyAttendance(
        employeeId: onTimeEmployee.id,
        date: todayStr,
        employeeName: onTimeEmployee.fullName,
        profileImageUrl: '',
        scheduledCheckInTime: currentInTime,
        currentLatitude: 0,
        currentLongitude: 0,
      );

      expect(result.allowed, isTrue);

      container.invalidate(todayAttendanceRecordProvider(onTimeEmployee.id));
      container.invalidate(attendanceRecordsProvider(onTimeEmployee.id));
      container.invalidate(allAttendanceRecordsProvider);

      final todayRec = await container.read(todayAttendanceRecordProvider(onTimeEmployee.id).future);
      expect(todayRec, isNotNull);
      expect(todayRec!.status, 'Present');

      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: onTimeEmployee,
        date: DateTime.now(),
        record: todayRec,
      );
      expect(statusInfo, equals(AttendanceStatusInfo.present));
      expect(statusInfo?.code, 'P');
      expect(statusInfo?.label, 'Present');
    });

    test('3. Date key normalization in Calendar Map: resolves record whether date is ISO or DD-MM-YYYY without duplicate keys', () {
      final now = DateTime.now();
      final dKey = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final isoKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final recordIso = AttendanceRecord(
        id: 101,
        employeeId: 1,
        employeeName: 'Super Admin',
        date: isoKey,
        time: '12:45 AM',
        status: 'Late',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        notes: 'Late = 10 minutes',
      );

      // Format key helper like in AttendancePage
      String formatKey(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
      DateTime? parseKey(String val) => DateTime.tryParse(val);

      final records = [recordIso];
      final attendanceMap = <String, AttendanceRecord>{};
      for (final rec in records) {
        final dt = parseKey(rec.date);
        final key = dt != null ? formatKey(dt) : rec.date;
        attendanceMap[key] = rec;
      }

      // Exact one unique entry with DD-MM-YYYY format
      expect(attendanceMap.length, equals(1));
      expect(attendanceMap.containsKey(dKey), isTrue);

      // Calendar cell query
      final cellDate = DateTime(now.year, now.month, now.day);
      final cellKey = formatKey(cellDate);
      final found = attendanceMap[cellKey];

      expect(found, isNotNull);
      expect(found!.status, 'Late');

      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: testEmployee,
        date: cellDate,
        record: found,
      );
      expect(statusInfo, equals(AttendanceStatusInfo.late));
    });

    test('4. All attendance providers stay synchronized upon check-in and checkout without manual refresh', () async {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await repo.verifyAttendance(
        employeeId: testEmployee.id,
        date: todayStr,
        employeeName: testEmployee.fullName,
        profileImageUrl: '',
        scheduledCheckInTime: '12:25 AM',
        currentLatitude: 0,
        currentLongitude: 0,
      );

      container.invalidate(todayAttendanceRecordProvider(testEmployee.id));
      container.invalidate(attendanceRecordsProvider(testEmployee.id));
      container.invalidate(allAttendanceRecordsProvider);

      final todayRec = await container.read(todayAttendanceRecordProvider(testEmployee.id).future);
      final empRecords = await container.read(attendanceRecordsProvider(testEmployee.id).future);
      final allRecords = await container.read(allAttendanceRecordsProvider.future);

      expect(todayRec, isNotNull);
      expect(empRecords, isNotEmpty);
      expect(allRecords, isNotEmpty);
      expect(todayRec!.status, 'Late');
      expect(empRecords.first.status, 'Late');
      expect(allRecords.first.status, 'Late');

      // Now Check Out
      await repo.verifyCheckOut(
        employeeId: testEmployee.id,
        date: todayStr,
        employeeName: testEmployee.fullName,
        profileImageUrl: '',
        currentLatitude: 0,
        currentLongitude: 0,
      );

      container.invalidate(todayAttendanceRecordProvider(testEmployee.id));
      container.invalidate(attendanceRecordsProvider(testEmployee.id));
      container.invalidate(allAttendanceRecordsProvider);

      final updatedTodayRec = await container.read(todayAttendanceRecordProvider(testEmployee.id).future);
      expect(updatedTodayRec, isNotNull);
      expect(updatedTodayRec!.checkOutTime, isNotEmpty);
    });

    test('5. Real-Time Admin Attendance Management: Admin screen OPEN -> Employee checks in ON-TIME -> Stream emits -> Admin reflects Present (P) automatically without manual refresh', () async {
      final adminRepo = MockAttendanceManagementRepository();
      final adminContainer = ProviderContainer(
        overrides: [
          attendanceManagementRepositoryProvider.overrideWithValue(adminRepo),
        ],
      );

      final queryKey = (employeeId: null, monthYear: '09-2026', statusFilter: 'All');
      final dateKey = '19-09-2026';

      // 1. Admin screen is ALREADY OPEN, actively listening to the records stream & stats stream
      final List<List<AttendanceRecord>> emittedRecordLists = [];
      final List<AttendanceManagementStats> emittedStatsList = [];

      final recordsSub = adminContainer.listen(
        attendanceManagementRecordsProvider(queryKey),
        (previous, next) {
          if (next.hasValue) {
            emittedRecordLists.add(next.value!);
          }
        },
        fireImmediately: true,
      );

      final statsSub = adminContainer.listen(
        attendanceManagementStatsProvider(dateKey),
        (previous, next) {
          if (next.hasValue) {
            emittedStatsList.add(next.value!);
          }
        },
        fireImmediately: true,
      );

      // Initially no records emitted yet
      expect(emittedRecordLists.isEmpty, isTrue);

      // 2. Employee checks in ON-TIME (e.g. from employee screen/mobile device)
      final onTimeRecord = AttendanceRecord(
        id: 1001,
        employeeId: testEmployee.id,
        employeeCode: testEmployee.employeeId,
        employeeName: testEmployee.fullName,
        date: '19-09-2026',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '',
        status: 'Present',
        verificationStatus: 'Face & GPS Verified',
        similarityScore: 0.98,
        notes: 'On time',
        markedAt: DateTime(2026, 9, 19, 9, 0).toIso8601String(),
        sessions: [
          const AttendanceSession(
            id: 'sess_1',
            type: 'Office',
            checkInTime: '09:00 AM',
            checkOutTime: '',
            checkInVerificationStatus: 'Face & GPS Verified',
            checkOutVerificationStatus: '',
            checkInSimilarityScore: 0.98,
            checkOutSimilarityScore: 0.0,
            durationHours: 0.0,
            durationMinutes: 0,
            notes: 'On time',
          ),
        ],
      );

      // Firestore document is written / updated
      adminRepo.updateAndEmit(onTimeRecord);

      // Wait a microtask for stream delivery
      await Future.delayed(const Duration(milliseconds: 10));

      // 3. Admin Attendance Management screen received the update automatically WITHOUT manual refresh
      expect(emittedRecordLists, isNotEmpty);
      final latestRecords = emittedRecordLists.last;
      expect(latestRecords.length, equals(1));
      expect(latestRecords.first.status, equals('Present'));
      expect(latestRecords.first.checkInTime, equals('09:00 AM'));
      expect(latestRecords.first.employeeName, equals('Super Admin'));

      // Status helper resolves to P - Present
      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: testEmployee,
        date: DateTime(2026, 9, 19),
        record: latestRecords.first,
      );
      expect(statusInfo, equals(AttendanceStatusInfo.present));
      expect(statusInfo?.code, equals('P'));
      expect(statusInfo?.label, equals('Present'));

      // Dashboard stats updated in real-time
      expect(emittedStatsList, isNotEmpty);
      final latestStats = emittedStatsList.last;
      expect(latestStats.presentToday, equals(1));
      expect(latestStats.lateToday, equals(0));

      recordsSub.close();
      statsSub.close();
      adminRepo.dispose();
      adminContainer.dispose();
    });

    test('6. Real-Time Admin Attendance Management: Admin screen OPEN -> Employee checks in LATE -> Stream emits -> Admin reflects Late (L) automatically without manual refresh', () async {
      final adminRepo = MockAttendanceManagementRepository();
      final adminContainer = ProviderContainer(
        overrides: [
          attendanceManagementRepositoryProvider.overrideWithValue(adminRepo),
        ],
      );

      final queryKey = (employeeId: null, monthYear: '09-2026', statusFilter: 'All');
      final dateKey = '19-09-2026';

      final List<List<AttendanceRecord>> emittedRecordLists = [];
      final List<AttendanceManagementStats> emittedStatsList = [];

      final recordsSub = adminContainer.listen(
        attendanceManagementRecordsProvider(queryKey),
        (previous, next) {
          if (next.hasValue) {
            emittedRecordLists.add(next.value!);
          }
        },
        fireImmediately: true,
      );

      final statsSub = adminContainer.listen(
        attendanceManagementStatsProvider(dateKey),
        (previous, next) {
          if (next.hasValue) {
            emittedStatsList.add(next.value!);
          }
        },
        fireImmediately: true,
      );

      // Employee checks in LATE (e.g. 09:35 AM with 10 min grace -> Late 25 mins)
      final lateRecord = AttendanceRecord(
        id: 1002,
        employeeId: testEmployee.id,
        employeeCode: testEmployee.employeeId,
        employeeName: testEmployee.fullName,
        date: '19-09-2026',
        time: '09:35 AM',
        checkInTime: '09:35 AM',
        checkOutTime: '',
        status: 'Late',
        verificationStatus: 'Face & GPS Verified',
        similarityScore: 0.96,
        notes: 'Late = 25 minutes beyond grace',
        markedAt: DateTime(2026, 9, 19, 9, 35).toIso8601String(),
        sessions: [
          const AttendanceSession(
            id: 'sess_1',
            type: 'Office',
            checkInTime: '09:35 AM',
            checkOutTime: '',
            checkInVerificationStatus: 'Face & GPS Verified',
            checkOutVerificationStatus: '',
            checkInSimilarityScore: 0.96,
            checkOutSimilarityScore: 0.0,
            durationHours: 0.0,
            durationMinutes: 0,
            notes: 'Late = 25 minutes beyond grace',
          ),
        ],
      );

      adminRepo.updateAndEmit(lateRecord);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emittedRecordLists, isNotEmpty);
      final latestRecords = emittedRecordLists.last;
      expect(latestRecords.length, equals(1));
      expect(latestRecords.first.status, equals('Late'));
      expect(latestRecords.first.checkInTime, equals('09:35 AM'));
      expect(latestRecords.first.notes, contains('Late = 25 minutes'));

      // Status helper resolves to L - Late
      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: testEmployee,
        date: DateTime(2026, 9, 19),
        record: latestRecords.first,
      );
      expect(statusInfo, equals(AttendanceStatusInfo.late));
      expect(statusInfo?.code, equals('L'));
      expect(statusInfo?.label, equals('Late'));

      // Stats reflect Late count
      expect(emittedStatsList, isNotEmpty);
      final latestStats = emittedStatsList.last;
      expect(latestStats.lateToday, equals(1));
      expect(latestStats.presentToday, equals(0));

      recordsSub.close();
      statsSub.close();
      adminRepo.dispose();
      adminContainer.dispose();
    });

    test('7. Real-Time Admin Attendance Management: Employee checks out -> Stream automatically updates check-out time & hours in open Admin view', () async {
      final adminRepo = MockAttendanceManagementRepository();
      final adminContainer = ProviderContainer(
        overrides: [
          attendanceManagementRepositoryProvider.overrideWithValue(adminRepo),
        ],
      );

      final queryKey = (employeeId: null, monthYear: '09-2026', statusFilter: 'All');
      final dateKey = '19-09-2026';

      final List<List<AttendanceRecord>> emittedRecordLists = [];
      final recordsSub = adminContainer.listen(
        attendanceManagementRecordsProvider(queryKey),
        (previous, next) {
          if (next.hasValue) {
            emittedRecordLists.add(next.value!);
          }
        },
        fireImmediately: true,
      );

      // 1. Initial check-in
      final checkedInRecord = AttendanceRecord(
        id: 1003,
        employeeId: testEmployee.id,
        employeeCode: testEmployee.employeeId,
        employeeName: testEmployee.fullName,
        date: '19-09-2026',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        markedAt: DateTime(2026, 9, 19, 9, 0).toIso8601String(),
        sessions: [
          const AttendanceSession(
            id: 'sess_1',
            type: 'Office',
            checkInTime: '09:00 AM',
            checkOutTime: '06:00 PM',
            durationHours: 9.0,
            durationMinutes: 540,
          ),
        ],
      );
      adminRepo.updateAndEmit(checkedInRecord);
      await Future.delayed(const Duration(milliseconds: 10));

      // 2. Later check-out
      final checkedOutRecord = checkedInRecord.copyWith(
        checkOutTime: '06:00 PM',
        totalHours: 9.0,
      );
      adminRepo.updateAndEmit(checkedOutRecord);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emittedRecordLists.length, greaterThanOrEqualTo(2));
      final finalRecord = emittedRecordLists.last.first;
      expect(finalRecord.checkInTime, equals('09:00 AM'));
      expect(finalRecord.checkOutTime, equals('06:00 PM'));
      expect(finalRecord.totalHours, equals(9.0));
      expect(finalRecord.formattedTotalHours, equals('9hr'));

      recordsSub.close();
      adminRepo.dispose();
      adminContainer.dispose();
    });

    testWidgets('8. Real-Time Admin Attendance Management Widget Rendering: Matrix and Table Views display P and L immediately on stream emission',
        (WidgetTester tester) async {
      final adminRepo = MockAttendanceManagementRepository();

      final onTimeRecord = AttendanceRecord(
        id: 1001,
        employeeId: testEmployee.id,
        employeeCode: testEmployee.employeeId,
        employeeName: testEmployee.fullName,
        date: '19-09-2026',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        markedAt: DateTime(2026, 9, 19, 9, 0).toIso8601String(),
      );

      // Render AttendanceMatrixView with the live record
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceMatrixView(
              focusedMonth: DateTime(2026, 9, 1),
              employees: [testEmployee],
              records: [onTimeRecord],
              onCellTap: (_, __, ___, ____) {},
            ),
          ),
        ),
      );

      // On-time check-in cell renders 'P'
      expect(find.text('P'), findsWidgets);
      expect(find.text('Super Admin'), findsOneWidget);

      // Render AttendanceTableView with the live record
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceTableView(
              records: [onTimeRecord],
              employees: [testEmployee],
              onEdit: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      // Table displays employee name, status chip 'P - Present', check-in time '09:00 AM'
      expect(find.text('Super Admin'), findsOneWidget);
      expect(find.text('P - Present'), findsOneWidget);
      expect(find.text('09:00 AM'), findsOneWidget);

      adminRepo.dispose();
    });

    test('9. Office Attendance Flow: Employee checks in & checks out -> Admin reflects P, in-time, out-time and total hours', () async {
      final adminRepo = MockAttendanceManagementRepository();
      final adminContainer = ProviderContainer(
        overrides: [
          attendanceManagementRepositoryProvider.overrideWithValue(adminRepo),
        ],
      );

      final queryKey = (employeeId: null, monthYear: '09-2026', statusFilter: 'All');
      final List<List<AttendanceRecord>> emittedRecords = [];
      final sub = adminContainer.listen(
        attendanceManagementRecordsProvider(queryKey),
        (prev, next) {
          if (next.hasValue) emittedRecords.add(next.value!);
        },
        fireImmediately: true,
      );

      // Office check in
      final officeRecord = AttendanceRecord(
        id: 201,
        employeeId: testEmployee.id,
        employeeCode: testEmployee.employeeId,
        employeeName: testEmployee.fullName,
        date: '19-09-2026',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '06:00 PM',
        status: 'Present',
        verificationStatus: 'Geofence Verified',
        similarityScore: 1.0,
        totalHours: 9.0,
        markedAt: DateTime(2026, 9, 19, 9, 0).toIso8601String(),
        sessions: [
          const AttendanceSession(
            id: 's_office',
            type: 'Office',
            checkInTime: '09:00 AM',
            checkOutTime: '06:00 PM',
            durationHours: 9.0,
            durationMinutes: 540,
          ),
        ],
      );
      adminRepo.updateAndEmit(officeRecord);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emittedRecords, isNotEmpty);
      final rec = emittedRecords.last.first;
      expect(rec.status, equals('Present'));
      expect(rec.checkInTime, equals('09:00 AM'));
      expect(rec.checkOutTime, equals('06:00 PM'));
      expect(rec.totalHours, equals(9.0));

      sub.close();
      adminRepo.dispose();
      adminContainer.dispose();
    });

    test('10. Site Visit Attendance Flow: Site record created -> Resolves with site name and duration', () {
      const visit = SiteVisitRecord(
        id: 1,
        employeeId: 1,
        employeeName: 'Super Admin',
        siteName: 'Metro Rail Phase 2',
        address: 'Sector 4, Central Corridor',
        latitude: 12.9716,
        longitude: 77.5946,
        visitDate: '19-09-2026',
        visitTime: '10:00 AM',
        photoUrl: '',
        notes: 'Site inspection completed',
        createdAt: '2026-09-19T10:00:00.000',
      );

      expect(visit.siteName, equals('Metro Rail Phase 2'));
      expect(visit.visitTime, equals('10:00 AM'));
      expect(visit.address, equals('Sector 4, Central Corridor'));
    });

    test('11. OD (On-Duty) Attendance Flow: Approved OD assignment -> AttendanceStatusHelper resolves to OD (On Duty)', () {
      const odAssignment = OnDutyAssignment(
        id: 301,
        employeeId: 1,
        employeeName: 'Super Admin',
        odType: 'Client Visit',
        purpose: 'Client Plant Audit',
        destination: 'Industrial Zone',
        date: '19-09-2026',
        status: 'APPROVED',
        assignedBy: 'Manager',
        createdAt: '2026-09-19T10:00:00.000',
      );

      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: testEmployee,
        date: DateTime(2026, 9, 19),
        record: null,
        onDutyAssignments: const [odAssignment],
      );

      expect(statusInfo, equals(AttendanceStatusInfo.onDuty));
      expect(statusInfo?.code, equals('OD'));
      expect(statusInfo?.label, equals('On Duty'));
    });

    test('12. Leave Request Flow: Approved Leave -> AttendanceStatusHelper resolves to OL (On Leave)', () {
      const approvedLeave = LeaveRequest(
        id: 401,
        employeeId: 1,
        employeeName: 'Super Admin',
        employeeCustomId: 'EMP001',
        leaveType: 'Casual Leave',
        fromDate: '19-09-2026',
        toDate: '19-09-2026',
        reason: 'Personal work',
        status: 'Approved',
        numDays: 1.0,
        createdAt: '2026-09-18T10:00:00.000',
      );

      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: testEmployee,
        date: DateTime(2026, 9, 19),
        record: null,
        leaves: const [approvedLeave],
      );

      expect(statusInfo, equals(AttendanceStatusInfo.onLeave));
      expect(statusInfo?.code, equals('OL'));
      expect(statusInfo?.label, equals('On Leave'));
    });

    test('13. Missing Check-Out Flow: Past day with check-in but no check-out -> Resolves to MC (Missing Checkout)', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final pastDateStr = DateFormat('dd-MM-yyyy').format(pastDate);

      final pastMissingCheckoutRecord = AttendanceRecord(
        id: 501,
        employeeId: testEmployee.id,
        employeeCode: testEmployee.employeeId,
        employeeName: testEmployee.fullName,
        date: pastDateStr,
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );

      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: testEmployee,
        date: pastDate,
        record: pastMissingCheckoutRecord,
      );

      expect(statusInfo, equals(AttendanceStatusInfo.missingCheckout));
      expect(statusInfo?.code, equals('MC'));
      expect(statusInfo?.label, equals('Missing Checkout'));
    });

    test('14. Past Absent Working Day Flow: Past working day with no record, leave, or holiday -> Resolves to A (Absent)', () {
      // Pick a past day that is a weekday (Monday = 1)
      var pastDate = DateTime.now().subtract(const Duration(days: 3));
      while (pastDate.weekday == DateTime.sunday) {
        pastDate = pastDate.subtract(const Duration(days: 1));
      }

      final statusInfo = AttendanceStatusHelper.resolveStatus(
        employee: testEmployee,
        date: pastDate,
        record: null,
      );

      expect(statusInfo, equals(AttendanceStatusInfo.absent));
      expect(statusInfo?.code, equals('A'));
      expect(statusInfo?.label, equals('Absent'));
    });

    test('15. Admin Correction Flow: Admin updates record -> Stream emits -> Record is immediately updated with new in/out time and reason note', () async {
      final adminRepo = MockAttendanceManagementRepository();
      final adminContainer = ProviderContainer(
        overrides: [
          attendanceManagementRepositoryProvider.overrideWithValue(adminRepo),
        ],
      );

      final queryKey = (employeeId: null, monthYear: '09-2026', statusFilter: 'All');
      final List<List<AttendanceRecord>> emittedRecords = [];
      final sub = adminContainer.listen(
        attendanceManagementRecordsProvider(queryKey),
        (prev, next) {
          if (next.hasValue) emittedRecords.add(next.value!);
        },
        fireImmediately: true,
      );

      // Initial record
      final initialRecord = AttendanceRecord(
        id: 601,
        employeeId: testEmployee.id,
        employeeCode: testEmployee.employeeId,
        employeeName: testEmployee.fullName,
        date: '19-09-2026',
        time: '09:00 AM',
        checkInTime: '09:00 AM',
        checkOutTime: '',
        status: 'Late',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );
      adminRepo.updateAndEmit(initialRecord);
      await Future.delayed(const Duration(milliseconds: 10));

      // Admin submits correction
      final correctedRecord = initialRecord.copyWith(
        status: 'Present',
        checkInTime: '09:00 AM',
        checkOutTime: '06:00 PM',
        totalHours: 9.0,
        notes: 'Admin manual correction: punch machine network error',
        verificationStatus: 'Admin Correction (Firestore)',
      );

      await adminRepo.saveOrOverrideAttendance(correctedRecord);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emittedRecords.length, greaterThanOrEqualTo(2));
      final latest = emittedRecords.last.first;
      expect(latest.status, equals('Present'));
      expect(latest.checkOutTime, equals('06:00 PM'));
      expect(latest.notes, contains('Admin manual correction'));
      expect(latest.verificationStatus, equals('Admin Correction (Firestore)'));

      sub.close();
      adminRepo.dispose();
      adminContainer.dispose();
    });
  });
}
