import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/utils/time_formatter.dart';
import 'package:flutter_application_1/features/attendance/data/firebase_attendance_repository.dart';
import 'package:flutter_application_1/features/attendance/domain/attendance_record.dart';
import 'package:flutter_application_1/features/on_duty/data/firebase_on_duty_repository.dart';
import 'package:flutter_application_1/features/on_duty/domain/on_duty_assignment.dart';
import 'package:flutter_application_1/features/on_duty/domain/on_duty_site.dart';

// =============================================================================
// Minimal In-Memory Fake Firestore for Testing Real Repository Methods
// =============================================================================

class _FakeFirestore implements FirebaseFirestore {
  final Map<String, Map<String, Map<String, dynamic>>> store = {};

  Map<String, Map<String, dynamic>> _col(String path) =>
      store.putIfAbsent(path, () => {});

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeCollectionRef(this, collectionPath);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollectionRef implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionRef(this.fs, this.path);
  final _FakeFirestore fs;
  @override
  final String path;
  int _autoIdCounter = 0;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? docPath]) {
    final id = docPath ?? 'auto_${++_autoIdCounter}';
    return _FakeDocRef(fs, path, id);
  }

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
      Map<String, dynamic> data) async {
    final ref = doc();
    await ref.set(data);
    return ref;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final col = fs._col(path);
    final docs = col.entries
        .map((e) => _FakeQueryDocSnap(
              _FakeDocRef(fs, path, e.key),
              e.key,
              Map<String, dynamic>.from(e.value),
            ))
        .toList();
    return _FakeQuerySnap(docs);
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return _FakeQuery(fs, path, (doc) {
      if (isEqualTo != null) {
        return doc[field.toString()] == isEqualTo;
      }
      return true;
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQuery implements Query<Map<String, dynamic>> {
  _FakeQuery(this.fs, this.path, this.predicate);
  final _FakeFirestore fs;
  final String path;
  final bool Function(Map<String, dynamic>) predicate;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final col = fs._col(path);
    final docs = col.entries
        .where((e) => predicate(e.value))
        .map((e) => _FakeQueryDocSnap(
              _FakeDocRef(fs, path, e.key),
              e.key,
              Map<String, dynamic>.from(e.value),
            ))
        .toList();
    return _FakeQuerySnap(docs);
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return _FakeQuery(fs, path, (doc) {
      if (!predicate(doc)) return false;
      if (isEqualTo != null) return doc[field.toString()] == isEqualTo;
      return true;
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocRef implements DocumentReference<Map<String, dynamic>> {
  _FakeDocRef(this.fs, this.colPath, this.id);
  final _FakeFirestore fs;
  final String colPath;
  @override
  final String id;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    final data = fs._col(colPath)[id];
    return _FakeDocSnap(
      this,
      id,
      data != null ? Map<String, dynamic>.from(data) : null,
    );
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    final col = fs._col(colPath);
    if (options?.merge == true && col.containsKey(id)) {
      col[id] = {...col[id]!, ...data};
    } else {
      col[id] = Map<String, dynamic>.from(data);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocSnap implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnap(this.reference, this.id, this._data);
  @override
  final DocumentReference<Map<String, dynamic>> reference;
  @override
  final String id;
  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQueryDocSnap
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDocSnap(this.reference, this.id, this._data);
  @override
  final DocumentReference<Map<String, dynamic>> reference;
  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQuerySnap implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnap(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('OD Start-Time, Transitions & Overlapping Work Hours Fixes', () {
    late _FakeFirestore fakeFs;
    late FirebaseAttendanceRepository attendanceRepo;
    late FirebaseOnDutyRepository onDutyRepo;

    setUp(() {
      fakeFs = _FakeFirestore();
      attendanceRepo = FirebaseAttendanceRepository(firestore: fakeFs);
      onDutyRepo = FirebaseOnDutyRepository(firestore: fakeFs);
    });

    Future<void> seedEmployee({
      int id = 10,
      String code = 'EMP010',
      String name = 'Test Employee',
      double requiredHours = 9.0,
    }) async {
      await fakeFs.collection('employees').doc(id.toString()).set({
        'id': id,
        'employee_id': code,
        'full_name': name,
        'required_working_hours': requiredHours,
        'in_time': '09:00 AM',
        'out_time': '06:00 PM',
        'work_schedule_type': 'Fixed Schedule',
        'is_static_employee': 1,
        'is_dynamic_employee': 0,
      });
    }

    Future<void> seedOfficeCheckIn({
      int empId = 10,
      String empCode = 'EMP010',
      String empName = 'Test Employee',
      String date = '2026-11-18',
      String checkInTime = '10:27:33 AM',
    }) async {
      final rec = AttendanceRecord(
        id: 1001,
        employeeId: empId,
        employeeCode: empCode,
        employeeName: empName,
        date: date,
        time: checkInTime,
        checkInTime: checkInTime,
        checkOutTime: '',
        status: 'Present',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: [
          AttendanceSession(
            id: 'session_office_1',
            type: 'office',
            checkInTime: checkInTime,
            checkOutTime: '',
            checkInVerificationStatus: 'Verified',
            checkInMethod: 'Face + Geofence',
          ),
        ],
      );
      await fakeFs
          .collection('attendance_records')
          .doc('${empId}_${date.replaceAll('-', '')}')
          .set(rec.toMap());
    }

    test('Scenario 1: Office check-in followed by unstarted (ASSIGNED) OD assignment creates NO synthetic session and NO 08:00 AM', () async {
      await seedEmployee();
      await seedOfficeCheckIn(checkInTime: '10:27:33 AM');

      // Seed an ASSIGNED OD that has NOT been started yet
      await fakeFs.collection('on_duty_assignments').doc('501').set({
        'id': 501,
        'employee_id': 10,
        'employee_name': 'Test Employee',
        'date': '18-11-2026',
        'status': 'ASSIGNED',
        'purpose': 'Client Site Visit',
        'destination': 'Site A',
        'planned_start_time': '',
        'actual_start_time': null,
        'travel_start_time': null,
        'sites': [
          {'site_name': 'Site A', 'status': 'PENDING'}
        ],
      });

      await attendanceRepo.autoSyncCompletedOdSessions(employeeId: 10);

      final updatedDoc = await fakeFs
          .collection('attendance_records')
          .doc('10_20261118')
          .get();
      final rec = AttendanceRecord.fromMap(updatedDoc.data()!);

      expect(rec.sessions.length, 1);
      expect(rec.sessions.first.isOffice, isTrue);
      expect(rec.sessions.first.isActive, isTrue);
      expect(rec.sessions.first.checkInTime, '10:27:33 AM');
      expect(rec.sessions.any((s) => s.isOd), isFalse);
      expect(rec.sessions.any((s) => s.checkInTime.contains('08:00')), isFalse);
    });

    test('Scenario 2: Office check-in followed by actual OD start closes Office and starts OD at the EXACT same timestamp', () async {
      await seedEmployee();
      await seedOfficeCheckIn(checkInTime: '10:27:33 AM');

      const odStartTime = '11:15:40 AM';
      await fakeFs.collection('on_duty_assignments').doc('502').set({
        'id': 502,
        'employee_id': 10,
        'employee_name': 'Test Employee',
        'date': '18-11-2026',
        'status': 'TRAVELING_TO_DESTINATION',
        'purpose': 'Client Inspection',
        'destination': 'Site B',
        'actual_start_time': odStartTime,
        'travel_start_time': odStartTime,
      });

      final res = await attendanceRepo.startOdAttendanceSession(
        employeeId: 10,
        employeeCode: 'EMP010',
        employeeName: 'Test Employee',
        date: '2026-11-18',
        time: odStartTime,
        assignmentId: 502,
        purpose: 'Client Inspection',
        destination: 'Site B',
      );

      expect(res.allowed, isTrue);

      final doc = await fakeFs
          .collection('attendance_records')
          .doc('10_20261118')
          .get();
      final rec = AttendanceRecord.fromMap(doc.data()!);

      expect(rec.sessions.length, 2);
      // Office session closed at exact OD start timestamp
      expect(rec.sessions[0].isOffice, isTrue);
      expect(rec.sessions[0].checkInTime, '10:27:33 AM');
      expect(rec.sessions[0].checkOutTime, odStartTime);
      expect(rec.sessions[0].isCompleted, isTrue);

      // OD session opened at exact same timestamp with preserved assignmentId
      expect(rec.sessions[1].isOd, isTrue);
      expect(rec.sessions[1].assignmentId, 502);
      expect(rec.sessions[1].checkInTime, odStartTime);
      expect(rec.sessions[1].isActive, isTrue);

      expect(rec.hasOverlappingSessions, isFalse);

      // Verify FirebaseOnDutyRepository.updateAssignmentStatus stores both actual_start_time & travel_start_time
      await onDutyRepo.updateAssignmentStatus(
        id: 502,
        status: 'TRAVELING_TO_DESTINATION',
        actualStartTime: odStartTime,
      );
      final odDoc = await fakeFs.collection('on_duty_assignments').doc('502').get();
      expect(odDoc.data()!['actual_start_time'], odStartTime);
      expect(odDoc.data()!['travel_start_time'], odStartTime);
    });

    test('Scenario 3: OD started without an Office session uses actual OD start timestamp directly', () async {
      await seedEmployee();

      const odStartTime = '09:42:15 AM';
      await fakeFs.collection('on_duty_assignments').doc('503').set({
        'id': 503,
        'employee_id': 10,
        'employee_name': 'Test Employee',
        'date': '18-11-2026',
        'status': 'REACHED_DESTINATION',
        'purpose': 'Start from Home Site Visit',
        'destination': 'Site C',
        'actual_start_time': odStartTime,
        'start_od_from_home': true,
      });

      final res = await attendanceRepo.startOdAttendanceSession(
        employeeId: 10,
        employeeCode: 'EMP010',
        employeeName: 'Test Employee',
        date: '2026-11-18',
        time: odStartTime,
        assignmentId: 503,
        purpose: 'Start from Home Site Visit',
        destination: 'Site C',
        startOdFromHome: true,
      );

      expect(res.allowed, isTrue);

      final doc = await fakeFs
          .collection('attendance_records')
          .doc('10_20261118')
          .get();
      final rec = AttendanceRecord.fromMap(doc.data()!);

      expect(rec.sessions.length, 1);
      expect(rec.sessions.first.isOd, isTrue);
      expect(rec.sessions.first.checkInTime, odStartTime);
      expect(rec.sessions.first.assignmentId, 503);
      expect(rec.checkInTime, odStartTime);
      expect(rec.sessions.any((s) => s.checkInTime.contains('08:00')), isFalse);
    });

    test('Scenario 4: POD submitted without an active OD session does NOT accidentally close active Office session', () async {
      await seedEmployee();
      await seedOfficeCheckIn(checkInTime: '10:27:33 AM');

      // Attempt to complete OD session when only an Office session is active
      final res = await attendanceRepo.completeOdAttendanceSession(
        employeeId: 10,
        employeeCode: 'EMP010',
        employeeName: 'Test Employee',
        date: '2026-11-18',
        time: '06:54:09 PM',
        assignmentId: 504,
        afterCompletionOption: 'CHECKOUT_FROM_OD',
      );

      expect(res.allowed, isFalse);
      expect(res.verificationStatus, 'No Active Session');

      final doc = await fakeFs
          .collection('attendance_records')
          .doc('10_20261118')
          .get();
      final rec = AttendanceRecord.fromMap(doc.data()!);

      // Office session must remain completely untouched and active
      expect(rec.sessions.length, 1);
      expect(rec.sessions.first.isOffice, isTrue);
      expect(rec.sessions.first.isActive, isTrue);
      expect(rec.sessions.first.checkOutTime, isEmpty);
    });

    test('Scenario 5: Employee returns to office after OD — closes OD and starts new Office session at exact return timestamp', () async {
      await seedEmployee();
      await seedOfficeCheckIn(checkInTime: '10:00:00 AM');

      // 1. Start OD at 12:00:00 PM (Office 10:00 -> 12:00 = 2h)
      await attendanceRepo.startOdAttendanceSession(
        employeeId: 10,
        employeeCode: 'EMP010',
        employeeName: 'Test Employee',
        date: '2026-11-18',
        time: '12:00:00 PM',
        assignmentId: 505,
        purpose: 'Site Work',
        destination: 'Site D',
      );

      // 2. Return to office at 03:30:00 PM (OD 12:00 -> 15:30 = 3.5h; new Office starts at 03:30:00 PM)
      const returnTime = '03:30:00 PM';
      final completeRes = await attendanceRepo.completeOdAttendanceSession(
        employeeId: 10,
        employeeCode: 'EMP010',
        employeeName: 'Test Employee',
        date: '2026-11-18',
        time: returnTime,
        assignmentId: 505,
        afterCompletionOption: 'RETURN_TO_OFFICE',
      );

      expect(completeRes.allowed, isTrue);

      // 3. Final Office checkout at 06:30:00 PM (Office 2: 15:30 -> 18:30 = 3h)
      await attendanceRepo.checkOut(
        employeeId: 10,
        date: '2026-11-18',
        checkOutTime: '06:30:00 PM',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
      );

      final doc = await fakeFs
          .collection('attendance_records')
          .doc('10_20261118')
          .get();
      final rec = AttendanceRecord.fromMap(doc.data()!);

      expect(rec.sessions.length, 3);
      expect(rec.sessions[0].isOffice, isTrue);
      expect(rec.sessions[0].checkInTime, '10:00:00 AM');
      expect(rec.sessions[0].checkOutTime, '12:00:00 PM');

      expect(rec.sessions[1].isOd, isTrue);
      expect(rec.sessions[1].checkInTime, '12:00:00 PM');
      expect(rec.sessions[1].checkOutTime, returnTime);

      expect(rec.sessions[2].isOffice, isTrue);
      expect(rec.sessions[2].checkInTime, returnTime);
      expect(rec.sessions[2].checkOutTime, '06:30:00 PM');

      expect(rec.hasOverlappingSessions, isFalse);
      // Total = 2h + 3.5h + 3h = 8.5h (30600 seconds)
      expect(rec.computedTotalHours, 8.5);
      expect(rec.totalWorkDurationSeconds, 30600);
      expect(TimeFormatter.formatSecondsToHHmmss(rec.totalWorkDurationSeconds), '08:30:00');
    });

    test('Scenario 6: Completed OD assignment with missing start-time fields (even with planned_start_time set) creates NO synthetic session and flags for admin review', () async {
      await seedEmployee();
      await seedOfficeCheckIn(checkInTime: '10:27:33 AM');

      // Seed a COMPLETED OD with planned_start_time present, but NO verified actual start time
      await fakeFs.collection('on_duty_assignments').doc('506').set({
        'id': 506,
        'employee_id': 10,
        'employee_name': 'Test Employee',
        'date': '18-11-2026',
        'status': 'COMPLETED',
        'purpose': 'POD Submitted Without Start',
        'destination': 'Site E',
        'planned_start_time': '09:00 AM', // Must NOT be used as actual start time
        'actual_start_time': '',
        'travel_start_time': null,
        'work_completed_time': '06:54:09 PM',
        'actual_end_time': '06:54:09 PM',
        'sites': [
          {'site_name': 'Site E', 'status': 'COMPLETED'}
        ],
      });

      // Static helper check: must return null even when planned_start_time exists
      final assignMap = (await fakeFs.collection('on_duty_assignments').doc('506').get()).data()!;
      expect(FirebaseAttendanceRepository.resolveVerifiedOdStartTime(assignMap), isNull);

      // OnDutyAssignment model check: verifiedActualStartTime must be null and never use plannedStartTime
      final parsedOd = OnDutyAssignment.fromMap(assignMap);
      expect(parsedOd.plannedStartTime, '09:00 AM');
      expect(parsedOd.actualStartTime, isNull);
      expect(parsedOd.travelStartTime, isNull);
      expect(parsedOd.verifiedActualStartTime, isNull);

      await attendanceRepo.autoSyncCompletedOdSessions(employeeId: 10);

      // Attendance record must remain untouched (no synthetic OD session inserted)
      final doc = await fakeFs
          .collection('attendance_records')
          .doc('10_20261118')
          .get();
      final rec = AttendanceRecord.fromMap(doc.data()!);
      expect(rec.sessions.length, 1);
      expect(rec.sessions.first.isOffice, isTrue);
      expect(rec.sessions.any((s) => s.isOd), isFalse);

      // Admin review audit flag must be logged in attendance_attempts
      final reviewDoc = await fakeFs
          .collection('attendance_attempts')
          .doc('od_unverified_start_10_20261118_506')
          .get();
      expect(reviewDoc.exists, isTrue);
      expect(
        reviewDoc.data()!['verification_status'],
        'OD Unverified Start Time - Admin Review Required',
      );
      expect(reviewDoc.data()!['assignment_id'], 506);
    });

    test('Scenario 7: Existing historical attendance record with overlapping sessions does NOT double-count hours, keeps raw sessions intact, and flags for admin review', () {
      // Exact scenario from screenshot:
      // On Duty: 08:00:00 -> 18:54:09 (10:54:09)
      // Office:  10:27:33 -> 18:55:16 (08:27:43)
      // Previously summed to 19:21:52. True non-overlapping union: 08:00:00 -> 18:55:16 = 10:55:16 (39316s = 10.92h)
      final historicalRecord = AttendanceRecord(
        id: 2001,
        employeeId: 10,
        employeeCode: 'EMP010',
        employeeName: 'Test Employee',
        date: '2026-11-18',
        time: '10:27:33 AM',
        checkInTime: '10:27:33 AM',
        checkOutTime: '06:55:16 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: const [
          AttendanceSession(
            id: 'session_od_legacy',
            type: 'od',
            checkInTime: '08:00 AM',
            checkOutTime: '18:54:09',
            checkInMethod: 'OD Auto Sync',
            durationMinutes: 654,
            durationHours: 10.9,
          ),
          AttendanceSession(
            id: 'session_office_legacy',
            type: 'office',
            checkInTime: '10:27:33 AM',
            checkOutTime: '06:55:16 PM',
            checkInMethod: 'Face + Geofence',
            durationMinutes: 507,
            durationHours: 8.46,
          ),
        ],
      );

      // Raw historical sessions remain untouched
      expect(historicalRecord.sessions.length, 2);
      expect(historicalRecord.sessions[0].checkInTime, '08:00 AM');
      expect(historicalRecord.sessions[1].checkInTime, '10:27:33 AM');

      // Flagged for admin review
      expect(historicalRecord.hasOverlappingSessions, isTrue);
      expect(historicalRecord.hasUnverifiedOdStartTime, isTrue);
      expect(historicalRecord.requiresAdminTimeReview, isTrue);

      // Work hours deduplicated: 08:00:00 -> 18:55:16 = 10h 55m 16s = 39316s
      expect(historicalRecord.totalWorkDurationSeconds, 39316);
      expect(
        TimeFormatter.formatSecondsToHHmmss(historicalRecord.totalWorkDurationSeconds),
        '10:55:16',
      );
      expect(historicalRecord.computedTotalHours, 10.92);
      expect(historicalRecord.formattedTotalHours, '10hr 55min');
    });

    test('Preserves existing break-counting rules and non-overlapping gaps', () {
      // Office 09:00 -> 13:00 (4h), Lunch 13:00 -> 13:30 (0.5h), Gap 13:30 -> 14:00 (not worked), Office 14:00 -> 18:00 (4h)
      // Total = 4 + 0.5 + 4 = 8.5h (30600s)
      final record = AttendanceRecord(
        id: 2002,
        employeeId: 10,
        employeeName: 'Test Employee',
        date: '2026-11-18',
        time: '09:00:00 AM',
        checkInTime: '09:00:00 AM',
        checkOutTime: '06:00:00 PM',
        status: 'Completed',
        verificationStatus: 'Verified',
        similarityScore: 1.0,
        sessions: const [
          AttendanceSession(
            id: 's1',
            type: 'office',
            checkInTime: '09:00:00 AM',
            checkOutTime: '01:00:00 PM',
          ),
          AttendanceSession(
            id: 's2',
            type: 'lunch',
            checkInTime: '01:00:00 PM',
            checkOutTime: '01:30:00 PM',
          ),
          AttendanceSession(
            id: 's3',
            type: 'office',
            checkInTime: '02:00:00 PM',
            checkOutTime: '06:00:00 PM',
          ),
        ],
      );

      expect(record.hasOverlappingSessions, isFalse);
      expect(record.requiresAdminTimeReview, isFalse);
      expect(record.totalWorkDurationSeconds, 30600);
      expect(record.computedTotalHours, 8.5);
    });

    test('OnDutyAssignment sanitizes empty strings to null and resolves site travel/reached start time', () {
      final od = OnDutyAssignment(
        id: 601,
        employeeId: 10,
        employeeName: 'Test Employee',
        odType: 'Field Work',
        purpose: 'Install',
        destination: 'Site X',
        date: '18-11-2026',
        plannedStartTime: '08:30 AM',
        actualStartTime: '   ',
        travelStartTime: '',
        sites: const [
          OnDutySite(
            siteId: 'site_1',
            siteName: 'Site X',
            destination: 'Site X',
            purpose: 'Install',
            travelStartTime: '11:05:00 AM',
          ),
        ],
        status: 'TRAVELING_TO_DESTINATION',
        assignedBy: 'Admin',
        createdAt: '2026-11-18T10:00:00',
      );

      final map = od.toMap();
      expect(map['actual_start_time'], isNull);
      expect(map['travel_start_time'], isNull);
      expect(od.verifiedActualStartTime, '11:05:00 AM');
    });
  });
}
