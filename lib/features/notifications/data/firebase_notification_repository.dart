import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../../employee/domain/employee.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> get _fcmTokensRef =>
      _firestore.collection('fcm_tokens');

  String _tokenDocId(String token) =>
      sha256.convert(utf8.encode(token.trim())).toString();

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

  static const int _maxVisibleNotifications = 50;
  static const Duration _retentionWindow = Duration(days: 30);

  @override
  Stream<List<AppNotification>> watchNotificationsForUser({
    required Employee currentEmployee,
  }) {
    final empIdStr = currentEmployee.id.toString();
    final empCodeStr = currentEmployee.employeeId.trim();

    return _notificationsRef.snapshots().map((snapshot) {
      final cutoff = DateTime.now().subtract(_retentionWindow);

      final all = snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
          .where((n) {
        // Hide notifications older than the retention window
        if (n.createdAt.isBefore(cutoff)) return false;

        // Hide notifications already seen (read) or dismissed by this user
        if (empIdStr.isNotEmpty &&
            (n.isReadBy(empIdStr) || n.isDismissedBy(empIdStr))) {
          return false;
        }
        if (empCodeStr.isNotEmpty &&
            (n.isReadBy(empCodeStr) || n.isDismissedBy(empCodeStr))) {
          return false;
        }

        // Filter by permissions or SuperAdmin
        if (currentEmployee.isSuperAdmin) return true;
        if (n.requiredPermission.isEmpty) return true;
        return currentEmployee.hasPermission(n.requiredPermission);
      }).toList();

      // Sort newest first and cap to most recent 50
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (all.length > _maxVisibleNotifications) {
        return all.sublist(0, _maxVisibleNotifications);
      }
      return all;
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
    if (employeeId.isEmpty || notificationIds.isEmpty) return;
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
  Future<void> dismissNotification({
    required String notificationId,
    required String employeeId,
  }) async {
    if (employeeId.isEmpty || notificationId.isEmpty) return;
    try {
      await _notificationsRef.doc(notificationId).update({
        'read_by_employee_ids': FieldValue.arrayUnion([employeeId]),
        'dismissed_by_employee_ids': FieldValue.arrayUnion([employeeId]),
      });
    } catch (_) {}
  }

  @override
  Future<void> clearNotifications({
    required String employeeId,
    required List<String> notificationIds,
  }) async {
    if (employeeId.isEmpty || notificationIds.isEmpty) return;
    try {
      const batchSize = 400;
      for (var i = 0; i < notificationIds.length; i += batchSize) {
        final chunk = notificationIds.sublist(
          i,
          (i + batchSize > notificationIds.length)
              ? notificationIds.length
              : i + batchSize,
        );
        final batch = _firestore.batch();
        for (final id in chunk) {
          final doc = _notificationsRef.doc(id);
          batch.update(doc, {
            'read_by_employee_ids': FieldValue.arrayUnion([employeeId]),
            'dismissed_by_employee_ids': FieldValue.arrayUnion([employeeId]),
          });
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).delete();
    } catch (_) {}
  }

  @override
  Future<void> saveFcmToken({
    required Employee employee,
    required String token,
    required String platform,
  }) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return;

    try {
      final docId = _tokenDocId(cleanToken);
      await _fcmTokensRef.doc(docId).set({
        'token': cleanToken,
        'employee_id': employee.id,
        'employee_code': employee.employeeId,
        'email': employee.emailAddress.trim().toLowerCase(),
        'employee_name': employee.fullName,
        'user_type': employee.userType,
        'is_super_admin': employee.isSuperAdmin,
        'access_permissions': employee.accessPermissions,
        'platform': platform,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> removeFcmToken({required String token}) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return;

    try {
      final docId = _tokenDocId(cleanToken);
      await _fcmTokensRef.doc(docId).delete();
    } catch (_) {}
  }
}

