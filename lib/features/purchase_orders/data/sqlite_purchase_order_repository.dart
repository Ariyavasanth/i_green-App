import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/purchase_order.dart';
import '../domain/purchase_order_repository.dart';

class SqlitePurchaseOrderRepository implements PurchaseOrderRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await openDatabase(
    p.join(await getDatabasesPath(), 'igreen_purchase_orders.db'),
    version: 1,
    onCreate: (db, _) async {
      await db.execute('CREATE TABLE purchase_orders(id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL, vendor_name TEXT NOT NULL, date TEXT NOT NULL, reference TEXT NOT NULL, status TEXT NOT NULL, billed_status TEXT NOT NULL, amount REAL NOT NULL, delivery_date TEXT)');
      await _seed(db);
    },
  );

  static Future<void> _seed(Database db) async {
    const rows = [
      ['PO-00225', 'Shahnaz Bright Steel Industries Pvt Ltd.', '2026-07-14', 18150.76],
      ['PO-00224', 'Shahnaz Bright Steel Industries Pvt Ltd.', '2026-06-20', 17452.20],
      ['PO-00223', 'Shahnaz Bright Steel Industries Pvt Ltd.', '2026-06-10', 53241.60],
      ['PO-00222', 'Balambiga metal finishers', '2026-06-01', 6598.56],
      ['PO-00221', 'Shahnaz Bright Steel Industries Pvt Ltd.', '2026-05-30', 19175.00],
      ['PO-00220', 'Shahnaz Bright Steel Industries Pvt Ltd.', '2026-05-27', 11193.48],
      ['PO-00219', 'FINE ENGINEERING SERVICES', '2026-05-11', 9086.00],
      ['PO-00218', 'Shahnaz Bright Steel Industries Pvt Ltd.', '2026-05-11', 22266.60],
    ];
    for (final row in rows) {
      await db.insert('purchase_orders', {
        'number': row[0], 'vendor_name': row[1], 'date': row[2],
        'reference': '', 'status': 'DRAFT',
        'billed_status': 'YET TO BE BILLED', 'amount': row[3],
      });
    }
  }

  @override
  Future<List<PurchaseOrder>> getPurchaseOrders() async =>
      (await (await _db).query('purchase_orders', orderBy: 'date DESC, id DESC'))
          .map((r) => PurchaseOrder(
                id: r['id'] as int,
                number: r['number'] as String,
                vendorName: r['vendor_name'] as String,
                date: DateTime.parse(r['date'] as String),
                reference: r['reference'] as String,
                status: r['status'] as String,
                billedStatus: r['billed_status'] as String,
                amount: (r['amount'] as num).toDouble(),
                deliveryDate: r['delivery_date'] == null ? null : DateTime.parse(r['delivery_date'] as String),
              ))
          .toList(growable: false);

  @override
  Future<void> addPurchaseOrder(PurchaseOrderDraft draft) async {
    await (await _db).insert('purchase_orders', {
      'number': draft.number, 'vendor_name': draft.vendorName,
      'date': draft.date.toIso8601String(), 'reference': draft.reference,
      'status': 'DRAFT', 'billed_status': 'YET TO BE BILLED',
      'amount': draft.amount, 'delivery_date': draft.deliveryDate?.toIso8601String(),
    });
  }

  @override
  Future<void> deletePurchaseOrder(int id) async =>
      (await _db).delete('purchase_orders', where: 'id = ?', whereArgs: [id]);
}
