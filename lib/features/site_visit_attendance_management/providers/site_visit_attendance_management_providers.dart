import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_site_visit_attendance_management_repository.dart';
import '../domain/site_visit_attendance_management_repository.dart';
import '../../site_visit_attendance/domain/site_visit_record.dart';

final siteVisitAttendanceManagementRepositoryProvider = Provider<SiteVisitAttendanceManagementRepository>(
  (ref) => FirebaseSiteVisitAttendanceManagementRepository(),
);

final allSiteVisitsProvider = FutureProvider.family<List<SiteVisitRecord>, ({String? visitDate, int? employeeId, String? siteName})>(
  (ref, args) => ref.watch(siteVisitAttendanceManagementRepositoryProvider).getAllSiteVisits(
        visitDate: args.visitDate,
        employeeId: args.employeeId,
        siteName: args.siteName,
      ),
);
