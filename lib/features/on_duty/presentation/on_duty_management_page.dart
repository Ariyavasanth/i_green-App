import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../site_visit_attendance_management/presentation/widgets/on_duty_management_view.dart';

class OnDutyManagementPage extends ConsumerWidget {
  const OnDutyManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: OnDutyManagementView(),
      ),
    );
  }
}
