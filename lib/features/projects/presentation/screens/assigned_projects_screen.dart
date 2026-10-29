import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/site_project.dart';
import '../../providers/project_providers.dart';
import '../dialogs/project_details_dialog.dart';

class AssignedProjectsScreen extends ConsumerStatefulWidget {
  const AssignedProjectsScreen({super.key});

  @override
  ConsumerState<AssignedProjectsScreen> createState() =>
      _AssignedProjectsScreenState();
}

class _AssignedProjectsScreenState
    extends ConsumerState<AssignedProjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  int _rowsPerPage = 10;
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

  List<SiteProject> _filterProjects(List<SiteProject> allProjects) {
    if (_searchQuery.isEmpty) return allProjects;

    final query = _searchQuery.toLowerCase();
    return allProjects.where((p) {
      final codeHit = p.projectCode.toLowerCase().contains(query);
      final idHit = p.id.toLowerCase().contains(query);
      final clientHit = p.clientName.toLowerCase().contains(query);
      final teamHit = p.assignedToEmployeeNames.any(
        (name) => name.toLowerCase().contains(query),
      );
      final editorHit =
          (p.updatedByName ?? '').toLowerCase().contains(query);
      return codeHit || idHit || clientHit || teamHit || editorHit;
    }).toList();
  }

  void _openDetails(BuildContext context, SiteProject project) {
    showDialog(
      context: context,
      builder: (_) => ProjectDetailsDialog(project: project),
    );
  }

  Future<void> _openEdit(BuildContext context, SiteProject project) async {
    final result = await context.push<bool>(
      '/projects/edit/${project.id}',
      extra: project,
    );
    if (result == true && mounted) {
      ref.invalidate(projectsStreamProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsStreamProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 1200
        ? 32.0
        : screenWidth > 650
            ? 24.0
            : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF414A51)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/module/project');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF414A51).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.assignment_ind_outlined,
                size: 20,
                color: Color(0xFF414A51),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'ASSIGNED PROJECTS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF414A51),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E8E2), height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 750;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: const Color(0xFFE5E8E2), width: 1),
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
                        // ── Search & Filter Bar ──
                        _buildSearchFilterBar(isMobile),

                        // ── Table Content ──
                        projectsAsync.when(
                          loading: () => _buildLoadingState(),
                          error: (err, stack) => _buildErrorState(err),
                          data: (allProjects) {
                            final filtered = _filterProjects(allProjects);

                            if (filtered.isEmpty) {
                              return _buildEmptyState(
                                hasQuery: _searchQuery.isNotEmpty,
                              );
                            }

                            final totalItems = filtered.length;
                            final totalPages =
                                (totalItems / _rowsPerPage).ceil();
                            if (_currentPage >= totalPages && totalPages > 0) {
                              _currentPage = totalPages - 1;
                            }

                            final startIndex = _currentPage * _rowsPerPage;
                            final endIndex =
                                (startIndex + _rowsPerPage > totalItems)
                                    ? totalItems
                                    : startIndex + _rowsPerPage;
                            final pageItems =
                                filtered.sublist(startIndex, endIndex);

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
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Search Bar ──
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
            child: Container(
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
                  hintText: 'Search Project ID, Team, Editor...',
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
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
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
          ),
        ],
      ),
    );
  }

  // ── Desktop Table View (Exactly 6 Columns) ──
  Widget _buildDesktopTable(List<SiteProject> projects) {
    return Column(
      children: [
        // Table Header: Exactly 6 Columns
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: const Color(0xFF414A51),
          child: const Row(
            children: [
              // 1. Project ID
              Expanded(
                flex: 3,
                child: Text(
                  'Project ID',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // 2. Date
              Expanded(
                flex: 2,
                child: Text(
                  'Date',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // 3. Team
              Expanded(
                flex: 3,
                child: Text(
                  'Team',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // 4. Last Update
              Expanded(
                flex: 3,
                child: Text(
                  'Last Update',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // 5. View
              SizedBox(
                width: 70,
                child: Text(
                  'View',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              // 6. Edit
              SizedBox(
                width: 70,
                child: Text(
                  'Edit',
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

        // Table Rows
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
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              child: Row(
                children: [
                  // 1. Project ID
                  Expanded(
                    flex: 3,
                    child: Text(
                      project.projectCode.isNotEmpty
                          ? project.projectCode
                          : (project.id.isNotEmpty ? project.id : '—'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22282D),
                      ),
                    ),
                  ),

                  // 2. Date (Creation Date formatted as dd-MM-yyyy)
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('dd-MM-yyyy').format(project.createdAt),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF414A51),
                      ),
                    ),
                  ),

                  // 3. Team (Assigned employees)
                  Expanded(
                    flex: 3,
                    child: _buildTeamCell(project.assignedToEmployeeNames),
                  ),

                  // 4. Last Update (Editor name + date/time)
                  Expanded(
                    flex: 3,
                    child: _buildLastUpdateCell(project),
                  ),

                  // 5. View action (Eye icon)
                  SizedBox(
                    width: 70,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 20,
                          color: Color(0xFF414A51),
                        ),
                        tooltip: 'View Project Details',
                        onPressed: () => _openDetails(context, project),
                      ),
                    ),
                  ),

                  // 6. Edit action (Pencil icon)
                  SizedBox(
                    width: 70,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Color(0xFF9CC70A),
                        ),
                        tooltip: 'Edit Project',
                        onPressed: () => _openEdit(context, project),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Team Column Formatter ──
  Widget _buildTeamCell(List<String> names) {
    if (names.isEmpty) {
      return const Text(
        'Unassigned',
        style: TextStyle(
          fontSize: 12.5,
          color: Color(0xFFA0AEC0),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (names.length <= 2) {
      return Text(
        names.join(', '),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF22282D),
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    final visible = names.take(2).join(', ');
    final remaining = names.length - 2;

    return Row(
      children: [
        Flexible(
          child: Text(
            visible,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF22282D),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: names.join('\n'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+$remaining',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF414A51),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Last Update Cell Formatter ──
  Widget _buildLastUpdateCell(SiteProject project) {
    final hasUpdatedBy =
        project.updatedByName != null && project.updatedByName!.trim().isNotEmpty;
    final editorName = hasUpdatedBy
        ? project.updatedByName!.trim()
        : 'Editor unavailable';
    final formattedDateTime =
        DateFormat('dd-MM-yyyy hh:mm a').format(project.updatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          editorName,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: hasUpdatedBy ? FontWeight.w600 : FontWeight.w400,
            color: hasUpdatedBy
                ? const Color(0xFF22282D)
                : const Color(0xFF718096),
            fontStyle: hasUpdatedBy ? FontStyle.normal : FontStyle.italic,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          formattedDateTime,
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF718096),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── Mobile Responsive Card View (Exact 6 Items) ──
  Widget _buildMobileCardList(List<SiteProject> projects) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: projects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final project = projects[index];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E8E2), width: 1),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: 1. Project ID + Actions (5. View, 6. Edit)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF414A51).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assignment_ind_outlined,
                      size: 18,
                      color: Color(0xFF414A51),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      project.projectCode.isNotEmpty
                          ? project.projectCode
                          : (project.id.isNotEmpty ? project.id : '—'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22282D),
                      ),
                    ),
                  ),
                  // 5. View Action
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    color: const Color(0xFF414A51),
                    tooltip: 'View Details',
                    onPressed: () => _openDetails(context, project),
                  ),
                  // 6. Edit Action
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: const Color(0xFF9CC70A),
                    tooltip: 'Edit Project',
                    onPressed: () => _openEdit(context, project),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE5E8E2)),
              const SizedBox(height: 10),

              // 2. Date
              Row(
                children: [
                  const Text(
                    'Date: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    DateFormat('dd-MM-yyyy').format(project.createdAt),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF22282D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 3. Team
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: _buildTeamCell(project.assignedToEmployeeNames),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 4. Last Update
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last Update: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: _buildLastUpdateCell(project),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Pagination Bar ──
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
          Text(
            '$startDisplay - $endDisplay of $totalItems',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            color: _currentPage > 0
                ? const Color(0xFF414A51)
                : const Color(0xFFCBD2DA),
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            color: _currentPage < totalPages - 1
                ? const Color(0xFF414A51)
                : const Color(0xFFCBD2DA),
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
          ),
        ],
      ),
    );
  }

  // ── States: Loading, Error, Empty ──
  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF9CC70A),
            ),
            SizedBox(height: 16),
            Text(
              'Loading assigned projects...',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF718096),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object err) {
    return Padding(
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
              'Failed to load assigned projects: $err',
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

  Widget _buildEmptyState({required bool hasQuery}) {
    return Padding(
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
                Icons.assignment_turned_in_outlined,
                size: 36,
                color: Color(0xFF9CC70A),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery
                  ? 'No projects matching "$_searchQuery"'
                  : 'No assigned projects found',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF414A51),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Try searching with a different keyword.'
                  : 'Newly created site projects will appear here immediately.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (hasQuery) ...[
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
}

