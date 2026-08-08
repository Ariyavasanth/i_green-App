import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/asset_assignment.dart';
import '../domain/asset_assignment_repository.dart';

class FirebaseAssetAssignmentRepository implements AssetAssignmentRepository {
  final FirebaseFirestore _firestore;

  FirebaseAssetAssignmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('asset_assignments');

  @override
  Future<List<AssetAssignment>> getAssignments() async {
    final snapshot = await _ref.get();
    final assignments = snapshot.docs
        .map((doc) => AssetAssignment.fromMap(doc.data(), doc.id))
        .toList();
    assignments.sort((a, b) => b.id.compareTo(a.id));
    return assignments;
  }

  @override
  Future<AssetAssignment> addAssignment(AssetAssignment assignment) async {
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
  }

  @override
  Future<void> addAssignments(List<AssetAssignment> assignments) async {
    if (assignments.isEmpty) return;
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
  }

  @override
  Future<void> updateAssignment(AssetAssignment assignment) async {
    final snapshot =
        await _ref.where('id', isEqualTo: assignment.id).limit(1).get();
    String docId = snapshot.docs.isNotEmpty ? snapshot.docs.first.id : assignment.id.toString();

    final data = assignment.toMap();
    data['updated_at'] = FieldValue.serverTimestamp();
    await _ref.doc(docId).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteAssignment(int id) async {
    final snapshot =
        await _ref.where('id', isEqualTo: id).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      await _ref.doc(snapshot.docs.first.id).delete();
      return;
    }
    await _ref.doc(id.toString()).delete();
  }
}
