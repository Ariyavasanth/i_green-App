import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

import '../../employee/domain/employee.dart';
import '../domain/payroll_input_override.dart';

class PayrollUploadParser {
  static const Map<String, String> editableFieldLabels = {
    'basic': 'Basic',
    'hra': 'HRA',
    'education_allowance': 'Education Allowance',
    'special_allowance': 'Special Allowance',
    'travel_allowance': 'Travel Allowance',
    'other_allowance': 'Other Allowance',
    'incentive': 'Incentive',
    'others_earning': 'Others Earning',
    'bonus': 'Bonus',
    'ot': 'OT',
    'pf': 'PF',
    'tax': 'TDS',
    'esi': 'ESI',
    'salary_advance': 'Salary Advance',
    'others_deduction': 'Others Deduction',
    'staff_welfare': 'Staff Welfare',
  };

  static const Map<String, String> systemControlledFieldLabels = {
    'employee_id': 'Employee ID',
    'employee_name': 'Employee Name',
    'organisation': 'Organisation',
    'department': 'Department',
    'payroll_month': 'Payroll Month',
    'present_days': 'Present Days',
    'late_days': 'Late Days',
    'lop_hours': 'LOP Hours',
    'leave_days': 'Leave Days',
    'absent_days': 'Absent Days',
    'weekly_off': 'Weekly Off',
    'working_days': 'Working Days',
    'lop_deduction': 'LOP Deduction',
    'company_loan': 'Company Loan',
    'gross_salary': 'Gross Salary',
    'total_deductions': 'Total Deductions',
    'net_salary': 'Net Salary',
    'status': 'Status',
  };

  /// Parses bytes from CSV, TSV, or XLSX and validates each row against the currently filtered employees.
  static Future<PayrollUploadValidationReport> parseAndValidate({
    required Uint8List bytes,
    required String fileName,
    required List<Employee> allowedEmployees,
  }) async {
    final lowerFileName = fileName.toLowerCase();
    List<List<String>> rawTable = [];

    if (lowerFileName.endsWith('.csv') || lowerFileName.endsWith('.tsv') || lowerFileName.endsWith('.txt')) {
      rawTable = _parseCsvOrTsv(bytes);
    } else if (lowerFileName.endsWith('.xlsx') || lowerFileName.endsWith('.xls')) {
      rawTable = _parseXlsx(bytes);
    } else {
      return PayrollUploadValidationReport(
        fileName: fileName,
        totalRows: 0,
        validRows: const [],
        invalidRows: [
          UploadRowValidation(
            rowIndex: 0,
            employeeIdRaw: '',
            employeeNameRaw: '',
            isValid: false,
            errorMessage: 'Unsupported file format "$fileName". Please upload a .xlsx, .xls, or .csv file.',
          ),
        ],
      );
    }

    if (rawTable.isEmpty) {
      return PayrollUploadValidationReport(
        fileName: fileName,
        totalRows: 0,
        validRows: const [],
        invalidRows: [
          const UploadRowValidation(
            rowIndex: 0,
            employeeIdRaw: '',
            employeeNameRaw: '',
            isValid: false,
            errorMessage: 'File is empty or could not be read.',
          ),
        ],
      );
    }

    // Identify header row
    final headerRow = rawTable.first;
    final headerMap = <String, int>{};
    final detectedEditable = <String>[];
    final detectedSystem = <String>[];

    for (int i = 0; i < headerRow.length; i++) {
      final normalized = _normalizeHeader(headerRow[i]);
      if (normalized.isNotEmpty) {
        headerMap[normalized] = i;
        if (editableFieldLabels.containsKey(normalized)) {
          final label = editableFieldLabels[normalized]!;
          if (!detectedEditable.contains(label)) detectedEditable.add(label);
        } else if (systemControlledFieldLabels.containsKey(normalized)) {
          final label = systemControlledFieldLabels[normalized]!;
          if (!detectedSystem.contains(label)) detectedSystem.add(label);
        }
      }
    }

    if (!headerMap.containsKey('employee_id')) {
      return PayrollUploadValidationReport(
        fileName: fileName,
        totalRows: rawTable.length - 1,
        validRows: const [],
        invalidRows: [
          UploadRowValidation(
            rowIndex: 1,
            employeeIdRaw: '',
            employeeNameRaw: '',
            isValid: false,
            errorMessage: 'Missing required "Employee ID" header column in file.',
          ),
        ],
        detectedEditableColumns: detectedEditable,
        detectedSystemColumns: detectedSystem,
      );
    }

    final validRows = <UploadRowValidation>[];
    final invalidRows = <UploadRowValidation>[];
    final seenEmployeeIds = <String>{};

    for (int r = 1; r < rawTable.length; r++) {
      final row = rawTable[r];
      // Skip completely empty rows
      if (row.every((cell) => cell.trim().isEmpty)) continue;

      final empIdIdx = headerMap['employee_id']!;
      final empIdRaw = empIdIdx < row.length ? row[empIdIdx].trim() : '';

      final nameIdx = headerMap['employee_name'];
      final nameRaw = (nameIdx != null && nameIdx < row.length) ? row[nameIdx].trim() : '';

      if (empIdRaw.isEmpty) {
        invalidRows.add(UploadRowValidation(
          rowIndex: r + 1,
          employeeIdRaw: '',
          employeeNameRaw: nameRaw,
          isValid: false,
          errorMessage: 'Row ${r + 1}: Employee ID is empty.',
        ));
        continue;
      }

      // Check duplicates within upload file
      final normalizedEmpId = empIdRaw.toLowerCase().replaceAll('-', '').replaceAll(' ', '');
      if (seenEmployeeIds.contains(normalizedEmpId)) {
        invalidRows.add(UploadRowValidation(
          rowIndex: r + 1,
          employeeIdRaw: empIdRaw,
          employeeNameRaw: nameRaw,
          isValid: false,
          errorMessage: 'Row ${r + 1}: Duplicate Employee ID "$empIdRaw" in file.',
        ));
        continue;
      }
      seenEmployeeIds.add(normalizedEmpId);

      // Check matching against allowed employees (currently filtered organisation & department)
      final matchedEmp = allowedEmployees.where((e) {
        final idStr = e.id.toString();
        final codeStr = e.employeeId.trim().toLowerCase().replaceAll('-', '').replaceAll(' ', '');
        final empIdWithPrefix = 'emp${e.id}'.toLowerCase();
        return idStr == empIdRaw ||
            codeStr == normalizedEmpId ||
            empIdWithPrefix == normalizedEmpId ||
            e.employeeId.trim().toLowerCase() == empIdRaw.toLowerCase();
      }).firstOrNull;

      if (matchedEmp == null) {
        invalidRows.add(UploadRowValidation(
          rowIndex: r + 1,
          employeeIdRaw: empIdRaw,
          employeeNameRaw: nameRaw,
          isValid: false,
          errorMessage: 'Row ${r + 1}: Employee "$empIdRaw" does not exist in the selected organisation and department.',
        ));
        continue;
      }

      // Parse and validate numeric overrides (only editable fields!)
      String? parseError;
      double? parseNum(String key, String label) {
        if (parseError != null) return null;
        final idx = headerMap[key];
        if (idx == null || idx >= row.length) return null;
        final valStr = row[idx].trim().replaceAll('₹', '').replaceAll(',', '');
        if (valStr.isEmpty || valStr == '-') return null;
        final parsed = double.tryParse(valStr);
        if (parsed == null || parsed < 0) {
          parseError = 'Row ${r + 1}: Invalid $label value "$valStr". Must be a non-negative number.';
          return null;
        }
        return double.parse(parsed.toStringAsFixed(2));
      }

      final basic = parseNum('basic', 'Basic Salary');
      final hra = parseNum('hra', 'HRA');
      final edu = parseNum('education_allowance', 'Education Allowance');
      final special = parseNum('special_allowance', 'Special Allowance');
      final travel = parseNum('travel_allowance', 'Travel Allowance');
      final otherAllow = parseNum('other_allowance', 'Other Allowance');

      final incentive = parseNum('incentive', 'Incentive');
      final othersEarning = parseNum('others_earning', 'Others Earning');
      final bonus = parseNum('bonus', 'Bonus');
      final ot = parseNum('ot', 'Overtime');

      final pf = parseNum('pf', 'PF');
      final tax = parseNum('tax', 'TDS');
      final esi = parseNum('esi', 'ESI');
      final advance = parseNum('salary_advance', 'Salary Advance');
      final othersDed = parseNum('others_deduction', 'Others Deduction');
      final welfare = parseNum('staff_welfare', 'Staff Welfare');

      if (parseError != null) {
        invalidRows.add(UploadRowValidation(
          rowIndex: r + 1,
          employeeIdRaw: empIdRaw,
          employeeNameRaw: nameRaw.isNotEmpty ? nameRaw : matchedEmp.fullName,
          isValid: false,
          errorMessage: parseError,
        ));
        continue;
      }

      final override = PayrollInputOverride(
        employeeId: matchedEmp.id.toString(),
        employeeName: matchedEmp.fullName,
        basic: basic,
        hra: hra,
        educationAllowance: edu,
        specialAllowance: special,
        travelAllowance: travel,
        otherAllowance: otherAllow,
        incentive: incentive,
        othersEarning: othersEarning,
        bonus: bonus,
        ot: ot,
        pf: pf,
        tax: tax,
        esi: esi,
        salaryAdvance: advance,
        othersDeduction: othersDed,
        staffWelfare: welfare,
      );

      validRows.add(UploadRowValidation(
        rowIndex: r + 1,
        employeeIdRaw: empIdRaw,
        employeeNameRaw: matchedEmp.fullName,
        isValid: true,
        overrideData: override,
      ));
    }

    return PayrollUploadValidationReport(
      fileName: fileName,
      totalRows: validRows.length + invalidRows.length,
      validRows: validRows,
      invalidRows: invalidRows,
      detectedEditableColumns: detectedEditable,
      detectedSystemColumns: detectedSystem,
    );
  }

  static String _normalizeHeader(String header) {
    final clean = header.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-\(\)\/\.]'), '');
    
    // System-controlled identifiers
    if (clean == 'employeeid' || clean == 'empid' || clean == 'employeecode' || clean == 'empcode' || clean == 'id') {
      return 'employee_id';
    }
    if (clean == 'employeename' || clean == 'empname' || clean == 'name' || clean == 'fullname') {
      return 'employee_name';
    }
    if (clean == 'organisation' || clean == 'organization' || clean == 'org' || clean == 'company') {
      return 'organisation';
    }
    if (clean == 'department' || clean == 'dept') {
      return 'department';
    }
    if (clean == 'payrollmonth' || clean == 'month' || clean == 'cycle') {
      return 'payroll_month';
    }
    if (clean == 'presentdays' || clean == 'presentcount' || clean == 'present') {
      return 'present_days';
    }
    if (clean == 'latedays' || clean == 'latecount' || clean == 'late') {
      return 'late_days';
    }
    if (clean == 'lophours' || clean == 'shortfallhours' || clean == 'lophour') {
      return 'lop_hours';
    }
    if (clean == 'leavedays' || clean == 'onleavecount' || clean == 'leave') {
      return 'leave_days';
    }
    if (clean == 'absentdays' || clean == 'absentcount' || clean == 'absent') {
      return 'absent_days';
    }
    if (clean == 'weeklyoff' || clean == 'weeklyoffcount' || clean == 'offdays') {
      return 'weekly_off';
    }
    if (clean == 'workingdays' || clean == 'totalworkingdays') {
      return 'working_days';
    }
    if (clean == 'lopdeduction' || clean == 'lop' || clean == 'lopamount') {
      return 'lop_deduction';
    }
    if (clean == 'companyloan' || clean == 'loan' || clean == 'loanemi' || clean == 'companyloanemi') {
      return 'company_loan';
    }
    if (clean == 'grosssalary' || clean == 'gross' || clean == 'grosspay' || clean == 'totalgross') {
      return 'gross_salary';
    }
    if (clean == 'totaldeductions' || clean == 'totaldeduction' || clean == 'deductions' || clean == 'totalded') {
      return 'total_deductions';
    }
    if (clean == 'netsalary' || clean == 'net' || clean == 'netpay' || clean == 'takehome') {
      return 'net_salary';
    }
    if (clean == 'status') {
      return 'status';
    }

    // Editable payroll inputs
    if (clean == 'basic' || clean == 'basicsalary' || clean == 'basicpay') {
      return 'basic';
    }
    if (clean == 'hra' || clean == 'houserentallowance') {
      return 'hra';
    }
    if (clean == 'educationalallowance' || clean == 'educationallowance' || clean == 'eduallowance') {
      return 'education_allowance';
    }
    if (clean == 'specialallowance' || clean == 'special') {
      return 'special_allowance';
    }
    if (clean == 'travelallowance' || clean == 'travel' || clean == 'conveyance') {
      return 'travel_allowance';
    }
    if (clean == 'otherallowance' || clean == 'otherallowances') {
      return 'other_allowance';
    }
    if (clean == 'incentive' || clean == 'incentives') {
      return 'incentive';
    }
    if (clean == 'othersearning' || clean == 'otherearning' || clean == 'othersexpense' || clean == 'additionlearning') {
      return 'others_earning';
    }
    if (clean == 'bonus') {
      return 'bonus';
    }
    if (clean == 'ot' || clean == 'overtime') {
      return 'ot';
    }
    if (clean == 'pf' || clean == 'providentfund' || clean == 'pfcontribution') {
      return 'pf';
    }
    if (clean == 'tds' || clean == 'incometax' || clean == 'tax') {
      return 'tax';
    }
    if (clean == 'esi' || clean == 'esicontribution') {
      return 'esi';
    }
    if (clean == 'salaryadvance' || clean == 'advance' || clean == 'advanceamount') {
      return 'salary_advance';
    }
    if (clean == 'othersdeduction' || clean == 'otherdeduction' || clean == 'otherdeductions') {
      return 'others_deduction';
    }
    if (clean == 'staffwelfare' || clean == 'welfare' || clean == 'staffwelfarecontribution') {
      return 'staff_welfare';
    }
    return '';
  }


  static List<List<String>> _parseCsvOrTsv(Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }

    final lines = content.split(RegExp(r'\r\n|\r|\n'));
    final table = <List<String>>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      // Check delimiter (tab or comma)
      final delimiter = line.contains('\t') ? '\t' : ',';
      table.add(_parseCsvLine(line, delimiter));
    }
    return table;
  }

  static List<String> _parseCsvLine(String line, String delimiter) {
    final cells = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // Skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        cells.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString().trim());
    return cells;
  }

  static List<List<String>> _parseXlsx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final sharedStrings = <String>[];

      // 1. Read shared strings
      final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
      if (sharedStringsFile != null) {
        final xml = utf8.decode(sharedStringsFile.content as List<int>);
        final siRegex = RegExp(r'<si>(.*?)</si>', dotAll: true);
        final tRegex = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);

        for (final match in siRegex.allMatches(xml)) {
          final siContent = match.group(1) ?? '';
          final textBuffer = StringBuffer();
          for (final tMatch in tRegex.allMatches(siContent)) {
            textBuffer.write(tMatch.group(1));
          }
          sharedStrings.add(textBuffer.toString().replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>'));
        }
      }

      // 2. Read sheet1
      final sheetFile = archive.findFile('xl/worksheets/sheet1.xml') ??
          archive.files.where((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')).firstOrNull;

      if (sheetFile == null) return [];

      final sheetXml = utf8.decode(sheetFile.content as List<int>);
      final table = <List<String>>[];

      final rowRegex = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true);
      final cellRegex = RegExp(r'<c\s+r="([A-Z]+)(\d+)"(?:\s+t="([^"]*)")?[^>]*>(?:<v>(.*?)</v>)?', dotAll: true);

      for (final rowMatch in rowRegex.allMatches(sheetXml)) {
        final rowXml = rowMatch.group(1) ?? '';
        final rowMap = <int, String>{};
        int maxCol = 0;

        for (final cellMatch in cellRegex.allMatches(rowXml)) {
          final colLetters = cellMatch.group(1) ?? 'A';
          final colIdx = _colLetterToIndex(colLetters);
          final cellType = cellMatch.group(3) ?? '';
          final val = cellMatch.group(4) ?? '';

          String cellText = val;
          if (cellType == 's') {
            final sIdx = int.tryParse(val);
            if (sIdx != null && sIdx >= 0 && sIdx < sharedStrings.length) {
              cellText = sharedStrings[sIdx];
            }
          }
          rowMap[colIdx] = cellText;
          if (colIdx > maxCol) maxCol = colIdx;
        }

        final rowList = <String>[];
        for (int c = 0; c <= maxCol; c++) {
          rowList.add(rowMap[c] ?? '');
        }
        table.add(rowList);
      }
      return table;
    } catch (_) {
      // If zip decoding fails, fallback to raw text splitting
      return _parseCsvOrTsv(bytes);
    }
  }

  static int _colLetterToIndex(String letters) {
    int result = 0;
    for (int i = 0; i < letters.length; i++) {
      result = result * 26 + (letters.codeUnitAt(i) - 64);
    }
    return result - 1;
  }
}
