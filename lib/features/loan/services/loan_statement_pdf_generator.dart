import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../employee/domain/employee.dart';
import '../../organization/domain/organization.dart';
import '../../payroll/domain/payroll.dart';
import '../domain/employee_loan.dart';

class LoanStatementPdfGenerator {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  /// Generates the binary PDF document for an Employee Loan Statement / Repayment Schedule.
  static Future<Uint8List> generateStatementPdf({
    required EmployeeLoan loan,
    Employee? employee,
    Organization? organization,
    List<PayrollRecord> payrolls = const [],
    PayrollSettings? settings,
  }) async {
    final pdf = pw.Document(
      title: 'Loan_Statement_${loan.loanId}_${loan.employeeName}',
      author: 'IGreen Technologies',
    );

    final pStart = settings?.payrollStartDay ?? 20;
    final pEnd = settings?.payrollEndDay ?? 20;

    // Load default asset logo if available
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/reference_logo_base.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      // Fallback without logo image
    }

    final orgName = organization?.name.isNotEmpty == true
        ? organization!.name
        : (employee?.organizationName.isNotEmpty == true
            ? employee!.organizationName
            : 'I-GREEN TECHNOLOGIES');

    final empName = loan.employeeName.isNotEmpty
        ? loan.employeeName
        : (employee?.fullName.isNotEmpty == true ? employee!.fullName : 'Employee');

    final empId = loan.employeeCustomId.isNotEmpty
        ? loan.employeeCustomId
        : (employee?.employeeId.isNotEmpty == true ? employee!.employeeId : '-');

    final department = loan.department.isNotEmpty
        ? loan.department
        : (employee?.department.isNotEmpty == true ? employee!.department : '-');

    final designation = loan.designation.isNotEmpty
        ? loan.designation
        : (employee?.designation.isNotEmpty == true ? employee!.designation : '-');

    final totalInterest = loan.interestRate > 0
        ? loan.calculatedTotalInterestWithDays(payrollStartDay: pStart, payrollEndDay: pEnd)
        : (loan.totalRepayableAmount - loan.loanAmount).clamp(0.0, double.infinity);

    final totalRepayable = loan.interestRate > 0
        ? loan.calculatedTotalRepayableWithDays(payrollStartDay: pStart, payrollEndDay: pEnd)
        : (loan.totalRepayableAmount > 0 ? loan.totalRepayableAmount : loan.loanAmount);

    final scheduleMonths = loan.scheduleMonths;
    final statementDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

    // Color definitions
    const primaryColor = PdfColor.fromInt(0xFF9CC70A);
    const darkHeaderColor = PdfColor.fromInt(0xFF414A51);
    const lightBgColor = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // ── HEADER SECTION ──────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: primaryColor, width: 2),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 55,
                      height: 55,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          orgName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: darkHeaderColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'EMPLOYEE LOAN STATEMENT & REPAYMENT SCHEDULE',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: lightBgColor,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: borderColor),
                        ),
                        child: pw.Text(
                          'Loan ID: ${loan.loanId}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: darkHeaderColor,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Date: $statementDate',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // ── EMPLOYEE & LOAN DETAILS GRID ─────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: Employee Info
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightBgColor,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'EMPLOYEE INFORMATION',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        _buildInfoRow('Employee Name:', empName),
                        _buildInfoRow('Employee ID:', empId),
                        _buildInfoRow('Department:', department),
                        _buildInfoRow('Designation:', designation),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                // Right: Loan Info
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightBgColor,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'LOAN SPECIFICATIONS',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        _buildInfoRow('Loan Type:', loan.loanType),
                        _buildInfoRow('Tenure:', '${loan.installments} Months'),
                        _buildInfoRow('Disbursement Date:', loan.disbursementDate.isNotEmpty ? loan.disbursementDate : '-'),
                        _buildInfoRow('Status:', loan.status),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // ── FINANCIAL SUMMARY METRICS ─────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderColor, width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricBlock('PRINCIPAL AMOUNT', _currencyFormat.format(loan.loanAmount), darkHeaderColor),
                  _buildMetricBlock('INTEREST (${loan.interestRate}%)', _currencyFormat.format(totalInterest), PdfColors.orange800),
                  _buildMetricBlock('TOTAL REPAYABLE', _currencyFormat.format(totalRepayable), darkHeaderColor),
                  _buildMetricBlock('TOTAL PAID', _currencyFormat.format(loan.totalPaid), primaryColor),
                  _buildMetricBlock('OUTSTANDING', _currencyFormat.format(loan.actualRemainingBalance), PdfColors.red800),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── REPAYMENT SCHEDULE TABLE ─────────────────────────────────
            pw.Text(
              'REPAYMENT SCHEDULE & DEDUCTION TIMELINE',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: darkHeaderColor,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 8),

            if (scheduleMonths.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                alignment: pw.Alignment.center,
                child: pw.Text('No repayment schedule defined for this loan.', style: const pw.TextStyle(fontSize: 10)),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: darkHeaderColor),
                    children: [
                      _buildTableHeaderCell('#', align: pw.TextAlign.center),
                      _buildTableHeaderCell('Month'),
                      _buildTableHeaderCell('Principal', align: pw.TextAlign.right),
                      _buildTableHeaderCell('Interest (${loan.interestRate}%)', align: pw.TextAlign.right),
                      _buildTableHeaderCell('Total EMI', align: pw.TextAlign.right),
                      _buildTableHeaderCell('Paid', align: pw.TextAlign.right),
                      _buildTableHeaderCell('Balance', align: pw.TextAlign.right),
                      _buildTableHeaderCell('Status', align: pw.TextAlign.center),
                    ],
                  ),
                  // Table Rows
                  ...List<pw.TableRow>.generate(scheduleMonths.length, (index) {
                    final month = scheduleMonths[index];
                    final monthlyPrincipal = loan.monthlyPrincipal;
                    final monthInterest = loan.interestForInstallment(index, payrollStartDay: pStart, payrollEndDay: pEnd);
                    final monthEmi = loan.emiForInstallment(index, payrollStartDay: pStart, payrollEndDay: pEnd);
                    final endingPrincipal = loan.endPrincipalForInstallment(index);

                    // Check if ledger repayment or payroll paid record matches
                    final ledgerRepayment = loan.repayments.where(
                      (r) => r.month.trim().toLowerCase() == month.trim().toLowerCase(),
                    ).firstOrNull;

                    final matchingPayroll = payrolls.where((p) =>
                        p.employeeId == loan.employeeId &&
                        p.month.trim().toLowerCase() == month.trim().toLowerCase() &&
                        p.status.toLowerCase() == 'paid' &&
                        p.companyLoan > 0).firstOrNull;

                    final isPaid = ledgerRepayment != null || matchingPayroll != null || index < loan.paidInstallments;
                    final paidAmount = isPaid ? (ledgerRepayment?.amount ?? monthEmi) : 0.0;
                    final rowBgColor = index % 2 == 0 ? PdfColors.white : lightBgColor;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowBgColor),
                      children: [
                        _buildTableCell('${index + 1}', align: pw.TextAlign.center),
                        _buildTableCell(month, isBold: true),
                        _buildTableCell(_currencyFormat.format(monthlyPrincipal), align: pw.TextAlign.right),
                        _buildTableCell(_currencyFormat.format(monthInterest), align: pw.TextAlign.right),
                        _buildTableCell(_currencyFormat.format(monthEmi), align: pw.TextAlign.right, isBold: true),
                        _buildTableCell(_currencyFormat.format(paidAmount), align: pw.TextAlign.right, color: isPaid ? primaryColor : PdfColors.grey600),
                        _buildTableCell(_currencyFormat.format(endingPrincipal), align: pw.TextAlign.right),
                        _buildTableCell(
                          isPaid ? 'PAID' : (loan.status == 'Active' && index == loan.paidInstallments ? 'UPCOMING' : 'SCHEDULED'),
                          align: pw.TextAlign.center,
                          isBold: true,
                          color: isPaid ? primaryColor : (loan.status == 'Active' && index == loan.paidInstallments ? PdfColors.orange800 : PdfColors.grey700),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 24),

            // ── FOOTER & SIGNATORY SECTION ────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 14),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Important Terms & Note:',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkHeaderColor),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '1. EMI deductions are processed automatically through monthly salary payroll.',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        '2. Reducing balance interest is computed on the outstanding principal balance.',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        '3. This is an official computer-generated statement issued by I-Green Technologies ERP.',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 140,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 4),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'Authorized Signatory',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkHeaderColor),
                        ),
                      ),
                      pw.Text(
                        orgName,
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricBlock(String label, String value, PdfColor valueColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }
}
