import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../domain/clock_entry.dart';
import '../domain/clocking_repository.dart';

class FirebaseClockingRepository implements ClockingRepository {
  final FirebaseFirestore _firestore;

  FirebaseClockingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _clockingRef =>
      _firestore.collection('time_clockings');

  @override
  Future<List<ClockEntry>> getClockEntries({
    String? employeeId,
    DateTime? date,
  }) async {
    Query<Map<String, dynamic>> query = _clockingRef;

    if (employeeId != null && employeeId.isNotEmpty) {
      query = query.where('employee_id', isEqualTo: employeeId);
    }

    final snapshot = await query.get();
    var entries = snapshot.docs.map((doc) => ClockEntry.fromMap(doc.data())).toList();

    if (date != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      entries = entries.where((e) => DateFormat('yyyy-MM-dd').format(e.startTime) == dateStr).toList();
    }

    entries.sort((a, b) => a.startTime.compareTo(b.startTime));
    return entries;
  }

  @override
  Future<ClockEntry?> getActiveEntry(String employeeId) async {
    final snapshot = await _clockingRef
        .where('employee_id', isEqualTo: employeeId)
        .where('end_time', isNull: true)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ClockEntry.fromMap(snapshot.docs.first.data());
  }

  @override
  Future<void> startClockEntry(ClockEntry entry) async {
    await clockOutActiveEntry(entry.employeeId, time: entry.startTime);
    await _clockingRef.doc(entry.id).set(entry.toMap());
  }

  @override
  Future<void> clockOutActiveEntry(String employeeId, {DateTime? time}) async {
    final snapshot = await _clockingRef
        .where('employee_id', isEqualTo: employeeId)
        .where('end_time', isNull: true)
        .get();

    final clockOutTime = (time ?? DateTime.now()).toIso8601String();
    for (final doc in snapshot.docs) {
      await doc.reference.update({'end_time': clockOutTime});
    }
  }

  @override
  Future<double> getTotalWorkHours(String employeeId, DateTime date) async {
    final entries = await getClockEntries(employeeId: employeeId, date: date);
    double workHours = 0.0;
    for (final e in entries) {
      if (!e.isBreak) {
        workHours += e.durationInHours;
      }
    }
    return workHours;
  }

  @override
  Future<double> getTotalBreakHours(String employeeId, DateTime date) async {
    final entries = await getClockEntries(employeeId: employeeId, date: date);
    double breakHours = 0.0;
    for (final e in entries) {
      if (e.isBreak) {
        breakHours += e.durationInHours;
      }
    }
    return breakHours;
  }
}
