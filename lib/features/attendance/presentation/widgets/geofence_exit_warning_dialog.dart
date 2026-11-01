import 'package:flutter/material.dart';
import '../../services/attendance_location_service.dart';

/// Modal popup displayed when an employee crosses the workplace boundary during an active session.
/// Shows a live 10-second countdown.
/// Auto-dismisses if the employee returns inside the workplace boundary before the timer expires.
class GeofenceExitWarningDialog extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback? onCheckOutNow;

  const GeofenceExitWarningDialog({
    super.key,
    this.initialSeconds = 10,
    this.onCheckOutNow,
  });

  /// Helper to show the dialog safely. Returns true if opened.
  static Future<void> show(BuildContext context, {VoidCallback? onCheckOutNow}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: GeofenceExitWarningDialog(
          onCheckOutNow: onCheckOutNow,
        ),
      ),
    );
  }

  @override
  State<GeofenceExitWarningDialog> createState() => _GeofenceExitWarningDialogState();
}

class _GeofenceExitWarningDialogState extends State<GeofenceExitWarningDialog> {
  @override
  void initState() {
    super.initState();
    AttendanceLocationService.instance.exitCountdownNotifier.addListener(_onCountdownChanged);
  }

  @override
  void dispose() {
    AttendanceLocationService.instance.exitCountdownNotifier.removeListener(_onCountdownChanged);
    super.dispose();
  }

  void _onCountdownChanged() {
    final remaining = AttendanceLocationService.instance.exitCountdownNotifier.value;
    // Auto-dismiss the popup immediately when employee walks back inside (countdown canceled to null) or completes
    if (remaining == null && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: AttendanceLocationService.instance.exitCountdownNotifier,
      builder: (context, secondsLeft, _) {
        final currentSeconds = secondsLeft ?? 0;
        final progress = (currentSeconds / 10.0).clamp(0.0, 1.0);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 12,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    color: Color(0xFFD97706),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Workplace Border Crossed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                const Text(
                  'You have stepped outside the office premises. Automatic check-out will complete in:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Circular Countdown Display
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            currentSeconds <= 3 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$currentSeconds',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: currentSeconds <= 3 ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                            ),
                          ),
                          const Text(
                            'sec',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Safe return instruction banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.directions_walk_rounded, color: Color(0xFF16A34A), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Step back inside the workplace boundary to automatically cancel checkout and resume shift.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
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
  }
}
