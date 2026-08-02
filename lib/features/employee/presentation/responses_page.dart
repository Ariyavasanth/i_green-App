import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final linksAsync = ref.watch(registrationLinksProvider);
    final employeesAsync = ref.watch(allEmployeesProvider);
    final prefAsync = ref.watch(empColumnPreferenceProvider(_tableId));
    final searchQuery = ref.watch(responseSearchQueryProvider);
    final statusFilter = ref.watch(responseStatusFilterProvider);

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          _buildToolbar(context, prefAsync),
          const Divider(height: 1),
          Expanded(
            child: linksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Unable to load responses: $err'),
              ),
              data: (links) {
                final employees = employeesAsync.valueOrNull ?? const <Employee>[];

                // Filter out candidates that have already been converted into employees
                final unconvertedLinks = links.where((link) {
                  final status = link.linkStatus.trim().toLowerCase();
                  final isAcceptedOrConverted = status == 'accepted' || status == 'converted';
                  final isEmpId = link.employeeId.trim().toUpperCase().startsWith('EMP-');
                  final employee = _employeeForLink(link, employees);
                  final isConvertedEmp = employee != null && employee.employeeId.trim().toUpperCase().startsWith('EMP-');
                  return !(isAcceptedOrConverted || isEmpId || isConvertedEmp);
                }).toList();

                final statusList = [
                  'All Statuses',
                  ...{for (final link in unconvertedLinks) if (link.linkStatus.isNotEmpty) link.linkStatus},
                ];

                final filtered = unconvertedLinks.where((link) {
                  final q = searchQuery.toLowerCase().trim();
                  final candidateId = _candidateId(link);
                  final employee = _employeeForLink(link, employees);
                  final matchesSearch = q.isEmpty ||
                      candidateId.toLowerCase().contains(q) ||
                      _candidateName(link, employee).toLowerCase().contains(q) ||
                      _emailForLink(link, employee).toLowerCase().contains(q) ||
                      _phoneForLink(link, employee).toLowerCase().contains(q) ||
                      link.linkStatus.toLowerCase().contains(q);

                  final matchesStatus = statusFilter == 'All Statuses' || link.linkStatus == statusFilter;
                  return matchesSearch && matchesStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return Column(
                    children: [
                      _buildFiltersRow([], [], statusList),
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
                    _buildFiltersRow([], [], statusList),
                    const Divider(height: 1),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => constraints.maxWidth < 720
                            ? _buildMobileList(pageItems, employees)
                            : _buildDesktopTable(pageItems, visibleCols, constraints.maxWidth, employees),
                      ),
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
          ),
        ],
      ),
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
      primaryActionLabel: 'Add Employee',
      primaryActionIcon: Icons.add,
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

  Widget _buildFiltersRow(List<String> orgs, List<String> depts, List<String> statuses) {
    final currentStatus = ref.watch(responseStatusFilterProvider);
    final selectedStatus = statuses.contains(currentStatus)
        ? currentStatus
        : (statuses.isNotEmpty ? statuses.first : 'All Statuses');

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
              if (currentStatus != 'All Statuses')
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    ref.read(responseStatusFilterProvider.notifier).state = 'All Statuses';
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

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting Response list to Excel / PDF...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  void _openColumnSelectionDialog(BuildContext context) {
    final pref = ref.read(empColumnPreferenceProvider(_tableId)).valueOrNull;
    showDialog<bool>(
      context: context,
      builder: (context) => ColumnSelectionDialog(
        tableId: _tableId,
        allColumns: _defaultAllColumns,
        currentVisibleColumns: pref?.visibleColumns ?? List.from(_defaultAllColumns),
        currentColumnOrder: pref?.columnOrder ?? List.from(_defaultAllColumns),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'accepted':
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
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _openViewDialog(context, link),
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppColors.textPrimary),
                              label: const Text('View', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _setResponseStatus(link, 'Accepted'),
                              icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                              label: const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _setResponseStatus(link, 'Rejected'),
                              icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                              label: const Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      ),
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
        final statusColor = _getStatusColor(link.linkStatus);
        customWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor, width: 0.8),
          ),
          child: Text(
            link.linkStatus,
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
      padding: const EdgeInsets.all(12),
      itemCount: links.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final link = links[index];
        final statusColor = _getStatusColor(link.linkStatus);
        final employee = _employeeForLink(link, employees);

        return Card(
          elevation: 1.5,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.divider, width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _candidateName(link, employee).isEmpty ? 'Candidate' : _candidateName(link, employee),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.active,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.active.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                            _candidateId(link),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.active,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor, width: 0.8),
                      ),
                      child: Text(
                        link.linkStatus,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Email: ${_emailForLink(link, employee).isEmpty ? '-' : _emailForLink(link, employee)}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                Text('Phone: ${_phoneForLink(link, employee).isEmpty ? '-' : _phoneForLink(link, employee)}', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                if (employee != null) ...[
                  Text('Organization: ${employee.organizationName.isEmpty ? '-' : employee.organizationName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Text('Department: ${employee.department.isEmpty ? '-' : employee.department}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openViewDialog(context, link),
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppColors.active),
                      label: const Text('View', style: TextStyle(fontSize: 12, color: AppColors.active)),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    onPressed: () => _setResponseStatus(link, 'Accepted'),
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                      label: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _setResponseStatus(link, 'Rejected'),
                      icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                      label: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
    await ref.read(employeeRepositoryProvider).updateRegistrationLinkStatus(
          linkId: link.linkId,
          linkStatus: status,
        );
    ref.invalidate(registrationLinksProvider);
    ref.invalidate(employeesProvider);
    ref.invalidate(allEmployeesProvider);
    setState(() {});
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
    if (link.employeeId.isEmpty) return null;
    for (final employee in employees) {
      if (employee.employeeId == link.employeeId || employee.id.toString() == link.employeeId) {
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
