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
        street TEXT,
        city TEXT,
        state TEXT,
        postal_code TEXT,
        country TEXT,
        education_degree TEXT,
        education_institution TEXT,
        education_year TEXT,
        education_grade TEXT,
        experience_company TEXT,
        experience_role TEXT,
        experience_years TEXT,
        bank_account_holder TEXT,
        bank_name TEXT,
        bank_account_number TEXT,
        bank_ifsc TEXT,
        bank_branch TEXT,
        pan_number TEXT,
        aadhaar_number TEXT,
        edu_certificates_url TEXT,
        blood_group_report TEXT,
        personal_history_details TEXT,
        salary_basic REAL,
        salary_hra REAL,
        salary_allowances REAL,
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
        temporary_password TEXT
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

  Future<void> _seedSampleData(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM employees'),
    );
    if (count == 0) {
      final sampleEmployees = [
        const Employee(
          id: 1,
          employeeId: 'EMP-0001',
          firstName: 'John',
          lastName: 'Doe',
          emailAddress: 'john.doe@techcorp.com',
          phoneNumber: '+91 98765 43210',
          gender: 'Male',
          dob: '1990-05-15',
          organizationName: 'Acme Corporation',
          department: 'Engineering',
          designation: 'Senior Software Engineer',
          employmentType: 'Full-Time',
          joiningDate: '2023-01-10',
          status: 'Active',
          city: 'Bangalore',
          state: 'Karnataka',
          salaryBasic: 50000,
          salaryHra: 25000,
          salaryAllowances: 15000,
          salaryTotalCtc: 1080000,
        ),
        const Employee(
          id: 2,
          employeeId: 'EMP-0002',
          firstName: 'Jane',
          lastName: 'Smith',
          emailAddress: 'jane.smith@techcorp.com',
          phoneNumber: '+91 98765 43211',
          gender: 'Female',
          dob: '1992-08-22',
          organizationName: 'Global Solutions Inc',
          department: 'Human Resources',
          designation: 'HR Manager',
          employmentType: 'Full-Time',
          joiningDate: '2022-06-01',
          status: 'Active',
          city: 'Mumbai',
          state: 'Maharashtra',
          salaryBasic: 45000,
          salaryHra: 22500,
          salaryAllowances: 12500,
          salaryTotalCtc: 960000,
        ),
        const Employee(
          id: 3,
          employeeId: 'EMP-0003',
          firstName: 'Robert',
          lastName: 'Johnson',
          emailAddress: 'robert.j@techcorp.com',
          phoneNumber: '+91 98765 43212',
          gender: 'Male',
          dob: '1988-12-05',
          organizationName: 'Acme Corporation',
          department: 'Finance',
          designation: 'Financial Analyst',
          employmentType: 'Contract',
          joiningDate: '2023-09-15',
          status: 'Active',
          city: 'Hyderabad',
          state: 'Telangana',
          salaryBasic: 40000,
          salaryHra: 20000,
          salaryAllowances: 10000,
          salaryTotalCtc: 840000,
        ),
      ];

      for (final emp in sampleEmployees) {
        await db.insert('employees', emp.toMap());
      }
    }
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
      status: 'Active',
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
      'SELECT employee_id FROM employees WHERE employee_id LIKE "EMP-%"',
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
