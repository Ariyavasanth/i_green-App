import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../organization/domain/column_preference.dart';
import '../domain/candidate_response.dart';
import '../domain/employee.dart';
import '../domain/employee_repository.dart';
import '../domain/registration_link.dart';

class SqliteEmployeeRepository implements EmployeeRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');

    final db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
        await _migrateLegacyAttendanceFlags(db);
      },
      onOpen: (db) async {
        await _createTables(db);
        await _ensureColumnsExist(db);
        await _migrateLegacyAttendanceFlags(db);
      },
    );

    await _seedSampleData(db);
    return db;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT UNIQUE,
        first_name TEXT,
        last_name TEXT,
        email_address TEXT,
        phone_number TEXT,
        gender TEXT,
        dob TEXT,
        organization_name TEXT,
        department TEXT,
        designation TEXT,
        employment_type TEXT,
        joining_date TEXT,
        status TEXT,
        blood_group TEXT,
        user_type TEXT,
        contract_end_date TEXT,
        profile_image_url TEXT,
        profile_image_public_id TEXT,
        profile_image_folder TEXT,
        street TEXT,
        city TEXT,
        state TEXT,
        postal_code TEXT,
        country TEXT,
        permanent_address TEXT,
        permanent_city TEXT,
        permanent_country TEXT,
        same_as_permanent INTEGER,
        present_address TEXT,
        present_city TEXT,
        present_country TEXT,
        education_degree TEXT,
        education_institution TEXT,
        education_year TEXT,
        education_grade TEXT,
        education_list_json TEXT,
        experience_company TEXT,
        experience_role TEXT,
        experience_years TEXT,
        experience_list_json TEXT,
        original_dob TEXT,
        personal_mobile TEXT,
        passport_number TEXT,
        driving_license_number TEXT,
        driving_license_batch TEXT,
        health_issues TEXT,
        emergency_name TEXT,
        emergency_mobile TEXT,
        referred_by_name TEXT,
        referred_by_mobile TEXT,
        father_name TEXT,
        mother_name TEXT,
        marital_status TEXT,
        spouseName TEXT,
        kids1_name TEXT,
        kids2_name TEXT,
        kids3_name TEXT,
        bank_account_holder TEXT,
        bank_name TEXT,
        bank_account_number TEXT,
        bank_ifsc TEXT,
        bank_branch TEXT,
        bank_account_type TEXT,
        pan_number TEXT,
        aadhaar_number TEXT,
        edu_certificates_url TEXT,
        blood_group_report TEXT,
        document_list_json TEXT,
        facebook_url TEXT,
        twitter_url TEXT,
        linkedin_url TEXT,
        google_url TEXT,
        personal_history_details TEXT,
        has_criminal_cases INTEGER DEFAULT 0,
        criminal_case_details TEXT,
        salary_type TEXT,
        salary_basic REAL,
        salary_hra REAL,
        salary_education_allowance REAL,
        salary_special_allowance REAL,
        salary_travel_allowance REAL,
        salary_other_allowance REAL,
        salary_allowances REAL,
        salary_tax REAL,
        salary_pf REAL,
        salary_esi REAL,
        salary_professional_tax REAL,
        salary_total_ctc REAL,
        insurance_policy_no TEXT,
        insurance_provider TEXT,
        insurance_coverage REAL,
        pf_number TEXT,
        pf_uan TEXT,
        esi_number TEXT,
        leave_details TEXT,
        in_time TEXT,
        out_time TEXT,
        company_assets TEXT,
        reporting_manager TEXT,
        reporting_manager_title TEXT,
        admin_name TEXT,
        coordinator_name TEXT,
        coordinator_phone TEXT,
        weekly_off_day TEXT,
        team_name TEXT,
        disciplinary_records TEXT,
        temporary_password TEXT,
        access_permissions TEXT,
        leave_type TEXT,
        leave_allocation_frequency TEXT,
        allowed_leaves REAL,
        monthly_permission_limit_hours REAL DEFAULT 3.0,
        daily_permission_limit_hours REAL DEFAULT 1.0,
        effective_date TEXT,
        requires_leave_approval INTEGER DEFAULT 1,
        required_working_hours REAL DEFAULT 9.0,
        is_static_employee INTEGER DEFAULT 0,
        is_dynamic_employee INTEGER DEFAULT 0,
        site_latitude REAL DEFAULT 0.0,
        site_longitude REAL DEFAULT 0.0,
        site_allowed_radius_meters INTEGER DEFAULT 15,
        site_require_gps_verification INTEGER DEFAULT 1
      )
    ''');

    try {
      await db.execute('ALTER TABLE employees ADD COLUMN requires_leave_approval INTEGER DEFAULT 1');
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS registration_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        link_id TEXT UNIQUE,
        generated_by TEXT,
        generated_date TEXT,
        expiry_date TEXT,
        link_status TEXT,
        employee_name TEXT,
        employee_id TEXT,
        organization_name TEXT,
        department TEXT,
        submitted_date TEXT,
        submitted_by TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS column_preferences (
        table_id TEXT PRIMARY KEY,
        visible_columns TEXT,
        column_order TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS candidate_responses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        candidate_id TEXT UNIQUE,
        link_id TEXT,
        submitted_date TEXT,
        status TEXT,
        full_name TEXT,
        email_address TEXT,
        phone_number TEXT,
        employee_data_json TEXT
      )
    ''');
  }

  Future<void> _ensureColumnsExist(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(employees)');
    final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();

    final requiredColumns = {
      'blood_group': 'TEXT',
      'user_type': 'TEXT',
      'contract_end_date': 'TEXT',
      'profile_image_url': 'TEXT',
      'profile_image_public_id': 'TEXT',
      'profile_image_folder': 'TEXT',
      'permanent_address': 'TEXT',
      'permanent_city': 'TEXT',
      'permanent_country': 'TEXT',
      'same_as_permanent': 'INTEGER',
      'present_address': 'TEXT',
      'present_city': 'TEXT',
      'present_country': 'TEXT',
      'education_list_json': 'TEXT',
      'experience_list_json': 'TEXT',
      'original_dob': 'TEXT',
      'personal_mobile': 'TEXT',
      'passport_number': 'TEXT',
      'driving_license_number': 'TEXT',
      'driving_license_batch': 'TEXT',
      'health_issues': 'TEXT',
      'emergency_name': 'TEXT',
      'emergency_mobile': 'TEXT',
      'referred_by_name': 'TEXT',
      'referred_by_mobile': 'TEXT',
      'father_name': 'TEXT',
      'mother_name': 'TEXT',
      'marital_status': 'TEXT',
      'spouse_name': 'TEXT',
      'kids1_name': 'TEXT',
      'kids2_name': 'TEXT',
      'kids3_name': 'TEXT',
      'bank_account_type': 'TEXT',
      'document_list_json': 'TEXT',
      'facebook_url': 'TEXT',
      'twitter_url': 'TEXT',
      'linkedin_url': 'TEXT',
      'google_url': 'TEXT',
      'salary_type': 'TEXT',
      'salary_education_allowance': 'REAL',
      'salary_special_allowance': 'REAL',
      'salary_travel_allowance': 'REAL',
      'salary_other_allowance': 'REAL',
      'salary_tax': 'REAL',
      'salary_pf': 'REAL',
      'salary_esi': 'REAL',
      'salary_esi_employer': 'REAL',
      'salary_professional_tax': 'REAL',
      'access_permissions': 'TEXT',
      'leave_type': 'TEXT',
      'leave_allocation_frequency': 'TEXT',
      'allowed_leaves': 'REAL',
      'monthly_leave_allowance': 'REAL DEFAULT 3.0',
      'monthly_permission_limit_hours': 'REAL DEFAULT 3.0',
      'daily_permission_limit_hours': 'REAL DEFAULT 1.0',
      'effective_date': 'TEXT',
      'in_time': 'TEXT',
      'out_time': 'TEXT',
      'reporting_manager_title': 'TEXT',
      'admin_name': 'TEXT',
      'coordinator_name': 'TEXT',
      'coordinator_phone': 'TEXT',
      'weekly_off_day': 'TEXT',
      'required_working_hours': 'REAL DEFAULT 9.0',
      'is_static_employee': 'INTEGER DEFAULT 0',
      'is_dynamic_employee': 'INTEGER DEFAULT 0',
      'site_latitude': 'REAL DEFAULT 0.0',
      'site_longitude': 'REAL DEFAULT 0.0',
      'site_allowed_radius_meters': 'INTEGER DEFAULT 15',
      'site_require_gps_verification': 'INTEGER DEFAULT 1',
      'has_criminal_cases': 'INTEGER DEFAULT 0',
      'criminal_case_details': 'TEXT',
    };

    for (final entry in requiredColumns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute('ALTER TABLE employees ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
  }

  Future<void> _seedSampleData(Database db) async {
    // Sample data seeding disabled
  }

  Future<void> _migrateLegacyAttendanceFlags(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(employees)');
    final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();
    if (existingColumns.contains('is_site_employee') &&
        existingColumns.contains('is_static_employee') &&
        existingColumns.contains('is_dynamic_employee')) {
      await db.execute('''
        UPDATE employees
        SET
          is_static_employee = CASE WHEN IFNULL(is_site_employee, 0) = 0 THEN 1 ELSE 0 END,
          is_dynamic_employee = CASE WHEN IFNULL(is_site_employee, 0) = 1 THEN 1 ELSE 0 END
        WHERE is_site_employee IS NOT NULL
      ''');
    }

    if (existingColumns.contains('is_static_employee') && existingColumns.contains('is_dynamic_employee')) {
      await db.execute('''
        UPDATE employees
        SET
          is_static_employee = CASE WHEN (IFNULL(in_time, '') != '' OR IFNULL(out_time, '') != '') THEN 1 ELSE 0 END,
          is_dynamic_employee = CASE WHEN (IFNULL(in_time, '') != '' OR IFNULL(out_time, '') != '') THEN 0 ELSE 1 END
        WHERE (IFNULL(is_static_employee, 0) = 1 AND IFNULL(is_dynamic_employee, 0) = 1)
           OR (IFNULL(is_static_employee, 0) = 0 AND IFNULL(is_dynamic_employee, 0) = 0)
      ''');
    }
  }

  @override
  Future<List<Employee>> getEmployees() async {
    final db = await database;
    final maps = await db.query('employees', orderBy: 'id DESC');
    final allEmps = maps.map((map) => Employee.fromMap(map)).toList();
    final result = <Employee>[];
    for (final emp in allEmps) {
      final s = emp.status.trim().toLowerCase();
      final empIdUpper = emp.employeeId.trim().toUpperCase();
      final isFullEmployee = empIdUpper.startsWith('EMP-');
      if (s == 'active' || s == 'converted' || s == 'submitted' || isFullEmployee) {
        var updatedEmp = emp;
        if (!isFullEmployee) {
          final newEmpId = await _generateNextEmployeeId();
          updatedEmp = emp.copyWith(employeeId: newEmpId, status: 'Active');
          await db.update('employees', updatedEmp.toMap(), where: 'id = ?', whereArgs: [emp.id]);
        } else if (emp.status.trim().toLowerCase() == 'draft' || (emp.status != 'Active' && emp.status != 'ACTIVE')) {
          updatedEmp = emp.copyWith(status: 'Active');
          await db.update('employees', updatedEmp.toMap(), where: 'id = ?', whereArgs: [emp.id]);
        }
        result.add(updatedEmp);
      }
    }
    return result;
  }

  @override
  Future<List<Employee>> getAllEmployees() async {
    final db = await database;
    final maps = await db.query('employees', orderBy: 'id DESC');
    return maps.map((map) => Employee.fromMap(map)).toList();
  }

  @override
  Future<Employee?> getEmployeeById(int id) async {
    final db = await database;
    final maps = await db.query('employees', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  @override
  Future<Employee> addEmployee(Employee employee) async {
    final db = await database;
    var empId = employee.employeeId;
    final empIdUpper = empId.trim().toUpperCase();
    if (empIdUpper.isEmpty ||
        empIdUpper.startsWith('CAN-') ||
        empIdUpper.startsWith('PENDING_') ||
        empIdUpper.startsWith('REG-') ||
        !empIdUpper.startsWith('EMP-')) {
      empId = await _generateNextEmployeeId();
    }
    final newEmp = employee.copyWith(employeeId: empId, status: 'Active');
    final id = await db.insert('employees', newEmp.toMap());
    return newEmp.copyWith(id: id);
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    final db = await database;
    var emp = employee;
    final empIdUpper = emp.employeeId.trim().toUpperCase();
    if (emp.status.toLowerCase() == 'active' &&
        (empIdUpper.isEmpty ||
         empIdUpper.startsWith('CAN-') ||
         empIdUpper.startsWith('PENDING_') ||
         empIdUpper.startsWith('REG-') ||
         !empIdUpper.startsWith('EMP-'))) {
      final newEmpId = await _generateNextEmployeeId();
      emp = emp.copyWith(employeeId: newEmpId);
    }
    await db.update(
      'employees',
      emp.toMap(),
      where: 'id = ?',
      whereArgs: [emp.id],
    );
  }

  @override
  Future<void> updateBulkLeavePolicy({
    required List<int> employeeIds,
    required String leaveType,
    required double allowedLeaves,
    required String leaveAllocationFrequency,
    required bool requiresLeaveApproval,
    String? effectiveDate,
  }) async {
    final db = await database;
    final batch = db.batch();
    final updateData = <String, dynamic>{
      'leave_type': leaveType,
      'allowed_leaves': allowedLeaves,
      'leave_allocation_frequency': leaveAllocationFrequency,
      'requires_leave_approval': requiresLeaveApproval ? 1 : 0,
    };
    if (effectiveDate != null && effectiveDate.isNotEmpty) {
      updateData['effective_date'] = effectiveDate;
    }

    for (final id in employeeIds) {
      batch.update(
        'employees',
        updateData,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteEmployee(int id) async {
    final db = await database;
    await db.delete(
      'employees',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<EmployeePhotoAsset> uploadEmployeeProfileImage({
    required String employeeId,
    required String role,
    required Uint8List imageBytes,
    required String fileName,
    required String mimeType,
  }) async {
    final base64Str = base64Encode(imageBytes);
    final dataUri = 'data:$mimeType;base64,$base64Str';
    return EmployeePhotoAsset(
      url: dataUri,
      publicId: 'local_${DateTime.now().millisecondsSinceEpoch}',
      folder: 'employee_management/profiles/$role/$employeeId',
    );
  }

  @override
  Future<RegistrationLink> createRegistrationLink({
    required String generatedBy,
    String? organizationName,
    String? department,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final linkId = 'link_${now.millisecondsSinceEpoch}';
    final generatedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);
    final expiryDate = DateFormat('yyyy-MM-dd HH:mm').format(now.add(const Duration(days: 7)));

    final link = RegistrationLink(
      id: 0,
      linkId: linkId,
      generatedBy: generatedBy,
      generatedDate: generatedDate,
      expiryDate: expiryDate,
      linkStatus: 'Pending',
      organizationName: organizationName ?? 'iGreen Tech',
      department: department ?? 'Management',
    );

    final id = await db.insert('registration_links', link.toMap());
    return link.copyWith(id: id);
  }

  @override
  Future<List<RegistrationLink>> getRegistrationLinks() async {
    final db = await database;
    final maps = await db.query('registration_links', orderBy: 'id DESC');
    final rawLinks = maps.map((map) => RegistrationLink.fromMap(map)).toList();
    final links = <RegistrationLink>[];
    final now = DateTime.now();

    for (final link in rawLinks) {
      if (link.linkStatus.trim().toLowerCase() == 'pending' && link.expiryDate.isNotEmpty) {
        final expiry = DateTime.tryParse(link.expiryDate);
        if (expiry != null && now.isAfter(expiry)) {
          await db.delete(
            'registration_links',
            where: 'id = ? OR link_id = ?',
            whereArgs: [link.id, link.linkId],
          );
          continue;
        }
      }
      links.add(link);
    }


    try {
      final responsesMaps = await db.query('candidate_responses');
      final existingIds = links.map((l) => l.linkId).toSet();
      final existingEmpIds = links.map((l) => l.employeeId).toSet();

      for (final rMap in responsesMaps) {
        final candResp = CandidateResponse.fromMap(rMap);
        final s = candResp.status.toLowerCase();
        if (s != 'converted' && s != 'registered') {
          if (!existingIds.contains(candResp.linkId) && !existingEmpIds.contains(candResp.candidateId)) {
            links.add(RegistrationLink(
              id: candResp.id,
              linkId: candResp.linkId.isNotEmpty ? candResp.linkId : candResp.candidateId,
              generatedBy: 'Candidate',
              generatedDate: candResp.submittedDate,
              expiryDate: '',
              linkStatus: candResp.status,
              employeeName: candResp.employeeData.fullName,
              employeeId: candResp.candidateId,
              organizationName: candResp.employeeData.organizationName,
              department: candResp.employeeData.department,
              submittedDate: candResp.submittedDate,
              submittedBy: candResp.employeeData.fullName,
            ));
          }
        }
      }
    } catch (_) {}

    return links;
  }

  @override
  Future<RegistrationLink?> getRegistrationLinkById(String linkId) async {
    final db = await database;
    final maps = await db.query(
      'registration_links',
      where: 'link_id = ? OR employee_id = ?',
      whereArgs: [linkId, linkId],
    );
    if (maps.isNotEmpty) {
      final link = RegistrationLink.fromMap(maps.first);
      if (link.linkStatus.trim().toLowerCase() == 'pending' && link.expiryDate.isNotEmpty) {
        final expiry = DateTime.tryParse(link.expiryDate);
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          await db.delete(
            'registration_links',
            where: 'id = ? OR link_id = ?',
            whereArgs: [link.id, link.linkId],
          );
          return null;
        }
      }
      return link;
    }

    final respMaps = await db.query(
      'candidate_responses',
      where: 'link_id = ? OR candidate_id = ?',
      whereArgs: [linkId, linkId],
    );
    if (respMaps.isNotEmpty) {
      final resp = CandidateResponse.fromMap(respMaps.first);
      return RegistrationLink(
        id: resp.id,
        linkId: resp.linkId.isNotEmpty ? resp.linkId : resp.candidateId,
        generatedBy: 'Candidate',
        generatedDate: resp.submittedDate,
        expiryDate: '',
        linkStatus: resp.status,
        employeeName: resp.employeeData.fullName,
        employeeId: resp.candidateId,
        organizationName: resp.employeeData.organizationName,
        department: resp.employeeData.department,
        submittedDate: resp.submittedDate,
        submittedBy: resp.employeeData.fullName,
      );
    }
    return null;
  }

  @override
  Future<void> updateRegistrationLinkStatus({
    required String linkId,
    required String linkStatus,
  }) async {
    final db = await database;
    final parsedId = int.tryParse(linkId);
    await db.update(
      'registration_links',
      {'link_status': linkStatus},
      where: 'link_id = ? OR id = ?',
      whereArgs: [linkId, parsedId ?? -1],
    );
  }

  @override
  Future<Employee> submitEmployeeRegistration({
    required String linkId,
    required Employee employeeData,
    bool isSubmit = true,
  }) async {
    final db = await database;
    final link = await getRegistrationLinkById(linkId);
    if (link == null) {
      throw Exception('Invalid registration link.');
    }
    final statusLower = link.linkStatus.trim().toLowerCase();
    if (statusLower == 'converted' || statusLower == 'registered') {
      throw Exception('This candidate link has already been converted into an employee.');
    }

    String candidateId = employeeData.employeeId;
    if (candidateId.isEmpty || candidateId.startsWith('pending_') || candidateId.startsWith('EMP-')) {
      candidateId = link.employeeId.isNotEmpty && link.employeeId.startsWith('CAN-')
          ? link.employeeId
          : await _generateNextCandidateId();
    }

    final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final finalEmployee = employeeData.copyWith(
      employeeId: candidateId,
      status: isSubmit ? 'Submitted' : 'Draft',
    );

    final candidateResponse = CandidateResponse(
      candidateId: candidateId,
      linkId: linkId,
      employeeData: finalEmployee,
      submittedDate: isSubmit ? nowStr : '',
      status: isSubmit ? 'Submitted' : 'Draft',
    );

    final existingResponse = await db.query(
      'candidate_responses',
      where: 'candidate_id = ? OR link_id = ?',
      whereArgs: [candidateId, linkId],
    );

    if (existingResponse.isNotEmpty) {
      await db.update(
        'candidate_responses',
        candidateResponse.toMap(),
        where: 'candidate_id = ? OR link_id = ?',
        whereArgs: [candidateId, linkId],
      );
    } else {
      await db.insert('candidate_responses', candidateResponse.toMap());
    }

    // Update Registration Link details
    final updatedLink = link.copyWith(
      linkStatus: isSubmit ? 'Submitted' : link.linkStatus,
      employeeName: finalEmployee.fullName,
      employeeId: candidateId,
      submittedDate: isSubmit ? nowStr : link.submittedDate,
      submittedBy: isSubmit ? finalEmployee.fullName : link.submittedBy,
    );

    await db.update(
      'registration_links',
      updatedLink.toMap(),
      where: 'link_id = ? OR id = ?',
      whereArgs: [link.linkId, link.id],
    );

    return finalEmployee;
  }

  @override
  Future<Employee> submitCandidateRegistration({
    required String linkId,
    required Employee candidateData,
  }) async {
    return submitEmployeeRegistration(
      linkId: linkId,
      employeeData: candidateData,
      isSubmit: true,
    );
  }

  @override
  Future<Employee> convertCandidateToEmployee({
    required String linkId,
    required Employee employeeData,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final empId = (employeeData.employeeId.isNotEmpty && employeeData.employeeId.startsWith('EMP-'))
        ? employeeData.employeeId
        : 'EMP-${timestamp.substring(timestamp.length - 4)}';

    final activeEmployee = employeeData.copyWith(
      employeeId: empId,
      status: 'Active',
      userType: employeeData.userType.isEmpty ? 'EMPLOYEE' : employeeData.userType,
    );

    final savedEmployee = await addEmployee(activeEmployee);

    await updateRegistrationLinkStatus(
      linkId: linkId,
      linkStatus: 'Registered',
    );

    return savedEmployee;
  }


  @override
  Future<CandidateResponse?> getCandidateResponseByLinkId(String linkId) async {
    final db = await database;
    final maps = await db.query(
      'candidate_responses',
      where: 'link_id = ?',
      whereArgs: [linkId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CandidateResponse.fromMap(maps.first);
  }

  @override
  Future<CandidateResponse?> getCandidateResponseByCandidateId(String candidateId) async {
    final db = await database;
    final maps = await db.query(
      'candidate_responses',
      where: 'candidate_id = ?',
      whereArgs: [candidateId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CandidateResponse.fromMap(maps.first);
  }

  @override
  Future<List<CandidateResponse>> getCandidateResponses() async {
    final db = await database;
    final maps = await db.query('candidate_responses');
    return maps.map((map) => CandidateResponse.fromMap(map)).toList();
  }

  /// Generates the next CAN-XXXX candidate ID for registration form submissions.
  /// This sequence is independent from the EMP-XXXX employee ID sequence.
  Future<String> _generateNextCandidateId() async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT candidate_id FROM candidate_responses WHERE candidate_id LIKE ?',
      ['CAN-%'],
    );

    int maxNum = 0;
    for (final map in maps) {
      final code = map['candidate_id'] as String? ?? '';
      final numPart = code.replaceAll(RegExp(r'[^0-9]'), '');
      if (numPart.isNotEmpty) {
        final val = int.tryParse(numPart) ?? 0;
        if (val > maxNum) maxNum = val;
      }
    }

    final nextNum = maxNum + 1;
    return 'CAN-${nextNum.toString().padLeft(4, '0')}';
  }

  /// Generates the next EMP-XXXX employee ID for manually created employees.
  /// Used only by the Employee Management module — do NOT call from registration flow.
  Future<String> _generateNextEmployeeId() async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT employee_id FROM employees WHERE employee_id LIKE ?',
      ['EMP-%'],
    );

    int maxNum = 0;
    for (final map in maps) {
      final code = map['employee_id'] as String? ?? '';
      final numPart = code.replaceAll(RegExp(r'[^0-9]'), '');
      if (numPart.isNotEmpty) {
        final val = int.tryParse(numPart) ?? 0;
        if (val > maxNum) maxNum = val;
      }
    }

    final nextNum = maxNum + 1;
    return 'EMP-${nextNum.toString().padLeft(4, '0')}';
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('employees');
    await db.delete('registration_links');
    await db.delete('candidate_responses');
  }

  @override
  Future<ColumnPreference?> getColumnPreference(String tableId) async {
    final db = await database;
    final maps = await db.query(
      'column_preferences',
      where: 'table_id = ?',
      whereArgs: [tableId],
    );
    if (maps.isEmpty) return null;
    return ColumnPreference.fromMap(maps.first);
  }

  @override
  Future<void> saveColumnPreference(ColumnPreference preference) async {
    final db = await database;
    await db.insert(
      'column_preferences',
      preference.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
