import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/expense.dart';
import '../domain/expense_repository.dart';

class SqliteExpenseRepository implements ExpenseRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await openDatabase(
    p.join(await getDatabasesPath(), 'igreen_expenses.db'),
    version: 1,
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, account TEXT NOT NULL, reference TEXT NOT NULL, vendor TEXT NOT NULL, paid_through TEXT NOT NULL, customer TEXT NOT NULL, status TEXT NOT NULL, amount REAL NOT NULL)',
      );
      await _seed(db);
    },
  );

  static Future<void> _seed(Database db) async {
    const rows = [
      ['2025-07-30', 'Transportation Expense', 'CRN1877635213', '', 'iGreen Technologies', '1150'],
      ['2025-07-30', 'Transportation Expense', 'CRN1862036124', 'Porter', 'iGreen Technologies', '1800'],
      ['2025-07-30', 'Transportation Expense', 'CRN1339007739', 'Porter', 'iGreentec Engineering India Pvt Ltd', '1000'],
      ['2025-07-30', 'Milk&snacks', '4997', 'Local Shops', 'iGreentec Engineering India Pvt Ltd', '300'],
      ['2025-07-30', 'Fuel', '', 'Local Shops', 'iGreentec Engineering India Pvt Ltd', '200'],
      ['2025-07-12', 'Milk&snacks', '', 'Local Shops', 'iGreentec Engineering India Pvt Ltd', '800'],
      ['2025-07-12', 'purchases', '', 'Local Shops', 'iGreentec Engineering India Pvt Ltd', '40'],
      ['2025-07-08', 'Fuel', '', 'Local Shops', 'iGreentec Engineering India Pvt Ltd', '220'],
      ['2025-07-08', 'Factory Expenses', '4976', 'Local Shops', 'iGreentec Engineering India Pvt Ltd', '1280'],
      ['2025-07-07', 'Factory Expenses', '4975', 'Local Shops', 'iGreentec Engineering India Pvt Ltd', '11445'],
      ['2025-07-01', 'Milk&snacks', '', '', 'iGreentec Engineering India Pvt Ltd', '330'],
    ];
    for (final row in rows) {
      await db.insert('expenses', {
        'date': row[0],
        'account': row[1],
        'reference': row[2],
        'vendor': row[3],
        'paid_through': 'Petty Cash',
        'customer': row[4],
        'status': 'NON-BILLABLE',
        'amount': double.parse(row[5]),
      });
    }
  }

  @override
  Future<List<Expense>> getExpenses() async =>
      (await (await _db).query('expenses', orderBy: 'date DESC, id ASC'))
          .map(_fromRow)
          .toList(growable: false);

  Expense _fromRow(Map<String, Object?> row) => Expense(
    id: row['id'] as int,
    date: DateTime.parse(row['date'] as String),
    account: row['account'] as String,
    reference: row['reference'] as String,
    vendor: row['vendor'] as String,
    paidThrough: row['paid_through'] as String,
    customer: row['customer'] as String,
    status: row['status'] as String,
    amount: (row['amount'] as num).toDouble(),
  );

  @override
  Future<void> addExpense({
    required DateTime date,
    required String account,
    required String reference,
    required String vendor,
    required String paidThrough,
    required String customer,
    required String status,
    required double amount,
  }) async {
    await (await _db).insert('expenses', {
      'date': date.toIso8601String(),
      'account': account,
      'reference': reference,
      'vendor': vendor,
      'paid_through': paidThrough,
      'customer': customer,
      'status': status,
      'amount': amount,
    });
  }
}

