import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/books_repository.dart';

class SqliteBooksRepository implements BooksRepository {
  Database? _database;
  Future<Database> get _db async => _database ??= await openDatabase(
    p.join(await getDatabasesPath(), 'igreen_books.db'),
    version: 2,
    onCreate: (db, _) async {
      // SQL is isolated in this repository so UI code remains backend-agnostic.
      await db.execute(
        'CREATE TABLE items(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, type TEXT NOT NULL DEFAULT "Goods", unit TEXT NOT NULL DEFAULT "pcs", sku TEXT NOT NULL, hsn_code TEXT NOT NULL DEFAULT "", rate REAL NOT NULL, cost_price REAL NOT NULL DEFAULT 0, tax_rate REAL NOT NULL DEFAULT 18, track_inventory INTEGER NOT NULL DEFAULT 0, stock_on_hand REAL NOT NULL DEFAULT 0)',
      );
      await db.execute(
        'CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, company TEXT NOT NULL, email TEXT NOT NULL DEFAULT "", phone TEXT NOT NULL, gst_treatment TEXT NOT NULL, receivables REAL NOT NULL DEFAULT 0)',
      );
      await db.execute(
        'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, number TEXT NOT NULL UNIQUE, customer_id INTEGER, customer TEXT NOT NULL, date TEXT NOT NULL, due_date TEXT, reference_number TEXT NOT NULL DEFAULT "", amount REAL NOT NULL, discount REAL NOT NULL DEFAULT 0, tax_amount REAL NOT NULL DEFAULT 0, amount_paid REAL NOT NULL DEFAULT 0, notes TEXT NOT NULL DEFAULT "", terms TEXT NOT NULL DEFAULT "", status TEXT NOT NULL, FOREIGN KEY(customer_id) REFERENCES customers(id))',
      );
      await db.execute(
        'CREATE TABLE adjustments(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, reason TEXT NOT NULL, description TEXT NOT NULL, status TEXT NOT NULL, reference_number TEXT NOT NULL UNIQUE, type TEXT NOT NULL, created_by TEXT NOT NULL, created_time TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE adjustment_items(id INTEGER PRIMARY KEY AUTOINCREMENT, adjustment_id INTEGER NOT NULL, item_id INTEGER NOT NULL, quantity_adjusted REAL NOT NULL, value_adjusted REAL NOT NULL DEFAULT 0, FOREIGN KEY(adjustment_id) REFERENCES adjustments(id), FOREIGN KEY(item_id) REFERENCES items(id))',
      );
      await _seed(db);
    },
    onUpgrade: (db, oldVersion, _) async {
      if (oldVersion < 2) {
        for (final sql in [
          'ALTER TABLE items ADD COLUMN type TEXT NOT NULL DEFAULT "Goods"',
          'ALTER TABLE items ADD COLUMN unit TEXT NOT NULL DEFAULT "pcs"',
          'ALTER TABLE items ADD COLUMN hsn_code TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE items ADD COLUMN cost_price REAL NOT NULL DEFAULT 0',
          'ALTER TABLE items ADD COLUMN tax_rate REAL NOT NULL DEFAULT 18',
          'ALTER TABLE items ADD COLUMN track_inventory INTEGER NOT NULL DEFAULT 0',
          'ALTER TABLE items ADD COLUMN stock_on_hand REAL NOT NULL DEFAULT 0',
          'ALTER TABLE customers ADD COLUMN email TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE customers ADD COLUMN receivables REAL NOT NULL DEFAULT 0',
          'ALTER TABLE transactions ADD COLUMN customer_id INTEGER',
          'ALTER TABLE transactions ADD COLUMN due_date TEXT',
          'ALTER TABLE transactions ADD COLUMN reference_number TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE transactions ADD COLUMN discount REAL NOT NULL DEFAULT 0',
          'ALTER TABLE transactions ADD COLUMN tax_amount REAL NOT NULL DEFAULT 0',
          'ALTER TABLE transactions ADD COLUMN amount_paid REAL NOT NULL DEFAULT 0',
          'ALTER TABLE transactions ADD COLUMN notes TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE transactions ADD COLUMN terms TEXT NOT NULL DEFAULT ""',
        ]) {
          await db.execute(sql);
        }
        await db.execute(
          'CREATE TABLE adjustments(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, reason TEXT NOT NULL, description TEXT NOT NULL, status TEXT NOT NULL, reference_number TEXT NOT NULL UNIQUE, type TEXT NOT NULL, created_by TEXT NOT NULL, created_time TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE adjustment_items(id INTEGER PRIMARY KEY AUTOINCREMENT, adjustment_id INTEGER NOT NULL, item_id INTEGER NOT NULL, quantity_adjusted REAL NOT NULL, value_adjusted REAL NOT NULL DEFAULT 0)',
        );
      }
    },
  );

  static Future<void> _seed(Database db) async {
    for (final name in [
      'Joint Kit',
      'Tool Holder',
      'End Mill',
      'Fixture',
      'Bore plug Gauge',
      '3 Jaw Chuck',
    ]) {
      await db.insert('items', {
        'name': name,
        'sku': '',
        'rate': 0.0,
        'cost_price': 0.0,
        'track_inventory': 1,
        'stock_on_hand': 10.0,
      });
    }
    for (final name in [
      'NEXORA INFRATECH',
      'Poomari Engineering',
      'Sark Telecom',
      'Indwel Precision Gears Pvt Ltd',
    ]) {
      await db.insert('customers', {
        'name': name,
        'company': name,
        'phone': '',
        'gst_treatment': 'Registered Business - Regular',
      });
    }
    for (final type in TransactionType.values) {
      for (var i = 0; i < 6; i++) {
        await db.insert('transactions', {
          'type': type.name,
          'number': '${type.name}-$i-1450',
          'customer': [
            'iGreen Technologies',
            'RAANCOM',
            'MR ENTERPRISES',
          ][i % 3],
          'date': DateTime(2026, 7, 14 - i).toIso8601String(),
          'amount': 7080.0 * i,
          'status': i.isEven
              ? 'Draft'
              : type == TransactionType.invoice
              ? 'Sent'
              : 'Accepted',
        });
      }
    }
  }

  @override
  Future<List<BookItem>> getItems() async =>
      (await (await _db).query('items', orderBy: 'id DESC'))
          .map(
            (r) => BookItem(
              id: r['id'] as int,
              name: r['name'] as String,
              sku: r['sku'] as String,
              rate: (r['rate'] as num).toDouble(),
              type: r['type'] as String,
              unit: r['unit'] as String,
              hsnCode: r['hsn_code'] as String,
              costPrice: (r['cost_price'] as num).toDouble(),
              taxRate: (r['tax_rate'] as num).toDouble(),
              trackInventory: r['track_inventory'] == 1,
              stockOnHand: (r['stock_on_hand'] as num).toDouble(),
            ),
          )
          .toList();
  @override
  Future<void> addItem({
    required String name,
    String sku = '',
    double rate = 0,
    String type = 'Goods',
  }) async {
    await (await _db).insert('items', {
      'name': name,
      'sku': sku,
      'rate': rate,
      'type': type,
    });
  }

  @override
  Future<List<Customer>> getCustomers() async =>
      (await (await _db).query('customers', orderBy: 'id DESC'))
          .map(
            (r) => Customer(
              id: r['id'] as int,
              name: r['name'] as String,
              company: r['company'] as String,
              email: r['email'] as String,
              phone: r['phone'] as String,
              gstTreatment: r['gst_treatment'] as String,
              receivables: (r['receivables'] as num).toDouble(),
            ),
          )
          .toList();
  @override
  Future<void> addCustomer({
    required String name,
    String company = '',
    String phone = '',
  }) async {
    await (await _db).insert('customers', {
      'name': name,
      'company': company,
      'phone': phone,
      'gst_treatment': 'Registered Business - Regular',
    });
  }

  @override
  Future<List<SalesTransaction>> getTransactions(TransactionType type) async =>
      (await (await _db).query(
            'transactions',
            where: 'type = ?',
            whereArgs: [type.name],
            orderBy: 'date DESC',
          ))
          .map(
            (r) => SalesTransaction(
              id: r['id'] as int,
              type: type,
              number: r['number'] as String,
              customer: r['customer'] as String,
              date: DateTime.parse(r['date'] as String),
              amount: (r['amount'] as num).toDouble(),
              status: r['status'] as String,
            ),
          )
          .toList();
  @override
  Future<void> addTransaction(TransactionDraft d) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'type': d.type.name,
        'number': d.number,
        'customer_id': d.customerId,
        'customer': d.customer,
        'date': d.date.toIso8601String(),
        'due_date': d.dueDate?.toIso8601String(),
        'reference_number': d.referenceNumber,
        'amount': d.amount,
        'discount': d.discount,
        'tax_amount': d.taxAmount,
        'amount_paid': d.amountPaid,
        'notes': d.notes,
        'terms': d.terms,
        'status': 'Draft',
      });
      if (d.type == TransactionType.invoice && d.customerId != null) {
        await txn.rawUpdate(
          'UPDATE customers SET receivables = receivables + ? WHERE id = ?',
          [d.amount, d.customerId],
        );
      }
    });
  }

  @override
  Future<List<InventoryAdjustment>> getAdjustments() async =>
      (await (await _db).query('adjustments', orderBy: 'date DESC'))
          .map(
            (r) => InventoryAdjustment(
              id: r['id'] as int,
              date: DateTime.parse(r['date'] as String),
              reason: r['reason'] as String,
              referenceNumber: r['reference_number'] as String,
              type: r['type'] as String,
              status: r['status'] as String,
              description: r['description'] as String,
            ),
          )
          .toList();
  @override
  Future<void> addAdjustment(AdjustmentDraft d) async {
    final db = await _db;
    await db.transaction((txn) async {
      final id = await txn.insert('adjustments', {
        'date': DateTime.now().toIso8601String(),
        'reason': d.reason,
        'description': d.description,
        'status': d.applyNow ? 'Adjusted' : 'Draft',
        'reference_number': d.referenceNumber,
        'type': 'Quantity',
        'created_by': 'Admin',
        'created_time': DateTime.now().toIso8601String(),
      });
      await txn.insert('adjustment_items', {
        'adjustment_id': id,
        'item_id': d.itemId,
        'quantity_adjusted': d.quantityAdjusted,
        'value_adjusted': 0,
      });
      if (d.applyNow) {
        await txn.rawUpdate(
          'UPDATE items SET stock_on_hand = stock_on_hand + ? WHERE id = ?',
          [d.quantityAdjusted, d.itemId],
        );
      }
    });
  }

  @override
  Future<DashboardMetrics> getDashboardMetrics() async {
    final db = await _db;
    final receivables =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT CAST(COALESCE(SUM(receivables),0) AS INTEGER) FROM customers',
          ),
        )?.toDouble() ??
        0;
    final inventory =
        (await db.rawQuery(
              'SELECT COALESCE(SUM(cost_price * stock_on_hand),0) total FROM items',
            )).first['total']
            as num;
    final invoices =
        (await db.rawQuery(
              'SELECT COALESCE(SUM(amount),0) total FROM transactions WHERE type = ?',
              [TransactionType.invoice.name],
            )).first['total']
            as num;
    final costs =
        (await db.rawQuery(
              'SELECT COALESCE(SUM(cost_price * stock_on_hand),0) total FROM items',
            )).first['total']
            as num;
    final risk =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM items WHERE track_inventory = 1 AND stock_on_hand < 5',
          ),
        ) ??
        0;
    return DashboardMetrics(
      receivables: receivables,
      payables: inventory * .4,
      revenue: invoices.toDouble(),
      netProfit: invoices.toDouble() - costs.toDouble(),
      inventoryAtRisk: risk,
    );
  }

  @override
  Future<void> recordInvoicePaid(int id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ? AND type = ?',
        whereArgs: [id, TransactionType.invoice.name],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      final balance =
          (row['amount'] as num).toDouble() -
          (row['amount_paid'] as num).toDouble();
      await txn.update(
        'transactions',
        {'amount_paid': row['amount'], 'status': 'Paid'},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (row['customer_id'] != null) {
        await txn.rawUpdate(
          'UPDATE customers SET receivables = MAX(0, receivables - ?) WHERE id = ?',
          [balance, row['customer_id']],
        );
      }
    });
  }

  @override
  Future<void> convertQuote(int id, TransactionType targetType) async {
    if (targetType == TransactionType.quote) return;
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ? AND type = ?',
        whereArgs: [id, TransactionType.quote.name],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final q = rows.first;
      await txn.update(
        'transactions',
        {'status': 'Accepted'},
        where: 'id = ?',
        whereArgs: [id],
      );
      final copy = Map<String, Object?>.from(q)..remove('id');
      copy['type'] = targetType.name;
      copy['number'] =
          '${targetType == TransactionType.invoice ? 'INV' : 'SO'}-${DateTime.now().millisecondsSinceEpoch}';
      copy['status'] = 'Draft';
      await txn.insert('transactions', copy);
    });
  }
}
