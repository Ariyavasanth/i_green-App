/// ONE-TIME CLEANUP TOOL — Run once, then DELETE this file.
///
/// Permanently deletes an employee and ALL their related Firestore data.
/// Usage: Call [cleanupEmployeeByCode('EMP-0001')] from any admin screen.
///
/// HOW TO RUN:
///   1. Import this file in any admin screen temporarily
///   2. Add: ElevatedButton(onPressed: () => cleanupEmployeeByCode('EMP-0001'), child: Text('Delete'))
///   3. Tap once — watch debug console for progress
///   4. Delete this file and the button when done

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> cleanupEmployeeByCode(String employeeCode) async {
  final code = employeeCode.trim().toUpperCase();
  if (code.isEmpty) {
    debugPrint('[Cleanup] No employee code provided. Aborting.');
    return;
  }

  debugPrint('[Cleanup] Starting permanent deletion of employee: $code');
  final firestore = FirebaseFirestore.instance;
  int totalDeleted = 0;

  // 1. employees
  try {
    final snap = await firestore.collection('employees').get();
    for (final doc in snap.docs) {
      final docId = doc.id.trim().toUpperCase();
      final empId = (doc.data()['employee_id'] ?? '').toString().trim().toUpperCase();
      if (docId == code || empId == code) {
        await doc.reference.delete();
        debugPrint('[Cleanup] Deleted employee: ${doc.id}');
        totalDeleted++;
      }
    }
  } catch (e) { debugPrint('[Cleanup] employees error: $e'); }

  // 2. attendance_records
  try {
    final snap = await firestore.collection('attendance_records').get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final docId = doc.id.trim().toUpperCase();
      final empCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
      if (docId.startsWith('${code}_') || empCode == code) {
        await doc.reference.delete();
        debugPrint('[Cleanup] Deleted attendance_record: ${doc.id}');
        totalDeleted++;
      }
    }
  } catch (e) { debugPrint('[Cleanup] attendance_records error: $e'); }

  // 3. attendance_attempts
  try {
    final snap = await firestore.collection('attendance_attempts').get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final empCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
      if (empCode == code) {
        await doc.reference.delete();
        debugPrint('[Cleanup] Deleted attendance_attempt: ${doc.id}');
        totalDeleted++;
      }
    }
  } catch (e) { debugPrint('[Cleanup] attendance_attempts error: $e'); }

  // 4. leave_requests
  try {
    final snap = await firestore.collection('leave_requests').get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final empCode = (data['employee_custom_id'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
      if (empCode == code) {
        await doc.reference.delete();
        debugPrint('[Cleanup] Deleted leave_request: ${doc.id}');
        totalDeleted++;
      }
    }
  } catch (e) { debugPrint('[Cleanup] leave_requests error: $e'); }

  // 5. on_duty_assignments
  try {
    final snap = await firestore.collection('on_duty_assignments').get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final empCode = (data['employee_code'] ?? data['employee_custom_id'] ?? '').toString().trim().toUpperCase();
      if (empCode == code) {
        await doc.reference.delete();
        debugPrint('[Cleanup] Deleted on_duty_assignment: ${doc.id}');
        totalDeleted++;
      }
    }
  } catch (e) { debugPrint('[Cleanup] on_duty_assignments error: $e'); }

  // 6. permissions
  try {
    final snap = await firestore.collection('permissions').get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final empCode = (data['employee_code'] ?? data['employee_id'] ?? '').toString().trim().toUpperCase();
      if (empCode == code) {
        await doc.reference.delete();
        debugPrint('[Cleanup] Deleted permission: ${doc.id}');
        totalDeleted++;
      }
    }
  } catch (e) { debugPrint('[Cleanup] permissions error: $e'); }

  debugPrint('[Cleanup] Done! Deleted $totalDeleted documents for: $code');
  debugPrint('[Cleanup] You can now delete lib/tools/cleanup_employee_data.dart');
}
