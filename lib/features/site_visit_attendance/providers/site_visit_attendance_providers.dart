import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_site_visit_attendance_repository.dart';
import '../domain/site_visit_attendance_repository.dart';
import '../domain/site_visit_record.dart';

final siteVisitAttendanceRepositoryProvider = Provider<SiteVisitAttendanceRepository>(
  (ref) => FirebaseSiteVisitAttendanceRepository(),
);

final siteVisitRecordsProvider = FutureProvider.family<List<SiteVisitRecord>, ({int employeeId, String visitDate})>(
  (ref, args) => ref
      .watch(siteVisitAttendanceRepositoryProvider)
      .getVisitsForEmployee(employeeId: args.employeeId, visitDate: args.visitDate),
);

final allSiteVisitRecordsProvider = FutureProvider.family<List<SiteVisitRecord>, String?>(
  (ref, visitDate) => ref.watch(siteVisitAttendanceRepositoryProvider).getAllVisits(visitDate: visitDate),
);
