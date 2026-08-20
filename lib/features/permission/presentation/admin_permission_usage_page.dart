import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/permission_balance.dart';
import '../providers/permission_providers.dart';

class AdminPermissionUsagePage extends ConsumerStatefulWidget {
  const AdminPermissionUsagePage({super.key});

  static const Color primaryGreen = Color(0xFF9CC70A);
  static const Color darkNeutral = Color(0xFF414A51);

  @override
  ConsumerState<AdminPermissionUsagePage> createState() => _AdminPermissionUsagePageState();
}

class _AdminPermissionUsagePageState extends ConsumerState<AdminPermissionUsagePage> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final repo = ref.watch(permissionRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permission Usage Tracker',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AdminPermissionUsagePage.darkNeutral,
                      ),
                    ),
                    Text(
                      'Monitor monthly employee permission consumption and remaining balances.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                  label: const Text('Refresh', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminPermissionUsagePage.darkNeutral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Employee Usage List
            Expanded(
              child: employeesAsync.when(
                data: (employees) {
                  if (employees.isEmpty) {
                    return const Center(child: Text('No employees found'));
                  }

                  return ListView.separated(
                    itemCount: employees.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final emp = employees[index];
                      return FutureBuilder<PermissionBalance>(
                        future: repo.getPermissionBalance(emp.id, _selectedMonth),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }

                          final bal = snapshot.data!;
                          final percent = bal.monthlyLimitMinutes > 0
                              ? (bal.monthlyUsedMinutes / bal.monthlyLimitMinutes).clamp(0.0, 1.0)
                              : 0.0;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AdminPermissionUsagePage.primaryGreen.withOpacity(0.2),
                                  child: Text(
                                    emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
                                    style: const TextStyle(color: AdminPermissionUsagePage.darkNeutral, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${emp.firstName} ${emp.lastName}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        '${emp.employeeId} • ${emp.department}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Used: ${bal.monthlyUsedHours.toStringAsFixed(1)}h / ${bal.monthlyLimitHours.toStringAsFixed(1)}h',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: percent,
                                          minHeight: 6,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            percent >= 1.0
                                                ? Colors.red
                                                : (percent > 0.7 ? Colors.orange : AdminPermissionUsagePage.primaryGreen),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('Rem.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      Text(
                                        '${bal.monthlyRemainingHours.toStringAsFixed(1)}h',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AdminPermissionUsagePage.darkNeutral,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error loading employees: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
