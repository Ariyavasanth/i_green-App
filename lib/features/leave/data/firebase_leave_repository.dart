import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/leave_request.dart';
import '../domain/leave_repository.dart';
import '../domain/leave_balance.dart';
import '../domain/leave_type.dart';
import '../domain/salary_calculation.dart';
import '../domain/permission_allowance.dart';

/// Full Firestore implementation of LeaveRepository.
/// Collections used:
///   leave_requests, leave_balances, leave_types,
///   loss_of_pay_records, leave_audit_logs
/// To switch back to SQLite: change one line in leave_providers.dart only.
class FirebaseLeaveRepository implements LeaveRepository {
  final FirebaseFirestore _firestore;
  bool _seeded = false; // guard so seeding only runs once per instance

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
  int _deriveId(Map<String, dynamic> data, String docId) {
    final rawId = data['id'];
    if (rawId is int && rawId != 0) return rawId;
    if (rawId is num && rawId.toInt() != 0) return rawId.toInt();

    final digitsOnly = docId.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isNotEmpty) {
      final parsed = int.tryParse(digitsOnly);
      if (parsed != null && parsed != 0) return parsed;
    }
    return (docId.hashCode & 0x7FFFFFFF);
  }

  /// Converts a Firestore document + its ID into a [LeaveRequest].
  LeaveRequest _requestFromDoc(Map<String, dynamic> data, String docId) {
    final mutable = Map<String, dynamic>.from(data);
    mutable['id'] = _deriveId(data, docId);
    return LeaveRequest.fromMap(mutable);
  }

  LeaveBalance _balanceFromDoc(Map<String, dynamic> data, String docId) {
    final mutable = Map<String, dynamic>.from(data);
    mutable['id'] = _deriveId(data, docId);
    return LeaveBalance.fromMap(mutable);
  }

  LeaveType _typeFromDoc(Map<String, dynamic> data, String docId) {
    final mutable = Map<String, dynamic>.from(data);
    mutable['id'] = _deriveId(data, docId);
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
    if (_seeded) return; // already ran this session
    _seeded = true;

    // Purge legacy non-leave-type documents if present
    final legacyNames = ['As Needed', 'Manual Allocation', 'No Leave', 'Monthly Leave'];
    for (final legacy in legacyNames) {
      final docId = legacy.replaceAll(' ', '_').toLowerCase();
      final docRef = _typesRef.doc(docId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.delete();
      }
      final querySnap = await _typesRef.where('name', isEqualTo: legacy).get();
      for (final doc in querySnap.docs) {
        await doc.reference.delete();
      }
    }

    final snap = await _typesRef.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final defaults = [
      const LeaveType(id: 1, name: 'Sick Leave', description: 'Medical leave allowance.', annualAllocation: 10.0, carryForward: 'Not allowed', colorHex: '#14B8A6', isActive: true),
      const LeaveType(id: 2, name: 'Casual Leave', description: 'Standard casual leave allowance.', annualAllocation: 12.0, carryForward: 'Up to 3 days', colorHex: '#6366F1', isActive: true),
      const LeaveType(id: 3, name: 'Annual Leave', description: 'Paid annual leave allowance.', annualAllocation: 15.0, carryForward: 'Up to 10 days', colorHex: '#22C55E', isActive: true),
      const LeaveType(id: 4, name: 'Optional Leave', description: 'Optional / Floating holiday leave.', annualAllocation: 3.0, carryForward: 'Not allowed', colorHex: '#F59E0B', isActive: true),
      const LeaveType(id: 5, name: 'Emergency Leave', description: 'Urgent emergency leave allowance.', annualAllocation: 5.0, carryForward: 'Not allowed', colorHex: '#F43F5E', isActive: true),
      const LeaveType(id: 6, name: 'Work From Home', description: 'Remote work allocation.', annualAllocation: 12.0, carryForward: 'Not allowed', colorHex: '#3B82F6', isActive: true),
      const LeaveType(id: 7, name: 'Comp Off', description: 'Compensatory off for extra work.', annualAllocation: 5.0, carryForward: 'Not allowed', colorHex: '#8B5CF6', isActive: true),
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
    try {
      final snap = await _requestsRef
          .where('employee_id', isEqualTo: employeeId)
          .get();
      final list = snap.docs.map((d) => _requestFromDoc(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<LeaveRequest>> getAllLeaveRequests() async {
    try {
      final snap = await _requestsRef.get();
      final list = snap.docs.map((d) => _requestFromDoc(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequestsForCalendar() async {
    final snap = await _requestsRef.get();
    return snap.docs.map((d) => _requestFromDoc(d.data(), d.id)).toList();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findRequestDoc(int id) async {
    if (id != 0) {
      final snap = await _requestsRef.where('id', isEqualTo: id).limit(1).get();
      if (snap.docs.isNotEmpty) return snap.docs.first;
    }

    // Direct doc ID fallback
    final docDirect = await _requestsRef.doc(id.toString()).get();
    if (docDirect.exists) return docDirect;

    // Fallback searching all docs using exact same derivation formula
    final allSnap = await _requestsRef.get();
    for (final doc in allSnap.docs) {
      if (_deriveId(doc.data(), doc.id) == id) {
        return doc;
      }
    }
    return null;
  }

  @override
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    if (request.leaveType.toLowerCase().startsWith('permission')) {
      await _validatePermissionRequest(request);
    }
    final docRef = _requestsRef.doc();
    final data = Map<String, dynamic>.from(request.toMap());

    final generatedId = request.id != 0
        ? request.id
        : (DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF);
    data['id'] = generatedId;

    // Store lists as native Firestore arrays instead of JSON strings
    data['approved_dates'] = request.approvedDates;
    data['lop_dates'] = request.lopDates;
    data['created_at'] = request.createdAt.isNotEmpty
        ? request.createdAt
        : DateTime.now().toIso8601String();
    data['submitted_at'] = FieldValue.serverTimestamp();

    await docRef.set(data);
  }

  Future<void> _validatePermissionRequest(LeaveRequest request) async {
    final requestedHours = request.numDays * 8;
    if (requestedHours <= 0 || requestedHours > 1.0001) {
      throw Exception('Only up to 1 hour of permission can be taken per day.');
    }
    final requestDate = _parsePermissionDate(request.fromDate);
    final requests = await getLeaveRequests(request.employeeId);
    final active = requests.where((item) =>
        item.leaveType.toLowerCase().startsWith('permission') &&
        (item.status == 'Pending' || item.status == 'Approved'));
    final usedToday = active
        .where((item) => item.fromDate == request.fromDate)
        .fold<double>(0, (sum, item) => sum + item.numDays * 8);
    if (usedToday + requestedHours > 1.0001) {
      throw Exception('The 1-hour permission limit for this day has already been used.');
    }
    final allowance = await getPermissionAllowance(request.employeeId, requestDate);
    if (allowance.usedHours + requestedHours > allowance.monthlyLimitHours + 0.0001) {
      throw Exception('Only 3 hours of permission are available per month.');
    }
  }

  DateTime _parsePermissionDate(String value) {
    final parts = value.split('-');
    if (parts.length == 3) {
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    }
    return DateTime.now();
  }

  @override
  Future<PermissionAllowance> getPermissionAllowance(int employeeId, DateTime month) async {
    final requests = await getLeaveRequests(employeeId);
    final used = requests.where((item) {
      if (!item.leaveType.toLowerCase().startsWith('permission') ||
          (item.status != 'Pending' && item.status != 'Approved')) {
        return false;
      }
      final date = _parsePermissionDate(item.fromDate);
      return date.year == month.year && date.month == month.month;
    }).fold<double>(0, (sum, item) => sum + item.numDays * 8);
    return PermissionAllowance(
      monthlyLimitHours: 3,
      dailyLimitHours: 1,
      usedHours: used,
    );
  }

  // ── Approve / Deny ─────────────────────────────────────────────────────────

  Future<void> _revertPreviousApprovalEffects(LeaveRequest req) async {
    if (req.status != 'Approved') return;

    // 1. Delete previous LOP records for this request
    final lopSnap = await _lopRef.where('leave_request_id', isEqualTo: req.id).get();
    for (final doc in lopSnap.docs) {
      await doc.reference.delete();
    }

    // 2. Restore leave balance if paid leave days were previously approved
    if (req.approvedDates.isNotEmpty) {
      final requestLeaveType = req.leaveType.startsWith('Permission') ? 'Permission' : req.leaveType;
      final balance = await getLeaveBalance(req.employeeId, requestLeaveType);
      final balanceDocRef = await _findBalanceDocRef(req.employeeId, requestLeaveType);

      if (balanceDocRef != null) {
        final double restoredCount = req.approvedDates.length.toDouble();
        final double newUsed = (balance.usedLeaves - restoredCount).clamp(0.0, double.infinity);
        final double newAvailable = (balance.availableLeaves + restoredCount).clamp(0.0, balance.allowedLeaves);

        await balanceDocRef.update({
          'used_leaves': newUsed,
          'available_leaves': newAvailable,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Future<void> approveLeaveRequest(
    int id,
    String adminName, {
    String approvalMode = 'as_calculated',
    String? overrideReason,
  }) async {
    // 1. Find the document
    final doc = await _findRequestDoc(id);
    if (doc == null || !doc.exists || doc.data() == null) {
      throw Exception('Leave request document not found for ID: $id');
    }

    final req = _requestFromDoc(doc.data()!, doc.id);
    await _revertPreviousApprovalEffects(req);

    // 2. Fetch employee details for leave policy and salary
    double grossSalary = 0.0;
    String employeePolicy = 'As Needed';
    final empSnap = await _employeesRef
        .where('id', isEqualTo: req.employeeId)
        .limit(1)
        .get();
    if (empSnap.docs.isNotEmpty) {
      grossSalary =
          (empSnap.docs.first.data()['salary_total_ctc'] as num?)?.toDouble() ??
              0.0;
      final rawPolicy = empSnap.docs.first.data()['leave_type'] as String?;
      if (rawPolicy != null && rawPolicy.isNotEmpty) {
        employeePolicy = rawPolicy;
      }
    }
    final double perDaySalary = grossSalary / 26.0;

    final allDates = _datesBetween(req.fromDate, req.toDate);
    final approvedDates = <String>[];
    final lopDates = <String>[];
    bool isOverride = (approvalMode == 'all_paid' && (employeePolicy == 'Manual Allocation' || employeePolicy == 'No Leave'));

    final batch = _firestore.batch();

    if (employeePolicy == 'As Needed') {
      approvedDates.addAll(allDates);
    } else if (employeePolicy == 'No Leave') {
      if (approvalMode == 'all_paid') {
        approvedDates.addAll(allDates);
        isOverride = true;
      } else {
        lopDates.addAll(allDates);
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
      }
    } else {
      // Manual Allocation
      final requestLeaveType = req.leaveType.startsWith('Permission') ? 'Permission' : req.leaveType;
      final balance = await getLeaveBalance(req.employeeId, requestLeaveType);
      final balanceDocRef = await _findBalanceDocRef(req.employeeId, requestLeaveType);

      if (approvalMode == 'all_paid') {
        approvedDates.addAll(allDates);
        isOverride = true;
        if (balanceDocRef != null) {
          batch.update(balanceDocRef, {
            'used_leaves': balance.usedLeaves + allDates.length,
            'available_leaves': (balance.availableLeaves - allDates.length).clamp(0.0, balance.allowedLeaves),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      } else if (approvalMode == 'all_lop') {
        lopDates.addAll(allDates);
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
      } else {
        double currentAvailable = balance.availableLeaves;
        double currentUsed = balance.usedLeaves;

        for (final d in allDates) {
          if (currentAvailable >= 1.0) {
            currentAvailable -= 1.0;
            currentUsed += 1.0;
            approvedDates.add(d);
          } else {
            lopDates.add(d);
            final lopRef = _lopRef.doc();
            batch.set(lopRef, {
              'employee_id': req.employeeId,
              'leave_request_id': id,
              'date': d,
              'amount': perDaySalary,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        if (balanceDocRef != null) {
          batch.update(balanceDocRef, {
            'used_leaves': currentUsed,
            'available_leaves': currentAvailable,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    // Update leave request
    batch.update(doc.reference, {
      'id': req.id,
      'status': 'Approved',
      'approved_dates': approvedDates,
      'lop_dates': lopDates,
      'is_override': isOverride,
      'override_reason': overrideReason,
      'approved_by': adminName,
      'updated_at': FieldValue.serverTimestamp(),
    });

    final detailText = isOverride
        ? 'Approved all ${allDates.length} day(s) as Paid Leave via Super Admin Override. Reason: ${overrideReason ?? "N/A"}'
        : 'Approved ${allDates.length} day(s): ${approvedDates.length} Paid, ${lopDates.length} LOP';

    final auditRef = _auditRef.doc();
    batch.set(auditRef, {
      'leave_request_id': id,
      'action': 'Approved',
      'performed_by': adminName,
      'timestamp': DateTime.now().toIso8601String(),
      'details': detailText,
    });

    await batch.commit();
  }

  @override
  Future<void> denyLeaveRequest(int id, String adminName) async {
    final doc = await _findRequestDoc(id);
    if (doc == null || !doc.exists || doc.data() == null) {
      throw Exception('Leave request document not found for ID: $id');
    }
    final req = _requestFromDoc(doc.data()!, doc.id);
    await _revertPreviousApprovalEffects(req);

    final docRef = doc.reference;
    final batch = _firestore.batch();

    batch.update(docRef, {
      'id': id,
      'status': 'Denied',
      'approved_dates': [],
      'lop_dates': [],
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

  @override
  Future<void> cancelLeaveRequest(int id, String employeeName) async {
    final doc = await _findRequestDoc(id);
    if (doc == null || !doc.exists || doc.data() == null) {
      throw Exception('Leave request document not found for ID: $id');
    }
    final docRef = doc.reference;

    final batch = _firestore.batch();

    batch.update(docRef, {
      'id': id,
      'status': 'Cancelled',
      'updated_at': FieldValue.serverTimestamp(),
    });

    final auditRef = _auditRef.doc();
    batch.set(auditRef, {
      'leave_request_id': id,
      'action': 'Cancelled',
      'performed_by': employeeName,
      'timestamp': DateTime.now().toIso8601String(),
      'details': 'Leave request cancelled by employee.',
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

    // 1. Check for employee override first
    final overrideSnap = await _overridesRef
        .where('employee_id', isEqualTo: employeeId)
        .where('leave_type', isEqualTo: leaveType)
        .limit(1)
        .get();

    double allowed = 12.0;
    String freq = 'Monthly';
    String effDate = '';

    if (overrideSnap.docs.isNotEmpty) {
      allowed = (overrideSnap.docs.first.data()['override_days'] as num?)?.toDouble() ?? 12.0;
    } else {
      // 2. Check leave_types policy allocation
      final typeDocId = leaveType.replaceAll(' ', '_').toLowerCase();
      final typeSnap = await _typesRef.doc(typeDocId).get();
      if (typeSnap.exists) {
        allowed = (typeSnap.data()?['annual_allocation'] as num?)?.toDouble() ?? 12.0;
      } else {
        final empSnap = await _employeesRef
            .where('id', isEqualTo: employeeId)
            .limit(1)
            .get();
        if (empSnap.docs.isNotEmpty) {
          final empData = empSnap.docs.first.data();
          allowed = (empData['allowed_leaves'] as num?)?.toDouble() ?? 12.0;
          freq = empData['leave_allocation_frequency'] as String? ?? 'Monthly';
          effDate = empData['effective_date'] as String? ?? '';
        }
      }
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
    try {
      await _seedLeaveTypesIfEmpty();
      final snap = await _typesRef.get();
      return snap.docs.map((d) => _typeFromDoc(d.data(), d.id)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> addLeaveType(LeaveType leaveType) async {
    final docId = leaveType.name.replaceAll(' ', '_').toLowerCase();
    await _typesRef.doc(docId).set({
      ...leaveType.toMap(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateLeaveType(LeaveType leaveType) async {
    final docId = leaveType.name.replaceAll(' ', '_').toLowerCase();
    await _typesRef.doc(docId).set(leaveType.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteLeaveType(int id) async {
    final snap = await _typesRef.where('id', isEqualTo: id).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  CollectionReference<Map<String, dynamic>> get _overridesRef =>
      _firestore.collection('leave_employee_overrides');

  @override
  Future<List<Map<String, dynamic>>> getEmployeeOverrides() async {
    final snap = await _overridesRef.get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Future<void> addEmployeeOverride(Map<String, dynamic> override) async {
    await _overridesRef.add({
      ...override,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteEmployeeOverride(int id) async {
    final snap = await _overridesRef.where('id', isEqualTo: id).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
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
