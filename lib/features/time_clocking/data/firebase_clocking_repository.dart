import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../domain/clock_entry.dart';
import '../domain/clocking_repository.dart';

class FirebaseClockingRepository implements ClockingRepository {
  final FirebaseFirestore? _firestore;
  static final List<ClockEntry> _fallbackEntries = [];

  FirebaseClockingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _getFirestoreSafely();

  static FirebaseFirestore? _getFirestoreSafely() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _clockingRef =>
      _firestore?.collection('time_clockings');

  @override
  Future<List<ClockEntry>> getClockEntries({
    String? employeeId,
    DateTime? date,
  }) async {
    final List<ClockEntry> result = [];
    try {
      if (_clockingRef != null) {
        Query<Map<String, dynamic>> query = _clockingRef!;

        if (employeeId != null && employeeId.isNotEmpty) {
          query = query.where('employee_id', isEqualTo: employeeId);
        }

        final snapshot = await query.get().timeout(const Duration(seconds: 1));
        final firestoreEntries = snapshot.docs.map((doc) => ClockEntry.fromMap(doc.data())).toList();
        result.addAll(firestoreEntries);
      }
    } catch (_) {}

    final fallbackFiltered = _filterFallback(
      employeeId: employeeId,
      date: date,
    );

    for (final entry in fallbackFiltered) {
      if (!result.any((e) => e.id == entry.id)) {
        result.add(entry);
      }
    }

    if (date != null && result.isNotEmpty) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final filtered = result.where((e) => DateFormat('yyyy-MM-dd').format(e.startTime) == dateStr).toList();
      filtered.sort((a, b) => a.startTime.compareTo(b.startTime));
      return filtered;
    }

    result.sort((a, b) => a.startTime.compareTo(b.startTime));
    return result;
  }

  List<ClockEntry> _filterFallback({
    String? employeeId,
    DateTime? date,
  }) {
    return _fallbackEntries.where((e) {
      if (employeeId != null && employeeId.isNotEmpty && e.employeeId != employeeId) {
        return false;
      }
      if (date != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        if (DateFormat('yyyy-MM-dd').format(e.startTime) != dateStr) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Future<ClockEntry?> getActiveEntry(String employeeId) async {
    try {
      if (_clockingRef != null) {
        final snapshot = await _clockingRef!
            .where('employee_id', isEqualTo: employeeId)
            .where('end_time', isNull: true)
            .get()
            .timeout(const Duration(seconds: 1));

        if (snapshot.docs.isNotEmpty) {
          return ClockEntry.fromMap(snapshot.docs.first.data());
        }
      }
    } catch (_) {}

    final activeFallback = _fallbackEntries.where((e) => e.employeeId == employeeId && e.isActive).toList();
    if (activeFallback.isNotEmpty) {
      return activeFallback.last;
    }
    return null;
  }

  @override
  Future<List<ClockEntry>> getAllActiveEntries() async {
    try {
      if (_clockingRef != null) {
        final snapshot = await _clockingRef!
            .where('end_time', isNull: true)
            .get()
            .timeout(const Duration(seconds: 1));

        return snapshot.docs.map((doc) => ClockEntry.fromMap(doc.data())).toList();
      }
    } catch (_) {}

    return _fallbackEntries.where((e) => e.isActive).toList();
  }

  @override
  Future<void> startClockEntry(ClockEntry entry) async {
    await clockOutActiveEntry(entry.employeeId, time: entry.startTime);
    try {
      if (_clockingRef != null) {
        await _clockingRef!.doc(entry.id).set(entry.toMap()).timeout(const Duration(seconds: 1));
      }
    } catch (_) {}
    _fallbackEntries.removeWhere((e) => e.id == entry.id);
    _fallbackEntries.add(entry);
  }

  @override
  Future<void> clockOutActiveEntry(String employeeId, {DateTime? time}) async {
    final clockOutTime = (time ?? DateTime.now()).toIso8601String();
    try {
      if (_clockingRef != null) {
        final snapshot = await _clockingRef!
            .where('employee_id', isEqualTo: employeeId)
            .where('end_time', isNull: true)
            .get()
            .timeout(const Duration(seconds: 1));

        for (final doc in snapshot.docs) {
          await doc.reference.update({'end_time': clockOutTime});
        }
      }
    } catch (_) {}

    final clockOutDateTime = time ?? DateTime.now();
    for (int i = 0; i < _fallbackEntries.length; i++) {
      final e = _fallbackEntries[i];
      if (e.employeeId == employeeId && e.isActive) {
        _fallbackEntries[i] = e.copyWith(endTime: clockOutDateTime);
      }
    }
  }

  @override
  Future<void> adminClockOutEntry(String id, DateTime endTime) async {
    final clockOutTime = endTime.toIso8601String();
    try {
      if (_clockingRef != null) {
        await _clockingRef!.doc(id).update({'end_time': clockOutTime}).timeout(const Duration(seconds: 1));
      }
    } catch (_) {}

    for (int i = 0; i < _fallbackEntries.length; i++) {
      if (_fallbackEntries[i].id == id) {
        _fallbackEntries[i] = _fallbackEntries[i].copyWith(endTime: endTime);
      }
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
