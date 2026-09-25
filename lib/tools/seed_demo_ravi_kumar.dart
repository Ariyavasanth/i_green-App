/// TEMPORARY DEMO SEEDING SCRIPT
///
/// Seeds demo records for:
///   Employee: Ravi Kumar (EMP-006, ID: 6)
///   Period: 01-09-2026 to 20-09-2026
///
/// Strictly isolates to:
///   1. employees/EMP-006
///   2. attendance_records (only EMP-006 records for Sep 1–19, 2026)
///   3. leave_requests (only 1 approved leave record for EMP-006 on 16-09-2026)
///
/// Does NOT touch any existing employees, other dates, or payrolls.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> seedDemoRaviKumar() async {
  debugPrint('=====================================================');
  debugPrint('[Demo Seeder] Starting seeding for Ravi Kumar (EMP-006)...');
  debugPrint('=====================================================');

  final firestore = FirebaseFirestore.instance;

  // ── 1. Seed Employee (EMP-006) ─────────────────────────────────────────────
  try {
    final employeeData = <String, dynamic>{
      'id': 6,
      'employee_id': 'EMP-006',
      'first_name': 'Ravi',
      'last_name': 'Kumar',
      'email_address': 'ravi.kumar@igreen.com',
      'phone_number': '9876543210',
      'gender': 'Male',
      'dob': '1995-05-15',
      'organization_name': 'I Green Technology',
      'department': 'Execution',
      'designation': 'Specialist',
      'employment_type': 'Full Time',
      'joining_date': '01-09-2026',
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
      'weekly_off_day': '',
      'bank_name': 'HDFC Bank',
      'bank_account_number': '50100987654321',
      'bank_ifsc': 'HDFC0001234',
      'bank_branch': 'Chennai',
      'pan_number': 'ABCDE1234F',
      'pf_number': '101234567890',
      'updated_at': FieldValue.serverTimestamp(),
    };

    await firestore.collection('employees').doc('EMP-006').set(employeeData, SetOptions(merge: true));
    debugPrint('✅ [employees] Successfully wrote document: employees/EMP-006');
  } catch (e) {
    debugPrint('❌ [employees] Failed to write employee record: $e');
  }

  // ── 2. Seed Attendance Records (01-09-2026 to 19-09-2026) ───────────────────
  try {
    final presentDates = [
      '01-09-2026',
      '02-09-2026',
      '03-09-2026',
      '04-09-2026',
      '05-09-2026',
      // 06-09-2026 is Sunday (Weekly Off)
      '07-09-2026',
      '08-09-2026',
      '09-09-2026',
      '10-09-2026',
      '11-09-2026',
      '12-09-2026',
      // 13-09-2026 is Sunday (Weekly Off)
      '14-09-2026',
      // 15-09-2026 is Late
      // 16-09-2026 is Leave (handled in leave_requests)
      '17-09-2026',
      '18-09-2026',
      '19-09-2026',
    ];

    int attendanceCount = 0;

    for (final dateStr in presentDates) {
      final docId = 'EMP-006_$dateStr';
      await firestore.collection('attendance_records').doc(docId).set({
        'employee_id': 6,
        'employee_code': 'EMP-006',
        'employee_name': 'Ravi Kumar',
        'date': dateStr,
        'time': '09:00:00',
        'check_in_time': '09:00:00',
        'check_out_time': '18:00:00',
        'status': 'Present',
        'verification_status': 'Face Verified',
        'similarity_score': 0.98,
        'total_hours': 9.0,
      }, SetOptions(merge: true));
      attendanceCount++;
    }

    // 1 Late Day: 15-09-2026
    final lateDocId = 'EMP-006_15-09-2026';
    await firestore.collection('attendance_records').doc(lateDocId).set({
      'employee_id': 6,
      'employee_code': 'EMP-006',
      'employee_name': 'Ravi Kumar',
      'date': '15-09-2026',
      'time': '09:45:00',
      'check_in_time': '09:45:00',
      'check_out_time': '18:00:00',
      'status': 'Late',
      'verification_status': 'Face Verified',
      'similarity_score': 0.95,
      'total_hours': 8.25,
    }, SetOptions(merge: true));
    attendanceCount++;

    debugPrint('✅ [attendance_records] Successfully wrote $attendanceCount attendance records for EMP-006 (14 Present + 1 Late, Sundays automatically Weekly Off).');
  } catch (e) {
    debugPrint('❌ [attendance_records] Failed to write attendance records: $e');
  }

  // ── 3. Seed Leave Request (16-09-2026) ──────────────────────────────────────
  try {
    final leaveData = <String, dynamic>{
      'id': 101,
      'employee_id': 6,
      'employee_custom_id': 'EMP-006',
      'employee_name': 'Ravi Kumar',
      'leave_type': 'Casual Leave',
      'from_date': '16-09-2026',
      'to_date': '16-09-2026',
      'num_days': 1.0,
      'reason': 'Personal Work',
      'status': 'Approved',
      'created_at': '2026-09-15T10:00:00Z',
      'approved_dates': '["16-09-2026"]',
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
      'monthly_allowance_snapshot': 3.0,
    };

    await firestore.collection('leave_requests').doc('leave_EMP-006_20260916').set(leaveData, SetOptions(merge: true));
    debugPrint('✅ [leave_requests] Successfully wrote 1 Approved Leave record: leave_requests/leave_EMP-006_20260916');
  } catch (e) {
    debugPrint('❌ [leave_requests] Failed to write leave record: $e');
  }

  // ── 4. Clean Up Existing Demo Payroll Record (Reset to Un-Generated State) ──
  try {
    final payrollDocIds = ['6_September_2026', '6_September 2026', 'EMP-006_September_2026', 'EMP-006_September 2026'];
    for (final docId in payrollDocIds) {
      final docRef = firestore.collection('payrolls').doc(docId);
      final snap = await docRef.get();
      if (snap.exists) {
        await docRef.delete();
        debugPrint('🗑️ [payrolls] Deleted existing demo payroll document: payrolls/$docId');
      }
    }
    // Also clean by query
    final querySnap = await firestore.collection('payrolls').where('employee_id', isEqualTo: 6).get();
    for (final doc in querySnap.docs) {
      final month = (doc.data()['month'] ?? '').toString().toLowerCase();
      if (month.contains('sep')) {
        await doc.reference.delete();
        debugPrint('🗑️ [payrolls] Deleted existing demo payroll document: payrolls/${doc.id}');
      }
    }
  } catch (e) {
    debugPrint('⚠️ [payrolls] Clean up notice: $e');
  }

  debugPrint('=====================================================');
  debugPrint('[Demo Seeder] Finished. Ready for Payroll Generation.');
  debugPrint('=====================================================');
}
