import 'site_visit_record.dart';
import 'site_visit_photo_asset.dart';

abstract class SiteVisitAttendanceRepository {
  Future<List<SiteVisitRecord>> getVisitsForEmployee({
    required int employeeId,
    required String visitDate,
  });

  Future<List<SiteVisitRecord>> getAllVisits({
    String? visitDate,
  });

  Future<SiteVisitRecord?> getVisitById(int id);

  Future<void> saveVisit(SiteVisitRecord record);

  Future<void> deleteVisit(int id);

  Future<SiteVisitPhotoAsset> createVisitPhotoUrl({
    required String localImagePath,
    required String employeeName,
    required String siteName,
    required String visitDate,
    required String visitTime,
    required double latitude,
    required double longitude,
  });
}
