import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../employee/providers/employee_providers.dart';
import '../domain/app_notification.dart';
import '../providers/notification_providers.dart';

class NotificationsPopover extends ConsumerStatefulWidget {
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

  static Future<void> showAsDesktopDialog(
    BuildContext context, {
    Offset? anchorPosition,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withValues(alpha: 0.14),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, secondaryAnimation) {
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
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
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
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<NotificationsPopover> createState() =>
      _NotificationsPopoverState();
}

class _NotificationsPopoverState extends ConsumerState<NotificationsPopover> {
  /// Optimistically hidden IDs so swiped/tapped notifications disappear immediately
  /// without waiting for Firestore roundtrip latency.
  final Set<String> _locallyDismissedIds = {};

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

  Color _getColorForType(
    String type, {
    Map<String, dynamic> metadata = const {},
  }) {
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

  String _sectionLabelFor(AppNotification item) {
    if (_isLiveAlert(item)) return 'ACTION REQUIRED';
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(
      item.createdAt.year,
      item.createdAt.month,
      item.createdAt.day,
    );
    final dayDiff = todayStart.difference(itemDay).inDays;
    if (dayDiff <= 0) return 'TODAY';
    if (dayDiff < 7) return 'THIS WEEK';
    return 'EARLIER';
  }

  List<_PopoverListEntry> _buildGroupedEntries(List<AppNotification> items) {
    final entries = <_PopoverListEntry>[];
    String? lastSection;
    for (final item in items) {
      final section = _sectionLabelFor(item);
      if (section != lastSection) {
        entries.add(_PopoverListEntry.header(section));
        lastSection = section;
      }
      entries.add(_PopoverListEntry.item(item));
    }
    return entries;
  }

  void _dismissItem(AppNotification item, String empIdStr) {
    setState(() {
      _locallyDismissedIds.add(item.id);
    });

    if (_isLiveAlert(item)) {
      ref.read(dismissedLiveAlertIdsProvider.notifier).dismissForToday(item.id);
    } else if (empIdStr.isNotEmpty) {
      ref.read(notificationRepositoryProvider).dismissNotification(
            notificationId: item.id,
            employeeId: empIdStr,
          );
    }
  }

  void _clearAll(List<AppNotification> visibleItems, String empIdStr) {
    if (visibleItems.isEmpty) return;

    setState(() {
      for (final item in visibleItems) {
        _locallyDismissedIds.add(item.id);
      }
    });

    final liveIds = visibleItems
        .where(_isLiveAlert)
        .map((n) => n.id)
        .toList();
    final persistedIds = visibleItems
        .where((n) => !_isLiveAlert(n))
        .map((n) => n.id)
        .toList();

    if (liveIds.isNotEmpty) {
      ref
          .read(dismissedLiveAlertIdsProvider.notifier)
          .dismissAllForToday(liveIds);
    }
    if (persistedIds.isNotEmpty && empIdStr.isNotEmpty) {
      ref.read(notificationRepositoryProvider).clearNotifications(
            employeeId: empIdStr,
            notificationIds: persistedIds,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    final empIdStr = currentEmp?.id.toString() ?? '';
    final notificationsAsync = ref.watch(combinedNotificationsProvider);

    return Container(
      height: widget.isMobile ? MediaQuery.of(context).size.height * 0.75 : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isMobile
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Drag handle for mobile
          if (widget.isMobile) ...[
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
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
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
                notificationsAsync.maybeWhen(
                  data: (notifications) {
                    final visibleCount = notifications
                        .where((n) => !_locallyDismissedIds.contains(n.id))
                        .length;
                    if (visibleCount == 0) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CC70A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        visibleCount > 99 ? '99+' : '$visibleCount',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                const Spacer(),
                notificationsAsync.maybeWhen(
                  data: (notifications) {
                    final visible = notifications
                        .where((n) => !_locallyDismissedIds.contains(n.id))
                        .toList();
                    if (visible.isEmpty) return const SizedBox.shrink();

                    return TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF9CC70A),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => _clearAll(visible, empIdStr),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                if (!widget.isMobile)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
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
                final visible = notifications
                    .where((n) => !_locallyDismissedIds.contains(n.id))
                    .toList();

                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                            "You're all caught up!",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'No new notifications right now.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final entries = _buildGroupedEntries(visible);

                return Column(
                  children: [
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: entries.length,
                          separatorBuilder: (context, index) {
                            if (entries[index].isHeader) {
                              return const SizedBox.shrink();
                            }
                            return const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFF1F5F9),
                            );
                          },
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            if (entry.isHeader) {
                              return Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 10, 16, 4),
                                child: Text(
                                  entry.headerTitle!,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              );
                            }

                            final item = entry.notification!;
                            final typeColor = _getColorForType(
                              item.type,
                              metadata: item.metadata,
                            );
                            final icon = _getIconForType(item.type);
                            final badgeLabel = _getModuleBadge(item.type);

                            return Dismissible(
                              key: ValueKey('notif_${item.id}'),
                              direction: DismissDirection.horizontal,
                              movementDuration:
                                  const Duration(milliseconds: 240),
                              resizeDuration:
                                  const Duration(milliseconds: 200),
                              dismissThresholds: const {
                                DismissDirection.startToEnd: 0.25,
                                DismissDirection.endToStart: 0.25,
                              },
                              background: _buildSlideDismissBackground(
                                alignment: Alignment.centerLeft,
                              ),
                              secondaryBackground:
                                  _buildSlideDismissBackground(
                                alignment: Alignment.centerRight,
                              ),
                              onDismissed: (_) => _dismissItem(item, empIdStr),
                              child: InkWell(
                                onTap: () {
                                  // Dismiss immediately on tap so once viewed, it's gone
                                  _dismissItem(item, empIdStr);

                                  // Close popover / bottomsheet
                                  Navigator.of(context).pop();

                                  // Navigate to target page
                                  if (item.route.isNotEmpty) {
                                    context.push(item.route);
                                  }
                                },
                                hoverColor: const Color(0xFFF8FAFC),
                                child: Container(
                                  color: item.type == 'vault_expired' ||
                                          (item.type ==
                                                  'tender_closing_reminder' &&
                                              ((item.metadata[
                                                          'days_until_closing']
                                                      as num?)
                                                  ?.toInt() ??
                                                  5) <=
                                                  1)
                                      ? const Color(0xFFFEF2F2)
                                      : item.type == 'vault_expiring' ||
                                              item.type ==
                                                  'tender_closing_reminder'
                                          ? const Color(0xFFFFFBEB)
                                          : const Color(0xFFF0FDF4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Icon Box
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: typeColor.withValues(
                                            alpha: 0.14,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: typeColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                // Module Badge
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: typeColor.withValues(
                                                      alpha: 0.12,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      4,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    badgeLabel,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: typeColor,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                // Time
                                                Text(
                                                  _formatTimeAgo(
                                                    item.createdAt,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(0xFF9CC70A),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
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
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Subtle gesture hint footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.swipe_rounded,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Click to view  •  Slide to dismiss',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideDismissBackground({required Alignment alignment}) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: const Color(0xFF414A51),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeft
            ? const [
                Icon(Icons.done_all_rounded, color: Color(0xFF9CC70A), size: 18),
                SizedBox(width: 6),
                Text(
                  'Dismiss',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            : const [
                Text(
                  'Dismiss',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.done_all_rounded, color: Color(0xFF9CC70A), size: 18),
              ],
      ),
    );
  }
}

class _PopoverListEntry {
  const _PopoverListEntry.header(this.headerTitle) : notification = null;
  const _PopoverListEntry.item(this.notification) : headerTitle = null;

  final String? headerTitle;
  final AppNotification? notification;

  bool get isHeader => headerTitle != null;
}
