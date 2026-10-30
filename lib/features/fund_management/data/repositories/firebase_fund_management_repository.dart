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

  @override
  Stream<List<FundRequest>> watchPendingFundRequests() {
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
            if (!req.isDeleted && req.status.toLowerCase() == 'pending') {
              list.add(req);
            }
          } catch (e) {
            developer.log('Error parsing fund request ${doc.id}: $e', name: 'FirebaseFundManagementRepo');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        developer.log('Error in watchPendingFundRequests: $e', name: 'FirebaseFundManagementRepo');
        return <FundRequest>[];
      });
    } catch (e) {
      developer.log('Exception in watchPendingFundRequests: $e', name: 'FirebaseFundManagementRepo');
      return Stream.value(<FundRequest>[]);
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
            developer.log('Error parsing fund request ${doc.id}: $e', name: 'FirebaseFundManagementRepo');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        developer.log('Error in watchAllFundRequests: $e', name: 'FirebaseFundManagementRepo');
        return <FundRequest>[];
      });
    } catch (e) {
      developer.log('Exception in watchAllFundRequests: $e', name: 'FirebaseFundManagementRepo');
      return Stream.value(<FundRequest>[]);
    }
  }

  @override
  Future<List<FundRequest>> getPendingFundRequests() async {
    final ref = _requestsRef;
    if (ref == null) return [];
    try {
      final snap = await ref.get();
      final list = <FundRequest>[];
      for (final doc in snap.docs) {
        try {
          final req = FundRequest.fromMap(doc.data(), doc.id);
          if (!req.isDeleted && req.status.toLowerCase() == 'pending') {
            list.add(req);
          }
        } catch (_) {}
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      developer.log('Error getPendingFundRequests: $e');
      return [];
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
      developer.log('Error getAllFundRequests: $e');
      return [];
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
    final rRef = _requestsRef;
    FundRequest? existing;
    if (rRef != null) {
      try {
        final doc = await rRef.doc(requestId).get();
        if (doc.exists && doc.data() != null) {
          existing = FundRequest.fromMap(doc.data()!, doc.id);
        }
      } catch (_) {}
    }

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

    // Deduct approved amount from the project's actual value
    final proj = await getProjectByCode(projectCode);
    if (proj != null && approvedAmount > 0) {
      final pRef = _projectsRef;
      if (pRef != null) {
        final currentActual = proj.actualProjectValue;
        final newActual = (currentActual - approvedAmount).clamp(0.0, double.infinity);

        try {
          await pRef.doc(proj.id).update({
            'actual_project_value': newActual,
            'updated_at': nowIso,
            'updated_by_name': approvedBy,
          });

          await pRef.doc(proj.id).collection('audit_logs').add(
                ProjectAuditLog(
                  id: '',
                  projectId: proj.id,
                  employeeId: '',
                  employeeName: approvedBy,
                  designation: 'Fund Approver',
                  changeNote: 'Fund ${isPartial ? "Partial Approval" : "Approval"}: Deducted ₹${approvedAmount.toStringAsFixed(2)} for Request $requestId. Remarks: ${remarks ?? "Approved"}',
                  timestamp: DateTime.now(),
                ).toJson(),
              );
        } catch (e) {
          developer.log('Error deducting fund from project: $e');
        }
      }
    }
  }

  @override
  Future<void> rejectRequest({
    required String requestId,
    required String rejectedBy,
    required String reason,
  }) async {
    final rRef = _requestsRef;
    if (rRef != null) {
      final nowIso = DateTime.now().toIso8601String();
      try {
        await rRef.doc(requestId).update({
          'status': 'Rejected',
          'approvedBy': rejectedBy,
          'approvedAt': nowIso,
          'approvalRemarks': reason,
          'updatedAt': nowIso,
        });
      } catch (e) {
        developer.log('Error rejecting fund request: $e');
      }
    }
  }
}
