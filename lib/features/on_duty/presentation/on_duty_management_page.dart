import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../site_visit_attendance_management/presentation/widgets/on_duty_management_view.dart';
import 'assign_on_duty_dialog.dart';

class OnDutyManagementPage extends ConsumerWidget {
  const OnDutyManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: const SafeArea(
        child: OnDutyManagementView(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (ctx) => const AssignOnDutyDialog(),
          );
        },
        backgroundColor: const Color(0xFF9CC70A),
        foregroundColor: const Color(0xFF414A51),
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
