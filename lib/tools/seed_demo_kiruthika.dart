import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Seeds real-time Firestore test data for:
///   Employee: Kiruthika K (EMP-5404, ID: 5404)
///   Period: 21-08-2026 to 20-09-2026
///   Criteria requested:
///     - Multiple Insufficient Hours (IH) days (3 days)
///     - 4 Late check-ins (triggers 0.5 LOP day penalty beyond 3 grace days)
///     - 2 Leave + 1 Leave (3 Approved Paid Leaves)
///     - 4 Absent days (triggers 4 full LOP days)
Future<void> seedDemoKiruthika() async {
  debugPrint('=====================================================');
  debugPrint('[Demo Seeder] Seeding real Firestore data for Kiruthika K (EMP-5404)...');
  debugPrint('=====================================================');

  final firestore = FirebaseFirestore.instance;

  // We support both EMP-5404 (from your active employee list) and EMP-007
  final empCodes = [
    {'id': 5404, 'code': 'EMP-5404', 'name': 'Kiruthika K', 'doc': 'EMP-5404'},
    {'id': 7, 'code': 'EMP-007', 'name': 'Kiruthika Devi', 'doc': 'EMP-007'},
  ];

  for (final emp in empCodes) {
    final empId = emp['id'] as int;
    final empCode = emp['code'] as String;
    final empName = emp['name'] as String;
    final empDoc = emp['doc'] as String;

    // ── 1. Seed / Update Employee Profile ─────────────────────────────────────
    try {
      final employeeData = <String, dynamic>{
        'id': empId,
        'employee_id': empCode,
        'first_name': 'Kiruthika',
        'last_name': empCode == 'EMP-5404' ? 'K' : 'Devi',
        'email_address': 'kiruthika@igreen.com',
        'phone_number': '9876543211',
        'gender': 'Female',
        'dob': '1996-08-20',
        'organization_name': 'I Green Technology',
        'department': 'Operations',
        'designation': 'Executive',
        'employment_type': 'Full Time',
        'joining_date': '01-08-2026',
        'status': 'Active',
        'user_type': 'EMPLOYEE',
        'salary_type': 'Monthly',
        'salary_basic': 30000.0,
        'salary_hra': 15000.0,
        'salary_special_allowance': 15000.0,
        'salary_education_allowance': 0.0,
        'salary_travel_allowance': 0.0,
        'salary_other_allowance': 0.0,
        'salary_pf': 1800.0,
        'salary_tax': 0.0,
        'salary_esi': 0.0,
        'salary_total_ctc': 60000.0,
        'required_working_hours': 9.0,
        'weekly_off_day': 'Sunday',
        'bank_name': 'Axis Bank',
        'bank_account_number': '920010047315999',
        'bank_ifsc': 'UTIB0003876',
        'bank_branch': 'Chennai',
        'pan_number': 'KIRUT1234F',
        'pf_number': '101234567899',
        'esi_number': '',
        'updated_at': FieldValue.serverTimestamp(),
      };

      await firestore.collection('employees').doc(empDoc).set(employeeData, SetOptions(merge: true));
      debugPrint('✅ [employees] Successfully wrote/merged document: employees/$empDoc');
    } catch (e) {
      debugPrint('❌ [employees] Failed to write employee record for $empDoc: $e');
    }

    // ── 2. Seed Attendance Records (21-08-2026 to 20-09-2026) ───────────────────
    try {
      // (A) 4 Absent Days
      final absentDates = [
        '24-08-2026',
        '27-08-2026',
        '04-09-2026',
        '10-09-2026',
      ];
      for (final dateStr in absentDates) {
        await firestore.collection('attendance_records').doc('${empCode}_$dateStr').set({
          'employee_id': empId,
          'employee_code': empCode,
          'employee_name': empName,
          'date': dateStr,
          'time': '',
          'check_in_time': '',
          'check_out_time': '',
          'status': 'Absent',
          'verification_status': 'Unverified',
          'similarity_score': 0.0,
          'total_hours': 0.0,
          'notes': 'Unexcused Absence (LOP)',
        }, SetOptions(merge: true));
      }

      // (B) 4 Late Days (02-09, 03-09, 14-09, 28-08)
      final lateDates = [
        {'date': '22-08-2026', 'time': '09:40:00'},
        {'date': '28-08-2026', 'time': '09:45:00'},
        {'date': '02-09-2026', 'time': '09:35:00'},
        {'date': '14-09-2026', 'time': '09:50:00'},
      ];
      for (final item in lateDates) {
        final dateStr = item['date']!;
        final timeStr = item['time']!;
        await firestore.collection('attendance_records').doc('${empCode}_$dateStr').set({
          'employee_id': empId,
          'employee_code': empCode,
          'employee_name': empName,
          'date': dateStr,
          'time': timeStr,
          'check_in_time': timeStr,
          'check_out_time': '18:45:00',
          'status': 'Late',
          'verification_status': 'Face Verified',
          'similarity_score': 0.95,
          'total_hours': 9.0,
          'notes': 'Late check-in at $timeStr',
        }, SetOptions(merge: true));
      }

      // (C) 3 Insufficient Hours (IH) Days (25-08: 7.5 hrs, 29-08: 8.0 hrs, 08-09: 6.5 hrs)
      final ihDates = [
        {'date': '25-08-2026', 'hours': 7.5, 'out': '16:30:00', 'unauth': 90},
        {'date': '29-08-2026', 'hours': 8.0, 'out': '17:00:00', 'unauth': 60},
        {'date': '08-09-2026', 'hours': 6.5, 'out': '15:30:00', 'unauth': 150},
      ];
      for (final item in ihDates) {
        final dateStr = item['date']! as String;
        final hrs = item['hours']! as double;
        final outTime = item['out']! as String;
        final unauthMins = item['unauth']! as int;
        await firestore.collection('attendance_records').doc('${empCode}_$dateStr').set({
          'employee_id': empId,
          'employee_code': empCode,
          'employee_name': empName,
          'date': dateStr,
          'time': '09:00:00',
          'check_in_time': '09:00:00',
          'check_out_time': outTime,
          'status': 'Insufficient hours',
          'verification_status': 'Face Verified',
          'similarity_score': 0.96,
          'total_hours': hrs,
          'notes': 'Worked $hrs hrs (Insufficient hours, $unauthMins mins unauthorized)',
        }, SetOptions(merge: true));
      }

      // (D) Regular Present Days (9.0 hrs completed)
      final regularDates = [
        '21-08-2026', // Cycle Start
        '26-08-2026',
        '03-09-2026',
        '05-09-2026',
        '07-09-2026',
        '09-09-2026',
        '11-09-2026',
        '12-09-2026',
        '17-09-2026',
        '18-09-2026',
        '19-09-2026',
        '20-09-2026', // Cycle End
      ];
      for (final dateStr in regularDates) {
        await firestore.collection('attendance_records').doc('${empCode}_$dateStr').set({
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
          'notes': 'Worked 9.0 hrs (Completed shift)',
        }, SetOptions(merge: true));
      }

      debugPrint('✅ [attendance_records] Successfully seeded attendance for $empCode ($empName).');
    } catch (e) {
      debugPrint('❌ [attendance_records] Failed to write attendance for $empCode: $e');
    }

    // ── 3. Seed Approved Leave Requests (2 Days Casual Leave + 1 Day Sick Leave) ──
    try {
      // 2 Days Casual Leave: 31-08-2026 to 01-09-2026
      await firestore.collection('leave_requests').doc('leave_${empCode}_20260831').set({
        'id': 201 + empId,
        'employee_id': empId,
        'employee_custom_id': empCode,
        'employee_name': empName,
        'leave_type': 'Casual Leave',
        'from_date': '31-08-2026',
        'to_date': '01-09-2026',
        'num_days': 2.0,
        'reason': 'Family function',
        'status': 'Approved',
        'created_at': '2026-08-29T10:00:00Z',
        'approved_dates': '["31-08-2026", "01-09-2026"]',
        'lop_dates': '[]',
        'is_emergency': 0,
        'is_half_day': 0,
        'is_override': 0,
        'requested_days': 2.0,
        'calculated_paid_days': 2.0,
        'calculated_lop_days': 0.0,
        'paid_days': 2.0,
        'lop_days': 0.0,
        'approval_mode': 'calculated',
      }, SetOptions(merge: true));

      // 1 Day Sick Leave: 15-09-2026
      await firestore.collection('leave_requests').doc('leave_${empCode}_20260915').set({
        'id': 202 + empId,
        'employee_id': empId,
        'employee_custom_id': empCode,
        'employee_name': empName,
        'leave_type': 'Sick Leave',
        'from_date': '15-09-2026',
        'to_date': '15-09-2026',
        'num_days': 1.0,
        'reason': 'Medical emergency',
        'status': 'Approved',
        'created_at': '2026-09-14T10:00:00Z',
        'approved_dates': '["15-09-2026"]',
        'lop_dates': '[]',
        'is_emergency': 0,
        'is_half_day': 0,
        'is_override': 0,
        'requested_days': 1.0,
        'calculated_paid_days': 1.0,
        'calculated_lop_days': 0.0,
        'paid_days': 1.0,
        'lop_days': 0.0,
        'approval_mode': 'calculated',
      }, SetOptions(merge: true));

      debugPrint('✅ [leave_requests] Successfully wrote 2 Approved Leave requests for $empCode ($empName).');
    } catch (e) {
      debugPrint('❌ [leave_requests] Failed to write leave requests for $empCode: $e');
    }

    // ── 4. Clean up any prior generated payroll record ────────────────────────
    try {
      final querySnap = await firestore.collection('payrolls').where('employee_id', isEqualTo: empId).get();
      for (final doc in querySnap.docs) {
        final month = (doc.data()['month'] ?? '').toString().toLowerCase();
        if (month.contains('sep')) {
          await doc.reference.delete();
          debugPrint('🗑️ [payrolls] Deleted existing demo payroll document for $empCode: payrolls/${doc.id}');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [payrolls] Clean up notice: $e');
    }
  }

  debugPrint('=====================================================');
  debugPrint('[Demo Seeder] Finished seeding Kiruthika K (EMP-5404).');
  debugPrint('=====================================================');
}
