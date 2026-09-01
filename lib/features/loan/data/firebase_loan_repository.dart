import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../domain/employee_loan.dart';
import '../domain/loan_repository.dart';

class FirebaseLoanRepository implements LoanRepository {
  final FirebaseFirestore _firestore;

  FirebaseLoanRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _loansRef =>
      _firestore.collection('employee_loans');

  EmployeeLoan _loanFromFirestore(Map<String, dynamic> map, String docId) {
    final mutableMap = Map<String, dynamic>.from(map);
    if (!mutableMap.containsKey('id') || mutableMap['id'] == null || mutableMap['id'] == 0) {
      mutableMap['id'] = docId.hashCode & 0x7FFFFFFF;
    }
    return EmployeeLoan.fromMap(mutableMap);
  }

  @override
  Future<List<EmployeeLoan>> getAllLoans() async {
    try {
      final snap = await _loansRef.get();
      final list = snap.docs.map((doc) => _loanFromFirestore(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.id.compareTo(a.id));
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<EmployeeLoan>> getLoansForEmployee(int employeeId) async {
    try {
      final snap = await _loansRef.where('employee_id', isEqualTo: employeeId).get();
      final list = snap.docs.map((doc) => _loanFromFirestore(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.id.compareTo(a.id));
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<EmployeeLoan?> getLoanById(int id) async {
    try {
      final snap = await _loansRef.where('id', isEqualTo: id).limit(1).get();
      if (snap.docs.isNotEmpty) {
        return _loanFromFirestore(snap.docs.first.data(), snap.docs.first.id);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<EmployeeLoan?> getLoanByLoanId(String loanId) async {
    try {
      final snap = await _loansRef.where('loan_id', isEqualTo: loanId).limit(1).get();
      if (snap.docs.isNotEmpty) {
        return _loanFromFirestore(snap.docs.first.data(), snap.docs.first.id);
      }
      // Also try direct doc lookup
      final doc = await _loansRef.doc(loanId).get();
      if (doc.exists && doc.data() != null) {
        return _loanFromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<EmployeeLoan?> getActiveLoanForEmployee(int employeeId, String month) async {
    try {
      final snap = await _loansRef
          .where('employee_id', isEqualTo: employeeId)
          .where('status', isEqualTo: 'Active')
          .get();

      if (snap.docs.isEmpty) return null;

      final activeLoans = snap.docs
          .map((d) => _loanFromFirestore(d.data(), d.id))
          .where((loan) => loan.actualRemainingBalance > 0)
          .toList();

      if (activeLoans.isEmpty) return null;

      // Check if there is an active loan matching this deduction month
      for (final loan in activeLoans) {
        if (loan.scheduleMonths.contains(month)) {
          return loan;
        }
      }

      // Default to the first active loan with remaining balance
      return activeLoans.first;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveLoan(EmployeeLoan loan) async {
    try {
      final docId = loan.loanId.isNotEmpty ? loan.loanId : 'loan_${loan.id}';
      final numericId = loan.id != 0 ? loan.id : (docId.hashCode & 0x7FFFFFFF);
      final updatedLoan = loan.copyWith(id: numericId);
      final map = updatedLoan.toMap();
      map['updated_at'] = FieldValue.serverTimestamp();
      await _loansRef.doc(docId).set(map, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> deleteLoan(int id) async {
    try {
      final snap = await _loansRef.where('id', isEqualTo: id).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  @override
  Future<void> updateLoanBalance(String loanId, double deductionAmount) async {
    try {
      final loan = await getLoanByLoanId(loanId);
      if (loan == null) return;

      final newBalance = (loan.actualRemainingBalance - deductionAmount).clamp(0.0, loan.totalRepayableAmount);
      final newStatus = newBalance <= 0.01 ? 'Closed' : loan.status;

      final docId = loan.loanId.isNotEmpty ? loan.loanId : 'loan_${loan.id}';
      await _loansRef.doc(docId).update({
        'remaining_balance': newBalance,
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Future<void> recordRepayment({
    required String loanId,
    required String payrollId,
    required String month,
    required double amount,
    required String paymentDate,
    String referenceNote = '',
  }) async {
    try {
      final loan = await getLoanByLoanId(loanId);
      if (loan == null) return;

      // Idempotency: check if this payroll repayment is already recorded
      final alreadyRecorded = loan.repayments.any(
        (r) => r.payrollId == payrollId || (r.month == month && r.payrollId.isNotEmpty && r.payrollId == payrollId),
      );
      if (alreadyRecorded) {
        return; // Do not deduct twice!
      }

      final newRepayment = LoanRepayment(
        repaymentId: 'REP_${DateTime.now().millisecondsSinceEpoch}',
        payrollId: payrollId,
        month: month,
        amount: amount,
        paymentDate: paymentDate.isNotEmpty ? paymentDate : DateFormat('yyyy-MM-dd').format(DateTime.now()),
        referenceNote: referenceNote.isNotEmpty ? referenceNote : 'Payroll deduction for $month',
        createdAt: DateTime.now().toIso8601String(),
      );

      final updatedRepayments = [...loan.repayments, newRepayment];
      final totalRepaid = updatedRepayments.fold<double>(0.0, (total, r) => total + r.amount);
      final newBalance = (loan.totalRepayableAmount - totalRepaid).clamp(0.0, loan.totalRepayableAmount);
      final newStatus = newBalance <= 0.01 ? 'Closed' : loan.status;

      final docId = loan.loanId.isNotEmpty ? loan.loanId : 'loan_${loan.id}';
      await _loansRef.doc(docId).update({
        'repayments': updatedRepayments.map((r) => r.toMap()).toList(),
        'remaining_balance': newBalance,
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Future<void> changeLoanStatus(int id, String status) async {
    try {
      final snap = await _loansRef.where('id', isEqualTo: id).get();
      for (final doc in snap.docs) {
        await doc.reference.update({
          'status': status,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  @override
  Future<String> approveLoan({
    required int id,
    required String approverName,
    required String approverRole,
  }) async {
    try {
      final loan = await getLoanById(id);
      if (loan == null) return '';

      String nextStatus = 'Approved';
      final roleLower = approverRole.toLowerCase();

      if (loan.status == 'Pending' || loan.status == 'Pending Supervisor') {
        if (roleLower.contains('supervisor')) {
          nextStatus = 'Pending HR';
        } else if (roleLower.contains('hr')) {
          nextStatus = 'Pending MD';
        } else {
          nextStatus = 'Approved';
        }
      } else if (loan.status == 'Pending HR') {
        if (roleLower.contains('hr')) {
          nextStatus = 'Pending MD';
        } else {
          nextStatus = 'Approved';
        }
      } else if (loan.status == 'Pending MD') {
        nextStatus = 'Approved';
      }

      final docId = loan.loanId.isNotEmpty ? loan.loanId : 'loan_${loan.id}';
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _loansRef.doc(docId).update({
        'status': nextStatus,
        'approved_by': approverName,
        'approval_date': todayStr,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return nextStatus;
    } catch (_) {
      return '';
    }
  }

  @override
  Future<void> disburseLoan(int id, String disbursementDate) async {
    try {
      final loan = await getLoanById(id);
      if (loan == null) return;

      final docId = loan.loanId.isNotEmpty ? loan.loanId : 'loan_${loan.id}';
      await _loansRef.doc(docId).update({
        'status': 'Active',
        'disbursement_date': disbursementDate,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Future<void> rejectLoan(int id, String reason) async {
    try {
      final loan = await getLoanById(id);
      if (loan == null) return;

      final docId = loan.loanId.isNotEmpty ? loan.loanId : 'loan_${loan.id}';
      await _loansRef.doc(docId).update({
        'status': 'Rejected',
        'remarks': reason,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
