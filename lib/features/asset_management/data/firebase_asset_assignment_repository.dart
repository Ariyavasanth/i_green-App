import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/asset_assignment.dart';
import '../domain/asset_assignment_repository.dart';
import '../domain/asset_transfer_request.dart';

class FirebaseAssetAssignmentRepository implements AssetAssignmentRepository {
  final FirebaseFirestore _firestore;

  FirebaseAssetAssignmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('asset_assignments');
  CollectionReference<Map<String, dynamic>> get _transferRef =>
      _firestore.collection('asset_transfer_requests');

  @override
  Future<List<AssetAssignment>> getAssignments() async {
    try {
      final snapshot = await _ref.get();
      final assignments = snapshot.docs
          .map((doc) => AssetAssignment.fromMap(doc.data(), doc.id))
          .toList();
      assignments.sort((a, b) => b.id.compareTo(a.id));
      return assignments;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<AssetAssignment> addAssignment(AssetAssignment assignment) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      final docRef = _ref.doc();
      final parsedId = int.tryParse(docRef.id.replaceAll(RegExp(r'\D'), ''));
      final assignedId = assignment.id != 0
          ? assignment.id
          : ((parsedId != null && parsedId != 0)
              ? parsedId
              : (docRef.id.hashCode & 0x7FFFFFFF));

      final newAssignment = assignment.copyWith(
        id: assignedId,
        createdAt: assignment.createdAt ?? nowStr,
      );

      final data = newAssignment.toMap();
      data['created_at'] = nowStr;
      data['updated_at'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));
      return newAssignment;
    } catch (_) {
      return assignment;
    }
  }

  @override
  Future<void> addAssignments(List<AssetAssignment> assignments) async {
    if (assignments.isEmpty) return;
    try {
      final batch = _firestore.batch();
      final nowStr = DateTime.now().toIso8601String();
      for (final assignment in assignments) {
        final docRef = _ref.doc();
        final parsedId = int.tryParse(docRef.id.replaceAll(RegExp(r'\D'), ''));
        final assignedId = assignment.id != 0
            ? assignment.id
            : ((parsedId != null && parsedId != 0)
                ? parsedId
                : (docRef.id.hashCode & 0x7FFFFFFF));

        final newAssignment = assignment.copyWith(
          id: assignedId,
          createdAt: assignment.createdAt ?? nowStr,
        );

        final data = newAssignment.toMap();
        data['created_at'] = nowStr;
        data['updated_at'] = FieldValue.serverTimestamp();
        batch.set(docRef, data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Future<void> updateAssignment(AssetAssignment assignment) async {
    try {
      final snapshot =
          await _ref.where('id', isEqualTo: assignment.id).limit(1).get();
      String docId = snapshot.docs.isNotEmpty ? snapshot.docs.first.id : assignment.id.toString();
      final data = assignment.toMap();
      data['updated_at'] = FieldValue.serverTimestamp();
      await _ref.doc(docId).set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> deleteAssignment(int id) async {
    try {
      final snapshot =
          await _ref.where('id', isEqualTo: id).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        await _ref.doc(snapshot.docs.first.id).delete();
        return;
      }
      await _ref.doc(id.toString()).delete();
    } catch (_) {}
  }

  @override
  Future<List<AssetTransferRequest>> getTransferRequests() async {
    final snapshot = await _transferRef.get();
    final requests = snapshot.docs.map((d) => AssetTransferRequest.fromMap(d.data(), d.id)).toList();
    requests.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return requests;
  }

  @override
  Future<AssetTransferRequest> createTransferRequest(AssetTransferRequest request) async {
    final doc = _transferRef.doc();
    final created = request.copyWith(
      id: request.id == 0 ? doc.id.hashCode & 0x7fffffff : request.id,
      createdAt: DateTime.now().toIso8601String(),
    );
    await doc.set(created.toMap());
    return created;
  }

  @override
  Future<void> respondToTransferRequest(AssetTransferRequest request, {required bool approve}) async {
    final requestQuery = await _transferRef.where('id', isEqualTo: request.id).limit(1).get();
    if (requestQuery.docs.isEmpty) throw StateError('Transfer request was not found.');
    final requestDoc = requestQuery.docs.first.reference;
    final assignmentQuery = await _ref.where('id', isEqualTo: request.assetAssignmentId).limit(1).get();
    if (approve && assignmentQuery.docs.isEmpty) throw StateError('Asset assignment was not found.');
    await _firestore.runTransaction((transaction) async {
      if (approve) {
        transaction.update(assignmentQuery.docs.first.reference, {
          'employee_id': request.toEmployeeId,
          'employee_name': request.toEmployeeName,
          'employee_code': request.toEmployeeCode,
          'assigned_date': request.transferDate,
          'description': request.reason,
          'status': 'Assigned',
          'transferred_from': '${request.fromEmployeeName}${request.fromEmployeeCode.isEmpty ? '' : ' (${request.fromEmployeeCode})'}',
          'transfer_date': request.transferDate,
          'maintenance_address': null,
          'maintenance_contact': null,
          'maintenance_given_date': null,
          'maintenance_return_date': null,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      transaction.update(requestDoc, {
        'status': approve ? 'Approved' : 'Rejected',
        'responded_at': DateTime.now().toIso8601String(),
      });
    });
  }
}
