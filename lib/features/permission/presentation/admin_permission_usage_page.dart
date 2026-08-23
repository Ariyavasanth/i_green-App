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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Usage Tracker',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AdminPermissionUsagePage.darkNeutral,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Monitor monthly employee permission consumption and remaining balances.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(employeesProvider);
                      setState(() {});
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: employees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                      final emp = employees[index];
                      final initials = emp.firstName.isNotEmpty
                          ? '${emp.firstName[0]}${emp.lastName.isNotEmpty ? emp.lastName[0] : ''}'.toUpperCase()
                          : 'E';

                      return FutureBuilder<PermissionBalance>(
                        future: repo.getPermissionBalance(emp.id, _selectedMonth),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          }

                          final bal = snapshot.data!;
                          final percent = bal.monthlyLimitMinutes > 0
                              ? (bal.monthlyUsedMinutes / bal.monthlyLimitMinutes).clamp(0.0, 1.0)
                              : 0.0;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFFE8F5E9),
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${emp.firstName} ${emp.lastName}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AdminPermissionUsagePage.darkNeutral,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ID: ${emp.employeeId} • ${emp.department}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: bal.monthlyRemainingMinutes <= 0
                                            ? Colors.red.shade50
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: bal.monthlyRemainingMinutes <= 0
                                              ? Colors.red.shade200
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        'Rem. ${bal.monthlyRemainingFormatted}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: bal.monthlyRemainingMinutes <= 0
                                              ? Colors.red.shade700
                                              : AdminPermissionUsagePage.darkNeutral,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Used: ${bal.monthlyUsedFormatted} / ${bal.monthlyLimitFormatted}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    Text(
                                      '${(percent * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: percent >= 1.0 ? Colors.red : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
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
                          );
                        },
                      );
                    },
                  ),
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
