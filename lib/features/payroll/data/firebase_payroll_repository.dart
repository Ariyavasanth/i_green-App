import 'package:cloud_firestore/cloud_firestore.dart';
import '../../loan/data/firebase_loan_repository.dart';
import '../../loan/domain/employee_loan.dart';
import '../../loan/domain/loan_repository.dart';
import '../domain/payroll.dart';
import '../domain/payroll_repository.dart';

class FirebasePayrollRepository implements PayrollRepository {
  final FirebaseFirestore _firestore;
  final LoanRepository? _loanRepository;

  FirebasePayrollRepository({FirebaseFirestore? firestore, LoanRepository? loanRepository})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _loanRepository = loanRepository {
    _seedDataIfNeeded();
  }

  CollectionReference<Map<String, dynamic>> get _payrollsRef =>
      _firestore.collection('payrolls');

  CollectionReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('payroll_settings');

  // Seed default settings and mock payroll records if they don't exist
  // Errors are silently ignored — the app still works with fallback defaults.
  Future<void> _seedDataIfNeeded() async {
    try {
      // Ensure a settings document exists
      final settingsDoc = await _settingsRef.doc('settings_1').get();
      if (!settingsDoc.exists) {
        await _settingsRef.doc('settings_1').set(const PayrollSettings().toMap());
      }

      // Seed payroll records only once
      final existing = await _payrollsRef
          .where('employee_name', isEqualTo: 'Ganesh Chandra Das')
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        // Record matching screenshot (June 2026)
        await _payrollsRef.doc('6_June_2026').set({
          'employee_id': 6,
          'employee_name': 'Ganesh Chandra Das',
          'month': 'June 2026',
          'present_days': 27,
          'late_days': 0,
          'absent_days': 0,
          'leave_days': 3,
          'designation': 'Bore Path Specialist',
          'department': 'Execution',
          'email_id': 'ganeshsavita8056338@gmail.com',
          'pan_number': 'ANAPG6040R',
          'pf_number': '101325736568',
          'esi_number': '',
          'bank_name': 'Axis Bank',
          'bank_acct_no': '920010047315532',
          'branch': 'Ram Nagar Madipakkam',
          'ifsc_code': 'UTIB0003876',
          'basic_pay': 33500.0,
          'hra': 16750.0,
          'education_allowance': 0.0,
          'special_allowance': 16750.0,
          'travel_allowance': 0.0,
          'other_allowance': 0.0,
          'incentive': 8880.0,
          'carry_forward': '-',
          'others_earning': 3000.0,
          'cumulative_incentive': 31067.0,
          'bonus': 0.0,
          'ot': 0.0,
          'pf': 1800.0,
          'tax': 0.0,
          'esi': 0.0,
          'lop': 0.0,
          'company_loan': 20000.0,
          'salary_advance': 12200.0,
          'others_deduction': 3392.0,
          'staff_welfare_contribution': 0.0,
          'greeting': 0.0,
          'net_salary': 72555.0,
          'status': 'Paid',
          'payment_date': '21-07-2026',
          'payment_method': 'Bank Transfer',
          'period_start_date': '20-06-2026',
          'period_end_date': '20-07-2026',
          'processing_date': '21-07-2026',
          'loan_description': '',
          'advance_description': '',
          'is_disputed': 0,
          'dispute_comment': '',
        });

        // Additional mock record (Ariya Vasanth) for completeness
        await _payrollsRef.doc('101_June_2026').set({
          'employee_id': 101,
          'employee_name': 'Ariya Vasanth',
          'month': 'June 2026',
          'present_days': 26,
          'late_days': 2,
          'absent_days': 0,
          'leave_days': 2,
          'designation': 'Senior Flutter Engineer',
          'department': 'Product Development',
          'email_id': 'ariya@example.com',
          'pan_number': 'ABCDE1234F',
          'pf_number': '100827364512',
          'esi_number': '3109827364',
          'bank_name': 'HDFC Bank',
          'bank_acct_no': '50100234567890',
          'branch': 'Adyar Chennai',
          'ifsc_code': 'HDFC0000005',
          'basic_pay': 35000.0,
          'hra': 15000.0,
          'education_allowance': 0.0,
          'special_allowance': 8000.0,
          'travel_allowance': 0.0,
          'other_allowance': 0.0,
          'incentive': 2000.0,
          'carry_forward': '-',
          'others_earning': 0.0,
          'cumulative_incentive': 0.0,
          'bonus': 0.0,
          'ot': 0.0,
          'pf': 4200.0,
          'tax': 2500.0,
          'esi': 0.0,
          'lop': 0.0,
          'company_loan': 0.0,
          'salary_advance': 0.0,
          'others_deduction': 200.0,
          'staff_welfare_contribution': 0.0,
          'greeting': 0.0,
          'net_salary': 53100.0,
          'status': 'Paid',
          'payment_date': '21-07-2026',
          'payment_method': 'Bank Transfer',
          'period_start_date': '20-06-2026',
          'period_end_date': '20-07-2026',
          'processing_date': '21-07-2026',
          'loan_description': '',
          'advance_description': '',
          'is_disputed': 0,
          'dispute_comment': '',
        });
      }
    } catch (_) {
      // Firestore unavailable (e.g. no internet). Skip seeding — defaults will
      // be returned by getPayrollSettings() and getPayrollRecordsForMonth().
    }
  }


  // Helper: map doc data to PayrollRecord
  PayrollRecord _recordFromFirestore(Map<String, dynamic> map, String docId) {
    final mutableMap = Map<String, dynamic>.from(map);
    if (!mutableMap.containsKey('id') || mutableMap['id'] == null || mutableMap['id'] == 0) {
      mutableMap['id'] = docId.hashCode & 0x7FFFFFFF;
    }
    return PayrollRecord.fromMap(mutableMap);
  }

  @override
  Future<List<PayrollRecord>> getPayrollRecordsForMonth(String month) async {
    try {
      final snap = await _payrollsRef.where('month', isEqualTo: month).get();
      return snap.docs.map((doc) => _recordFromFirestore(doc.data(), doc.id)).toList();
    } catch (_) {
      return [];
    }
  }


  @override
  Future<List<PayrollRecord>> getAllPayrollRecords() async {
    try {
      final snap = await _payrollsRef.get();
      return snap.docs.map((doc) => _recordFromFirestore(doc.data(), doc.id)).toList();
    } catch (_) {
      return [];
    }
  }


  @override
  Future<PayrollRecord?> getPayrollRecordById(int id) async {
    try {
      final snap = await _payrollsRef.where('id', isEqualTo: id).get();
      if (snap.docs.isNotEmpty) {
        return _recordFromFirestore(snap.docs.first.data(), snap.docs.first.id);
      }

      // Fallback: search all docs by computed id
      final allSnap = await _payrollsRef.get();
      for (final doc in allSnap.docs) {
        final rec = _recordFromFirestore(doc.data(), doc.id);
        if (rec.id == id) {
          return rec;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }


  @override
  Future<PayrollRecord?> getPayrollRecordForEmployee(int employeeId, String month) async {
    try {
      final snap = await _payrollsRef
          .where('employee_id', isEqualTo: employeeId)
          .where('month', isEqualTo: month)
          .get();
      if (snap.docs.isEmpty) return null;
      return _recordFromFirestore(snap.docs.first.data(), snap.docs.first.id);
    } catch (_) {
      return null;
    }
  }


  @override
  Future<PayrollRecord> savePayrollRecord(PayrollRecord record) async {
    final docId = '${record.employeeId}_${record.month.replaceAll(' ', '_')}';
    
    // Check if existing record is already PAID in Firestore -> REJECT ALL MUTATIONS
    try {
      final existingDoc = await _payrollsRef.doc(docId).get();
      if (existingDoc.exists && existingDoc.data() != null) {
        final existingStatus = (existingDoc.data()!['status'] as String? ?? '').trim().toUpperCase();
        if (existingStatus == 'PAID') {
          throw Exception('This payroll record has been marked as PAID and is locked against all changes.');
        }
      }
    } catch (e) {
      if (e.toString().contains('locked against all changes')) {
        rethrow;
      }
    }

    try {
      final map = record.toMap();
      final numericId = record.id != 0 ? record.id : (docId.hashCode & 0x7FFFFFFF);
      map['id'] = numericId;
      map['updated_at'] = FieldValue.serverTimestamp();
      await _payrollsRef.doc(docId).set(map, SetOptions(merge: true));

      // Record loan repayment if status is Paid and companyLoan > 0
      if (record.status.trim().toUpperCase() == 'PAID' && record.companyLoan > 0) {
        try {
          final loanRepo = _loanRepository ?? FirebaseLoanRepository(firestore: _firestore);
          EmployeeLoan? targetLoan;
          if (record.loanDescription.isNotEmpty) {
            targetLoan = await loanRepo.getLoanByLoanId(record.loanDescription.trim());
          }
          targetLoan ??= await loanRepo.getActiveLoanForEmployee(record.employeeId, record.month);

          if (targetLoan != null) {
            await loanRepo.recordRepayment(
              loanId: targetLoan.loanId,
              payrollId: docId,
              month: record.month,
              amount: record.companyLoan,
              paymentDate: record.paymentDate,
              referenceNote: 'Payroll deduction for ${record.month}',
            );
          }
        } catch (_) {}
      }

      return record.copyWith(id: numericId);
    } catch (_) {
      return record;
    }
  }


  @override
  Future<void> deletePayrollRecord(int id) async {
    try {
      final snap = await _payrollsRef.where('id', isEqualTo: id).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }


  @override
  Future<PayrollSettings> getPayrollSettings() async {
    try {
      final doc = await _settingsRef.doc('settings_1').get();
      if (!doc.exists || doc.data() == null) {
        const defaults = PayrollSettings();
        try { await savePayrollSettings(defaults); } catch (_) {}
        return defaults;
      }
      return PayrollSettings.fromMap(doc.data()!);
    } catch (_) {
      // Firestore unavailable — return hardcoded defaults so the UI still loads
      return const PayrollSettings();
    }
  }


  @override
  Future<void> savePayrollSettings(PayrollSettings settings) async {
    try {
      await _settingsRef.doc('settings_1').set(settings.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }


  @override
  Future<List<PayrollRecord>> getPayrollRecordsForEmployee(int employeeId) async {
    try {
      final snap = await _payrollsRef.where('employee_id', isEqualTo: employeeId).get();
      final list = snap.docs.map((doc) => _recordFromFirestore(doc.data(), doc.id)).toList();
      list.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.paymentDate.isNotEmpty ? a.paymentDate.split('-').reversed.join('-') : '1970-01-01');
          final dateB = DateTime.parse(b.paymentDate.isNotEmpty ? b.paymentDate.split('-').reversed.join('-') : '1970-01-01');
          return dateB.compareTo(dateA);
        } catch (_) {
          return b.id.compareTo(a.id);
        }
      });
      return list;
    } catch (_) {
      return [];
    }
  }

}
