import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../employee/domain/employee.dart';
import '../../organization/domain/organization.dart';
import '../domain/payroll.dart';
import '../utils/currency_words_helper.dart';

class PayslipPdfGenerator {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  /// Generates the binary PDF document for a payslip.
  static Future<Uint8List> generatePayslipPdf({
    required PayrollRecord record,
    Employee? employee,
    Organization? organization,
  }) async {
    final pdf = pw.Document(
      title: 'Payslip_${record.employeeName}_${record.month}',
      author: 'IGreen Technologies',
    );

    // Load default asset logo if available
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/reference_logo_base.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      // Fallback without logo image
    }

    // Resolve employee details (prefer record snapshot, then employee model)
    final displayName = record.employeeName.isNotEmpty
        ? record.employeeName
        : (employee?.fullName.isNotEmpty == true ? employee!.fullName : 'Employee');

    final displayEmpId = employee?.employeeId.isNotEmpty == true
        ? employee!.employeeId
        : (record.employeeId > 0 ? 'EMP-${record.employeeId.toString().padLeft(4, '0')}' : '-');

    final displayDesignation = record.designation.isNotEmpty
        ? record.designation
        : (employee?.designation.isNotEmpty == true ? employee!.designation : '-');

    final displayDepartment = record.department.isNotEmpty
        ? record.department
        : (employee?.department.isNotEmpty == true ? employee!.department : '-');

    final displayEmail = record.emailId.isNotEmpty
        ? record.emailId
        : (employee?.emailAddress.isNotEmpty == true ? employee!.emailAddress : '-');

    final daysWorked = '${record.presentDays}';

    // Statutory & Bank Details (prefer record snapshot, then employee model)
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

    // Organization details
    final orgName = organization?.name.isNotEmpty == true
        ? organization!.name
        : (employee?.organizationName.isNotEmpty == true ? employee!.organizationName : 'I-GREEN TECHNOLOGIES');
    final orgEmail = organization?.emailAddress ?? '';
    final orgTan = organization?.tanNumber ?? '';

    // Calculations
    final standardBasic = employee != null && employee.salaryBasic > 0 ? employee.salaryBasic : record.basicPay;
    final standardHra = employee != null && employee.salaryHra > 0 ? employee.salaryHra : record.hra;
    final standardEdu = employee != null && employee.salaryEducationAllowance > 0
        ? employee.salaryEducationAllowance
        : record.educationAllowance;
    final standardSpecial = employee != null && employee.salarySpecialAllowance > 0
        ? employee.salarySpecialAllowance
        : record.specialAllowance;
    final standardSalary = employee != null && employee.salaryTotalCtc > 0
        ? employee.salaryTotalCtc
        : (standardBasic + standardHra + standardEdu + standardSpecial);

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

    final totalDays = record.totalWorkingDays > 0
        ? record.totalWorkingDays
        : (record.presentDays + record.lateDays + record.absentDays + record.leaveDays);

    final primaryGreen = PdfColor.fromHex('9CC70A');
    final darkSlate = PdfColor.fromHex('414A51');
    final borderGrey = PdfColor.fromHex('D0D5DD');
    final lightBg = PdfColor.fromHex('F8F9FA');
    final tableHeaderBg = PdfColor.fromHex('EEF2F6');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: darkSlate, width: 1.2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. HEADER SECTION
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border(bottom: pw.BorderSide(color: darkSlate, width: 1)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Organization Branding
                      pw.Row(
                        children: [
                          if (logoImage != null)
                            pw.Container(
                              width: 38,
                              height: 38,
                              margin: const pw.EdgeInsets.only(right: 10),
                              child: pw.Image(logoImage),
                            ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                orgName.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: darkSlate,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'PAYSLIP',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryGreen,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Organization Details on Right
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          if (orgEmail.isNotEmpty)
                            pw.Text(
                              'Email: $orgEmail',
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                            ),
                          if (orgTan.isNotEmpty)
                            pw.Text(
                              'TAN: $orgTan',
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                            ),
                          pw.Text(
                            'Period: ${record.month}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: darkSlate,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. EMPLOYEE / STATUTORY / BANK DETAILS (Two Column Grid)
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: darkSlate, width: 1)),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // LEFT: EMPLOYEE DETAILS
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: borderGrey, width: 0.8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Container(
                                width: double.infinity,
                                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                color: lightBg,
                                child: pw.Text(
                                  'EMPLOYEE DETAILS',
                                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkSlate),
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              _pdfFieldRow('Employee No', displayEmpId),
                              _pdfFieldRow('Employee Name', displayName),
                              _pdfFieldRow('Designation', displayDesignation),
                              _pdfFieldRow('Department', displayDepartment),
                              _pdfFieldRow('Email ID', displayEmail),
                              _pdfFieldRow('Days Worked in Month', daysWorked),
                            ],
                          ),
                        ),
                      ),
                      // RIGHT: STATUTORY & BANK DETAILS
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Container(
                                width: double.infinity,
                                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                color: lightBg,
                                child: pw.Text(
                                  'STATUTORY & BANK DETAILS',
                                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkSlate),
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              _pdfFieldRow('PAN Number', panNo),
                              _pdfFieldRow('PF / UAN', pfNo),
                              _pdfFieldRow('ESI Number', esiNo),
                              _pdfFieldRow('Bank Name', bankName),
                              _pdfFieldRow('Bank Account No', bankAcct),
                              _pdfFieldRow('Branch', branch),
                              _pdfFieldRow('IFSC Code', ifsc),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. ATTENDANCE METRICS ROW
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: tableHeaderBg,
                    border: pw.Border(bottom: pw.BorderSide(color: darkSlate, width: 1)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _pdfAttendanceMetric('Present Days', '${record.presentDays}'),
                      _pdfAttendanceMetric('Late Days', '${record.lateDays}'),
                      _pdfAttendanceMetric('Absent (LOP) Days', '${record.absentDays}'),
                      _pdfAttendanceMetric('Leave Days', '${record.leaveDays}'),
                      _pdfAttendanceMetric('Total Working Days', '$totalDays'),
                    ],
                  ),
                ),

                // 4. SALARY BREAKDOWN TABLE (3 COLUMNS)
                pw.Container(
                  child: pw.Table(
                    border: pw.TableBorder(
                      verticalInside: pw.BorderSide(color: borderGrey, width: 0.8),
                      horizontalInside: pw.BorderSide(color: borderGrey, width: 0.5),
                    ),
                    children: [
                      // Table Header
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: tableHeaderBg),
                        children: [
                          _pdfTableHeaderCell('MONTHLY SALARY (CTC)'),
                          _pdfTableHeaderCell('EARNINGS'),
                          _pdfTableHeaderCell('DEDUCTIONS'),
                        ],
                      ),
                      // Row 1: Basic
                      pw.TableRow(
                        children: [
                          _pdfSalaryItemCell('Basic Pay', _currencyFormat.format(standardBasic)),
                          _pdfSalaryItemCell('Basic Pay', _currencyFormat.format(record.basicPay)),
                          _pdfSalaryItemCell('PF (Statutory)', _currencyFormat.format(record.pf)),
                        ],
                      ),
                      // Row 2: HRA
                      pw.TableRow(
                        children: [
                          _pdfSalaryItemCell('HRA', _currencyFormat.format(standardHra)),
                          _pdfSalaryItemCell('HRA', _currencyFormat.format(record.hra)),
                          _pdfSalaryItemCell('TDS / Tax', _currencyFormat.format(record.tax)),
                        ],
                      ),
                      // Row 3: Educational Allowance
                      pw.TableRow(
                        children: [
                          _pdfSalaryItemCell('Educational Allowance', _currencyFormat.format(standardEdu)),
                          _pdfSalaryItemCell('Educational Allowance', _currencyFormat.format(record.educationAllowance)),
                          _pdfSalaryItemCell('ESI', _currencyFormat.format(record.esi)),
                        ],
                      ),
                      // Row 4: Special Allowance
                      pw.TableRow(
                        children: [
                          _pdfSalaryItemCell('Special Allowance', _currencyFormat.format(standardSpecial)),
                          _pdfSalaryItemCell('Special Allowance', _currencyFormat.format(record.specialAllowance)),
                          _pdfSalaryItemCell('LOP Deduction', _currencyFormat.format(record.lop)),
                        ],
                      ),
                      // Row 5: Additional earnings & Other Deductions
                      pw.TableRow(
                        children: [
                          _pdfSalaryItemCell('-', '-'),
                          _pdfSalaryItemCell('Incentive', _currencyFormat.format(record.incentive)),
                          _pdfSalaryItemCell('Company Loan', _currencyFormat.format(record.companyLoan)),
                        ],
                      ),
                      // Row 6: Carry Forward / Advance
                      pw.TableRow(
                        children: [
                          _pdfSalaryItemCell('-', '-'),
                          _pdfSalaryItemCell('Carry Forward', record.carryForward.isNotEmpty ? record.carryForward : '-'),
                          _pdfSalaryItemCell('Salary Advance', _currencyFormat.format(record.salaryAdvance)),
                        ],
                      ),
                      // Row 7: Others / Staff Welfare
                      pw.TableRow(
                        children: [
                          _pdfSalaryItemCell('-', '-'),
                          _pdfSalaryItemCell('Others', _currencyFormat.format(record.othersEarning)),
                          _pdfSalaryItemCell('Staff Welfare', _currencyFormat.format(record.staffWelfareContribution)),
                        ],
                      ),
                      // Row 8: Cumulative Incentive / Others Deduction
                      pw.TableRow(
                        children: [
                          _pdfSalaryItemCell('-', '-'),
                          _pdfSalaryItemCell('Cumulative Incentive', _currencyFormat.format(record.cumulativeIncentive)),
                          _pdfSalaryItemCell('Other Deductions', _currencyFormat.format(record.othersDeduction)),
                        ],
                      ),
                      // Totals Row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: lightBg),
                        children: [
                          _pdfTotalCell('Standard Salary', _currencyFormat.format(standardSalary)),
                          _pdfTotalCell('Gross Salary', _currencyFormat.format(grossSalary)),
                          _pdfTotalCell('Total Deductions', _currencyFormat.format(deductions)),
                        ],
                      ),
                    ],
                  ),
                ),

                // 5. NET SALARY & WORDS BANNER
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border(
                      top: pw.BorderSide(color: darkSlate, width: 1),
                      bottom: pw.BorderSide(color: darkSlate, width: 1),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'NET SALARY',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: darkSlate,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'In words: $netInWords Rupees Only',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontStyle: pw.FontStyle.italic,
                                color: PdfColors.grey800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: pw.BoxDecoration(
                          color: tableHeaderBg,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: primaryGreen, width: 1),
                        ),
                        child: pw.Text(
                          _currencyFormat.format(netSalary),
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: darkSlate,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Spacer
                pw.Spacer(),

                // 6. SYSTEM GENERATED FOOTER
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    border: pw.Border(top: pw.BorderSide(color: darkSlate, width: 1)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'This Is A System Generated Payslip Hence Needs No Signature',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: darkSlate,
                      ),
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

  static pw.Widget _pdfFieldRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 95,
            child: pw.Text(
              '$label:',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isNotEmpty ? value : '-',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfAttendanceMetric(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
        ),
      ],
    );
  }

  static pw.Widget _pdfTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('414A51')),
      ),
    );
  }

  static pw.Widget _pdfSalaryItemCell(String label, String amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
          pw.Text(amount, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
    );
  }

  static pw.Widget _pdfTotalCell(String label, String amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.Text(amount, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
    );
  }
}
