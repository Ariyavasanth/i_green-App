import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/site_visit_attendance_repository.dart';
import '../domain/site_visit_record.dart';

class SqliteSiteVisitAttendanceRepository implements SiteVisitAttendanceRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await _createTables(_database!);
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async => _createTables(db),
      onOpen: (db) async => _createTables(db),
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS site_visit_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        employee_name TEXT NOT NULL,
        site_name TEXT NOT NULL,
        visit_date TEXT NOT NULL,
        visit_time TEXT NOT NULL,
        photo_url TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address TEXT NOT NULL,
        notes TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_site_visit_employee_date
      ON site_visit_records(employee_id, visit_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_site_visit_date
      ON site_visit_records(visit_date)
    ''');
  }

  @override
  Future<List<SiteVisitRecord>> getVisitsForEmployee({
    required int employeeId,
    required String visitDate,
  }) async {
    final db = await database;
    final rows = await db.query(
      'site_visit_records',
      where: 'employee_id = ? AND visit_date = ?',
      whereArgs: [employeeId, visitDate],
      orderBy: 'visit_time ASC',
    );
    return rows.map(SiteVisitRecord.fromMap).toList();
  }

  @override
  Future<List<SiteVisitRecord>> getAllVisits({String? visitDate}) async {
    final db = await database;
    final rows = await db.query(
      'site_visit_records',
      where: visitDate == null ? null : 'visit_date = ?',
      whereArgs: visitDate == null ? null : [visitDate],
      orderBy: 'visit_date DESC, visit_time DESC',
    );
    return rows.map(SiteVisitRecord.fromMap).toList();
  }

  @override
  Future<SiteVisitRecord?> getVisitById(int id) async {
    final db = await database;
    final rows = await db.query('site_visit_records', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return SiteVisitRecord.fromMap(rows.first);
  }

  @override
  Future<void> saveVisit(SiteVisitRecord record) async {
    final db = await database;
    await db.insert(
      'site_visit_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteVisit(int id) async {
    final db = await database;
    await db.delete('site_visit_records', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<String> createVisitPhotoUrl({
    required String localImagePath,
    required String employeeName,
    required String siteName,
    required String visitDate,
    required String visitTime,
    required double latitude,
    required double longitude,
  }) async {
    final file = File(localImagePath);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return localImagePath;

    final stamp = img.copyResize(decoded, width: decoded.width);
    final black = img.ColorRgb8(0, 0, 0);
    final white = img.ColorRgb8(255, 255, 255);
    final footerHeight = (stamp.height * 0.18).clamp(110, 180).toInt();
    final canvas = img.Image(width: stamp.width, height: stamp.height + footerHeight);
    img.fill(canvas, color: black);
    img.compositeImage(canvas, stamp, dstX: 0, dstY: 0);
    img.drawString(canvas, employeeName, font: img.arial24, x: 16, y: stamp.height + 12, color: white);
    img.drawString(canvas, siteName, font: img.arial24, x: 16, y: stamp.height + 38, color: white);
    img.drawString(canvas, '$visitDate $visitTime', font: img.arial24, x: 16, y: stamp.height + 64, color: white);
    img.drawString(canvas, 'Lat: ${latitude.toStringAsFixed(6)}', font: img.arial14, x: 16, y: stamp.height + 94, color: white);
    img.drawString(canvas, 'Lng: ${longitude.toStringAsFixed(6)}', font: img.arial14, x: 16, y: stamp.height + 114, color: white);

    final outPath = join(
      Directory.systemTemp.path,
      'site_visit_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(outPath).writeAsBytes(img.encodeJpg(canvas));
    return outPath;
  }
}
