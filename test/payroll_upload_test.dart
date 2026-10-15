import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/domain/employee.dart';
import 'package:flutter_application_1/features/payroll/domain/payroll.dart';
import 'package:flutter_application_1/features/payroll/services/payroll_upload_parser.dart';

Employee _makeEmployee({
  required int id,
  required String employeeId,
  required String firstName,
  required String lastName,
}) {
  return Employee(
    id: id,
    employeeId: employeeId,
    firstName: firstName,
    lastName: lastName,
    emailAddress: '$firstName@igreen.com',
    phoneNumber: '9999999999',
    gender: 'Male',
    dob: '1995-01-01',
    organizationName: 'IGREEN TECHNOLOGIES',
    department: 'execution',
    designation: 'Developer',
    employmentType: 'Full Time',
    joiningDate: '2026-08-20',
    status: 'active',
  );
}

void main() {
  final testEmployees = [
    _makeEmployee(id: 5405, employeeId: 'EMP-5405', firstName: 'Dummy', lastName: 'Testing'),
    _makeEmployee(id: 5406, employeeId: 'EMP-5406', firstName: 'Nithya Sri', lastName: 'J'),
    _makeEmployee(id: 5407, employeeId: 'EMP-5407', firstName: 'Sam', lastName: 'J'),
    _makeEmployee(id: 5410, employeeId: 'EMP-5410', firstName: 'Keshav', lastName: 'rajan'),
  ];

  group('PayrollUploadParser CSV parsing', () {
    const csvContent = '''Employee ID,Employee Name,Organisation,Department,Payroll Month,Present Days,Late Days,LOP Hours,Leave Days,Absent Days,Weekly Off,Working Days,Basic,HRA,Education Allowance,Special Allowance,Travel Allowance,Other Allowance,Incentive,Others Earning,Bonus,OT,PF,TDS,ESI,Salary Advance,Others Deduction,Staff Welfare,LOP Deduction,Company Loan,Gross Salary,Total Deductions,Net Salary,Status
EMP-5405,Dummy Testing,IGREEN TECHNOLOGIES,execution,September 2026,26,0,0.0,0,0,5,26,500000.00,250000.00,0.00,250000.00,0.00,0.00,0.00,0.00,0.00,0.00,60000.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,1000000.00,60000.00,940000.00,Draft
EMP-5406,Nithya Sri J,IGREEN TECHNOLOGIES,execution,September 2026,0,0,0.0,0,0,0,26,30000.00,15000.00,0.00,15000.00,0.00,0.00,0.00,0.00,0.00,0.00,3600.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,60000.00,3600.00,56400.00,Not Generated
EMP-5407,Sam J,IGREEN TECHNOLOGIES,execution,September 2026,0,0,0.0,0,0,0,26,30000.00,15000.00,0.00,15000.00,0.00,0.00,0.00,0.00,0.00,0.00,3600.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,60000.00,3600.00,56400.00,Not Generated
EMP-5410,Keshav rajan,IGREEN TECHNOLOGIES,execution,September 2026,0,0,0.0,0,0,0,26,20000.00,10000.00,0.00,10000.00,0.00,0.00,0.00,0.00,0.00,0.00,2400.00,0.00,0.00,0.00,0.00,0.00,0.00,0.00,40000.00,2400.00,37600.00,Not Generated''';

    test('Parses standard CSV successfully', () async {
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final report = await PayrollUploadParser.parseAndValidate(
        bytes: bytes,
        fileName: 'Payroll_IGREEN_TECHNOLOGIES_All_Departments_October_2026.csv',
        allowedEmployees: testEmployees,
      );

      expect(report.invalidRows, isEmpty);
      expect(report.validRows.length, equals(4));
      expect(report.validRows[0].employeeIdRaw, equals('EMP-5405'));
      expect(report.validRows[0].overrideData?.basic, equals(500000.0));
      expect(report.validRows[0].overrideData?.hra, equals(250000.0));
    });

    test('Parses CSV with UTF-8 BOM successfully', () async {
      // BOM: 0xEF, 0xBB, 0xBF
      final bomBytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csvContent)];
      final report = await PayrollUploadParser.parseAndValidate(
        bytes: Uint8List.fromList(bomBytes),
        fileName: 'Payroll_IGREEN_TECHNOLOGIES_All_Departments_October_2026.csv',
        allowedEmployees: testEmployees,
      );

      expect(report.invalidRows, isEmpty, reason: report.invalidRows.map((e) => e.errorMessage).join(', '));
      expect(report.validRows.length, equals(4));
    });
  });

  group('PayrollUploadParser XLSX parsing', () {
    test('Parses exported XLSX with inlineStr tags', () async {
      final archive = Archive();
      final sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="inlineStr" s="1"><is><t>Employee ID</t></is></c>
      <c r="B1" t="inlineStr" s="1"><is><t>Employee Name</t></is></c>
      <c r="C1" t="inlineStr" s="1"><is><t>Organisation</t></is></c>
      <c r="D1" t="inlineStr" s="1"><is><t>Department</t></is></c>
      <c r="E1" t="inlineStr" s="1"><is><t>Payroll Month</t></is></c>
      <c r="M1" t="inlineStr" s="1"><is><t>Basic</t></is></c>
    </row>
    <row r="2">
      <c r="A2" t="inlineStr"><is><t>EMP-5405</t></is></c>
      <c r="B2" t="inlineStr"><is><t>Dummy Testing</t></is></c>
      <c r="C2" t="inlineStr"><is><t>IGREEN TECHNOLOGIES</t></is></c>
      <c r="D2" t="inlineStr"><is><t>execution</t></is></c>
      <c r="E2" t="inlineStr"><is><t>September 2026</t></is></c>
      <c r="M2"><v>550000.00</v></c>
    </row>
  </sheetData>
</worksheet>''';
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));
      final zipBytes = ZipEncoder().encode(archive)!;

      final report = await PayrollUploadParser.parseAndValidate(
        bytes: Uint8List.fromList(zipBytes),
        fileName: 'Payroll_IGREEN_TECHNOLOGIES_All_Departments_October_2026.xlsx',
        allowedEmployees: testEmployees,
      );

      expect(report.invalidRows, isEmpty, reason: report.invalidRows.map((e) => e.errorMessage).join(', '));
      expect(report.validRows.length, equals(1));
      expect(report.validRows[0].employeeIdRaw, equals('EMP-5405'));
      expect(report.validRows[0].overrideData?.basic, equals(550000.0));
    });

    test('Parses Microsoft Excel format with sharedStrings and mixed attribute order', () async {
      final archive = Archive();
      // sharedStrings.xml
      const sharedStringsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="6" uniqueCount="6">
  <si><t>Employee ID</t></si>
  <si><t>Employee Name</t></si>
  <si><t>Basic</t></si>
  <si><t>EMP-5406</t></si>
  <si><t>Nithya Sri J</t></si>
  <si><t>HRA</t></si>
</sst>''';
      archive.addFile(ArchiveFile('xl/sharedStrings.xml', sharedStringsXml.length, utf8.encode(sharedStringsXml)));

      // sheet1.xml: attributes have s="1" before t="s"
      const sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" s="5" t="s"><v>0</v></c>
      <c r="B1" s="5" t="s"><v>1</v></c>
      <c r="C1" s="5" t="s"><v>2</v></c>
      <c r="D1" s="5" t="s"><v>5</v></c>
    </row>
    <row r="2">
      <c r="A2" s="1" t="s"><v>3</v></c>
      <c r="B2" s="1" t="s"><v>4</v></c>
      <c r="C2" s="2"><v>35000</v></c>
      <c r="D2" s="2"><v>17500</v></c>
    </row>
  </sheetData>
</worksheet>''';
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));
      final zipBytes = ZipEncoder().encode(archive)!;

      final report = await PayrollUploadParser.parseAndValidate(
        bytes: Uint8List.fromList(zipBytes),
        fileName: 'Payroll_Data.xlsx',
        allowedEmployees: testEmployees,
      );

      expect(report.invalidRows, isEmpty, reason: report.invalidRows.map((e) => e.errorMessage).join(', '));
      expect(report.validRows.length, equals(1));
      expect(report.validRows[0].employeeIdRaw, equals('EMP-5406'));
      expect(report.validRows[0].overrideData?.basic, equals(35000.0));
      expect(report.validRows[0].overrideData?.hra, equals(17500.0));
    });

    test('Selects the payroll sheet when instructions sheet is sheet1 and payroll is sheet2', () async {
      final archive = Archive();
      // sheet1 is Instructions (does not contain employee_id)
      const sheet1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1"><c r="A1" t="inlineStr"><is><t>Instructions for Payroll</t></is></c></row>
    <row r="2"><c r="A2" t="inlineStr"><is><t>Do not edit system columns.</t></is></c></row>
  </sheetData>
</worksheet>''';
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheet1Xml.length, utf8.encode(sheet1Xml)));

      // sheet2 is Payroll Data
      const sheet2Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="inlineStr"><is><t>Employee ID</t></is></c>
      <c r="B1" t="inlineStr"><is><t>Basic</t></is></c>
    </row>
    <row r="2">
      <c r="A2" t="inlineStr"><is><t>EMP-5407</t></is></c>
      <c r="B2"><v>32000</v></c>
    </row>
  </sheetData>
</worksheet>''';
      archive.addFile(ArchiveFile('xl/worksheets/sheet2.xml', sheet2Xml.length, utf8.encode(sheet2Xml)));
      final zipBytes = ZipEncoder().encode(archive)!;

      final report = await PayrollUploadParser.parseAndValidate(
        bytes: Uint8List.fromList(zipBytes),
        fileName: 'MultiSheet.xlsx',
        allowedEmployees: testEmployees,
      );

      expect(report.invalidRows, isEmpty, reason: report.invalidRows.map((e) => e.errorMessage).join(', '));
      expect(report.validRows.length, equals(1));
      expect(report.validRows[0].employeeIdRaw, equals('EMP-5407'));
      expect(report.validRows[0].overrideData?.basic, equals(32000.0));
    });
  });

  group('PayrollUploadParser Delimiters and ID normalization', () {
    test('Parses Semicolon delimited CSV', () async {
      const semiCsv = 'Employee ID;Employee Name;Basic\nEMP-5410;Keshav rajan;25000.00';
      final report = await PayrollUploadParser.parseAndValidate(
        bytes: Uint8List.fromList(utf8.encode(semiCsv)),
        fileName: 'payroll_semi.csv',
        allowedEmployees: testEmployees,
      );

      expect(report.invalidRows, isEmpty, reason: report.invalidRows.map((e) => e.errorMessage).join(', '));
      expect(report.validRows.length, equals(1));
      expect(report.validRows[0].employeeIdRaw, equals('EMP-5410'));
      expect(report.validRows[0].overrideData?.basic, equals(25000.0));
    });

    test('Matches employee with numeric ID or without hyphens (e.g. 5405 or EMP5405)', () async {
      const csvWithMixedIds = 'Employee ID,Basic\n5405,520000\nEMP5406,31000';
      final report = await PayrollUploadParser.parseAndValidate(
        bytes: Uint8List.fromList(utf8.encode(csvWithMixedIds)),
        fileName: 'mixed_ids.csv',
        allowedEmployees: testEmployees,
      );

      expect(report.invalidRows, isEmpty, reason: report.invalidRows.map((e) => e.errorMessage).join(', '));
      expect(report.validRows.length, equals(2));
      expect(report.validRows[0].employeeIdRaw, equals('5405'));
      expect(report.validRows[0].overrideData?.employeeId, equals('5405'));
      expect(report.validRows[0].overrideData?.basic, equals(520000.0));
      expect(report.validRows[1].employeeIdRaw, equals('EMP5406'));
      expect(report.validRows[1].overrideData?.basic, equals(31000.0));
    });
  });

  group('PayrollUploadParser Change Tracking & Selective Overrides', () {
    final existingRecords = [
      const PayrollRecord(
        id: 101,
        employeeId: 5405,
        employeeName: 'Dummy Testing',
        month: 'September 2026',
        presentDays: 26,
        lateDays: 0,
        absentDays: 0,
        leaveDays: 0,
        basicPay: 500000.0,
        hra: 250000.0,
        educationAllowance: 0.0,
        specialAllowance: 250000.0,
        pf: 60000.0,
        tax: 0.0,
        netSalary: 940000.0,
        status: 'Draft',
      ),
      const PayrollRecord(
        id: 102,
        employeeId: 5406,
        employeeName: 'Nithya Sri J',
        month: 'September 2026',
        presentDays: 26,
        lateDays: 0,
        absentDays: 0,
        leaveDays: 0,
        basicPay: 30000.0,
        hra: 15000.0,
        educationAllowance: 0.0,
        specialAllowance: 15000.0,
        pf: 3600.0,
        tax: 0.0,
        netSalary: 56400.0,
        status: 'Not Generated',
      ),
    ];

    test('Detects no changes when uploaded values are identical to current records', () async {
      const csvIdentical = '''Employee ID,Basic,HRA,Special Allowance
EMP-5405,500000.00,250000.00,250000.00
EMP-5406,30000.00,15000.00,15000.00''';

      final report = await PayrollUploadParser.parseAndValidate(
        bytes: Uint8List.fromList(utf8.encode(csvIdentical)),
        fileName: 'identical.csv',
        allowedEmployees: testEmployees,
        currentRecords: existingRecords,
      );

      expect(report.validRows.length, equals(2));
      expect(report.changedCount, equals(0));
      expect(report.unchangedCount, equals(2));
      expect(report.changedValidRows, isEmpty);
      expect(report.validRows[0].hasChanges, isFalse);
      expect(report.validRows[1].hasChanges, isFalse);
    });

    test('Detects only changed rows and fields when values are modified', () async {
      // EMP-5405: Basic changed 500,000 -> 550,000
      // EMP-5406: Unchanged (30,000 and 15,000 match current record)
      const csvWithOneChange = '''Employee ID,Basic,HRA
EMP-5405,550000.00,250000.00
EMP-5406,30000.00,15000.00''';

      final report = await PayrollUploadParser.parseAndValidate(
        bytes: Uint8List.fromList(utf8.encode(csvWithOneChange)),
        fileName: 'one_change.csv',
        allowedEmployees: testEmployees,
        currentRecords: existingRecords,
      );

      expect(report.validRows.length, equals(2));
      expect(report.changedCount, equals(1));
      expect(report.unchangedCount, equals(1));
      expect(report.changedValidRows.length, equals(1));

      // Row 1 (EMP-5405) has changes
      final changedRow = report.validRows[0];
      expect(changedRow.hasChanges, isTrue);
      expect(changedRow.changes.length, equals(1));
      expect(changedRow.changes[0].key, equals('basic'));
      expect(changedRow.changes[0].oldValue, equals(500000.0));
      expect(changedRow.changes[0].newValue, equals(550000.0));

      // Row 2 (EMP-5406) has no changes
      final unchangedRow = report.validRows[1];
      expect(unchangedRow.hasChanges, isFalse);
      expect(unchangedRow.changes, isEmpty);
    });

    test('Parses XLSX with dynamic formula cells <f>...</f><v>...</v>', () async {
      final archive = Archive();
      const sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="inlineStr"><is><t>Employee ID</t></is></c>
      <c r="B1" t="inlineStr"><is><t>Basic</t></is></c>
      <c r="C1" t="inlineStr"><is><t>Gross Salary</t></is></c>
    </row>
    <row r="2">
      <c r="A2" t="inlineStr"><is><t>EMP-5405</t></is></c>
      <c r="B2"><v>520000</v></c>
      <c r="C2"><f>SUM(B2:B2)</f><v>520000</v></c>
    </row>
  </sheetData>
</worksheet>''';
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final report = await PayrollUploadParser.parseAndValidate(
        bytes: bytes,
        fileName: 'formula_test.xlsx',
        allowedEmployees: testEmployees,
      );

      expect(report.validRows.length, equals(1));
      expect(report.validRows[0].overrideData?.basic, equals(520000.0));
    });
  });
}
