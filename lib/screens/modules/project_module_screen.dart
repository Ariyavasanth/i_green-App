import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/employee/providers/employee_providers.dart';
import '../../widgets/module_card.dart';

class ProjectModuleScreen extends ConsumerWidget {
  const ProjectModuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(currentEmployeeProvider);
    final employeeName = employee?.firstName ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      body: Column(
        children: [
          ModuleScreenHeader(
            title: 'PROJECT MODULE',
            icon: Icons.engineering_outlined,
            color: const Color(0xFF9C27B0),
            onBack: () => context.go('/module-dashboard'),
            employeeName: employeeName,
            onProfile: () => context.go('/my-profile'),
          ),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF9C27B0),
              onRefresh: () async {
                ref.invalidate(currentEmployeeProvider);
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                          ),
                          child: const Icon(
                            Icons.engineering_outlined,
                            size: 48,
                            color: Color(0xFF9C27B0),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Coming Soon',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The Project Module is currently under development.\nStay tuned for exciting project management features!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Preview of planned features
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: const [
                            _PlannedFeatureChip(
                              label: 'Project Planning',
                              icon: Icons.calendar_today_outlined,
                            ),
                            _PlannedFeatureChip(
                              label: 'Resource Allocation',
                              icon: Icons.group_outlined,
                            ),
                            _PlannedFeatureChip(
                              label: 'Milestones',
                              icon: Icons.flag_outlined,
                            ),
                            _PlannedFeatureChip(
                              label: 'Progress Tracking',
                              icon: Icons.trending_up_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedFeatureChip extends StatelessWidget {
  const _PlannedFeatureChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
