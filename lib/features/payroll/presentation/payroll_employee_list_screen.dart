import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../incentive/domain/incentive_payout_ledger.dart';
import '../../incentive/domain/incentive_settings.dart';
import '../../incentive/providers/incentive_providers.dart';
import '../../leave/providers/leave_providers.dart';
import '../../loan/providers/loan_providers.dart';
import '../../on_duty/providers/on_duty_providers.dart';
import '../../organization/domain/department.dart';
import '../../organization/domain/organization.dart';

import '../../organization/providers/organization_providers.dart';
import '../../permission/domain/permission_enums.dart';
import '../../permission/domain/permission_request.dart';
import '../../permission/providers/permission_providers.dart';
import '../domain/payroll.dart';
import '../domain/payroll_input_override.dart';
import '../domain/payroll_report_dataset.dart';
import '../providers/payroll_providers.dart';
import '../services/payroll_calculation_service.dart';
import '../services/payroll_export_service.dart';
import '../services/payroll_upload_parser.dart';

class PayrollEmployeeListScreen extends ConsumerStatefulWidget {
  const PayrollEmployeeListScreen({super.key});

  @override
  ConsumerState<PayrollEmployeeListScreen> createState() => _PayrollEmployeeListScreenState();
}

class _PayrollEmployeeListScreenState extends ConsumerState<PayrollEmployeeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filter Selection State
  Organization? _selectedOrganization;
  String? _selectedDepartment;
  String? _selectedMonth;

  // Submitted Filter State (used to display results)
  bool _hasSubmitted = false;
  Organization? _submittedOrganization;
  String? _submittedDepartment;
  String? _submittedMonth;

  // Batch Generation State
  bool _isGeneratingAll = false;
  bool _isMarkingAllPaid = false;

  // In-memory Upload Overrides (scoped to currently submitted filter)
  final Map<String, PayrollInputOverride> _appliedOverrides = {};
  String? _uploadedFileName;

  @override
  void initState() {
    super.initState();
    _selectedMonth = ref.read(selectedPayrollMonthProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getAvailableMonths() {
    final now = DateTime.now();
    final formatter = DateFormat('MMMM yyyy');
    final months = <String>[];
    for (int i = -12; i <= 3; i++) {
      final date = DateTime(now.year, now.month + i);
      months.add(formatter.format(date));
    }
    final currentSelected = ref.read(selectedPayrollMonthProvider);
    if (!months.contains(currentSelected)) {
      months.add(currentSelected);
    }
    return months;
  }

  void _handleSubmit() {
    if (_selectedOrganization == null ||
        _selectedDepartment == null ||
        _selectedDepartment!.trim().isEmpty ||
        _selectedMonth == null ||
        _selectedMonth!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select organisation, department, and month first.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Sync global selected month provider
    ref.read(selectedPayrollMonthProvider.notifier).state = _selectedMonth!;

    setState(() {
      _hasSubmitted = true;
      _submittedOrganization = _selectedOrganization;
      _submittedDepartment = _selectedDepartment;
      _submittedMonth = _selectedMonth;
      // Clear previous upload overrides on fresh filter submission
      _appliedOverrides.clear();
      _uploadedFileName = null;
      ref.read(payrollInputOverridesProvider.notifier).state = {};
    });
  }

  Future<void> _handlePickAndValidateUpload(
    BuildContext context,
    List<Employee> matchingEmployees,
  ) async {
    if (matchingEmployees.isEmpty) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'tsv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      if (bytes == null && file.path != null) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          bytes = await ioFile.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read file data. Please select a valid file.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Parse and validate against currently filtered employees
      final report = await PayrollUploadParser.parseAndValidate(
        bytes: bytes,
        fileName: file.name,
        allowedEmployees: matchingEmployees,
      );

      if (!mounted) return;

      // Show Preview & Validation Dialog
      _showUploadPreviewDialog(
        context: context,
        report: report,
        onApply: (validOverrides) {
          setState(() {
            _appliedOverrides.clear();
            for (final row in validOverrides) {
              if (row.overrideData != null) {
                _appliedOverrides[row.overrideData!.employeeId] = row.overrideData!;
              }
            }
            _uploadedFileName = file.name;
            ref.read(payrollInputOverridesProvider.notifier).state = Map.from(_appliedOverrides);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payroll input uploaded successfully for ${validOverrides.length} employees.',
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showExcelInstructionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Color(0xFF414A51), size: 24),
            SizedBox(width: 8),
            Text(
              'Excel Instructions & Field Guide',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How the Excel Edit Workflow Works:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '1. Export the payroll Excel file using the Export menu.\n'
                        '2. Edit allowed payroll inputs for any employee in the file.\n'
                        '3. Save and upload the same file using "Upload Excel/CSV".\n'
                        '4. Click "Generate All" to recalculate and save updated payroll records.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'EDITABLE PAYROLL INPUTS (16)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• Basic\n'
                        '• HRA\n'
                        '• Education Allowance\n'
                        '• Special Allowance\n'
                        '• Travel Allowance\n'
                        '• Other Allowance\n'
                        '• Incentive\n'
                        '• Others Earning\n'
                        '• Bonus\n'
                        '• OT\n'
                        '• PF\n'
                        '• TDS / Tax\n'
                        '• ESI\n'
                        '• Salary Advance\n'
                        '• Others Deduction\n'
                        '• Staff Welfare',
                        style: TextStyle(fontSize: 12, color: Color(0xFF14532D), height: 1.4),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Note: Only editable payroll input fields are used as Excel overrides.',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.lock_outline, color: Color(0xFF414A51), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'SYSTEM CONTROLLED / NOT EDITABLE (18)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF414A51)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• Employee ID\n'
                        '• Employee Name\n'
                        '• Organisation\n'
                        '• Department\n'
                        '• Payroll Month\n'
                        '• Present Days\n'
                        '• Late Days\n'
                        '• LOP Hours\n'
                        '• Leave Days\n'
                        '• Absent Days\n'
                        '• Weekly Off\n'
                        '• Working Days\n'
                        '• LOP Deduction\n'
                        '• Company Loan\n'
                        '• Gross Salary\n'
                        '• Total Deductions\n'
                        '• Net Salary\n'
                        '• Status',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Employee ID is used to identify the employee and must not be changed.\n'
                        '• Attendance and calculated payroll fields are calculated by the system.',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9CC70A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUploadPreviewDialog({
    required BuildContext context,
    required PayrollUploadValidationReport report,
    required void Function(List<UploadRowValidation> validRows) onApply,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.file_present_rounded, color: Color(0xFF414A51), size: 24),
            SizedBox(width: 8),
            Text(
              'Upload Validation Preview',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File: ${report.fileName}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatChip('Total Rows', report.totalRows.toString(), Colors.blueGrey[800]!, const Color(0xFFF1F5F9)),
                    const SizedBox(width: 8),
                    _buildStatChip('Valid', report.validRows.length.toString(), Colors.green[700]!, const Color(0xFFE8F5E9)),
                    const SizedBox(width: 8),
                    _buildStatChip('Invalid', report.invalidRows.length.toString(), Colors.red[700]!, const Color(0xFFFFEBEE)),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Detected Editable Columns
                if (report.detectedEditableColumns.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(
                        'Editable fields detected (${report.detectedEditableColumns.length}):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: report.detectedEditableColumns
                          .map((col) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Text(
                                  col,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 2. Detected System-Controlled Columns
                if (report.detectedSystemColumns.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF414A51)),
                      const SizedBox(width: 6),
                      Text(
                        'System-controlled fields are ignored (${report.detectedSystemColumns.length}):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF414A51)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: report.detectedSystemColumns
                              .map((col) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.divider),
                                    ),
                                    child: Text(
                                      col,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Attendance and calculated totals will be dynamically calculated by the system during generation.',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. Validation Issues
                if (report.hasErrors) ...[
                  Text(
                    'Validation Issues (${report.invalidRows.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: report.invalidRows
                          .map((row) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Text(
                                  '• ${row.errorMessage ?? "Invalid row data"}',
                                  style: TextStyle(fontSize: 12, color: Colors.red[900]),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 4. Valid Rows
                if (report.hasValidRows) ...[
                  Text(
                    'Valid Rows Ready to Apply (${report.validRows.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: report.validRows
                          .take(10)
                          .map((row) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '✓ ${row.employeeNameRaw} (${row.employeeIdRaw})',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ))
                          .toList()
                        ..addAll(
                          report.validRows.length > 10
                              ? [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '... and ${report.validRows.length - 10} more employees',
                                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                                    ),
                                  )
                                ]
                              : [],
                        ),
                    ),
                  ),
                ],
                if (!report.hasValidRows) ...[
                  const Text(
                    'No valid rows could be parsed. Please correct the errors in the file and try again.',
                    style: TextStyle(fontSize: 13, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.divider),
            ),
            child: const Text('Cancel'),
          ),
          if (report.hasValidRows)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onApply(report.validRows);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: Colors.white,
              ),
              child: Text(
                report.hasErrors
                    ? 'Apply Valid Rows (${report.validRows.length})'
                    : 'Apply Overrides (${report.validRows.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }


  Future<void> _handleGenerateAll({
    required BuildContext context,
    required List<Employee> matchingEmployees,
    required List<PayrollRecord> records,
    required String month,
    required PayrollSettings settings,
  }) async {
    if (_isGeneratingAll || matchingEmployees.isEmpty) return;

    // 1. Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.flash_on_rounded, color: Color(0xFF9CC70A), size: 24),
            SizedBox(width: 8),
            Text(
              'Confirm Generate All',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate payroll for all ${matchingEmployees.length} employees in the selected organisation and department?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organisation: ${_submittedOrganization?.name ?? "-"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Department: ${_submittedDepartment ?? "-"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Month: $month',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (_appliedOverrides.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Upload Overrides: Applied for ${_appliedOverrides.length} employees',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: Any employee whose payroll is already marked as Paid or Processed will be safely skipped.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.divider),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9CC70A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isGeneratingAll = true;
    });

    int currentCompleted = 0;
    final int totalCount = matchingEmployees.length;
    int successCount = 0;
    final List<String> skippedList = [];
    final List<String> failedList = [];

    final progressNotifier = ValueNotifier<({int completed, String employeeName})>(
      (completed: 0, employeeName: ''),
    );

    // Show persistent progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: ValueListenableBuilder<({int completed, String employeeName})>(
          valueListenable: progressNotifier,
          builder: (dialogCtx, progressData, _) {
            final int currentCompletedCount = progressData.completed;
            final double progressValue = totalCount > 0 ? (currentCompletedCount / totalCount) : 0.0;
            final String currentEmployeeName = progressData.employeeName;

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF9CC70A)),
                      ),
                      SizedBox(width: 14),
                      Text(
                        'Generating payroll...',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9CC70A)),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$currentCompletedCount / $totalCount employees completed',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${(progressValue * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9CC70A)),
                      ),
                    ],
                  ),
                  if (currentEmployeeName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Processing: $currentEmployeeName',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );

    try {
      // Pre-fetch shared resources
      final holidays = await ref.read(leaveRepositoryProvider).getHolidays();
      final permissions = await ref.read(permissionRepositoryProvider).getAllRequests();
      final incentives = await ref.read(incentiveRepositoryProvider).getAllRequests();
      final incentiveSettings = await ref.read(incentiveRepositoryProvider).getIncentiveSettings();
      final allLedgers = await ref.read(incentiveRepositoryProvider).getAllPayoutLedgers();
      final payrollRepo = ref.read(payrollRepositoryProvider);
      final loanRepo = ref.read(loanRepositoryProvider);
      final attendanceRepo = ref.read(attendanceRepositoryProvider);
      final leaveRepo = ref.read(leaveRepositoryProvider);
      final onDutyRepo = ref.read(onDutyRepositoryProvider);

      for (final emp in matchingEmployees) {
        final empDisplayName = '${emp.firstName} ${emp.lastName} (EMP${emp.id})';
        progressNotifier.value = (completed: currentCompleted, employeeName: empDisplayName);

        // Check if existing record is protected (PAID or PROCESSED)
        final existingRecord = records.where((r) => r.employeeId == emp.id && r.id != 0).firstOrNull;
        if (existingRecord != null) {
          final statusUpper = existingRecord.status.trim().toUpperCase();
          if (statusUpper == 'PAID' || statusUpper == 'PROCESSED') {
            skippedList.add('$empDisplayName — Status is already ${existingRecord.status}');
            currentCompleted++;
            progressNotifier.value = (completed: currentCompleted, employeeName: '');
            continue;
          }
        }

        try {
          // 1. Fetch individual dependencies
          final empAttendance = await attendanceRepo.getAttendanceRecords(emp.id);
          final empLeaves = await leaveRepo.getLeaveRequests(emp.id);
          final empOnDuty = await onDutyRepo.getAssignmentsForEmployee(employeeId: emp.id, date: null);
          final activeLoan = await loanRepo.getActiveLoanForEmployee(emp.id, month);

          // 2. Lookup upload input override if available
          final override = _appliedOverrides[emp.id.toString()] ??
              _appliedOverrides[emp.employeeId.trim().toLowerCase()];

          // 3. Compute full calculation via single source of truth service
          final calculatedRecord = PayrollCalculationService.calculatePayrollRecord(
            employee: emp,
            month: month,
            settings: settings,
            attendanceRecords: empAttendance,
            leaves: empLeaves,
            onDutyAssignments: empOnDuty,
            holidays: holidays,
            permissions: permissions,
            incentives: incentives,
            incentiveSettings: incentiveSettings,
            ledgers: allLedgers,
            activeLoan: activeLoan,
            overrideInput: override,
            status: 'Processed',
          );

          // 4. Save via repository
          await payrollRepo.savePayrollRecord(calculatedRecord);

          // 5. Update 3-Table Incentive Ledger
          final parsed = PayrollCalculationService.parseMonthYear(month);
          final period = settings.getPayrollPeriod(parsed.year, parsed.monthNum);
          final incentiveMetrics = PayrollCalculationService.calculateIncentives(
            employee: emp,
            requests: incentives,
            period: period,
            cycleMonth: month,
            incentiveSettings: incentiveSettings,
            ledgers: allLedgers,
          );

          if (incentiveMetrics.totalEarnedIncentive > 0) {
            await ref.read(incentiveRepositoryProvider).savePayoutLedger(
              IncentivePayoutLedger(
                id: 'ledger_${emp.id}_${month.replaceAll(' ', '_')}',
                employeeId: emp.id,
                employeeName: emp.fullName,
                earnedCycle: month,
                totalEarnedAmount: incentiveMetrics.totalEarnedIncentive,
                immediateAmount: incentiveMetrics.immediateIncentive,
                deferredAmount: incentiveMetrics.currentDeferredIncentive,
                status: 'Pending',
                createdAt: DateTime.now().toIso8601String(),
              ),
            );
          }

          if (incentiveMetrics.eligibleLedgersToRelease.isNotEmpty) {
            final pendingIds = incentiveMetrics.eligibleLedgersToRelease
                .where((l) => l.isPending)
                .map((l) => l.id)
                .toList();
            if (pendingIds.isNotEmpty) {
              await ref.read(incentiveRepositoryProvider).markPayoutLedgersReleased(
                ledgerIds: pendingIds,
                releaseCycle: month,
                releasedAt: DateTime.now(),
              );
            }
          }

          successCount++;
        } catch (e) {
          failedList.add('$empDisplayName: $e');
        }

        currentCompleted++;
        progressNotifier.value = (completed: currentCompleted, employeeName: '');
      }

    } catch (globalErr) {
      debugPrint('Error during batch payroll generation: $globalErr');
    } finally {
      // Close progress dialog
      if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      progressNotifier.dispose();

      // Refresh payroll providers to update table statuses
      ref.read(selectedPayrollMonthProvider.notifier).state = month;
      ref.invalidate(payrollRecordsForMonthProvider);
      ref.invalidate(allPayrollRecordsProvider);

      if (mounted) {
        setState(() {
          _isGeneratingAll = false;
        });

        // 5. Show Summary Dialog
        _showSummaryDialog(
          context: context,
          successCount: successCount,
          skippedList: skippedList,
          failedList: failedList,
          totalProcessed: totalCount,
          title: 'Payroll Generation Summary',
        );
      }
    }
  }

  Future<void> _handleMarkAllAsPaid({
    required BuildContext context,
    required List<Employee> matchingEmployees,
    required List<PayrollRecord> records,
    required String month,
  }) async {
    if (_isMarkingAllPaid || _isGeneratingAll || matchingEmployees.isEmpty) return;

    final matchingEmployeeIds = matchingEmployees.map((e) => e.id).toSet();
    final eligibleRecords = records.where((r) =>
      matchingEmployeeIds.contains(r.employeeId) &&
      r.status.trim().toLowerCase() == 'processed'
    ).toList();

    if (eligibleRecords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No processed payroll records available to mark as paid.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final empMap = {for (final e in matchingEmployees) e.id: e};

    // 1. Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.payment_rounded, color: Color(0xFF414A51), size: 24),
            SizedBox(width: 8),
            Text(
              'Confirm Mark All as Paid',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will mark ${eligibleRecords.length} processed payroll records as Paid. Paid payroll cannot be edited afterward.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organisation: ${_submittedOrganization?.name ?? "-"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Department: ${_submittedDepartment ?? "-"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Month: $month',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Eligible Records: ${eligibleRecords.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.divider),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF414A51),
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark as Paid', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isMarkingAllPaid = true;
    });

    int currentCompleted = 0;
    final int totalCount = eligibleRecords.length;
    int successCount = 0;
    final List<String> failedList = [];

    final progressNotifier = ValueNotifier<({int completed, String employeeName})>(
      (completed: 0, employeeName: ''),
    );

    // Show persistent progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: ValueListenableBuilder<({int completed, String employeeName})>(
          valueListenable: progressNotifier,
          builder: (dialogCtx, progressData, _) {
            final int currentCompletedCount = progressData.completed;
            final double progressValue = totalCount > 0 ? (currentCompletedCount / totalCount) : 0.0;
            final String currentEmployeeName = progressData.employeeName;

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF414A51)),
                      ),
                      SizedBox(width: 14),
                      Text(
                        'Marking payroll as paid...',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF414A51)),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$currentCompletedCount / $totalCount records completed',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${(progressValue * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                      ),
                    ],
                  ),
                  if (currentEmployeeName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Processing: $currentEmployeeName',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );

    final paymentDateFormatted = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final payrollRepo = ref.read(payrollRepositoryProvider);

    try {
      for (final rec in eligibleRecords) {
        final emp = empMap[rec.employeeId];
        final empDisplayName = emp != null ? '${emp.firstName} ${emp.lastName} (EMP${emp.id})' : 'EMP #${rec.employeeId}';

        progressNotifier.value = (completed: currentCompleted, employeeName: empDisplayName);

        try {
          final updated = rec.copyWith(
            status: 'Paid',
            paymentDate: paymentDateFormatted,
          );
          await payrollRepo.savePayrollRecord(updated);
          successCount++;
        } catch (e) {
          failedList.add('$empDisplayName: $e');
        }

        currentCompleted++;
        progressNotifier.value = (completed: currentCompleted, employeeName: '');
      }
    } catch (globalErr) {
      debugPrint('Error during batch mark as paid: $globalErr');
    } finally {
      // Close progress dialog
      if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      progressNotifier.dispose();

      // Refresh payroll providers to update table statuses
      ref.read(selectedPayrollMonthProvider.notifier).state = month;
      ref.invalidate(payrollRecordsForMonthProvider);
      ref.invalidate(allPayrollRecordsProvider);

      if (mounted) {
        setState(() {
          _isMarkingAllPaid = false;
        });

        if (failedList.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount payroll records marked as Paid.'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          _showSummaryDialog(
            context: context,
            successCount: successCount,
            skippedList: [],
            failedList: failedList,
            totalProcessed: totalCount,
            title: 'Mark as Paid Summary',
          );
        }
      }
    }
  }

  void _showSummaryDialog({
    required BuildContext context,
    required int successCount,
    required List<String> skippedList,
    required List<String> failedList,
    required int totalProcessed,
    String title = 'Payroll Generation Summary',
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              failedList.isEmpty ? Icons.check_circle_outline : Icons.info_outline,
              color: failedList.isEmpty ? const Color(0xFF9CC70A) : Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatChip('Success', successCount.toString(), Colors.green[700]!, const Color(0xFFE8F5E9)),
                    const SizedBox(width: 8),
                    _buildStatChip('Skipped', skippedList.length.toString(), Colors.amber[800]!, const Color(0xFFFFF8E1)),
                    const SizedBox(width: 8),
                    _buildStatChip('Failed', failedList.length.toString(), Colors.red[700]!, const Color(0xFFFFEBEE)),
                  ],
                ),
                const SizedBox(height: 16),
                if (skippedList.isNotEmpty) ...[
                  Text(
                    'Skipped Employees (${skippedList.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: skippedList
                          .map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text('• $item', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (failedList.isNotEmpty) ...[
                  Text(
                    'Failed Employees (${failedList.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: failedList
                          .map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text('• $item', style: TextStyle(fontSize: 12, color: Colors.red[900])),
                              ))
                          .toList(),
                    ),
                  ),
                ],
                if (skippedList.isEmpty && failedList.isEmpty) ...[
                  const Text(
                    'All employees were processed and saved successfully.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9CC70A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String activeMonth = _submittedMonth ?? _selectedMonth ?? ref.watch(selectedPayrollMonthProvider);
    final settingsAsync = ref.watch(payrollSettingsProvider);
    final settings = settingsAsync.value ?? const PayrollSettings();
    final employeesAsync = ref.watch(employeesProvider);
    final payrollRecordsAsync = ref.watch(payrollRecordsForMonthProvider);
    final orgsAsync = ref.watch(organizationsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Run Payroll',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
          final gutter = AppLayout.gutter(constraints.maxWidth);

          return SingleChildScrollView(
            padding: EdgeInsets.all(gutter),
            child: ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Organisation -> Department -> Month Filter Section
                  _buildFilterControlCard(context, orgsAsync, isMobile),
                  const SizedBox(height: 16),

                  // 2. If not submitted, show initial prompt
                  if (!_hasSubmitted) ...[
                    _buildInitialPromptCard(),
                  ] else ...[
                    // 3. If submitted, show payroll period header & employee list
                    _buildSubHeader(activeMonth, settings),
                    const SizedBox(height: 16),

                    employeesAsync.when(
                      data: (employees) => payrollRecordsAsync.when(
                        data: (records) {
                          // Strict filter: organizationId = selected organisation AND department = selected department (or All Departments)
                          final matchingEmployees = employees.where((emp) {
                            final submittedOrg = _submittedOrganization!;
                            final orgId = emp.organizationId.trim();

                            final matchesOrg = (orgId.isNotEmpty &&
                                    (orgId == submittedOrg.canonicalId ||
                                        orgId == submittedOrg.id.toString() ||
                                        orgId == submittedOrg.docId)) ||
                                (orgId.isEmpty &&
                                    emp.organizationName.trim().toLowerCase() ==
                                        submittedOrg.name.trim().toLowerCase());

                            final isAllDepts = _submittedDepartment == 'All Departments';
                            final matchesDept = isAllDepts ||
                                emp.department.trim().toLowerCase() ==
                                    _submittedDepartment!.trim().toLowerCase();

                            return matchesOrg && matchesDept;
                          }).toList();

                          // Search query within the matching employees
                          final filteredEmployees = matchingEmployees.where((emp) {
                            if (_searchQuery.isEmpty) return true;
                            final query = _searchQuery.toLowerCase();
                            final name = '${emp.firstName} ${emp.lastName}'.toLowerCase();
                            final id = 'emp${emp.id}'.toLowerCase();
                            final desig = emp.designation.toLowerCase();
                            return name.contains(query) || id.contains(query) || desig.contains(query);
                          }).toList();

                          if (matchingEmployees.isEmpty) {
                            return _buildEmptyState();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildActionsBar(
                                context: context,
                                matchingEmployees: matchingEmployees,
                                records: records,
                                activeMonth: activeMonth,
                                settings: settings,
                                isMobile: isMobile,
                              ),
                              if (_appliedOverrides.isNotEmpty)
                                _buildActiveUploadBanner(matchingEmployees),
                              const SizedBox(height: 16),
                              if (filteredEmployees.isEmpty)
                                _buildNoSearchResultsCard()
                              else
                                isMobile
                                    ? _buildMobileEmployeeList(
                                        context,
                                        filteredEmployees,
                                        records,
                                        activeMonth,
                                      )
                                    : _buildDesktopEmployeeList(
                                        context,
                                        filteredEmployees,
                                        records,
                                        activeMonth,
                                      ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error loading payroll records: $err')),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error loading employees: $err')),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveUploadBanner(List<Employee> matchingEmployees) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Upload active: "$_uploadedFileName" applied for ${_appliedOverrides.length} employees.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
            ),
          ),
          TextButton(
            onPressed: () => _handlePickAndValidateUpload(context, matchingEmployees),
            child: const Text('Replace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          const SizedBox(width: 2),
          TextButton(
            onPressed: () {
              setState(() {
                _appliedOverrides.clear();
                _uploadedFileName = null;
                ref.read(payrollInputOverridesProvider.notifier).state = {};
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Uploaded overrides cleared. Default master values restored.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport({
    required String type,
    required List<Employee> matchingEmployees,
    required List<PayrollRecord> records,
    required PayrollSettings settings,
  }) async {
    if (_submittedOrganization == null || _submittedDepartment == null || _submittedMonth == null) {
      return;
    }

    // Pre-fetch shared resources for live calculation of ungenerated employees
    final holidays = await ref.read(leaveRepositoryProvider).getHolidays();
    final permissions = await ref.read(permissionRepositoryProvider).getAllRequests();
    final incentives = await ref.read(incentiveRepositoryProvider).getAllRequests();
    final incentiveSettings = await ref.read(incentiveRepositoryProvider).getIncentiveSettings();
    final allLedgers = await ref.read(incentiveRepositoryProvider).getAllPayoutLedgers();
    final loanRepo = ref.read(loanRepositoryProvider);
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final leaveRepo = ref.read(leaveRepositoryProvider);
    final onDutyRepo = ref.read(onDutyRepositoryProvider);

    final resolvedRecords = <PayrollRecord>[];

    for (final emp in matchingEmployees) {
      final existingRecord = records.where((r) => r.employeeId == emp.id && r.id != 0).firstOrNull;
      if (existingRecord != null) {
        resolvedRecords.add(existingRecord);
      } else {
        try {
          final empAttendance = await attendanceRepo.getAttendanceRecords(emp.id);
          final empLeaves = await leaveRepo.getLeaveRequests(emp.id);
          final empOnDuty = await onDutyRepo.getAssignmentsForEmployee(employeeId: emp.id, date: null);
          final activeLoan = await loanRepo.getActiveLoanForEmployee(emp.id, _submittedMonth!);

          final override = _appliedOverrides[emp.id.toString()] ??
              _appliedOverrides[emp.employeeId.trim().toLowerCase()];

          final liveRecord = PayrollCalculationService.calculatePayrollRecord(
            employee: emp,
            month: _submittedMonth!,
            settings: settings,
            attendanceRecords: empAttendance,
            leaves: empLeaves,
            onDutyAssignments: empOnDuty,
            holidays: holidays,
            permissions: permissions,
            incentives: incentives,
            incentiveSettings: incentiveSettings,
            ledgers: allLedgers,
            activeLoan: activeLoan,
            overrideInput: override,
            status: 'Not Generated',
          );
          resolvedRecords.add(liveRecord);
        } catch (e) {

          debugPrint('Error calculating live payroll record for export: $e');
        }
      }
    }

    final dataset = PayrollReportDataset.build(
      organization: _submittedOrganization!,
      department: _submittedDepartment!,
      month: _submittedMonth!,
      employees: matchingEmployees,
      records: resolvedRecords,
    );

    try {
      if (type == 'copy') {
        await PayrollExportService.copyToClipboard(dataset);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payroll report copied to clipboard (tab-separated format).'),
              backgroundColor: Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (type == 'csv') {
        await PayrollExportService.exportCsv(context, dataset);
      } else if (type == 'excel') {
        await PayrollExportService.exportExcel(context, dataset);
      } else if (type == 'pdf') {
        await PayrollExportService.exportPdf(context, dataset);
      } else if (type == 'print') {
        await PayrollExportService.printReport(context, dataset);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildActionsBar({
    required BuildContext context,
    required List<Employee> matchingEmployees,
    required List<PayrollRecord> records,
    required String activeMonth,
    required PayrollSettings settings,
    required bool isMobile,
  }) {
    final exportMenuBtn = PopupMenuButton<String>(
      onSelected: (type) => _handleExport(
        type: type,
        matchingEmployees: matchingEmployees,
        records: records,
        settings: settings,
      ),
      tooltip: 'Export Payroll Report',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 18, color: AppColors.textPrimary),
              SizedBox(width: 10),
              Text('Copy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'csv',
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 18, color: AppColors.textPrimary),
              SizedBox(width: 10),
              Text('CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'excel',
          child: Row(
            children: [
              Icon(Icons.table_chart_outlined, size: 18, color: Color(0xFF16A34A)),
              SizedBox(width: 10),
              Text('Excel (.xlsx)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'print',
          child: Row(
            children: [
              Icon(Icons.print_outlined, size: 18, color: AppColors.textPrimary),
              SizedBox(width: 10),
              Text('Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.file_download_outlined, size: 18, color: AppColors.textPrimary),
            SizedBox(width: 6),
            Text(
              'Export',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );

    final instructionsBtn = OutlinedButton.icon(
      onPressed: () => _showExcelInstructionsDialog(context),
      icon: const Icon(Icons.help_outline_rounded, size: 18),
      label: const Text(
        'Excel Guide',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF414A51),
        side: const BorderSide(color: AppColors.divider, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final uploadBtn = OutlinedButton.icon(
      onPressed: _isGeneratingAll
          ? null
          : () => _handlePickAndValidateUpload(context, matchingEmployees),
      icon: const Icon(Icons.upload_file_outlined, size: 18),
      label: Text(
        _appliedOverrides.isEmpty ? 'Upload Excel/CSV' : 'Uploaded (${_appliedOverrides.length})',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _appliedOverrides.isEmpty ? AppColors.textPrimary : const Color(0xFF16A34A),
        side: BorderSide(
          color: _appliedOverrides.isEmpty ? AppColors.divider : const Color(0xFF16A34A),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final generateAllBtn = ElevatedButton.icon(
      onPressed: _isGeneratingAll
          ? null
          : () => _handleGenerateAll(
                context: context,
                matchingEmployees: matchingEmployees,
                records: records,
                month: activeMonth,
                settings: settings,
              ),
      icon: _isGeneratingAll
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.flash_on_rounded, size: 18),
      label: Text(
        _isGeneratingAll ? 'Generating...' : 'Generate All (${matchingEmployees.length})',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9CC70A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final matchingEmpIds = matchingEmployees.map((e) => e.id).toSet();
    final processedCount = records
        .where((r) => matchingEmpIds.contains(r.employeeId) && r.status.trim().toLowerCase() == 'processed')
        .length;

    final markAllAsPaidBtn = ElevatedButton.icon(
      onPressed: (_isGeneratingAll || _isMarkingAllPaid || processedCount == 0)
          ? null
          : () => _handleMarkAllAsPaid(
                context: context,
                matchingEmployees: matchingEmployees,
                records: records,
                month: activeMonth,
              ),
      icon: _isMarkingAllPaid
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.check_circle_outline, size: 18),
      label: Text(
        _isMarkingAllPaid
            ? 'Marking Paid...'
            : (processedCount > 0 ? 'Mark All as Paid ($processedCount)' : 'Mark All as Paid'),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF414A51),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE2E8F0),
        disabledForegroundColor: const Color(0xFF94A3B8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: exportMenuBtn),
              const SizedBox(width: 8),
              Expanded(child: instructionsBtn),
            ],
          ),
          const SizedBox(height: 8),
          uploadBtn,
          const SizedBox(height: 8),
          generateAllBtn,
          const SizedBox(height: 8),
          markAllAsPaidBtn,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildSearchBar()),
        const SizedBox(width: 10),
        exportMenuBtn,
        const SizedBox(width: 8),
        instructionsBtn,
        const SizedBox(width: 8),
        uploadBtn,
        const SizedBox(width: 8),
        generateAllBtn,
        const SizedBox(width: 8),
        markAllAsPaidBtn,
      ],
    );
  }


  Widget _buildFilterControlCard(
    BuildContext context,
    AsyncValue<List<Organization>> orgsAsync,
    bool isMobile,
  ) {
    final availableMonths = _getAvailableMonths();
    final String currentMonth = _selectedMonth ?? ref.watch(selectedPayrollMonthProvider);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: orgsAsync.when(
          data: (organizations) {
            final activeOrgs = organizations.where((o) => o.isActive).toList();

            // Department options for selected organization
            List<String> departmentNames = [];
            if (_selectedOrganization != null) {
              final selectedOrg = _selectedOrganization!;
              final deptsAsync = ref.watch(filteredDepartmentsProvider(
                DepartmentFilter(
                  organizationId: selectedOrg.canonicalId,
                  organizationName: selectedOrg.name,
                ),
              ));
              final rawDepts = deptsAsync.valueOrNull ?? [];
              final allDepts = ref.watch(departmentsProvider).valueOrNull ?? [];

              bool isOrgMatch(Department d) {
                final orgId = d.organizationId.trim();
                final orgName = d.organizationName.trim().toLowerCase();
                final selectedOrgName = selectedOrg.name.trim().toLowerCase();

                final idMatch = orgId.isNotEmpty && (
                  orgId == selectedOrg.canonicalId ||
                  orgId == selectedOrg.id.toString() ||
                  orgId == selectedOrg.docId
                );

                final nameMatch = orgName.isNotEmpty && orgName == selectedOrgName;

                return idMatch || nameMatch;
              }

              final combined = <Department>[];
              for (final d in [...rawDepts, ...allDepts]) {
                if (isOrgMatch(d) && !combined.any((c) => c.departmentName.trim().toLowerCase() == d.departmentName.trim().toLowerCase())) {
                  combined.add(d);
                }
              }

              departmentNames = combined
                  .map((d) => d.departmentName.trim())
                  .where((name) => name.isNotEmpty)
                  .toSet()
                  .toList();
              departmentNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              departmentNames.insert(0, 'All Departments');
            }

            final isDepartmentEnabled = _selectedOrganization != null;

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOrgDropdown(activeOrgs),
                  const SizedBox(height: 14),
                  _buildDeptDropdown(departmentNames, isDepartmentEnabled),
                  const SizedBox(height: 14),
                  _buildMonthDropdown(availableMonths, currentMonth),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _isGeneratingAll ? null : _handleSubmit,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildOrgDropdown(activeOrgs),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: _buildDeptDropdown(departmentNames, isDepartmentEnabled),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: _buildMonthDropdown(availableMonths, currentMonth),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingAll ? null : _handleSubmit,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading organizations: $err')),
        ),
      ),
    );
  }

  Widget _buildOrgDropdown(List<Organization> organizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Organisation',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Organization>(
              isExpanded: true,
              value: _selectedOrganization != null &&
                      organizations.any((o) => o.canonicalId == _selectedOrganization!.canonicalId || o.id == _selectedOrganization!.id)
                  ? organizations.firstWhere((o) => o.canonicalId == _selectedOrganization!.canonicalId || o.id == _selectedOrganization!.id)
                  : null,
              hint: const Text('Select Organisation', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              onChanged: _isGeneratingAll
                  ? null
                  : (Organization? newOrg) {
                      setState(() {
                        _selectedOrganization = newOrg;
                        _selectedDepartment = null; // Clear previously selected department
                      });
                    },
              items: organizations.map((org) {
                return DropdownMenuItem<Organization>(
                  value: org,
                  child: Text(org.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeptDropdown(List<String> departmentNames, bool isEnabled) {
    final effectiveEnabled = isEnabled && !_isGeneratingAll;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Department',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: effectiveEnabled ? Colors.white : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: effectiveEnabled && _selectedDepartment != null && departmentNames.contains(_selectedDepartment)
                  ? _selectedDepartment
                  : null,
              hint: Text(
                _selectedOrganization == null
                    ? 'Select Organisation first'
                    : (departmentNames.isEmpty ? 'No departments found' : 'Select Department'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: effectiveEnabled ? AppColors.textSecondary : Colors.grey[400],
                size: 20,
              ),
              style: TextStyle(
                fontSize: 13,
                color: effectiveEnabled ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              onChanged: effectiveEnabled
                  ? (String? newDept) {
                      setState(() {
                        _selectedDepartment = newDept;
                      });
                    }
                  : null,
              items: effectiveEnabled
                  ? departmentNames.map((dept) {
                      return DropdownMenuItem<String>(
                        value: dept,
                        child: Text(dept, overflow: TextOverflow.ellipsis),
                      );
                    }).toList()
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthDropdown(List<String> availableMonths, String currentMonth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Month',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: availableMonths.contains(_selectedMonth ?? currentMonth)
                  ? (_selectedMonth ?? currentMonth)
                  : (availableMonths.isNotEmpty ? availableMonths.first : null),
              hint: const Text('Select Month', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              onChanged: _isGeneratingAll
                  ? null
                  : (String? newMonth) {
                      if (newMonth != null) {
                        setState(() {
                          _selectedMonth = newMonth;
                        });
                      }
                    },
              items: availableMonths.map((m) {
                return DropdownMenuItem<String>(
                  value: m,
                  child: Text(m, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialPromptCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.filter_alt_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Filters to Run Payroll',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose an Organisation, Department, and Month above, then click Submit to load eligible employees.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubHeader(String month, PayrollSettings settings) {
    final parsed = PayrollCalculationService.parseMonthYear(month);
    final period = settings.getPayrollPeriod(parsed.year, parsed.monthNum);

    final orgName = _submittedOrganization?.name ?? '';
    final deptName = _submittedDepartment ?? '';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.active, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Running payroll for $orgName • $deptName • $month (${period.displayPeriodString}). Select an employee to review or calculate monthly salary.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search Employee by Name, ID, Designation...',
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopEmployeeList(
    BuildContext context,
    List<Employee> employees,
    List<PayrollRecord> records,
    String selectedMonth,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2), // Employee Name
          1: FlexColumnWidth(1.2), // Emp ID
          2: FlexColumnWidth(1.8), // Department
          3: FlexColumnWidth(1.8), // Designation
          4: FlexColumnWidth(1.4), // Status
          5: FlexColumnWidth(2.2), // Actions
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            children: [
              _buildTableHeader('Employee'),
              _buildTableHeader('Employee ID'),
              _buildTableHeader('Department'),
              _buildTableHeader('Designation'),
              _buildTableHeader('Status'),
              _buildTableHeader('Actions'),
            ],
          ),
          for (final emp in employees) ...[
            () {
              final payrollRecord = records.firstWhere(
                (r) => r.employeeId == emp.id,
                orElse: () => PayrollRecord(
                  id: 0,
                  employeeId: emp.id,
                  employeeName: '${emp.firstName} ${emp.lastName}',
                  month: selectedMonth,
                  presentDays: 0,
                  lateDays: 0,
                  absentDays: 0,
                  leaveDays: 0,
                  basicPay: 0,
                  hra: 0,
                  specialAllowance: 0,
                  educationAllowance: 0,
                  pf: 0,
                  tax: 0,
                  netSalary: 0,
                  status: 'Not Generated',
                ),
              );

              final isGenerated = payrollRecord.id != 0;
              final hasOverride = _appliedOverrides.containsKey(emp.id.toString());

              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                children: [
                  _buildTableCell(
                    Row(
                      children: [
                        Text('${emp.firstName} ${emp.lastName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (hasOverride) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Override',
                              style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildTableCell(Text('EMP${emp.id}', style: const TextStyle(fontWeight: FontWeight.w500))),
                  _buildTableCell(Text(emp.department)),
                  _buildTableCell(Text(emp.designation)),
                  _buildTableCell(_buildStatusBadge(payrollRecord.status)),
                  _buildTableCell(
                    isGenerated
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: _isGeneratingAll
                                    ? null
                                    : () => context.push('/payroll/details/${payrollRecord.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.active,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('View Details', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _isGeneratingAll
                                    ? null
                                    : () => context.push('/payroll/payslip/${payrollRecord.id}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('Payslip', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            onPressed: _isGeneratingAll
                                ? null
                                : () => context.push('/payroll/generate/${emp.id}'),
                            icon: const Icon(Icons.play_arrow_rounded, size: 14),
                            label: const Text('Generate', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                  ),
                ],
              );
            }()
          ]
        ],
      ),
    );
  }

  Widget _buildMobileEmployeeList(
    BuildContext context,
    List<Employee> employees,
    List<PayrollRecord> records,
    String selectedMonth,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final emp = employees[index];
        final payrollRecord = records.firstWhere(
          (r) => r.employeeId == emp.id,
          orElse: () => PayrollRecord(
            id: 0,
            employeeId: emp.id,
            employeeName: '${emp.firstName} ${emp.lastName}',
            month: selectedMonth,
            presentDays: 0,
            lateDays: 0,
            absentDays: 0,
            leaveDays: 0,
            basicPay: 0,
            hra: 0,
            specialAllowance: 0,
            educationAllowance: 0,
            pf: 0,
            tax: 0,
            netSalary: 0,
            status: 'Not Generated',
          ),
        );

        final isGenerated = payrollRecord.id != 0;
        final hasOverride = _appliedOverrides.containsKey(emp.id.toString());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${emp.firstName} ${emp.lastName}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        if (hasOverride) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Override',
                              style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EMP${emp.id} • ${emp.department} • ${emp.designation}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 14),
                    isGenerated
                        ? Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isGeneratingAll
                                      ? null
                                      : () => context.push('/payroll/details/${payrollRecord.id}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.active,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('View Details', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isGeneratingAll
                                      ? null
                                      : () => context.push('/payroll/payslip/${payrollRecord.id}'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Payslip', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isGeneratingAll
                                  ? null
                                  : () => context.push('/payroll/generate/${emp.id}'),
                              icon: const Icon(Icons.play_arrow_rounded, size: 14),
                              label: const Text('Generate Payroll'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _buildStatusBadge(payrollRecord.status),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey[700]!;
    Color bgColor = Colors.grey[100]!;

    if (status == 'Paid') {
      color = const Color(0xFF9CC70A);
      bgColor = const Color(0xFF9CC70A).withValues(alpha: 0.1);
    } else if (status == 'Processed') {
      color = Colors.blue[700]!;
      bgColor = Colors.blue[50]!;
    } else if (status == 'Draft' || status == 'Pending') {
      color = Colors.amber[800]!;
      bgColor = Colors.amber[50]!;
    } else if (status == 'Not Generated') {
      color = Colors.blueGrey[700]!;
      bgColor = Colors.blueGrey[50]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Text(
            'No matching employees found for the selected organization and department.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResultsCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Text(
            'No employees match your search query.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
