import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/exit_model.dart';
import '../domain/exit_repository.dart';

class FirebaseExitRepository implements ExitRepository {
  final FirebaseFirestore _firestore;

  FirebaseExitRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection('exit_requests');

  CollectionReference<Map<String, dynamic>> get _clearancesRef =>
      _firestore.collection('exit_clearances');

  CollectionReference<Map<String, dynamic>> get _interviewsRef =>
      _firestore.collection('exit_interviews');

  CollectionReference<Map<String, dynamic>> get _settlementsRef =>
      _firestore.collection('exit_settlements');

  @override
  Future<List<ExitRequest>> getAllExitRequests() async {
    try {
      final snap = await _requestsRef.get();
      final list = snap.docs.map((doc) {
        final data = doc.data();
        final map = Map<String, dynamic>.from(data);
        if (!map.containsKey('id') || map['id'] == null || map['id'] == 0) {
          map['id'] = int.tryParse(doc.id) ?? (doc.id.hashCode & 0x7FFFFFFF);
        }
        return ExitRequest.fromMap(map);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('Firestore getAllExitRequests error: $e');
      return [];
    }
  }

  @override
  Future<ExitRequest?> getExitRequestByEmployeeId(String employeeId) async {
    try {
      final cleanId = employeeId.trim();
      final snap = await _requestsRef
          .where('employee_id', isEqualTo: cleanId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final map = Map<String, dynamic>.from(doc.data());
        if (!map.containsKey('id') || map['id'] == null || map['id'] == 0) {
          map['id'] = int.tryParse(doc.id) ?? (doc.id.hashCode & 0x7FFFFFFF);
        }
        return ExitRequest.fromMap(map);
      }
    } catch (e) {
      debugPrint('Firestore getExitRequestByEmployeeId error: $e');
    }
    return null;
  }

  @override
  Future<ExitRequest?> getExitRequestById(int id) async {
    try {
      final doc = await _requestsRef.doc('$id').get();
      if (doc.exists && doc.data() != null) {
        final map = Map<String, dynamic>.from(doc.data()!);
        map['id'] = id;
        return ExitRequest.fromMap(map);
      }
      final query = await _requestsRef.where('id', isEqualTo: id).limit(1).get();
      if (query.docs.isNotEmpty) {
        final docQuery = query.docs.first;
        final map = Map<String, dynamic>.from(docQuery.data());
        map['id'] = id;
        return ExitRequest.fromMap(map);
      }
    } catch (e) {
      debugPrint('Firestore getExitRequestById error: $e');
    }
    return null;
  }

  @override
  Future<int> submitExitRequest(ExitRequest request) async {
    try {
      final id = (request.id != null && request.id! > 0)
          ? request.id!
          : (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);

      final updated = request.copyWith(id: id);
      await _requestsRef.doc('$id').set({
        ...updated.toMap(),
        'id': id,
        'created_at_server': FieldValue.serverTimestamp(),
      });
      return id;
    } catch (e) {
      debugPrint('Firestore submitExitRequest error: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateExitRequestStatus(int id, String status) async {
    try {
      await _requestsRef.doc('$id').update({
        'status': status,
        'updated_at_server': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore updateExitRequestStatus error: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateExitRequestDetails(ExitRequest request) async {
    try {
      final id = request.id;
      if (id == null) return;
      await _requestsRef.doc('$id').set(
        {
          ...request.toMap(),
          'updated_at_server': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Firestore updateExitRequestDetails error: $e');
      rethrow;
    }
  }

  @override
  Future<List<DepartmentClearance>> getClearancesForExit(int exitRequestId) async {
    try {
      final snap = await _clearancesRef
          .where('exit_request_id', isEqualTo: exitRequestId)
          .get();
      return snap.docs.map((doc) {
        final map = Map<String, dynamic>.from(doc.data());
        if (!map.containsKey('id') || map['id'] == null || map['id'] == 0) {
          map['id'] = int.tryParse(doc.id) ?? (doc.id.hashCode & 0x7FFFFFFF);
        }
        return DepartmentClearance.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('Firestore getClearancesForExit error: $e');
      return [];
    }
  }

  @override
  Future<void> saveOrUpdateClearance(DepartmentClearance clearance) async {
    try {
      final id = (clearance.id != null && clearance.id! > 0)
          ? clearance.id!
          : (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);
      final updated = clearance.copyWith(id: id);
      await _clearancesRef.doc('$id').set(
        {
          ...updated.toMap(),
          'id': id,
          'updated_at_server': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Firestore saveOrUpdateClearance error: $e');
      rethrow;
    }
  }

  @override
  Future<ExitInterview?> getExitInterview(int exitRequestId) async {
    try {
      final snap = await _interviewsRef
          .where('exit_request_id', isEqualTo: exitRequestId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final map = Map<String, dynamic>.from(doc.data());
        if (!map.containsKey('id') || map['id'] == null || map['id'] == 0) {
          map['id'] = int.tryParse(doc.id) ?? (doc.id.hashCode & 0x7FFFFFFF);
        }
        return ExitInterview.fromMap(map);
      }
    } catch (e) {
      debugPrint('Firestore getExitInterview error: $e');
    }
    return null;
  }

  @override
  Future<void> submitExitInterview(ExitInterview interview) async {
    try {
      final id = (interview.id != null && interview.id! > 0)
          ? interview.id!
          : (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);
      await _interviewsRef.doc('$id').set({
        ...interview.toMap(),
        'id': id,
        'created_at_server': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firestore submitExitInterview error: $e');
      rethrow;
    }
  }

  @override
  Future<ExitSettlement?> getExitSettlement(int exitRequestId) async {
    try {
      final snap = await _settlementsRef
          .where('exit_request_id', isEqualTo: exitRequestId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final map = Map<String, dynamic>.from(doc.data());
        if (!map.containsKey('id') || map['id'] == null || map['id'] == 0) {
          map['id'] = int.tryParse(doc.id) ?? (doc.id.hashCode & 0x7FFFFFFF);
        }
        return ExitSettlement.fromMap(map);
      }
    } catch (e) {
      debugPrint('Firestore getExitSettlement error: $e');
    }
    return null;
  }

  @override
  Future<void> saveOrUpdateSettlement(ExitSettlement settlement) async {
    try {
      final id = (settlement.id != null && settlement.id! > 0)
          ? settlement.id!
          : (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);
      await _settlementsRef.doc('$id').set(
        {
          ...settlement.toMap(),
          'id': id,
          'updated_at_server': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Firestore saveOrUpdateSettlement error: $e');
      rethrow;
    }
  }
}
