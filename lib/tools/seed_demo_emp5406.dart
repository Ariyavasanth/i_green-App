import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Seeds real-time Firestore test data ONLY for Employee 5406 (EMP-5406 - Nithya Sri J):
///   - Profile with CTC ₹60,000, 9-hour shift, Sunday weekly off
///   - Present days (9 hrs full)
///   - Insufficient Hours days (5.5 hrs worked, 3.5 hrs shortfall each)
///   - Absent / Full LOP days (9.0 hrs shortfall each)
///   - Late arrivals
///   - Weekly Offs (Sundays)
Future<void> seedDemoEmp5406() async {
  debugPrint('=====================================================');
  debugPrint('[Demo Seeder] Seeding Firestore test data ONLY for Employee 5406 (EMP-5406)...');
  debugPrint('=====================================================');

  final firestore = FirebaseFirestore.instance;

  const empId = 5406;
  const empCode = 'EMP-5406';
  const empName = 'Nithya Sri J';
  const empDoc = 'EMP-5406';

  // ── 1. Seed / Update Employee Profile ─────────────────────────────────────
  try {
    final employeeData = <String, dynamic>{
      'id': empId,
      'employee_id': empCode,
      'first_name': 'Nithya Sri',
      'last_name': 'J',
      'email_address': 'nithya@igreen.com',
      'phone_number': '9876543216',
      'gender': 'Female',
      'dob': '1998-04-12',
      'organization_name': 'IGREEN TECHNOLOGIES',
      'department': 'Execution',
      'designation': 'Junior Engineer',
      'employment_type': 'Full Time',
      'joining_date': '20-08-2026',
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
      'bank_name': 'HDFC Bank',
      'bank_account_number': '50100987654306',
      'bank_ifsc': 'HDFC0001234',
      'bank_branch': 'Chennai',
      'pan_number': 'NITHY1234J',
      'pf_number': '101234567806',
      'esi_number': '',
      'updated_at': FieldValue.serverTimestamp(),
    };

    await firestore.collection('employees').doc(empDoc).set(employeeData, SetOptions(merge: true));
    debugPrint('✅ [employees] Successfully saved profile: employees/$empDoc');
  } catch (e) {
    debugPrint('❌ [employees] Failed to write employee record for $empDoc: $e');
  }

  // ── 2. Seed Attendance Records for Cycle Periods ─────────────────────────────
  try {
    // September 2026 cycle (21-08-2026 to 20-09-2026)
    final sepAbsentDates = ['28-08-2026', '08-09-2026'];
    final sepInsufficientDates = ['02-09-2026', '15-09-2026'];
    final sepLateDates = ['25-08-2026', '11-09-2026'];
    final sepSundayDates = ['23-08-2026', '30-08-2026', '06-09-2026', '13-09-2026', '20-09-2026'];
    final sepPresentDates = [
      '21-08-2026', '22-08-2026', '24-08-2026', '26-08-2026', '27-08-2026', '29-08-2026', '31-08-2026',
      '01-09-2026', '03-09-2026', '04-09-2026', '05-09-2026', '07-09-2026', '09-09-2026', '10-09-2026',
      '12-09-2026', '14-09-2026', '16-09-2026', '17-09-2026', '18-09-2026', '19-09-2026',
    ];

    // October 2026 cycle (21-09-2026 to 20-10-2026)
    final octAbsentDates = ['29-09-2026', '07-10-2026'];
    final octInsufficientDates = ['02-10-2026', '14-10-2026'];
    final octLateDates = ['24-09-2026', '09-10-2026'];
    final octSundayDates = ['27-09-2026', '04-10-2026', '11-10-2026', '18-10-2026'];
    final octPresentDates = [
      '21-09-2026', '22-09-2026', '23-09-2026', '25-09-2026', '26-09-2026', '28-09-2026', '30-09-2026',
      '01-10-2026', '03-10-2026', '05-10-2026', '06-10-2026', '08-10-2026', '10-10-2026',
      '12-10-2026', '13-10-2026', '15-10-2026', '16-10-2026', '17-10-2026', '19-10-2026', '20-10-2026',
    ];

    Future<void> saveRecord(String dateStr, Map<String, dynamic> data) async {
      await firestore.collection('attendance_records').doc('${empCode}_$dateStr').set(data, SetOptions(merge: true));
      await firestore.collection('attendance_records').doc('${empId}_$dateStr').set(data, SetOptions(merge: true));
    }

    // (A) Absent / LOP Days (9.0 hrs shortfall each)
    for (final dateStr in [...sepAbsentDates, ...octAbsentDates]) {
      await saveRecord(dateStr, {
        'id': 0,
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
        'required_hours': 9.0,
        'notes': 'Unexcused Absence (Full LOP Day)',
        'marked_at': '${dateStr.split('-').reversed.join('-')}T09:00:00',
        'sessions': [],
      });
    }

    // (B) Insufficient Hours Days (5.5 hrs worked, 3.5 hrs shortfall each)
    for (final dateStr in [...sepInsufficientDates, ...octInsufficientDates]) {
      final inIso = '${dateStr.split('-').reversed.join('-')}T09:00:00';
      final outIso = '${dateStr.split('-').reversed.join('-')}T14:30:00';
      await saveRecord(dateStr, {
        'id': 0,
        'employee_id': empId,
        'employee_code': empCode,
        'employee_name': empName,
        'date': dateStr,
        'time': '09:00:00',
        'check_in_time': '09:00:00',
        'check_out_time': '14:30:00',
        'status': 'Insufficient Hours',
        'verification_status': 'Verified',
        'similarity_score': 0.95,
        'check_in_verification_status': 'Verified',
        'check_out_verification_status': 'Verified',
        'check_in_similarity_score': 0.95,
        'check_out_similarity_score': 0.94,
        'total_hours': 5.5,
        'required_hours': 9.0,
        'scheduled_in_time': '09:00',
        'scheduled_out_time': '18:00',
        'notes': 'Insufficient Hours - Early departure at 14:30 (3.5 hrs shortfall)',
        'marked_at': inIso,
        'sessions': [
          {
            'session_id': 'sess_${empId}_${dateStr}_1',
            'type': 'Office',
            'check_in_time': inIso,
            'check_out_time': outIso,
            'duration_minutes': 330,
            'verification_status': 'Verified',
            'similarity_score': 0.95,
            'status': 'Completed',
          }
        ],
      });
    }

    // (C) Late Arrivals (8.4 hrs worked, counted Late)
    for (final dateStr in [...sepLateDates, ...octLateDates]) {
      final inIso = '${dateStr.split('-').reversed.join('-')}T09:35:00';
      final outIso = '${dateStr.split('-').reversed.join('-')}T18:00:00';
      await saveRecord(dateStr, {
        'id': 0,
        'employee_id': empId,
        'employee_code': empCode,
        'employee_name': empName,
        'date': dateStr,
        'time': '09:35:00',
        'check_in_time': '09:35:00',
        'check_out_time': '18:00:00',
        'status': 'Late',
        'verification_status': 'Verified',
        'similarity_score': 0.96,
        'check_in_verification_status': 'Verified',
        'check_out_verification_status': 'Verified',
        'check_in_similarity_score': 0.96,
        'check_out_similarity_score': 0.95,
        'total_hours': 8.42,
        'required_hours': 9.0,
        'scheduled_in_time': '09:00',
        'scheduled_out_time': '18:00',
        'notes': 'Late arrival (checked in at 09:35 AM)',
        'marked_at': inIso,
        'sessions': [
          {
            'session_id': 'sess_${empId}_${dateStr}_1',
            'type': 'Office',
            'check_in_time': inIso,
            'check_out_time': outIso,
            'duration_minutes': 505,
            'verification_status': 'Verified',
            'similarity_score': 0.96,
            'status': 'Completed',
          }
        ],
      });
    }

    // (D) Weekly Offs (Sundays)
    for (final dateStr in [...sepSundayDates, ...octSundayDates]) {
      await saveRecord(dateStr, {
        'id': 0,
        'employee_id': empId,
        'employee_code': empCode,
        'employee_name': empName,
        'date': dateStr,
        'time': '',
        'check_in_time': '',
        'check_out_time': '',
        'status': 'Weekly Off',
        'verification_status': 'System',
        'similarity_score': 1.0,
        'total_hours': 0.0,
        'required_hours': 0.0,
        'notes': 'Sunday Weekly Off',
        'marked_at': '${dateStr.split('-').reversed.join('-')}T00:00:00',
        'sessions': [],
      });
    }

    // (E) Regular Present Days (9.0 hrs worked)
    for (final dateStr in [...sepPresentDates, ...octPresentDates]) {
      final inIso = '${dateStr.split('-').reversed.join('-')}T09:00:00';
      final outIso = '${dateStr.split('-').reversed.join('-')}T18:00:00';
      await saveRecord(dateStr, {
        'id': 0,
        'employee_id': empId,
        'employee_code': empCode,
        'employee_name': empName,
        'date': dateStr,
        'time': '09:00:00',
        'check_in_time': '09:00:00',
        'check_out_time': '18:00:00',
        'status': 'Present',
        'verification_status': 'Verified',
        'similarity_score': 0.97,
        'check_in_verification_status': 'Verified',
        'check_out_verification_status': 'Verified',
        'check_in_similarity_score': 0.97,
        'check_out_similarity_score': 0.97,
        'total_hours': 9.0,
        'required_hours': 9.0,
        'scheduled_in_time': '09:00',
        'scheduled_out_time': '18:00',
        'notes': 'Full 9.0 hrs Office Attendance',
        'marked_at': inIso,
        'sessions': [
          {
            'session_id': 'sess_${empId}_${dateStr}_1',
            'type': 'Office',
            'check_in_time': inIso,
            'check_out_time': outIso,
            'duration_minutes': 540,
            'verification_status': 'Verified',
            'similarity_score': 0.97,
            'status': 'Completed',
          }
        ],
      });
    }

    debugPrint('✅ [attendance_records] Successfully seeded all attendance records for Employee 5406!');
  } catch (e) {
    debugPrint('❌ [attendance_records] Error seeding attendance for Employee 5406: $e');
  }

  // ── 3. Seed Active Loan for Employee 5406 (EMP-5406) with Flexible EMI ──
  try {
    final loanData = <String, dynamic>{
      'id': 540601,
      'loan_id': 'LN-5406',
      'employee_id': empId,
      'employee_name': empName,
      'employee_custom_id': empCode,
      'department': 'Execution',
      'designation': 'Junior Engineer',
      'loan_type': 'Personal Loan',
      'loan_amount': 20000.0,
      'loan_date': '2026-09-25',
      'disbursement_date': '2026-09-28',
      'purpose': 'Personal Emergency Support',
      'installments': 12,
      'original_installments': 12,
      'emi_amount': 1667.0,
      'first_deduction_month': 'October 2026',
      'last_deduction_month': 'September 2027',
      'interest_rate': 0.0,
      'total_repayable_amount': 20000.0,
      'requested_by': empName,
      'approved_by': 'Admin',
      'approval_date': '2026-09-26',
      'remarks': 'Approved personal loan with 12 months tenure',
      'status': 'Active',
      'remaining_balance': 20000.0,
      'repayments': [],
      'pause_requests': [
        {
          'request_id': 'REQ-5406-01',
          'loan_id': 'LN-5406',
          'employee_id': empId,
          'employee_name': empName,
          'month': 'October 2026',
          'reason': 'Financial hardship',
          'status': 'Approved',
          'requested_at': '2026-10-01T10:00:00Z',
          'reviewed_by': 'Administrator',
          'reviewed_at': '2026-10-02T10:00:00Z',
          'admin_remarks': 'Approved partial flexible EMI of ₹833',
          'is_recovered': false,
          'request_type': 'Flexible',
          'requested_amount': 833.0,
          'approved_amount': 833.0,
        }
      ],
    };

    await firestore.collection('employee_loans').doc('LN-5406').set(loanData, SetOptions(merge: true));
    debugPrint('✅ [employee_loans] Successfully seeded Active Loan with Flexible EMI for Employee 5406: LN-5406');
  } catch (e) {
    debugPrint('❌ [employee_loans] Error seeding loan for Employee 5406: $e');
  }

  // ── 4. Clean up any existing Payroll doc for Employee 5406 so status is "Not Generated" ──
  try {
    final payrollSnap = await firestore.collection('payrolls').get();
    for (final doc in payrollSnap.docs) {
      final data = doc.data();
      final eId = data['employee_id'];
      final eCode = data['employee_code'] ?? data['employee_id_raw'];
      final docId = doc.id;
      if (eId == empId || eCode == empCode || docId.startsWith('${empId}_') || docId.startsWith('${empCode}_') || docId.startsWith('EMP${empId}_')) {
        await doc.reference.delete();
        debugPrint('🗑️ [payrolls] Cleared previous payroll record for EMP-5406: $docId');
      }
    }
  } catch (e) {
    debugPrint('⚠️ [payrolls] Payroll reset notice: $e');
  }

  debugPrint('=====================================================');
  debugPrint('[Demo Seeder] All seed operations for Employee 5406 completed.');
  debugPrint('=====================================================');
}
