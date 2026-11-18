import '../../employee/domain/employee.dart';
import 'app_notification.dart';

abstract class NotificationRepository {
  Future<void> sendNotification(AppNotification notification);

  Stream<List<AppNotification>> watchNotificationsForUser({
    required Employee currentEmployee,
  });

  Future<void> markAsRead({
    required String notificationId,
    required String employeeId,
  });

  Future<void> markAllAsRead({
    required String employeeId,
    required List<String> notificationIds,
  });

  Future<void> dismissNotification({
    required String notificationId,
    required String employeeId,
  });

  Future<void> clearNotifications({
    required String employeeId,
    required List<String> notificationIds,
  });

  Future<void> deleteNotification(String notificationId);

  Future<void> saveFcmToken({
    required Employee employee,
    required String token,
    required String platform,
  });

  Future<void> removeFcmToken({required String token});
}

