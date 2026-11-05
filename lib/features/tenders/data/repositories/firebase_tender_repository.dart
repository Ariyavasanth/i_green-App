import 'dart:developer' as developer;
import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../projects/domain/models/project_document.dart';
import '../../domain/models/tender.dart';
import '../../domain/repositories/tender_repository.dart';

class FirebaseTenderRepository implements TenderRepository {
  FirebaseTenderRepository({
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

  CollectionReference<Map<String, dynamic>> get _tendersRef =>
      _firestore.collection('tenders');

  @override
  Future<String> generateNextTenderId() async {
    try {
      final now = DateTime.now();
      final year = now.year.toString();
      final snap = await _tendersRef.get();
      final count = snap.docs.length + 1;
      final seq = count.toString().padLeft(4, '0');
      return 'TE-$year-$seq';
    } catch (_) {
      final now = DateTime.now();
      return 'TE-${now.year}-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
    }
  }

  @override
  Future<String> createTender(
    Tender tender, {
    Map<String, List<PlatformFile>>? filesByCategory,
  }) async {
    try {
      final docRef = _tendersRef.doc();
      final docId = docRef.id;
      final tenderId = tender.tenderId.trim().isNotEmpty
          ? tender.tenderId.trim()
          : await generateNextTenderId();

      final storageFolderId = tenderId.replaceAll('/', '_');

      final specDocs = List<ProjectDocument>.from(tender.tenderSpecDocuments);
      final bqrDocs = List<ProjectDocument>.from(tender.bqrDocuments);
      final emdDocs = List<ProjectDocument>.from(tender.emdDocuments);

      if (filesByCategory != null) {
        Future<void> uploadCategory(
            String key, List<ProjectDocument> target) async {
          final files = filesByCategory[key];
          if (files != null && files.isNotEmpty) {
            final uploaded = await _uploadFiles(storageFolderId, key, files);
            target.addAll(uploaded);
          }
        }

        await uploadCategory('tender_spec', specDocs);
        await uploadCategory('bqr', bqrDocs);
        await uploadCategory('emd', emdDocs);
      }

      final now = DateTime.now();
      final finalTender = tender.copyWith(
        id: docId,
        tenderId: tenderId,
        tenderSpecDocuments: specDocs,
        bqrDocuments: bqrDocs,
        emdDocuments: emdDocs,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(finalTender.toJson());
      return docId;
    } catch (e, stack) {
      developer.log('Error creating tender: $e',
          name: 'FirebaseTenderRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> updateTender(
    Tender tender, {
    Map<String, List<PlatformFile>>? filesByCategory,
  }) async {
    try {
      final storageFolderId = (tender.tenderId.trim().isNotEmpty
              ? tender.tenderId.trim()
              : tender.id)
          .replaceAll('/', '_');

      final specDocs = List<ProjectDocument>.from(tender.tenderSpecDocuments);
      final bqrDocs = List<ProjectDocument>.from(tender.bqrDocuments);
      final emdDocs = List<ProjectDocument>.from(tender.emdDocuments);

      if (filesByCategory != null) {
        Future<void> uploadCategory(
            String key, List<ProjectDocument> target) async {
          final files = filesByCategory[key];
          if (files != null && files.isNotEmpty) {
            final uploaded = await _uploadFiles(storageFolderId, key, files);
            target.addAll(uploaded);
          }
        }

        await uploadCategory('tender_spec', specDocs);
        await uploadCategory('bqr', bqrDocs);
        await uploadCategory('emd', emdDocs);
      }

      final finalTender = tender.copyWith(
        tenderSpecDocuments: specDocs,
        bqrDocuments: bqrDocs,
        emdDocuments: emdDocs,
        updatedAt: DateTime.now(),
      );

      await _tendersRef.doc(tender.id).set(
            finalTender.toJson(),
            SetOptions(merge: true),
          );
    } catch (e, stack) {
      developer.log('Error updating tender: $e',
          name: 'FirebaseTenderRepository', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteTender(String id) async {
    await _tendersRef.doc(id).delete();
  }

  @override
  Stream<List<Tender>> watchTenders() {
    return _tendersRef
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Tender.fromJson(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<List<Tender>> getTenders() async {
    final snap =
        await _tendersRef.orderBy('created_at', descending: true).get();
    return snap.docs
        .map((doc) => Tender.fromJson(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<Tender?> getTenderById(String id) async {
    final doc = await _tendersRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Tender.fromJson(doc.data()!, doc.id);
  }

  Future<List<ProjectDocument>> _uploadFiles(
    String tenderId,
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
              'tenders/$tenderId/$category/${timestamp}_$cleanFileName';
          final ref = _storage.ref().child(storagePath);
          final uploadTask = await ref.putData(
            bytes,
            SettableMetadata(contentType: _getContentType(file.extension)),
          );
          downloadUrl = await uploadTask.ref.getDownloadURL();
        }
      } catch (e) {
        developer.log('Storage upload fallback for ${file.name}: $e',
            name: 'FirebaseTenderRepository');
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

  String _getContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
