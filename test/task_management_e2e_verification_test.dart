import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/task_management/domain/task_item.dart';
import 'package:flutter_application_1/features/task_management/data/firebase_task_repository.dart';
import 'package:flutter_application_1/features/time_clocking/domain/clock_entry.dart';
import 'package:flutter_application_1/features/time_clocking/data/firebase_clocking_repository.dart';

void main() {
  group('Task Management — Complete End-to-End Test Suite', () {
    late FirebaseTaskRepository taskRepo;
    late FirebaseClockingRepository clockingRepo;

    setUp(() {
      taskRepo = FirebaseTaskRepository();
      clockingRepo = FirebaseClockingRepository();
    });

    // =========================================================================
    // 1. Admin Task Creation & SLA Calculation
    // =========================================================================
    test('1. Admin Task Creation — Priority SLA durations and assignment anchoring', () async {
      final assignTime = DateTime(2026, 9, 26, 14, 0); // 2:00 PM

      // Low Priority (30 days / 720 hours)
      final lowTask = TaskItem(
        id: 'T-LOW',
        title: 'Low Priority Audit',
        projectOrOfficeCode: 'PRJ-101',
        assignedBy: 'Super Admin',
        assignedTo: 'EMP-001',
        startTime: assignTime,
        assignedAt: assignTime,
        createdAt: assignTime,
        priority: 'LOW',
        status: 'TODO',
      );
      expect(lowTask.slaDurationHours, 720);
      expect(lowTask.deadline, assignTime.add(const Duration(days: 30)));

      // Medium Priority (15 days / 360 hours)
      final medTask = TaskItem(
        id: 'T-MED',
        title: 'Medium Priority Task',
        projectOrOfficeCode: 'PRJ-102',
        assignedBy: 'Super Admin',
        assignedTo: 'EMP-001',
        startTime: assignTime,
        assignedAt: assignTime,
        createdAt: assignTime,
        priority: 'MEDIUM',
        status: 'TODO',
      );
      expect(medTask.slaDurationHours, 360);
      expect(medTask.deadline, assignTime.add(const Duration(days: 15)));

      // High Priority (8 hours)
      final highTask = TaskItem(
        id: 'T-HIGH',
        title: 'High Priority Task',
        projectOrOfficeCode: 'PRJ-103',
        assignedBy: 'Super Admin',
        assignedTo: 'EMP-001',
        startTime: assignTime,
        assignedAt: assignTime,
        createdAt: assignTime,
        priority: 'HIGH',
        status: 'TODO',
      );
      expect(highTask.slaDurationHours, 8);
      expect(highTask.deadline, assignTime.add(const Duration(hours: 8)));

      // Very High Priority (3 hours)
      final vHighTask = TaskItem(
        id: 'T-VHIGH',
        title: 'Very High Priority Task',
        projectOrOfficeCode: 'PRJ-104',
        assignedBy: 'Super Admin',
        assignedTo: 'EMP-001',
        startTime: assignTime,
        assignedAt: assignTime,
        createdAt: assignTime,
        priority: 'VERY_HIGH',
        status: 'TODO',
      );
      expect(vHighTask.slaDurationHours, 3);
      expect(vHighTask.deadline, DateTime(2026, 9, 26, 17, 0)); // 5:00 PM
      expect(vHighTask.assignedAt, assignTime);

      await taskRepo.createTask(vHighTask);
      final fetched = await taskRepo.getTaskById('T-VHIGH');
      expect(fetched, isNotNull);
      expect(fetched!.priority, 'VERY_HIGH');
      expect(fetched.deadline, DateTime(2026, 9, 26, 17, 0));
    });

    // =========================================================================
    // 2. Employee Visibility & Self-Assignment Restriction
    // =========================================================================
    test('2. Employee Visibility & Self-Assignment Lock', () async {
      const empA = 'EMP-001';
      const empB = 'EMP-002';
      final now = DateTime.now();

      // Create Task for Emp A
      final taskA = TaskItem(
        id: 'T-EMPA',
        title: 'Employee A Private Task',
        projectOrOfficeCode: 'PRJ-A',
        assignedBy: 'Admin',
        assignedTo: empA,
        startTime: now,
        status: 'TODO',
      );
      await taskRepo.createTask(taskA);

      // Create Task for Emp B
      final taskB = TaskItem(
        id: 'T-EMPB',
        title: 'Employee B Private Task',
        projectOrOfficeCode: 'PRJ-B',
        assignedBy: 'Admin',
        assignedTo: empB,
        startTime: now,
        status: 'TODO',
      );
      await taskRepo.createTask(taskB);

      // Emp A only retrieves tasks for Emp A
      final tasksForA = await taskRepo.getTasks(assignedTo: empA);
      expect(tasksForA.any((t) => t.id == 'T-EMPA'), isTrue);
      expect(tasksForA.any((t) => t.id == 'T-EMPB'), isFalse);

      // Self-Assignment by Emp A
      final selfAssignedTask = TaskItem(
        id: 'T-SELF',
        title: 'Self Assigned Cleanup',
        projectOrOfficeCode: 'OFFICE-01',
        assignedBy: 'John Doe (Self)',
        assignedTo: empA, // Locked to current employee
        startTime: now,
        priority: 'HIGH',
        status: 'TODO',
      );
      await taskRepo.createTask(selfAssignedTask);

      // Visible in Employee A's tasks
      final updatedTasksForA = await taskRepo.getTasks(assignedTo: empA);
      expect(updatedTasksForA.any((t) => t.id == 'T-SELF'), isTrue);

      // Visible in Admin Task Board (query without assignedTo filter)
      final allAdminTasks = await taskRepo.getTasks();
      expect(allAdminTasks.any((t) => t.id == 'T-SELF'), isTrue);
    });

    // =========================================================================
    // 3. Start Task & Single Active Task Enforcement
    // =========================================================================
    test('3. Start Task Flow & Auto-Pause of Existing Active Tasks', () async {
      const empId = 'EMP-001';
      final t0 = DateTime(2026, 9, 26, 9, 0);

      final task1 = TaskItem(
        id: 'T-RUN-1',
        title: 'First Active Task',
        projectOrOfficeCode: 'PRJ-1',
        assignedBy: 'Admin',
        assignedTo: empId,
        startTime: t0,
        status: 'IN_PROGRESS',
        isPaused: false,
      );
      await taskRepo.createTask(task1);

      // Employee starts second task at 9:30
      final t1 = DateTime(2026, 9, 26, 9, 30);
      final task2 = TaskItem(
        id: 'T-RUN-2',
        title: 'Second Task to Start',
        projectOrOfficeCode: 'PRJ-2',
        assignedBy: 'Admin',
        assignedTo: empId,
        startTime: t1,
        status: 'TODO',
      );
      await taskRepo.createTask(task2);

      // Business Rule: Auto-pause any active task when starting another task
      final activeTasks = await taskRepo.getTasks(assignedTo: empId, status: 'IN_PROGRESS');
      for (final t in activeTasks) {
        if (!t.isPaused) {
          await taskRepo.updateTask(t.copyWith(
            isPaused: true,
            accumulatedSeconds: 1800, // 30 minutes
          ));
        }
      }

      // Start task2
      await taskRepo.updateTask(task2.copyWith(
        status: 'IN_PROGRESS',
        startTime: t1,
        isPaused: false,
      ));

      final updatedTask1 = await taskRepo.getTaskById('T-RUN-1');
      final updatedTask2 = await taskRepo.getTaskById('T-RUN-2');

      expect(updatedTask1!.status, 'IN_PROGRESS');
      expect(updatedTask1.isPaused, isTrue);
      expect(updatedTask1.accumulatedSeconds, 1800);

      expect(updatedTask2!.status, 'IN_PROGRESS');
      expect(updatedTask2.isPaused, isFalse);
    });

    // =========================================================================
    // 4. Pause / Stop Task (Without Completing)
    // =========================================================================
    test('4. Pause / Stop Task — Preserves IN_PROGRESS status and tracks time', () async {
      final startTime = DateTime(2026, 9, 26, 10, 0);
      final pauseTime = DateTime(2026, 9, 26, 10, 45); // 45 min later

      final task = TaskItem(
        id: 'T-PAUSE',
        title: 'Task To Pause',
        projectOrOfficeCode: 'PRJ-101',
        assignedBy: 'Admin',
        assignedTo: 'EMP-001',
        startTime: startTime,
        status: 'IN_PROGRESS',
        isPaused: false,
      );
      await taskRepo.createTask(task);

      // Employee clicks [Pause Task]
      final pausedTask = task.copyWith(
        isPaused: true,
        accumulatedSeconds: pauseTime.difference(startTime).inSeconds, // 2700s
      );
      await taskRepo.updateTask(pausedTask);

      final fetched = await taskRepo.getTaskById('T-PAUSE');
      expect(fetched!.status, 'IN_PROGRESS'); // Must NOT become COMPLETED
      expect(fetched.isPaused, isTrue);
      expect(fetched.accumulatedSeconds, 2700);
      expect(fetched.duration.inMinutes, 45);

      // Employee clicks [Resume Task] 15 mins later
      final resumeTime = DateTime(2026, 9, 26, 11, 0);
      final resumedTask = fetched.copyWith(
        isPaused: false,
        lastResumedAt: resumeTime,
      );
      await taskRepo.updateTask(resumedTask);

      final fetchedResumed = await taskRepo.getTaskById('T-PAUSE');
      expect(fetchedResumed!.isPaused, isFalse);
      expect(fetchedResumed.status, 'IN_PROGRESS');
    });

    // =========================================================================
    // 5. Complete Task with Description & Photo Proof
    // =========================================================================
    test('5. Complete Task Flow — Required fields, photo proof and timeline persistence', () async {
      final startTime = DateTime(2026, 9, 26, 13, 0);
      final completionTime = DateTime(2026, 9, 26, 14, 15); // 1h 15m
      const dummyPhotoBase64 = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD...';

      final task = TaskItem(
        id: 'T-COMPLETE',
        title: 'HVAC Duct Installation',
        projectOrOfficeCode: 'PRJ-HVAC',
        assignedBy: 'Admin',
        assignedTo: 'EMP-001',
        startTime: startTime,
        priority: 'HIGH',
        status: 'IN_PROGRESS',
      );
      await taskRepo.createTask(task);

      // Complete task with description and photo
      final completed = task.copyWith(
        status: 'COMPLETED',
        endTime: completionTime,
        completionDescription: 'Installed ducting in Sector 4 and pressure tested successfully.',
        completionPhotoUrl: dummyPhotoBase64,
      );
      await taskRepo.updateTask(completed);

      final fetched = await taskRepo.getTaskById('T-COMPLETE');
      expect(fetched!.status, 'COMPLETED');
      expect(fetched.endTime, completionTime);
      expect(fetched.duration.inMinutes, 75); // 1h 15m
      expect(fetched.completionDescription, 'Installed ducting in Sector 4 and pressure tested successfully.');
      expect(fetched.completionPhotoUrl, dummyPhotoBase64);
    });

    // =========================================================================
    // 6. SLA On-Time vs Breached Verification
    // =========================================================================
    test('6. SLA Tracking — On-Time vs Breached Scenarios', () async {
      final assignTime = DateTime(2026, 9, 26, 14, 0); // 2:00 PM
      final deadline = DateTime(2026, 9, 26, 17, 0);   // 5:00 PM (3h SLA for VERY_HIGH)

      // On-Time Completed Task (Completed at 4:30 PM)
      final onTimeTask = TaskItem(
        id: 'T-ONTIME',
        title: 'Urgent Wire Replacement',
        projectOrOfficeCode: 'PRJ-101',
        assignedBy: 'Admin',
        assignedTo: 'EMP-001',
        startTime: assignTime,
        assignedAt: assignTime,
        createdAt: assignTime,
        deadline: deadline,
        priority: 'VERY_HIGH',
        status: 'COMPLETED',
        endTime: DateTime(2026, 9, 26, 16, 30), // 4:30 PM
      );
      expect(onTimeTask.isBreached, isFalse);

      // Breached Completed Task (Completed at 5:30 PM)
      final breachedCompletedTask = TaskItem(
        id: 'T-BREACHED-DONE',
        title: 'Late Wire Replacement',
        projectOrOfficeCode: 'PRJ-101',
        assignedBy: 'Admin',
        assignedTo: 'EMP-001',
        startTime: assignTime,
        assignedAt: assignTime,
        createdAt: assignTime,
        deadline: deadline,
        priority: 'VERY_HIGH',
        status: 'COMPLETED',
        endTime: DateTime(2026, 9, 26, 17, 30), // 5:30 PM
      );
      expect(breachedCompletedTask.isBreached, isTrue);
      expect(breachedCompletedTask.formattedBreachDuration, '30m');

      // Active Breached Task (Current Time Past Deadline)
      final pastDeadline = DateTime.now().subtract(const Duration(hours: 1));
      final activeBreachedTask = TaskItem(
        id: 'T-BREACHED-ACTIVE',
        title: 'Overdue Inspection',
        projectOrOfficeCode: 'PRJ-102',
        assignedBy: 'Admin',
        assignedTo: 'EMP-001',
        startTime: pastDeadline.subtract(const Duration(hours: 3)),
        assignedAt: pastDeadline.subtract(const Duration(hours: 3)),
        createdAt: pastDeadline.subtract(const Duration(hours: 3)),
        deadline: pastDeadline, // 1 hour ago
        priority: 'VERY_HIGH',
        status: 'IN_PROGRESS',
      );
      expect(activeBreachedTask.isBreached, isTrue);
      // Active breached tasks must remain executable and completable
      final finishedActiveBreach = activeBreachedTask.copyWith(
        status: 'COMPLETED',
        endTime: DateTime.now(),
        completionDescription: 'Finished after delay due to material delivery.',
      );
      expect(finishedActiveBreach.status, 'COMPLETED');
      expect(finishedActiveBreach.isBreached, isTrue);
    });

    // =========================================================================
    // 7. Historical Filters & Assignment Time Scoping
    // =========================================================================
    test('7. Historical Task Querying & AssignedAt Anchoring', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // Task assigned yesterday, but worked on today
      final taskYesterday = TaskItem(
        id: 'T-YESTERDAY',
        title: 'Yesterday Assigned Task',
        projectOrOfficeCode: 'PRJ-YEST',
        assignedBy: 'Admin',
        assignedTo: 'EMP-001',
        assignedAt: yesterday,
        createdAt: yesterday,
        startTime: now, // Worked today
        status: 'COMPLETED',
        endTime: now.add(const Duration(hours: 1)),
      );
      await taskRepo.createTask(taskYesterday);

      // Verify task assignedAt matches yesterday
      final fetched = await taskRepo.getTaskById('T-YESTERDAY');
      expect(fetched!.assignedAt.day, yesterday.day);
      expect(fetched.assignedAt.month, yesterday.month);
      expect(fetched.assignedAt.year, yesterday.year);
    });

    // =========================================================================
    // 8. Firestore Serialization / Deserialization Consistency
    // =========================================================================
    test('8. Full Firestore Schema Serialization Roundtrip', () {
      final original = TaskItem(
        id: 'T-ROUNDTRIP',
        title: 'Full Audit Verification',
        projectOrOfficeCode: 'PRJ-999',
        assignedBy: 'Admin Manager',
        assignedTo: 'EMP-777',
        startTime: DateTime(2026, 9, 26, 10, 0),
        endTime: DateTime(2026, 9, 26, 12, 30),
        status: 'COMPLETED',
        priority: 'HIGH',
        assignedAt: DateTime(2026, 9, 26, 9, 0),
        createdAt: DateTime(2026, 9, 26, 9, 0),
        slaDurationHours: 8,
        deadline: DateTime(2026, 9, 26, 17, 0),
        breached: false,
        isPaused: true,
        accumulatedSeconds: 3600,
        lastResumedAt: DateTime(2026, 9, 26, 11, 0),
        completionDescription: 'Everything inspected according to ISO standards.',
        completionPhotoUrl: 'data:image/jpeg;base64,samplephoto123',
      );

      final map = original.toMap();
      final reconstructed = TaskItem.fromMap(map);

      expect(reconstructed.id, original.id);
      expect(reconstructed.title, original.title);
      expect(reconstructed.projectOrOfficeCode, original.projectOrOfficeCode);
      expect(reconstructed.assignedBy, original.assignedBy);
      expect(reconstructed.assignedTo, original.assignedTo);
      expect(reconstructed.priority, original.priority);
      expect(reconstructed.slaDurationHours, original.slaDurationHours);
      expect(reconstructed.deadline, original.deadline);
      expect(reconstructed.isPaused, original.isPaused);
      expect(reconstructed.accumulatedSeconds, original.accumulatedSeconds);
      expect(reconstructed.completionDescription, original.completionDescription);
      expect(reconstructed.completionPhotoUrl, original.completionPhotoUrl);
      expect(reconstructed.status, original.status);
    });
  });
}
