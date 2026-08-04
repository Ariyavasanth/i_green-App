import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/employee_loan.dart';
import '../domain/loan_repository.dart';

class SqliteLoanRepository implements LoanRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _createTables(_database!);
    await _seedEmployeesAndLoans(_database!);
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
      onOpen: (db) async {
        await _createTables(db);
      },
    );

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
        salary_allowances REAL,
        salary_tax REAL,
        salary_pf REAL,
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS employee_loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id TEXT UNIQUE,
        employee_id INTEGER,
        employee_name TEXT,
        employee_custom_id TEXT,
        department TEXT,
        designation TEXT,
        loan_type TEXT,
        loan_amount REAL,
        loan_date TEXT,
        disbursement_date TEXT,
        purpose TEXT,
        installments INTEGER,
        emi_amount REAL,
        first_deduction_month TEXT,
        last_deduction_month TEXT,
        interest_rate REAL,
        total_repayable_amount REAL,
        requested_by TEXT,
        approved_by TEXT,
        approval_date TEXT,
        remarks TEXT,
        status TEXT,
        remaining_balance REAL
      )
    ''');
  }

  Future<void> _seedEmployeesAndLoans(Database db) async {
    // 1. Seed Rahul if not present
    final rahulList = await db.query('employees', where: 'first_name = ?', whereArgs: ['Rahul']);
    int rahulId = 1001; // default seed ID
    if (rahulList.isEmpty) {
      await db.insert('employees', {
        'id': rahulId,
        'employee_id': 'EMP-0001',
        'first_name': 'Rahul',
        'last_name': 'Kumar',
        'email_address': 'rahul@example.com',
        'department': 'Finance',
        'designation': 'Sr. Accountant',
        'status': 'Active',
        'user_type': 'EMPLOYEE',
      });
    } else {
      rahulId = rahulList.first['id'] as int? ?? 1001;
    }

    // 2. Seed Priya if not present
    final priyaList = await db.query('employees', where: 'first_name = ?', whereArgs: ['Priya']);
    int priyaId = 1002; // default seed ID
    if (priyaList.isEmpty) {
      await db.insert('employees', {
        'id': priyaId,
        'employee_id': 'EMP-0002',
        'first_name': 'Priya',
        'last_name': 'Sharma',
        'email_address': 'priya@example.com',
        'department': 'Human Resources',
        'designation': 'Coordinator',
        'status': 'Active',
        'user_type': 'EMPLOYEE',
      });
    } else {
      priyaId = priyaList.first['id'] as int? ?? 1002;
    }

    // 3. Seed Rahul's Active Loan: LN001
    final loan1List = await db.query('employee_loans', where: 'loan_id = ?', whereArgs: ['LN001']);
    if (loan1List.isEmpty) {
      await db.insert('employee_loans', {
        'loan_id': 'LN001',
        'employee_id': rahulId,
        'employee_name': 'Rahul Kumar',
        'employee_custom_id': 'EMP-0001',
        'department': 'Finance',
        'designation': 'Sr. Accountant',
        'loan_type': 'Personal Loan',
        'loan_amount': 50000.0,
        'loan_date': '2026-06-01',
        'disbursement_date': '2026-06-05',
        'purpose': 'Personal Use',
        'installments': 10,
        'emi_amount': 5000.0,
        'first_deduction_month': 'June 2026',
        'last_deduction_month': 'March 2027',
        'interest_rate': 0.0,
        'total_repayable_amount': 50000.0,
        'requested_by': 'Rahul Kumar',
        'approved_by': 'Finance Manager',
        'approval_date': '2026-05-20',
        'remarks': 'Approved and active',
        'status': 'Active',
        'remaining_balance': 20000.0,
      });
    }

    // 4. Seed Priya's Closed Loan: LN002
    final loan2List = await db.query('employee_loans', where: 'loan_id = ?', whereArgs: ['LN002']);
    if (loan2List.isEmpty) {
      await db.insert('employee_loans', {
        'loan_id': 'LN002',
        'employee_id': priyaId,
        'employee_name': 'Priya Sharma',
        'employee_custom_id': 'EMP-0002',
        'department': 'Human Resources',
        'designation': 'Coordinator',
        'loan_type': 'Salary Advance',
        'loan_amount': 20000.0,
        'loan_date': '2026-06-01',
        'disbursement_date': '2026-06-05',
        'purpose': 'Medical Expense',
        'installments': 10,
        'emi_amount': 2000.0,
        'first_deduction_month': 'June 2026',
        'last_deduction_month': 'March 2027',
        'interest_rate': 0.0,
        'total_repayable_amount': 20000.0,
        'requested_by': 'Priya Sharma',
        'approved_by': 'HR Manager',
        'approval_date': '2026-05-18',
        'remarks': 'Fully paid off',
        'status': 'Closed',
        'remaining_balance': 0.0,
      });
    }
  }

  @override
  Future<List<EmployeeLoan>> getAllLoans() async {
    final db = await database;
    final maps = await db.query('employee_loans', orderBy: 'id DESC');
    return maps.map((map) => EmployeeLoan.fromMap(map)).toList();
  }

  @override
  Future<List<EmployeeLoan>> getLoansForEmployee(int employeeId) async {
    final db = await database;
    final maps = await db.query(
      'employee_loans',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'id DESC',
    );
    return maps.map((map) => EmployeeLoan.fromMap(map)).toList();
  }

  @override
  Future<EmployeeLoan?> getLoanById(int id) async {
    final db = await database;
    final maps = await db.query(
      'employee_loans',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return EmployeeLoan.fromMap(maps.first);
  }

  @override
  Future<EmployeeLoan?> getLoanByLoanId(String loanId) async {
    final db = await database;
    final maps = await db.query(
      'employee_loans',
      where: 'loan_id = ?',
      whereArgs: [loanId],
    );
    if (maps.isEmpty) return null;
    return EmployeeLoan.fromMap(maps.first);
  }

  @override
  Future<EmployeeLoan?> getActiveLoanForEmployee(int employeeId, String month) async {
    final db = await database;
    final maps = await db.query(
      'employee_loans',
      where: 'employee_id = ? AND status = ?',
      whereArgs: [employeeId, 'Active'],
    );
    for (final map in maps) {
      final loan = EmployeeLoan.fromMap(map);
      if (isMonthInTerm(month, loan.firstDeductionMonth, loan.lastDeductionMonth)) {
        return loan;
      }
    }
    return null;
  }

  @override
  Future<void> saveLoan(EmployeeLoan loan) async {
    final db = await database;
    await db.insert(
      'employee_loans',
      loan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteLoan(int id) async {
    final db = await database;
    await db.delete(
      'employee_loans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateLoanBalance(String loanId, double deductionAmount) async {
    final db = await database;
    final maps = await db.query('employee_loans', where: 'loan_id = ?', whereArgs: [loanId]);
    if (maps.isNotEmpty) {
      final loan = EmployeeLoan.fromMap(maps.first);
      final newBalance = (loan.remainingBalance - deductionAmount).clamp(0.0, double.infinity);
      final newStatus = newBalance <= 0 ? 'Closed' : loan.status;
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

  @override
  Future<void> changeLoanStatus(int id, String status) async {
    final db = await database;
    await db.update(
      'employee_loans',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  bool isMonthInTerm(String month, String start, String end) {
    final mVal = _parseMonthYear(month);
    final sVal = _parseMonthYear(start);
    final eVal = _parseMonthYear(end);
    if (mVal == null || sVal == null || eVal == null) return false;
    return mVal >= sVal && mVal <= eVal;
  }

  int? _parseMonthYear(String value) {
    try {
      final parts = value.trim().split(' ');
      if (parts.length < 2) return null;
      final monthName = parts[0].toLowerCase();
      final year = int.tryParse(parts[1]) ?? 0;
      final months = [
        'january', 'february', 'march', 'april', 'may', 'june',
        'july', 'august', 'september', 'october', 'november', 'december'
      ];
      final monthIndex = months.indexOf(monthName);
      if (monthIndex == -1) {
        final shortMonths = [
          'jan', 'feb', 'mar', 'apr', 'may', 'jun',
          'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
        ];
        final shortIndex = shortMonths.indexOf(monthName.substring(0, 3));
        if (shortIndex != -1) return year * 12 + shortIndex;
        return null;
      }
      return year * 12 + monthIndex;
    } catch (_) {
      return null;
    }
  }
}
