import 'dart:async';
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

  // In-memory fallback / cache for offline/demo reliability
  static final List<FundRequest> _fallbackRequests = [
    FundRequest(
      id: 'fr_mock_1',
      requestNumber: 'REQ-2024-001',
      employeeId: 'emp_sathiya',
      employeeName: 'Sathiya',
      employeeCustomId: 'EMP042',
      department: 'Site Engineering',
      message: 'igig',
      projectCode: 'Corrtech-SUB-SEP/2023-1-TN-Coimbatore-Coimbatore',
      projectName: 'Corrtech Pipeline Section 1',
      approvedAmount: 0.0,
      requestAmount: 25.0,
      items: const [
        FundRequestItem(
          id: 'item_1_1',
          category: 'Fuel',
          subCategory: 'CNG',
          comments: 'Zfsd',
          amount: 25.0,
        ),
      ],
      billUrls: const [],
      status: 'Pending',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    FundRequest(
      id: 'fr_mock_2',
      requestNumber: 'REQ-2024-002',
      employeeId: 'emp_sathiya',
      employeeName: 'Sathiya',
      employeeCustomId: 'EMP042',
      department: 'Site Engineering',
      message: 'uftut',
      projectCode: 'Ajay Babu-SUB-FEB/2024-5-TN-Chennai-Tharamani',
      projectName: 'Ajay Babu Substation Tharamani',
      approvedAmount: 0.0,
      requestAmount: 946.0,
      items: const [
        FundRequestItem(
          id: 'item_2_1',
          category: 'Rental',
          subCategory: 'Truck',
          comments: 'Jn',
          amount: 688.0,
        ),
        FundRequestItem(
          id: 'item_2_2',
          category: 'Wages',
          subCategory: 'Daily Labor',
          comments: 'Loading and unloading helper allowance',
          amount: 258.0,
        ),
      ],
      billUrls: const [],
      status: 'Pending',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FundRequest(
      id: 'fr_mock_3',
      requestNumber: 'REQ-2024-003',
      employeeId: 'emp_sathiya',
      employeeName: 'Sathiya',
      employeeCustomId: 'EMP042',
      department: 'Site Engineering',
      message: 'Emergency compressor repair on site generator',
      projectCode: 'L&T-SUB-AUG/2024-9-KA-Bengaluru-Whitefield',
      projectName: 'L&T Metro Underground Feeder',
      approvedAmount: 1850.0,
      requestAmount: 1850.0,
      items: const [
        FundRequestItem(
          id: 'item_3_1',
          category: 'Repairs',
          subCategory: 'Machinery',
          comments: 'Compressor motor rewinding and gasket seal',
          amount: 1850.0,
        ),
      ],
      billUrls: const [],
      status: 'Approved',
      approvedBy: 'Admin Manager',
      approvedAt: DateTime.now().subtract(const Duration(days: 2)),
      approvalRemarks: 'Urgent machinery maintenance verified on site log.',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  @override
  Stream<List<FundRequest>> watchAllFundRequests() {
    final ref = _requestsRef;
    if (ref == null) {
      return Stream.value(List<FundRequest>.from(_fallbackRequests));
    }
    try {
      return ref
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) {
          return List<FundRequest>.from(_fallbackRequests);
        }
        return snapshot.docs
            .map((doc) => FundRequest.fromMap(doc.data(), doc.id))
            .where((r) => !r.isDeleted)
            .toList();
      }).handleError((_) => List<FundRequest>.from(_fallbackRequests));
    } catch (_) {
      return Stream.value(List<FundRequest>.from(_fallbackRequests));
    }
  }

  @override
  Stream<List<FundRequest>> watchFundRequestsForEmployee(String employeeId) {
    final ref = _requestsRef;
    if (ref == null) {
      final matched = _fallbackRequests
          .where((r) => r.employeeId == employeeId || employeeId.isEmpty)
          .toList();
      return Stream.value(matched.isNotEmpty ? matched : List<FundRequest>.from(_fallbackRequests));
    }
    try {
      return ref
          .where('employeeId', isEqualTo: employeeId)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) {
          final matched = _fallbackRequests
              .where((r) => r.employeeId == employeeId || employeeId.isEmpty)
              .toList();
          return matched.isNotEmpty ? matched : List<FundRequest>.from(_fallbackRequests);
        }
        final list = snapshot.docs
            .map((doc) => FundRequest.fromMap(doc.data(), doc.id))
            .where((r) => !r.isDeleted)
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((_) => List<FundRequest>.from(_fallbackRequests));
    } catch (_) {
      return Stream.value(List<FundRequest>.from(_fallbackRequests));
    }
  }

  @override
  Future<List<FundRequest>> getAllFundRequests() async {
    final ref = _requestsRef;
    if (ref == null) {
      return List<FundRequest>.from(_fallbackRequests);
    }
    try {
      final snap = await ref.orderBy('createdAt', descending: true).get();
      if (snap.docs.isEmpty) {
        return List<FundRequest>.from(_fallbackRequests);
      }
      return snap.docs
          .map((doc) => FundRequest.fromMap(doc.data(), doc.id))
          .where((r) => !r.isDeleted)
          .toList();
    } catch (_) {
      return List<FundRequest>.from(_fallbackRequests);
    }
  }

  @override
  Future<List<FundRequest>> getFundRequestsForEmployee(String employeeId) async {
    final ref = _requestsRef;
    if (ref == null) {
      return _fallbackRequests
          .where((r) => r.employeeId == employeeId || employeeId.isEmpty)
          .toList();
    }
    try {
      final snap = await ref
          .where('employeeId', isEqualTo: employeeId)
          .get();
      if (snap.docs.isEmpty) {
        return _fallbackRequests
            .where((r) => r.employeeId == employeeId || employeeId.isEmpty)
            .toList();
      }
      final list = snap.docs
          .map((doc) => FundRequest.fromMap(doc.data(), doc.id))
          .where((r) => !r.isDeleted)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return _fallbackRequests;
    }
  }

  @override
  Future<FundRequest?> getFundRequestById(String id) async {
    final ref = _requestsRef;
    if (ref == null) {
      return _fallbackRequests.where((r) => r.id == id).firstOrNull;
    }
    try {
      final doc = await ref.doc(id).get();
      if (doc.exists && doc.data() != null) {
        return FundRequest.fromMap(doc.data()!, doc.id);
      }
      return _fallbackRequests.where((r) => r.id == id).firstOrNull;
    } catch (_) {
      return _fallbackRequests.where((r) => r.id == id).firstOrNull;
    }
  }

  @override
  Future<String> createFundRequest(FundRequest request) async {
    final ref = _requestsRef;
    if (ref == null) {
      final id = 'fr_${DateTime.now().millisecondsSinceEpoch}';
      final localReq = request.copyWith(id: id);
      _fallbackRequests.insert(0, localReq);
      return id;
    }
    try {
      final docRef = ref.doc();
      final finalRequest = request.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await docRef.set(finalRequest.toMap());
      _fallbackRequests.insert(0, finalRequest);
      return docRef.id;
    } catch (_) {
      final id = 'fr_${DateTime.now().millisecondsSinceEpoch}';
      final localReq = request.copyWith(id: id);
      _fallbackRequests.insert(0, localReq);
      return id;
    }
  }

  @override
  Future<void> updateFundRequest(FundRequest request) async {
    final ref = _requestsRef;
    if (ref != null) {
      try {
        await ref.doc(request.id).update(request.toMap());
      } catch (_) {
        // fallback
      }
    }
    final idx = _fallbackRequests.indexWhere((r) => r.id == request.id);
    if (idx != -1) {
      _fallbackRequests[idx] = request;
    }
  }

  @override
  Future<void> deleteFundRequest(String id) async {
    final ref = _requestsRef;
    if (ref != null) {
      try {
        await ref.doc(id).delete();
      } catch (_) {
        // ignore
      }
    }
    _fallbackRequests.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> approveFundRequest(
    String id, {
    required double approvedAmount,
    required String approvedBy,
    String? remarks,
  }) async {
    final updateData = {
      'status': 'Approved',
      'approvedAmount': approvedAmount,
      'approvedBy': approvedBy,
      'approvedAt': DateTime.now().toIso8601String(),
      'approvalRemarks': remarks,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final ref = _requestsRef;
    if (ref != null) {
      try {
        await ref.doc(id).update(updateData);
      } catch (_) {
        // fallback
      }
    }
    final idx = _fallbackRequests.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _fallbackRequests[idx] = _fallbackRequests[idx].copyWith(
        status: 'Approved',
        approvedAmount: approvedAmount,
        approvedBy: approvedBy,
        approvedAt: DateTime.now(),
        approvalRemarks: remarks,
      );
    }
  }

  @override
  Future<void> rejectFundRequest(
    String id, {
    required String rejectedBy,
    required String reason,
  }) async {
    final updateData = {
      'status': 'Rejected',
      'approvedBy': rejectedBy,
      'approvedAt': DateTime.now().toIso8601String(),
      'approvalRemarks': reason,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final ref = _requestsRef;
    if (ref != null) {
      try {
        await ref.doc(id).update(updateData);
      } catch (_) {
        // fallback
      }
    }
    final idx = _fallbackRequests.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _fallbackRequests[idx] = _fallbackRequests[idx].copyWith(
        status: 'Rejected',
        approvedBy: rejectedBy,
        approvedAt: DateTime.now(),
        approvalRemarks: reason,
      );
    }
  }
}
