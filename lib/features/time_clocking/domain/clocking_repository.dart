import 'clock_entry.dart';

abstract class ClockingRepository {
  Future<List<ClockEntry>> getClockEntries({
    String? employeeId,
    DateTime? date,
  });

  Future<ClockEntry?> getActiveEntry(String employeeId);

  Future<void> startClockEntry(ClockEntry entry);

  Future<void> clockOutActiveEntry(String employeeId, {DateTime? time});

  Future<double> getTotalWorkHours(String employeeId, DateTime date);

  Future<double> getTotalBreakHours(String employeeId, DateTime date);
}
