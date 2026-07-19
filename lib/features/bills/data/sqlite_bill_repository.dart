import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/bill.dart';
import '../domain/bill_repository.dart';

class SqliteBillRepository implements BillRepository {
  Database? _database;
  Future<Database> get _db async => _database ??= await openDatabase(
    p.join(await getDatabasesPath(), 'igreen_bills.db'), version: 1,
    onCreate: (db, _) async {
      await db.execute('CREATE TABLE bills(id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL, vendor_name TEXT NOT NULL, date TEXT NOT NULL, due_date TEXT NOT NULL, reference TEXT NOT NULL, status TEXT NOT NULL, amount REAL NOT NULL)');
      await _seed(db);
    },
  );

  static Future<void> _seed(Database db) async {
    const rows = [
      ['858', 'Chennai Seals And Spares', '2025-08-12', 3599.00],
      ['1541/25-26', 'Immanuel heat treater', '2025-08-06', 319.20],
      ['3126/2025-26', 'M K Enterprises', '2025-08-06', 1080.06],
      ['1492/25-26', 'Immanuel heat treater', '2025-08-02', 1332.80],
      ['670', 'Oxald India Gases Pvt Ltd', '2025-07-29', 1200.06],
      ['695', 'Oxald India Gases Pvt Ltd', '2025-07-31', 400.02],
      ['523', 'Abirami Engineering Work', '2025-07-19', 960.00],
      ['SPTSR03140/25-26/25-26', 'SHRIMMA POWER TOOLS', '2025-07-19', 340.00],
      ['GST/8950/25-26', 'SIVAGAMI TRADERS', '2025-07-21', 22280.76],
    ];
    for (final r in rows) {
      await db.insert('bills', {'number': r[0], 'vendor_name': r[1], 'date': r[2], 'due_date': r[2], 'reference': '', 'status': 'DRAFT', 'amount': r[3]});
    }
  }

  @override Future<List<Bill>> getBills() async => (await (await _db).query('bills', orderBy: 'date DESC, id DESC')).map((r) => Bill(id: r['id'] as int, number: r['number'] as String, vendorName: r['vendor_name'] as String, date: DateTime.parse(r['date'] as String), dueDate: DateTime.parse(r['due_date'] as String), reference: r['reference'] as String, status: r['status'] as String, amount: (r['amount'] as num).toDouble())).toList(growable: false);
  @override Future<void> addBill(BillDraft bill) async => (await _db).insert('bills', {'number': bill.number, 'vendor_name': bill.vendorName, 'date': bill.date.toIso8601String(), 'due_date': bill.dueDate.toIso8601String(), 'reference': bill.reference, 'status': 'DRAFT', 'amount': bill.amount});
  @override Future<void> deleteBill(int id) async => (await _db).delete('bills', where: 'id = ?', whereArgs: [id]);
}
