import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../models/customer.dart';
import 'customer_repository.dart';

class SqliteCustomerRepository implements CustomerRepository {
  Database? _database;
  Future<Database> get _db async => _database ??= await openDatabase(
    p.join(await getDatabasesPath(), 'customer_management.db'),
    version: 1,
    onCreate: (db, _) async {
      // Customer persistence stays isolated from presentation and can be swapped for Firebase.
      await db.execute('CREATE TABLE customers(id INTEGER PRIMARY KEY AUTOINCREMENT, display_name TEXT NOT NULL, company_name TEXT NOT NULL, email TEXT NOT NULL, work_phone TEXT NOT NULL, place_of_supply TEXT NOT NULL, receivables REAL NOT NULL DEFAULT 0, unused_credits REAL NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 1, payload TEXT NOT NULL)');
      for (final name in ['NEXORA INFRATECH', 'Poomari Engineering', 'Sark Telecom', 'Indwel Precision Gears Pvt Ltd']) {
        final customer = Customer(displayName: name, companyName: name, gstTreatment: 'Registered Business - Regular', placeOfSupply: 'Tamil Nadu');
        await db.insert('customers', _toRow(customer));
      }
    },
  );

  static Map<String, Object?> _toRow(Customer c) => {
    'display_name': c.displayName, 'company_name': c.companyName, 'email': c.email,
    'work_phone': c.workPhone, 'place_of_supply': c.placeOfSupply,
    'receivables': c.receivables, 'unused_credits': c.unusedCredits,
    'is_active': c.isActive ? 1 : 0, 'payload': jsonEncode(_toJson(c)),
  };

  static Map<String, dynamic> _toJson(Customer c) => {
    'type': c.type.name, 'salutation': c.salutation, 'firstName': c.firstName,
    'lastName': c.lastName, 'gstTreatment': c.gstTreatment, 'gstin': c.gstin,
    'pan': c.pan, 'language': c.language, 'mobile': c.mobile,
    'taxPreference': c.taxPreference.name, 'currency': c.currency,
    'openingBalance': c.openingBalance, 'paymentTerms': c.paymentTerms,
    'portalEnabled': c.portalEnabled, 'billingAddress': c.billingAddress.toJson(),
    'shippingAddress': c.shippingAddress.toJson(),
    'contacts': c.contacts.map((e) => e.toJson()).toList(),
    'customFields': c.customFields, 'reportingTags': c.reportingTags,
    'remarks': c.remarks, 'documentNames': c.documentNames,
  };

  static Customer _fromRow(Map<String, Object?> row) {
    final j = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    return Customer(
      id: row['id'] as int, displayName: row['display_name'] as String,
      companyName: row['company_name'] as String, email: row['email'] as String,
      workPhone: row['work_phone'] as String, placeOfSupply: row['place_of_supply'] as String,
      receivables: (row['receivables'] as num).toDouble(), unusedCredits: (row['unused_credits'] as num).toDouble(),
      isActive: row['is_active'] == 1, type: CustomerType.values.byName(j['type'] ?? 'business'),
      salutation: j['salutation'] ?? 'Mr.', firstName: j['firstName'] ?? '', lastName: j['lastName'] ?? '',
      gstTreatment: j['gstTreatment'] ?? '', gstin: j['gstin'] ?? '', pan: j['pan'] ?? '',
      language: j['language'] ?? 'English', mobile: j['mobile'] ?? '',
      taxPreference: TaxPreference.values.byName(j['taxPreference'] ?? 'taxable'), currency: j['currency'] ?? 'INR',
      openingBalance: (j['openingBalance'] as num?)?.toDouble() ?? 0, paymentTerms: j['paymentTerms'] ?? 'Due on Receipt',
      portalEnabled: j['portalEnabled'] ?? false,
      billingAddress: CustomerAddress.fromJson(Map<String, dynamic>.from(j['billingAddress'] ?? {})),
      shippingAddress: CustomerAddress.fromJson(Map<String, dynamic>.from(j['shippingAddress'] ?? {})),
      contacts: (j['contacts'] as List? ?? []).map((e) => CustomerContact.fromJson(Map<String, dynamic>.from(e))).toList(),
      customFields: Map<String, String>.from(j['customFields'] ?? {}),
      reportingTags: List<String>.from(j['reportingTags'] ?? []), remarks: j['remarks'] ?? '',
      documentNames: List<String>.from(j['documentNames'] ?? []),
    );
  }

  @override Future<int> createCustomer(Customer customer) async => (await _db).insert('customers', _toRow(customer));
  @override Future<void> deleteCustomer(int id) async => (await _db).update('customers', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  @override Future<Customer?> getCustomer(int id) async { final rows = await (await _db).query('customers', where: 'id = ?', whereArgs: [id], limit: 1); return rows.isEmpty ? null : _fromRow(rows.first); }
  @override Future<List<Customer>> getCustomers({bool activeOnly = true}) async => (await (await _db).query('customers', where: activeOnly ? 'is_active = 1' : null, orderBy: 'display_name COLLATE NOCASE')).map(_fromRow).toList();
  @override Future<void> updateCustomer(Customer customer) async { if (customer.id == null) throw ArgumentError('Customer id is required'); await (await _db).update('customers', _toRow(customer), where: 'id = ?', whereArgs: [customer.id]); }
}
