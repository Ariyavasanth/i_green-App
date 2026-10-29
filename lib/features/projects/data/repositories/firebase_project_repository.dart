import 'dart:developer' as developer;
import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/project_audit_log.dart';
import '../../domain/models/project_document.dart';
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
    'Open Tender',
    'Limited Tender',
    'Single Tender / Direct',
    'E-Tender',
    'Item Rate Tender',
    'Percentage Rate Tender',
    'EPC Tender',
    'Turnkey Tender',
    'Quotation',
    'Other',
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
          final ref = _storage.ref().child(storagePath);
          final uploadTask = await ref.putData(
            bytes,
            SettableMetadata(contentType: _getContentType(file.extension)),
          );
          downloadUrl = await uploadTask.ref.getDownloadURL();
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
          .map((doc) => SiteProject.fromJson(doc.data(), docId: doc.id))
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
      final list = snap.docs
          .map((doc) => SiteProject.fromJson(doc.data(), docId: doc.id))
          .toList();
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
      }

      final finalProject = project.copyWith(
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
        updatedAt: DateTime.now(),
      );

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
}
