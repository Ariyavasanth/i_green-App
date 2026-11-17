import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../employee/providers/employee_providers.dart';
import '../../tenders/providers/company_document_providers.dart';
import '../data/firebase_notification_repository.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

const String kVaultAlertPrefix = 'vault_alert_';

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

/// Live expiry alerts derived from Company Vault documents.
final vaultExpiryNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final docsAsync = ref.watch(companyDocumentsStreamProvider);
  final df = DateFormat('dd-MM-yyyy');

  return docsAsync.maybeWhen(
    data: (docs) {
      final alerts = <AppNotification>[];
      for (final doc in docs) {
        if (!doc.isExpired && !doc.isExpiringSoon) continue;
        final expDateStr =
            doc.expiryDate != null ? df.format(doc.expiryDate!) : '';
        final days = doc.daysUntilExpiry ?? 0;

        final String title;
        final String message;
        final String type;

        if (doc.isExpired) {
          type = 'vault_expired';
          title = 'Document Expired: ${doc.title}';
          message =
              'Expired on $expDateStr (${days.abs()} day(s) ago). Tap to update in Company Vault.';
        } else {
          type = 'vault_expiring';
          title = 'Document Expiring Soon: ${doc.title}';
          message = days == 0
              ? 'Expires TODAY ($expDateStr). Tap to renew in Company Vault.'
              : 'Expires in $days day(s) on $expDateStr. Tap to renew in Company Vault.';
        }

        alerts.add(
          AppNotification(
            id: '$kVaultAlertPrefix${doc.id}',
            title: title,
            message: message,
            type: type,
            requiredPermission: '',
            route: '/projects/company-documents',
            createdAt: DateTime.now(),
            metadata: {
              'company_doc_id': doc.id,
              'expiry_date': expDateStr,
              'days_until_expiry': days,
            },
          ),
        );
      }

      // Expired documents first, then soonest-to-expire
      alerts.sort((a, b) {
        final da = (a.metadata['days_until_expiry'] as int?) ?? 999;
        final db = (b.metadata['days_until_expiry'] as int?) ?? 999;
        return da.compareTo(db);
      });
      return alerts;
    },
    orElse: () => const [],
  );
});

/// Combined notifications list (Vault expiry alerts on top + user notifications).
final combinedNotificationsProvider =
    Provider<AsyncValue<List<AppNotification>>>((ref) {
  final userNotifsAsync = ref.watch(userNotificationsStreamProvider);
  final vaultAlerts = ref.watch(vaultExpiryNotificationsProvider);

  return userNotifsAsync.when(
    data: (userNotifs) => AsyncValue.data([...vaultAlerts, ...userNotifs]),
    loading: () => vaultAlerts.isNotEmpty
        ? AsyncValue.data(vaultAlerts)
        : const AsyncValue.loading(),
    error: (err, st) => vaultAlerts.isNotEmpty
        ? AsyncValue.data(vaultAlerts)
        : AsyncValue.error(err, st),
  );
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final currentEmp = ref.watch(currentEmployeeProvider);
  if (currentEmp == null) return 0;

  final vaultCount = ref.watch(vaultExpiryNotificationsProvider).length;
  final notificationsAsync = ref.watch(userNotificationsStreamProvider);
  final userUnread = notificationsAsync.maybeWhen(
    data: (list) {
      final empIdStr = currentEmp.id.toString();
      return list.where((n) => !n.isReadBy(empIdStr)).length;
    },
    orElse: () => 0,
  );
  return vaultCount + userUnread;
});
