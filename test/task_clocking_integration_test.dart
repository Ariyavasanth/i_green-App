import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/task_management/domain/task_item.dart';
import 'package:flutter_application_1/features/time_clocking/domain/clock_entry.dart';
import 'package:flutter_application_1/features/time_clocking/data/firebase_clocking_repository.dart';
import 'package:flutter_application_1/features/task_management/data/firebase_task_repository.dart';

void main() {
  group('Task ↔ Clocking Integration & Single Active-Work Rule Tests', () {
    late FirebaseTaskRepository taskRepo;
    late FirebaseClockingRepository clockingRepo;

    setUp(() {
      taskRepo = FirebaseTaskRepository();
      clockingRepo = FirebaseClockingRepository();
    });

    test('Test 1 — Attendance + Task duration calculation', () async {
      final startTime = DateTime(2026, 8, 17, 9, 15);
      final endTime = DateTime(2026, 8, 17, 11, 00);

      final task = TaskItem(
        id: 'T1',
        title: 'Client Project',
        projectOrOfficeCode: 'PRJ-101',
        assignedBy: 'Admin',
        assignedTo: 'EMP-001',
        startTime: startTime,
        endTime: endTime,
        status: 'COMPLETED',
      );

      await taskRepo.createTask(task);

      // Verify task duration
      expect(task.duration.inMinutes, 105); // 1h 45m
      expect(task.durationInHours, 1.75);
    });

    test('Test 2 — Attendance + Clocking work vs break calculation', () async {
      final workStart = DateTime(2026, 8, 17, 9, 15);
      final workEnd = DateTime(2026, 8, 17, 11, 00);
      final lunchStart = DateTime(2026, 8, 17, 13, 00);
      final lunchEnd = DateTime(2026, 8, 17, 14, 00);

      final workEntry = ClockEntry(
        id: 'C1',
        employeeId: 'EMP-002',
        entryType: 'General Work',
        startTime: workStart,
        endTime: workEnd,
      );

      final lunchEntry = ClockEntry(
        id: 'C2',
        employeeId: 'EMP-002',
        entryType: 'Lunch',
        startTime: lunchStart,
        endTime: lunchEnd,
      );

      await clockingRepo.startClockEntry(workEntry);
      await clockingRepo.clockOutActiveEntry('EMP-002', time: workEnd);

      await clockingRepo.startClockEntry(lunchEntry);
      await clockingRepo.clockOutActiveEntry('EMP-002', time: lunchEnd);

      final workHours = await clockingRepo.getTotalWorkHours('EMP-002', DateTime(2026, 8, 17));
      final breakHours = await clockingRepo.getTotalBreakHours('EMP-002', DateTime(2026, 8, 17));

      expect(workHours, 1.75); // 1h 45m
      expect(breakHours, 1.0);  // 1h Lunch
    });

    test('Test 3 — Task → Clocking transition (No Overlap)', () async {
      const empId = 'EMP-003';
      final taskStart = DateTime(2026, 8, 17, 9, 15);
      final transitionTime = DateTime(2026, 8, 17, 11, 00);
      final clockingEnd = DateTime(2026, 8, 17, 12, 00);

      // 1. Employee starts Task at 09:15
      final task = TaskItem(
        id: 'T3',
        title: 'Project A',
        projectOrOfficeCode: 'PRJ-3',
        assignedBy: 'Admin',
        assignedTo: empId,
        startTime: taskStart,
        status: 'IN_PROGRESS',
      );
      await taskRepo.createTask(task);

      // Verify task is currently active
      final activeTasks1 = await taskRepo.getTasks(assignedTo: empId, status: 'IN_PROGRESS');
      expect(activeTasks1.length, 1);

      // 2. At 11:00, Employee starts WORK Clocking
      // System must auto-complete the active task at transitionTime
      for (final t in activeTasks1) {
        await taskRepo.updateTask(t.copyWith(status: 'COMPLETED', endTime: transitionTime));
      }

      final clockEntry = ClockEntry(
        id: 'C3',
        employeeId: empId,
        entryType: 'General Work',
        startTime: transitionTime,
      );
      await clockingRepo.startClockEntry(clockEntry);

      // 3. At 12:00, Stop WORK Clocking
      await clockingRepo.clockOutActiveEntry(empId, time: clockingEnd);

      // Verify no active tasks and no active clockings
      final activeTasksAfter = await taskRepo.getTasks(assignedTo: empId, status: 'IN_PROGRESS');
      expect(activeTasksAfter, isEmpty);

      final completedTask = await taskRepo.getTaskById('T3');
      expect(completedTask?.duration.inMinutes, 105); // 09:15 -> 11:00 = 1h45m

      final clockEntries = await clockingRepo.getClockEntries(employeeId: empId, date: DateTime(2026, 8, 17));
      expect(clockEntries.length, 1);
      expect(clockEntries.first.duration.inMinutes, 60); // 11:00 -> 12:00 = 1h
    });

    test('Test 4 — Clocking → Task transition (No Overlap)', () async {
      const empId = 'EMP-004';
      final clockingStart = DateTime(2026, 8, 17, 9, 15);
      final transitionTime = DateTime(2026, 8, 17, 10, 00);
      final taskEnd = DateTime(2026, 8, 17, 12, 00);

      // 1. Employee starts WORK Clocking at 09:15
      final clockEntry = ClockEntry(
        id: 'C4',
        employeeId: empId,
        entryType: 'General Work',
        startTime: clockingStart,
      );
      await clockingRepo.startClockEntry(clockEntry);

      final activeClocking1 = await clockingRepo.getActiveEntry(empId);
      expect(activeClocking1, isNotNull);

      // 2. At 10:00, Employee starts Task
      // System must auto clock-out active Clocking entry at transitionTime
      await clockingRepo.clockOutActiveEntry(empId, time: transitionTime);

      final task = TaskItem(
        id: 'T4',
        title: 'Project B',
        projectOrOfficeCode: 'PRJ-4',
        assignedBy: 'Admin',
        assignedTo: empId,
        startTime: transitionTime,
        status: 'IN_PROGRESS',
      );
      await taskRepo.createTask(task);

      // 3. At 12:00, Stop Task
      await taskRepo.updateTask(task.copyWith(status: 'COMPLETED', endTime: taskEnd));

      // Verify durations
      final entries = await clockingRepo.getClockEntries(employeeId: empId, date: DateTime(2026, 8, 17));
      expect(entries.first.duration.inMinutes, 45); // 09:15 -> 10:00 = 45m

      final completedTask = await taskRepo.getTaskById('T4');
      expect(completedTask?.duration.inMinutes, 120); // 10:00 -> 12:00 = 2h
    });
  });
}
