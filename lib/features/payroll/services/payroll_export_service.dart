import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../employee/services/offer_letter_save_stub.dart'
    if (dart.library.html) '../../employee/services/offer_letter_save_web.dart'
    if (dart.library.io) '../../employee/services/offer_letter_save_io.dart';
import '../domain/payroll_report_dataset.dart';

class PayrollExportService {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  /// 1. COPY to Clipboard in formatted Tab-Separated Values (TSV)
  static Future<bool> copyToClipboard(PayrollReportDataset dataset) async {
    final buffer = StringBuffer();

    // Headers
    buffer.writeln(PayrollReportDataset.columnHeaders.join('\t'));

    // Rows
    for (final row in dataset.rows) {
      final cells = dataset.rowToCells(row);
      buffer.writeln(cells.join('\t'));
    }

    // Grand Totals Summary Row
    buffer.write('GRAND TOTAL\t\t\t\t\t\t\t\t\t\t\t\t'); // Skip to earnings
    buffer.write('\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t');
    buffer.write('${dataset.grandTotalGross.toStringAsFixed(2)}\t');
    buffer.write('${dataset.grandTotalDeductions.toStringAsFixed(2)}\t');
    buffer.write('${dataset.grandTotalNet.toStringAsFixed(2)}\t');
    buffer.writeln();

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    return true;
  }

  /// 2. CSV Export
  static Future<void> exportCsv(BuildContext context, PayrollReportDataset dataset) async {
    final buffer = StringBuffer();

    // CSV Headers
    buffer.writeln(PayrollReportDataset.columnHeaders.map(_escapeCsv).join(','));

    // Rows
    for (final row in dataset.rows) {
      final cells = dataset.rowToCells(row);
      buffer.writeln(cells.map((c) => _escapeCsv(c.toString())).join(','));
    }

    final bytes = utf8.encode(buffer.toString());
    final cleanOrg = dataset.organizationName.replaceAll(RegExp(r'[^\w\-_]'), '_');
    final cleanDept = dataset.departmentName.replaceAll(RegExp(r'[^\w\-_]'), '_');
    final cleanMonth = dataset.payrollMonth.replaceAll(RegExp(r'[^\w\-_]'), '_');
    final fileName = 'Payroll_${cleanOrg}_${cleanDept}_$cleanMonth.csv';

    await saveAndDownloadOfferLetter(
      context: context,
      bytes: bytes,
      fileName: fileName,
      docTitle: 'Payroll CSV Export',
    );
  }

  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// 3. Excel (.xlsx) Export using OpenXML Zip Archive
  static Future<void> exportExcel(BuildContext context, PayrollReportDataset dataset) async {
    final xlsxBytes = _buildXlsxArchive(dataset);
    final cleanOrg = dataset.organizationName.replaceAll(RegExp(r'[^\w\-_]'), '_');
    final cleanDept = dataset.departmentName.replaceAll(RegExp(r'[^\w\-_]'), '_');
    final cleanMonth = dataset.payrollMonth.replaceAll(RegExp(r'[^\w\-_]'), '_');
    final fileName = 'Payroll_${cleanOrg}_${cleanDept}_$cleanMonth.xlsx';

    await saveAndDownloadOfferLetter(
      context: context,
      bytes: xlsxBytes,
      fileName: fileName,
      docTitle: 'Payroll Excel Export',
    );
  }

  /// 4. PDF Export
  static Future<void> exportPdf(BuildContext context, PayrollReportDataset dataset) async {
    final pdfBytes = await generatePdfBytes(dataset);
    final cleanOrg = dataset.organizationName.replaceAll(RegExp(r'[^\w\-_]'), '_');
    final cleanDept = dataset.departmentName.replaceAll(RegExp(r'[^\w\-_]'), '_');
    final cleanMonth = dataset.payrollMonth.replaceAll(RegExp(r'[^\w\-_]'), '_');
    final fileName = 'Payroll_Report_${cleanOrg}_${cleanDept}_$cleanMonth.pdf';

    await saveAndDownloadOfferLetter(
      context: context,
      bytes: pdfBytes,
      fileName: fileName,
      docTitle: 'Payroll PDF Report',
    );
  }

  /// 5. PRINT Export (Generates print-ready PDF and initiates download/save for printing)
  static Future<void> printReport(BuildContext context, PayrollReportDataset dataset) async {
    await exportPdf(context, dataset);
  }

  /// Generates the landscaped multi-page PDF document for the unified report.
  static Future<Uint8List> generatePdfBytes(PayrollReportDataset dataset) async {
    final pdf = pw.Document(
      title: 'Payroll Report - ${dataset.organizationName} - ${dataset.payrollMonth}',
      author: 'I-Green Technology',
    );

    // Landscape orientation with minimal margins for wide payroll tables
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (pw.Context context) => _buildPdfHeader(dataset),
        footer: (pw.Context context) => _buildPdfFooter(context, dataset),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          _buildPdfTable(dataset),
          pw.SizedBox(height: 14),
          _buildPdfSummaryBox(dataset),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfHeader(PayrollReportDataset dataset) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                dataset.organizationName.toUpperCase(),
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Department: ${dataset.departmentName}  |  Payroll Month: ${dataset.payrollMonth}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PAYROLL REPORT',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Total Employees: ${dataset.totalEmployees}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context, PayrollReportDataset dataset) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())} • Confidential',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfTable(PayrollReportDataset dataset) {
    final headers = [
      'Emp ID',
      'Employee Name',
      'Attn (P/L/LOP)',
      'Basic',
      'HRA',
      'Allowances',
      'Incentive/OT',
      'Gross',
      'PF/ESI/TDS',
      'Loan/Adv/LOP',
      'Total Ded.',
      'Net Salary',
      'Status',
    ];

    final tableRows = <pw.TableRow>[
      // Header Row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF414A51)),
        children: headers.map((h) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            h,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          ),
        )).toList(),
      ),
    ];

    for (int i = 0; i < dataset.rows.length; i++) {
      final r = dataset.rows[i];
      final isEven = i % 2 == 0;
      final rowBg = isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF9FAFB);

      final allowances = r.educationAllowance + r.specialAllowance + r.travelAllowance + r.otherAllowance;
      final additional = r.incentive + r.othersEarning + r.bonus + r.ot;
      final statutory = r.pf + r.tax + r.esi;
      final otherDeds = r.companyLoan + r.salaryAdvance + r.othersDeduction + r.staffWelfare + r.lopDeduction;

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: rowBg),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(r.employeeId, style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(r.employeeName, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text('${r.presentDays}/${r.leaveDays}/${r.lopHours.toStringAsFixed(0)}h', style: const pw.TextStyle(fontSize: 7)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(r.basic.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(r.hra.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(allowances.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(additional.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(r.grossSalary.toStringAsFixed(0), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(statutory.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(otherDeds.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(r.totalDeductions.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.red800)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(r.netSalary.toStringAsFixed(0), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(r.status, style: const pw.TextStyle(fontSize: 7)),
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(48), // Emp ID
        1: const pw.FlexColumnWidth(2.0), // Name
        2: const pw.FixedColumnWidth(48), // Attn
        3: const pw.FixedColumnWidth(40), // Basic
        4: const pw.FixedColumnWidth(36), // HRA
        5: const pw.FixedColumnWidth(44), // Allowances
        6: const pw.FixedColumnWidth(44), // Incentive/OT
        7: const pw.FixedColumnWidth(48), // Gross
        8: const pw.FixedColumnWidth(44), // Stat Ded
        9: const pw.FixedColumnWidth(48), // Other Ded
        10: const pw.FixedColumnWidth(46), // Total Ded
        11: const pw.FixedColumnWidth(52), // Net Salary
        12: const pw.FixedColumnWidth(42), // Status
      },
      children: tableRows,
    );
  }

  static pw.Widget _buildPdfSummaryBox(PayrollReportDataset dataset) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF1F5F9),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Text('Employees: ${dataset.totalEmployees}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text('Total Gross: ${_currencyFormat.format(dataset.grandTotalGross)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text('Total Deductions: ${_currencyFormat.format(dataset.grandTotalDeductions)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
          pw.Text('Total Net Salary: ${_currencyFormat.format(dataset.grandTotalNet)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
        ],
      ),
    );
  }

  /// Builds a valid OpenXML .xlsx document from the report dataset with Payroll Data and Instructions sheets.
  static List<int> _buildXlsxArchive(PayrollReportDataset dataset) {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypes.length, utf8.encode(contentTypes)));

    // 2. _rels/.rels
    const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rootRels.length, utf8.encode(rootRels)));

    // 3. xl/_rels/workbook.xml.rels
    const wbRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels', wbRels.length, utf8.encode(wbRels)));

    // 4. xl/workbook.xml
    const workbook = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Payroll Data" sheetId="1" r:id="rId1"/>
    <sheet name="Instructions" sheetId="2" r:id="rId3"/>
  </sheets>
</workbook>''';
    archive.addFile(ArchiveFile('xl/workbook.xml', workbook.length, utf8.encode(workbook)));

    // 5. xl/styles.xml
    const styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><sz val="10"/><name val="Calibri"/></font>
    <font><b/><sz val="10"/><name val="Calibri"/></font>
  </fonts>
  <fills count="2">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
  </fills>
  <borders count="1">
    <border><left/><right/><top/><bottom/></border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="2">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0"/>
  </cellXfs>
</styleSheet>''';
    archive.addFile(ArchiveFile('xl/styles.xml', styles.length, utf8.encode(styles)));

    // 6. xl/worksheets/sheet1.xml (Payroll Data)
    final sheet1Buffer = StringBuffer();
    sheet1Buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sheet1Buffer.writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    sheet1Buffer.writeln('  <sheetData>');

    // Row 1: Header
    sheet1Buffer.writeln('    <row r="1">');
    final headers = PayrollReportDataset.columnHeaders;
    for (int col = 0; col < headers.length; col++) {
      final colRef = _indexToColLetter(col) + '1';
      final text = _escapeXml(headers[col]);
      sheet1Buffer.writeln('      <c r="$colRef" t="inlineStr" s="1"><is><t>$text</t></is></c>');
    }
    sheet1Buffer.writeln('    </row>');

    // Data rows
    for (int r = 0; r < dataset.rows.length; r++) {
      final rowNum = r + 2;
      final cells = dataset.rowToCells(dataset.rows[r]);
      sheet1Buffer.writeln('    <row r="$rowNum">');
      for (int c = 0; c < cells.length; c++) {
        final colRef = _indexToColLetter(c) + rowNum.toString();
        final val = cells[c];
        final numVal = double.tryParse(val.toString());
        if (numVal != null && c >= 5 && c <= 32) {
          sheet1Buffer.writeln('      <c r="$colRef"><v>$numVal</v></c>');
        } else {
          final text = _escapeXml(val.toString());
          sheet1Buffer.writeln('      <c r="$colRef" t="inlineStr"><is><t>$text</t></is></c>');
        }
      }
      sheet1Buffer.writeln('    </row>');
    }

    sheet1Buffer.writeln('  </sheetData>');
    sheet1Buffer.writeln('</worksheet>');

    final sheet1Xml = sheet1Buffer.toString();
    archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheet1Xml.length, utf8.encode(sheet1Xml)));

    // 7. xl/worksheets/sheet2.xml (Instructions)
    final sheet2Buffer = StringBuffer();
    sheet2Buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sheet2Buffer.writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    sheet2Buffer.writeln('  <sheetData>');

    // Instructions guidance rows
    sheet2Buffer.writeln('    <row r="1">');
    sheet2Buffer.writeln('      <c r="A1" t="inlineStr" s="1"><is><t>PAYROLL EXCEL EDIT INSTRUCTIONS &amp; FIELD GUIDE</t></is></c>');
    sheet2Buffer.writeln('    </row>');
    sheet2Buffer.writeln('    <row r="2">');
    sheet2Buffer.writeln('      <c r="A2" t="inlineStr"><is><t>After editing the allowed fields, save this file and upload it using Upload Excel/CSV. Click Generate All to recalculate payroll.</t></is></c>');
    sheet2Buffer.writeln('    </row>');
    sheet2Buffer.writeln('    <row r="3">');
    sheet2Buffer.writeln('      <c r="A3" t="inlineStr"><is><t>Note: Employee ID is used to identify the employee and must not be changed. Attendance and calculated payroll fields are calculated by the system.</t></is></c>');
    sheet2Buffer.writeln('    </row>');

    // Row 5: Table Header
    sheet2Buffer.writeln('    <row r="5">');
    sheet2Buffer.writeln('      <c r="A5" t="inlineStr" s="1"><is><t>Column</t></is></c>');
    sheet2Buffer.writeln('      <c r="B5" t="inlineStr" s="1"><is><t>Editable</t></is></c>');
    sheet2Buffer.writeln('      <c r="C5" t="inlineStr" s="1"><is><t>Description</t></is></c>');
    sheet2Buffer.writeln('    </row>');

    const instructionRows = [
      ('Employee ID', 'System Controlled', 'Used to identify the employee and must not be changed.'),
      ('Employee Name', 'System Controlled', 'Employee full name for reference.'),
      ('Organisation', 'System Controlled', 'Selected organisation.'),
      ('Department', 'System Controlled', 'Selected department.'),
      ('Payroll Month', 'System Controlled', 'Payroll cycle month.'),
      ('Present Days', 'System Controlled', 'Calculated from biometric and check-in attendance records.'),
      ('Late Days', 'System Controlled', 'Calculated late check-in count.'),
      ('LOP Hours', 'System Controlled', 'Calculated net shortfall hours after paid leave adjustments.'),
      ('Leave Days', 'System Controlled', 'Approved leave requests count from Leave module.'),
      ('Absent Days', 'System Controlled', 'Calculated unexcused absence count.'),
      ('Weekly Off', 'System Controlled', 'Designated weekly off days in cycle.'),
      ('Working Days', 'System Controlled', 'Scheduled working days in month.'),
      ('Basic', 'Editable', 'Basic salary override.'),
      ('HRA', 'Editable', 'House Rent Allowance override.'),
      ('Education Allowance', 'Editable', 'Education Allowance override.'),
      ('Special Allowance', 'Editable', 'Special Allowance override.'),
      ('Travel Allowance', 'Editable', 'Travel / Conveyance Allowance override.'),
      ('Other Allowance', 'Editable', 'Miscellaneous allowance override.'),
      ('Incentive', 'Editable', 'Monthly approved incentive amount override.'),
      ('Others Earning', 'Editable', 'Additional earnings / reimbursements override.'),
      ('Bonus', 'Editable', 'Performance or festival bonus override.'),
      ('OT', 'Editable', 'Overtime pay override.'),
      ('PF', 'Editable', 'Provident Fund employee contribution deduction override.'),
      ('TDS', 'Editable', 'Income Tax / TDS deduction override.'),
      ('ESI', 'Editable', 'ESI employee contribution deduction override.'),
      ('Salary Advance', 'Editable', 'Salary advance deduction override.'),
      ('Others Deduction', 'Editable', 'Miscellaneous deduction override.'),
      ('Staff Welfare', 'Editable', 'Staff welfare fund contribution override.'),
      ('LOP Deduction', 'System Controlled', 'Calculated Loss of Pay deduction amount.'),
      ('Company Loan', 'System Controlled', 'Active loan EMI calculated from Loan module.'),
      ('Gross Salary', 'System Controlled', 'Total gross earnings dynamically calculated by system.'),
      ('Total Deductions', 'System Controlled', 'Total statutory and other deductions dynamically calculated by system.'),
      ('Net Salary', 'System Controlled', 'Final take-home pay calculated as Gross - Total Deductions.'),
      ('Status', 'System Controlled', 'Payroll processing status (Paid / Processed / Draft / Not Generated).'),
    ];

    for (int i = 0; i < instructionRows.length; i++) {
      final rowNum = i + 6;
      final item = instructionRows[i];
      final colName = _escapeXml(item.$1);
      final editable = _escapeXml(item.$2);
      final desc = _escapeXml(item.$3);

      sheet2Buffer.writeln('    <row r="$rowNum">');
      sheet2Buffer.writeln('      <c r="A$rowNum" t="inlineStr"><is><t>$colName</t></is></c>');
      sheet2Buffer.writeln('      <c r="B$rowNum" t="inlineStr" s="1"><is><t>$editable</t></is></c>');
      sheet2Buffer.writeln('      <c r="C$rowNum" t="inlineStr"><is><t>$desc</t></is></c>');
      sheet2Buffer.writeln('    </row>');
    }

    sheet2Buffer.writeln('  </sheetData>');
    sheet2Buffer.writeln('</worksheet>');

    final sheet2Xml = sheet2Buffer.toString();
    archive.addFile(ArchiveFile('xl/worksheets/sheet2.xml', sheet2Xml.length, utf8.encode(sheet2Xml)));

    return ZipEncoder().encode(archive) ?? [];
  }

  static String _indexToColLetter(int index) {
    String col = '';
    int n = index;
    while (n >= 0) {
      col = String.fromCharCode(65 + (n % 26)) + col;
      n = (n ~/ 26) - 1;
    }
    return col;
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

