import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../site_visit_attendance/domain/site_visit_record.dart';
import '../domain/site_visit_attendance_management_repository.dart';

class SqliteSiteVisitAttendanceManagementRepository implements SiteVisitAttendanceManagementRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_database.db');
    _database = await openDatabase(path);
    return _database!;
  }

  @override
  Future<void> deleteSiteVisit(int id) async {
    final db = await database;
    await db.delete('site_visit_records', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<SiteVisitRecord>> getAllSiteVisits({String? visitDate, int? employeeId, String? siteName}) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (visitDate != null) {
      clauses.add('visit_date = ?');
      args.add(visitDate);
    }
    if (employeeId != null) {
      clauses.add('employee_id = ?');
      args.add(employeeId);
    }
    if (siteName != null && siteName.trim().isNotEmpty) {
      clauses.add('site_name LIKE ?');
      args.add('%${siteName.trim()}%');
    }
    final rows = await db.query(
      'site_visit_records',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'visit_date DESC, visit_time DESC',
    );
    return rows.map(SiteVisitRecord.fromMap).toList();
  }
}
