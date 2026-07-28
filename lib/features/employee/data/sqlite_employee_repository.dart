import 'dart:convert';
import 'dart:math';
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
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onOpen: (db) async {
        await _createTables(db);
        await _ensureColumnsExist(db);
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
        salary_allowances REAL,
        salary_tax REAL,
        salary_pf REAL,
        salary_total_ctc REAL,
        insurance_policy_no TEXT,
        insurance_provider TEXT,
        insurance_coverage REAL,
        pf_number TEXT,
        pf_uan TEXT,
        esi_number TEXT,
        leave_details TEXT,
        company_assets TEXT,
        reporting_manager TEXT,
        team_name TEXT,
        disciplinary_records TEXT,
        temporary_password TEXT,
        access_permissions TEXT,
        leave_type TEXT,
        leave_allocation_frequency TEXT,
        allowed_leaves REAL,
        effective_date TEXT
      )
    ''');

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
      'salary_tax': 'REAL',
      'salary_pf': 'REAL',
      'access_permissions': 'TEXT',
      'leave_type': 'TEXT',
      'leave_allocation_frequency': 'TEXT',
      'allowed_leaves': 'REAL',
      'effective_date': 'TEXT',
    };

    for (final entry in requiredColumns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute('ALTER TABLE employees ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
  }

  Future<void> _seedSampleData(Database db) async {
    final sampleEmployees = [
      const Employee(
        id: 1,
        employeeId: 'EMP-0001',
        firstName: 'Saravanan',
        lastName: 'G S',
        emailAddress: 'Saravanan@igreentec.in',
        phoneNumber: '8760098789',
        gender: 'Male',
        dob: '13-05-1982',
        organizationName: 'iGreen Tech',
        department: 'Management',
        designation: 'Company Director',
        employmentType: 'Full-Time',
        joiningDate: '29-04-2017',
        status: 'Active',
        bloodGroup: 'B+',
        userType: 'ADMIN',
        aadhaarNumber: '833750993144',
        pfNumber: '100338738050',
        city: 'Chennai',
        state: 'Tamil Nadu',
        salaryTotalCtc: 1200000.0,
        leaveType: 'As Needed',
        leaveAllocationFrequency: 'Monthly',
        allowedLeaves: 1.5,
        effectiveDate: '01-01-2026',
      ),
      const Employee(
        id: 2,
        employeeId: 'EMP-0002',
        firstName: 'John',
        lastName: 'Doe',
        emailAddress: 'john.doe@igreentec.in',
        phoneNumber: '9876543210',
        gender: 'Male',
        dob: '15-08-1990',
        organizationName: 'iGreen Tech',
        department: 'Engineering',
        designation: 'Software Engineer',
        employmentType: 'Full-Time',
        joiningDate: '01-06-2022',
        status: 'Active',
        bloodGroup: 'O+',
        userType: 'EMPLOYEE',
        city: 'Bangalore',
        state: 'Karnataka',
        salaryTotalCtc: 600000.0,
        leaveType: 'Once a Month',
        leaveAllocationFrequency: 'Monthly',
        allowedLeaves: 1.0,
        effectiveDate: '01-01-2026',
        accessPermissions: ['Home', 'Leave', 'Loan', 'Pay Slip'],
      ),
      const Employee(
        id: 3,
        employeeId: 'EMP-0003',
        firstName: 'Jane',
        lastName: 'Smith',
        emailAddress: 'jane.smith@igreentec.in',
        phoneNumber: '9123456780',
        gender: 'Female',
        dob: '22-11-1993',
        organizationName: 'iGreen Tech',
        department: 'HR',
        designation: 'HR Executive',
        employmentType: 'Full-Time',
        joiningDate: '15-03-2021',
        status: 'Active',
        bloodGroup: 'A-',
        userType: 'EMPLOYEE',
        city: 'Hyderabad',
        state: 'Telangana',
        salaryTotalCtc: 450000.0,
        leaveType: 'No Leave',
        leaveAllocationFrequency: 'Monthly',
        allowedLeaves: 1.0,
        effectiveDate: '01-01-2026',
        accessPermissions: ['Home', 'Leave', 'Loan', 'Pay Slip'],
      ),
      const Employee(
        id: 4,
        employeeId: 'EMP-9222',
        firstName: 'Employee',
        lastName: '9222',
        emailAddress: 'emp9222@igreentec.in',
        phoneNumber: '9876549222',
        gender: 'Male',
        dob: '10-10-1995',
        organizationName: 'iGreen Tech',
        department: 'Engineering',
        designation: 'Software Engineer',
        employmentType: 'Full-Time',
        joiningDate: '01-01-2026',
        status: 'Active',
        bloodGroup: 'B+',
        userType: 'EMPLOYEE',
        city: 'Chennai',
        state: 'Tamil Nadu',
        salaryTotalCtc: 480000.0,
        leaveType: 'Once a Month',
        leaveAllocationFrequency: 'Monthly',
        allowedLeaves: 1.0,
        effectiveDate: '01-01-2026',
        temporaryPassword: 'Admin@123',
        accessPermissions: ['Leave', 'Loan', 'Pay Slip'],
      ),
    ];

    for (final emp in sampleEmployees) {
      final exists = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM employees WHERE employee_id = ?', [emp.employeeId]),
      ) ?? 0;
      if (exists == 0) {
        final idExists = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM employees WHERE id = ?', [emp.id]),
        ) ?? 0;
        if (idExists > 0) {
          final map = emp.toMap()..remove('id');
          await db.insert('employees', map);
        } else {
          await db.insert('employees', emp.toMap());
        }
      }
    }

    // Ensure EMP-9222 has correct permissions
    await db.rawUpdate(
      'UPDATE employees SET access_permissions = ? WHERE LOWER(employee_id) = ?',
      [jsonEncode(['Leave', 'Loan', 'Pay Slip']), 'emp-9222'],
    );
  }

  @override
  Future<List<Employee>> getEmployees() async {
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
  Future<void> addEmployee(Employee employee) async {
    final db = await database;
    var empId = employee.employeeId;
    if (empId.isEmpty) {
      empId = await _generateNextEmployeeId();
    }
    final newEmp = employee.copyWith(employeeId: empId);
    await db.insert('employees', newEmp.toMap());
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    final db = await database;
    await db.update(
      'employees',
      employee.toMap(),
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  @override
  Future<void> deleteEmployee(int id) async {
    final db = await database;
    await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<RegistrationLink> createRegistrationLink({
    required String generatedBy,
    String? organizationName,
    String? department,
  }) async {
    final db = await database;
    final linkId = _generateRandomCode(8);
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final expiry = now.add(const Duration(days: 7));

    final link = RegistrationLink(
      id: 0,
      linkId: linkId,
      generatedBy: generatedBy.isEmpty ? 'HR Admin' : generatedBy,
      generatedDate: dateFormat.format(now),
      expiryDate: dateFormat.format(expiry),
      linkStatus: 'Pending',
      organizationName: organizationName ?? '',
      department: department ?? '',
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
  Future<Employee> submitEmployeeRegistration({
    required String linkId,
    required Employee employeeData,
  }) async {
    final db = await database;
    final link = await getRegistrationLinkById(linkId);
    if (link == null) {
      throw Exception('Invalid registration link.');
    }
    if (link.linkStatus != 'Pending') {
      throw Exception('This registration link has already been used or expired.');
    }

    final newEmpId = await _generateNextEmployeeId();
    final tempPassword = _generateRandomCode(10);
    final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final finalEmployee = employeeData.copyWith(
      employeeId: newEmpId,
      status: employeeData.status.isEmpty ? 'Pending' : employeeData.status,
      temporaryPassword: tempPassword,
    );

    final empDbId = await db.insert('employees', finalEmployee.toMap());
    final createdEmployee = finalEmployee.copyWith(id: empDbId);

    // Update Registration Link to Completed
    final updatedLink = link.copyWith(
      linkStatus: 'Completed',
      employeeName: createdEmployee.fullName,
      employeeId: newEmpId,
      submittedDate: nowStr,
      submittedBy: createdEmployee.fullName,
    );

    await db.update(
      'registration_links',
      updatedLink.toMap(),
      where: 'id = ?',
      whereArgs: [link.id],
    );

    return createdEmployee;
  }

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
    final row = maps.first;
    final visStr = row['visible_columns'] as String? ?? '';
    final ordStr = row['column_order'] as String? ?? '';

    return ColumnPreference(
      tableId: tableId,
      visibleColumns: visStr.isEmpty ? [] : visStr.split(','),
      columnOrder: ordStr.isEmpty ? [] : ordStr.split(','),
    );
  }

  @override
  Future<void> saveColumnPreference(ColumnPreference preference) async {
    final db = await database;
    await db.insert(
      'column_preferences',
      {
        'table_id': preference.tableId,
        'visible_columns': preference.visibleColumns.join(','),
        'column_order': preference.columnOrder.join(','),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
