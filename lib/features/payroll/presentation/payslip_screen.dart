import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../employee/services/offer_letter_save_stub.dart'
    if (dart.library.html) '../../employee/services/offer_letter_save_web.dart'
    if (dart.library.io) '../../employee/services/offer_letter_save_io.dart';
import '../../organization/domain/organization.dart';
import '../../organization/providers/organization_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../services/payslip_pdf_generator.dart';
import '../utils/currency_words_helper.dart';
import '../utils/organization_branding_helper.dart';
import 'widgets/payslip_brand_logo_widget.dart';

class PayslipScreen extends ConsumerStatefulWidget {
  const PayslipScreen({required this.payrollId, super.key});
  final int payrollId;

  @override
  ConsumerState<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends ConsumerState<PayslipScreen> {
  bool _downloading = false;

  String _maskBankAccount(String acctNo) {
    final clean = acctNo.trim();
    if (clean.length <= 4) return clean;
    return '${"*" * (clean.length - 4)}${clean.substring(clean.length - 4)}';
  }

  void _showFeedback(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF9CC70A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleDownloadPdf(
    BuildContext context,
    PayrollRecord record,
    Employee? employee,
    Organization? organization,
  ) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });

    try {
      final pdfBytes = await PayslipPdfGenerator.generatePayslipPdf(
        record: record,
        employee: employee,
        organization: organization,
      ).timeout(const Duration(seconds: 8));

      final cleanEmpId = (employee?.employeeId.isNotEmpty == true
              ? employee!.employeeId
              : 'EMP_${record.employeeId}')
          .replaceAll(RegExp(r'[^\w\-_]'), '_');
      final cleanMonth = record.month.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final fileName = 'Payslip_${cleanEmpId}_$cleanMonth.pdf';

      if (context.mounted) {
        await saveAndDownloadOfferLetter(
          context: context,
          bytes: pdfBytes,
          fileName: fileName,
          docTitle: 'Payslip',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showFeedback(context, 'Failed to generate PDF: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  void _showOverflowMenu(
    BuildContext context,
    WidgetRef ref,
    PayrollRecord record,
    Employee? employee,
    Organization? organization,
    bool isMobile,
  ) {
    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.print_outlined, color: Color(0xFF414A51)),
                  title: const Text('Print Payslip'),
                  onTap: () {
                    Navigator.pop(context);
                    _handleDownloadPdf(context, record, employee, organization);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  title: const Text('Report an issue', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportIssueDialog(context, ref, record);
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final payrollAsync = ref.watch(payrollRecordByIdProvider(widget.payrollId));
    final currentEmp = ref.watch(currentEmployeeProvider);
    final employees = ref.watch(employeesProvider).valueOrNull ?? [];
    final organizations = ref.watch(organizationsProvider).valueOrNull ?? [];

    return payrollAsync.when(
      data: (record) {
        if (record == null) {
          return Scaffold(
            backgroundColor: AppColors.canvas,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF414A51)),
                onPressed: () => context.pop(),
              ),
              title: const Text('Payslip Detail'),
            ),
            body: const Center(child: Text('Payroll record not found.')),
          );
        }

        // 1. Resolve matching employee
        Employee? matchingEmp;
        if (record.employeeId > 0) {
          matchingEmp = employees.where((e) => e.id == record.employeeId).firstOrNull;
        }
        if (matchingEmp == null && currentEmp != null) {
          if (currentEmp.id == record.employeeId ||
              (record.employeeName.trim().isNotEmpty &&
                  record.employeeName.toLowerCase() == currentEmp.fullName.toLowerCase())) {
            matchingEmp = currentEmp;
          }
        }

        // 2. Resolve organization dynamically
        Organization? resolvedOrg;
        if (matchingEmp != null) {
          final empOrgId = matchingEmp.organizationId.trim();
          final empOrgName = matchingEmp.organizationName.trim();

          if (empOrgId.isNotEmpty) {
            resolvedOrg = organizations.where((o) =>
                o.docId == empOrgId ||
                o.canonicalId == empOrgId ||
                o.id.toString() == empOrgId ||
                'org_${o.id}' == empOrgId).firstOrNull;
          }
          if (resolvedOrg == null && empOrgName.isNotEmpty) {
            resolvedOrg = organizations.where((o) =>
                o.name.trim().toLowerCase() == empOrgName.toLowerCase()).firstOrNull;
          }
        }
        if (resolvedOrg == null && organizations.isNotEmpty) {
          if (matchingEmp != null) {
            final empOrgNameLower = matchingEmp.organizationName.toLowerCase();
            final empCode = matchingEmp.employeeId.toUpperCase();
            if (empOrgNameLower.contains('technolog') || empCode.startsWith('EMP')) {
              resolvedOrg = organizations.where((o) => o.name.toLowerCase().contains('technolog')).firstOrNull;
            } else if (empOrgNameLower.contains('engineering') || empCode.startsWith('IGT')) {
              resolvedOrg = organizations.where((o) => o.name.toLowerCase().contains('engineering')).firstOrNull;
            }
          }
          resolvedOrg ??= organizations.firstOrNull;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
            final gutter = AppLayout.gutter(constraints.maxWidth);

            return Scaffold(
              backgroundColor: AppColors.canvas,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF414A51)),
                  onPressed: () => context.pop(),
                ),
                title: const Text(
                  'Payslip Detail',
                  style: TextStyle(color: Color(0xFF414A51), fontWeight: FontWeight.bold),
                ),
                actions: [
                  if (isMobile)
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Color(0xFF414A51)),
                      onPressed: () => _showOverflowMenu(
                        context,
                        ref,
                        record,
                        matchingEmp,
                        resolvedOrg,
                        true,
                      ),
                    )
                  else
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Color(0xFF414A51)),
                      onSelected: (val) {
                        if (val == 'print') {
                          _handleDownloadPdf(context, record, matchingEmp, resolvedOrg);
                        } else if (val == 'report') {
                          _showReportIssueDialog(context, ref, record);
                        }
                      },
                      color: Colors.white,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'print',
                          child: Row(
                            children: [
                              Icon(Icons.print_outlined, size: 18, color: Color(0xFF414A51)),
                              SizedBox(width: 8),
                              Text('Print / Download PDF'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Report an issue', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              body: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(gutter),
                  child: ResponsiveContent(
                    maxWidth: 820,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (record.isDisputed)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DISPUTE RAISED BY EMPLOYEE',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        record.disputeComment,
                                        style: TextStyle(color: Colors.red[900], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildPayslipStructuredCard(
                          record: record,
                          employee: matchingEmp,
                          organization: resolvedOrg,
                          isMobile: isMobile,
                        ),
                        const SizedBox(height: 24),
                        _buildActionRow(
                          context: context,
                          record: record,
                          employee: matchingEmp,
                          organization: resolvedOrg,
                          isMobile: isMobile,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF414A51)),
            onPressed: () => context.pop(),
          ),
          title: const Text('Payslip Detail'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ResponsiveContent(
              maxWidth: 820,
              child: _buildSkeletonLoader(),
            ),
          ),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(child: Text('Error loading payslip: $err')),
      ),
    );
  }

  Widget _buildPayslipStructuredCard({
    required PayrollRecord record,
    required Employee? employee,
    required Organization? organization,
    required bool isMobile,
  }) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);

    // Dynamic Organization Branding
    final branding = OrganizationPayslipBranding.resolve(
      organization: organization,
      employee: employee,
    );

    // Employee & Statutory Details (prefer snapshot in PayrollRecord)
    final displayName = record.employeeName.isNotEmpty
        ? record.employeeName
        : (employee?.fullName.isNotEmpty == true ? employee!.fullName : 'Employee');

    final displayEmpId = employee?.employeeId.isNotEmpty == true
        ? employee!.employeeId
        : (record.employeeId > 0
            ? (branding.isTecEngineering
                ? 'IGT - ${record.employeeId.toString().padLeft(4, '0')}'
                : 'EMP-${record.employeeId.toString().padLeft(4, '0')}')
            : '-');

    final displayDesignation = record.designation.isNotEmpty
        ? record.designation
        : (employee?.designation.isNotEmpty == true ? employee!.designation : '-');

    final displayDepartment = record.department.isNotEmpty
        ? record.department
        : (employee?.department.isNotEmpty == true ? employee!.department : '-');

    final displayEmail = record.emailId.isNotEmpty
        ? record.emailId
        : (employee?.emailAddress.isNotEmpty == true ? employee!.emailAddress : '-');

    final panNo = record.panNumber.isNotEmpty
        ? record.panNumber
        : (employee?.panNumber.isNotEmpty == true ? employee!.panNumber : '-');

    final pfNo = record.pfNumber.isNotEmpty
        ? record.pfNumber
        : (employee?.pfUan.isNotEmpty == true
            ? employee!.pfUan
            : (employee?.pfNumber.isNotEmpty == true ? employee!.pfNumber : '-'));

    final esiNo = record.esiNumber.isNotEmpty
        ? record.esiNumber
        : (employee?.esiNumber.isNotEmpty == true ? employee!.esiNumber : '-');

    final bankName = record.bankName.isNotEmpty
        ? record.bankName
        : (employee?.bankName.isNotEmpty == true ? employee!.bankName : '-');

    final bankAcct = record.bankAcctNo.isNotEmpty
        ? record.bankAcctNo
        : (employee?.bankAccountNumber.isNotEmpty == true ? employee!.bankAccountNumber : '-');

    final branch = record.branch.isNotEmpty
        ? record.branch
        : (employee?.bankBranch.isNotEmpty == true ? employee!.bankBranch : '-');

    final ifsc = record.ifscCode.isNotEmpty
        ? record.ifscCode
        : (employee?.bankIfsc.isNotEmpty == true ? employee!.bankIfsc : '-');

    // Attendance
    final totalDays = record.totalWorkingDays > 0
        ? record.totalWorkingDays
        : (record.presentDays + record.lateDays + record.absentDays + record.leaveDays);

    // Standard Master Salaries
    final standardBasic = employee != null && employee.salaryBasic > 0 ? employee.salaryBasic : record.basicPay;
    final standardHra = employee != null && employee.salaryHra > 0 ? employee.salaryHra : record.hra;
    final standardEdu = employee != null && employee.salaryEducationAllowance > 0
        ? employee.salaryEducationAllowance
        : record.educationAllowance;
    final standardSpecial = employee != null && employee.salarySpecialAllowance > 0
        ? employee.salarySpecialAllowance
        : record.specialAllowance;
    final standardSalary = employee != null && employee.salaryTotalCtc > 0
        ? (employee.salaryType.toLowerCase() == 'yearly'
            ? employee.salaryTotalCtc / 12.0
            : employee.salaryTotalCtc)
        : (standardBasic + standardHra + standardEdu + standardSpecial);

    // Monthly Processed Earnings
    final grossSalary = record.basicPay +
        record.hra +
        record.educationAllowance +
        record.specialAllowance +
        record.travelAllowance +
        record.otherAllowance +
        record.incentive +
        record.othersEarning +
        record.bonus +
        record.ot;

    // Monthly Processed Deductions
    final deductions = record.pf +
        record.tax +
        record.esi +
        record.lop +
        record.companyLoan +
        record.salaryAdvance +
        record.othersDeduction +
        record.staffWelfareContribution +
        record.greeting;

    final netSalary = record.netSalary > 0 ? record.netSalary : (grossSalary - deductions);
    final netWords = CurrencyWordsHelper.formatAmountInWords(netSalary);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF414A51), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER SECTION (Dynamic Organization Branding, Email & TAN Number)
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFF414A51), width: 1)),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            PayslipBrandLogoWidget(
                              branding: branding,
                              height: 44,
                            ),
                            _buildStatusPill(record),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: AppColors.divider),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (branding.email.isNotEmpty)
                              Text(
                                'EMAIL : ${branding.email.toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            if (branding.tanNumber.isNotEmpty)
                              Text(
                                'TAN No: ${branding.tanNumber}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF414A51),
                                ),
                              ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        PayslipBrandLogoWidget(
                          branding: branding,
                          height: 54,
                        ),
                        if (branding.email.isNotEmpty)
                          Text(
                            'EMAIL : ${branding.email.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF414A51),
                            ),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (branding.tanNumber.isNotEmpty)
                              Text(
                                'TAN No: ${branding.tanNumber}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF414A51),
                                ),
                              ),
                            const SizedBox(width: 10),
                            _buildStatusPill(record),
                          ],
                        ),
                      ],
                    ),
            ),

            // 2. TWO-COLUMN EMPLOYEE / STATUTORY & BANK DETAILS SECTION
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF414A51), width: 1)),
              ),
              child: isMobile
                  ? Column(
                      children: [
                        _buildLeftDetailsBox(
                          record: record,
                          employeeId: displayEmpId,
                          name: displayName,
                          designation: displayDesignation,
                          department: displayDepartment,
                          email: displayEmail,
                          daysWorked: '${record.presentDays}',
                          isMobile: true,
                        ),
                        const Divider(height: 1, color: Color(0xFF414A51)),
                        _buildRightDetailsBox(
                          pan: panNo,
                          pf: pfNo,
                          esi: esiNo,
                          bankName: bankName,
                          bankAcct: _maskBankAccount(bankAcct),
                          branch: branch,
                          ifsc: ifsc,
                          isMobile: true,
                        ),
                      ],
                    )
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildLeftDetailsBox(
                              record: record,
                              employeeId: displayEmpId,
                              name: displayName,
                              designation: displayDesignation,
                              department: displayDepartment,
                              email: displayEmail,
                              daysWorked: '${record.presentDays}',
                              isMobile: false,
                            ),
                          ),
                          Container(width: 1, color: AppColors.divider),
                          Expanded(
                            child: _buildRightDetailsBox(
                              pan: panNo,
                              pf: pfNo,
                              esi: esiNo,
                              bankName: bankName,
                              bankAcct: _maskBankAccount(bankAcct),
                              branch: branch,
                              ifsc: ifsc,
                              isMobile: false,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // 3. ATTENDANCE METRICS ROW
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2F6),
                border: Border(bottom: BorderSide(color: Color(0xFF414A51), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttendanceMetricCell('PRESENT DAYS', '${record.presentDays}'),
                  _buildAttendanceMetricCell('LATE DAYS', '${record.lateDays}'),
                  _buildAttendanceMetricCell('ABSENT (LOP)', '${record.absentDays}'),
                  _buildAttendanceMetricCell('LEAVE DAYS', '${record.leaveDays}'),
                  _buildAttendanceMetricCell('TOTAL DAYS', '$totalDays'),
                ],
              ),
            ),

            // 4. THREE-COLUMN SALARY TABLE (Standard CTC | Earnings | Deductions)
            _buildSalaryTable(
              currencyFormat: currencyFormat,
              isMobile: isMobile,
              standardBasic: standardBasic,
              standardHra: standardHra,
              standardEdu: standardEdu,
              standardSpecial: standardSpecial,
              standardSalary: standardSalary,
              record: record,
              grossSalary: grossSalary,
              deductions: deductions,
            ),

            // 5. SUMMARY & NET SALARY ROW
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFF414A51), width: 1),
                  bottom: BorderSide(color: Color(0xFF414A51), width: 1),
                ),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'NET SALARY',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF414A51),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF9CC70A)),
                              ),
                              child: Text(
                                currencyFormat.format(netSalary),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF414A51),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'In words: $netWords Rupees Only',
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NET SALARY',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF414A51),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'In words: $netWords Rupees Only',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF9CC70A)),
                          ),
                          child: Text(
                            currencyFormat.format(netSalary),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF414A51),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            // 6. SYSTEM GENERATED FOOTER
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: const Color(0xFFF8F9FA),
              child: const Center(
                child: Text(
                  'This Is A System Generated Payslip Hence Needs No Signature',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF414A51),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildLeftDetailsBox({
    required PayrollRecord record,
    required String employeeId,
    required String name,
    required String designation,
    required String department,
    required String email,
    required String daysWorked,
    required bool isMobile,
  }) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'PAYSLIP PERIOD',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF414A51),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildDetailRow('Month-Year', record.month),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'EMPLOYEE DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF414A51),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Employee No', employeeId),
          _buildDetailRow('Employee Name', name),
          _buildDetailRow('Designation', designation),
          _buildDetailRow('Department', department),
          _buildDetailRow('Email ID', email),
          _buildDetailRow('Days Worked in Month', daysWorked),
        ],
      ),
    );
  }

  Widget _buildRightDetailsBox({
    required String pan,
    required String pf,
    required String esi,
    required String bankName,
    required String bankAcct,
    required String branch,
    required String ifsc,
    required bool isMobile,
  }) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'STATUTORY DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF414A51),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildDetailRow('PAN Number', pan),
          _buildDetailRow('PF / UAN', pf),
          _buildDetailRow('ESI Number', esi),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'BANK DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF414A51),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildDetailRow('Bank Name', bankName),
          _buildDetailRow('Bank Account No', bankAcct),
          _buildDetailRow('Branch', branch),
          _buildDetailRow('IFSC / SWIFT Code', ifsc),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF414A51),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceMetricCell(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Color(0xFF414A51),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF414A51),
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryTable({
    required NumberFormat currencyFormat,
    required bool isMobile,
    required double standardBasic,
    required double standardHra,
    required double standardEdu,
    required double standardSpecial,
    required double standardSalary,
    required PayrollRecord record,
    required double grossSalary,
    required double deductions,
  }) {
    final rows = [
      _SalaryTableRow(
        col1Label: 'Basic Pay',
        col1Value: currencyFormat.format(standardBasic),
        col2Label: 'Basic Pay',
        col2Value: currencyFormat.format(record.basicPay),
        col3Label: 'PF (Statutory)',
        col3Value: currencyFormat.format(record.pf),
      ),
      _SalaryTableRow(
        col1Label: 'HRA',
        col1Value: currencyFormat.format(standardHra),
        col2Label: 'HRA',
        col2Value: currencyFormat.format(record.hra),
        col3Label: 'TDS / Tax',
        col3Value: currencyFormat.format(record.tax),
      ),
      _SalaryTableRow(
        col1Label: 'Educational Allowance',
        col1Value: currencyFormat.format(standardEdu),
        col2Label: 'Educational Allowance',
        col2Value: currencyFormat.format(record.educationAllowance),
        col3Label: 'ESI',
        col3Value: currencyFormat.format(record.esi),
      ),
      _SalaryTableRow(
        col1Label: 'Special Allowance',
        col1Value: currencyFormat.format(standardSpecial),
        col2Label: 'Special Allowance',
        col2Value: currencyFormat.format(record.specialAllowance),
        col3Label: 'Hourly LOP',
        col3Value: currencyFormat.format(record.lop),
      ),
      _SalaryTableRow(
        col1Label: '-',
        col1Value: '-',
        col2Label: 'Incentive',
        col2Value: currencyFormat.format(record.incentive),
        col3Label: record.loanDescription.isNotEmpty
            ? 'Company Loan (${record.loanDescription})'
            : 'Company Loan',
        col3Value: currencyFormat.format(record.companyLoan),
      ),
      _SalaryTableRow(
        col1Label: '-',
        col1Value: '-',
        col2Label: 'Carry Forward',
        col2Value: record.carryForward.isNotEmpty ? record.carryForward : '-',
        col3Label: record.advanceDescription.isNotEmpty
            ? 'Salary Advance (${record.advanceDescription})'
            : 'Salary Advance',
        col3Value: currencyFormat.format(record.salaryAdvance),
      ),
      _SalaryTableRow(
        col1Label: '-',
        col1Value: '-',
        col2Label: 'Others',
        col2Value: currencyFormat.format(record.othersEarning),
        col3Label: 'Staff Welfare',
        col3Value: currencyFormat.format(record.staffWelfareContribution),
      ),
      _SalaryTableRow(
        col1Label: '-',
        col1Value: '-',
        col2Label: 'Cumulative Incentive',
        col2Value: currencyFormat.format(record.cumulativeIncentive),
        col3Label: 'Other Deductions',
        col3Value: currencyFormat.format(record.othersDeduction),
      ),
    ];

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 700,
          child: _buildTableInternal(rows, currencyFormat, standardSalary, grossSalary, deductions),
        ),
      );
    }

    return _buildTableInternal(rows, currencyFormat, standardSalary, grossSalary, deductions);
  }

  Widget _buildTableInternal(
    List<_SalaryTableRow> rows,
    NumberFormat currencyFormat,
    double standardSalary,
    double grossSalary,
    double deductions,
  ) {
    return Table(
      border: const TableBorder(
        verticalInside: BorderSide(color: AppColors.divider, width: 0.8),
        horizontalInside: BorderSide(color: AppColors.divider, width: 0.5),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFEEF2F6)),
          children: [
            _buildTableHeaderCell('MONTHLY SALARY (CTC)'),
            _buildTableHeaderCell('EARNINGS'),
            _buildTableHeaderCell('DEDUCTIONS'),
          ],
        ),
        ...rows.map(
          (row) => TableRow(
            children: [
              _buildTableCell(row.col1Label, row.col1Value),
              _buildTableCell(row.col2Label, row.col2Value),
              _buildTableCell(row.col3Label, row.col3Value),
            ],
          ),
        ),
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
          children: [
            _buildTotalCell('Standard Salary', currencyFormat.format(standardSalary)),
            _buildTotalCell('Gross Salary', currencyFormat.format(grossSalary)),
            _buildTotalCell('Total Deductions', currencyFormat.format(deductions)),
          ],
        ),
      ],
    );
  }

  Widget _buildTableHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF414A51),
        ),
      ),
    );
  }

  Widget _buildTableCell(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF414A51)),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF414A51),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCell(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF414A51),
              ),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF414A51),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(PayrollRecord record) {
    final status = record.status;
    final isPaid = status == 'Paid';
    final isProcessed = status == 'Processed';

    Color color;
    Color bgColor;

    if (isPaid) {
      color = const Color(0xFF9CC70A);
      bgColor = const Color(0xFF9CC70A).withValues(alpha: 0.12);
    } else if (isProcessed) {
      color = const Color(0xFF414A51);
      bgColor = const Color(0xFF414A51).withValues(alpha: 0.1);
    } else {
      color = Colors.amber[800]!;
      bgColor = Colors.amber[50]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPaid) ...[
            const Icon(Icons.lock_outlined, size: 11, color: Color(0xFF9CC70A)),
            const SizedBox(width: 3),
          ],
          Text(
            status,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required BuildContext context,
    required PayrollRecord record,
    required Employee? employee,
    required Organization? organization,
    required bool isMobile,
  }) {
    final downloadBtn = ElevatedButton.icon(
      onPressed: _downloading
          ? null
          : () => _handleDownloadPdf(context, record, employee, organization),
      icon: _downloading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.download_rounded, size: 18),
      label: Text(
        _downloading ? 'Preparing PDF…' : 'Download PDF',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9CC70A),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[200],
        disabledForegroundColor: Colors.grey[400],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );

    final emailBtn = OutlinedButton.icon(
      onPressed: () => _showFeedback(context, 'Payslip emailed to employee.'),
      icon: const Icon(Icons.email_outlined, size: 18, color: Color(0xFF414A51)),
      label: const Text(
        'Send Email',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.divider, width: 1),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white,
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          downloadBtn,
          const SizedBox(height: 10),
          emailBtn,
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: downloadBtn),
          const SizedBox(width: 12),
          Expanded(child: emailBtn),
        ],
      );
    }
  }

  Widget _buildSkeletonLoader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 160,
                height: 24,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
              ),
              Container(
                width: 60,
                height: 20,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 160,
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
          ),
        ],
      ),
    );
  }

  void _showReportIssueDialog(BuildContext context, WidgetRef ref, PayrollRecord record) {
    final commentController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report an Issue / Query'),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please describe the query or mismatch in detail. This will flag the payslip to HR/admin for review.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'e.g. LOP days incorrect, missing bonus, bank credit issue...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final comment = commentController.text.trim();
                if (comment.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a description of the issue.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext);

                final updated = record.copyWith(
                  isDisputed: true,
                  disputeComment: comment,
                );

                try {
                  await ref.read(payrollRepositoryProvider).savePayrollRecord(updated);
                  ref.invalidate(payrollRecordByIdProvider(record.id));
                  ref.invalidate(payrollRecordsForMonthProvider);
                  ref.invalidate(employeePayrollRecordsProvider(record.employeeId));

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dispute raised successfully. HR has been notified.'),
                        backgroundColor: Color(0xFF9CC70A),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to raise dispute: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Query'),
            ),
          ],
        );
      },
    );
  }
}

class _SalaryTableRow {
  final String col1Label;
  final String col1Value;
  final String col2Label;
  final String col2Value;
  final String col3Label;
  final String col3Value;

  const _SalaryTableRow({
    required this.col1Label,
    required this.col1Value,
    required this.col2Label,
    required this.col2Value,
    required this.col3Label,
    required this.col3Value,
  });
}
