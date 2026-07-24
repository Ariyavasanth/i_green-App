import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/column_preference.dart';
import '../domain/department.dart';
import '../domain/organization.dart';
import '../domain/organization_repository.dart';

class SqliteOrganizationRepository implements OrganizationRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'igreen_organization.db');
    return await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE departments ADD COLUMN organization_name TEXT NOT NULL DEFAULT ''",
          );
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE organizations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            business_type TEXT NOT NULL,
            industry_type TEXT NOT NULL,
            business_units TEXT NOT NULL,
            locations TEXT NOT NULL,
            address TEXT NOT NULL,
            phone_number TEXT NOT NULL,
            email_address TEXT NOT NULL,
            website TEXT NOT NULL,
            tax_id TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE departments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            organization_name TEXT NOT NULL,
            department_name TEXT NOT NULL,
            department_head TEXT NOT NULL,
            reporting_hierarchy TEXT NOT NULL,
            work_location TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE column_preferences (
            table_id TEXT PRIMARY KEY,
            visible_columns TEXT NOT NULL,
            column_order TEXT NOT NULL
          )
        ''');

        await _seed(db);
      },
    );
  }

  static Future<void> _seed(Database db) async {
    final orgs = [
      Organization(
        id: 0,
        name: 'iGreen Technologies',
        businessType: 'Private Limited',
        industryType: 'Information Technology',
        businessUnits: 'Software & Cloud Services',
        locations: 'HQ, Regional Hub',
        address: '100 Tech Park, Suite 400, Tech City',
        phoneNumber: '+1 (800) 555-0199',
        emailAddress: 'info@igreentech.com',
        website: 'https://www.igreentech.com',
        taxId: 'GSTIN33AAACI1234F1Z1',
      ),
      Organization(
        id: 0,
        name: 'iGreentec Engineering India Pvt Ltd',
        businessType: 'Private Limited',
        industryType: 'Manufacturing & Engineering',
        businessUnits: 'Industrial Automation, R&D',
        locations: 'Factory Unit 1, Chennai Office',
        address: '45 Industrial Estate, Guindy, Chennai, TN',
        phoneNumber: '+91 44 2345 6789',
        emailAddress: 'contact@igreentec.in',
        website: 'https://www.igreentec.in',
        taxId: '33AAACI9876E1Z5',
      ),
      Organization(
        id: 0,
        name: 'Acme Global Enterprises',
        businessType: 'Corporation',
        industryType: 'Logistics & Supply Chain',
        businessUnits: 'Freight, Warehousing',
        locations: 'Mumbai Hub, Delhi Branch',
        address: '12 Commercial Street, Fort, Mumbai, MH',
        phoneNumber: '+91 22 8765 4321',
        emailAddress: 'support@acmeglobal.com',
        website: 'https://www.acmeglobal.com',
        taxId: '27AABCA4321D1Z9',
      ),
    ];

    for (final org in orgs) {
      await db.insert('organizations', org.toMap());
    }

    final depts = [
      const Department(
        id: 0,
        organizationName: 'iGreen Technologies',
        departmentName: 'Production',
        departmentHead: 'Robert Chen',
        reportingHierarchy: 'Manager',
        workLocation: 'Factory',
      ),
      const Department(
        id: 0,
        organizationName: 'iGreen Technologies',
        departmentName: 'Sales',
        departmentHead: 'Sarah Jenkins',
        reportingHierarchy: 'Manager',
        workLocation: 'Office',
      ),
      const Department(
        id: 0,
        organizationName: 'iGreentec Engineering India Pvt Ltd',
        departmentName: 'Human Resources (HR)',
        departmentHead: 'Michael Scott',
        reportingHierarchy: 'Manager',
        workLocation: 'Office',
      ),
      const Department(
        id: 0,
        organizationName: 'iGreentec Engineering India Pvt Ltd',
        departmentName: 'Information Technology (IT)',
        departmentHead: 'David Miller',
        reportingHierarchy: 'Supervisor',
        workLocation: 'Office',
      ),
      const Department(
        id: 0,
        organizationName: 'Acme Global Enterprises',
        departmentName: 'Research & Development (R&D)',
        departmentHead: 'Dr. Elena Rostova',
        reportingHierarchy: 'Manager',
        workLocation: 'Remote',
      ),
      const Department(
        id: 0,
        organizationName: 'Acme Global Enterprises',
        departmentName: 'Customer Support',
        departmentHead: 'Priya Sharma',
        reportingHierarchy: 'Supervisor',
        workLocation: 'Office',
      ),
    ];

    for (final dept in depts) {
      await db.insert('departments', dept.toMap());
    }
  }

  // Organizations CRUD
  @override
  Future<List<Organization>> getOrganizations() async {
    final db = await _db;
    final maps = await db.query('organizations', orderBy: 'id ASC');
    return maps.map((map) => Organization.fromMap(map)).toList();
  }

  @override
  Future<void> addOrganization(Organization organization) async {
    final db = await _db;
    await db.insert('organizations', organization.toMap());
  }

  @override
  Future<void> updateOrganization(Organization organization) async {
    final db = await _db;
    await db.update(
      'organizations',
      organization.toMap(),
      where: 'id = ?',
      whereArgs: [organization.id],
    );
  }

  @override
  Future<void> deleteOrganization(int id) async {
    final db = await _db;
    await db.delete('organizations', where: 'id = ?', whereArgs: [id]);
  }

  // Departments CRUD
  @override
  Future<List<Department>> getDepartments() async {
    final db = await _db;
    final maps = await db.query('departments', orderBy: 'id ASC');
    return maps.map((map) => Department.fromMap(map)).toList();
  }

  @override
  Future<void> addDepartment(Department department) async {
    final db = await _db;
    await db.insert('departments', department.toMap());
  }

  @override
  Future<void> updateDepartment(Department department) async {
    final db = await _db;
    await db.update(
      'departments',
      department.toMap(),
      where: 'id = ?',
      whereArgs: [department.id],
    );
  }

  @override
  Future<void> deleteDepartment(int id) async {
    final db = await _db;
    await db.delete('departments', where: 'id = ?', whereArgs: [id]);
  }

  // Column Preference CRUD
  @override
  Future<ColumnPreference?> getColumnPreference(String tableId) async {
    final db = await _db;
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
    final db = await _db;
    await db.insert(
      'column_preferences',
      preference.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
