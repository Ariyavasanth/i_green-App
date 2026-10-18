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
    _ensureSettings();
  }

  CollectionReference<Map<String, dynamic>> get _payrollsRef =>
      _firestore.collection('payrolls');

  CollectionReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('payroll_settings');

  // Ensure default settings exist if absent without fabricating mock records
  Future<void> _ensureSettings() async {
    try {
      final settingsDoc = await _settingsRef.doc('settings_1').get();
      if (!settingsDoc.exists) {
        await _settingsRef.doc('settings_1').set(const PayrollSettings().toMap());
      }
    } catch (_) {
      // Firestore unavailable. Settings defaults will be returned by getPayrollSettings().
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
    
    // Check if existing record is already PAID or PROCESSED in Firestore -> REJECT ALL MUTATIONS
    try {
      DocumentSnapshot<Map<String, dynamic>>? existingDoc = await _payrollsRef.doc(docId).get();
      Map<String, dynamic>? data = existingDoc.exists ? existingDoc.data() : null;

      if (data == null && record.id != 0) {
        final snap = await _payrollsRef.where('id', isEqualTo: record.id).get();
        if (snap.docs.isNotEmpty) {
          existingDoc = snap.docs.first;
          data = snap.docs.first.data();
        }
      }

      if (data != null) {
        final existingStatus = (data['status'] as String? ?? '').trim().toUpperCase();
        if (existingStatus == 'PAID') {
          throw Exception('This payroll record has been marked as PAID and is locked against all changes.');
        }

        if (existingStatus == 'PROCESSED') {
          final incomingStatus = record.status.trim().toUpperCase();
          final isExplicitPaidTransition = incomingStatus == 'PAID';
          if (!isExplicitPaidTransition) {
            throw Exception('This payroll record has been marked as PROCESSED and is locked against all changes.');
          }
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
            final match = RegExp(r'LN\d+').firstMatch(record.loanDescription);
            final loanIdToFind = match != null ? match.group(0)! : record.loanDescription.trim();
            targetLoan = await loanRepo.getLoanByLoanId(loanIdToFind);
          }
          targetLoan ??= await loanRepo.getActiveLoanForEmployee(record.employeeId, record.month);

          if (targetLoan != null) {
            // Check if this deduction recovered a deferred EMI pause
            final unrecovered = targetLoan.getUnrecoveredDeferredRequestBefore(record.month);
            if (unrecovered != null) {
              await loanRepo.markPauseRequestRecovered(
                loanId: targetLoan.loanId,
                requestId: unrecovered.requestId,
              );
            }

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
        final status = (doc.data()['status'] as String? ?? '').trim().toUpperCase();
        if (status == 'PAID' || status == 'PROCESSED') {
          throw Exception('Payroll record $id has status $status and is locked against deletion.');
        }
        await doc.reference.delete();
      }
    } catch (e) {
      if (e.toString().contains('locked against deletion')) {
        rethrow;
      }
    }
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
