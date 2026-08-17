import 'package:cloud_firestore/cloud_firestore.dart';
import '../../site_visit_attendance/domain/site_visit_record.dart';
import '../domain/site_visit_attendance_management_repository.dart';

class FirebaseSiteVisitAttendanceManagementRepository
    implements SiteVisitAttendanceManagementRepository {
  final FirebaseFirestore? _customFirestore;

  FirebaseSiteVisitAttendanceManagementRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _visitsRef =>
      _firestore.collection('site_visit_records');

  @override
  Future<void> deleteSiteVisit(int id) async {
    try {
      final snap = await _visitsRef.where('id', isEqualTo: id).limit(1).get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.delete();
        return;
      }
      await _visitsRef.doc(id.toString()).delete();
    } catch (_) {}
  }

  @override
  Future<List<SiteVisitRecord>> getAllSiteVisits({
    String? visitDate,
    int? employeeId,
    String? siteName,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snap = await _visitsRef.get();
      var visits = snap.docs
          .map((doc) => SiteVisitRecord.fromMap({
                ...doc.data(),
                'id': int.tryParse(doc.id.replaceAll(RegExp(r'\D'), '')) ??
                    (doc.id.hashCode & 0x7fffffff),
              }))
          .toList();
      if (visitDate != null && visitDate.isNotEmpty) {
        visits = visits.where((v) => v.visitDate == visitDate).toList();
      }
      if (employeeId != null) {
        visits = visits.where((v) => v.employeeId == employeeId).toList();
      }
      if (siteName != null && siteName.trim().isNotEmpty) {
        final q = siteName.trim().toLowerCase();
        visits = visits.where((v) => v.siteName.toLowerCase().contains(q)).toList();
      }
      visits.sort((a, b) {
        final byDate = b.visitDate.compareTo(a.visitDate);
        if (byDate != 0) return byDate;
        return b.visitTime.compareTo(a.visitTime);
      });
      return visits;
    } catch (_) {
      return [];
    }
  }
}
