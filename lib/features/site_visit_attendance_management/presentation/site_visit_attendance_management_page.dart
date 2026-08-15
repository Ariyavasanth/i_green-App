import 'package:flutter/material.dart';
import '../../attendance_management/presentation/attendance_management_page.dart';

class SiteVisitAttendanceManagementPage extends StatelessWidget {
  const SiteVisitAttendanceManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AttendanceManagementPage(
      initialTab: AttendanceCategoryTab.siteVisitAttendance,
    );
  }
}
