import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../employee/providers/employee_providers.dart';
import 'employee_clocking_widget.dart';

class TimeClockingPage extends ConsumerWidget {
  const TimeClockingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    final isMobile = MediaQuery.of(context).size.width < 750;

    if (currentEmp == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF9CC70A),
          ),
        ),
      );
    }

    final empId = currentEmp.employeeId.isNotEmpty
        ? currentEmp.employeeId
        : currentEmp.id.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 24,
            isMobile ? 12 : 20,
            isMobile ? 12 : 24,
            60,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployeeClockingWidget(employeeId: empId),
            ],
          ),
        ),
      ),
    );
  }
}
