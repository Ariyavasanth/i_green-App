import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../employee/providers/employee_providers.dart';
import '../../tenders/providers/company_document_providers.dart';
import '../../tenders/providers/tender_providers.dart';
import '../data/firebase_notification_repository.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';
import '../services/fcm_push_service.dart';

const String kVaultAlertPrefix = 'vault_alert_';
const String kTenderClosingAlertPrefix = 'tender_closing_live_';

/// Tracks live alert IDs (Vault expiry / Tender closing) dismissed by the user for today.
class DismissedLiveAlertsNotifier extends StateNotifier<Set<String>> {
  DismissedLiveAlertsNotifier(this._employeeKey) : super(const {}) {
    _load();
  }

  final String _employeeKey;

  String get _prefsKey {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return 'dismissed_live_alerts_${_employeeKey}_$today';
  }

  Future<void> _load() async {
    if (_employeeKey.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey) ?? const [];
      if (mounted) {
        state = saved.toSet();
      }
    } catch (_) {}
  }

  Future<void> dismissForToday(String alertId) async {
    if (alertId.isEmpty) return;
    final next = {...state, alertId};
    state = next;
    if (_employeeKey.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, next.toList());
    } catch (_) {}
  }

  Future<void> dismissAllForToday(Iterable<String> alertIds) async {
    final ids = alertIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    final next = {...state, ...ids};
    state = next;
    if (_employeeKey.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, next.toList());
    } catch (_) {}
  }
}

final dismissedLiveAlertIdsProvider =
    StateNotifierProvider<DismissedLiveAlertsNotifier, Set<String>>((ref) {
  final currentEmp = ref.watch(currentEmployeeProvider);
  final key = currentEmp != null ? currentEmp.id.toString() : '';
  return DismissedLiveAlertsNotifier(key);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return FirebaseNotificationRepository();
});

final fcmPushServiceProvider = Provider<FcmPushService>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final service = FcmPushService(notificationRepository: repo);
  ref.onDispose(service.dispose);
  return service;
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
  final dismissedIds = ref.watch(dismissedLiveAlertIdsProvider);
  final df = DateFormat('dd-MM-yyyy');

  return docsAsync.maybeWhen(
    data: (docs) {
      final alerts = <AppNotification>[];
      for (final doc in docs) {
        if (!doc.isExpired && !doc.isExpiringSoon) continue;
        final alertId = '$kVaultAlertPrefix${doc.id}';
        if (dismissedIds.contains(alertId)) continue;
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
            id: alertId,
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

/// Live tender closing date reminders (0–5 days before submission) with pending document count.
final tenderClosingNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final currentEmp = ref.watch(currentEmployeeProvider);
  if (currentEmp == null) return const [];
  if (!currentEmp.isSuperAdmin && !currentEmp.hasPermission('Projects')) {
    return const [];
  }

  final tendersAsync = ref.watch(tendersStreamProvider);
  final dismissedIds = ref.watch(dismissedLiveAlertIdsProvider);
  final df = DateFormat('dd MMM yyyy');

  return tendersAsync.maybeWhen(
    data: (tenders) {
      final alerts = <AppNotification>[];
      for (final tender in tenders) {
        if (!tender.isClosingSoon) continue;
        final alertId = '$kTenderClosingAlertPrefix${tender.id}';
        if (dismissedIds.contains(alertId)) continue;
        final days = tender.daysUntilClosing ?? 0;
        final closeDateStr =
            tender.closingDate != null ? df.format(tender.closingDate!) : '';
        final pendingTotal = tender.pendingDocumentCount;
        final pendingBqr = tender.pendingBqrCount;
        final missingCore = tender.missingCoreDocumentLabels;

        final parts = <String>[];
        if (pendingBqr > 0) parts.add('$pendingBqr BQR');
        parts.addAll(missingCore);
        final breakdown = parts.isNotEmpty ? ' (${parts.join(', ')})' : '';

        final timingText = days == 0
            ? 'Closes TODAY ($closeDateStr)'
            : 'Closes in $days day(s) ($closeDateStr)';
        final pendingText = pendingTotal > 0
            ? '$pendingTotal pending document(s)$breakdown.'
            : '0 pending documents — ready for submission.';

        final displayName = tender.title.trim().isNotEmpty
            ? '${tender.tenderId} - ${tender.title.trim()}'
            : tender.tenderId;

        alerts.add(
          AppNotification(
            id: alertId,
            title: days == 0
                ? 'Tender Closing TODAY: $displayName'
                : 'Tender Closing Soon: $displayName',
            message: '$timingText • $pendingText',
            type: 'tender_closing_reminder',
            requiredPermission: 'Projects',
            route: '/projects/tenders',
            createdAt: DateTime.now(),
            metadata: {
              'tender_doc_id': tender.id,
              'tender_id': tender.tenderId,
              'closing_date': closeDateStr,
              'days_until_closing': days,
              'pending_bqr_count': pendingBqr,
              'missing_core_documents': missingCore,
              'pending_document_count': pendingTotal,
            },
          ),
        );
      }

      // Soonest-to-close first, then highest pending document count
      alerts.sort((a, b) {
        final da = (a.metadata['days_until_closing'] as int?) ?? 999;
        final db = (b.metadata['days_until_closing'] as int?) ?? 999;
        if (da != db) return da.compareTo(db);
        final pa = (a.metadata['pending_document_count'] as int?) ?? 0;
        final pb = (b.metadata['pending_document_count'] as int?) ?? 0;
        return pb.compareTo(pa);
      });
      return alerts;
    },
    orElse: () => const [],
  );
});

/// Combined notifications list (Tender closing + Vault expiry live alerts + user notifications).
final combinedNotificationsProvider =
    Provider<AsyncValue<List<AppNotification>>>((ref) {
  final userNotifsAsync = ref.watch(userNotificationsStreamProvider);
  final vaultAlerts = ref.watch(vaultExpiryNotificationsProvider);
  final tenderAlerts = ref.watch(tenderClosingNotificationsProvider);
  final liveAlerts = [...tenderAlerts, ...vaultAlerts];

  final liveTenderDocIds = tenderAlerts
      .map((a) => a.metadata['tender_doc_id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();

  return userNotifsAsync.when(
    data: (userNotifs) {
      // Avoid duplicate rows when a live closing alert is already showing for the same tender
      final filteredUserNotifs = userNotifs.where((n) {
        if (n.type != 'tender_closing_reminder') return true;
        final docId = n.metadata['tender_doc_id']?.toString() ?? '';
        return docId.isEmpty || !liveTenderDocIds.contains(docId);
      }).toList();
      return AsyncValue.data([...liveAlerts, ...filteredUserNotifs]);
    },
    loading: () => liveAlerts.isNotEmpty
        ? AsyncValue.data(liveAlerts)
        : const AsyncValue.loading(),
    error: (err, st) => liveAlerts.isNotEmpty
        ? AsyncValue.data(liveAlerts)
        : AsyncValue.error(err, st),
  );
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final currentEmp = ref.watch(currentEmployeeProvider);
  if (currentEmp == null) return 0;

  final vaultCount = ref.watch(vaultExpiryNotificationsProvider).length;
  final tenderAlerts = ref.watch(tenderClosingNotificationsProvider);
  final liveTenderDocIds = tenderAlerts
      .map((a) => a.metadata['tender_doc_id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();

  final notificationsAsync = ref.watch(userNotificationsStreamProvider);
  final userUnread = notificationsAsync.maybeWhen(
    data: (list) {
      final empIdStr = currentEmp.id.toString();
      return list.where((n) {
        if (n.type == 'tender_closing_reminder') {
          final docId = n.metadata['tender_doc_id']?.toString() ?? '';
          if (docId.isNotEmpty && liveTenderDocIds.contains(docId)) {
            return false;
          }
        }
        return !n.isReadBy(empIdStr);
      }).length;
    },
    orElse: () => 0,
  );
  return tenderAlerts.length + vaultCount + userUnread;
});
