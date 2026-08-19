import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/purchase_order.dart';
import '../domain/purchase_order_repository.dart';

class SqlitePurchaseOrderRepository implements PurchaseOrderRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await openDatabase(
        p.join(await getDatabasesPath(), 'igreen_purchase_orders_v3.db'),
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE purchase_orders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              number TEXT NOT NULL UNIQUE,
              vendor_id INTEGER,
              vendor_name TEXT NOT NULL,
              date TEXT NOT NULL,
              reference TEXT,
              status TEXT NOT NULL,
              billed_status TEXT NOT NULL,
              amount REAL NOT NULL,
              delivery_date TEXT,
              delivery_address_type TEXT,
              delivery_address TEXT,
              customer_id INTEGER,
              customer_name TEXT,
              shipment_preference TEXT,
              payment_terms TEXT,
              reverse_charge INTEGER NOT NULL DEFAULT 0,
              notes TEXT,
              terms TEXT,
              sub_total REAL DEFAULT 0,
              discount_type TEXT DEFAULT '%',
              discount_value REAL DEFAULT 0,
              discount_amount REAL DEFAULT 0,
              tax_amount REAL DEFAULT 0,
              tds_rate REAL DEFAULT 0,
              tds_amount REAL DEFAULT 0,
              tcs_rate REAL DEFAULT 0,
              tcs_amount REAL DEFAULT 0,
              round_off REAL DEFAULT 0,
              attachments TEXT,
              created_at TEXT,
              updated_at TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE purchase_order_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              purchase_order_id INTEGER NOT NULL,
              item_id INTEGER,
              item_name TEXT NOT NULL,
              account TEXT,
              quantity REAL NOT NULL,
              unit TEXT,
              rate REAL NOT NULL,
              tax TEXT,
              tax_rate REAL DEFAULT 0,
              amount REAL NOT NULL,
              FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders (id) ON DELETE CASCADE
            )
          ''');

          await _seed(db);
        },
      );

  static Future<void> _seed(Database db) async {
    final rows = [
      ['PO-00225', 'Shahnaz Bright Steel Industries Pvt Ltd.', '2026-07-14', 18150.76, 15382.00, 2768.76],
      ['PO-00224', 'Shahnaz Bright Steel Industries Pvt Ltd.', '2026-06-20', 17452.20, 14790.00, 2662.20],
    ];
    for (final row in rows) {
      final poId = await db.insert('purchase_orders', {
        'number': row[0],
        'vendor_name': row[1],
        'date': row[2],
        'reference': '',
        'status': 'DRAFT',
        'billed_status': 'YET TO BE BILLED',
        'amount': row[3],
        'sub_total': row[4],
        'tax_amount': row[5],
        'reverse_charge': 0,
        'payment_terms': 'Due on Receipt',
        'delivery_address_type': 'Organization',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('purchase_order_items', {
        'purchase_order_id': poId,
        'item_id': 101,
        'item_name': 'Sample Inventory Item',
        'account': 'Cost of Goods Sold',
        'quantity': 1.0,
        'unit': 'pcs',
        'rate': row[4],
        'tax': 'GST 18%',
        'tax_rate': 18.0,
        'amount': row[4],
      });
    }
  }

  @override
  Future<List<PurchaseOrder>> getPurchaseOrders() async {
    final db = await _db;
    final poRows = await db.query('purchase_orders', orderBy: 'date DESC, id DESC');
    final result = <PurchaseOrder>[];

    for (final r in poRows) {
      final id = r['id'] as int;
      final itemRows = await db.query(
        'purchase_order_items',
        where: 'purchase_order_id = ?',
        whereArgs: [id],
      );
      final items = itemRows
          .map((i) => PurchaseOrderItem(
                id: i['id'] as int?,
                purchaseOrderId: i['purchase_order_id'] as int?,
                itemId: i['item_id'] as int?,
                itemName: i['item_name'] as String,
                account: (i['account'] as String?) ?? 'Cost of Goods Sold',
                quantity: (i['quantity'] as num).toDouble(),
                unit: (i['unit'] as String?) ?? 'pcs',
                rate: (i['rate'] as num).toDouble(),
                tax: (i['tax'] as String?) ?? 'GST 18%',
                taxRate: ((i['tax_rate'] as num?) ?? 18.0).toDouble(),
                amount: (i['amount'] as num).toDouble(),
              ))
          .toList();

      final rawAttachments = r['attachments'] as String?;
      final attachments = rawAttachments != null && rawAttachments.isNotEmpty
          ? rawAttachments.split('|')
          : <String>[];

      result.add(PurchaseOrder(
        id: id,
        number: r['number'] as String,
        vendorId: r['vendor_id'] as int?,
        vendorName: r['vendor_name'] as String,
        date: DateTime.parse(r['date'] as String),
        reference: (r['reference'] as String?) ?? '',
        status: (r['status'] as String?) ?? 'DRAFT',
        billedStatus: (r['billed_status'] as String?) ?? 'YET TO BE BILLED',
        amount: (r['amount'] as num).toDouble(),
        deliveryDate: r['delivery_date'] == null ? null : DateTime.tryParse(r['delivery_date'] as String),
        deliveryAddressType: (r['delivery_address_type'] as String?) ?? 'Organization',
        deliveryAddress: (r['delivery_address'] as String?) ?? '',
        customerId: r['customer_id'] as int?,
        customerName: (r['customer_name'] as String?) ?? '',
        shipmentPreference: (r['shipment_preference'] as String?) ?? '',
        paymentTerms: (r['payment_terms'] as String?) ?? 'Due on Receipt',
        reverseCharge: (r['reverse_charge'] as int?) == 1,
        notes: (r['notes'] as String?) ?? '',
        terms: (r['terms'] as String?) ?? '',
        subTotal: ((r['sub_total'] as num?) ?? (r['amount'] as num)).toDouble(),
        discountType: (r['discount_type'] as String?) ?? '%',
        discountValue: ((r['discount_value'] as num?) ?? 0.0).toDouble(),
        discountAmount: ((r['discount_amount'] as num?) ?? 0.0).toDouble(),
        taxAmount: ((r['tax_amount'] as num?) ?? 0.0).toDouble(),
        tdsRate: ((r['tds_rate'] as num?) ?? 0.0).toDouble(),
        tdsAmount: ((r['tds_amount'] as num?) ?? 0.0).toDouble(),
        tcsRate: ((r['tcs_rate'] as num?) ?? 0.0).toDouble(),
        tcsAmount: ((r['tcs_amount'] as num?) ?? 0.0).toDouble(),
        roundOff: ((r['round_off'] as num?) ?? 0.0).toDouble(),
        attachments: attachments,
        createdAt: r['created_at'] == null ? null : DateTime.tryParse(r['created_at'] as String),
        updatedAt: r['updated_at'] == null ? null : DateTime.tryParse(r['updated_at'] as String),
        items: items,
      ));
    }
    return result;
  }

  @override
  Future<PurchaseOrder?> getPurchaseOrderById(int id) async {
    final db = await _db;
    final poRows = await db.query('purchase_orders', where: 'id = ?', whereArgs: [id]);
    if (poRows.isEmpty) return null;
    final r = poRows.first;

    final itemRows = await db.query(
      'purchase_order_items',
      where: 'purchase_order_id = ?',
      whereArgs: [id],
    );
    final items = itemRows
        .map((i) => PurchaseOrderItem(
              id: i['id'] as int?,
              purchaseOrderId: i['purchase_order_id'] as int?,
              itemId: i['item_id'] as int?,
              itemName: i['item_name'] as String,
              account: (i['account'] as String?) ?? 'Cost of Goods Sold',
              quantity: (i['quantity'] as num).toDouble(),
              unit: (i['unit'] as String?) ?? 'pcs',
              rate: (i['rate'] as num).toDouble(),
              tax: (i['tax'] as String?) ?? 'GST 18%',
              taxRate: ((i['tax_rate'] as num?) ?? 18.0).toDouble(),
              amount: (i['amount'] as num).toDouble(),
            ))
        .toList();

    final rawAttachments = r['attachments'] as String?;
    final attachments = rawAttachments != null && rawAttachments.isNotEmpty
        ? rawAttachments.split('|')
        : <String>[];

    return PurchaseOrder(
      id: id,
      number: r['number'] as String,
      vendorId: r['vendor_id'] as int?,
      vendorName: r['vendor_name'] as String,
      date: DateTime.parse(r['date'] as String),
      reference: (r['reference'] as String?) ?? '',
      status: (r['status'] as String?) ?? 'DRAFT',
      billedStatus: (r['billed_status'] as String?) ?? 'YET TO BE BILLED',
      amount: (r['amount'] as num).toDouble(),
      deliveryDate: r['delivery_date'] == null ? null : DateTime.tryParse(r['delivery_date'] as String),
      deliveryAddressType: (r['delivery_address_type'] as String?) ?? 'Organization',
      deliveryAddress: (r['delivery_address'] as String?) ?? '',
      customerId: r['customer_id'] as int?,
      customerName: (r['customer_name'] as String?) ?? '',
      shipmentPreference: (r['shipment_preference'] as String?) ?? '',
      paymentTerms: (r['payment_terms'] as String?) ?? 'Due on Receipt',
      reverseCharge: (r['reverse_charge'] as int?) == 1,
      notes: (r['notes'] as String?) ?? '',
      terms: (r['terms'] as String?) ?? '',
      subTotal: ((r['sub_total'] as num?) ?? (r['amount'] as num)).toDouble(),
      discountType: (r['discount_type'] as String?) ?? '%',
      discountValue: ((r['discount_value'] as num?) ?? 0.0).toDouble(),
      discountAmount: ((r['discount_amount'] as num?) ?? 0.0).toDouble(),
      taxAmount: ((r['tax_amount'] as num?) ?? 0.0).toDouble(),
      tdsRate: ((r['tds_rate'] as num?) ?? 0.0).toDouble(),
      tdsAmount: ((r['tds_amount'] as num?) ?? 0.0).toDouble(),
      tcsRate: ((r['tcs_rate'] as num?) ?? 0.0).toDouble(),
      tcsAmount: ((r['tcs_amount'] as num?) ?? 0.0).toDouble(),
      roundOff: ((r['round_off'] as num?) ?? 0.0).toDouble(),
      attachments: attachments,
      createdAt: r['created_at'] == null ? null : DateTime.tryParse(r['created_at'] as String),
      updatedAt: r['updated_at'] == null ? null : DateTime.tryParse(r['updated_at'] as String),
      items: items,
    );
  }

  @override
  Future<void> addPurchaseOrder(PurchaseOrderDraft draft) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final poId = await txn.insert('purchase_orders', {
        'number': draft.number,
        'vendor_id': draft.vendorId,
        'vendor_name': draft.vendorName,
        'date': draft.date.toIso8601String(),
        'reference': draft.reference,
        'status': draft.status,
        'billed_status': 'YET TO BE BILLED',
        'amount': draft.amount,
        'delivery_date': draft.deliveryDate?.toIso8601String(),
        'delivery_address_type': draft.deliveryAddressType,
        'delivery_address': draft.deliveryAddress,
        'customer_id': draft.customerId,
        'customer_name': draft.customerName,
        'shipment_preference': draft.shipmentPreference,
        'payment_terms': draft.paymentTerms,
        'reverse_charge': draft.reverseCharge ? 1 : 0,
        'notes': draft.notes,
        'terms': draft.terms,
        'sub_total': draft.subTotal,
        'discount_type': draft.discountType,
        'discount_value': draft.discountValue,
        'discount_amount': draft.discountAmount,
        'tax_amount': draft.taxAmount,
        'tds_rate': draft.tdsRate,
        'tds_amount': draft.tdsAmount,
        'tcs_rate': draft.tcsRate,
        'tcs_amount': draft.tcsAmount,
        'round_off': draft.roundOff,
        'attachments': draft.attachments.join('|'),
        'created_at': now,
        'updated_at': now,
      });

      for (final item in draft.items) {
        await txn.insert('purchase_order_items', {
          'purchase_order_id': poId,
          'item_id': item.itemId,
          'item_name': item.itemName,
          'account': item.account,
          'quantity': item.quantity,
          'unit': item.unit,
          'rate': item.rate,
          'tax': item.tax,
          'tax_rate': item.taxRate,
          'amount': item.amount,
        });
      }
    });
  }

  @override
  Future<void> updatePurchaseOrder(int id, PurchaseOrderDraft draft) async {
    final existing = await getPurchaseOrderById(id);
    if (existing != null && existing.isReadOnly) {
      throw StateError('Purchase Order #${existing.number} is in status "${existing.status}" and cannot be modified.');
    }
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'purchase_orders',
        {
          'number': draft.number,
          'vendor_id': draft.vendorId,
          'vendor_name': draft.vendorName,
          'date': draft.date.toIso8601String(),
          'reference': draft.reference,
          'status': draft.status,
          'amount': draft.amount,
          'delivery_date': draft.deliveryDate?.toIso8601String(),
          'delivery_address_type': draft.deliveryAddressType,
          'delivery_address': draft.deliveryAddress,
          'customer_id': draft.customerId,
          'customer_name': draft.customerName,
          'shipment_preference': draft.shipmentPreference,
          'payment_terms': draft.paymentTerms,
          'reverse_charge': draft.reverseCharge ? 1 : 0,
          'notes': draft.notes,
          'terms': draft.terms,
          'sub_total': draft.subTotal,
          'discount_type': draft.discountType,
          'discount_value': draft.discountValue,
          'discount_amount': draft.discountAmount,
          'tax_amount': draft.taxAmount,
          'tds_rate': draft.tdsRate,
          'tds_amount': draft.tdsAmount,
          'tcs_rate': draft.tcsRate,
          'tcs_amount': draft.tcsAmount,
          'round_off': draft.roundOff,
          'attachments': draft.attachments.join('|'),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'purchase_order_items',
        where: 'purchase_order_id = ?',
        whereArgs: [id],
      );

      for (final item in draft.items) {
        await txn.insert('purchase_order_items', {
          'purchase_order_id': id,
          'item_id': item.itemId,
          'item_name': item.itemName,
          'account': item.account,
          'quantity': item.quantity,
          'unit': item.unit,
          'rate': item.rate,
          'tax': item.tax,
          'tax_rate': item.taxRate,
          'amount': item.amount,
        });
      }
    });
  }

  @override
  Future<void> updatePoStatus(int id, String newStatus) async {
    final db = await _db;
    final data = <String, dynamic>{
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (newStatus == 'BILLED') {
      data['billed_status'] = 'BILLED';
    }
    await db.update(
      'purchase_orders',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deletePurchaseOrder(int id) async {
    final existing = await getPurchaseOrderById(id);
    if (existing != null && (existing.isBilled || existing.status == 'RECEIVED')) {
      throw StateError('Cannot delete Purchase Order #${existing.number} because it is already ${existing.status}.');
    }
    final db = await _db;
    await db.delete('purchase_orders', where: 'id = ?', whereArgs: [id]);
    await db.delete('purchase_order_items', where: 'purchase_order_id = ?', whereArgs: [id]);
  }

  @override
  Future<String> generateNextPoNumber() async {
    final db = await _db;
    final rows = await db.rawQuery('SELECT number FROM purchase_orders ORDER BY id DESC LIMIT 1');
    if (rows.isEmpty) return 'PO-00001';
    final lastNumber = rows.first['number'] as String;
    final match = RegExp(r'(\d+)').firstMatch(lastNumber);
    if (match != null) {
      final numStr = match.group(1)!;
      final nextNum = int.parse(numStr) + 1;
      return 'PO-${nextNum.toString().padLeft(numStr.length, '0')}';
    }
    return 'PO-00001';
  }
}
