import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/incentive_payout_ledger.dart';
import '../domain/incentive_repository.dart';
import '../domain/incentive_request.dart';
import '../domain/incentive_settings.dart';

class FirebaseIncentiveRepository implements IncentiveRepository {
  FirebaseIncentiveRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('incentive_requests');

  CollectionReference<Map<String, dynamic>> get _payoutLedgers =>
      _firestore.collection('incentive_payout_ledgers');

  DocumentReference<Map<String, dynamic>> get _settings =>
      _firestore.collection('incentive_settings').doc('global');

  int _id(Map<String, dynamic> data, String documentId) {
    final value = data['id'];
    if (value is num && value.toInt() > 0) return value.toInt();
    return documentId.hashCode & 0x7FFFFFFF;
  }

  IncentiveRequest _request(Map<String, dynamic> source, String documentId) {
    final data = Map<String, dynamic>.from(source);
    data['id'] = _id(data, documentId);
    if (data['created_at'] is Timestamp) {
      data['created_at'] =
          (data['created_at'] as Timestamp).toDate().toIso8601String();
    }
    return IncentiveRequest.fromMap(data);
  }

  IncentivePayoutLedger _ledger(Map<String, dynamic> source, String documentId) {
    final data = Map<String, dynamic>.from(source);
    if (data['created_at'] is Timestamp) {
      data['created_at'] =
          (data['created_at'] as Timestamp).toDate().toIso8601String();
    }
    if (data['released_at'] is Timestamp) {
      data['released_at'] =
          (data['released_at'] as Timestamp).toDate().toIso8601String();
    }
    return IncentivePayoutLedger.fromMap(data, documentId);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _find(int id) async {
    final query = await _requests.where('id', isEqualTo: id).limit(1).get();
    if (query.docs.isNotEmpty) return query.docs.first;
    final direct = await _requests.doc(id.toString()).get();
    return direct.exists ? direct : null;
  }

  @override
  Future<List<IncentiveRequest>> getAllRequests() async {
    final snapshot = await _requests.get();
    final result = snapshot.docs
        .map((document) => _request(document.data(), document.id))
        .toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Stream<List<IncentiveRequest>> watchAllRequests() {
    return _requests.snapshots().map((snapshot) {
      final result = snapshot.docs
          .map((document) => _request(document.data(), document.id))
          .toList();
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    });
  }

  @override
  Future<List<IncentiveRequest>> getRequestsByEmployeeName(String employeeName) async {
    final snapshot = await _requests
        .where('employee_name', isEqualTo: employeeName)
        .get();
    final result = snapshot.docs
        .map((document) => _request(document.data(), document.id))
        .toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<IncentiveRequest?> getRequestById(int id) async {
    final document = await _find(id);
    final data = document?.data();
    return data == null ? null : _request(data, document!.id);
  }

  @override
  Future<void> createRequest(IncentiveRequest request) async {
    final data = Map<String, dynamic>.from(request.toMap());
    data['id'] =
        request.id ?? (DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF);
    data['updated_at'] = FieldValue.serverTimestamp();
    await _requests.doc().set(data);
  }

  @override
  Future<void> cancelRequest(int id) async {
    final document = await _find(id);
    if (document == null || document.data()?['status'] != 'Pending') return;
    await document.reference.update({
      'status': 'Cancelled',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateRequest(IncentiveRequest request) async {
    if (request.id == null) return;
    final document = await _find(request.id!);
    if (document == null || document.data()?['status'] != 'Pending') return;
    final data = Map<String, dynamic>.from(request.toMap());
    data['updated_at'] = FieldValue.serverTimestamp();
    await document.reference.set(data, SetOptions(merge: true));
  }

  @override
  Future<void> updateRequestStatus(
    int id,
    String status, {
    double? verifiedMeters,
    double? approvedAmount,
  }) async {
    final document = await _find(id);
    if (document == null) return;
    final data = <String, dynamic>{
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (verifiedMeters != null) data['verified_meters'] = verifiedMeters;
    if (approvedAmount != null) data['approved_amount'] = approvedAmount;
    await document.reference.update(data);
  }

  @override
  Future<IncentiveSettings> getIncentiveSettings() async {
    final document = await _settings.get();
    final data = document.data();
    return data == null
        ? const IncentiveSettings()
        : IncentiveSettings.fromMap(data);
  }

  @override
  Future<void> updateIncentiveSettings(IncentiveSettings settings) async {
    await _settings.set({
      ...settings.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<IncentiveRequest>> getApprovedRequestsForEmployee({
    int? employeeId,
    String? employeeName,
    String? employeeCode,
    DateTime? startDate,
    DateTime? endDateExclusive,
  }) async {
    final all = await getAllRequests();
    final normEmpName = employeeName?.trim().toLowerCase() ?? '';
    final normEmpCode = employeeCode?.trim().toLowerCase().replaceAll('-', '') ?? '';

    return all.where((req) {
      if (req.status.trim().toLowerCase() != 'approved') return false;

      final reqName = req.employeeName.trim().toLowerCase();
      final reqCode = reqName.replaceAll('-', '');

      bool matchesEmp = false;
      if (employeeId != null && req.employeeId != null && req.employeeId == employeeId) {
        matchesEmp = true;
      } else if (normEmpName.isNotEmpty && reqName == normEmpName) {
        matchesEmp = true;
      } else if (normEmpCode.isNotEmpty && (reqCode == normEmpCode || reqName.contains(normEmpCode))) {
        matchesEmp = true;
      } else if (normEmpName.isNotEmpty && (reqName.contains(normEmpName) || normEmpName.contains(reqName))) {
        matchesEmp = true;
      }

      if (!matchesEmp) return false;

      if (startDate != null || endDateExclusive != null) {
        final reqDate = DateTime.tryParse(req.createdAt);
        if (reqDate != null) {
          final reqLocal = reqDate.toLocal();
          if (startDate != null) {
            final startLocal = startDate.toLocal();
            if (reqLocal.isBefore(startLocal)) return false;
          }
          if (endDateExclusive != null) {
            final endLocal = endDateExclusive.toLocal();
            if (!reqLocal.isBefore(endLocal)) return false;
          }
        }
      }

      return true;
    }).toList();
  }

  // 3-Table Payout & Deferred Ledger Operations
  @override
  Future<List<IncentivePayoutLedger>> getPayoutLedgersForEmployee(int employeeId) async {
    final snapshot = await _payoutLedgers
        .where('employee_id', isEqualTo: employeeId)
        .get();
    final result = snapshot.docs
        .map((doc) => _ledger(doc.data(), doc.id))
        .toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<List<IncentivePayoutLedger>> getAllPayoutLedgers() async {
    final snapshot = await _payoutLedgers.get();
    final result = snapshot.docs
        .map((doc) => _ledger(doc.data(), doc.id))
        .toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Stream<List<IncentivePayoutLedger>> watchPayoutLedgersForEmployee(int employeeId) {
    return _payoutLedgers
        .where('employee_id', isEqualTo: employeeId)
        .snapshots()
        .map((snapshot) {
      final result = snapshot.docs
          .map((doc) => _ledger(doc.data(), doc.id))
          .toList();
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    });
  }

  @override
  Future<void> savePayoutLedger(IncentivePayoutLedger ledger) async {
    final docId = ledger.id.isNotEmpty
        ? ledger.id
        : 'ledger_${ledger.employeeId}_${ledger.earnedCycle.replaceAll(' ', '_')}';
    final data = Map<String, dynamic>.from(ledger.toMap());
    data['id'] = docId;
    data['updated_at'] = FieldValue.serverTimestamp();
    await _payoutLedgers.doc(docId).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> markPayoutLedgersReleased({
    required List<String> ledgerIds,
    required String releaseCycle,
    required DateTime releasedAt,
    int? payrollRecordId,
  }) async {
    if (ledgerIds.isEmpty) return;
    final batch = _firestore.batch();
    for (final id in ledgerIds) {
      final docRef = _payoutLedgers.doc(id);
      final updateData = <String, dynamic>{
        'status': 'Released',
        'release_cycle': releaseCycle,
        'released_at': releasedAt.toIso8601String(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (payrollRecordId != null) {
        updateData['payroll_record_id'] = payrollRecordId;
      }
      batch.set(docRef, updateData, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

