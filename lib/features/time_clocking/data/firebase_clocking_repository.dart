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

  bool _matchesEmployee(dynamic docEmpId, String? targetEmpId) {
    if (targetEmpId == null || targetEmpId.trim().isEmpty) return true;
    final t = targetEmpId.trim().toLowerCase();
    final docStr = (docEmpId ?? '').toString().trim().toLowerCase();
    if (docStr.isEmpty) return false;
    if (docStr == t) return true;
    final tDigits = t.replaceAll(RegExp(r'\D'), '');
    final docDigits = docStr.replaceAll(RegExp(r'\D'), '');
    if (tDigits.isNotEmpty && tDigits == docDigits) return true;
    return false;
  }

  @override
  Future<List<ClockEntry>> getClockEntries({
    String? employeeId,
    DateTime? date,
  }) async {
    final List<ClockEntry> result = [];
    try {
      if (_clockingRef != null) {
        final snapshot = await _clockingRef!.get().timeout(const Duration(seconds: 5));
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            final docEmpId = data['employee_id'];
            if (_matchesEmployee(docEmpId, employeeId)) {
              final map = Map<String, dynamic>.from(data);
              if (!map.containsKey('id') || map['id'] == null || map['id'].toString().isEmpty) {
                map['id'] = doc.id;
              }
              result.add(ClockEntry.fromMap(map));
            }
          } catch (_) {}
        }
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
      if (employeeId != null && employeeId.isNotEmpty && !_matchesEmployee(e.employeeId, employeeId)) {
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
        final snapshot = await _clockingRef!.get().timeout(const Duration(seconds: 5));
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            final docEmpId = data['employee_id'];
            if (_matchesEmployee(docEmpId, employeeId)) {
              final map = Map<String, dynamic>.from(data);
              if (!map.containsKey('id') || map['id'] == null || map['id'].toString().isEmpty) {
                map['id'] = doc.id;
              }
              final entry = ClockEntry.fromMap(map);
              if (entry.isActive) {
                return entry;
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    final activeFallback = _fallbackEntries.where((e) => _matchesEmployee(e.employeeId, employeeId) && e.isActive).toList();
    if (activeFallback.isNotEmpty) {
      return activeFallback.last;
    }
    return null;
  }

  @override
  Future<List<ClockEntry>> getAllActiveEntries() async {
    try {
      if (_clockingRef != null) {
        final snapshot = await _clockingRef!.get().timeout(const Duration(seconds: 5));
        final List<ClockEntry> active = [];
        for (final doc in snapshot.docs) {
          try {
            final map = Map<String, dynamic>.from(doc.data());
            if (!map.containsKey('id') || map['id'] == null || map['id'].toString().isEmpty) {
              map['id'] = doc.id;
            }
            final entry = ClockEntry.fromMap(map);
            if (entry.isActive) active.add(entry);
          } catch (_) {}
        }
        return active;
      }
    } catch (_) {}

    return _fallbackEntries.where((e) => e.isActive).toList();
  }

  @override
  Future<void> startClockEntry(ClockEntry entry) async {
    await clockOutActiveEntry(entry.employeeId, time: entry.startTime);
    try {
      if (_clockingRef != null) {
        await _clockingRef!.doc(entry.id).set(entry.toMap()).timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    _fallbackEntries.removeWhere((e) => e.id == entry.id);
    _fallbackEntries.add(entry);
  }

  @override
  Future<void> clockOutActiveEntry(String employeeId, {DateTime? time}) async {
    final clockOutDateTime = time ?? DateTime.now();
    final clockOutTime = clockOutDateTime.toIso8601String();
    try {
      if (_clockingRef != null) {
        final snapshot = await _clockingRef!.get().timeout(const Duration(seconds: 5));
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final docEmpId = data['employee_id'];
          final endTimeVal = data['end_time'];
          final isNullOrEmpty = endTimeVal == null || endTimeVal.toString().trim().isEmpty;
          if (_matchesEmployee(docEmpId, employeeId) && isNullOrEmpty) {
            await doc.reference.update({'end_time': clockOutTime});
          }
        }
      }
    } catch (_) {}

    for (int i = 0; i < _fallbackEntries.length; i++) {
      final e = _fallbackEntries[i];
      if (_matchesEmployee(e.employeeId, employeeId) && e.isActive) {
        _fallbackEntries[i] = e.copyWith(endTime: clockOutDateTime);
      }
    }
  }

  @override
  Future<void> adminClockOutEntry(String id, DateTime endTime) async {
    final clockOutTime = endTime.toIso8601String();
    try {
      if (_clockingRef != null) {
        await _clockingRef!.doc(id).update({'end_time': clockOutTime}).timeout(const Duration(seconds: 5));
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
