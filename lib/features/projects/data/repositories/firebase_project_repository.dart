import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/models/project_document.dart';
import '../../domain/models/site_project.dart';
import '../../domain/repositories/project_repository.dart';

class FirebaseProjectRepository implements ProjectRepository {
  FirebaseProjectRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _projectsRef =>
      _firestore.collection('site_projects');

  CollectionReference<Map<String, dynamic>> get _tenderTypesRef =>
      _firestore.collection('tender_types');

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

      // 2. Upload attachments per category if provided
      final tenderDocs = List<ProjectDocument>.from(project.tenderSpecDocuments);
      final bqrDocs = List<ProjectDocument>.from(project.bqrDocuments);
      final emdDocs = List<ProjectDocument>.from(project.emdDocuments);

      if (filesByCategory != null) {
        if (filesByCategory['tender_spec'] != null) {
          final uploaded = await _uploadFiles(
            docId,
            'tender_spec',
            filesByCategory['tender_spec']!,
          );
          tenderDocs.addAll(uploaded);
        }
        if (filesByCategory['bqr'] != null) {
          final uploaded = await _uploadFiles(
            docId,
            'bqr',
            filesByCategory['bqr']!,
          );
          bqrDocs.addAll(uploaded);
        }
        if (filesByCategory['emd'] != null) {
          final uploaded = await _uploadFiles(
            docId,
            'emd',
            filesByCategory['emd']!,
          );
          emdDocs.addAll(uploaded);
        }
      }

      // 3. Assemble final project
      final finalProject = project.copyWith(
        id: docId,
        tenderSpecDocuments: tenderDocs,
        bqrDocuments: bqrDocs,
        emdDocuments: emdDocs,
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
      try {
        if (file.bytes != null) {
          final cleanFileName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final ref = _storage.ref().child('projects/$projectId/$category/${DateTime.now().millisecondsSinceEpoch}_$cleanFileName');
          final uploadTask = await ref.putData(
            file.bytes!,
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
  Future<void> updateProject(SiteProject project) async {
    try {
      final data = project.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();
      await _projectsRef.doc(project.id).update(data);
    } catch (e, stack) {
      developer.log('Error updating project ${project.id}: $e',
          name: 'FirebaseProjectRepository', error: e, stackTrace: stack);
      rethrow;
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
