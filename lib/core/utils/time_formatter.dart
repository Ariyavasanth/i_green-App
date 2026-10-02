import 'package:intl/intl.dart';

/// Formats any time string (24-hour, ISO, or 12-hour) into local 12-hour AM/PM format.
/// Examples:
/// "22:45:23" -> "10:45:23 PM"
/// "22:45" -> "10:45 PM"
/// "10:45 PM" -> "10:45 PM"
class TimeFormatter {
  static String formatToLocal12HourTime(String timeStr, {bool forceSeconds = false}) {
    final trimmed = timeStr.trim();
    if (trimmed.isEmpty ||
        trimmed == '--:--' ||
        trimmed == '--:--:--' ||
        trimmed == '--' ||
        trimmed.toLowerCase() == 'active' ||
        trimmed.toLowerCase() == 'running') {
      return trimmed;
    }

    try {
      if (trimmed.contains('T')) {
        final dt = DateTime.tryParse(trimmed);
        if (dt != null) {
          return DateFormat(forceSeconds ? 'hh:mm:ss a' : 'hh:mm a').format(dt.toLocal());
        }
      }

      final formats = [
        'hh:mm:ss a',
        'hh:mm a',
        'h:mm:ss a',
        'h:mm a',
        'HH:mm:ss',
        'HH:mm',
        'H:m:s',
        'H:m',
      ];

      for (final fmt in formats) {
        try {
          final parsed = DateFormat(fmt).parseStrict(trimmed);
          final outFmt = forceSeconds ? 'hh:mm:ss a' : 'hh:mm a';
          return DateFormat(outFmt).format(parsed);
        } catch (_) {}
      }

      for (final fmt in formats) {
        try {
          final parsed = DateFormat(fmt).parse(trimmed);
          final outFmt = forceSeconds ? 'hh:mm:ss a' : 'hh:mm a';
          return DateFormat(outFmt).format(parsed);
        } catch (_) {}
      }
    } catch (_) {}

    return trimmed;
  }

  static int? parseTimeToMinutes(String? timeStr) {
    if (timeStr == null) return null;
    final trimmed = timeStr.trim();
    if (trimmed.isEmpty ||
        trimmed == '--:--' ||
        trimmed == '--:--:--' ||
        trimmed == '--' ||
        trimmed.toLowerCase() == 'active' ||
        trimmed.toLowerCase() == 'running') {
      return null;
    }

    try {
      if (trimmed.contains('T')) {
        final dt = DateTime.tryParse(trimmed);
        if (dt != null) {
          return dt.hour * 60 + dt.minute;
        }
      }

      final upper = trimmed.toUpperCase();
      final isPm = upper.contains('PM');
      final isAm = upper.contains('AM');

      if (isPm || isAm) {
        final clean = upper.replaceAll(RegExp(r'[A-Z]'), '').trim();
        final parts = clean.split(':');
        if (parts.length >= 2) {
          int hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          if (isPm && hour < 12) hour += 12;
          if (isAm && hour == 12) hour = 0;
          return hour * 60 + minute;
        }
      }

      // 24-hour format e.g. "20:10" or "08:10:00"
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null && hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
          return hour * 60 + minute;
        }
      }
    } catch (_) {}

    return null;
  }
}

String formatToLocal12HourTime(String timeStr, {bool forceSeconds = false}) {
  return TimeFormatter.formatToLocal12HourTime(timeStr, forceSeconds: forceSeconds);
}
