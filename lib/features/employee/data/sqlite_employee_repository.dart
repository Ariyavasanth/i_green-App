import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../organization/domain/column_preference.dart';
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
        effective_date TEXT,
        requires_leave_approval INTEGER DEFAULT 1,
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
      'effective_date': 'TEXT',
      'in_time': 'TEXT',
      'out_time': 'TEXT',
      'reporting_manager_title': 'TEXT',
      'admin_name': 'TEXT',
      'coordinator_name': 'TEXT',
      'coordinator_phone': 'TEXT',
      'weekly_off_day': 'TEXT',
      'is_static_employee': 'INTEGER DEFAULT 0',
      'is_dynamic_employee': 'INTEGER DEFAULT 0',
      'site_latitude': 'REAL DEFAULT 0.0',
      'site_longitude': 'REAL DEFAULT 0.0',
      'site_allowed_radius_meters': 'INTEGER DEFAULT 15',
      'site_require_gps_verification': 'INTEGER DEFAULT 1',
    };

    for (final entry in requiredColumns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute('ALTER TABLE employees ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
  }

  Future<void> _seedSampleData(Database db) async {
    // Remove sample/dummy employee records and registration links
    await db.delete(
      'employees',
      where: "employee_id IN ('EMP-0001', 'EMP-0002', 'EMP-3006') OR first_name IN ('Saravanan', 'Ariya', 'guna')",
    );
    await db.delete(
      'registration_links',
      where: "employee_name IN ('Saravanan G S', 'Ariya vasanth', 'guna S')",
    );
  }

  Future<void> _migrateLegacyAttendanceFlags(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(employees)');
    final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();
    if (!existingColumns.contains('is_site_employee')) return;
    if (!existingColumns.contains('is_static_employee') || !existingColumns.contains('is_dynamic_employee')) return;

    await db.execute('''
      UPDATE employees
      SET
        is_static_employee = CASE WHEN IFNULL(is_site_employee, 0) = 0 THEN 1 ELSE 0 END,
        is_dynamic_employee = CASE WHEN IFNULL(is_site_employee, 0) = 1 THEN 1 ELSE 0 END
      WHERE is_site_employee IS NOT NULL
    ''');
  }

  @override
  Future<List<Employee>> getEmployees() async {
    final db = await database;
    final maps = await db.query('employees', orderBy: 'id DESC');
    final allEmps = maps.map((map) => Employee.fromMap(map)).toList();
    final result = <Employee>[];
    for (final emp in allEmps) {
      final s = emp.status.trim().toLowerCase();
      if (s == 'active' || s == 'converted' || s == 'submitted') {
        var updatedEmp = emp;
        final empIdUpper = emp.employeeId.trim().toUpperCase();
        if (empIdUpper.isEmpty || !empIdUpper.startsWith('EMP-')) {
          final newEmpId = await _generateNextEmployeeId();
          updatedEmp = emp.copyWith(employeeId: newEmpId, status: 'Active');
          await db.update('employees', updatedEmp.toMap(), where: 'id = ?', whereArgs: [emp.id]);
        } else if (emp.status != 'Active') {
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
    return maps.map((map) => RegistrationLink.fromMap(map)).toList();
  }

  @override
  Future<RegistrationLink?> getRegistrationLinkById(String linkId) async {
    final db = await database;
    final maps = await db.query(
      'registration_links',
      where: 'link_id = ?',
      whereArgs: [linkId],
    );
    if (maps.isEmpty) return null;
    return RegistrationLink.fromMap(maps.first);
  }

  @override
  Future<void> updateRegistrationLinkStatus({
    required String linkId,
    required String linkStatus,
  }) async {
    final db = await database;
    await db.update(
      'registration_links',
      {'link_status': linkStatus},
      where: 'link_id = ?',
      whereArgs: [linkId],
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
    if (link.linkStatus != 'Pending') {
      throw Exception('This registration link has already been used or expired.');
    }

    String newEmpId = employeeData.employeeId;
    if (newEmpId.isEmpty || newEmpId.startsWith('pending_')) {
      newEmpId = link.employeeId.isNotEmpty && link.employeeId.startsWith('EMP-')
          ? link.employeeId
          : await _generateNextCandidateId();
    }

    final tempPassword = employeeData.temporaryPassword.isNotEmpty
        ? employeeData.temporaryPassword
        : _generateRandomCode(10);
    final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final existing = await db.query(
      'employees',
      where: 'employee_id = ?',
      whereArgs: [newEmpId],
    );

    Employee createdEmployee;
    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      final finalEmployee = employeeData.copyWith(
        id: existingId,
        employeeId: newEmpId,
        status: isSubmit ? 'Active' : 'Draft',
        temporaryPassword: tempPassword,
      );
      await db.update(
        'employees',
        finalEmployee.toMap(),
        where: 'id = ?',
        whereArgs: [existingId],
      );
      createdEmployee = finalEmployee;
    } else {
      final finalEmployee = employeeData.copyWith(
        employeeId: newEmpId,
        status: isSubmit ? 'Active' : 'Draft',
        temporaryPassword: tempPassword,
      );
      final empDbId = await db.insert('employees', finalEmployee.toMap());
      createdEmployee = finalEmployee.copyWith(id: empDbId);
    }

    // Update Registration Link details
    final updatedLink = link.copyWith(
      linkStatus: 'Submitted',
      employeeName: createdEmployee.fullName,
      employeeId: newEmpId,
      submittedDate: isSubmit ? nowStr : '',
      submittedBy: isSubmit ? createdEmployee.fullName : '',
    );

    await db.update(
      'registration_links',
      updatedLink.toMap(),
      where: 'id = ?',
      whereArgs: [link.id],
    );

    return createdEmployee;
  }

  /// Generates the next CAN-XXXX candidate ID for registration form submissions.
  /// This sequence is independent from the EMP-XXXX employee ID sequence.
  Future<String> _generateNextCandidateId() async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT employee_id FROM employees WHERE employee_id LIKE ?',
      ['CAN-%'],
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
