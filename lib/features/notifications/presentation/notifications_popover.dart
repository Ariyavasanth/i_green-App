import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../employee/providers/employee_providers.dart';
import '../domain/app_notification.dart';
import '../providers/notification_providers.dart';

class NotificationsPopover extends ConsumerWidget {
  const NotificationsPopover({super.key, this.isMobile = false});

  final bool isMobile;

  static Future<void> showAsBottomSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationsPopover(isMobile: true),
    );
  }

  static Future<void> showAsDesktopDialog(BuildContext context, {Offset? anchorPosition}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.12),
      builder: (ctx) {
        return Stack(
          children: [
            Positioned(
              top: (anchorPosition?.dy ?? 60) + 10,
              right: 24,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 400,
                  height: 520,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const NotificationsPopover(isMobile: false),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'tender_closing_reminder':
        return Icons.event_available_rounded;
      case 'vault_expired':
        return Icons.error_outline_rounded;
      case 'vault_expiring':
        return Icons.warning_amber_rounded;
      case 'od_request':
        return Icons.commute_rounded;
      case 'leave_request':
        return Icons.event_busy_rounded;
      case 'incentive_request':
        return Icons.monetization_on_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getColorForType(String type, {Map<String, dynamic> metadata = const {}}) {
    switch (type) {
      case 'tender_closing_reminder':
        final days = (metadata['days_until_closing'] as num?)?.toInt() ?? 5;
        return days <= 1 ? const Color(0xFFDC2626) : const Color(0xFFD97706);
      case 'vault_expired':
        return const Color(0xFFDC2626);
      case 'vault_expiring':
        return const Color(0xFFD97706);
      case 'od_request':
        return const Color(0xFF9CC70A);
      case 'leave_request':
        return const Color(0xFF414A51);
      case 'incentive_request':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF414A51);
    }
  }

  String _getModuleBadge(String type) {
    switch (type) {
      case 'tender_closing_reminder':
        return 'Tender Closing';
      case 'vault_expired':
        return 'Vault Expired';
      case 'vault_expiring':
        return 'Vault Alert';
      case 'od_request':
        return 'On-Duty';
      case 'leave_request':
        return 'Leave';
      case 'incentive_request':
        return 'Incentive';
      default:
        return 'Request';
    }
  }

  bool _isLiveAlert(AppNotification item) =>
      item.id.startsWith(kVaultAlertPrefix) ||
      item.id.startsWith(kTenderClosingAlertPrefix);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    final empIdStr = currentEmp?.id.toString() ?? '';
    final notificationsAsync = ref.watch(combinedNotificationsProvider);

    return Container(
      height: isMobile ? MediaQuery.of(context).size.height * 0.75 : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Drag handle for mobile
          if (isMobile) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFF414A51),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                notificationsAsync.maybeWhen(
                  data: (notifications) {
                    final unread = notifications
                        .where((n) => !_isLiveAlert(n) && !n.isReadBy(empIdStr))
                        .toList();
                    if (unread.isEmpty) return const SizedBox.shrink();

                    return TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF9CC70A),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text(
                        'Mark all as read',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        final unreadIds = unread.map((n) => n.id).toList();
                        ref
                            .read(notificationRepositoryProvider)
                            .markAllAsRead(
                              employeeId: empIdStr,
                              notificationIds: unreadIds,
                            );
                      },
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                if (!isMobile)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Notification List
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF9CC70A)),
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Failed to load notifications: $err',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (notifications) {
                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 28,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No new notifications',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "You're all caught up!",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final isLiveAlert = _isLiveAlert(item);
                    final isRead = !isLiveAlert && item.isReadBy(empIdStr);
                    final typeColor =
                        _getColorForType(item.type, metadata: item.metadata);
                    final icon = _getIconForType(item.type);
                    final badgeLabel = _getModuleBadge(item.type);

                    return InkWell(
                      onTap: () {
                        // Mark as read (only for persisted Firestore notifications)
                        if (!isLiveAlert && !isRead && empIdStr.isNotEmpty) {
                          ref
                              .read(notificationRepositoryProvider)
                              .markAsRead(
                                notificationId: item.id,
                                employeeId: empIdStr,
                              );
                        }

                        // Close popover / bottomsheet
                        Navigator.of(context).pop();

                        // Route navigation
                        if (item.route.isNotEmpty) {
                          context.push(item.route);
                        }
                      },
                      hoverColor: const Color(0xFFF8FAFC),
                      child: Container(
                        color: item.type == 'vault_expired' ||
                                (item.type == 'tender_closing_reminder' &&
                                    ((item.metadata['days_until_closing']
                                                as num?)
                                            ?.toInt() ??
                                        5) <=
                                        1)
                            ? const Color(0xFFFEF2F2)
                            : item.type == 'vault_expiring' ||
                                    item.type == 'tender_closing_reminder'
                                ? const Color(0xFFFFFBEB)
                                : (isRead
                                    ? Colors.transparent
                                    : const Color(0xFFF0FDF4)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon Box
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: typeColor, size: 20),
                            ),
                            const SizedBox(width: 12),

                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Module Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: typeColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: typeColor,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Time
                                      Text(
                                        _formatTimeAgo(item.createdAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      if (!isRead) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF9CC70A),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isRead
                                          ? FontWeight.w600
                                          : FontWeight.bold,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.message,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

