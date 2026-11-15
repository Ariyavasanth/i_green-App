import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_application_1/features/projects/domain/models/project_document.dart';
import 'package:flutter_application_1/features/projects/domain/models/site_project.dart';
import 'package:flutter_application_1/features/retention_sd/domain/models/retention_sd_record.dart';
import 'package:flutter_application_1/features/retention_sd/domain/repositories/retention_sd_repository.dart';

class FirebaseRetentionSdRepository implements RetentionSdRepository {
  FirebaseRetentionSdRepository({
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

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('retention_sd_followups');

  RetentionSdRecord _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    data['id'] = doc.id;
    return RetentionSdRecord.fromJson(data);
  }

  @override
  Stream<List<RetentionSdRecord>> watchRecords() {
    return _collection.snapshots().map((snap) {
      final list = <RetentionSdRecord>[];
      for (final doc in snap.docs) {
        try {
          list.add(_fromDoc(doc));
        } catch (e, st) {
          developer.log(
            'Error parsing retention SD record ${doc.id}: $e',
            name: 'FirebaseRetentionSdRepository',
            error: e,
            stackTrace: st,
          );
        }
      }
      list.sort((a, b) {
        // Sort: BG Expiring soon first, then by retention due date, then by updated date
        final aBgDays = a.daysUntilBgExpiry;
        final bBgDays = b.daysUntilBgExpiry;
        if (a.isBgExpiringSoon && !b.isBgExpiringSoon) return -1;
        if (!a.isBgExpiringSoon && b.isBgExpiringSoon) return 1;
        if (aBgDays != null && bBgDays != null) {
          return aBgDays.compareTo(bBgDays);
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return list;
    });
  }

  @override
  Future<List<RetentionSdRecord>> getRecords() async {
    try {
      final snap = await _collection.get();
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } catch (e, st) {
      developer.log(
        'Error fetching retention SD records: $e',
        name: 'FirebaseRetentionSdRepository',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  @override
  Future<RetentionSdRecord?> getRecordById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return _fromDoc(doc);
    } catch (e, st) {
      developer.log(
        'Error getting retention SD record $id: $e',
        name: 'FirebaseRetentionSdRepository',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  Future<RetentionSdRecord?> getRecordByProjectId(String projectId) async {
    try {
      final snap = await _collection
          .where('project_id', isEqualTo: projectId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return _fromDoc(snap.docs.first);
    } catch (e, st) {
      developer.log(
        'Error getting retention SD record by projectId $projectId: $e',
        name: 'FirebaseRetentionSdRepository',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  Future<void> saveRecord(
    RetentionSdRecord record, {
    List<PlatformFile>? claimFiles,
    List<PlatformFile>? bgFiles,
  }) async {
    try {
      final docRef = record.id.trim().isNotEmpty
          ? _collection.doc(record.id.trim())
          : _collection.doc();
      final recordId = docRef.id;

      var claimDocs = List<ProjectDocument>.from(record.claimDocuments);
      if (claimFiles != null && claimFiles.isNotEmpty) {
        final uploaded = await _uploadFiles(recordId, 'claim_docs', claimFiles);
        claimDocs.addAll(uploaded);
      }

      var bg = record.bg;
      if (bg != null && bgFiles != null && bgFiles.isNotEmpty) {
        final uploaded = await _uploadFiles(recordId, 'bg_docs', bgFiles);
        final currentDocs = List<ProjectDocument>.from(bg.documents)..addAll(uploaded);
        bg = bg.copyWith(documents: currentDocs);
      }

      final updatedRecord = record.copyWith(
        id: recordId,
        claimDocuments: claimDocs,
        bg: bg,
        updatedAt: DateTime.now(),
      );

      await docRef.set(updatedRecord.toJson(), SetOptions(merge: true));
    } catch (e, st) {
      developer.log(
        'Error saving retention SD record: $e',
        name: 'FirebaseRetentionSdRepository',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateClaimStatus({
    required String recordId,
    required RetentionClaimStatus status,
    DateTime? submissionDate,
    String? referenceNo,
    DateTime? releasedDate,
    double? releasedAmount,
    String? remarks,
    List<PlatformFile>? documents,
    String? updatedBy,
  }) async {
    try {
      final docRef = _collection.doc(recordId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final existing = _fromDoc(doc);
      var currentDocs = List<ProjectDocument>.from(existing.claimDocuments);
      if (documents != null && documents.isNotEmpty) {
        final uploaded = await _uploadFiles(recordId, 'claim_docs', documents);
        currentDocs.addAll(uploaded);
      }

      final Map<String, dynamic> updates = {
        'claim_status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
        'claim_documents': currentDocs.map((d) => d.toJson()).toList(),
      };

      if (updatedBy != null) updates['updated_by'] = updatedBy;

      if (status == RetentionClaimStatus.submitted) {
        updates['claim_submission_date'] =
            (submissionDate ?? DateTime.now()).toIso8601String();
        if (referenceNo != null && referenceNo.isNotEmpty) {
          updates['claim_reference_no'] = referenceNo;
        }
        if (remarks != null && remarks.isNotEmpty) {
          updates['claim_remarks'] = remarks;
        }
      } else if (status == RetentionClaimStatus.released) {
        updates['released_date'] =
            (releasedDate ?? DateTime.now()).toIso8601String();
        updates['released_amount'] =
            releasedAmount ?? existing.totalFollowUpAmount;
        if (remarks != null && remarks.isNotEmpty) {
          updates['release_remarks'] = remarks;
        }
      } else {
        if (remarks != null && remarks.isNotEmpty) {
          updates['claim_remarks'] = remarks;
        }
      }

      await docRef.update(updates);
    } catch (e, st) {
      developer.log(
        'Error updating claim status for $recordId: $e',
        name: 'FirebaseRetentionSdRepository',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateBgDetails({
    required String recordId,
    required BankGuaranteeDetail bg,
    List<PlatformFile>? documents,
    String? updatedBy,
  }) async {
    try {
      final docRef = _collection.doc(recordId);
      var bgDocs = List<ProjectDocument>.from(bg.documents);
      if (documents != null && documents.isNotEmpty) {
        final uploaded = await _uploadFiles(recordId, 'bg_docs', documents);
        bgDocs.addAll(uploaded);
      }

      final updatedBg = bg.copyWith(documents: bgDocs);

      await docRef.update({
        'has_bg': true,
        'bg': updatedBg.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
        if (updatedBy != null) 'updated_by': updatedBy,
      });
    } catch (e, st) {
      developer.log(
        'Error updating BG details for $recordId: $e',
        name: 'FirebaseRetentionSdRepository',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteRecord(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e, st) {
      developer.log(
        'Error deleting retention SD record $id: $e',
        name: 'FirebaseRetentionSdRepository',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> syncWithSiteProjects(List<SiteProject> projects) async {
    try {
      final existingRecords = await getRecords();
      final projectRecordMap = <String, RetentionSdRecord>{};
      for (final r in existingRecords) {
        projectRecordMap[r.projectId] = r;
      }

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final p in projects) {
        final totalRet =
            p.sdRetentionAmount + p.emdRetentionAmount + p.otherRetentionAmount;
        final hasRetention = totalRet > 0;
        final hasSd = p.sdAmount > 0 ||
            p.sdAgreementNo.isNotEmpty ||
            p.sdAgreementDate != null;

        if (!hasRetention && !hasSd) continue;

        final existing = projectRecordMap[p.id];
        final now = DateTime.now();

        if (existing == null) {
          // Detect if BG is indicated in SD agreement or remark
          final isBgIndicated =
              p.sdAgreementNo.toUpperCase().contains('BG') ||
              p.sdDateRemark.toUpperCase().contains('BG');

          BankGuaranteeDetail? defaultBg;
          if (isBgIndicated || p.sdAmount > 0) {
            defaultBg = BankGuaranteeDetail(
              bgNumber: p.sdAgreementNo,
              bgAmount: p.sdAmount,
              issueDate: p.sdAgreementDate,
              expiryDate: p.sdRetentionDate ??
                  (p.sdAgreementDate != null
                      ? p.sdAgreementDate!.add(const Duration(days: 365))
                      : null),
              status: 'Active',
              remarks: p.sdDateRemark,
            );
          }

          final newDocRef = _collection.doc();
          final newRecord = RetentionSdRecord(
            id: newDocRef.id,
            projectId: p.id,
            projectCode: p.projectCode,
            projectName: p.projectName,
            clientName: p.clientName,
            division: p.division,
            retentionAmount: totalRet,
            retentionDueDate: p.sdRetentionDate ??
                p.emdRetentionDate ??
                p.otherRetentionDate,
            retentionRemarks: p.sdRetentionRemark.isNotEmpty
                ? p.sdRetentionRemark
                : p.emdRetentionRemark,
            sdAmount: p.sdAmount,
            sdDueDate: p.sdAgreementDate,
            sdAgreementNo: p.sdAgreementNo,
            sdRemarks: p.sdDateRemark,
            claimStatus: RetentionClaimStatus.pending,
            hasBg: defaultBg != null,
            bg: defaultBg,
            createdAt: now,
            updatedAt: now,
          );

          batch.set(newDocRef, newRecord.toJson());
          batchCount++;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
        developer.log(
          'Synced $batchCount retention SD records from site projects',
          name: 'FirebaseRetentionSdRepository',
        );
      }
    } catch (e, st) {
      developer.log(
        'Error syncing site projects with retention SD records: $e',
        name: 'FirebaseRetentionSdRepository',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<List<ProjectDocument>> _uploadFiles(
    String recordId,
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
              'retention_sd_followups/$recordId/$category/${timestamp}_$cleanFileName';
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
              name: 'FirebaseRetentionSdRepository',
            );
            final mime = _getContentType(file.extension);
            final base64Str = base64Encode(bytes);
            downloadUrl = 'data:$mime;base64,$base64Str';
          }
        }
      } catch (e) {
        developer.log(
          'Storage upload fallback for ${file.name}: $e',
          name: 'FirebaseRetentionSdRepository',
        );
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
      default:
        return 'application/octet-stream';
    }
  }
}
