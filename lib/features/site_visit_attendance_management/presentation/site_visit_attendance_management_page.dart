import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../site_visit_attendance/domain/site_visit_record.dart';
import '../providers/site_visit_attendance_management_providers.dart';

class SiteVisitAttendanceManagementPage extends ConsumerStatefulWidget {
  const SiteVisitAttendanceManagementPage({super.key});

  @override
  ConsumerState<SiteVisitAttendanceManagementPage> createState() =>
      _SiteVisitAttendanceManagementPageState();
}

class _SiteVisitAttendanceManagementPageState
    extends ConsumerState<SiteVisitAttendanceManagementPage> {
  String? _date;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(
      allSiteVisitsProvider((visitDate: _date, employeeId: null, siteName: _search)),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on_outlined, color: AppColors.active),
                SizedBox(width: 8),
                Text(
                  'Site Visit Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                DropdownButton<String?>(
                  value: _date,
                  hint: const Text('All dates'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All dates')),
                    DropdownMenuItem(
                      value: DateFormat('dd-MM-yyyy').format(DateTime.now()),
                      child: const Text('Today'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _date = v),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Search site name'),
                    onChanged: (v) => setState(() => _search = v.trim()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visitsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading visits: $e'),
                data: _buildList,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<SiteVisitRecord> visits) {
    if (visits.isEmpty) {
      return const Center(child: Text('No site visits found.'));
    }
    return ListView.separated(
      itemCount: visits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final visit = visits[index];
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.photo, color: AppColors.active),
          title: Text('${visit.employeeName} • ${visit.siteName}'),
          subtitle: Text('${visit.visitDate} • ${visit.visitTime}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await ref.read(siteVisitAttendanceManagementRepositoryProvider).deleteSiteVisit(visit.id);
              ref.invalidate(
                allSiteVisitsProvider((visitDate: _date, employeeId: null, siteName: _search)),
              );
            },
          ),
        );
      },
    );
  }
}
