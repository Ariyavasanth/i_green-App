import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/payslip_logo_assets.dart';
import '../../employee/domain/employee.dart';
import '../../organization/domain/organization.dart';
import '../domain/payroll.dart';
import '../utils/currency_words_helper.dart';
import '../utils/organization_branding_helper.dart';

class PayslipPdfGenerator {
  static final _numberFormat = NumberFormat('#,##0', 'en_IN');

  static String _formatMoney(double amount) {
    if (amount == 0) return '0';
    return _numberFormat.format(amount);
  }

  /// Generates the binary PDF document for a payslip matching the exact reference layout and dynamic branding.
  static Future<Uint8List> generatePayslipPdf({
    required PayrollRecord record,
    Employee? employee,
    Organization? organization,
  }) async {
    PayslipLogoAssets.ensureAssetsExist();

    final branding = OrganizationPayslipBranding.resolve(
      organization: organization,
      employee: employee,
    );

    final pdf = pw.Document(
      title: 'Payslip_${record.employeeName}_${record.month}',
      author: branding.orgName,
    );

    // Load exact organization logo image
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = branding.isTecEngineering
          ? await PayslipLogoAssets.getTecEngineeringLogoBytes()
          : await PayslipLogoAssets.getTechnologiesLogoBytes();

      if (logoBytes.isNotEmpty) {
        logoImage = pw.MemoryImage(logoBytes);
      }
    } catch (_) {}

    // Resolve employee details (prefer snapshot in PayrollRecord)
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

    final daysWorked = record.presentDays > 0 ? '${record.presentDays}' : '-';

    // Statutory & Bank Details (prefer snapshot in PayrollRecord)
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

    // Master CTC Component Calculations
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

    // Monthly Earnings & Deductions
    final grossSalary = record.basicPay +
        record.hra +
        record.educationAllowance +
        record.specialAllowance +
        record.travelAllowance +
        record.otherAllowance +
        record.incentive +
        record.othersEarning +
        record.cumulativeIncentive +
        record.bonus +
        record.ot;

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
    final netInWords = CurrencyWordsHelper.formatAmountInWords(netSalary);

    final darkSlate = PdfColor.fromHex('414A51');
    final borderGrey = PdfColor.fromHex('B0B7C3');
    final tableHeaderBg = PdfColor.fromHex('F3F5F7');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: darkSlate, width: 1.0),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. TOP HEADER (Exact Logo Image on Left, Center Email, Right TAN Number)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: darkSlate, width: 0.8)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Left: Exact Logo Image
                      if (logoImage != null)
                        pw.Container(
                          height: 42,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.Text(
                          branding.orgName,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: darkSlate,
                          ),
                        ),

                      // Center: Email
                      pw.Text(
                        'EMAIL : ${branding.email.toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: darkSlate,
                        ),
                      ),

                      // Right: TAN Number
                      pw.Text(
                        branding.tanNumber.isNotEmpty
                            ? 'TAN No: ${branding.tanNumber}'
                            : '',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: darkSlate,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. TWO COLUMN DETAILS (EMPLOYEE DETAILS + STATUTORY & BANK DETAILS)
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: darkSlate, width: 0.8)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN: Period & Employee Details
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: darkSlate, width: 0.8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _pdfSectionHeader('PAYSLIP PERIOD'),
                              pw.SizedBox(height: 2),
                              _pdfDetailRow('Month-Year', record.month),
                              pw.SizedBox(height: 6),
                              _pdfSectionHeader('EMPLOYEE DETAILS'),
                              pw.SizedBox(height: 2),
                              _pdfDetailRow('Employee no', displayEmpId),
                              _pdfDetailRow('Employee Name', displayName),
                              _pdfDetailRow('Designation', displayDesignation),
                              _pdfDetailRow('Department', displayDepartment),
                              _pdfDetailRow('Email ID', displayEmail),
                              _pdfDetailRow('Days Worked In Month', daysWorked),
                            ],
                          ),
                        ),
                      ),

                      // RIGHT COLUMN: Statutory & Bank Details
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _pdfSectionHeader('STATUTORY DETAILS'),
                              pw.SizedBox(height: 2),
                              _pdfDetailRow('PAN Number', panNo),
                              _pdfDetailRow('PF', pfNo),
                              _pdfDetailRow('ESI Number', esiNo),
                              pw.SizedBox(height: 6),
                              _pdfSectionHeader('BANK DETAILS'),
                              pw.SizedBox(height: 2),
                              _pdfDetailRow('Bank Name', bankName),
                              _pdfDetailRow('Bank Acct no', bankAcct),
                              _pdfDetailRow('Branch', branch),
                              _pdfDetailRow('IFSC/Swift Code', ifsc),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. SALARY BREAKDOWN TABLE (3 Columns: Monthly Salary, Earning, Deductions)
                pw.Container(
                  child: pw.Table(
                    border: pw.TableBorder(
                      verticalInside: pw.BorderSide(color: borderGrey, width: 0.6),
                      horizontalInside: pw.BorderSide(color: borderGrey, width: 0.4),
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.0),
                      1: const pw.FlexColumnWidth(1.0),
                      2: const pw.FlexColumnWidth(1.0),
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: tableHeaderBg),
                        children: [
                          _pdfTableHeaderCell('Monthly Salary', 'INR'),
                          _pdfTableHeaderCell('Earning', 'INR'),
                          _pdfTableHeaderCell('Deductions', 'INR'),
                        ],
                      ),
                      // Sub-header Row: Standard Components / Statutory
                      pw.TableRow(
                        children: [
                          _pdfSubHeaderCell('Standard Components'),
                          _pdfSubHeaderCell('Standard Components'),
                          _pdfSubHeaderCell('Statutory'),
                        ],
                      ),
                      // Row 1: Basic
                      pw.TableRow(
                        children: [
                          _pdfTableRowItem('Basic', _formatMoney(standardBasic)),
                          _pdfTableRowItem('Basic', _formatMoney(record.basicPay)),
                          _pdfTableRowItem('PF', _formatMoney(record.pf)),
                        ],
                      ),
                      // Row 2: HRA / TDS
                      pw.TableRow(
                        children: [
                          _pdfTableRowItem('HRA', _formatMoney(standardHra)),
                          _pdfTableRowItem('HRA', _formatMoney(record.hra)),
                          _pdfTableRowItem('TDS', _formatMoney(record.tax)),
                        ],
                      ),
                      // Row 3: Educational Allowance / ESI
                      pw.TableRow(
                        children: [
                          _pdfTableRowItem('Educational Allowance', _formatMoney(standardEdu)),
                          _pdfTableRowItem('Educational Allowance', _formatMoney(record.educationAllowance)),
                          _pdfTableRowItem('ESI', _formatMoney(record.esi)),
                        ],
                      ),
                      // Row 4: Special Allowance / Sub-header Other Deductions
                      pw.TableRow(
                        children: [
                          _pdfTableRowItem('Special Allowance', _formatMoney(standardSpecial)),
                          _pdfTableRowItem('Special Allowance', _formatMoney(record.specialAllowance)),
                          _pdfSubHeaderCell('Other'),
                        ],
                      ),
                      // Row 5: Additional Components Header / LOP
                      pw.TableRow(
                        children: [
                          _pdfEmptyCell(),
                          _pdfSubHeaderCell('Additional Components'),
                          _pdfTableRowItem('LOP', _formatMoney(record.lop)),
                        ],
                      ),
                      // Row 6: Incentive / Company Loan
                      pw.TableRow(
                        children: [
                          _pdfEmptyCell(),
                          _pdfTableRowItem('Incentive', _formatMoney(record.incentive)),
                          _pdfTableRowItem('Company loan', _formatMoney(record.companyLoan)),
                        ],
                      ),
                      // Row 7: Carry Forward / Salary Advance
                      pw.TableRow(
                        children: [
                          _pdfEmptyCell(),
                          _pdfTableRowItem('Carry forward', record.carryForward.isNotEmpty ? record.carryForward : '-'),
                          _pdfTableRowItem('Salary Advance', _formatMoney(record.salaryAdvance)),
                        ],
                      ),
                      // Row 8: Others / Others Deduction
                      pw.TableRow(
                        children: [
                          _pdfEmptyCell(),
                          _pdfTableRowItem('Others', _formatMoney(record.othersEarning)),
                          _pdfTableRowItem('Others', _formatMoney(record.othersDeduction)),
                        ],
                      ),
                      // Row 9: Cumulative Incentive / Staff Welfare
                      pw.TableRow(
                        children: [
                          _pdfEmptyCell(),
                          _pdfTableRowItem('Cumulative Incentive', _formatMoney(record.cumulativeIncentive)),
                          _pdfTableRowItem('Staff welfare contribution', _formatMoney(record.staffWelfareContribution)),
                        ],
                      ),
                    ],
                  ),
                ),

                // 4. TOTALS ROW (Standard Salary, Gross Salary, Deduction, Net Salary)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: tableHeaderBg,
                    border: pw.Border(
                      top: pw.BorderSide(color: darkSlate, width: 0.8),
                      bottom: pw.BorderSide(color: darkSlate, width: 0.8),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Standard Salary', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                            pw.Text(_formatMoney(standardSalary), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 14),
                      pw.Expanded(
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Gross Salary', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                            pw.Text(_formatMoney(grossSalary), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 14),
                      pw.Expanded(
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Deduction', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                            pw.Text(_formatMoney(deductions), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 14),
                      pw.Expanded(
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Net Salary', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                            pw.Text(_formatMoney(netSalary), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. IN WORDS
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: darkSlate, width: 0.8)),
                  ),
                  child: pw.Text(
                    'In words: $netInWords',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: darkSlate,
                    ),
                  ),
                ),

                // 6. SYSTEM GENERATED FOOTER NOTE
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'This Is A System Generated Payslip Hence Needs No Signature',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey700,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- Helper Widgets for PDF Building ---
  static pw.Widget _pdfSectionHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('414A51'),
        ),
      ),
    );
  }

  static pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.grey800),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isNotEmpty ? value : '-',
              style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfTableHeaderCell(String title, String currency) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('414A51')),
          ),
          pw.Text(
            currency,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('414A51')),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfSubHeaderCell(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('414A51')),
      ),
    );
  }

  static pw.Widget _pdfTableRowItem(String label, String amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey900),
          ),
          pw.Text(
            amount,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.black),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfEmptyCell() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      child: pw.Text('', style: const pw.TextStyle(fontSize: 7)),
    );
  }
}
