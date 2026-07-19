import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/vendor.dart';
import '../domain/vendor_repository.dart';

class SqliteVendorRepository implements VendorRepository {
  Database? _database;

  Future<Database> get _db async => _database ??= await openDatabase(
    p.join(await getDatabasesPath(), 'igreen_vendors.db'),
    version: 1,
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE vendors(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, company_name TEXT NOT NULL DEFAULT "", email TEXT NOT NULL DEFAULT "", work_phone TEXT NOT NULL DEFAULT "", gst_treatment TEXT NOT NULL, payables REAL NOT NULL DEFAULT 0)',
      );
      const regular = 'Registered Business - Regular';
      for (final vendor in <Map<String, Object>>[
        {
          'name': 'IGreen Technologies',
          'company_name': 'IGreen Technologies',
          'gst_treatment': regular,
        },
        {
          'name': 'RS Industrial Equipments',
          'company_name': 'RS Industrial Equipments',
          'gst_treatment': regular,
        },
        {
          'name': 'RAJLAXMI METAL SUPPLYS',
          'company_name': '',
          'gst_treatment': regular,
        },
        {
          'name': 'MAHAVIR METAL CORP/RAJLAXMI METALS SUPPLYS',
          'company_name': '',
          'gst_treatment': regular,
        },
        {
          'name': 'Srinivaas Additives & Labs',
          'company_name': 'Srinivaas Additives & Labs',
          'gst_treatment': regular,
        },
        {
          'name': 'Balambiga metal finishers',
          'company_name': '',
          'gst_treatment': regular,
        },
        {
          'name': 'The Light Companie',
          'company_name': 'The Light Companie',
          'gst_treatment': regular,
        },
        {
          'name': 'M K Enterprises',
          'company_name': 'M K Enterprises',
          'gst_treatment': regular,
        },
      ]) {
        await db.insert('vendors', vendor);
      }
    },
  );

  @override
  Future<List<Vendor>> getVendors() async {
    final rows = await (await _db).query('vendors', orderBy: 'id');
    return rows
        .map(
          (row) => Vendor(
            id: row['id'] as int,
            name: row['name'] as String,
            companyName: row['company_name'] as String,
            email: row['email'] as String,
            workPhone: row['work_phone'] as String,
            gstTreatment: row['gst_treatment'] as String,
            payables: (row['payables'] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }
}
