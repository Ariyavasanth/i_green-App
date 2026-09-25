import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/employee/providers/employee_providers.dart';
import '../../widgets/app_background_wrapper.dart';
import '../../widgets/module_card.dart';

/// Data model for a sub-module item.
class _SubModule {
  const _SubModule(this.label, this.icon, this.route, this.color);
  final String label;
  final IconData icon;
  final String route;
  final Color color;
}

class ProjectModuleScreen extends ConsumerStatefulWidget {
  const ProjectModuleScreen({super.key});

  static const _sections = <String, List<_SubModule>>{
    'PROJECT OPERATIONS': [
      _SubModule(
        'NEW PROJECT',
        Icons.add_circle_outline_rounded,
        '/projects/new',
        Color(0xFF9C27B0),
      ),
    ],
  };

  @override
  ConsumerState<ProjectModuleScreen> createState() =>
      _ProjectModuleScreenState();
}

class _ProjectModuleScreenState extends ConsumerState<ProjectModuleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(currentEmployeeProvider);
    final employeeName = employee?.firstName ?? '';

    final query = _searchQuery.trim().toLowerCase();
    final filteredSections = <String, List<_SubModule>>{};

    for (final entry in ProjectModuleScreen._sections.entries) {
      final matches = entry.value.where((m) {
        if (query.isEmpty) return true;
        final cleanLabel = m.label.replaceAll('\n', ' ').toLowerCase();
        final sectionName = entry.key.toLowerCase();
        return cleanLabel.contains(query) || sectionName.contains(query);
      }).toList();

      if (matches.isNotEmpty) {
        filteredSections[entry.key] = matches;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      body: AppBackgroundWrapper(
        child: Column(
          children: [
            ModuleScreenHeader(
              title: 'PROJECT MODULE',
              icon: Icons.rocket_launch_rounded,
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
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Search Bar ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search icons (e.g. New Project...)',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF9C27B0),
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18, color: AppColors.textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFFE5E8E2), width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFFE5E8E2), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFF9C27B0), width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    if (filteredSections.isEmpty && _searchQuery.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 40, horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF9C27B0)
                                      .withValues(alpha: 0.1),
                                ),
                                child: const Icon(
                                  Icons.search_off_rounded,
                                  size: 40,
                                  color: Color(0xFF9C27B0),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No icons found for "$_searchQuery"',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF414A51),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Try searching with a different keyword like "New Project".',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear search'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF9C27B0),
                                  side: const BorderSide(
                                      color: Color(0xFF9C27B0)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Sub-module Sections ──
                    ...filteredSections.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, top: 4),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9C27B0),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = constraints.maxWidth > 800
                                  ? 6
                                  : constraints.maxWidth > 500
                                      ? 4
                                      : 3;
                              final childAspectRatio = constraints.maxWidth > 800
                                  ? 0.95
                                  : constraints.maxWidth > 500
                                      ? 0.82
                                      : 0.72;

                              return GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: childAspectRatio,
                                children: entry.value.map((m) {
                                  return SubModuleCard(
                                    label: m.label,
                                    icon: m.icon,
                                    color: m.color,
                                    onTap: () => context.go(m.route),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
