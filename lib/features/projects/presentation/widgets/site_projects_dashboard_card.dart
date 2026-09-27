import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/site_project.dart';
import '../../providers/project_providers.dart';
import '../dialogs/project_details_dialog.dart';

class SiteProjectsDashboardCard extends ConsumerStatefulWidget {
  const SiteProjectsDashboardCard({
    super.key,
    this.showTitleHeader = true,
  });

  final bool showTitleHeader;

  @override
  ConsumerState<SiteProjectsDashboardCard> createState() =>
      _SiteProjectsDashboardCardState();
}

class _SiteProjectsDashboardCardState
    extends ConsumerState<SiteProjectsDashboardCard> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  int _rowsPerPage = 5;
  int _currentPage = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim();
      _currentPage = 0;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _currentPage = 0;
    });
  }

  List<SiteProject> _filterProjects(List<SiteProject> projects) {
    if (_searchQuery.isEmpty) return projects;

    final query = _searchQuery.toLowerCase();
    return projects.where((p) {
      return p.projectCode.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsStreamProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showTitleHeader) _buildSectionTabs(context),
            if (widget.showTitleHeader) const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E8E2), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Search Bar ──
                  _buildSearchFilterBar(isMobile),

                  // ── Content Area ──
                  projectsAsync.when(
                    loading: () => _buildLoadingState(),
                    error: (err, stack) => _buildErrorState(err),
                    data: (projects) {
                      final filtered = _filterProjects(projects);

                      if (filtered.isEmpty) {
                        return _buildEmptyState();
                      }

                      final totalItems = filtered.length;
                      final totalPages = (totalItems / _rowsPerPage).ceil();
                      if (_currentPage >= totalPages && totalPages > 0) {
                        _currentPage = totalPages - 1;
                      }

                      final startIndex = _currentPage * _rowsPerPage;
                      final endIndex = (startIndex + _rowsPerPage > totalItems)
                          ? totalItems
                          : startIndex + _rowsPerPage;
                      final pageItems = filtered.sublist(startIndex, endIndex);

                      return Column(
                        children: [
                          if (isMobile)
                            _buildMobileCardList(pageItems)
                          else
                            _buildDesktopTable(pageItems),
                          _buildPaginationBar(
                            totalItems: totalItems,
                            startIndex: startIndex,
                            endIndex: endIndex,
                            totalPages: totalPages,
                            isMobile: isMobile,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Top Section Tab (SITE)
  Widget _buildSectionTabs(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFF9CC70A),
              width: 2.5,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 4, right: 16, bottom: 8),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.domain_rounded,
              size: 18,
              color: Color(0xFF414A51),
            ),
            SizedBox(width: 8),
            Text(
              'SITE',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Color(0xFF414A51),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Search Bar without dropdown
  Widget _buildSearchFilterBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAF8),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E8E2), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSearchInput(isMobile),
          ),
          const SizedBox(width: 12),
          _buildSearchButton(),
        ],
      ),
    );
  }

  Widget _buildSearchInput(bool isMobile) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD2DA)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search Project Code...',
          hintStyle: const TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: _clearSearch,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return ElevatedButton.icon(
      onPressed: () => _onSearchChanged(_searchController.text),
      icon: const Icon(Icons.search_rounded, size: 16),
      label: const Text(
        'SEARCH',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF414A51),
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(100, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Desktop / Tablet Elevated Table View
  Widget _buildDesktopTable(List<SiteProject> projects) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: const Color(0xFF414A51),
          child: const Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'Project Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Tender Amount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Expense Amount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows - Shows only Project Code
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: projects.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            color: Color(0xFFE5E8E2),
          ),
          itemBuilder: (context, index) {
            final project = projects[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openProjectDetails(context, project),
                hoverColor: const Color(0xFFF7F9F5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Project Code Only
                      Expanded(
                        flex: 5,
                        child: Text(
                          project.projectCode.isNotEmpty
                              ? project.projectCode
                              : '—',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF22282D),
                          ),
                        ),
                      ),

                      // Tender Amount
                      Expanded(
                        flex: 2,
                        child: Text(
                          '0',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF22282D),
                          ),
                        ),
                      ),

                      // Expense Amount
                      Expanded(
                        flex: 2,
                        child: Text(
                          '0',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF22282D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Mobile Responsive Card List
  Widget _buildMobileCardList(List<SiteProject> projects) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: projects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final project = projects[index];

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _openProjectDetails(context, project),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE5E8E2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Code & Badge Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.domain_rounded,
                          size: 18,
                          color: Color(0xFF9CC70A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          project.projectCode.isNotEmpty
                              ? project.projectCode
                              : 'Untitled Project',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF414A51),
                            height: 1.3,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE5E8E2)),
                  const SizedBox(height: 12),

                  // Metrics Side-by-Side Badges
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricStatCard(
                          title: 'Tender Amount',
                          value: '₹ 0',
                          color: const Color(0xFF414A51),
                          bgColor: const Color(0xFFF4F6F3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricStatCard(
                          title: 'Expense Amount',
                          value: '₹ 0',
                          color: const Color(0xFF9CC70A),
                          bgColor: const Color(0xFF9CC70A).withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricStatCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Pagination Controls matching screenshot
  Widget _buildPaginationBar({
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required int totalPages,
    required bool isMobile,
  }) {
    final startDisplay = totalItems == 0 ? 0 : startIndex + 1;
    final endDisplay = endIndex;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAF8),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E8E2), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            isMobile ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
        children: [
          // Rows per page dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Rows per page: ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _rowsPerPage,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF414A51),
                  ),
                  items: [5, 10, 25, 50].map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text('$count'),
                    );
                  }).toList(),
                  onChanged: (count) {
                    if (count != null) {
                      setState(() {
                        _rowsPerPage = count;
                        _currentPage = 0;
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Count text
          Text(
            '$startDisplay–$endDisplay of $totalItems',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF414A51),
            ),
          ),

          const SizedBox(width: 12),

          // Navigation buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                color: const Color(0xFF414A51),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                color: const Color(0xFF414A51),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF9CC70A),
            ),
            SizedBox(height: 14),
            Text(
              'Loading site projects...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object err) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 10),
            Text(
              'Failed to load projects: $err',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.redAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF9CC70A).withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 36,
                color: Color(0xFF9CC70A),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No projects matching "$_searchQuery"'
                  : 'No site projects found',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF414A51),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching by a different project code.'
                  : 'Newly created projects will appear here immediately.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear Filter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF414A51),
                  side: const BorderSide(color: Color(0xFFCBD2DA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openProjectDetails(BuildContext context, SiteProject project) {
    showDialog(
      context: context,
      builder: (context) => ProjectDetailsDialog(project: project),
    );
  }
}
