import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../domain/site_visit_attendance_repository.dart';
import '../domain/site_visit_photo_asset.dart';
import '../domain/site_visit_record.dart';

class FirebaseSiteVisitAttendanceRepository implements SiteVisitAttendanceRepository {
  FirebaseSiteVisitAttendanceRepository({
    FirebaseFirestore? firestore,
    Uri? cloudinarySignerBaseUri,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        cloudinarySignerBaseUri = cloudinarySignerBaseUri ??
            Uri.parse('https://i-green-app.onrender.com');

  final FirebaseFirestore _firestore;
  final Uri cloudinarySignerBaseUri;

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
  Future<void> deleteVisit(int id) async {
    final doc = await _visitsRef.where('id', isEqualTo: id).limit(1).get();
    if (doc.docs.isNotEmpty) {
      final data = doc.docs.first.data();
      final photoUrl = data['photo_url'] as String? ?? '';
      final publicId = data['photo_public_id'] as String? ?? '';
      await doc.docs.first.reference.delete();
      await _deleteLocalPhotoIfPresent(photoUrl);
      await _deleteCloudinaryPhotoIfPresent(publicId);
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
      final request = http.MultipartRequest(
        'POST',
        cloudinarySignerBaseUri.resolve('/cloudinary/upload-image'),
      );
      request.fields['folder'] = 'attendance/site_visit';
      request.fields['fileName'] = 'site_visit_${DateTime.now().millisecondsSinceEpoch}.jpg';
      request.fields['mimeType'] = 'image/jpeg';
      request.fields['employeeName'] = employeeName;
      request.fields['siteName'] = siteName;
      request.fields['visitDate'] = visitDate;
      request.fields['visitTime'] = visitTime;
      request.fields['latitude'] = latitude.toStringAsFixed(6);
      request.fields['longitude'] = longitude.toStringAsFixed(6);
      request.files.add(await http.MultipartFile.fromPath('file', localImagePath));

      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Cloudinary upload failed: $body');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final remoteUrl = decoded['secureUrl'] as String? ?? decoded['secure_url'] as String? ?? '';
      final publicId = decoded['publicId'] as String? ?? decoded['public_id'] as String? ?? '';
      if (remoteUrl.isEmpty) {
        throw Exception('Cloudinary upload returned an empty URL.');
      }
      return SiteVisitPhotoAsset(url: remoteUrl, publicId: publicId);
    } on SocketException {
      return SiteVisitPhotoAsset(url: localImagePath, publicId: '');
    } on HttpException {
      return SiteVisitPhotoAsset(url: localImagePath, publicId: '');
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

  Future<void> _deleteCloudinaryPhotoIfPresent(String publicId) async {
    if (publicId.isEmpty) return;
    try {
      final request = http.post(
        cloudinarySignerBaseUri.resolve('/cloudinary/delete-image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'publicId': publicId}),
      );
      await request;
    } catch (_) {
      // Best effort cleanup only.
    }
  }
}
