import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/books_repository.dart';

class SqliteBooksRepository implements BooksRepository {
  Database? _database;
  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      p.join(await getDatabasesPath(), 'igreen_books.db'),
      version: 15,
      onCreate: (db, _) async {
        // SQL is isolated in this repository so UI code remains backend-agnostic.
        await db.execute(
          'CREATE TABLE items(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, type TEXT NOT NULL DEFAULT "Goods", unit TEXT NOT NULL DEFAULT "pcs", sku TEXT NOT NULL, hsn_code TEXT NOT NULL DEFAULT "", rate REAL NOT NULL, cost_price REAL NOT NULL DEFAULT 0, tax_rate REAL NOT NULL DEFAULT 18, track_inventory INTEGER NOT NULL DEFAULT 0, stock_on_hand REAL NOT NULL DEFAULT 0, intra_state_tax_rate TEXT NOT NULL DEFAULT "", inter_state_tax_rate TEXT NOT NULL DEFAULT "", tax_preference TEXT NOT NULL DEFAULT "Taxable", purchase_account TEXT NOT NULL DEFAULT "Cost of Goods Sold", sales_account TEXT NOT NULL DEFAULT "Sales", reporting_tags TEXT NOT NULL DEFAULT "", product TEXT NOT NULL DEFAULT "", product_name TEXT NOT NULL DEFAULT "", master_serial_no TEXT NOT NULL DEFAULT "", part_no TEXT NOT NULL DEFAULT "", drawing_file TEXT NOT NULL DEFAULT "", assembly_image TEXT NOT NULL DEFAULT "")',
        );
        await db.execute(
          'CREATE TABLE item_parts(id INTEGER PRIMARY KEY AUTOINCREMENT, item_id INTEGER NOT NULL, sl_no INTEGER NOT NULL, part_name TEXT NOT NULL, part_no TEXT NOT NULL, part_image TEXT NOT NULL DEFAULT "", part_pdf TEXT NOT NULL DEFAULT "", rm_grade TEXT NOT NULL DEFAULT "", rm_size TEXT NOT NULL DEFAULT "", rm_weight REAL NOT NULL DEFAULT 0, fg_weight REAL NOT NULL DEFAULT 0, quantity REAL NOT NULL DEFAULT 1, has_process_flow INTEGER NOT NULL DEFAULT 0, FOREIGN KEY(item_id) REFERENCES items(id))',
        );
      await db.execute(
        'CREATE TABLE part_operations(id INTEGER PRIMARY KEY AUTOINCREMENT, part_id INTEGER NOT NULL, operation_number INTEGER NOT NULL, operation_name TEXT NOT NULL, machine TEXT NOT NULL, duration TEXT NOT NULL, remarks TEXT NOT NULL, vendor TEXT NOT NULL DEFAULT "", FOREIGN KEY(part_id) REFERENCES item_parts(id))',
      );
      await db.execute(
        'CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, company TEXT NOT NULL, email TEXT NOT NULL DEFAULT "", phone TEXT NOT NULL, gst_treatment TEXT NOT NULL, receivables REAL NOT NULL DEFAULT 0)',
      );
      await db.execute(
        'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, number TEXT NOT NULL UNIQUE, customer_id INTEGER, customer TEXT NOT NULL, date TEXT NOT NULL, due_date TEXT, reference_number TEXT NOT NULL DEFAULT "", amount REAL NOT NULL, discount REAL NOT NULL DEFAULT 0, discount_type TEXT NOT NULL DEFAULT "%", tax_amount REAL NOT NULL DEFAULT 0, amount_paid REAL NOT NULL DEFAULT 0, payment_terms TEXT NOT NULL DEFAULT "", notes TEXT NOT NULL DEFAULT "", terms TEXT NOT NULL DEFAULT "", status TEXT NOT NULL, FOREIGN KEY(customer_id) REFERENCES customers(id))',
      );
      await db.execute('CREATE TABLE invoice_items(id INTEGER PRIMARY KEY AUTOINCREMENT, transaction_id INTEGER NOT NULL, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT "", quantity REAL NOT NULL, rate REAL NOT NULL, tax TEXT NOT NULL DEFAULT "No Tax", FOREIGN KEY(transaction_id) REFERENCES transactions(id))');
      await db.execute(
        'CREATE TABLE adjustments(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, reason TEXT NOT NULL, description TEXT NOT NULL, status TEXT NOT NULL, reference_number TEXT NOT NULL UNIQUE, type TEXT NOT NULL, created_by TEXT NOT NULL, created_time TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE adjustment_items(id INTEGER PRIMARY KEY AUTOINCREMENT, adjustment_id INTEGER NOT NULL, item_id INTEGER NOT NULL, quantity_adjusted REAL NOT NULL, value_adjusted REAL NOT NULL DEFAULT 0, FOREIGN KEY(adjustment_id) REFERENCES adjustments(id), FOREIGN KEY(item_id) REFERENCES items(id))',
      );
      await db.execute(
        'CREATE TABLE item_history(id INTEGER PRIMARY KEY AUTOINCREMENT, item_id INTEGER NOT NULL, occurred_at TEXT NOT NULL, details TEXT NOT NULL, FOREIGN KEY(item_id) REFERENCES items(id))',
      );
      await db.execute(
        'CREATE TABLE stock_entries(id INTEGER PRIMARY KEY AUTOINCREMENT, grn_number TEXT NOT NULL, supplier TEXT NOT NULL, po_number TEXT NOT NULL, po_date TEXT NOT NULL, invoice_number TEXT NOT NULL, invoice_date TEXT NOT NULL, material_code TEXT NOT NULL, description TEXT NOT NULL DEFAULT "", heat_number TEXT NOT NULL, batch_number TEXT NOT NULL, quantity REAL NOT NULL, weight REAL NOT NULL, inspection_status TEXT NOT NULL, store_location TEXT NOT NULL, created_at TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE materials(id INTEGER PRIMARY KEY AUTOINCREMENT, source_type TEXT NOT NULL, code TEXT NOT NULL DEFAULT "", description TEXT NOT NULL, material_type TEXT NOT NULL DEFAULT "", grade TEXT NOT NULL DEFAULT "", make TEXT NOT NULL DEFAULT "", model TEXT NOT NULL DEFAULT "", size TEXT NOT NULL DEFAULT "", unit TEXT NOT NULL DEFAULT "", density TEXT NOT NULL DEFAULT "", supplier TEXT NOT NULL DEFAULT "", heat_number TEXT NOT NULL DEFAULT "", batch_number TEXT NOT NULL DEFAULT "", warehouse_location TEXT NOT NULL DEFAULT "", rack_location TEXT NOT NULL DEFAULT "", minimum_stock TEXT NOT NULL DEFAULT "", maximum_stock TEXT NOT NULL DEFAULT "", reorder_level TEXT NOT NULL DEFAULT "", weight TEXT NOT NULL DEFAULT "", used_for TEXT NOT NULL DEFAULT "", image BLOB, stock_alert REAL NOT NULL DEFAULT 0, vendor_id INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE stock_movements(id INTEGER PRIMARY KEY AUTOINCREMENT, work_order TEXT NOT NULL, production_order TEXT NOT NULL, job_card TEXT NOT NULL, date TEXT NOT NULL, machine TEXT NOT NULL, operator_name TEXT NOT NULL, capture_work_order TEXT NOT NULL, material_id INTEGER NOT NULL, quantity_issued REAL NOT NULL, weight_issued REAL NOT NULL, issued_by TEXT NOT NULL, received_by TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY(material_id) REFERENCES items(id))',
      );
      await db.execute(
        'CREATE TABLE material_requests(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, machine TEXT NOT NULL, operator_name TEXT NOT NULL, work_order TEXT NOT NULL, material TEXT NOT NULL, quantity_issued REAL NOT NULL, weight_issued REAL NOT NULL, created_at TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE material_returns(id INTEGER PRIMARY KEY AUTOINCREMENT, work_order TEXT NOT NULL, material TEXT NOT NULL, quantity_returned REAL NOT NULL, weight REAL NOT NULL, reason TEXT NOT NULL, created_at TEXT NOT NULL)',
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
      if (oldVersion < 3) {
        await db.execute(
          'CREATE TABLE item_history(id INTEGER PRIMARY KEY AUTOINCREMENT, item_id INTEGER NOT NULL, occurred_at TEXT NOT NULL, details TEXT NOT NULL, FOREIGN KEY(item_id) REFERENCES items(id))',
        );
        // Existing items need an initial event so their History tab is useful after migration.
        await db.rawInsert(
          'INSERT INTO item_history(item_id, occurred_at, details) SELECT id, ?, ? FROM items',
          [
            DateTime(2026, 6, 28, 10, 35).toIso8601String(),
            'created by - iGreenTec Engineering india Pvt.Ltd.',
          ],
        );
      }
      if (oldVersion < 4) {
        // Invoice-only fields stay in the repository so screens remain storage agnostic.
        await db.execute('ALTER TABLE transactions ADD COLUMN payment_terms TEXT NOT NULL DEFAULT ""');
        await db.execute('ALTER TABLE transactions ADD COLUMN discount_type TEXT NOT NULL DEFAULT "%"');
        await db.execute('CREATE TABLE invoice_items(id INTEGER PRIMARY KEY AUTOINCREMENT, transaction_id INTEGER NOT NULL, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT "", quantity REAL NOT NULL, rate REAL NOT NULL, tax TEXT NOT NULL DEFAULT "No Tax", FOREIGN KEY(transaction_id) REFERENCES transactions(id))');
      }
      if (oldVersion < 5) {
        // Add the new catalog item for existing databases without changing the schema.
        await _insertPullingSwivel(db);
      }
      if (oldVersion < 6) {
        await db.execute(
          'CREATE TABLE stock_entries(id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_order_number TEXT NOT NULL, purchase_order_date TEXT NOT NULL, invoice_number TEXT NOT NULL, invoice_date TEXT NOT NULL, item TEXT NOT NULL, description TEXT NOT NULL DEFAULT "", size TEXT NOT NULL DEFAULT "", measurement TEXT NOT NULL DEFAULT "", quantity REAL NOT NULL, basic_price REAL NOT NULL, tax_percentage REAL NOT NULL, net_average REAL NOT NULL, created_at TEXT NOT NULL)',
        );
      }
      if (oldVersion < 7) {
        await db.execute('ALTER TABLE stock_entries ADD COLUMN total_amount_with_tax REAL NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE stock_entries ADD COLUMN grand_total REAL NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE stock_entries ADD COLUMN paid REAL NOT NULL DEFAULT 0');
        await db.execute(
          'CREATE TABLE materials(id INTEGER PRIMARY KEY AUTOINCREMENT, source_type TEXT NOT NULL, description TEXT NOT NULL, size TEXT NOT NULL DEFAULT "", weight TEXT NOT NULL DEFAULT "", used_for TEXT NOT NULL DEFAULT "", image BLOB, stock_alert REAL NOT NULL DEFAULT 0, vendor_id INTEGER NOT NULL, created_at TEXT NOT NULL)',
        );
      }
      if (oldVersion < 8) {
        await db.execute(
          'CREATE TABLE stock_movements(id INTEGER PRIMARY KEY AUTOINCREMENT, work_order TEXT NOT NULL, production_order TEXT NOT NULL, job_card TEXT NOT NULL, date TEXT NOT NULL, machine TEXT NOT NULL, operator_name TEXT NOT NULL, capture_work_order TEXT NOT NULL, material_id INTEGER NOT NULL, quantity_issued REAL NOT NULL, weight_issued REAL NOT NULL, issued_by TEXT NOT NULL, received_by TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY(material_id) REFERENCES items(id))',
        );
      }
      if (oldVersion < 9) {
        await db.execute('ALTER TABLE stock_entries RENAME TO legacy_stock_entries');
        await db.execute(
          'CREATE TABLE stock_entries(id INTEGER PRIMARY KEY AUTOINCREMENT, grn_number TEXT NOT NULL, supplier TEXT NOT NULL, po_number TEXT NOT NULL, material_code TEXT NOT NULL, heat_number TEXT NOT NULL, batch_number TEXT NOT NULL, quantity REAL NOT NULL, weight REAL NOT NULL, inspection_status TEXT NOT NULL, store_location TEXT NOT NULL, created_at TEXT NOT NULL)',
        );
      }
      if (oldVersion < 10) {
        await db.execute('ALTER TABLE stock_entries ADD COLUMN po_date TEXT NOT NULL DEFAULT ""');
        await db.execute('ALTER TABLE stock_entries ADD COLUMN invoice_number TEXT NOT NULL DEFAULT ""');
        await db.execute('ALTER TABLE stock_entries ADD COLUMN invoice_date TEXT NOT NULL DEFAULT ""');
        await db.execute('ALTER TABLE stock_entries ADD COLUMN description TEXT NOT NULL DEFAULT ""');
      }
      if (oldVersion < 11) {
        for (final column in [
          'code', 'material_type', 'grade', 'make', 'model', 'unit', 'density',
          'supplier', 'heat_number', 'batch_number', 'warehouse_location',
          'rack_location', 'minimum_stock', 'maximum_stock', 'reorder_level',
        ]) {
          await db.execute(
            'ALTER TABLE materials ADD COLUMN $column TEXT NOT NULL DEFAULT ""',
          );
        }
      }
      if (oldVersion < 12) {
        await db.execute(
          'CREATE TABLE material_requests(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, machine TEXT NOT NULL, operator_name TEXT NOT NULL, work_order TEXT NOT NULL, material TEXT NOT NULL, quantity_issued REAL NOT NULL, weight_issued REAL NOT NULL, created_at TEXT NOT NULL)',
        );
      }
      if (oldVersion < 13) {
        await db.execute(
          'CREATE TABLE material_returns(id INTEGER PRIMARY KEY AUTOINCREMENT, work_order TEXT NOT NULL, material TEXT NOT NULL, quantity_returned REAL NOT NULL, weight REAL NOT NULL, reason TEXT NOT NULL, created_at TEXT NOT NULL)',
        );
      }
      if (oldVersion < 14) {
        for (final sql in [
          'ALTER TABLE items ADD COLUMN intra_state_tax_rate TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE items ADD COLUMN inter_state_tax_rate TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE items ADD COLUMN tax_preference TEXT NOT NULL DEFAULT "Taxable"',
          'ALTER TABLE items ADD COLUMN purchase_account TEXT NOT NULL DEFAULT "Cost of Goods Sold"',
          'ALTER TABLE items ADD COLUMN sales_account TEXT NOT NULL DEFAULT "Sales"',
          'ALTER TABLE items ADD COLUMN reporting_tags TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE items ADD COLUMN product TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE items ADD COLUMN product_name TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE items ADD COLUMN master_serial_no TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE items ADD COLUMN part_no TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE items ADD COLUMN drawing_file TEXT NOT NULL DEFAULT ""',
          'ALTER TABLE items ADD COLUMN assembly_image TEXT NOT NULL DEFAULT ""',
        ]) {
          await db.execute(sql);
        }
        await db.execute(
          'CREATE TABLE item_parts(id INTEGER PRIMARY KEY AUTOINCREMENT, item_id INTEGER NOT NULL, sl_no INTEGER NOT NULL, part_name TEXT NOT NULL, part_no TEXT NOT NULL, part_image TEXT NOT NULL DEFAULT "", part_pdf TEXT NOT NULL DEFAULT "", rm_grade TEXT NOT NULL DEFAULT "", rm_size TEXT NOT NULL DEFAULT "", rm_weight REAL NOT NULL DEFAULT 0, fg_weight REAL NOT NULL DEFAULT 0, quantity REAL NOT NULL DEFAULT 1, has_process_flow INTEGER NOT NULL DEFAULT 0, FOREIGN KEY(item_id) REFERENCES items(id))',
        );
        await db.execute(
          'CREATE TABLE part_operations(id INTEGER PRIMARY KEY AUTOINCREMENT, part_id INTEGER NOT NULL, operation_number INTEGER NOT NULL, operation_name TEXT NOT NULL, machine TEXT NOT NULL, duration TEXT NOT NULL, remarks TEXT NOT NULL, vendor TEXT NOT NULL DEFAULT "", FOREIGN KEY(part_id) REFERENCES item_parts(id))',
        );
      }
      if (oldVersion < 15) {
        try {
          await db.execute('ALTER TABLE item_parts ADD COLUMN part_pdf TEXT NOT NULL DEFAULT ""');
        } catch (_) {}
      }
    },
  );
  try {
    await _database!.execute('ALTER TABLE item_parts ADD COLUMN part_pdf TEXT NOT NULL DEFAULT ""');
  } catch (_) {}
  return _database!;
}

  static Future<void> _seed(Database db) async {
    for (final name in [
      'Joint Kit',
      'Tool Holder',
      'End Mill',
      'Fixture',
      'Bore plug Gauge',
      '3 Jaw Chuck',
      '3.5" Pulling Swivel',
    ]) {
      final itemId = await db.insert('items', {
        'name': name,
        'sku': '',
        'rate': 0.0,
        'cost_price': 0.0,
        'track_inventory': 1,
        'stock_on_hand': 10.0,
      });
      await db.insert('item_history', {
        'item_id': itemId,
        'occurred_at': DateTime(2026, 6, 28, 10, 35).toIso8601String(),
        'details': 'created by - iGreenTec Engineering india Pvt.Ltd.',
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

  static Future<void> _insertPullingSwivel(Database db) async {
    final existing = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM items WHERE name = ?',
        ['3.5" Pulling Swivel'],
      ),
    );
    if ((existing ?? 0) > 0) return;

    final itemId = await db.insert('items', {
      'name': '3.5" Pulling Swivel',
      'sku': '',
      'rate': 0.0,
      'cost_price': 0.0,
      'track_inventory': 1,
      'stock_on_hand': 10.0,
    });
    await db.insert('item_history', {
      'item_id': itemId,
      'occurred_at': DateTime(2026, 6, 28, 10, 35).toIso8601String(),
      'details': 'created by - iGreenTec Engineering india Pvt.Ltd.',
    });
  }

  @override
  Future<List<BookItem>> getItems() async {
    final db = await _db;
    final itemRows = await db.query('items', orderBy: 'id DESC');
    final items = <BookItem>[];
    for (final r in itemRows) {
      final itemId = r['id'] as int;
      final partRows = await db.query('item_parts', where: 'item_id = ?', whereArgs: [itemId], orderBy: 'sl_no ASC');
      final parts = <ItemPart>[];
      for (final pr in partRows) {
        final partId = pr['id'] as int;
        final opRows = await db.query('part_operations', where: 'part_id = ?', whereArgs: [partId], orderBy: 'operation_number ASC');
        final ops = opRows.map((op) => ItemPartOperation(
          operationNumber: op['operation_number'] as int,
          operationName: op['operation_name'] as String,
          machine: op['machine'] as String,
          duration: op['duration'] as String,
          remarks: op['remarks'] as String,
          vendor: (op['vendor'] as String?).toString().isEmpty ? null : op['vendor'] as String,
        )).toList();
        parts.add(ItemPart(
          slNo: pr['sl_no'] as int,
          partName: pr['part_name'] as String,
          partNo: pr['part_no'] as String,
          partImage: pr['part_image'] as String? ?? '',
          partPdf: pr['part_pdf'] as String? ?? '',
          rmGrade: pr['rm_grade'] as String? ?? '',
          rmSize: pr['rm_size'] as String? ?? '',
          rmWeight: (pr['rm_weight'] as num?)?.toDouble() ?? 0,
          fgWeight: (pr['fg_weight'] as num?)?.toDouble() ?? 0,
          quantity: (pr['quantity'] as num?)?.toDouble() ?? 1,
          hasProcessFlow: pr['has_process_flow'] == 1,
          operations: ops,
        ));
      }
      items.add(BookItem(
        id: itemId,
        name: r['name'] as String,
        sku: r['sku'] as String? ?? '',
        rate: (r['rate'] as num?)?.toDouble() ?? 0,
        type: r['type'] as String? ?? 'Goods',
        unit: r['unit'] as String? ?? 'pcs',
        hsnCode: r['hsn_code'] as String? ?? '',
        taxPreference: r['tax_preference'] as String? ?? 'Taxable',
        taxRate: (r['tax_rate'] as num?)?.toDouble() ?? 18,
        intraStateTaxRate: r['intra_state_tax_rate'] as String? ?? '',
        interStateTaxRate: r['inter_state_tax_rate'] as String? ?? '',
        costPrice: (r['cost_price'] as num?)?.toDouble() ?? 0,
        purchaseAccount: r['purchase_account'] as String? ?? 'Cost of Goods Sold',
        salesAccount: r['sales_account'] as String? ?? 'Sales',
        cogsAccount: r['cogs_account'] as String? ?? 'Cost of Goods Sold',
        reportingTags: r['reporting_tags'] as String? ?? '',
        preferredVendor: r['preferred_vendor'] as String? ?? '',
        trackInventory: r['track_inventory'] == 1,
        stockOnHand: (r['stock_on_hand'] as num?)?.toDouble() ?? 0,
        product: r['product'] as String? ?? '',
        productName: r['product_name'] as String? ?? '',
        masterSerialNo: r['master_serial_no'] as String? ?? '',
        partNo: r['part_no'] as String? ?? '',
        drawingFileName: r['drawing_file'] as String? ?? '',
        assemblyImagePath: r['assembly_image'] as String? ?? '',
        parts: parts,
      ));
    }
    return items;
  }
  @override
  Future<List<ItemHistoryEntry>> getItemHistory(int itemId) async =>
      (await (await _db).query(
            'item_history',
            where: 'item_id = ?',
            whereArgs: [itemId],
            orderBy: 'occurred_at DESC',
          ))
          .map(
            (r) => ItemHistoryEntry(
              date: DateTime.parse(r['occurred_at'] as String),
              details: r['details'] as String,
            ),
          )
          .toList();

  @override
  Future<BookItem> addItem({
    required String name,
    String sku = '',
    double rate = 0,
    String type = 'Goods',
    String unit = 'pcs',
    String hsnCode = '',
    String taxPreference = 'Taxable',
    double taxRate = 18,
    String intraStateTaxRate = '',
    String interStateTaxRate = '',
    double costPrice = 0,
    String purchaseAccount = 'Cost of Goods Sold',
    String salesAccount = 'Sales',
    String cogsAccount = 'Cost of Goods Sold',
    String reportingTags = '',
    String preferredVendor = '',
    String product = '',
    String productName = '',
    String masterSerialNo = '',
    String partNo = '',
    String drawingFileName = '',
    String assemblyImagePath = '',
    List<ItemPart> parts = const [],
  }) async {
    final db = await _db;
    late BookItem newItem;
    await db.transaction((txn) async {
      final itemId = await txn.insert('items', {
        'name': name,
        'sku': sku,
        'rate': rate,
        'type': type,
        'unit': unit,
        'hsn_code': hsnCode,
        'tax_preference': taxPreference,
        'tax_rate': taxRate,
        'intra_state_tax_rate': intraStateTaxRate,
        'inter_state_tax_rate': interStateTaxRate,
        'cost_price': costPrice,
        'purchase_account': purchaseAccount,
        'sales_account': salesAccount,
        'cogs_account': cogsAccount,
        'reporting_tags': reportingTags,
        'preferred_vendor': preferredVendor,
        'product': product,
        'product_name': productName,
        'master_serial_no': masterSerialNo,
        'part_no': partNo,
        'drawing_file': drawingFileName,
        'assembly_image': assemblyImagePath,
        'track_inventory': 1,
        'stock_on_hand': 0,
      });

      // 1. Automatically create initial History record
      await txn.insert('item_history', {
        'item_id': itemId,
        'occurred_at': DateTime.now().toIso8601String(),
        'details': 'created by - iGreenTec Engineering india Pvt.Ltd.',
      });

      // 2. Automatically create initial Transactions record
      final txnNo = 'SO-${DateTime.now().millisecondsSinceEpoch % 100000}';
      final txnId = await txn.insert('transactions', {
        'type': TransactionType.salesOrder.name,
        'number': txnNo,
        'customer': 'iGreen Technologies',
        'date': DateTime.now().toIso8601String(),
        'amount': rate > 0 ? rate : costPrice,
        'status': 'DRAFT',
        'reference_number': partNo.isNotEmpty ? partNo : name,
        'notes': 'Initial transaction for created item: $name',
        'terms': 'Net 30',
      });
      await txn.insert('invoice_items', {
        'transaction_id': txnId,
        'name': name,
        'description': productName.isNotEmpty ? productName : name,
        'quantity': 1.0,
        'rate': rate,
        'tax': taxPreference,
      });

      // 3. Save Raw Materials & Parts and their process flows
      final savedParts = <ItemPart>[];
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        final partId = await txn.insert('item_parts', {
          'item_id': itemId,
          'sl_no': part.slNo > 0 ? part.slNo : (i + 1),
          'part_name': part.partName,
          'part_no': part.partNo,
          'part_image': part.partImage,
          'part_pdf': part.partPdf,
          'rm_grade': part.rmGrade,
          'rm_size': part.rmSize,
          'rm_weight': part.rmWeight,
          'fg_weight': part.fgWeight,
          'quantity': part.quantity,
          'has_process_flow': part.hasProcessFlow ? 1 : 0,
        });

        final savedOps = <ItemPartOperation>[];
        if (part.hasProcessFlow) {
          for (var j = 0; j < part.operations.length; j++) {
            final op = part.operations[j];
            await txn.insert('part_operations', {
              'part_id': partId,
              'operation_number': op.operationNumber > 0 ? op.operationNumber : (j + 1),
              'operation_name': op.operationName,
              'machine': op.machine,
              'duration': op.duration,
              'remarks': op.remarks,
              'vendor': op.vendor ?? '',
            });
            savedOps.add(op);
          }
        }

        savedParts.add(ItemPart(
          slNo: part.slNo > 0 ? part.slNo : (i + 1),
          partName: part.partName,
          partNo: part.partNo,
          partImage: part.partImage,
          partPdf: part.partPdf,
          rmGrade: part.rmGrade,
          rmSize: part.rmSize,
          rmWeight: part.rmWeight,
          fgWeight: part.fgWeight,
          quantity: part.quantity,
          hasProcessFlow: part.hasProcessFlow,
          operations: savedOps,
        ));
      }

      newItem = BookItem(
        id: itemId,
        name: name,
        sku: sku,
        rate: rate,
        type: type,
        unit: unit,
        hsnCode: hsnCode,
        taxPreference: taxPreference,
        taxRate: taxRate,
        intraStateTaxRate: intraStateTaxRate,
        interStateTaxRate: interStateTaxRate,
        costPrice: costPrice,
        purchaseAccount: purchaseAccount,
        salesAccount: salesAccount,
        cogsAccount: cogsAccount,
        reportingTags: reportingTags,
        preferredVendor: preferredVendor,
        product: product,
        productName: productName,
        masterSerialNo: masterSerialNo,
        partNo: partNo,
        drawingFileName: drawingFileName,
        assemblyImagePath: assemblyImagePath,
        parts: savedParts,
        trackInventory: true,
        stockOnHand: 0,
      );
    });
    return newItem;
  }

  @override
  Future<void> updateItem({
    required int id,
    required String name,
    String sku = '',
    double rate = 0,
    String type = 'Goods',
    String unit = 'pcs',
    String hsnCode = '',
    String taxPreference = 'Taxable',
    double taxRate = 18,
    String intraStateTaxRate = '',
    String interStateTaxRate = '',
    double costPrice = 0,
    String purchaseAccount = 'Cost of Goods Sold',
    String salesAccount = 'Sales',
    String cogsAccount = 'Cost of Goods Sold',
    String reportingTags = '',
    String preferredVendor = '',
    String product = '',
    String productName = '',
    String masterSerialNo = '',
    String partNo = '',
    String drawingFileName = '',
    String assemblyImagePath = '',
    List<ItemPart> parts = const [],
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'items',
        {
          'name': name,
          'sku': sku,
          'rate': rate,
          'type': type,
          'unit': unit,
          'hsn_code': hsnCode,
          'tax_preference': taxPreference,
          'tax_rate': taxRate,
          'intra_state_tax_rate': intraStateTaxRate,
          'inter_state_tax_rate': interStateTaxRate,
          'cost_price': costPrice,
          'purchase_account': purchaseAccount,
          'sales_account': salesAccount,
          'cogs_account': cogsAccount,
          'reporting_tags': reportingTags,
          'preferred_vendor': preferredVendor,
          'product': product,
          'product_name': productName,
          'master_serial_no': masterSerialNo,
          'part_no': partNo,
          'drawing_file': drawingFileName,
          'assembly_image': assemblyImagePath,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.insert('item_history', {
        'item_id': id,
        'occurred_at': DateTime.now().toIso8601String(),
        'details': 'updated by - iGreenTec Engineering india Pvt.Ltd.',
      });

      final existingPartRows = await txn.query('item_parts', where: 'item_id = ?', whereArgs: [id]);
      for (final pr in existingPartRows) {
        final partId = pr['id'] as int;
        await txn.delete('part_operations', where: 'part_id = ?', whereArgs: [partId]);
      }
      await txn.delete('item_parts', where: 'item_id = ?', whereArgs: [id]);

      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        final partId = await txn.insert('item_parts', {
          'item_id': id,
          'sl_no': part.slNo > 0 ? part.slNo : (i + 1),
          'part_name': part.partName,
          'part_no': part.partNo,
          'part_image': part.partImage,
          'part_pdf': part.partPdf,
          'rm_grade': part.rmGrade,
          'rm_size': part.rmSize,
          'rm_weight': part.rmWeight,
          'fg_weight': part.fgWeight,
          'quantity': part.quantity,
          'has_process_flow': part.hasProcessFlow ? 1 : 0,
        });

        if (part.hasProcessFlow) {
          for (var j = 0; j < part.operations.length; j++) {
            final op = part.operations[j];
            await txn.insert('part_operations', {
              'part_id': partId,
              'operation_number': op.operationNumber > 0 ? op.operationNumber : (j + 1),
              'operation_name': op.operationName,
              'machine': op.machine,
              'duration': op.duration,
              'remarks': op.remarks,
              'vendor': op.vendor ?? '',
            });
          }
        }
      }
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
              referenceNumber: r['reference_number'] as String? ?? '',
              dueDate: r['due_date'] == null
                  ? null
                  : DateTime.parse(r['due_date'] as String),
              notes: r['notes'] as String? ?? '',
              terms: r['terms'] as String? ?? '',
            ),
          )
          .toList();
  @override
  Future<void> addTransaction(TransactionDraft d) async {
    final db = await _db;
    await db.transaction((txn) async {
      final transactionId = await txn.insert('transactions', {
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
        'payment_terms': d.paymentTerms,
        'discount_type': d.discountType,
        'status': 'Draft',
      });
      for (final item in d.items) {
        await txn.insert('invoice_items', {
          'transaction_id': transactionId,
          'name': item.name,
          'description': item.description,
          'quantity': item.quantity,
          'rate': item.rate,
          'tax': item.tax,
        });
      }
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
  Future<void> addStock(StockEntryDraft d) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('stock_entries', {
        'grn_number': d.grnNumber,
        'supplier': d.supplier,
        'po_number': d.poNumber,
        'po_date': d.poDate.toIso8601String(),
        'invoice_number': d.invoiceNumber,
        'invoice_date': d.invoiceDate.toIso8601String(),
        'material_code': d.materialCode,
        'description': d.description,
        'heat_number': d.heatNumber,
        'batch_number': d.batchNumber,
        'quantity': d.quantity,
        'weight': d.weight,
        'inspection_status': d.inspectionStatus,
        'store_location': d.storeLocation,
        'created_at': DateTime.now().toIso8601String(),
      });
      final matches = await txn.query(
        'items',
        columns: ['id'],
        where: 'LOWER(name) = ?',
        whereArgs: [d.materialCode.toLowerCase()],
        limit: 1,
      );
      if (matches.isEmpty) {
        await txn.insert('items', {
          'name': d.materialCode,
          'sku': '',
          'rate': 0.0,
          'cost_price': 0.0,
          'unit': 'pcs',
          'track_inventory': 1,
          'stock_on_hand': d.quantity,
        });
      } else {
        await txn.rawUpdate(
          'UPDATE items SET stock_on_hand = stock_on_hand + ? WHERE id = ?',
          [d.quantity, matches.first['id']],
        );
      }
    });
  }

  @override
  Future<void> addMaterial(MaterialDraft d) async {
    await (await _db).insert('materials', {
      'source_type': d.sourceType,
      'code': d.code,
      'description': d.description,
      'material_type': d.materialType,
      'grade': d.grade,
      'make': d.make,
      'model': d.model,
      'size': d.size,
      'unit': d.unit,
      'density': d.density,
      'supplier': d.supplier,
      'heat_number': d.heatNumber,
      'batch_number': d.batchNumber,
      'warehouse_location': d.warehouseLocation,
      'rack_location': d.rackLocation,
      'minimum_stock': d.minimumStock,
      'maximum_stock': d.maximumStock,
      'reorder_level': d.reorderLevel,
      'weight': '',
      'used_for': '',
      'stock_alert': 0,
      'vendor_id': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> moveStock(MoveStockDraft d) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('stock_movements', {
        'work_order': d.workOrder,
        'production_order': d.productionOrder,
        'job_card': d.jobCard,
        'date': d.date.toIso8601String(),
        'machine': d.machine,
        'operator_name': d.operatorName,
        'capture_work_order': d.captureWorkOrder,
        'material_id': d.materialId,
        'quantity_issued': d.quantityIssued,
        'weight_issued': d.weightIssued,
        'issued_by': d.issuedBy,
        'received_by': d.receivedBy,
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate(
        'UPDATE items SET stock_on_hand = stock_on_hand - ? WHERE id = ?',
        [d.quantityIssued, d.materialId],
      );
    });
  }

  @override
  Future<void> requestMaterial(MaterialRequestDraft d) async {
    await (await _db).insert('material_requests', {
      'date': d.date.toIso8601String(),
      'machine': d.machine,
      'operator_name': d.operatorName,
      'work_order': d.workOrder,
      'material': d.material,
      'quantity_issued': d.quantityIssued,
      'weight_issued': d.weightIssued,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> returnMaterial(MaterialReturnDraft d) async {
    await (await _db).insert('material_returns', {
      'work_order': d.workOrder,
      'material': d.material,
      'quantity_returned': d.quantityReturned,
      'weight': d.weight,
      'reason': d.reason,
      'created_at': DateTime.now().toIso8601String(),
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

  @override
  Future<String> uploadItemImage({
    required Uint8List bytes,
    required String fileName,
    String folderName = 'Item Images',
  }) async {
    final mimeType = fileName.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final base64Str = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64Str';
  }
}
