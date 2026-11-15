import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../domain/models/daily_progress_entry.dart';
import '../../domain/models/deduction_entry.dart';
import '../../domain/models/eot_letter.dart';
import '../../domain/models/project_audit_log.dart';
import '../../domain/models/project_breakdown_item.dart';
import '../../domain/models/project_budget.dart';
import '../../domain/models/project_compliance_record.dart';
import '../../domain/models/project_document.dart';
import '../../domain/models/project_inventory_item.dart';
import '../../domain/models/site_project.dart';
import '../../domain/repositories/project_repository.dart';

class FirebaseProjectRepository implements ProjectRepository {
  FirebaseProjectRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    String? storageBucket,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ??
            (storageBucket != null && storageBucket.isNotEmpty
                ? FirebaseStorage.instanceFor(bucket: storageBucket)
                : FirebaseStorage.instance);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _projectsRef =>
      _firestore.collection('site_projects');

  CollectionReference<Map<String, dynamic>> get _tenderTypesRef =>
      _firestore.collection('tender_types');

  CollectionReference<Map<String, dynamic>> _auditLogsRef(String projectId) =>
      _projectsRef.doc(projectId).collection('audit_logs');

  static const List<String> _defaultTenderTypes = [
    'Open',
    'Close',
  ];

  @override
  Future<SiteProject> createProject(
    SiteProject project, {
    Map<String, List<PlatformFile>>? filesByCategory,
  }) async {
    try {
      // 1. Generate new document ID
      final docRef = _projectsRef.doc();
      final docId = docRef.id;
      final storageFolderId = (project.projectCode.trim().isNotEmpty
              ? project.projectCode.trim()
              : docId)
          .replaceAll('/', '_');

      // 2. Upload attachments per category if provided
      final tenderDocs = List<ProjectDocument>.from(project.tenderSpecDocuments);
      final bqrDocs = List<ProjectDocument>.from(project.bqrDocuments);
      final emdDocs = List<ProjectDocument>.from(project.emdDocuments);
      final sdDateDocs = List<ProjectDocument>.from(project.sdDateDocuments);
      final boqDocs = List<ProjectDocument>.from(project.boqDocuments);
      final projectDetailsDocs = List<ProjectDocument>.from(project.projectDetailsDocuments);
      final workOrderDocs = List<ProjectDocument>.from(project.workOrderDocuments);
      final profileDrawingDocs = List<ProjectDocument>.from(project.profileDrawingDocuments);
      final agreementDocs = List<ProjectDocument>.from(project.agreementDocuments);
      final supplyMaterialsDocs = List<ProjectDocument>.from(project.supplyMaterialsDocuments);
      final billingDetailsDocs = List<ProjectDocument>.from(project.billingDetailsDocuments);
      final emdRetentionDocs = List<ProjectDocument>.from(project.emdRetentionDocuments);
      final sdRetentionDocs = List<ProjectDocument>.from(project.sdRetentionDocuments);
      final otherRetentionDocs = List<ProjectDocument>.from(project.otherRetentionDocuments);
      final wrpoDocs = List<ProjectDocument>.from(project.wrpoDocuments);
      final tenderLostDocs = List<ProjectDocument>.from(project.tenderLostDocuments);
      final mBookDocs = List<ProjectDocument>.from(project.mBookDocuments);

      if (filesByCategory != null) {
        Future<void> uploadCategory(String key, List<ProjectDocument> target) async {
          final files = filesByCategory[key];
          if (files != null && files.isNotEmpty) {
            final uploaded = await _uploadFiles(storageFolderId, key, files);
            target.addAll(uploaded);
          }
        }

        await uploadCategory('tender_spec', tenderDocs);
        await uploadCategory('bqr', bqrDocs);
        await uploadCategory('emd', emdDocs);
        await uploadCategory('sd_date', sdDateDocs);
        await uploadCategory('boq', boqDocs);
        await uploadCategory('project_details', projectDetailsDocs);
        await uploadCategory('work_order', workOrderDocs);
        await uploadCategory('profile_drawing', profileDrawingDocs);
        await uploadCategory('agreement', agreementDocs);
        await uploadCategory('supply_materials', supplyMaterialsDocs);
        await uploadCategory('billing_details', billingDetailsDocs);
        await uploadCategory('emd_retention', emdRetentionDocs);
        await uploadCategory('sd_retention', sdRetentionDocs);
        await uploadCategory('other_retention', otherRetentionDocs);
        await uploadCategory('wrpo', wrpoDocs);
        await uploadCategory('purchase_order', wrpoDocs);
        await uploadCategory('tender_lost', tenderLostDocs);
        await uploadCategory('m_book', mBookDocs);
      }

      // 3. Assemble final project
      final finalProject = project.copyWith(
        id: docId,
        tenderSpecDocuments: tenderDocs,
        bqrDocuments: bqrDocs,
        emdDocuments: emdDocs,
        sdDateDocuments: sdDateDocs,
        boqDocuments: boqDocs,
        projectDetailsDocuments: projectDetailsDocs,
        workOrderDocuments: workOrderDocs,
        profileDrawingDocuments: profileDrawingDocs,
        agreementDocuments: agreementDocs,
        supplyMaterialsDocuments: supplyMaterialsDocs,
        billingDetailsDocuments: billingDetailsDocs,
        emdRetentionDocuments: emdRetentionDocs,
        sdRetentionDocuments: sdRetentionDocs,
        otherRetentionDocuments: otherRetentionDocs,
        wrpoDocuments: wrpoDocs,
        tenderLostDocuments: tenderLostDocs,
        mBookDocuments: mBookDocs,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 4. Save to Firestore
      await docRef.set(finalProject.toJson());

      return finalProject;
    } catch (e, stack) {
      developer.log('Error creating site project: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<List<ProjectDocument>> _uploadFiles(
    String projectId,
    String category,
    List<PlatformFile> files,
  ) async {
    final docs = <ProjectDocument>[];

    for (final file in files) {
      String downloadUrl = '';
      String storagePath = '';
      try {
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null && file.path!.isNotEmpty) {
          if (!kIsWeb) {
            final f = io.File(file.path!);
            if (await f.exists()) {
              bytes = await f.readAsBytes();
            }
          }
        }

        if (bytes != null) {
          final cleanFileName =
              file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          storagePath =
              'site_projects/$projectId/$category/${timestamp}_$cleanFileName';
          try {
            final ref = _storage.ref().child(storagePath);
            final uploadTask = await ref.putData(
              bytes,
              SettableMetadata(contentType: _getContentType(file.extension)),
            );
            downloadUrl = await uploadTask.ref.getDownloadURL();
          } catch (storageErr) {
            developer.log(
              'Firebase Storage putData failed ($storageErr). Saving as data URI fallback.',
              name: 'FirebaseProjectRepository',
            );
            final mime = _getContentType(file.extension);
            final base64Str = base64Encode(bytes);
            downloadUrl = 'data:$mime;base64,$base64Str';
          }
        }
      } catch (e) {
        developer.log('Storage upload fallback for ${file.name}: $e',
            name: 'FirebaseProjectRepository');
        downloadUrl = '';
      }

      docs.add(
        ProjectDocument(
          name: file.name,
          size: file.size,
          downloadUrl: downloadUrl,
          localPath: file.path ?? '',
          category: category,
          storagePath: storagePath,
          uploadedAt: DateTime.now(),
        ),
      );
    }

    return docs;
  }

  String _getContentType(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Future<List<SiteProject>> getProjects() async {
    try {
      final snap = await _projectsRef.orderBy('created_at', descending: true).get();
      return snap.docs
          .map((doc) {
            final p = SiteProject.fromJson(doc.data(), docId: doc.id);
            return p.shouldAutoReopenForRetention
                ? p.copyWith(status: 'Active')
                : p;
          })
          .toList();
    } catch (e, stack) {
      developer.log('Error fetching site projects: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      // Fallback if index on created_at is building or missing
      try {
        final snap = await _projectsRef.get();
        final list = snap.docs
            .map((doc) => SiteProject.fromJson(doc.data(), docId: doc.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      } catch (_) {
        rethrow;
      }
    }
  }

  @override
  Stream<List<SiteProject>> watchProjects() {
    return _projectsRef.snapshots().map((snap) {
      final list = <SiteProject>[];
      for (final doc in snap.docs) {
        try {
          final p = SiteProject.fromJson(doc.data(), docId: doc.id);
          list.add(
            p.shouldAutoReopenForRetention ? p.copyWith(status: 'Active') : p,
          );
        } catch (e, stack) {
          developer.log('Error parsing project doc ${doc.id}: $e',
              name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<SiteProject?> getProjectById(String id) async {
    try {
      final doc = await _projectsRef.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return SiteProject.fromJson(doc.data()!, docId: doc.id);
    } catch (e, stack) {
      developer.log('Error getting project $id: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<void> updateProject(
    SiteProject project, {
    Map<String, List<PlatformFile>>? filesByCategory,
    String? auditNote,
    String? auditEmployeeId,
    String? auditEmployeeName,
    String? auditDesignation,
  }) async {
    try {
      final storageFolderId = (project.projectCode.trim().isNotEmpty
              ? project.projectCode.trim()
              : project.id)
          .replaceAll('/', '_');

      final tenderDocs = List<ProjectDocument>.from(project.tenderSpecDocuments);
      final bqrDocs = List<ProjectDocument>.from(project.bqrDocuments);
      final emdDocs = List<ProjectDocument>.from(project.emdDocuments);
      final sdDateDocs = List<ProjectDocument>.from(project.sdDateDocuments);
      final boqDocs = List<ProjectDocument>.from(project.boqDocuments);
      final projectDetailsDocs = List<ProjectDocument>.from(project.projectDetailsDocuments);
      final workOrderDocs = List<ProjectDocument>.from(project.workOrderDocuments);
      final profileDrawingDocs = List<ProjectDocument>.from(project.profileDrawingDocuments);
      final agreementDocs = List<ProjectDocument>.from(project.agreementDocuments);
      final supplyMaterialsDocs = List<ProjectDocument>.from(project.supplyMaterialsDocuments);
      final billingDetailsDocs = List<ProjectDocument>.from(project.billingDetailsDocuments);
      final emdRetentionDocs = List<ProjectDocument>.from(project.emdRetentionDocuments);
      final sdRetentionDocs = List<ProjectDocument>.from(project.sdRetentionDocuments);
      final otherRetentionDocs = List<ProjectDocument>.from(project.otherRetentionDocuments);
      final wrpoDocs = List<ProjectDocument>.from(project.wrpoDocuments);
      final tenderLostDocs = List<ProjectDocument>.from(project.tenderLostDocuments);
      final mBookDocs = List<ProjectDocument>.from(project.mBookDocuments);

      if (filesByCategory != null) {
        Future<void> uploadCategory(String key, List<ProjectDocument> target) async {
          final files = filesByCategory[key];
          if (files != null && files.isNotEmpty) {
            final uploaded = await _uploadFiles(storageFolderId, key, files);
            target.addAll(uploaded);
          }
        }

        await uploadCategory('tender_spec', tenderDocs);
        await uploadCategory('bqr', bqrDocs);
        await uploadCategory('emd', emdDocs);
        await uploadCategory('sd_date', sdDateDocs);
        await uploadCategory('boq', boqDocs);
        await uploadCategory('project_details', projectDetailsDocs);
        await uploadCategory('work_order', workOrderDocs);
        await uploadCategory('profile_drawing', profileDrawingDocs);
        await uploadCategory('agreement', agreementDocs);
        await uploadCategory('supply_materials', supplyMaterialsDocs);
        await uploadCategory('billing_details', billingDetailsDocs);
        await uploadCategory('emd_retention', emdRetentionDocs);
        await uploadCategory('sd_retention', sdRetentionDocs);
        await uploadCategory('other_retention', otherRetentionDocs);
        await uploadCategory('wrpo', wrpoDocs);
        await uploadCategory('purchase_order', wrpoDocs);
        await uploadCategory('tender_lost', tenderLostDocs);
        await uploadCategory('m_book', mBookDocs);
      }

      var finalProject = project.copyWith(
        tenderSpecDocuments: tenderDocs,
        bqrDocuments: bqrDocs,
        emdDocuments: emdDocs,
        sdDateDocuments: sdDateDocs,
        boqDocuments: boqDocs,
        projectDetailsDocuments: projectDetailsDocs,
        workOrderDocuments: workOrderDocs,
        profileDrawingDocuments: profileDrawingDocs,
        agreementDocuments: agreementDocs,
        supplyMaterialsDocuments: supplyMaterialsDocs,
        billingDetailsDocuments: billingDetailsDocs,
        emdRetentionDocuments: emdRetentionDocs,
        sdRetentionDocuments: sdRetentionDocs,
        otherRetentionDocuments: otherRetentionDocs,
        wrpoDocuments: wrpoDocs,
        tenderLostDocuments: tenderLostDocs,
        mBookDocuments: mBookDocs,
        updatedAt: DateTime.now(),
      );

      // Enforce project closure & auto-close rules
      if (finalProject.status == 'Closed' && !finalProject.canBeClosed) {
        if (!finalProject.supervisorMaterialBalanceSettled) {
          throw StateError(
            'Project cannot be closed until the supervisor material balance is settled.',
          );
        }
        throw StateError(
          'Project cannot be closed until the bill is uploaded and payment is received.',
        );
      }
      if (finalProject.status != 'Closed' &&
          finalProject.canBeClosed &&
          !finalProject.shouldAutoReopenForRetention) {
        finalProject = finalProject.copyWith(status: 'Closed');
      }

      final data = finalProject.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();
      if (finalProject.updatedBy != null) {
        data['updated_by'] = finalProject.updatedBy;
      }
      if (finalProject.updatedByName != null) {
        data['updated_by_name'] = finalProject.updatedByName;
      }

      await _projectsRef.doc(project.id).update(data);

      // Record audit history log if audit details are provided
      if ((auditEmployeeId != null && auditEmployeeId.isNotEmpty) ||
          (auditNote != null && auditNote.isNotEmpty)) {
        final auditDoc = _auditLogsRef(project.id).doc();
        final log = ProjectAuditLog(
          id: auditDoc.id,
          projectId: project.id,
          employeeId: auditEmployeeId ?? project.updatedBy ?? 'EMP-UNKNOWN',
          employeeName: auditEmployeeName ?? project.updatedByName ?? 'Unknown',
          designation: auditDesignation ?? 'Staff',
          changeNote: auditNote ?? 'Updated project details',
          timestamp: DateTime.now(),
        );
        await auditDoc.set(log.toJson());
      }
    } catch (e, stack) {
      developer.log('Error updating project ${project.id}: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> updateProjectBreakdown({
    required String projectId,
    required List<ProjectBreakdownItem> materials,
    required List<ProjectBreakdownItem> services,
    String? auditEmployeeId,
    String? auditEmployeeName,
    String? auditDesignation,
    String? auditNote,
  }) async {
    try {
      final totalMaterials =
          materials.fold(0.0, (acc, item) => acc + item.amount);
      final totalServices =
          services.fold(0.0, (acc, item) => acc + item.amount);
      final totalBreakdown = totalMaterials + totalServices;

      final now = DateTime.now();
      final data = <String, dynamic>{
        'breakdown_materials': materials.map((m) => m.toJson()).toList(),
        'breakdown_services': services.map((s) => s.toJson()).toList(),
        'total_materials_value': totalMaterials,
        'total_services_value': totalServices,
        'total_breakdown_value': totalBreakdown,
        'breakdown_updated_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      if (auditEmployeeId != null && auditEmployeeId.isNotEmpty) {
        data['updated_by'] = auditEmployeeId;
      }
      if (auditEmployeeName != null && auditEmployeeName.isNotEmpty) {
        data['updated_by_name'] = auditEmployeeName;
      }

      await _projectsRef.doc(projectId).update(data);

      if ((auditEmployeeId != null && auditEmployeeId.isNotEmpty) ||
          (auditNote != null && auditNote.isNotEmpty)) {
        final auditDoc = _auditLogsRef(projectId).doc();
        final log = ProjectAuditLog(
          id: auditDoc.id,
          projectId: projectId,
          employeeId: auditEmployeeId ?? 'EMP-UNKNOWN',
          employeeName: auditEmployeeName ?? 'Unknown',
          designation: auditDesignation ?? 'Staff',
          changeNote: auditNote ??
              'Updated Project Breakdown (Materials: ${materials.length}, Services: ${services.length})',
          timestamp: now,
        );
        await auditDoc.set(log.toJson());
      }
    } catch (e, stack) {
      developer.log('Error updating project breakdown for $projectId: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> updateProjectBudget({
    required String projectId,
    required ProjectBudget budget,
    double contractValue = 0.0,
    String? auditEmployeeId,
    String? auditEmployeeName,
    String? auditDesignation,
    String? auditNote,
  }) async {
    try {
      final now = DateTime.now();
      final updatedBudget = budget.copyWith(
        updatedAt: now,
        updatedBy: auditEmployeeId ?? budget.updatedBy,
      );

      final data = <String, dynamic>{
        'project_budget': updatedBudget.toJson(contractValue: contractValue),
        'updated_at': now.toIso8601String(),
      };

      if (auditEmployeeId != null && auditEmployeeId.isNotEmpty) {
        data['updated_by'] = auditEmployeeId;
      }
      if (auditEmployeeName != null && auditEmployeeName.isNotEmpty) {
        data['updated_by_name'] = auditEmployeeName;
      }

      await _projectsRef.doc(projectId).update(data);

      if ((auditEmployeeId != null && auditEmployeeId.isNotEmpty) ||
          (auditNote != null && auditNote.isNotEmpty)) {
        final auditDoc = _auditLogsRef(projectId).doc();
        final log = ProjectAuditLog(
          id: auditDoc.id,
          projectId: projectId,
          employeeId: auditEmployeeId ?? 'EMP-UNKNOWN',
          employeeName: auditEmployeeName ?? 'Unknown',
          designation: auditDesignation ?? 'Staff',
          changeNote: auditNote ??
              'Updated Project Budget (${updatedBudget.status.label}, Total: ₹${updatedBudget.totalBudget.toStringAsFixed(2)})',
          timestamp: now,
        );
        await auditDoc.set(log.toJson());
      }
    } catch (e, stack) {
      developer.log('Error updating project budget for $projectId: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<List<ProjectAuditLog>> getProjectAuditLogs(String projectId) async {
    try {
      final snap = await _auditLogsRef(projectId).orderBy('timestamp', descending: true).get();
      return snap.docs
          .map((doc) => ProjectAuditLog.fromJson(doc.data(), docId: doc.id))
          .toList();
    } catch (e, stack) {
      developer.log('Error fetching audit logs for $projectId: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      try {
        final snap = await _auditLogsRef(projectId).get();
        final list = snap.docs
            .map((doc) => ProjectAuditLog.fromJson(doc.data(), docId: doc.id))
            .toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<void> addAuditLog(ProjectAuditLog log) async {
    try {
      final docRef = _auditLogsRef(log.projectId).doc();
      final toSave = {
        ...log.toJson(),
        'id': docRef.id,
      };
      await docRef.set(toSave);
    } catch (e, stack) {
      developer.log('Error adding audit log: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
    }
  }

  @override
  Future<void> deleteProject(String id) async {
    try {
      await _projectsRef.doc(id).delete();
    } catch (e, stack) {
      developer.log('Error deleting project $id: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<List<String>> getTenderTypes() async {
    try {
      final snap = await _tenderTypesRef.get();
      if (snap.docs.isNotEmpty) {
        final types = snap.docs
            .map((d) => (d.data()['name'] ?? d.data()['title'] ?? d.id).toString())
            .where((s) => s.isNotEmpty)
            .toList();
        if (types.isNotEmpty) return types;
      }
    } catch (e) {
      developer.log('Could not load tender types from Firestore: $e',
          name: 'FirebaseProjectRepository');
    }
    return _defaultTenderTypes;
  }

  @override
  Future<int> getNextProjectSequence() async {
    try {
      final snap = await _projectsRef.count().get();
      return (snap.count ?? 0) + 1;
    } catch (_) {
      try {
        final snap = await _projectsRef.get();
        return snap.docs.length + 1;
      } catch (_) {
        return 1;
      }
    }
  }

  // ── Daily Progress ──
  CollectionReference<Map<String, dynamic>> get _dailyProgressRef =>
      _firestore.collection('daily_progress');

  @override
  Stream<List<DailyProgressEntry>> watchDailyProgress(String projectCode) {
    return _dailyProgressRef
        .where('project_code', isEqualTo: projectCode)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => DailyProgressEntry.fromJson(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  @override
  Future<void> addDailyProgress(DailyProgressEntry entry) async {
    final status = DailyProgressEntry.isBackdatedBeyondLimit(entry.date)
        ? 'pending_approval'
        : 'approved';
    final docRef = _dailyProgressRef.doc();
    final data = entry.toJson();
    data['id'] = docRef.id;
    data['approval_status'] = status;
    await docRef.set(data);
  }

  @override
  Future<void> approveDailyProgress(String entryId, String approvedBy) async {
    await _dailyProgressRef.doc(entryId).update({
      'approval_status': 'approved',
      'approved_by': approvedBy,
      'approved_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Project Inventory ──
  CollectionReference<Map<String, dynamic>> get _inventoryRef =>
      _firestore.collection('project_inventory');

  @override
  Stream<List<ProjectInventoryItem>> watchProjectInventory(String projectCode) {
    return _inventoryRef
        .where('project_code', isEqualTo: projectCode)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProjectInventoryItem.fromJson(d.data(), d.id))
            .toList());
  }

  @override
  Future<void> updateProjectInventory(ProjectInventoryItem item) async {
    final docId = item.id.isNotEmpty
        ? item.id
        : '${item.projectCode}_${item.supervisorId}_${item.itemId}'
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final data = item.toJson();
    data['id'] = docId;
    data['updated_at'] = DateTime.now().toIso8601String();
    await _inventoryRef.doc(docId).set(data, SetOptions(merge: true));
    await _syncProjectSettlementStatus(item.projectCode);
  }

  @override
  Future<void> deleteProjectInventory(String id, String projectCode) async {
    await _inventoryRef.doc(id).delete();
    await _syncProjectSettlementStatus(projectCode);
  }

  Future<void> _syncProjectSettlementStatus(String projectCode) async {
    final cleanCode = projectCode.trim();
    if (cleanCode.isEmpty) return;
    try {
      final snap = await _inventoryRef
          .where('project_code', isEqualTo: cleanCode)
          .get();
      final items = snap.docs
          .map((d) => ProjectInventoryItem.fromJson(d.data(), d.id))
          .toList();
      final allSettled = items.isNotEmpty && items.every((i) => i.isSettled);

      final projSnap = await _projectsRef
          .where('project_code', isEqualTo: cleanCode)
          .limit(1)
          .get();
      if (projSnap.docs.isNotEmpty) {
        await _projectsRef.doc(projSnap.docs.first.id).update({
          'supervisor_material_balance_settled': allSettled,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e, stack) {
      developer.log('Error syncing project settlement status: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
    }
  }

  // ── Permissions Register ──
  CollectionReference<Map<String, dynamic>> get _permissionsRef =>
      _firestore.collection('project_permissions');

  @override
  Stream<List<ProjectPermission>> watchPermissions(String projectCode) {
    return _permissionsRef
        .where('project_code', isEqualTo: projectCode)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ProjectPermission.fromJson(d.data(), d.id))
          .toList();
      list.sort((a, b) => a.validTo.compareTo(b.validTo));
      return list;
    });
  }

  @override
  Future<void> addPermission(
    ProjectPermission permission, [
    PlatformFile? file,
  ]) async {
    final docRef = _permissionsRef.doc();
    ProjectDocument? doc = permission.document;
    if (file != null) {
      final safeFolder = permission.projectCode.replaceAll('/', '_');
      final uploaded = await _uploadFiles(safeFolder, 'permissions', [file]);
      if (uploaded.isNotEmpty) doc = uploaded.first;
    }
    final data = permission.toJson();
    data['id'] = docRef.id;
    if (doc != null) data['document'] = doc.toJson();
    await docRef.set(data);
  }

  @override
  Future<void> deletePermission(String id, String projectCode) async {
    if (id.trim().isEmpty) return;
    await _permissionsRef.doc(id).delete();
  }

  // ── Insurance Policies ──
  CollectionReference<Map<String, dynamic>> get _insuranceRef =>
      _firestore.collection('project_insurance');

  @override
  Stream<List<ProjectInsurance>> watchInsurance(String projectCode) {
    return _insuranceRef
        .where('project_code', isEqualTo: projectCode)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ProjectInsurance.fromJson(d.data(), d.id))
          .toList();
      list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return list;
    });
  }

  @override
  Future<void> addInsurance(
    ProjectInsurance insurance, [
    PlatformFile? file,
  ]) async {
    final docRef = _insuranceRef.doc();
    ProjectDocument? doc = insurance.document;
    if (file != null) {
      final safeFolder = insurance.projectCode.replaceAll('/', '_');
      final uploaded = await _uploadFiles(safeFolder, 'insurance', [file]);
      if (uploaded.isNotEmpty) doc = uploaded.first;
    }
    final data = insurance.toJson();
    data['id'] = docRef.id;
    if (doc != null) data['document'] = doc.toJson();
    await docRef.set(data);
  }

  @override
  Future<void> deleteInsurance(String id, String projectCode) async {
    if (id.trim().isEmpty) return;
    await _insuranceRef.doc(id).delete();
  }

  // ── Incident Log ──
  CollectionReference<Map<String, dynamic>> get _incidentsRef =>
      _firestore.collection('project_incidents');

  @override
  Stream<List<IncidentLogEntry>> watchIncidents(String projectCode) {
    return _incidentsRef
        .where('project_code', isEqualTo: projectCode)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => IncidentLogEntry.fromJson(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.incidentDate.compareTo(a.incidentDate));
      return list;
    });
  }

  @override
  Future<void> addIncident(
    IncidentLogEntry incident, [
    dynamic photoFileOrFiles,
  ]) async {
    final docRef = _incidentsRef.doc();
    final List<String> photoUrls = List<String>.from(incident.photoUrls);
    List<PlatformFile> filesToUpload = [];
    if (photoFileOrFiles is PlatformFile) {
      filesToUpload = [photoFileOrFiles];
    } else if (photoFileOrFiles is List<PlatformFile>) {
      filesToUpload = photoFileOrFiles;
    }

    if (filesToUpload.isNotEmpty) {
      final safeFolder = incident.projectCode.replaceAll('/', '_');
      final uploaded = await _uploadFiles(safeFolder, 'incident_photos', filesToUpload);
      for (final doc in uploaded) {
        if (doc.downloadUrl.isNotEmpty) {
          photoUrls.add(doc.downloadUrl);
        }
      }
    }
    final data = incident.toJson();
    data['id'] = docRef.id;
    data['photo_url'] = photoUrls.isNotEmpty ? photoUrls.first : incident.photoUrl;
    data['photo_urls'] = photoUrls;
    await docRef.set(data);
  }

  @override
  Future<void> deleteIncident(String id, String projectCode) async {
    if (id.trim().isEmpty) return;
    await _incidentsRef.doc(id).delete();
  }

  // ── Project Completion and M-Book ──
  @override
  Future<void> recordProjectCompletion({
    required String projectId,
    required DateTime completionDate,
    required List<PlatformFile> mBookPhotos,
    String? recordedBy,
    String? remarks,
  }) async {
    try {
      final existingProject = await getProjectById(projectId);
      final safeFolder = (existingProject?.projectCode.isNotEmpty == true
              ? existingProject!.projectCode
              : projectId)
          .replaceAll('/', '_');

      final uploadedDocs = <ProjectDocument>[];
      if (mBookPhotos.isNotEmpty) {
        final docs = await _uploadFiles(safeFolder, 'm_book', mBookPhotos);
        uploadedDocs.addAll(docs);
      }

      final existingMBookDocs = existingProject != null
          ? List<ProjectDocument>.from(existingProject.mBookDocuments)
          : <ProjectDocument>[];
      existingMBookDocs.addAll(uploadedDocs);

      final now = DateTime.now();
      final updateData = <String, dynamic>{
        'actual_completion_date': completionDate.toIso8601String(),
        'm_book_documents': existingMBookDocs.map((d) => d.toJson()).toList(),
        'm_book_recorded_at': now.toIso8601String(),
        'status': 'Completed',
        'updated_at': now.toIso8601String(),
      };
      if (recordedBy != null && recordedBy.isNotEmpty) {
        updateData['m_book_recorded_by'] = recordedBy;
        updateData['updated_by'] = recordedBy;
      }

      await _projectsRef.doc(projectId).update(updateData);

      // Record audit history log
      final auditDoc = _auditLogsRef(projectId).doc();
      final log = ProjectAuditLog(
        id: auditDoc.id,
        projectId: projectId,
        employeeId: recordedBy ?? 'EMP-UNKNOWN',
        employeeName: recordedBy ?? 'Staff',
        designation: 'Site Operations',
        changeNote: remarks != null && remarks.trim().isNotEmpty
            ? 'Completed project work. Completion Date: ${DateFormat('dd-MM-yyyy').format(completionDate)}. Attached ${uploadedDocs.length} M-Book photo(s). Remarks: $remarks'
            : 'Completed project work. Completion Date: ${DateFormat('dd-MM-yyyy').format(completionDate)}. Attached ${uploadedDocs.length} M-Book photo(s).',
        timestamp: now,
      );
      await auditDoc.set(log.toJson());
    } catch (e, stack) {
      developer.log('Error recording project completion: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // ── Extension of Time (EOT) Letters ──
  @override
  Stream<List<EotLetter>> watchEotLetters(String projectCode) {
    return _projectsRef
        .where('general_code', isEqualTo: projectCode)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return <EotLetter>[];
      final project = SiteProject.fromJson(
        snapshot.docs.first.data(),
        docId: snapshot.docs.first.id,
      );
      final letters = List<EotLetter>.from(project.eotLetters);
      letters.sort((a, b) => b.letterDate.compareTo(a.letterDate));
      return letters;
    });
  }

  @override
  Future<void> addEotLetter({
    required String projectId,
    required EotLetter letter,
    required PlatformFile file,
    String? auditEmployeeId,
    String? auditEmployeeName,
  }) async {
    try {
      final project = await getProjectById(projectId);
      final safeFolder = (project?.projectCode.isNotEmpty == true
              ? project!.projectCode
              : projectId)
          .replaceAll('/', '_');

      // 1. Upload letter document
      final uploadedDocs =
          await _uploadFiles(safeFolder, 'eot_letters', [file]);
      final attachedDoc =
          uploadedDocs.isNotEmpty ? uploadedDocs.first : letter.document;

      final newLetter = letter.copyWith(
        document: attachedDoc,
        createdAt: DateTime.now(),
      );

      // 2. Append to project.eotLetters
      final updatedList = project != null
          ? List<EotLetter>.from(project.eotLetters)
          : <EotLetter>[];
      updatedList.add(newLetter);

      // 3. Find the latest extended completion date
      DateTime? maxExtendedDate = newLetter.extendedCompletionDate;
      for (final eot in updatedList) {
        if (maxExtendedDate == null ||
            eot.extendedCompletionDate.isAfter(maxExtendedDate)) {
          maxExtendedDate = eot.extendedCompletionDate;
        }
      }

      final now = DateTime.now();
      final updateData = <String, dynamic>{
        'eot_letters': updatedList.map((e) => e.toJson()).toList(),
        'revised_completion_date': maxExtendedDate?.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      if (auditEmployeeId != null && auditEmployeeId.isNotEmpty) {
        updateData['updated_by'] = auditEmployeeId;
      }
      if (auditEmployeeName != null && auditEmployeeName.isNotEmpty) {
        updateData['updated_by_name'] = auditEmployeeName;
      }

      await _projectsRef.doc(projectId).update(updateData);

      // 4. Record Audit Log
      final auditDoc = _auditLogsRef(projectId).doc();
      final log = ProjectAuditLog(
        id: auditDoc.id,
        projectId: projectId,
        employeeId: auditEmployeeId ?? 'EMP-SYSTEM',
        employeeName: auditEmployeeName ?? 'Project Team',
        designation: 'Operations',
        changeNote:
            'Recorded EOT Approval Letter (Ref: ${newLetter.letterRefNo}). Extended Target Date: ${DateFormat('dd-MM-yyyy').format(newLetter.extendedCompletionDate)} (+${newLetter.extendedDays} days). Reason: ${newLetter.reason}',
        timestamp: now,
      );
      await auditDoc.set(log.toJson());
    } catch (e, stack) {
      developer.log('Error adding EOT letter: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteEotLetter({
    required String projectId,
    required String letterId,
  }) async {
    try {
      final project = await getProjectById(projectId);
      if (project == null) return;
      final updatedList =
          project.eotLetters.where((e) => e.id != letterId).toList();
      DateTime? maxExtendedDate;
      for (final eot in updatedList) {
        if (maxExtendedDate == null ||
            eot.extendedCompletionDate.isAfter(maxExtendedDate)) {
          maxExtendedDate = eot.extendedCompletionDate;
        }
      }
      await _projectsRef.doc(projectId).update({
        'eot_letters': updatedList.map((e) => e.toJson()).toList(),
        'revised_completion_date': maxExtendedDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e, stack) {
      developer.log('Error deleting EOT letter: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // ── Payment Received & Completion Certificate Automation ──
  @override
  Future<void> recordPaymentReceived({
    required String projectId,
    required double amount,
    DateTime? paymentDate,
    String? remarks,
    List<DeductionEntry>? deductions,
    String? recordedBy,
    String? recordedByName,
  }) async {
    try {
      final project = await getProjectById(projectId);
      if (project == null) throw Exception('Project not found');

      final effectivePaymentDate = paymentDate ?? DateTime.now();
      final deadline = effectivePaymentDate.add(const Duration(days: 30));
      final taskId = 'TASK-CC-${DateTime.now().millisecondsSinceEpoch}';

      // 1. Auto-create follow-up task in 'tasks' collection
      try {
        final assignedTo = project.assignedToEmployeeNames.isNotEmpty
            ? project.assignedToEmployeeNames.first
            : (project.employeeName.isNotEmpty ? project.employeeName : 'All');

        await _firestore.collection('tasks').doc(taskId).set({
          'id': taskId,
          'title':
              'Upload Completion Certificate - ${project.projectCode}',
          'project_or_office_code': project.projectCode,
          'assigned_by': recordedByName ?? 'Finance Team',
          'assigned_to': assignedTo,
          'created_at': DateTime.now().toIso8601String(),
          'start_time': DateTime.now().toIso8601String(),
          'status': 'TODO',
          'priority': 'LOW', // Low (30 days SLA)
          'sla_duration_hours': 720, // 30 days
          'deadline': deadline.toIso8601String(),
          'is_paused': false,
          'accumulated_seconds': 0,
          'completion_description':
              'Follow-up Task: Payment received on ${DateFormat('dd-MM-yyyy').format(effectivePaymentDate)}. Upload project completion certificate to Company Document Vault within 30 days.',
        });
      } catch (taskErr) {
        developer.log('Non-critical: Task creation failed: $taskErr',
            name: 'FirebaseProjectRepository');
      }

      // 2. Notify project team in 'notifications' collection
      try {
        final notifDoc = _firestore.collection('notifications').doc();
        await notifDoc.set({
          'id': notifDoc.id,
          'title': 'Action Required: Upload Completion Certificate',
          'message':
              'Payment of ₹${NumberFormat('#,##,###.##').format(amount)} received for ${project.projectCode} (${project.projectName}). Upload Completion Certificate within 30 days (Deadline: ${DateFormat('dd-MM-yyyy').format(deadline)}).',
          'type': 'completion_certificate_reminder',
          'required_permission': '',
          'sender_id': recordedBy ?? 'SYSTEM',
          'sender_name': recordedByName ?? 'Finance System',
          'route': '/projects/manage/$projectId',
          'created_at': DateTime.now().toIso8601String(),
          'read_by_employee_ids': <String>[],
          'metadata': {
            'project_id': projectId,
            'project_code': project.projectCode,
            'task_id': taskId,
            'deadline': deadline.toIso8601String(),
          },
        });
      } catch (notifErr) {
        developer.log('Non-critical: Notification failed: $notifErr',
            name: 'FirebaseProjectRepository');
      }

      // 3. Update SiteProject in Firestore
      final now = DateTime.now();
      final updateData = <String, dynamic>{
        'payment_amount': amount,
        'payment_received_date': effectivePaymentDate.toIso8601String(),
        'completion_certificate_deadline': deadline.toIso8601String(),
        'completion_certificate_task_id': taskId,
        'updated_at': now.toIso8601String(),
      };
      if (remarks != null && remarks.isNotEmpty) {
        updateData['payment_received_remark'] = remarks;
      }
      if (deductions != null) {
        updateData['deductions'] = deductions.map((d) => d.toJson()).toList();
      }
      if (recordedBy != null && recordedBy.isNotEmpty) {
        updateData['updated_by'] = recordedBy;
      }
      if (recordedByName != null && recordedByName.isNotEmpty) {
        updateData['updated_by_name'] = recordedByName;
      }

      await _projectsRef.doc(projectId).update(updateData);

      // 4. Record Audit Log
      final auditDoc = _auditLogsRef(projectId).doc();
      final log = ProjectAuditLog(
        id: auditDoc.id,
        projectId: projectId,
        employeeId: recordedBy ?? 'EMP-FINANCE',
        employeeName: recordedByName ?? 'Finance Team',
        designation: 'Accounts',
        changeNote:
            'Recorded Payment Received: ₹${NumberFormat('#,##,###.##').format(amount)}. Triggered 30-day Completion Certificate deadline (${DateFormat('dd-MM-yyyy').format(deadline)}) & follow-up task ($taskId).',
        timestamp: now,
      );
      await auditDoc.set(log.toJson());
    } catch (e, stack) {
      developer.log('Error recording payment received: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> uploadCompletionCertificate({
    required String projectId,
    required PlatformFile file,
    required String title,
    String? remarks,
    String? uploadedBy,
    String? uploadedByName,
  }) async {
    try {
      final project = await getProjectById(projectId);
      if (project == null) throw Exception('Project not found');

      // 1. Upload to Storage & Save to Company Document Vault under Experience Certificates
      final companyDocRef = _firestore.collection('company_documents').doc();
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath =
          'company_documents/EXP_CERT/${companyDocRef.id}_$safeName';

      String downloadUrl = '';
      try {
        final ref = _storage.ref().child(storagePath);
        final bytes = file.bytes ?? Uint8List(0);
        final contentType = file.name.toLowerCase().endsWith('.pdf')
            ? 'application/pdf'
            : 'image/jpeg';
        final uploadTask = await ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        downloadUrl = await uploadTask.ref.getDownloadURL();
      } catch (storageErr) {
        developer.log(
          'Firebase Storage putData failed ($storageErr). Saving as data URI fallback.',
          name: 'FirebaseProjectRepository',
        );
        final bytes = file.bytes ?? Uint8List(0);
        final base64Str = base64Encode(bytes);
        downloadUrl = 'data:application/pdf;base64,$base64Str';
      }

      final now = DateTime.now();
      final projectDoc = ProjectDocument(
        name: file.name,
        size: file.size,
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        uploadedAt: now,
      );

      final vaultTitle = title.trim().isNotEmpty
          ? title.trim()
          : '${project.projectCode} Completion Certificate';

      final vaultItemData = {
        'id': companyDocRef.id,
        'doc_type': 'EXP_CERT',
        'title': vaultTitle,
        'project_code': project.projectCode,
        'document': projectDoc.toJson(),
        'created_at': now.toIso8601String(),
      };
      await companyDocRef.set(vaultItemData);

      // 2. Update Project status
      await _projectsRef.doc(projectId).update({
        'is_completion_certificate_uploaded': true,
        'completion_certificate_uploaded_at': now.toIso8601String(),
        'completion_certificate_doc_id': companyDocRef.id,
        'updated_at': now.toIso8601String(),
      });

      // 3. Mark Follow-up Task as Completed (if any)
      if (project.completionCertificateTaskId != null &&
          project.completionCertificateTaskId!.isNotEmpty) {
        try {
          await _firestore
              .collection('tasks')
              .doc(project.completionCertificateTaskId)
              .update({
            'status': 'COMPLETED',
            'end_time': now.toIso8601String(),
            'completion_description':
                'Completion Certificate uploaded to Company Document Vault under Experience Certificates by ${uploadedByName ?? "User"}.',
          });
        } catch (_) {}
      }

      // 4. Record Audit Log
      final auditDoc = _auditLogsRef(projectId).doc();
      final log = ProjectAuditLog(
        id: auditDoc.id,
        projectId: projectId,
        employeeId: uploadedBy ?? 'EMP-SYSTEM',
        employeeName: uploadedByName ?? 'Project Team',
        designation: 'Operations',
        changeNote:
            'Uploaded Completion Certificate ($vaultTitle). Saved to Company Document Vault under Experience Certificates.',
        timestamp: now,
      );
      await auditDoc.set(log.toJson());
    } catch (e, stack) {
      developer.log('Error uploading completion certificate: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
