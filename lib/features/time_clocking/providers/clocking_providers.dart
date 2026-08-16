import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/clock_entry.dart';
import '../domain/clocking_repository.dart';
import '../data/firebase_clocking_repository.dart';

final clockingRepositoryProvider = Provider<ClockingRepository>((ref) {
  return FirebaseClockingRepository();
  // To switch back to SQLite: return SqliteClockingRepository();
});

typedef ClockFilter = ({String? employeeId, DateTime? date});

final clockEntriesProvider = FutureProvider.family<List<ClockEntry>, ClockFilter>((ref, filter) async {
  final repo = ref.watch(clockingRepositoryProvider);
  return repo.getClockEntries(
    employeeId: filter.employeeId,
    date: filter.date,
  );
});

final activeClockEntryProvider = FutureProvider.family<ClockEntry?, String>((ref, employeeId) async {
  final repo = ref.watch(clockingRepositoryProvider);
  return repo.getActiveEntry(employeeId);
});

final totalWorkHoursProvider = FutureProvider.family<double, ClockFilter>((ref, filter) async {
  final repo = ref.watch(clockingRepositoryProvider);
  final empId = filter.employeeId ?? 'EMP-001';
  final date = filter.date ?? DateTime.now();
  return repo.getTotalWorkHours(empId, date);
});

final totalBreakHoursProvider = FutureProvider.family<double, ClockFilter>((ref, filter) async {
  final repo = ref.watch(clockingRepositoryProvider);
  final empId = filter.employeeId ?? 'EMP-001';
  final date = filter.date ?? DateTime.now();
  return repo.getTotalBreakHours(empId, date);
});
