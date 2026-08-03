import '../../site_visit_attendance/domain/site_visit_record.dart';

abstract class SiteVisitAttendanceManagementRepository {
  Future<List<SiteVisitRecord>> getAllSiteVisits({
    String? visitDate,
    int? employeeId,
    String? siteName,
  });

  Future<void> deleteSiteVisit(int id);
}
