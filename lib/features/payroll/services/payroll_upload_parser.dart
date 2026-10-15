import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

import '../../employee/domain/employee.dart';
import '../domain/payroll.dart';
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
    List<PayrollRecord> currentRecords = const [],
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
      final rawDigits = empIdRaw.replaceAll(RegExp(r'\D'), '');
      final matchedEmp = allowedEmployees.where((e) {
        final idStr = e.id.toString();
        final codeStr = e.employeeId.trim().toLowerCase().replaceAll('-', '').replaceAll(' ', '');
        final empIdWithPrefix = 'emp${e.id}'.toLowerCase();
        final empDigits = e.employeeId.replaceAll(RegExp(r'\D'), '');

        if (idStr == empIdRaw) return true;
        if (codeStr == normalizedEmpId) return true;
        if (empIdWithPrefix == normalizedEmpId) return true;
        if (e.employeeId.trim().toLowerCase() == empIdRaw.toLowerCase()) return true;
        if (rawDigits.isNotEmpty && rawDigits == empDigits) return true;
        if (rawDigits.isNotEmpty && int.tryParse(rawDigits) == e.id) return true;
        return false;
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
          email: matchedEmp.emailAddress,
          contactNumber: matchedEmp.phoneNumber,
          department: matchedEmp.department,
          designation: matchedEmp.designation,
          joiningDate: matchedEmp.joiningDate,
          isValid: false,
          errorMessage: parseError,
          hasChanges: false,
          changes: const [],
        ));
        continue;
      }

      // Find current existing record or master fallback to detect actual changes
      final existingRecord = currentRecords.where((rec) => rec.employeeId == matchedEmp.id).firstOrNull;

      double getCurrentVal(String key) {
        if (existingRecord != null) {
          switch (key) {
            case 'basic': return existingRecord.basicPay;
            case 'hra': return existingRecord.hra;
            case 'education_allowance': return existingRecord.educationAllowance;
            case 'special_allowance': return existingRecord.specialAllowance;
            case 'travel_allowance': return existingRecord.travelAllowance;
            case 'other_allowance': return existingRecord.otherAllowance;
            case 'incentive': return existingRecord.incentive;
            case 'others_earning': return existingRecord.othersEarning;
            case 'bonus': return existingRecord.bonus;
            case 'ot': return existingRecord.ot;
            case 'pf': return existingRecord.pf;
            case 'tax': return existingRecord.tax;
            case 'esi': return existingRecord.esi;
            case 'salary_advance': return existingRecord.salaryAdvance;
            case 'others_deduction': return existingRecord.othersDeduction;
            case 'staff_welfare': return existingRecord.staffWelfareContribution;
          }
        }
        switch (key) {
          case 'basic': return (matchedEmp.salaryBasic as num?)?.toDouble() ?? 0.0;
          case 'hra': return (matchedEmp.salaryHra as num?)?.toDouble() ?? 0.0;
          case 'education_allowance': return (matchedEmp.salaryEducationAllowance as num?)?.toDouble() ?? 0.0;
          case 'special_allowance': return (matchedEmp.salarySpecialAllowance as num?)?.toDouble() ?? 0.0;
          case 'travel_allowance': return (matchedEmp.salaryTravelAllowance as num?)?.toDouble() ?? 0.0;
          case 'other_allowance': return (matchedEmp.salaryOtherAllowance as num?)?.toDouble() ?? 0.0;
          case 'incentive': return 0.0;
          case 'others_earning': return 0.0;
          case 'bonus': return 0.0;
          case 'ot': return 0.0;
          case 'pf': return (matchedEmp.salaryPf as num?)?.toDouble() ?? 0.0;
          case 'tax': return (matchedEmp.salaryTax as num?)?.toDouble() ?? 0.0;
          case 'esi': return (matchedEmp.salaryEsi as num?)?.toDouble() ?? 0.0;
          case 'salary_advance': return 0.0;
          case 'others_deduction': return 0.0;
          case 'staff_welfare': return 0.0;
        }
        return 0.0;
      }

      final changes = <PayrollFieldChange>[];
      void checkChange(String key, String label, double? newVal) {
        if (newVal != null) {
          final cur = getCurrentVal(key);
          if ((newVal - cur).abs() > 0.009) {
            changes.add(PayrollFieldChange(
              key: key,
              label: label,
              oldValue: cur,
              newValue: newVal,
            ));
          }
        }
      }

      checkChange('basic', 'Basic', basic);
      checkChange('hra', 'HRA', hra);
      checkChange('education_allowance', 'Education Allowance', edu);
      checkChange('special_allowance', 'Special Allowance', special);
      checkChange('travel_allowance', 'Travel Allowance', travel);
      checkChange('other_allowance', 'Other Allowance', otherAllow);
      checkChange('incentive', 'Incentive', incentive);
      checkChange('others_earning', 'Others Earning', othersEarning);
      checkChange('bonus', 'Bonus', bonus);
      checkChange('ot', 'OT', ot);
      checkChange('pf', 'PF', pf);
      checkChange('tax', 'TDS', tax);
      checkChange('esi', 'ESI', esi);
      checkChange('salary_advance', 'Salary Advance', advance);
      checkChange('others_deduction', 'Others Deduction', othersDed);
      checkChange('staff_welfare', 'Staff Welfare', welfare);

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
        email: matchedEmp.emailAddress,
        contactNumber: matchedEmp.phoneNumber,
        department: matchedEmp.department,
        designation: matchedEmp.designation,
        joiningDate: matchedEmp.joiningDate,
        isValid: true,
        overrideData: override,
        hasChanges: changes.isNotEmpty,
        changes: changes,
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
    final clean = header
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'[\u200B-\u200D\u00A0]'), '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-\(\)\/\.]'), '');

    // System-controlled identifiers
    if (clean == 'employeeid' ||
        clean == 'empid' ||
        clean == 'employeecode' ||
        clean == 'empcode' ||
        clean == 'employeeno' ||
        clean == 'empno' ||
        clean == 'staffid' ||
        clean == 'staffno' ||
        clean == 'id') {
      return 'employee_id';
    }
    if (clean == 'employeename' ||
        clean == 'empname' ||
        clean == 'name' ||
        clean == 'fullname' ||
        clean == 'staffname') {
      return 'employee_name';
    }
    if (clean == 'organisation' ||
        clean == 'organization' ||
        clean == 'org' ||
        clean == 'company' ||
        clean == 'companyname') {
      return 'organisation';
    }
    if (clean == 'department' || clean == 'dept' || clean == 'division') {
      return 'department';
    }
    if (clean == 'payrollmonth' ||
        clean == 'month' ||
        clean == 'cycle' ||
        clean == 'salarymonth' ||
        clean == 'paymonth' ||
        clean == 'period') {
      return 'payroll_month';
    }
    if (clean == 'presentdays' || clean == 'presentcount' || clean == 'present' || clean == 'presents') {
      return 'present_days';
    }
    if (clean == 'latedays' || clean == 'latecount' || clean == 'late' || clean == 'lates') {
      return 'late_days';
    }
    if (clean == 'lophours' || clean == 'shortfallhours' || clean == 'lophour' || clean == 'shortfallhour') {
      return 'lop_hours';
    }
    if (clean == 'leavedays' || clean == 'onleavecount' || clean == 'leave' || clean == 'leaves' || clean == 'leavecount') {
      return 'leave_days';
    }
    if (clean == 'absentdays' || clean == 'absentcount' || clean == 'absent' || clean == 'absents') {
      return 'absent_days';
    }
    if (clean == 'weeklyoff' || clean == 'weeklyoffcount' || clean == 'offdays' || clean == 'weekoff' || clean == 'weekoffs') {
      return 'weekly_off';
    }
    if (clean == 'workingdays' || clean == 'totalworkingdays' || clean == 'workdays' || clean == 'totalworkdays') {
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
    if (clean == 'netsalary' || clean == 'net' || clean == 'netpay' || clean == 'takehome' || clean == 'takehomepay') {
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
    if (clean == 'specialallowance' || clean == 'special' || clean == 'specialallow') {
      return 'special_allowance';
    }
    if (clean == 'travelallowance' || clean == 'travel' || clean == 'conveyance' || clean == 'conveyanceallowance') {
      return 'travel_allowance';
    }
    if (clean == 'otherallowance' || clean == 'otherallowances') {
      return 'other_allowance';
    }
    if (clean == 'incentive' || clean == 'incentives') {
      return 'incentive';
    }
    if (clean == 'othersearning' ||
        clean == 'otherearning' ||
        clean == 'othersexpense' ||
        clean == 'additionlearning' ||
        clean == 'additionalearning') {
      return 'others_earning';
    }
    if (clean == 'bonus' || clean == 'bonuses') {
      return 'bonus';
    }
    if (clean == 'ot' || clean == 'overtime' || clean == 'otamount' || clean == 'overtimeamount') {
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

    // Strip UTF-8 Byte Order Mark (BOM) if present
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    final lines = content.split(RegExp(r'\r\n|\r|\n'));
    final table = <List<String>>[];

    // Auto-detect delimiter from the first non-empty line
    String delimiter = ',';
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final tabCount = '\t'.allMatches(trimmed).length;
      final semiCount = ';'.allMatches(trimmed).length;
      final commaCount = ','.allMatches(trimmed).length;
      if (tabCount > commaCount && tabCount > semiCount) {
        delimiter = '\t';
      } else if (semiCount > commaCount && semiCount > tabCount) {
        delimiter = ';';
      } else {
        delimiter = ',';
      }
      break;
    }

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
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

      // 1. Read shared strings if available
      final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
      if (sharedStringsFile != null) {
        final xml = utf8.decode(sharedStringsFile.content as List<int>);
        final siRegex = RegExp(r'<si\b[^>]*>(.*?)</si>', dotAll: true);
        final tRegex = RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true);

        for (final match in siRegex.allMatches(xml)) {
          final siContent = match.group(1) ?? '';
          final textBuffer = StringBuffer();
          for (final tMatch in tRegex.allMatches(siContent)) {
            textBuffer.write(tMatch.group(1));
          }
          sharedStrings.add(_decodeXml(textBuffer.toString()));
        }
      }

      // 2. Locate candidate worksheets
      final sheetFiles = archive.files
          .where((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'))
          .toList();

      if (sheetFiles.isEmpty) return [];

      // Sort sheets to evaluate sheet1 first if available
      sheetFiles.sort((a, b) => a.name.compareTo(b.name));

      List<List<String>> bestTable = [];
      for (final sf in sheetFiles) {
        final xml = utf8.decode(sf.content as List<int>);
        final table = _parseSheetTable(xml, sharedStrings);
        if (table.isNotEmpty) {
          final firstRow = table.first;
          final hasEmpId = firstRow.any((h) => _normalizeHeader(h) == 'employee_id');
          if (hasEmpId) {
            return table; // Found the payroll data sheet!
          }
          if (bestTable.isEmpty) {
            bestTable = table;
          }
        }
      }

      return bestTable;
    } catch (_) {
      // If zip decoding fails, fallback to raw text splitting
      return _parseCsvOrTsv(bytes);
    }
  }

  static List<List<String>> _parseSheetTable(String sheetXml, List<String> sharedStrings) {
    final table = <List<String>>[];
    final rowRegex = RegExp(r'<row\b[^>]*>(.*?)</row>', dotAll: true);
    final cellRegex = RegExp(r'<c\b([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true);

    for (final rowMatch in rowRegex.allMatches(sheetXml)) {
      final rowXml = rowMatch.group(1) ?? '';
      final rowMap = <int, String>{};
      int maxCol = -1;
      int autoCol = 0;

      for (final cellMatch in cellRegex.allMatches(rowXml)) {
        final attrs = cellMatch.group(1) ?? '';
        final body = cellMatch.group(2) ?? '';

        final colLetters = RegExp(r'\br="([A-Za-z]+)(\d+)"').firstMatch(attrs)?.group(1);
        final colIdx = colLetters != null ? _colLetterToIndex(colLetters) : autoCol;
        autoCol = colIdx + 1;

        final cellType = RegExp(r'\bt="([^"]*)"').firstMatch(attrs)?.group(1) ?? '';
        String cellText = '';

        if (cellType == 's') {
          final vMatch = RegExp(r'<v\b[^>]*>(.*?)</v>', dotAll: true).firstMatch(body);
          final sIdx = int.tryParse(vMatch?.group(1) ?? '');
          if (sIdx != null && sIdx >= 0 && sIdx < sharedStrings.length) {
            cellText = sharedStrings[sIdx];
          }
        } else if (cellType == 'inlineStr') {
          final tMatches = RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true).allMatches(body);
          cellText = _decodeXml(tMatches.map((m) => m.group(1) ?? '').join());
        } else if (cellType == 'str') {
          final vMatch = RegExp(r'<v\b[^>]*>(.*?)</v>', dotAll: true).firstMatch(body);
          cellText = _decodeXml(vMatch?.group(1) ?? '');
        } else if (cellType == 'b') {
          final vMatch = RegExp(r'<v\b[^>]*>(.*?)</v>', dotAll: true).firstMatch(body);
          final v = vMatch?.group(1)?.trim();
          cellText = (v == '1' || v == 'true') ? 'true' : 'false';
        } else {
          final vMatch = RegExp(r'<v\b[^>]*>(.*?)</v>', dotAll: true).firstMatch(body);
          if (vMatch != null) {
            cellText = _decodeXml(vMatch.group(1) ?? '');
          } else {
            final tMatches = RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true).allMatches(body);
            if (tMatches.isNotEmpty) {
              cellText = _decodeXml(tMatches.map((m) => m.group(1) ?? '').join());
            }
          }
        }

        rowMap[colIdx] = cellText.trim();
        if (colIdx > maxCol) maxCol = colIdx;
      }

      if (maxCol >= 0) {
        final rowList = <String>[];
        for (int c = 0; c <= maxCol; c++) {
          rowList.add(rowMap[c] ?? '');
        }
        table.add(rowList);
      }
    }
    return table;
  }

  static String _decodeXml(String text) {
    if (!text.contains('&')) return text;
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#160;', ' ')
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          final code = int.tryParse(m.group(1) ?? '');
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        })
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          final code = int.tryParse(m.group(1) ?? '', radix: 16);
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        });
  }

  static int _colLetterToIndex(String letters) {
    int result = 0;
    final upper = letters.toUpperCase();
    for (int i = 0; i < upper.length; i++) {
      result = result * 26 + (upper.codeUnitAt(i) - 64);
    }
    return result - 1;
  }
}
