import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/site_visit_attendance_repository.dart';
import '../domain/site_visit_photo_asset.dart';
import '../domain/site_visit_record.dart';

class FirebaseSiteVisitAttendanceRepository implements SiteVisitAttendanceRepository {
  FirebaseSiteVisitAttendanceRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _visitsRef => _firestore.collection('site_visit_records');

  @override
  Future<List<SiteVisitRecord>> getVisitsForEmployee({
    required int employeeId,
    required String visitDate,
  }) async {
    final snap = await _visitsRef
        .where('employee_id', isEqualTo: employeeId)
        .where('visit_date', isEqualTo: visitDate)
        .get();
    final visits = snap.docs
        .map((doc) => SiteVisitRecord.fromMap({...doc.data(), 'id': _docIdToInt(doc.id)}))
        .toList();
    visits.sort((a, b) => a.visitTime.compareTo(b.visitTime));
    return visits;
  }

  @override
  Future<List<SiteVisitRecord>> getAllVisits({String? visitDate}) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    if (visitDate == null || visitDate.isEmpty) {
      snap = await _visitsRef.get();
    } else {
      snap = await _visitsRef.where('visit_date', isEqualTo: visitDate).get();
    }
    final visits = snap.docs
        .map((doc) => SiteVisitRecord.fromMap({...doc.data(), 'id': _docIdToInt(doc.id)}))
        .toList();
    visits.sort((a, b) {
      final byDate = b.visitDate.compareTo(a.visitDate);
      if (byDate != 0) return byDate;
      return b.visitTime.compareTo(a.visitTime);
    });
    return visits;
  }

  @override
  Future<SiteVisitRecord?> getVisitById(int id) async {
    final snap = await _visitsRef.where('id', isEqualTo: id).limit(1).get();
    if (snap.docs.isNotEmpty) {
      return SiteVisitRecord.fromMap({...snap.docs.first.data(), 'id': _docIdToInt(snap.docs.first.id)});
    }
    return null;
  }

  @override
  Future<void> saveVisit(SiteVisitRecord record) async {
    final data = record.toMap();
    if (record.id == 0) {
      data.remove('id');
      await _visitsRef.add(data);
      return;
    }
    await _visitsRef.doc(record.id.toString()).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> saveDayCheckout({
    required int employeeId,
    required String employeeName,
    required String visitDate,
    required String visitTime,
    required double latitude,
    required double longitude,
    String notes = '',
  }) async {
    await saveVisit(
      SiteVisitRecord(
        id: 0,
        employeeId: employeeId,
        employeeName: employeeName,
        siteName: 'Day Checkout',
        visitDate: visitDate,
        visitTime: visitTime,
        photoUrl: '',
        photoPublicId: '',
        latitude: latitude,
        longitude: longitude,
        address: '',
        notes: notes.isEmpty ? 'Checked out for the day' : notes,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Future<void> deleteVisit(int id) async {
    final doc = await _visitsRef.where('id', isEqualTo: id).limit(1).get();
    if (doc.docs.isNotEmpty) {
      final data = doc.docs.first.data();
      final photoUrl = data['photo_url'] as String? ?? '';
      final publicId = data['photo_public_id'] as String? ?? '';
      await doc.docs.first.reference.delete();
      await _deleteLocalPhotoIfPresent(photoUrl);
      await _deleteStoragePhotoIfPresent(publicId, photoUrl);
      return;
    }
    await _visitsRef.doc(id.toString()).delete();
  }

  @override
  Future<SiteVisitPhotoAsset> createVisitPhotoUrl({
    required String localImagePath,
    required String employeeName,
    required String siteName,
    required String visitDate,
    required String visitTime,
    required double latitude,
    required double longitude,
  }) async {
    try {
      Uint8List? bytes;
      if (localImagePath.startsWith('data:image')) {
        final base64Str = localImagePath.split(',').last;
        bytes = base64Decode(base64Str);
      } else if (localImagePath.startsWith('http://') || localImagePath.startsWith('https://')) {
        return SiteVisitPhotoAsset(url: localImagePath, publicId: '');
      } else if (kIsWeb || localImagePath.startsWith('blob:')) {
        final response = await http.get(Uri.parse(localImagePath));
        bytes = response.bodyBytes;
      } else {
        final file = File(localImagePath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      final fileName = 'site_visit_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'Site Attendence/$fileName';
      final ref = _storage.ref().child(storagePath);

      TaskSnapshot uploadTask;
      if (bytes != null && bytes.isNotEmpty) {
        uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        final file = File(localImagePath);
        uploadTask = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      }

      final remoteUrl = await uploadTask.ref.getDownloadURL();
      return SiteVisitPhotoAsset(url: remoteUrl, publicId: storagePath);
    } catch (_) {
      return SiteVisitPhotoAsset(url: localImagePath, publicId: '');
    }
  }

  int _docIdToInt(String docId) => int.tryParse(docId.replaceAll(RegExp(r'\D'), '')) ?? (docId.hashCode & 0x7fffffff);

  Future<void> _deleteLocalPhotoIfPresent(String photoUrl) async {
    if (photoUrl.isEmpty) return;
    final file = File(photoUrl);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {
      // Best effort cleanup only.
    }
  }

  Future<void> _deleteStoragePhotoIfPresent(String publicId, String photoUrl) async {
    try {
      if (publicId.isNotEmpty) {
        await _storage.ref().child(publicId).delete();
      } else if (photoUrl.startsWith('http')) {
        await _storage.refFromURL(photoUrl).delete();
      }
    } catch (_) {
      // Best effort cleanup only.
    }
  }
}

