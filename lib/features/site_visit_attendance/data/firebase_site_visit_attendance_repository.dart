import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

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
      final docRef = _visitsRef.doc();
      final intId = _docIdToInt(docRef.id);
      data['id'] = intId;
      await docRef.set(data);
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
    // Prevent duplicate Day Checkout entries on the same day
    final existing = await _visitsRef
        .where('employee_id', isEqualTo: employeeId)
        .where('visit_date', isEqualTo: visitDate)
        .where('site_name', isEqualTo: 'Day Checkout')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return;
    }

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
    // Fallback: check matching doc ID or _docIdToInt(doc.id)
    final allDocs = await _visitsRef.get();
    for (final d in allDocs.docs) {
      if (d.id == id.toString() || _docIdToInt(d.id) == id) {
        final data = d.data();
        final photoUrl = data['photo_url'] as String? ?? '';
        final publicId = data['photo_public_id'] as String? ?? '';
        await d.reference.delete();
        await _deleteLocalPhotoIfPresent(photoUrl);
        await _deleteStoragePhotoIfPresent(publicId, photoUrl);
        return;
      }
    }
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
    Uint8List? bytes;
    try {
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

      if (bytes != null && bytes.isNotEmpty) {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final stamp = img.copyResize(decoded, width: decoded.width);
          final black = img.ColorRgb8(0, 0, 0);
          final white = img.ColorRgb8(255, 255, 255);
          final accent = img.ColorRgb8(156, 199, 10);
          final footerHeight = (stamp.height * 0.22).clamp(140, 220).toInt();
          final canvas = img.Image(width: stamp.width, height: stamp.height + footerHeight);
          img.fill(canvas, color: black);
          img.compositeImage(canvas, stamp, dstX: 0, dstY: 0);
          img.fillRect(canvas, x1: 0, y1: stamp.height, x2: stamp.width, y2: stamp.height + footerHeight - 1, color: black);
          img.fillRect(canvas, x1: 0, y1: stamp.height, x2: stamp.width, y2: stamp.height + 5, color: accent);
          img.drawString(canvas, 'Site visit verified', font: img.arial24, x: 16, y: stamp.height + 14, color: white);
          img.drawString(canvas, employeeName, font: img.arial24, x: 16, y: stamp.height + 42, color: white);
          img.drawString(canvas, siteName, font: img.arial24, x: 16, y: stamp.height + 68, color: white);
          img.drawString(canvas, 'Time: $visitDate $visitTime', font: img.arial14, x: 16, y: stamp.height + 98, color: white);
          img.drawString(canvas, 'Geo: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}', font: img.arial14, x: 16, y: stamp.height + 120, color: white);
          bytes = Uint8List.fromList(img.encodeJpg(canvas));
        }
      }

      final fileName = 'site_visit_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'Site Attendence/$fileName';
      final ref = _storage.ref().child(storagePath);

      TaskSnapshot uploadTask;
      if (bytes != null && bytes.isNotEmpty) {
        uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else if (!kIsWeb) {
        final file = File(localImagePath);
        uploadTask = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        return SiteVisitPhotoAsset(url: localImagePath, publicId: '');
      }

      final remoteUrl = await uploadTask.ref.getDownloadURL();
      return SiteVisitPhotoAsset(url: remoteUrl, publicId: storagePath);
    } catch (_) {
      // If Firebase Storage upload fails (permissions, offline, or CORS), fallback to base64
      // so the captured photo can be rendered on any device/platform rather than saving an unreachable local path.
      if (bytes != null && bytes.isNotEmpty) {
        return SiteVisitPhotoAsset(
          url: 'data:image/jpeg;base64,${base64Encode(bytes)}',
          publicId: '',
        );
      }
      if (!kIsWeb && localImagePath.isNotEmpty) {
        try {
          final file = File(localImagePath);
          if (file.existsSync()) {
            final fBytes = file.readAsBytesSync();
            return SiteVisitPhotoAsset(
              url: 'data:image/jpeg;base64,${base64Encode(fBytes)}',
              publicId: '',
            );
          }
        } catch (_) {}
      }
      return SiteVisitPhotoAsset(url: localImagePath, publicId: '');
    }
  }

  int _docIdToInt(String docId) => int.tryParse(docId.replaceAll(RegExp(r'\D'), '')) ?? (docId.hashCode & 0x7fffffff);

  Future<void> _deleteLocalPhotoIfPresent(String photoUrl) async {
    if (kIsWeb || photoUrl.isEmpty) return;
    try {
      final file = File(photoUrl);
      if (await file.exists()) {
        await file.delete();
      }
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

