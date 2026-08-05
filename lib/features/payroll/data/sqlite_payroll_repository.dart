import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/payroll.dart';
import '../domain/payroll_repository.dart';

class SqlitePayrollRepository implements PayrollRepository {
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
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _upgradeTables(db);
      },
      onOpen: (db) async {
        await _createTables(db);
        await _upgradeTables(db);
      },
    );

    await _seedDefaultSettingsAndMockData(db);
    return db;
  }

  Future<void> _upgradeTables(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(payroll_records)');
    final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();

    final requiredColumns = {
      'loan_description': 'TEXT DEFAULT ""',
      'advance_description': 'TEXT DEFAULT ""',
      'is_disputed': 'INTEGER DEFAULT 0',
      'dispute_comment': 'TEXT DEFAULT ""',
      'greeting': 'REAL DEFAULT 0.0',
    };

    for (final entry in requiredColumns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute('ALTER TABLE payroll_records ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payroll_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        employee_name TEXT,
        month TEXT,
        present_days INTEGER,
        late_days INTEGER,
        absent_days INTEGER,
        leave_days INTEGER,
        designation TEXT,
        department TEXT,
        email_id TEXT,
        pan_number TEXT,
        pf_number TEXT,
        esi_number TEXT,
        bank_name TEXT,
        bank_acct_no TEXT,
        branch TEXT,
        ifsc_code TEXT,
        basic_pay REAL,
        hra REAL,
        education_allowance REAL,
        special_allowance REAL,
        incentive REAL,
        carry_forward TEXT,
        others_earning REAL,
        cumulative_incentive REAL,
        pf REAL,
        tax REAL,
        esi REAL,
        lop REAL,
        company_loan REAL,
        salary_advance REAL,
        others_deduction REAL,
        staff_welfare_contribution REAL,
        greeting REAL,
        net_salary REAL,
        status TEXT,
        payment_date TEXT,
        payment_method TEXT,
        loan_description TEXT,
        advance_description TEXT,
        is_disputed INTEGER,
        dispute_comment TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payroll_settings (
        id INTEGER PRIMARY KEY,
        penalty_per_late_day REAL,
        allowed_late_days INTEGER,
        working_days_in_month REAL,
        pf_percentage REAL,
        tax_percentage REAL,
        professional_tax_percentage REAL,
        payroll_cutoff_day INTEGER,
        payment_day INTEGER
      )
    ''');
  }

  Future<void> _seedDefaultSettingsAndMockData(Database db) async {
    // 1. Seed Settings
    final settingsList = await db.query('payroll_settings', where: 'id = 1');
    if (settingsList.isEmpty) {
      await db.insert('payroll_settings', {
        'id': 1,
        'penalty_per_late_day': 0.5,
        'allowed_late_days': 3,
        'working_days_in_month': 30.0,
        'pf_percentage': 12.0,
        'tax_percentage': 10.0,
        'professional_tax_percentage': 2.0,
        'payroll_cutoff_day': 20,
        'payment_day': 5,
      });
    }

    // 2. Clear out legacy payroll records to update the structure
    // Check if we need to seed the exact screenshot data
    final hasExactMock = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM payroll_records WHERE employee_name = 'Ganesh Chandra Das'"),
    );

    if (hasExactMock == 0 || hasExactMock == null) {
      // Re-seed mock data
      await db.delete('payroll_records');

      // Insert exact screenshot data
      await db.insert('payroll_records', {
        'employee_id': 6,
        'employee_name': 'Ganesh Chandra Das',
        'month': 'June 2026',
        'present_days': 27,
        'late_days': 0,
        'absent_days': 0,
        'leave_days': 3,
        'designation': 'Bore Path Specialist',
        'department': 'Execution',
        'email_id': 'ganeshsavita8056338@gmail.com',
        'pan_number': 'ANAPG6040R',
        'pf_number': '101325736568',
        'esi_number': '',
        'bank_name': 'Axis Bank',
        'bank_acct_no': '920010047315532',
        'branch': 'Ram Nagar Madipakkam',
        'ifsc_code': 'UTIB0003876',
        'basic_pay': 33500.0,
        'hra': 16750.0,
        'education_allowance': 0.0,
        'special_allowance': 16750.0,
        'incentive': 8880.0,
        'carry_forward': '-',
        'others_earning': 3000.0,
        'cumulative_incentive': 31067.0,
        'pf': 1800.0,
        'tax': 0.0,
        'esi': 0.0,
        'lop': 0.0,
        'company_loan': 20000.0,
        'salary_advance': 12200.0,
        'others_deduction': 3392.0,
        'staff_welfare_contribution': 0.0,
        'net_salary': 72555.0,
        'status': 'Paid',
        'payment_date': '05-07-2026',
        'payment_method': 'Bank Transfer',
      });

      // Insert other standard mocks for other employees
      await db.insert('payroll_records', {
        'employee_id': 101,
        'employee_name': 'Ariya Vasanth',
        'month': 'June 2026',
        'present_days': 26,
        'late_days': 2,
        'absent_days': 0,
        'leave_days': 2,
        'designation': 'Senior Flutter Engineer',
        'department': 'Product Development',
        'email_id': 'ariya@example.com',
        'pan_number': 'ABCDE1234F',
        'pf_number': '100827364512',
        'esi_number': '3109827364',
        'bank_name': 'HDFC Bank',
        'bank_acct_no': '50100234567890',
        'branch': 'Adyar Chennai',
        'ifsc_code': 'HDFC0000005',
        'basic_pay': 35000.0,
        'hra': 15000.0,
        'education_allowance': 0.0,
        'special_allowance': 8000.0,
        'incentive': 2000.0,
        'carry_forward': '-',
        'others_earning': 0.0,
        'cumulative_incentive': 0.0,
        'pf': 4200.0,
        'tax': 2500.0,
        'esi': 0.0,
        'lop': 0.0,
        'company_loan': 0.0,
        'salary_advance': 0.0,
        'others_deduction': 200.0,
        'staff_welfare_contribution': 0.0,
        'net_salary': 53100.0,
        'status': 'Paid',
        'payment_date': '05-07-2026',
        'payment_method': 'Bank Transfer',
      });

      await db.insert('payroll_records', {
        'employee_id': 6,
        'employee_name': 'Ganesh Chandra Das',
        'month': 'August 2026',
        'present_days': 27,
        'late_days': 0,
        'absent_days': 0,
        'leave_days': 3,
        'designation': 'Bore Path Specialist',
        'department': 'Execution',
        'email_id': 'ganeshsavita8056338@gmail.com',
        'pan_number': 'ANAPG6040R',
        'pf_number': '101325736568',
        'esi_number': '',
        'bank_name': 'Axis Bank',
        'bank_acct_no': '920010047315532',
        'branch': 'Ram Nagar Madipakkam',
        'ifsc_code': 'UTIB0003876',
        'basic_pay': 33500.0,
        'hra': 16750.0,
        'education_allowance': 0.0,
        'special_allowance': 16750.0,
        'incentive': 0.0,
        'carry_forward': '-',
        'others_earning': 0.0,
        'cumulative_incentive': 31067.0,
        'pf': 1800.0,
        'tax': 0.0,
        'esi': 0.0,
        'lop': 0.0,
        'company_loan': 0.0,
        'salary_advance': 0.0,
        'others_deduction': 200.0,
        'staff_welfare_contribution': 0.0,
        'net_salary': 65000.0,
        'status': 'Processed',
        'payment_date': '',
        'payment_method': 'Bank Transfer',
      });
    }
  }

  @override
  Future<List<PayrollRecord>> getPayrollRecordsForMonth(String month) async {
    final db = await database;
    final res = await db.query(
      'payroll_records',
      where: 'month = ?',
      whereArgs: [month],
    );
    return res.map((r) => PayrollRecord.fromMap(r)).toList();
  }

  @override
  Future<List<PayrollRecord>> getAllPayrollRecords() async {
    final db = await database;
    final res = await db.query('payroll_records');
    return res.map((r) => PayrollRecord.fromMap(r)).toList();
  }

  @override
  Future<PayrollRecord?> getPayrollRecordById(int id) async {
    final db = await database;
    final res = await db.query(
      'payroll_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (res.isEmpty) return null;
    return PayrollRecord.fromMap(res.first);
  }

  @override
  Future<PayrollRecord?> getPayrollRecordForEmployee(int employeeId, String month) async {
    final db = await database;
    final res = await db.query(
      'payroll_records',
      where: 'employee_id = ? AND month = ?',
      whereArgs: [employeeId, month],
    );
    if (res.isEmpty) return null;
    return PayrollRecord.fromMap(res.first);
  }

  @override
  Future<PayrollRecord> savePayrollRecord(PayrollRecord record) async {
    final db = await database;
    final map = record.toMap();

    if (record.companyLoan > 0 && record.loanDescription.isNotEmpty) {
      final loanId = record.loanDescription.trim();
      final loanMaps = await db.query('employee_loans', where: 'loan_id = ?', whereArgs: [loanId]);
      if (loanMaps.isNotEmpty) {
        final currentBal = (loanMaps.first['remaining_balance'] as num?)?.toDouble() ?? 0.0;
        final currentStatus = loanMaps.first['status'] as String? ?? 'Active';

        final newBalance = (currentBal - record.companyLoan).clamp(0.0, double.infinity);
        final newStatus = newBalance <= 0 ? 'Closed' : currentStatus;

        await db.update(
          'employee_loans',
          {
            'remaining_balance': newBalance,
            'status': newStatus,
          },
          where: 'loan_id = ?',
          whereArgs: [loanId],
        );
      }
    }

    if (record.id != 0) {
      await db.update(
        'payroll_records',
        map,
        where: 'id = ?',
        whereArgs: [record.id],
      );
      return record;
    } else {
      final id = await db.insert('payroll_records', map);
      return record.copyWith(id: id);
    }
  }

  @override
  Future<void> deletePayrollRecord(int id) async {
    final db = await database;
    await db.delete(
      'payroll_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<PayrollSettings> getPayrollSettings() async {
    final db = await database;
    final res = await db.query(
      'payroll_settings',
      where: 'id = 1',
    );
    if (res.isEmpty) return const PayrollSettings();
    return PayrollSettings.fromMap(res.first);
  }

  @override
  Future<void> savePayrollSettings(PayrollSettings settings) async {
    final db = await database;
    await db.update(
      'payroll_settings',
      settings.toMap(),
      where: 'id = 1',
    );
  }

  @override
  Future<List<PayrollRecord>> getPayrollRecordsForEmployee(int employeeId) async {
    final db = await database;
    final res = await db.query(
      'payroll_records',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'id DESC',
    );
    return res.map((r) => PayrollRecord.fromMap(r)).toList();
  }
}
