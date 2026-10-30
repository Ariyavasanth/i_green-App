import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/fund_request.dart';
import '../../domain/models/fund_request_item.dart';
import '../../domain/repositories/fund_request_repository.dart';

class FirebaseFundRequestRepository implements FundRequestRepository {
  final FirebaseFirestore? _customFirestore;

  FirebaseFundRequestRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  CollectionReference<Map<String, dynamic>>? get _requestsRef {
    try {
      final fs = _customFirestore ?? FirebaseFirestore.instance;
      return fs.collection('fund_requests');
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<FundRequest>> watchAllFundRequests() {
    final ref = _requestsRef;
    if (ref == null) {
      return Stream.value(<FundRequest>[]);
    }
    try {
      return ref.snapshots().map((snapshot) {
        final list = <FundRequest>[];
        for (final doc in snapshot.docs) {
          try {
            final req = FundRequest.fromMap(doc.data(), doc.id);
            if (!req.isDeleted) {
              list.add(req);
            }
          } catch (e) {
            developer.log('Error parsing fund request ${doc.id}: $e', name: 'FirebaseFundRequestRepo');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        developer.log('Error in watchAllFundRequests: $e', name: 'FirebaseFundRequestRepo');
        return <FundRequest>[];
      });
    } catch (e) {
      developer.log('Exception in watchAllFundRequests: $e', name: 'FirebaseFundRequestRepo');
      return Stream.value(<FundRequest>[]);
    }
  }

  @override
  Stream<List<FundRequest>> watchFundRequestsForEmployee(String employeeId) {
    final ref = _requestsRef;
    if (ref == null) {
      return Stream.value(<FundRequest>[]);
    }
    try {
      return ref.snapshots().map((snapshot) {
        final list = <FundRequest>[];
        for (final doc in snapshot.docs) {
          try {
            final req = FundRequest.fromMap(doc.data(), doc.id);
            if (!req.isDeleted) {
              if (employeeId.isEmpty || req.employeeId == employeeId) {
                list.add(req);
              }
            }
          } catch (e) {
            developer.log('Error parsing fund request ${doc.id}: $e', name: 'FirebaseFundRequestRepo');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        developer.log('Error in watchFundRequestsForEmployee: $e', name: 'FirebaseFundRequestRepo');
        return <FundRequest>[];
      });
    } catch (e) {
      developer.log('Exception in watchFundRequestsForEmployee: $e', name: 'FirebaseFundRequestRepo');
      return Stream.value(<FundRequest>[]);
    }
  }

  @override
  Future<List<FundRequest>> getAllFundRequests() async {
    final ref = _requestsRef;
    if (ref == null) return [];
    try {
      final snap = await ref.get();
      final list = <FundRequest>[];
      for (final doc in snap.docs) {
        try {
          final req = FundRequest.fromMap(doc.data(), doc.id);
          if (!req.isDeleted) {
            list.add(req);
          }
        } catch (_) {}
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      developer.log('Error in getAllFundRequests: $e');
      return [];
    }
  }

  @override
  Future<List<FundRequest>> getFundRequestsForEmployee(String employeeId) async {
    final ref = _requestsRef;
    if (ref == null) return [];
    try {
      final snap = await ref.get();
      final list = <FundRequest>[];
      for (final doc in snap.docs) {
        try {
          final req = FundRequest.fromMap(doc.data(), doc.id);
          if (!req.isDeleted && (employeeId.isEmpty || req.employeeId == employeeId)) {
            list.add(req);
          }
        } catch (_) {}
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      developer.log('Error in getFundRequestsForEmployee: $e');
      return [];
    }
  }

  @override
  Future<FundRequest?> getFundRequestById(String id) async {
    final ref = _requestsRef;
    if (ref == null) return null;
    try {
      final doc = await ref.doc(id).get();
      if (doc.exists && doc.data() != null) {
        return FundRequest.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      developer.log('Error in getFundRequestById: $e');
    }
    return null;
  }

  @override
  Future<String> createFundRequest(FundRequest request) async {
    final ref = _requestsRef;
    if (ref == null) {
      throw Exception('Firestore fund_requests collection is unavailable.');
    }
    try {
      final docRef = ref.doc();
      final finalRequest = request.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await docRef.set(finalRequest.toMap());
      developer.log('Successfully created fund request doc: ${docRef.id}', name: 'FirebaseFundRequestRepo');
      return docRef.id;
    } catch (e) {
      developer.log('Error creating fund request: $e', name: 'FirebaseFundRequestRepo');
      rethrow;
    }
  }

  @override
  Future<void> updateFundRequest(FundRequest request) async {
    final ref = _requestsRef;
    if (ref != null) {
      try {
        await ref.doc(request.id).update(request.toMap());
      } catch (e) {
        developer.log('Error updating fund request ${request.id}: $e');
        rethrow;
      }
    }
  }

  @override
  Future<void> deleteFundRequest(String id) async {
    final ref = _requestsRef;
    if (ref != null) {
      try {
        await ref.doc(id).update({
          'isDeleted': true,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        developer.log('Error deleting fund request $id: $e');
        rethrow;
      }
    }
  }

  @override
  Future<void> approveFundRequest(
    String id, {
    required double approvedAmount,
    required String approvedBy,
    String? remarks,
  }) async {
    final ref = _requestsRef;
    if (ref != null) {
      try {
        final nowIso = DateTime.now().toIso8601String();
        await ref.doc(id).update({
          'status': 'Approved',
          'approvedAmount': approvedAmount,
          'approvedBy': approvedBy,
          'approvedAt': nowIso,
          'approvalRemarks': remarks,
          'updatedAt': nowIso,
        });
      } catch (e) {
        developer.log('Error approving fund request $id: $e');
        rethrow;
      }
    }
  }

  @override
  Future<void> rejectFundRequest(
    String id, {
    required String rejectedBy,
    required String reason,
  }) async {
    final ref = _requestsRef;
    if (ref != null) {
      try {
        final nowIso = DateTime.now().toIso8601String();
        await ref.doc(id).update({
          'status': 'Rejected',
          'approvedBy': rejectedBy,
          'approvedAt': nowIso,
          'approvalRemarks': reason,
          'updatedAt': nowIso,
        });
      } catch (e) {
        developer.log('Error rejecting fund request $id: $e');
        rethrow;
      }
    }
  }
}
