import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/clock_entry.dart';
import '../domain/clocking_repository.dart';
import '../data/firebase_clocking_repository.dart';

final clockingRepositoryProvider = Provider<ClockingRepository>((ref) {
  return FirebaseClockingRepository();
});

typedef ClockFilter = ({String? employeeId, DateTime? date});

DateTime _normalizeDate(DateTime? date) {
  final d = date ?? DateTime.now();
  return DateTime(d.year, d.month, d.day);
}

final clockEntriesProvider = FutureProvider.family<List<ClockEntry>, ClockFilter>((ref, filter) async {
  final repo = ref.watch(clockingRepositoryProvider);
  final empId = (filter.employeeId == null || filter.employeeId!.isEmpty)
      ? null
      : filter.employeeId;
  return repo.getClockEntries(
    employeeId: empId,
    date: _normalizeDate(filter.date),
  );
});

final activeClockEntryProvider = FutureProvider.family<ClockEntry?, String>((ref, employeeId) async {
  if (employeeId.trim().isEmpty) return null;
  final repo = ref.watch(clockingRepositoryProvider);
  return repo.getActiveEntry(employeeId.trim());
});

final allActiveClockEntriesProvider = FutureProvider<List<ClockEntry>>((ref) async {
  final repo = ref.watch(clockingRepositoryProvider);
  return repo.getAllActiveEntries();
});

final totalWorkHoursProvider = FutureProvider.family<double, ClockFilter>((ref, filter) async {
  final repo = ref.watch(clockingRepositoryProvider);
  final empId = filter.employeeId;
  if (empId == null || empId.trim().isEmpty) return 0.0;
  final normDate = _normalizeDate(filter.date);
  return repo.getTotalWorkHours(empId.trim(), normDate);
});

final totalBreakHoursProvider = FutureProvider.family<double, ClockFilter>((ref, filter) async {
  final repo = ref.watch(clockingRepositoryProvider);
  final empId = filter.employeeId;
  if (empId == null || empId.trim().isEmpty) return 0.0;
  final normDate = _normalizeDate(filter.date);
  return repo.getTotalBreakHours(empId.trim(), normDate);
});
