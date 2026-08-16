import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../organization/presentation/widgets/column_selection_dialog.dart';
import '../domain/registration_link.dart';
import '../domain/employee.dart';
import '../providers/employee_providers.dart';
import 'dialogs/add_employee_link_dialog.dart';
import 'dialogs/registration_links_dialog.dart';
import 'widgets/admin_list_toolbar.dart';

class ResponsesPage extends ConsumerStatefulWidget {
  const ResponsesPage({super.key});

  @override
  ConsumerState<ResponsesPage> createState() => _ResponsesPageState();
}

class _ResponsesPageState extends ConsumerState<ResponsesPage> {
  static const String _tableId = 'employee_responses_table';

  static const List<String> _defaultAllColumns = [
    'Candidate ID',
    'Candidate Name',
    'Email',
    'Phone Number',
    'Status',
  ];

  int _currentPage = 0;
  int _rowsPerPage = 10;
  final Set<int> _selectedIds = {};
  late final TextEditingController _mobileSearchController = TextEditingController();

  @override
  void dispose() {
    _mobileSearchController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return 'C';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final linksAsync = ref.watch(registrationLinksProvider);
    final employeesAsync = ref.watch(allEmployeesProvider);
    final prefAsync = ref.watch(empColumnPreferenceProvider(_tableId));
    final searchQuery = ref.watch(responseSearchQueryProvider);
    final statusFilter = ref.watch(responseStatusFilterProvider);
    final dateRange = ref.watch(responseDateRangeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;

        return ColoredBox(
          color: Colors.white,
          child: linksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Unable to load responses: $err'),
            ),
            data: (links) {
              final employees = employeesAsync.valueOrNull ?? const <Employee>[];

              final statusList = const [
                'All Statuses',
                'Pending',
                'Submitted',
                'Accepted',
                'Rejected',
              ];

              final filtered = links.where((link) {
                final q = searchQuery.toLowerCase().trim();
                final candidateId = _candidateId(link);
                final employee = _employeeForLink(link, employees);
                final matchesSearch = q.isEmpty ||
                    candidateId.toLowerCase().contains(q) ||
                    link.linkId.toLowerCase().contains(q) ||
                    link.employeeName.toLowerCase().contains(q) ||
                    _candidateName(link, employee).toLowerCase().contains(q) ||
                    _emailForLink(link, employee).toLowerCase().contains(q) ||
                    _phoneForLink(link, employee).toLowerCase().contains(q) ||
                    link.linkStatus.toLowerCase().contains(q);

                final status = link.linkStatus.trim().toLowerCase();
                final filter = statusFilter.trim().toLowerCase();

                bool matchesStatus = false;
                if (filter == 'all statuses') {
                  matchesStatus = true;
                } else if (filter == 'submitted') {
                  matchesStatus = status == 'submitted' || status == 'completed';
                } else {
                  matchesStatus = status == filter;
                }

                final matchesDate = _matchesDateRange(link, dateRange);

                return matchesSearch && matchesStatus && matchesDate;
              }).toList();

              if (isMobile) {
                final totalItems = filtered.length;
                final totalPages = (totalItems / _rowsPerPage).ceil();
                final pageIndex = _currentPage.clamp(0, (totalPages - 1).clamp(0, 999));
                final startIndex = pageIndex * _rowsPerPage;
                final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                final pageItems = filtered.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    _buildMobileSearch(context, searchQuery),
                    _buildMobileFilterChips(context, statusList),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No candidate responses found.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          : _buildMobileList(pageItems, employees),
                    ),
                    _buildPaginationBar(
                      totalItems: totalItems,
                      startIndex: startIndex,
                      endIndex: endIndex,
                      currentPage: pageIndex,
                      totalPages: totalPages,
                    ),
                    _buildStickyAddEmployeeButton(context),
                  ],
                );
              }

              // Desktop View Layout
              if (filtered.isEmpty) {
                return Column(
                  children: [
                    _buildToolbar(context, prefAsync),
                    const Divider(height: 1),
                    _buildFiltersRow(statusList),
                    const Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No candidate responses found.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              final pref = prefAsync.valueOrNull;
              final visibleCols = (pref != null && pref.visibleColumns.isNotEmpty)
                  ? pref.visibleColumns
                  : List<String>.from(_defaultAllColumns);

              final totalItems = filtered.length;
              final totalPages = (totalItems / _rowsPerPage).ceil();
              final pageIndex = _currentPage.clamp(0, (totalPages - 1).clamp(0, 999));
              final startIndex = pageIndex * _rowsPerPage;
              final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
              final pageItems = filtered.sublist(startIndex, endIndex);

              return Column(
                children: [
                  _buildToolbar(context, prefAsync),
                  const Divider(height: 1),
                  _buildFiltersRow(statusList),
                  const Divider(height: 1),
                  Expanded(
                    child: _buildDesktopTable(pageItems, visibleCols, constraints.maxWidth, employees),
                  ),
                  _buildPaginationBar(
                    totalItems: totalItems,
                    startIndex: startIndex,
                    endIndex: endIndex,
                    currentPage: pageIndex,
                    totalPages: totalPages,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, AsyncValue<dynamic> prefAsync) {
    final searchQuery = ref.watch(responseSearchQueryProvider);

    return AdminListToolbar(
      title: 'Responses',
      searchHint: 'Search responses...',
      searchQuery: searchQuery,
      onSearchChanged: (val) {
        ref.read(responseSearchQueryProvider.notifier).state = val;
        setState(() => _currentPage = 0);
      },
      onSearchCleared: () {
        ref.read(responseSearchQueryProvider.notifier).state = '';
        setState(() => _currentPage = 0);
      },
      primaryActionLabel: 'Generate Link',
      primaryActionIcon: Icons.link_sharp,
      onPrimaryAction: () => _openAddLinkDialog(context),
      secondaryActions: [
        AdminToolbarAction(
          label: 'Export',
          icon: Icons.file_download_outlined,
          tooltip: 'Export (CSV/PDF)',
          onPressed: _exportData,
        ),
        AdminToolbarAction(
          label: 'Response',
          icon: Icons.rate_review_outlined,
          tooltip: 'Response',
          onPressed: () => _openRegistrationLinksDialog(context),
        ),
        AdminToolbarAction(
          label: 'Columns',
          icon: Icons.view_column_outlined,
          tooltip: 'Columns',
          onPressed: () => _openColumnSelectionDialog(context),
        ),
      ],
    );
  }

  Widget _buildMobileSearch(BuildContext context, String searchQuery) {
    if (_mobileSearchController.text != searchQuery) {
      _mobileSearchController.text = searchQuery;
      _mobileSearchController.selection = TextSelection.fromPosition(
        TextPosition(offset: searchQuery.length),
      );
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        controller: _mobileSearchController,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search responses...',
          hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    ref.read(responseSearchQueryProvider.notifier).state = '';
                    setState(() => _currentPage = 0);
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          filled: true,
          fillColor: Colors.grey.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.active),
          ),
        ),
        onChanged: (val) {
          ref.read(responseSearchQueryProvider.notifier).state = val;
          setState(() => _currentPage = 0);
        },
      ),
    );
  }

  Widget _buildMobileFilterChips(
    BuildContext context,
    List<String> statuses,
  ) {
    final currentStatus = ref.watch(responseStatusFilterProvider);
    final currentDateRange = ref.watch(responseDateRangeProvider);

    int activeCount = 0;
    if (currentStatus != 'All Statuses') activeCount++;
    if (currentDateRange != null) activeCount++;

    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => _openFilterBottomSheet(context, statuses),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: activeCount > 0
                      ? AppColors.active.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: activeCount > 0 ? AppColors.active : AppColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune,
                      size: 16,
                      color: activeCount > 0 ? AppColors.active : AppColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Filters${activeCount > 0 ? " • $activeCount active" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: activeCount > 0 ? AppColors.active : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            if (currentStatus != 'All Statuses')
              _buildActiveChip(
                label: currentStatus,
                onClear: () {
                  ref.read(responseStatusFilterProvider.notifier).state = 'All Statuses';
                  setState(() => _currentPage = 0);
                },
              ),
            if (currentDateRange != null)
              _buildActiveChip(
                label: '${DateFormat('MMM d').format(currentDateRange.start)} - ${DateFormat('MMM d').format(currentDateRange.end)}',
                onClear: () {
                  ref.read(responseDateRangeProvider.notifier).state = null;
                  setState(() => _currentPage = 0);
                },
              ),

            if (activeCount == 0)
              ...statuses.where((s) => s != 'All Statuses').map((status) {
                final isSelected = currentStatus == status;
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      ref.read(responseStatusFilterProvider.notifier).state =
                          isSelected ? 'All Statuses' : status;
                      setState(() => _currentPage = 0);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.active.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.active : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.active : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveChip({
    required String label,
    required VoidCallback onClear,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.active.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.active, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.active,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onClear,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.active,
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterBottomSheet(
    BuildContext context,
    List<String> statuses,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final currentStatus = ref.watch(responseStatusFilterProvider);
            final currentDateRange = ref.watch(responseDateRangeProvider);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Responses',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildBottomSheetDropdown(
                    label: 'Status',
                    value: currentStatus,
                    items: statuses,
                    onChanged: (val) {
                      ref.read(responseStatusFilterProvider.notifier).state = val;
                      setState(() => _currentPage = 0);
                    },
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Submitted Date Range',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          alignment: Alignment.centerLeft,
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDateRange: currentDateRange,
                          );
                          if (picked != null) {
                            ref.read(responseDateRangeProvider.notifier).state = picked;
                            setState(() => _currentPage = 0);
                          }
                        },
                        icon: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                        label: Text(
                          currentDateRange != null
                              ? '${DateFormat('MMM d, yyyy').format(currentDateRange.start)} - ${DateFormat('MMM d, yyyy').format(currentDateRange.end)}'
                              : 'Select Date Range',
                          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(responseStatusFilterProvider.notifier).state = 'All Statuses';
                            ref.read(responseDateRangeProvider.notifier).state = null;
                            setState(() => _currentPage = 0);
                          },
                          child: const Text('Reset All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.active,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomSheetDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  DateTime? _parseDate(String rawDate) {
    if (rawDate.trim().isEmpty) return null;
    try {
      final str = rawDate.trim();
      return DateTime.tryParse(str) ?? DateTime.tryParse(str.replaceAll(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  bool _matchesDateRange(RegistrationLink link, DateTimeRange? range) {
    if (range == null) return true;
    final dateStr = link.submittedDate.isNotEmpty ? link.submittedDate : link.generatedDate;
    final date = _parseDate(dateStr);
    if (date == null) return false;

    final start = DateTime(range.start.year, range.start.month, range.start.day, 0, 0, 0);
    final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);

    return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
           (date.isBefore(end) || date.isAtSameMomentAs(end));
  }

  Widget _buildFiltersRow(List<String> statuses) {
    final currentStatus = ref.watch(responseStatusFilterProvider);
    final currentDateRange = ref.watch(responseDateRangeProvider);
    final selectedStatus = statuses.contains(currentStatus)
        ? currentStatus
        : (statuses.isNotEmpty ? statuses.first : 'All Statuses');

    final String dateButtonText = currentDateRange != null
        ? '${DateFormat('MMM d, yyyy').format(currentDateRange.start)} - ${DateFormat('MMM d, yyyy').format(currentDateRange.end)}'
        : 'Submitted Date';

    final hasActiveFilter = currentStatus != 'All Statuses' || currentDateRange != null;

    return Container(
      width: double.infinity,
      color: Colors.grey.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Filters:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedStatus,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 20),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(responseStatusFilterProvider.notifier).state = val;
                        setState(() => _currentPage = 0);
                      }
                    },
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDateRange: currentDateRange,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: AppColors.active,
                            onPrimary: Colors.white,
                            onSurface: AppColors.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    ref.read(responseDateRangeProvider.notifier).state = picked;
                    setState(() => _currentPage = 0);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: currentDateRange != null ? AppColors.active : AppColors.divider,
                      width: currentDateRange != null ? 1.2 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: currentDateRange != null ? AppColors.active : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateButtonText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: currentDateRange != null ? AppColors.active : AppColors.textPrimary,
                        ),
                      ),
                      if (currentDateRange != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            ref.read(responseDateRangeProvider.notifier).state = null;
                            setState(() => _currentPage = 0);
                          },
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasActiveFilter)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    ref.read(responseStatusFilterProvider.notifier).state = 'All Statuses';
                    ref.read(responseDateRangeProvider.notifier).state = null;
                    setState(() => _currentPage = 0);
                  },
                  child: const Text('Reset Filters', style: TextStyle(fontSize: 13, color: AppColors.active)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    final links = ref.read(registrationLinksProvider).valueOrNull ?? const [];
    final employees = ref.read(allEmployeesProvider).valueOrNull ?? const [];

    if (links.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No candidate responses available to export.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Candidate ID,Candidate Name,Email,Phone Number,Status,Generated Date,Submitted Date');
    for (final link in links) {
      final emp = _employeeForLink(link, employees);
      final cId = _candidateId(link);
      final cName = _candidateName(link, emp);
      final email = _emailForLink(link, emp);
      final phone = _phoneForLink(link, emp);
      final status = link.linkStatus;
      final genDate = link.generatedDate;
      final subDate = link.submittedDate;

      buffer.writeln(
        '"$cId","${cName.replaceAll('"', '""')}","$email","$phone","$status","$genDate","$subDate"',
      );
    }

    final String csvContent = buffer.toString();
    final Uri url = Uri.parse('data:text/csv;charset=utf-8,${Uri.encodeComponent(csvContent)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully exported ${links.length} candidate responses!'),
              backgroundColor: AppColors.active,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openAddLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const AddEmployeeLinkDialog(),
    );
  }

  void _openRegistrationLinksDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const RegistrationLinksDialog(),
    );
  }

  Future<void> _openColumnSelectionDialog(BuildContext context) async {
    final pref = ref.read(empColumnPreferenceProvider(_tableId)).valueOrNull;
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => ColumnSelectionDialog(
        tableId: _tableId,
        allColumns: _defaultAllColumns,
        currentVisibleColumns: pref?.visibleColumns ?? List.from(_defaultAllColumns),
        currentColumnOrder: pref?.columnOrder ?? List.from(_defaultAllColumns),
      ),
    );

    if (updated == true) {
      ref.invalidate(empColumnPreferenceProvider(_tableId));
    }
  }

  Color _getStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'submitted':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'registered':
      case 'converted':
      case 'completed':
      case 'active':
        return Colors.green;
      case 'expired':
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDesktopTable(List<RegistrationLink> links, List<String> visibleColumns, double screenWidth, List<Employee> employees) {
    final minTableWidth = (visibleColumns.length * 140.0 + 220.0).clamp(800.0, 3200.0);
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: screenWidth < minTableWidth ? minTableWidth : screenWidth,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.06)),
                headingRowHeight: 44,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 60,
                horizontalMargin: 16,
                columnSpacing: 18,
                showCheckboxColumn: true,
                onSelectAll: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedIds.addAll(links.map((e) => e.id));
                    } else {
                      _selectedIds.removeAll(links.map((e) => e.id));
                    }
                  });
                },
                headingTextStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                columns: [
                  for (final colName in visibleColumns) DataColumn(label: Text(colName.toUpperCase())),
                  const DataColumn(label: Text('ACTIONS')),
                ],
                rows: links.map((link) {
                  final employee = _employeeForLink(link, employees);
                  final isSelected = _selectedIds.contains(link.id);
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedIds.add(link.id);
                        } else {
                          _selectedIds.remove(link.id);
                        }
                      });
                    },
                    cells: [
                      for (final colName in visibleColumns) DataCell(_buildCellContent(colName, link, employee)),
                      DataCell(_buildRowActions(link)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(String columnName, RegistrationLink link, Employee? employee) {
    String value = '';
    Widget? customWidget;
    TextStyle? style;

    switch (columnName) {
      case 'Candidate ID':
        value = _candidateId(link);
        style = const TextStyle(fontWeight: FontWeight.bold, color: AppColors.active);
        break;
      case 'Candidate Name':
        value = _candidateName(link, employee);
        style = const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary);
        break;
      case 'Email':
        value = _emailForLink(link, employee);
        break;
      case 'Phone Number':
        value = _phoneForLink(link, employee);
        break;
      case 'Status':
        final rawStatus = link.linkStatus.trim();
        final displayStatus = (rawStatus.toLowerCase() == 'completed' || rawStatus.toLowerCase() == 'pending')
            ? 'Submitted'
            : rawStatus;
        final statusColor = _getStatusColor(displayStatus);
        customWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor, width: 0.8),
          ),
          child: Text(
            displayStatus,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        );
        break;
      default:
        value = '-';
    }

    if (customWidget != null) return customWidget;
    return SizedBox(
      width: 130,
      child: Text(
        value.isEmpty ? '-' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style ?? const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildMobileList(List<RegistrationLink> links, List<Employee> employees) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      itemCount: links.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildCompactResponseCard(context, links[index], employees),
    );
  }

  Widget _buildCompactResponseCard(BuildContext context, RegistrationLink link, List<Employee> employees) {
    final employee = _employeeForLink(link, employees);
    final candidateName = _candidateName(link, employee);
    final rawStatus = link.linkStatus.trim();
    final displayStatus = (rawStatus.toLowerCase() == 'completed' || rawStatus.toLowerCase() == 'pending')
        ? 'Submitted'
        : rawStatus;
    final statusColor = _getStatusColor(displayStatus);
    final initials = _getInitials(candidateName);
    final email = _emailForLink(link, employee);
    final phone = _phoneForLink(link, employee);

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Initials Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.active.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.active,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidateName.isEmpty ? 'Candidate' : candidateName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ID: ${_candidateId(link)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.active,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Email: ${email.isEmpty ? '-' : email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Phone: ${phone.isEmpty ? '-' : phone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Status Badge (equal size/height to View Button) + View Button + ⋮ Menu
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => _openViewDialog(context, link),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  itemBuilder: (context) {
                    final status = link.linkStatus.trim().toLowerCase();
                    final isSubmittedOrPending = status == 'submitted' || status == 'pending' || status == 'completed';
                    final isAccepted = status == 'accepted';

                    return [
                      if (isSubmittedOrPending)
                        const PopupMenuItem(
                          value: 'accept',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Accept', style: TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      if (isAccepted)
                        const PopupMenuItem(
                          value: 'register',
                          child: Row(
                            children: [
                              Icon(Icons.person_add_outlined, size: 18, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Register', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      if (isSubmittedOrPending || isAccepted)
                        const PopupMenuItem(
                          value: 'reject',
                          child: Row(
                            children: [
                              Icon(Icons.cancel_outlined, size: 18, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Reject', style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ];
                  },
                  onSelected: (value) {
                    if (value == 'accept') {
                      _setResponseStatus(link, 'Accepted');
                    } else if (value == 'register') {
                      GoRouter.of(context).push('/employee/register/new?acceptedLinkId=${link.linkId}');
                    } else if (value == 'reject') {
                      _setResponseStatus(link, 'Rejected');
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowActions(RegistrationLink link, {bool isMobile = false}) {
    final status = link.linkStatus.trim().toLowerCase();
    final isSubmittedOrPending = status == 'submitted' || status == 'pending' || status == 'completed';
    final isAccepted = status == 'accepted';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => _openViewDialog(context, link),
          icon: Icon(Icons.remove_red_eye_outlined, size: isMobile ? 14 : 16, color: AppColors.textPrimary),
          label: Text('View', style: TextStyle(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        if (isSubmittedOrPending) ...[
          const SizedBox(width: 6),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _setResponseStatus(link, 'Accepted'),
            icon: Icon(Icons.check_circle_outline, size: isMobile ? 14 : 16, color: Colors.blue),
            label: Text('Accept', style: TextStyle(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _setResponseStatus(link, 'Rejected'),
            icon: Icon(Icons.cancel_outlined, size: isMobile ? 14 : 16, color: Colors.redAccent),
            label: Text('Reject', style: TextStyle(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ),
        ],
        if (isAccepted) ...[
          const SizedBox(width: 6),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              GoRouter.of(context).push('/employee/register/new?acceptedLinkId=${link.linkId}');
            },
            icon: Icon(Icons.person_add_outlined, size: isMobile ? 14 : 16, color: Colors.green),
            label: Text('Register', style: TextStyle(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.bold, color: Colors.green)),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _setResponseStatus(link, 'Rejected'),
            icon: Icon(Icons.cancel_outlined, size: isMobile ? 14 : 16, color: Colors.redAccent),
            label: Text('Reject', style: TextStyle(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ),
        ],
      ],
    );
  }

  Widget _buildStickyAddEmployeeButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.active,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => _openAddLinkDialog(context),
          icon: const Icon(Icons.link_sharp, size: 20),
          label: const Text(
            'Generate Link',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar({
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required int currentPage,
    required int totalPages,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;
        final showingText = Text(
          totalItems == 0 ? 'Showing 0 records' : 'Showing ${startIndex + 1} - $endIndex of $totalItems',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        );

        final controlsRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Rows: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            DropdownButton<int>(
              value: _rowsPerPage,
              isDense: true,
              underline: const SizedBox(),
              items: [5, 10, 20, 50]
                  .map((val) => DropdownMenuItem(value: val, child: Text('$val', style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _rowsPerPage = val;
                    _currentPage = 0;
                  });
                }
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: currentPage > 0 ? () => setState(() => _currentPage -= 1) : null,
            ),
            Text('${totalPages == 0 ? 0 : currentPage + 1} / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: currentPage < totalPages - 1 ? () => setState(() => _currentPage += 1) : null,
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: isCompact
              ? Column(mainAxisSize: MainAxisSize.min, children: [showingText, const SizedBox(height: 4), controlsRow])
              : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [showingText, controlsRow]),
        );
      },
    );
  }

  void _openViewDialog(BuildContext context, RegistrationLink link) {
    unawaited(_openViewDialogAsync(context, link));
  }

  Future<void> _openViewDialogAsync(BuildContext context, RegistrationLink link) async {
    final employees = await ref.read(allEmployeesProvider.future);
    final employee = _employeeForLink(link, employees);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_candidateName(link, employee).isEmpty || _candidateName(link, employee) == '-'
            ? 'Candidate Details'
            : _candidateName(link, employee)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewSection('Basic Info', [
                  _buildViewItem('Candidate ID', _candidateId(link)),
                  _buildViewItem('Name', _candidateName(link, employee)),
                  _buildViewItem('Email', _emailForLink(link, employee)),
                  _buildViewItem('Phone', _phoneForLink(link, employee)),
                  _buildViewItem('Gender', employee?.gender ?? ''),
                  _buildViewItem('DOB', employee?.dob ?? ''),
                  _buildViewItem('Status', link.linkStatus),
                ]),
                const SizedBox(height: 16),
                _buildViewSection('Address', [
                  _buildViewItem('Permanent Address', employee?.permanentAddress ?? ''),
                  _buildViewItem('Permanent City', employee?.permanentCity ?? ''),
                  _buildViewItem('Permanent Country', employee?.permanentCountry ?? ''),
                  _buildViewItem('Present Address', employee?.presentAddress ?? ''),
                  _buildViewItem('Present City', employee?.presentCity ?? ''),
                  _buildViewItem('Present Country', employee?.presentCountry ?? ''),
                ]),
                const SizedBox(height: 16),
                _buildViewSection('Education', [
                  _buildViewItem('Education Details', _joinItems(employee?.educationItems.map((e) => '${e.degreeName} | ${e.instituteName} | ${e.result} | ${e.passingYear}') ?? const [])),
                ]),
                const SizedBox(height: 16),
                _buildViewSection('Experience', [
                  _buildViewItem('Experience Details', _joinItems(employee?.experienceItems.map((e) => '${e.companyName} | ${e.position} | ${e.address} | ${e.workingDuration}') ?? const [])),
                ]),
                const SizedBox(height: 16),
                _buildViewSection('History', [
                  _buildViewItem('Original DOB', employee?.originalDob ?? ''),
                  _buildViewItem('Personal Mobile Number', employee?.personalMobile ?? ''),
                  _buildViewItem('PAN Card Number', employee?.panNumber ?? ''),
                  _buildViewItem('Passport Number', employee?.passportNumber ?? ''),
                  _buildViewItem('Driving License Number', employee?.drivingLicenseNumber ?? ''),
                  _buildViewItem('Health Issues', employee?.healthIssues ?? ''),
                  _buildViewItem('Emergency Contact', '${employee?.emergencyName ?? ''} ${employee?.emergencyMobile ?? ''}'.trim()),
                  _buildViewItem('Referred By', '${employee?.referredByName ?? ''} ${employee?.referredByMobile ?? ''}'.trim()),
                  _buildViewItem('Father Name', employee?.fatherName ?? ''),
                  _buildViewItem('Mother Name', employee?.motherName ?? ''),
                  _buildViewItem('Marital Status', employee?.maritalStatus ?? ''),
                  _buildViewItem('Spouse Name', employee?.spouseName ?? ''),
                  _buildViewItem('Kids 1 Name', employee?.kids1Name ?? ''),
                  _buildViewItem('Kids 2 Name', employee?.kids2Name ?? ''),
                  _buildViewItem('Kids 3 Name', employee?.kids3Name ?? ''),
                ]),
                const SizedBox(height: 16),
                _buildViewSection('Bank Account', [
                  _buildViewItem('Account Holder Name', employee?.bankAccountHolder ?? ''),
                  _buildViewItem('Bank Name', employee?.bankName ?? ''),
                  _buildViewItem('Account Number', employee?.bankAccountNumber ?? ''),
                  _buildViewItem('IFSC Code', employee?.bankIfsc ?? ''),
                  _buildViewItem('Branch Name', employee?.bankBranch ?? ''),
                  _buildViewItem('Account Type', employee?.bankAccountType ?? ''),
                ]),
                const SizedBox(height: 16),
                _buildViewSection('Document', [
                  _buildViewItem('Documents', _joinItems(employee?.documentItems.map((e) => '${e.documentType} | ${e.documentNumber} | ${e.fileName} | ${e.uploadedDate}') ?? const [])),
                ]),
                const SizedBox(height: 16),
                _buildViewSection('Social Media', [
                  _buildViewItem('Facebook URL', employee?.facebookUrl ?? ''),
                  _buildViewItem('Twitter URL', employee?.twitterUrl ?? ''),
                  _buildViewItem('LinkedIn URL', employee?.linkedinUrl ?? ''),
                  _buildViewItem('Google URL', employee?.googleUrl ?? ''),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _setResponseStatus(RegistrationLink link, String status) async {
    try {
      await ref.read(employeeRepositoryProvider).updateRegistrationLinkStatus(
            linkId: link.linkId,
            linkStatus: status,
          );
      ref.invalidate(registrationLinksProvider);
      ref.invalidate(employeesProvider);
      ref.invalidate(allEmployeesProvider);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update response status: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _candidateId(RegistrationLink link) => link.employeeId.isNotEmpty ? link.employeeId : link.linkId;

  String _candidateName(RegistrationLink link, Employee? employee) {
    if (employee != null && employee.fullName.isNotEmpty) return employee.fullName;
    return link.employeeName.isNotEmpty ? link.employeeName : '-';
  }

  String _emailForLink(RegistrationLink link, Employee? employee) {
    if (employee != null && employee.emailAddress.isNotEmpty) return employee.emailAddress;
    return '';
  }

  String _phoneForLink(RegistrationLink link, Employee? employee) {
    if (employee != null && employee.phoneNumber.isNotEmpty) return employee.phoneNumber;
    return '';
  }

  Employee? _employeeForLink(RegistrationLink link, List<Employee> employees) {
    for (final employee in employees) {
      if ((link.employeeId.isNotEmpty && (employee.employeeId == link.employeeId || employee.id.toString() == link.employeeId)) ||
          (link.linkId.isNotEmpty && employee.employeeId == link.linkId) ||
          (link.employeeName.isNotEmpty && employee.fullName.trim().toLowerCase() == link.employeeName.trim().toLowerCase())) {
        return employee;
      }
    }
    return null;
  }

  Widget _buildViewSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.active),
        ),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  Widget _buildViewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _joinItems(Iterable<String> items) {
    final cleaned = items.where((e) => e.trim().isNotEmpty).toList();
    return cleaned.isEmpty ? '' : cleaned.join('\n');
  }
}
