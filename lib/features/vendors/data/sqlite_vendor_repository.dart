import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/vendor.dart';
import '../domain/vendor_repository.dart';

class SqliteVendorRepository implements VendorRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await openDatabase(
    p.join(await getDatabasesPath(), 'igreen_vendors.db'),
    version: 2,
    onCreate: (db, version) async {
      await _createTables(db);
      await _seedData(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('DROP TABLE IF EXISTS vendors');
        await db.execute('DROP TABLE IF EXISTS vendor_addresses');
        await db.execute('DROP TABLE IF EXISTS vendor_contacts');
        await db.execute('DROP TABLE IF EXISTS vendor_bank_accounts');
        await db.execute('DROP TABLE IF EXISTS vendor_documents');
        await _createTables(db);
        await _seedData(db);
      }
    },
  );

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE vendors(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendor_code TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        company_name TEXT NOT NULL DEFAULT "",
        salutation TEXT NOT NULL DEFAULT "",
        first_name TEXT NOT NULL DEFAULT "",
        last_name TEXT NOT NULL DEFAULT "",
        email TEXT NOT NULL DEFAULT "",
        work_phone TEXT NOT NULL DEFAULT "",
        mobile TEXT NOT NULL DEFAULT "",
        gst_treatment TEXT NOT NULL DEFAULT "Registered Business - Regular",
        source_of_supply TEXT NOT NULL DEFAULT "",
        pan TEXT NOT NULL DEFAULT "",
        msme_registered INTEGER NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT "INR - Indian Rupee",
        opening_balance REAL NOT NULL DEFAULT 0.0,
        payment_terms TEXT NOT NULL DEFAULT "Due on Receipt",
        tds TEXT,
        status TEXT NOT NULL DEFAULT "Active",
        remarks TEXT NOT NULL DEFAULT "",
        payables REAL NOT NULL DEFAULT 0.0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vendor_addresses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendor_id INTEGER NOT NULL,
        address_line1 TEXT NOT NULL DEFAULT "",
        address_line2 TEXT NOT NULL DEFAULT "",
        city TEXT NOT NULL DEFAULT "",
        state TEXT NOT NULL DEFAULT "",
        country TEXT NOT NULL DEFAULT "India",
        pin_code TEXT NOT NULL DEFAULT "",
        FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE vendor_contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendor_id INTEGER NOT NULL,
        salutation TEXT NOT NULL DEFAULT "",
        first_name TEXT NOT NULL DEFAULT "",
        last_name TEXT NOT NULL DEFAULT "",
        designation TEXT NOT NULL DEFAULT "",
        department TEXT NOT NULL DEFAULT "",
        email TEXT NOT NULL DEFAULT "",
        phone TEXT NOT NULL DEFAULT "",
        mobile TEXT NOT NULL DEFAULT "",
        is_primary INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE vendor_bank_accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendor_id INTEGER NOT NULL,
        bank_name TEXT NOT NULL DEFAULT "",
        account_holder_name TEXT NOT NULL DEFAULT "",
        account_number TEXT NOT NULL DEFAULT "",
        ifsc_code TEXT NOT NULL DEFAULT "",
        branch TEXT NOT NULL DEFAULT "",
        account_type TEXT NOT NULL DEFAULT "",
        FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE vendor_documents(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendor_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _seedData(Database db) async {
    const regular = 'Registered Business - Regular';
    final initialVendors = <Map<String, Object>>[
      {
        'vendor_code': 'VEN-0001',
        'display_name': 'IGreen Technologies',
        'company_name': 'IGreen Technologies',
        'gst_treatment': regular,
        'source_of_supply': 'Tamil Nadu',
        'status': 'Active',
      },
      {
        'vendor_code': 'VEN-0002',
        'display_name': 'RS Industrial Equipments',
        'company_name': 'RS Industrial Equipments',
        'gst_treatment': regular,
        'source_of_supply': 'Tamil Nadu',
        'status': 'Active',
      },
      {
        'vendor_code': 'VEN-0003',
        'display_name': 'RAJLAXMI METAL SUPPLYS',
        'company_name': 'RAJLAXMI METAL SUPPLYS',
        'gst_treatment': regular,
        'source_of_supply': 'Tamil Nadu',
        'status': 'Active',
      },
      {
        'vendor_code': 'VEN-0004',
        'display_name': 'MAHAVIR METAL CORP/RAJLAXMI METALS SUPPLYS',
        'company_name': 'MAHAVIR METAL CORP',
        'gst_treatment': regular,
        'source_of_supply': 'Tamil Nadu',
        'status': 'Active',
      },
      {
        'vendor_code': 'VEN-0005',
        'display_name': 'Srinivaas Additives & Labs',
        'company_name': 'Srinivaas Additives & Labs',
        'gst_treatment': regular,
        'source_of_supply': 'Tamil Nadu',
        'status': 'Active',
      },
      {
        'vendor_code': 'VEN-0006',
        'display_name': 'Balambiga metal finishers',
        'company_name': 'Balambiga metal finishers',
        'gst_treatment': regular,
        'source_of_supply': 'Tamil Nadu',
        'status': 'Active',
      },
      {
        'vendor_code': 'VEN-0007',
        'display_name': 'The Light Companie',
        'company_name': 'The Light Companie',
        'gst_treatment': regular,
        'source_of_supply': 'Tamil Nadu',
        'status': 'Active',
      },
      {
        'vendor_code': 'VEN-0008',
        'display_name': 'M K Enterprises',
        'company_name': 'M K Enterprises',
        'gst_treatment': regular,
        'source_of_supply': 'Tamil Nadu',
        'status': 'Active',
      },
    ];

    for (final vendor in initialVendors) {
      vendor['created_at'] = DateTime.now().toIso8601String();
      vendor['updated_at'] = DateTime.now().toIso8601String();
      await db.insert('vendors', vendor);
    }
  }

  @override
  Future<String> generateNextVendorCode() async {
    final db = await _db;
    final result = await db.rawQuery(
      "SELECT vendor_code FROM vendors WHERE vendor_code LIKE 'VEN-%' ORDER BY id DESC LIMIT 1",
    );

    if (result.isEmpty) {
      return 'VEN-0001';
    }

    final lastCode = result.first['vendor_code'] as String? ?? 'VEN-0000';
    final numberStr = lastCode.replaceAll(RegExp(r'[^0-9]'), '');
    final number = int.tryParse(numberStr) ?? 0;
    final nextNumber = number + 1;
    return 'VEN-${nextNumber.toString().padLeft(4, '0')}';
  }

  @override
  Future<List<Vendor>> getVendors({bool includeInactive = true}) async {
    final db = await _db;
    final where = includeInactive ? null : 'status = "Active"';
    final rows = await db.query('vendors', where: where, orderBy: 'id DESC');

    final vendors = <Vendor>[];
    for (final row in rows) {
      final vendorId = row['id'] as int;
      final vendor = await _buildVendorFromRow(db, row, vendorId);
      vendors.add(vendor);
    }
    return vendors;
  }

  @override
  Future<Vendor?> getVendorById(int id) async {
    final db = await _db;
    final rows = await db.query('vendors', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _buildVendorFromRow(db, rows.first, id);
  }

  Future<Vendor> _buildVendorFromRow(
    Database db,
    Map<String, Object?> row,
    int vendorId,
  ) async {
    // Address
    final addressRows = await db.query(
      'vendor_addresses',
      where: 'vendor_id = ?',
      whereArgs: [vendorId],
      limit: 1,
    );
    VendorAddress? primaryAddress;
    if (addressRows.isNotEmpty) {
      final aRow = addressRows.first;
      primaryAddress = VendorAddress(
        id: aRow['id'] as int?,
        addressLine1: aRow['address_line1'] as String? ?? '',
        addressLine2: aRow['address_line2'] as String? ?? '',
        city: aRow['city'] as String? ?? '',
        state: aRow['state'] as String? ?? '',
        country: aRow['country'] as String? ?? 'India',
        pinCode: aRow['pin_code'] as String? ?? '',
      );
    }

    // Contacts
    final contactRows = await db.query(
      'vendor_contacts',
      where: 'vendor_id = ?',
      whereArgs: [vendorId],
    );
    final contacts = contactRows
        .map(
          (cRow) => VendorContactPerson(
            id: cRow['id'] as int?,
            salutation: cRow['salutation'] as String? ?? '',
            firstName: cRow['first_name'] as String? ?? '',
            lastName: cRow['last_name'] as String? ?? '',
            designation: cRow['designation'] as String? ?? '',
            department: cRow['department'] as String? ?? '',
            email: cRow['email'] as String? ?? '',
            phone: cRow['phone'] as String? ?? '',
            mobile: cRow['mobile'] as String? ?? '',
            isPrimary: (cRow['is_primary'] as int? ?? 0) == 1,
          ),
        )
        .toList();

    // Bank Accounts
    final bankRows = await db.query(
      'vendor_bank_accounts',
      where: 'vendor_id = ?',
      whereArgs: [vendorId],
    );
    final bankAccounts = bankRows
        .map(
          (bRow) => VendorBankAccount(
            id: bRow['id'] as int?,
            bankName: bRow['bank_name'] as String? ?? '',
            accountHolderName: bRow['account_holder_name'] as String? ?? '',
            accountNumber: bRow['account_number'] as String? ?? '',
            ifscCode: bRow['ifsc_code'] as String? ?? '',
            branch: bRow['branch'] as String? ?? '',
            accountType: bRow['account_type'] as String? ?? '',
          ),
        )
        .toList();

    // Documents
    final docRows = await db.query(
      'vendor_documents',
      where: 'vendor_id = ?',
      whereArgs: [vendorId],
    );
    final docPaths = docRows
        .map((dRow) => dRow['file_path'] as String)
        .toList();

    return Vendor(
      id: vendorId,
      vendorCode: row['vendor_code'] as String? ?? '',
      displayName: row['display_name'] as String? ?? '',
      companyName: row['company_name'] as String? ?? '',
      salutation: row['salutation'] as String? ?? '',
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      workPhone: row['work_phone'] as String? ?? '',
      mobile: row['mobile'] as String? ?? '',
      gstTreatment: row['gst_treatment'] as String? ?? 'Registered Business - Regular',
      sourceOfSupply: row['source_of_supply'] as String? ?? '',
      pan: row['pan'] as String? ?? '',
      msmeRegistered: (row['msme_registered'] as int? ?? 0) == 1,
      currency: row['currency'] as String? ?? 'INR - Indian Rupee',
      openingBalance: (row['opening_balance'] as num? ?? 0.0).toDouble(),
      paymentTerms: row['payment_terms'] as String? ?? 'Due on Receipt',
      tds: row['tds'] as String?,
      status: row['status'] as String? ?? 'Active',
      remarks: row['remarks'] as String? ?? '',
      payables: (row['payables'] as num? ?? 0.0).toDouble(),
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
      primaryAddress: primaryAddress,
      contactPersons: contacts,
      bankAccounts: bankAccounts,
      documentPaths: docPaths,
    );
  }

  @override
  Future<int> createVendor(Vendor vendor) async {
    final db = await _db;
    return await db.transaction((txn) async {
      var code = vendor.vendorCode.trim();
      if (code.isEmpty) {
        code = await generateNextVendorCode();
      }

      final now = DateTime.now().toIso8601String();
      final vendorId = await txn.insert('vendors', {
        'vendor_code': code,
        'display_name': vendor.displayName,
        'company_name': vendor.companyName,
        'salutation': vendor.salutation,
        'first_name': vendor.firstName,
        'last_name': vendor.lastName,
        'email': vendor.email,
        'work_phone': vendor.workPhone,
        'mobile': vendor.mobile,
        'gst_treatment': vendor.gstTreatment,
        'source_of_supply': vendor.sourceOfSupply,
        'pan': vendor.pan,
        'msme_registered': vendor.msmeRegistered ? 1 : 0,
        'currency': vendor.currency,
        'opening_balance': vendor.openingBalance,
        'payment_terms': vendor.paymentTerms,
        'tds': vendor.tds,
        'status': vendor.status,
        'remarks': vendor.remarks,
        'payables': vendor.payables,
        'created_at': now,
        'updated_at': now,
      });

      if (vendor.primaryAddress != null) {
        final addr = vendor.primaryAddress!;
        await txn.insert('vendor_addresses', {
          'vendor_id': vendorId,
          'address_line1': addr.addressLine1,
          'address_line2': addr.addressLine2,
          'city': addr.city,
          'state': addr.state,
          'country': addr.country,
          'pin_code': addr.pinCode,
        });
      }

      for (final contact in vendor.contactPersons) {
        await txn.insert('vendor_contacts', {
          'vendor_id': vendorId,
          'salutation': contact.salutation,
          'first_name': contact.firstName,
          'last_name': contact.lastName,
          'designation': contact.designation,
          'department': contact.department,
          'email': contact.email,
          'phone': contact.phone,
          'mobile': contact.mobile,
          'is_primary': contact.isPrimary ? 1 : 0,
        });
      }

      for (final bank in vendor.bankAccounts) {
        await txn.insert('vendor_bank_accounts', {
          'vendor_id': vendorId,
          'bank_name': bank.bankName,
          'account_holder_name': bank.accountHolderName,
          'account_number': bank.accountNumber,
          'ifsc_code': bank.ifscCode,
          'branch': bank.branch,
          'account_type': bank.accountType,
        });
      }

      for (final doc in vendor.documentPaths) {
        await txn.insert('vendor_documents', {
          'vendor_id': vendorId,
          'file_path': doc,
        });
      }

      return vendorId;
    });
  }

  @override
  Future<void> updateVendor(Vendor vendor) async {
    final db = await _db;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'vendors',
        {
          'vendor_code': vendor.vendorCode,
          'display_name': vendor.displayName,
          'company_name': vendor.companyName,
          'salutation': vendor.salutation,
          'first_name': vendor.firstName,
          'last_name': vendor.lastName,
          'email': vendor.email,
          'work_phone': vendor.workPhone,
          'mobile': vendor.mobile,
          'gst_treatment': vendor.gstTreatment,
          'source_of_supply': vendor.sourceOfSupply,
          'pan': vendor.pan,
          'msme_registered': vendor.msmeRegistered ? 1 : 0,
          'currency': vendor.currency,
          'opening_balance': vendor.openingBalance,
          'payment_terms': vendor.paymentTerms,
          'tds': vendor.tds,
          'status': vendor.status,
          'remarks': vendor.remarks,
          'payables': vendor.payables,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [vendor.id],
      );

      // Re-insert primary address
      await txn.delete('vendor_addresses', where: 'vendor_id = ?', whereArgs: [vendor.id]);
      if (vendor.primaryAddress != null) {
        final addr = vendor.primaryAddress!;
        await txn.insert('vendor_addresses', {
          'vendor_id': vendor.id,
          'address_line1': addr.addressLine1,
          'address_line2': addr.addressLine2,
          'city': addr.city,
          'state': addr.state,
          'country': addr.country,
          'pin_code': addr.pinCode,
        });
      }

      // Re-insert contact persons
      await txn.delete('vendor_contacts', where: 'vendor_id = ?', whereArgs: [vendor.id]);
      for (final contact in vendor.contactPersons) {
        await txn.insert('vendor_contacts', {
          'vendor_id': vendor.id,
          'salutation': contact.salutation,
          'first_name': contact.firstName,
          'last_name': contact.lastName,
          'designation': contact.designation,
          'department': contact.department,
          'email': contact.email,
          'phone': contact.phone,
          'mobile': contact.mobile,
          'is_primary': contact.isPrimary ? 1 : 0,
        });
      }

      // Re-insert bank accounts
      await txn.delete('vendor_bank_accounts', where: 'vendor_id = ?', whereArgs: [vendor.id]);
      for (final bank in vendor.bankAccounts) {
        await txn.insert('vendor_bank_accounts', {
          'vendor_id': vendor.id,
          'bank_name': bank.bankName,
          'account_holder_name': bank.accountHolderName,
          'account_number': bank.accountNumber,
          'ifsc_code': bank.ifscCode,
          'branch': bank.branch,
          'account_type': bank.accountType,
        });
      }

      // Re-insert documents
      await txn.delete('vendor_documents', where: 'vendor_id = ?', whereArgs: [vendor.id]);
      for (final doc in vendor.documentPaths) {
        await txn.insert('vendor_documents', {
          'vendor_id': vendor.id,
          'file_path': doc,
        });
      }
    });
  }

  @override
  Future<void> deleteVendor(int id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('vendor_addresses', where: 'vendor_id = ?', whereArgs: [id]);
      await txn.delete('vendor_contacts', where: 'vendor_id = ?', whereArgs: [id]);
      await txn.delete('vendor_bank_accounts', where: 'vendor_id = ?', whereArgs: [id]);
      await txn.delete('vendor_documents', where: 'vendor_id = ?', whereArgs: [id]);
      await txn.delete('vendors', where: 'id = ?', whereArgs: [id]);
    });
  }
}
