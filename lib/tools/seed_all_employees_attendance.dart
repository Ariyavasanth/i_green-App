import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Seeds / updates all employees in Firestore:
/// 1. Updates `joining_date` to '20-08-2026' for all employees EXCEPT Super Admin, Ravi Kumar, and Kiruthika.
/// 2. Sets 'Present' attendance records for all employees across August and September 2026 (excluding weekly offs / Sundays).
Future<void> syncEmployeeJoiningAndAttendance() async {
  debugPrint('=====================================================');
  debugPrint('[Attendance Sync] Starting sync of employee joining dates and attendance...');
  debugPrint('=====================================================');

  final firestore = FirebaseFirestore.instance;

  try {
    final employeesSnap = await firestore.collection('employees').get();
    debugPrint('[Attendance Sync] Found ${employeesSnap.docs.length} employee documents.');

    // List of known employees in case Firestore is being populated for the first time
    final knownEmployees = [
      {
        'id': 1,
        'doc': 'FMP-001',
        'code': 'FMP-001',
        'name': 'Super Admin',
        'first_name': 'Super',
        'last_name': 'Admin',
        'email': 'admin@igreen.com',
        'joining_date': '01-01-2025',
        'is_admin': true,
      },
      {
        'id': 6,
        'doc': 'EMP-006',
        'code': 'EMP-006',
        'name': 'Ravi Kumar',
        'first_name': 'Ravi',
        'last_name': 'Kumar',
        'email': 'ravi.kumar@igreen.com',
        'joining_date': '01-08-2026',
        'is_admin': false,
      },
      {
        'id': 5403,
        'doc': 'EMP-5403',
        'code': 'EMP-5403',
        'name': 'Sandya K',
        'first_name': 'Sandya',
        'last_name': 'K',
        'email': 'sandya@igreen.com',
        'joining_date': '20-08-2026',
        'is_admin': false,
      },
      {
        'id': 5404,
        'doc': 'EMP-5404',
        'code': 'EMP-5404',
        'name': 'Kiruthika K',
        'first_name': 'Kiruthika',
        'last_name': 'K',
        'email': 'kiruthika@igreen.com',
        'joining_date': '01-08-2026',
        'is_admin': false,
      },
      {
        'id': 5405,
        'doc': 'EMP-5405',
        'code': 'EMP-5405',
        'name': 'Dummy Testing',
        'first_name': 'Dummy',
        'last_name': 'Testing',
        'email': 'dummy@igreen.com',
        'joining_date': '20-08-2026',
        'is_admin': false,
      },
      {
        'id': 5406,
        'doc': 'EMP-5406',
        'code': 'EMP-5406',
        'name': 'Nithya Sri J',
        'first_name': 'Nithya Sri',
        'last_name': 'J',
        'email': 'nithya@igreen.com',
        'joining_date': '20-08-2026',
        'is_admin': false,
      },
      {
        'id': 5407,
        'doc': 'EMP-5407',
        'code': 'EMP-5407',
        'name': 'Sam J',
        'first_name': 'Sam',
        'last_name': 'J',
        'email': 'sam@igreen.com',
        'joining_date': '20-08-2026',
        'is_admin': false,
      },
      {
        'id': 5408,
        'doc': 'EMP-5408',
        'code': 'EMP-5408',
        'name': 'Thanigavel E',
        'first_name': 'Thanigavel',
        'last_name': 'E',
        'email': 'thanigavel@igreen.com',
        'joining_date': '20-08-2026',
        'is_admin': false,
      },
      {
        'id': 5409,
        'doc': 'EMP-5409',
        'code': 'EMP-5409',
        'name': 'Priya M',
        'first_name': 'Priya',
        'last_name': 'M',
        'email': 'priya@igreen.com',
        'joining_date': '20-08-2026',
        'is_admin': false,
      },
    ];

    bool isExcludedJoiningDate(String code, String name, int id) {
      final c = code.trim().toUpperCase();
      final n = name.trim().toLowerCase();
      if (c == 'FMP-001' || c.contains('SUPER') || n.contains('super admin') || id == 1) {
        return true;
      }
      if (c == 'EMP-006' || c == 'EMP-06' || c == 'EMP-6' || n.contains('ravi') || id == 6) {
        return true;
      }
      if (c == 'EMP-5404' || c == 'EMP-007' || c == 'EMP-07' || c == 'EMP-7' || n.contains('kiruthika') || id == 5404 || id == 7) {
        return true;
      }
      return false;
    }

    WriteBatch batch = firestore.batch();
    int opCount = 0;

    Future<void> flushBatchIfNeeded() async {
      if (opCount >= 400) {
        await batch.commit();
        batch = firestore.batch();
        opCount = 0;
      }
    }

    // 1. Process all existing employee documents in Firestore
    final processedCodes = <String>{};
    for (final doc in employeesSnap.docs) {
      final data = doc.data();
      final docId = doc.id.trim();
      final empCode = (data['employee_id'] ?? docId).toString().trim();
      final empName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
      final empId = data['id'] is int ? data['id'] as int : (int.tryParse(data['id']?.toString() ?? '') ?? 0);

      processedCodes.add(empCode.toUpperCase());
      processedCodes.add(docId.toUpperCase());

      // If NOT Super Admin, Ravi Kumar, or Kiruthika -> set joining_date to 20-08-2026
      if (!isExcludedJoiningDate(empCode, empName, empId)) {
        batch.set(doc.reference, {
          'joining_date': '20-08-2026',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        opCount++;
        await flushBatchIfNeeded();
      }
    }

    // 2. Ensure known employees are created/updated if not present
    for (final ke in knownEmployees) {
      final docId = ke['doc'] as String;
      final empCode = ke['code'] as String;
      final empName = ke['name'] as String;
      final empId = ke['id'] as int;
      final jDate = ke['joining_date'] as String;

      if (!processedCodes.contains(docId.toUpperCase()) && !processedCodes.contains(empCode.toUpperCase())) {
        final ref = firestore.collection('employees').doc(docId);
        batch.set(ref, {
          'id': empId,
          'employee_id': empCode,
          'first_name': ke['first_name'],
          'last_name': ke['last_name'],
          'email_address': ke['email'],
          'phone_number': '9876543210',
          'gender': 'Male',
          'dob': '1995-01-01',
          'organization_name': 'I Green Technology',
          'department': 'Operations',
          'designation': 'Executive',
          'employment_type': 'Full Time',
          'joining_date': jDate,
          'status': 'Active',
          'user_type': (ke['is_admin'] as bool) ? 'SUPER_ADMIN' : 'EMPLOYEE',
          'salary_type': 'Monthly',
          'salary_basic': 30000.0,
          'salary_hra': 15000.0,
          'salary_special_allowance': 15000.0,
          'salary_pf': 1800.0,
          'salary_total_ctc': 60000.0,
          'required_working_hours': 9.0,
          'weekly_off_day': 'Sunday',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        opCount++;
        await flushBatchIfNeeded();
      }
    }

    // 3. Generate Present Attendance Records for ALL Employees
    // Date range: 20-08-2026 to 30-09-2026
    final List<DateTime> datesToSeed = [];
    // August 2026 (20th to 31st)
    for (int day = 20; day <= 31; day++) {
      datesToSeed.add(DateTime(2026, 8, day));
    }
    // September 2026 (1st to 30th)
    for (int day = 1; day <= 30; day++) {
      datesToSeed.add(DateTime(2026, 9, day));
    }

    // Fetch fresh list of all employees to generate attendance for
    final allEmpSnap = await firestore.collection('employees').get();
    int totalAttendanceRecords = 0;

    for (final doc in allEmpSnap.docs) {
      final data = doc.data();
      final docId = doc.id.trim();
      final empCode = (data['employee_id'] ?? docId).toString().trim();
      final firstName = (data['first_name'] ?? '').toString().trim();
      final lastName = (data['last_name'] ?? '').toString().trim();
      final empName = '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName'.trim() : empCode;
      final empId = data['id'] is int ? data['id'] as int : (int.tryParse(data['id']?.toString() ?? '') ?? 0);
      final rawJoiningDate = (data['joining_date'] ?? '').toString().trim();
      final weeklyOff = (data['weekly_off_day'] ?? 'Sunday').toString().trim().toLowerCase();

      // Parse employee's joining date
      DateTime? joiningDate;
      if (rawJoiningDate.isNotEmpty) {
        try {
          final parts = rawJoiningDate.split('-');
          if (parts.length == 3) {
            joiningDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        } catch (_) {}
      }

      for (final dt in datesToSeed) {
        final dayName = DateFormat('EEEE').format(dt).toLowerCase();
        final isSunday = dt.weekday == DateTime.sunday || dayName == weeklyOff;

        // Skip weekly off days (Sundays) so they are rendered as 'WO'
        if (isSunday) continue;

        // If date is before employee's joining date, skip so it renders as 'BJ'
        if (joiningDate != null && dt.isBefore(DateTime(joiningDate.year, joiningDate.month, joiningDate.day))) {
          continue;
        }

        // Exclude EMP-5407 for Sep 1 to Sep 5, 2026
        final isEmp5407 = empCode.toUpperCase().contains('5407') || empId == 5407 || empName.toLowerCase().contains('sam');
        if (isEmp5407 && dt.year == 2026 && dt.month == 9 && dt.day >= 1 && dt.day <= 5) {
          continue;
        }

        final dateStr = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
        final attDocRef = firestore.collection('attendance_records').doc('${empCode}_$dateStr');

        batch.set(attDocRef, {
          'employee_id': empId,
          'employee_code': empCode,
          'employee_name': empName,
          'date': dateStr,
          'time': '09:00:00',
          'check_in_time': '09:00:00',
          'check_out_time': '18:00:00',
          'status': 'Present',
          'verification_status': 'Face Verified',
          'similarity_score': 0.98,
          'total_hours': 9.0,
          'notes': 'Present (Full Shift 9.0 hrs)',
        }, SetOptions(merge: true));

        opCount++;
        totalAttendanceRecords++;
        await flushBatchIfNeeded();
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }

    // 4. Exhaustively delete attendance records for EMP-5407 for Sep 1 to Sep 5, 2026
    try {
      final targets = [
        '01-09-2026', '02-09-2026', '03-09-2026', '04-09-2026', '05-09-2026',
        '1-9-2026', '2-9-2026', '3-9-2026', '4-9-2026', '5-9-2026',
        '2026-09-01', '2026-09-02', '2026-09-03', '2026-09-04', '2026-09-05',
        '01/09/2026', '02/09/2026', '03/09/2026', '04/09/2026', '05/09/2026',
        '1/9/2026', '2/9/2026', '3/9/2026', '4/9/2026', '5/9/2026',
      ];

      // Direct doc ID deletions
      for (final prefix in ['EMP-5407', '5407', 'EMP5407', 'emp-5407', 'emp5407']) {
        for (final d in targets) {
          final docRef = firestore.collection('attendance_records').doc('${prefix}_$d');
          final snap = await docRef.get();
          if (snap.exists) {
            await docRef.delete();
            debugPrint('🗑️ [attendance_records] Deleted record: ${docRef.id}');
          }
        }
      }

      // Query and delete any matching documents in attendance_records
      final attSnap = await firestore.collection('attendance_records').get();
      for (final doc in attSnap.docs) {
        final data = doc.data();
        final eCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
        final eName = (data['employee_name'] ?? '').toString().trim().toLowerCase();
        final eId = data['employee_id'] is int
            ? data['employee_id'] as int
            : (int.tryParse(data['employee_id']?.toString() ?? '') ?? 0);
        final docId = doc.id.toUpperCase();

        final matchesEmp = eCode.contains('5407') || eId == 5407 || eName.contains('sam') ||
            docId.contains('5407');

        if (matchesEmp) {
          final rawDate = (data['date'] ?? '').toString().trim();
          bool isTargetSepDate = targets.contains(rawDate);

          for (final t in targets) {
            if (docId.endsWith(t.toUpperCase())) {
              isTargetSepDate = true;
              break;
            }
          }

          if (!isTargetSepDate && rawDate.isNotEmpty) {
            try {
              final parsed = DateTime.tryParse(rawDate);
              if (parsed != null && parsed.year == 2026 && parsed.month == 9 && parsed.day >= 1 && parsed.day <= 5) {
                isTargetSepDate = true;
              } else {
                final parts = rawDate.replaceAll('/', '-').split('-');
                if (parts.length == 3) {
                  int y = int.tryParse(parts[2]) ?? 0;
                  int m = int.tryParse(parts[1]) ?? 0;
                  int d = int.tryParse(parts[0]) ?? 0;
                  if (y == 2026 && m == 9 && d >= 1 && d <= 5) {
                    isTargetSepDate = true;
                  }
                }
              }
            } catch (_) {}
          }

          if (isTargetSepDate) {
            await doc.reference.delete();
            debugPrint('🗑️ [attendance_records] Deleted record for EMP-5407: ${doc.id}');
          }
        }
      }

      // Delete any matching attendance_attempts
      final attemptSnap = await firestore.collection('attendance_attempts').get();
      for (final doc in attemptSnap.docs) {
        final data = doc.data();
        final eCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
        final eId = data['employee_id'] is int
            ? data['employee_id'] as int
            : (int.tryParse(data['employee_id']?.toString() ?? '') ?? 0);
        final docId = doc.id.toUpperCase();

        final matchesEmp = eCode.contains('5407') || eId == 5407 || docId.contains('5407');

        if (matchesEmp) {
          final rawDate = (data['date'] ?? '').toString().trim();
          if (targets.contains(rawDate) || rawDate.contains('09-2026') || rawDate.contains('2026-09')) {
            await doc.reference.delete();
            debugPrint('🗑️ [attendance_attempts] Deleted attempt for EMP-5407: ${doc.id}');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [attendance_records] Error deleting EMP-5407 records: $e');
    }

    // 5. Reset/Delete any generated payroll records for EMP-5406 and EMP-5407 so status becomes "Not Generated"
    try {
      final payrollSnap = await firestore.collection('payrolls').get();
      for (final doc in payrollSnap.docs) {
        final data = doc.data();
        final empId = data['employee_id'];
        final docId = doc.id;
        if (empId == 5406 || docId.startsWith('5406_') || docId.startsWith('EMP-5406_') || docId.startsWith('EMP5406_') ||
            empId == 5407 || docId.startsWith('5407_') || docId.startsWith('EMP-5407_') || docId.startsWith('EMP5407_')) {
          await doc.reference.delete();
          debugPrint('🗑️ [payrolls] Deleted payroll document to reset status to Not Generated: $docId');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [payrolls] Payroll reset notice: $e');
    }

    debugPrint('✅ [attendance_records] Successfully created/updated $totalAttendanceRecords Present records across all employees.');
    debugPrint('=====================================================');
    debugPrint('[Attendance Sync] Completed successfully.');
    debugPrint('=====================================================');
  } catch (e, st) {
    debugPrint('❌ [Attendance Sync] Error during sync: $e\n$st');
  }
}
