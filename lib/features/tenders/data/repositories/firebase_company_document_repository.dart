import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../projects/domain/models/project_document.dart';
import '../../domain/models/company_document_item.dart';
import '../../domain/repositories/company_document_repository.dart';

class FirebaseCompanyDocumentRepository implements CompanyDocumentRepository {
  FirebaseCompanyDocumentRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('company_documents');

  @override
  Stream<List<CompanyDocumentItem>> watchDocuments() {
    return _collection
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CompanyDocumentItem.fromJson(d.data(), d.id))
              .toList(),
        );
  }

  @override
  Future<List<CompanyDocumentItem>> getDocuments() async {
    final snap = await _collection.orderBy('created_at', descending: true).get();
    return snap.docs
        .map((d) => CompanyDocumentItem.fromJson(d.data(), d.id))
        .toList();
  }

  Future<ProjectDocument> _uploadToBucket({
    required String docId,
    required CompanyDocType docType,
    required PlatformFile file,
  }) async {
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = 'company_documents/${docType.code}/${docId}_$safeName';
    final ref = _storage.ref().child(storagePath);

    final bytes = file.bytes ?? Uint8List(0);
    String contentType = 'application/octet-stream';
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.png')) {
      contentType = 'image/png';
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    } else if (lower.endsWith('.webp')) {
      contentType = 'image/webp';
    } else if (lower.endsWith('.pdf')) {
      contentType = 'application/pdf';
    }

    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    final url = await ref.getDownloadURL();

    return ProjectDocument(
      name: file.name,
      storagePath: storagePath,
      downloadUrl: url,
      category: docType.code,
      size: file.size,
      uploadedAt: DateTime.now(),
    );
  }

  @override
  Future<CompanyDocumentItem> addDocument({
    required CompanyDocType docType,
    required String title,
    required PlatformFile file,
    String? financialYear,
    String? monthYear,
    String? projectCode,
    DateTime? startDate,
    DateTime? expiryDate,
    int alertBeforeDays = 30,
  }) async {
    final docRef = _collection.doc();
    final projectDoc = await _uploadToBucket(
      docId: docRef.id,
      docType: docType,
      file: file,
    );

    final item = CompanyDocumentItem(
      id: docRef.id,
      docType: docType,
      title: title,
      financialYear: financialYear,
      monthYear: monthYear,
      projectCode: projectCode,
      startDate: startDate,
      expiryDate: expiryDate,
      alertBeforeDays: alertBeforeDays,
      document: projectDoc,
      createdAt: DateTime.now(),
    );

    await docRef.set(item.toJson());
    return item;
  }

  @override
  Future<CompanyDocumentItem> updateDocument({
    required CompanyDocumentItem existing,
    required CompanyDocType docType,
    required String title,
    PlatformFile? newFile,
    String? financialYear,
    String? monthYear,
    String? projectCode,
    DateTime? startDate,
    DateTime? expiryDate,
    int alertBeforeDays = 30,
  }) async {
    ProjectDocument finalDoc = existing.document;

    if (newFile != null) {
      finalDoc = await _uploadToBucket(
        docId: existing.id,
        docType: docType,
        file: newFile,
      );
      if (existing.document.storagePath.isNotEmpty &&
          existing.document.storagePath != finalDoc.storagePath) {
        try {
          await _storage.ref().child(existing.document.storagePath).delete();
        } catch (_) {
          // Ignore missing old storage object
        }
      }
    }

    final updated = CompanyDocumentItem(
      id: existing.id,
      docType: docType,
      title: title,
      financialYear: financialYear,
      monthYear: monthYear,
      projectCode: projectCode,
      startDate: startDate,
      expiryDate: expiryDate,
      alertBeforeDays: alertBeforeDays,
      document: finalDoc,
      createdAt: existing.createdAt,
    );

    await _collection.doc(existing.id).set(updated.toJson());
    return updated;
  }

  @override
  Future<void> deleteDocument(String id) async {
    final snap = await _collection.doc(id).get();
    if (snap.exists) {
      final item = CompanyDocumentItem.fromJson(snap.data()!, snap.id);
      if (item.document.storagePath.isNotEmpty) {
        try {
          await _storage.ref().child(item.document.storagePath).delete();
        } catch (_) {
          // Ignore missing storage object
        }
      }
      await _collection.doc(id).delete();
    }
  }
}
