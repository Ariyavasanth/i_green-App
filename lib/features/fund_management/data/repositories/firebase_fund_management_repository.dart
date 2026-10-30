import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_application_1/features/fund_requester/domain/models/fund_request.dart';
import 'package:flutter_application_1/features/projects/domain/models/project_audit_log.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/fund_management/domain/repositories/fund_management_repository.dart';

class FirebaseFundManagementRepository implements FundManagementRepository {
  final FirebaseFirestore? _customFirestore;

  FirebaseFundManagementRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  CollectionReference<Map<String, dynamic>>? get _requestsRef {
    try {
      final fs = _customFirestore ?? FirebaseFirestore.instance;
      return fs.collection('fund_requests');
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _projectsRef {
    try {
      final fs = _customFirestore ?? FirebaseFirestore.instance;
      return fs.collection('site_projects');
    } catch (_) {
      return null;
    }
  }

  // Fallback demo requests matching the screenshots if database is offline or empty
  static final List<FundRequest> _fallbackRequests = [
    FundRequest(
      id: 'fr_screen_1',
      requestNumber: 'REQ-2026-10550',
      employeeId: '65',
      employeeName: 'K Paramasivam',
      employeeCustomId: '65',
      department: 'Site Operations',
      message: 'street light erection work',
      projectCode:
          'TNEB-OWN-DEC/2025-107-TN-Thanjavur-11kv cable Laying_Kumbakonam',
      projectName: 'Thanjavur 11KV Cable Laying Kumbakonam',
      approvedAmount: 0.0,
      requestAmount: 10550.00,
      status: 'Pending',
      createdAt: DateTime.parse('2026-10-30 16:38:16'),
      updatedAt: DateTime.parse('2026-10-30 16:38:16'),
    ),
    FundRequest(
      id: 'fr_screen_2',
      requestNumber: 'REQ-2026-2000',
      employeeId: '84',
      employeeName: 'Deepak R',
      employeeCustomId: '84',
      department: 'Site Engineering',
      message: 'Police others',
      projectCode:
          'TNEB-OWN-SEP/2025-103-TN-Kanchipuram-11KV TNHB Feeder-Sholinganallur',
      projectName: 'Kanchipuram 11KV TNHB Feeder Sholinganallur',
      approvedAmount: 0.0,
      requestAmount: 2000.00,
      status: 'Pending',
      createdAt: DateTime.parse('2026-10-30 12:07:21'),
      updatedAt: DateTime.parse('2026-10-30 12:07:21'),
    ),
    FundRequest(
      id: 'fr_screen_3',
      requestNumber: 'REQ-2026-27000',
      employeeId: '84',
      employeeName: 'Deepak R',
      employeeCustomId: '84',
      department: 'Site Engineering',
      message: 'Night shift Machine advance and hydra',
      projectCode:
          'TNEB-OWN-SEP/2025-103-TN-Kanchipuram-11KV TNHB Feeder-Sholinganallur',
      projectName: 'Kanchipuram 11KV TNHB Feeder Sholinganallur',
      approvedAmount: 0.0,
      requestAmount: 27000.00,
      status: 'Pending',
      createdAt: DateTime.parse('2026-10-29 19:45:08'),
      updatedAt: DateTime.parse('2026-10-29 19:45:08'),
    ),
  ];

  @override
  Stream<List<FundRequest>> watchPendingFundRequests() {
    final ref = _requestsRef;
    if (ref == null) {
      return Stream.value(
        _fallbackRequests.where((r) => r.status == 'Pending' && !r.isDeleted).toList(),
      );
    }
    try {
      return ref
          .where('status', isEqualTo: 'Pending')
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) {
          return _fallbackRequests
              .where((r) => r.status == 'Pending' && !r.isDeleted)
              .toList();
        }
        final list = snapshot.docs
            .map((doc) => FundRequest.fromMap(doc.data(), doc.id))
            .where((r) => !r.isDeleted)
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((_) {
        return _fallbackRequests
            .where((r) => r.status == 'Pending' && !r.isDeleted)
            .toList();
      });
    } catch (_) {
      return Stream.value(
        _fallbackRequests.where((r) => r.status == 'Pending' && !r.isDeleted).toList(),
      );
    }
  }

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
  Future<List<FundRequest>> getPendingFundRequests() async {
    final ref = _requestsRef;
    if (ref == null) {
      return _fallbackRequests
          .where((r) => r.status == 'Pending' && !r.isDeleted)
          .toList();
    }
    try {
      final snap = await ref.where('status', isEqualTo: 'Pending').get();
      if (snap.docs.isEmpty) {
        return _fallbackRequests
            .where((r) => r.status == 'Pending' && !r.isDeleted)
            .toList();
      }
      final list = snap.docs
          .map((doc) => FundRequest.fromMap(doc.data(), doc.id))
          .where((r) => !r.isDeleted)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return _fallbackRequests
          .where((r) => r.status == 'Pending' && !r.isDeleted)
          .toList();
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
  Future<SiteProject?> getProjectByCode(String projectCode) async {
    final ref = _projectsRef;
    if (ref == null || projectCode.trim().isEmpty) return null;
    try {
      final snap = await ref
          .where('project_code', isEqualTo: projectCode.trim())
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return SiteProject.fromJson(snap.docs.first.data(), docId: snap.docs.first.id);
      }
    } catch (e) {
      developer.log('Error looking up project by code $projectCode: $e');
    }
    return null;
  }

  @override
  Future<void> approveOrPartiallyApproveRequest({
    required String requestId,
    required String projectCode,
    required double approvedAmount,
    required String approvedBy,
    String? remarks,
  }) async {
    FundRequest? existing;
    final rRef = _requestsRef;
    if (rRef != null) {
      try {
        final doc = await rRef.doc(requestId).get();
        if (doc.exists && doc.data() != null) {
          existing = FundRequest.fromMap(doc.data()!, doc.id);
        }
      } catch (_) {}
    }
    existing ??= _fallbackRequests.where((r) => r.id == requestId).firstOrNull;

    final reqAmt = existing?.requestAmount ?? approvedAmount;
    final isPartial = approvedAmount < (reqAmt - 0.01);
    final finalStatus = isPartial ? 'Partially Approved' : 'Approved';

    final nowIso = DateTime.now().toIso8601String();
    final updateData = {
      'status': finalStatus,
      'approvedAmount': approvedAmount,
      'approvedBy': approvedBy,
      'approvedAt': nowIso,
      'approvalRemarks': remarks,
      'updatedAt': nowIso,
    };

    if (rRef != null) {
      try {
        await rRef.doc(requestId).update(updateData);
      } catch (e) {
        developer.log('Error updating fund request status: $e');
      }
    }

    final idx = _fallbackRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      _fallbackRequests[idx] = _fallbackRequests[idx].copyWith(
        status: finalStatus,
        approvedAmount: approvedAmount,
        approvedBy: approvedBy,
        approvedAt: DateTime.now(),
        approvalRemarks: remarks,
        updatedAt: DateTime.now(),
      );
    }

    // Deduct from Project Actual Amount
    final pRef = _projectsRef;
    if (pRef != null && projectCode.trim().isNotEmpty) {
      try {
        final snap = await pRef
            .where('project_code', isEqualTo: projectCode.trim())
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          final doc = snap.docs.first;
          final project = SiteProject.fromJson(doc.data(), docId: doc.id);
          final currentActual = project.actualProjectValue;
          final newActual = (currentActual - approvedAmount).clamp(0.0, double.infinity);

          await doc.reference.update({
            'actual_project_value': newActual,
            'updated_at': nowIso,
            'updated_by': approvedBy,
            'updated_by_name': approvedBy,
          });

          await doc.reference.collection('audit_logs').add({
            'timestamp': nowIso,
            'summary':
                'Fund Request ${existing?.requestNumber ?? requestId} $finalStatus: ₹$approvedAmount deducted from Actual Project Value (Previous: ₹$currentActual, New: ₹$newActual)',
            'updated_fields': ['actual_project_value'],
            'employee_name': approvedBy,
            'designation': 'Admin Approver',
            'note': remarks ?? 'Approved from Fund Management',
          });
        }
      } catch (e) {
        developer.log('Error deducting fund amount from project: $e');
      }
    }
  }

  @override
  Future<void> rejectRequest({
    required String requestId,
    required String rejectedBy,
    required String reason,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final updateData = {
      'status': 'Rejected',
      'approvedBy': rejectedBy,
      'approvedAt': nowIso,
      'approvalRemarks': reason,
      'updatedAt': nowIso,
    };

    final rRef = _requestsRef;
    if (rRef != null) {
      try {
        await rRef.doc(requestId).update(updateData);
      } catch (e) {
        developer.log('Error rejecting fund request: $e');
      }
    }

    final idx = _fallbackRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      _fallbackRequests[idx] = _fallbackRequests[idx].copyWith(
        status: 'Rejected',
        approvedBy: rejectedBy,
        approvedAt: DateTime.now(),
        approvalRemarks: reason,
        updatedAt: DateTime.now(),
      );
    }
  }
}
