import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/leave_request.dart';
import '../domain/leave_repository.dart';
import '../domain/leave_balance.dart';
import '../domain/leave_type.dart';
import '../domain/salary_calculation.dart';

/// Full Firestore implementation of LeaveRepository.
/// Collections used:
///   leave_requests, leave_balances, leave_types,
///   loss_of_pay_records, leave_audit_logs
/// To switch back to SQLite: change one line in leave_providers.dart only.
class FirebaseLeaveRepository implements LeaveRepository {
  final FirebaseFirestore _firestore;

  FirebaseLeaveRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Collection references ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('leave_requests');

  CollectionReference<Map<String, dynamic>> get _balancesRef =>
      _firestore.collection('leave_balances');

  CollectionReference<Map<String, dynamic>> get _typesRef =>
      _firestore.collection('leave_types');

  CollectionReference<Map<String, dynamic>> get _lopRef =>
      _firestore.collection('loss_of_pay_records');

  CollectionReference<Map<String, dynamic>> get _auditRef =>
      _firestore.collection('leave_audit_logs');

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Converts a Firestore document + its ID into a [LeaveRequest].
  LeaveRequest _requestFromDoc(Map<String, dynamic> data, String docId) {
    final mutable = Map<String, dynamic>.from(data);

    // Firestore auto-ID docs may not have an integer `id` — derive from docId
    if (!mutable.containsKey('id') || mutable['id'] == null || mutable['id'] == 0) {
      final parsed = int.tryParse(docId.replaceAll(RegExp(r'\D'), ''));
      mutable['id'] = (parsed != null && parsed != 0)
          ? parsed
          : (docId.hashCode & 0x7FFFFFFF);
    }
    return LeaveRequest.fromMap(mutable);
  }

  LeaveBalance _balanceFromDoc(Map<String, dynamic> data, String docId) {
    final mutable = Map<String, dynamic>.from(data);
    if (!mutable.containsKey('id') || mutable['id'] == null || mutable['id'] == 0) {
      final parsed = int.tryParse(docId.replaceAll(RegExp(r'\D'), ''));
      mutable['id'] = (parsed != null && parsed != 0)
          ? parsed
          : (docId.hashCode & 0x7FFFFFFF);
    }
    return LeaveBalance.fromMap(mutable);
  }

  LeaveType _typeFromDoc(Map<String, dynamic> data, String docId) {
    final mutable = Map<String, dynamic>.from(data);
    if (!mutable.containsKey('id') || mutable['id'] == null || mutable['id'] == 0) {
      final parsed = int.tryParse(docId.replaceAll(RegExp(r'\D'), ''));
      mutable['id'] = (parsed != null && parsed != 0)
          ? parsed
          : (docId.hashCode & 0x7FFFFFFF);
    }
    return LeaveType.fromMap(mutable);
  }

  /// Converts dd-MM-yyyy string to DateTime (returns null on failure).
  DateTime? _parseDate(String s) {
    try {
      final p = s.split('-');
      if (p.length != 3) return null;
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return null;
    }
  }

  /// Returns all dates (as dd-MM-yyyy strings) between [fromStr] and [toStr].
  List<String> _datesBetween(String fromStr, String toStr) {
    final from = _parseDate(fromStr);
    final to = _parseDate(toStr);
    if (from == null || to == null) return [fromStr];
    final list = <String>[];
    var curr = from;
    while (!curr.isAfter(to)) {
      final d = curr.day.toString().padLeft(2, '0');
      final m = curr.month.toString().padLeft(2, '0');
      list.add('$d-$m-${curr.year}');
      curr = curr.add(const Duration(days: 1));
    }
    return list;
  }

  // ── Seed helpers ───────────────────────────────────────────────────────────

  Future<void> _seedLeaveTypesIfEmpty() async {
    final snap = await _typesRef.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final defaults = [
      LeaveType(id: 1, name: 'As Needed', description: 'You can take leave whenever required.'),
      LeaveType(id: 2, name: 'Manual Allocation', description: 'Leave is allocated manually per policy.'),
      LeaveType(id: 3, name: 'No Leave', description: 'You are not eligible to take leave.'),
    ];

    final batch = _firestore.batch();
    for (final lt in defaults) {
      final docRef = _typesRef.doc(lt.name.replaceAll(' ', '_').toLowerCase());
      batch.set(docRef, {
        ...lt.toMap(),
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ── Leave Requests ─────────────────────────────────────────────────────────

  @override
  Future<List<LeaveRequest>> getLeaveRequests(int employeeId) async {
    final snap = await _requestsRef
        .where('employee_id', isEqualTo: employeeId)
        .get();
    final list = snap.docs.map((d) => _requestFromDoc(d.data(), d.id)).toList();
    // Sort client-side — avoids requiring a Firestore composite index
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<LeaveRequest>> getAllLeaveRequests() async {
    final snap = await _requestsRef.get();
    final list = snap.docs.map((d) => _requestFromDoc(d.data(), d.id)).toList();
    // Sort client-side — avoids requiring a Firestore composite index
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequestsForCalendar() async {
    final snap = await _requestsRef.get();
    return snap.docs.map((d) => _requestFromDoc(d.data(), d.id)).toList();
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    final docRef = _requestsRef.doc();
    final data = Map<String, dynamic>.from(request.toMap());

    // Store lists as native Firestore arrays instead of JSON strings
    data['approved_dates'] = request.approvedDates;
    data['lop_dates'] = request.lopDates;
    data['created_at'] = request.createdAt.isNotEmpty
        ? request.createdAt
        : DateTime.now().toIso8601String();
    data['submitted_at'] = FieldValue.serverTimestamp();

    await docRef.set(data);
  }

  // ── Approve / Deny ─────────────────────────────────────────────────────────

  @override
  Future<void> approveLeaveRequest(int id, String adminName) async {
    // 1. Find the document
    QuerySnapshot<Map<String, dynamic>> snap;
    if (id != 0) {
      snap = await _requestsRef.where('id', isEqualTo: id).limit(1).get();
    } else {
      snap = await _requestsRef.limit(0).get(); // empty
    }

    DocumentSnapshot<Map<String, dynamic>> doc;
    if (snap.docs.isNotEmpty) {
      doc = snap.docs.first;
    } else {
      // Fallback: try docId == id.toString()
      doc = await _requestsRef.doc(id.toString()).get();
      if (!doc.exists) return;
    }

    final req = _requestFromDoc(doc.data()!, doc.id);
    if (req.status != 'Pending') return;

    // 2. Fetch employee salary and leave permission type for LOP calculation
    double grossSalary = 0.0;
    String employeeLeavePermissionType = 'As Needed';
    final empSnap = await _employeesRef
        .where('id', isEqualTo: req.employeeId)
        .limit(1)
        .get();
    if (empSnap.docs.isNotEmpty) {
      grossSalary =
          (empSnap.docs.first.data()['salary_total_ctc'] as num?)?.toDouble() ??
              0.0;
      employeeLeavePermissionType =
          empSnap.docs.first.data()['leave_type'] as String? ?? 'As Needed';
    }
    final double perDaySalary = grossSalary / 26.0;

    // 3. Fetch leave balance using the employee's leave permission type (not the request category)
    final balance = await getLeaveBalance(req.employeeId, employeeLeavePermissionType);

    // 4. Split dates into approved vs LOP
    final allDates = _datesBetween(req.fromDate, req.toDate);
    final approvedDates = <String>[];
    final lopDates = <String>[];
    double currentAvailable = balance.availableLeaves;
    double currentUsed = balance.usedLeaves;

    for (final d in allDates) {
      if (currentAvailable >= 1.0) {
        currentAvailable -= 1.0;
        currentUsed += 1.0;
        approvedDates.add(d);
      } else {
        lopDates.add(d);
      }
    }

    // 5. Batch write everything atomically
    final batch = _firestore.batch();

    // Update leave request
    batch.update(doc.reference, {
      'status': 'Approved',
      'approved_dates': approvedDates,
      'lop_dates': lopDates,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Update leave balance
    final balanceDocRef = await _findBalanceDocRef(req.employeeId, employeeLeavePermissionType);
    if (balanceDocRef != null) {
      batch.update(balanceDocRef, {
        'used_leaves': currentUsed,
        'available_leaves': currentAvailable,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    // Insert LOP records
    for (final d in lopDates) {
      final lopRef = _lopRef.doc();
      batch.set(lopRef, {
        'employee_id': req.employeeId,
        'leave_request_id': id,
        'date': d,
        'amount': perDaySalary,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // Insert audit log
    final auditRef = _auditRef.doc();
    batch.set(auditRef, {
      'leave_request_id': id,
      'action': 'Approved',
      'performed_by': adminName,
      'timestamp': DateTime.now().toIso8601String(),
      'details':
          'Approved ${allDates.length} day(s): ${approvedDates.length} Paid, ${lopDates.length} LOP',
    });

    await batch.commit();
  }

  @override
  Future<void> denyLeaveRequest(int id, String adminName) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    if (id != 0) {
      snap = await _requestsRef.where('id', isEqualTo: id).limit(1).get();
    } else {
      snap = await _requestsRef.limit(0).get();
    }

    DocumentReference<Map<String, dynamic>> docRef;
    if (snap.docs.isNotEmpty) {
      docRef = snap.docs.first.reference;
    } else {
      docRef = _requestsRef.doc(id.toString());
    }

    final batch = _firestore.batch();

    batch.update(docRef, {
      'status': 'Denied',
      'updated_at': FieldValue.serverTimestamp(),
    });

    final auditRef = _auditRef.doc();
    batch.set(auditRef, {
      'leave_request_id': id,
      'action': 'Denied',
      'performed_by': adminName,
      'timestamp': DateTime.now().toIso8601String(),
      'details': 'Leave request denied.',
    });

    await batch.commit();
  }

  // ── Leave Balances ─────────────────────────────────────────────────────────

  @override
  Future<List<LeaveBalance>> getLeaveBalances(int employeeId) async {
    final snap = await _balancesRef
        .where('employee_id', isEqualTo: employeeId)
        .get();
    return snap.docs.map((d) => _balanceFromDoc(d.data(), d.id)).toList();
  }

  @override
  Future<LeaveBalance> getLeaveBalance(int employeeId, String leaveType) async {
    final snap = await _balancesRef
        .where('employee_id', isEqualTo: employeeId)
        .where('leave_type', isEqualTo: leaveType)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      return _balanceFromDoc(snap.docs.first.data(), snap.docs.first.id);
    }

    // Auto-create balance from employee settings
    double allowed = 1.0;
    String freq = 'Monthly';
    String effDate = '';

    final empSnap = await _employeesRef
        .where('id', isEqualTo: employeeId)
        .limit(1)
        .get();
    if (empSnap.docs.isNotEmpty) {
      final empData = empSnap.docs.first.data();
      allowed = (empData['allowed_leaves'] as num?)?.toDouble() ?? 1.0;
      freq = empData['leave_allocation_frequency'] as String? ?? 'Monthly';
      effDate = empData['effective_date'] as String? ?? '';
    }

    final newBalance = LeaveBalance(
      id: 0,
      employeeId: employeeId,
      leaveType: leaveType,
      allowedLeaves: allowed,
      usedLeaves: 0.0,
      availableLeaves: allowed,
      effectiveDate: effDate,
      allocationFrequency: freq,
    );

    // Persist the new balance
    final docRef = _balancesRef
        .doc('${employeeId}_${leaveType.replaceAll(' ', '_').toLowerCase()}');
    await docRef.set({
      ...newBalance.toMap(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final createdSnap = await docRef.get();
    return _balanceFromDoc(createdSnap.data()!, createdSnap.id);
  }

  /// Helper: find the DocumentReference for a balance by employee+leaveType.
  Future<DocumentReference<Map<String, dynamic>>?> _findBalanceDocRef(
      int employeeId, String leaveType) async {
    // Try deterministic doc ID first
    final docId =
        '${employeeId}_${leaveType.replaceAll(' ', '_').toLowerCase()}';
    final directDoc = await _balancesRef.doc(docId).get();
    if (directDoc.exists) return directDoc.reference;

    // Fall back to query
    final snap = await _balancesRef
        .where('employee_id', isEqualTo: employeeId)
        .where('leave_type', isEqualTo: leaveType)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.reference;
    return null;
  }

  // ── Leave Types ────────────────────────────────────────────────────────────

  @override
  Future<List<LeaveType>> getLeaveTypes() async {
    await _seedLeaveTypesIfEmpty();
    final snap = await _typesRef.get();
    return snap.docs.map((d) => _typeFromDoc(d.data(), d.id)).toList();
  }

  @override
  Future<void> addLeaveType(LeaveType leaveType) async {
    final docId = leaveType.name.replaceAll(' ', '_').toLowerCase();
    await _typesRef.doc(docId).set({
      ...leaveType.toMap(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Salary / LOP Calculation ───────────────────────────────────────────────

  @override
  Future<SalaryCalculation> calculateSalaryAndLop(
    int employeeId,
    int year,
    int month, {
    int workingDays = 26,
  }) async {
    // 1. Fetch employee salary
    double grossSalary = 0.0;
    final empSnap = await _employeesRef
        .where('id', isEqualTo: employeeId)
        .limit(1)
        .get();
    if (empSnap.docs.isNotEmpty) {
      grossSalary =
          (empSnap.docs.first.data()['salary_total_ctc'] as num?)?.toDouble() ??
              0.0;
    }

    final double perDaySalary =
        workingDays > 0 ? (grossSalary / workingDays) : 0.0;

    // 2. Count LOP records for this employee in the given month/year
    final lopSnap = await _lopRef
        .where('employee_id', isEqualTo: employeeId)
        .get();

    final monthStr = month.toString().padLeft(2, '0');
    final suffix = '-$monthStr-$year';

    double totalLopDays = 0;
    for (final doc in lopSnap.docs) {
      final date = doc.data()['date'] as String? ?? '';
      if (date.endsWith(suffix)) totalLopDays++;
    }

    // 3. Count approved leave days in that month/year
    final leaveSnap = await _requestsRef
        .where('employee_id', isEqualTo: employeeId)
        .where('status', isEqualTo: 'Approved')
        .get();

    double approvedDaysCount = 0;
    for (final doc in leaveSnap.docs) {
      final req = _requestFromDoc(doc.data(), doc.id);
      for (final date in req.approvedDates) {
        if (date.endsWith(suffix)) approvedDaysCount++;
      }
    }

    final double lopDeduction = perDaySalary * totalLopDays;
    final double payableSalary = grossSalary - lopDeduction;

    return SalaryCalculation(
      grossMonthlySalary: grossSalary,
      totalWorkingDays: workingDays,
      perDaySalary: perDaySalary,
      totalApprovedLeaveDays: approvedDaysCount,
      totalLopDays: totalLopDays,
      lopDeductionAmount: lopDeduction,
      finalPayableSalary: payableSalary,
    );
  }

  // ── Audit Logs ─────────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getAuditLogs(int leaveRequestId) async {
    final snap = await _auditRef
        .where('leave_request_id', isEqualTo: leaveRequestId)
        .get();
    final list = snap.docs.map((d) => d.data()).toList();
    // Sort client-side — avoids requiring a Firestore composite index
    list.sort((a, b) {
      final ta = a['timestamp'] as String? ?? '';
      final tb = b['timestamp'] as String? ?? '';
      return tb.compareTo(ta);
    });
    return list;
  }
}
