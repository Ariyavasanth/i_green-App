import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../employee/providers/employee_providers.dart';
import '../data/firebase_notification_repository.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return FirebaseNotificationRepository();
});

final userNotificationsStreamProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final currentEmp = ref.watch(currentEmployeeProvider);
  if (currentEmp == null) {
    return Stream.value(const []);
  }

  final repo = ref.watch(notificationRepositoryProvider);
  return repo.watchNotificationsForUser(currentEmployee: currentEmp);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final currentEmp = ref.watch(currentEmployeeProvider);
  if (currentEmp == null) return 0;

  final notificationsAsync = ref.watch(userNotificationsStreamProvider);
  return notificationsAsync.maybeWhen(
    data: (list) {
      final empIdStr = currentEmp.id.toString();
      return list.where((n) => !n.isReadBy(empIdStr)).length;
    },
    orElse: () => 0,
  );
});

