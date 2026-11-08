import 'package:cloud_firestore/cloud_firestore.dart';

import '../../employee/domain/employee.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');

  @override
  Future<void> sendNotification(AppNotification notification) async {
    try {
      final docRef = notification.id.isNotEmpty
          ? _notificationsRef.doc(notification.id)
          : _notificationsRef.doc();

      final data = notification.toMap();
      data['id'] = docRef.id;
      data['server_timestamp'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));
    } catch (e) {
      // Non-blocking error handling
      // debugPrint('Failed to send notification: $e');
    }
  }

  @override
  Stream<List<AppNotification>> watchNotificationsForUser({
    required Employee currentEmployee,
  }) {
    // Stream all recent notifications, ordered by created_at desc (limit 100)
    return _notificationsRef.snapshots().map((snapshot) {
      final all = snapshot.docs.map((doc) {
        return AppNotification.fromMap(doc.data(), doc.id);
      }).toList();

      // Sort newest first
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Filter by permissions or SuperAdmin
      if (currentEmployee.isSuperAdmin) {
        return all;
      }

      return all.where((n) {
        if (n.requiredPermission.isEmpty) return true;
        // User has explicit permission for the module
        return currentEmployee.hasPermission(n.requiredPermission);
      }).toList();
    });
  }

  @override
  Future<void> markAsRead({
    required String notificationId,
    required String employeeId,
  }) async {
    try {
      await _notificationsRef.doc(notificationId).update({
        'read_by_employee_ids': FieldValue.arrayUnion([employeeId]),
      });
    } catch (_) {}
  }

  @override
  Future<void> markAllAsRead({
    required String employeeId,
    required List<String> notificationIds,
  }) async {
    try {
      final batch = _firestore.batch();
      for (final id in notificationIds) {
        final doc = _notificationsRef.doc(id);
        batch.update(doc, {
          'read_by_employee_ids': FieldValue.arrayUnion([employeeId]),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).delete();
    } catch (_) {}
  }
}

