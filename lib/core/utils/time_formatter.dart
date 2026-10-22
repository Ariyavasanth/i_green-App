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

  /// Formats any time string (12-hour AM/PM, ISO, or 24-hour) into 24-hour "HH:mm:ss" format.
  /// Examples:
  /// "12:44 AM" -> "00:44:00"
  /// "12:58 PM" -> "12:58:00"
  /// "01:15 PM" -> "13:15:00"
  /// "14:20" -> "14:20:00"
  /// "00:14:00" -> "00:14:00"
  static String formatTo24HourTime(String timeStr) {
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
          final local = dt.toLocal();
          return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
        }
      }

      final upper = trimmed.toUpperCase();
      final isPm = upper.contains('PM');
      final isAm = upper.contains('AM');

      if (isPm || isAm) {
        final clean = upper.replaceAll(RegExp(r'[A-Z]'), '').trim();
        final parts = clean.split(':');
        if (parts.length >= 2) {
          int hour = int.tryParse(parts[0].trim()) ?? 0;
          final minute = int.tryParse(parts[1].trim()) ?? 0;
          final second = parts.length >= 3 ? (int.tryParse(parts[2].trim()) ?? 0) : 0;
          if (isPm && hour < 12) hour += 12;
          if (isAm && hour == 12) hour = 0;
          return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
        }
      }

      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0].trim());
        final minute = int.tryParse(parts[1].trim());
        final second = parts.length >= 3 ? (int.tryParse(parts[2].trim()) ?? 0) : 0;
        if (hour != null && minute != null && hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
          return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
        }
      }
    } catch (_) {}

    return trimmed;
  }

  /// Parses any time string (12-hour AM/PM, ISO, or 24-hour) into seconds from midnight.
  static int? parseTimeToSeconds(String? timeStr) {
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
          final local = dt.toLocal();
          return local.hour * 3600 + local.minute * 60 + local.second;
        }
      }

      final upper = trimmed.toUpperCase();
      final isPm = upper.contains('PM');
      final isAm = upper.contains('AM');

      if (isPm || isAm) {
        final clean = upper.replaceAll(RegExp(r'[A-Z]'), '').trim();
        final parts = clean.split(':');
        if (parts.length >= 2) {
          int hour = int.tryParse(parts[0].trim()) ?? 0;
          final minute = int.tryParse(parts[1].trim()) ?? 0;
          final second = parts.length >= 3 ? (int.tryParse(parts[2].trim()) ?? 0) : 0;
          if (isPm && hour < 12) hour += 12;
          if (isAm && hour == 12) hour = 0;
          return hour * 3600 + minute * 60 + second;
        }
      }

      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0].trim());
        final minute = int.tryParse(parts[1].trim());
        final second = parts.length >= 3 ? (int.tryParse(parts[2].trim()) ?? 0) : 0;
        if (hour != null && minute != null && hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
          return hour * 3600 + minute * 60 + second;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Calculates elapsed duration between two time strings in seconds.
  /// Handles 24-hour wrap-around if endTime is earlier than startTime.
  static int? calculateElapsedSeconds(String startTime, String endTime) {
    final startSec = parseTimeToSeconds(startTime);
    final endSec = parseTimeToSeconds(endTime);
    if (startSec == null || endSec == null) return null;
    int diff = endSec - startSec;
    if (diff < 0) diff += 86400; // wrap around 24 hours
    return diff;
  }

  /// Formats total elapsed seconds into "HH:mm:ss" format.
  /// Example: 840 seconds -> "00:14:00"
  static String formatSecondsToHHmmss(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formats total elapsed minutes into "HH:mm:ss" format.
  /// Example: 14 minutes -> "00:14:00"
  static String formatMinutesToHHmmss(int totalMinutes) {
    return formatSecondsToHHmmss(totalMinutes * 60);
  }

  /// Formats a [Duration] into "HH:mm:ss" format.
  static String formatDuration(Duration duration) {
    var d = duration;
    if (d.isNegative) d = Duration.zero;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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

String formatTo24HourTime(String timeStr) {
  return TimeFormatter.formatTo24HourTime(timeStr);
}

String formatSecondsToHHmmss(int totalSeconds) {
  return TimeFormatter.formatSecondsToHHmmss(totalSeconds);
}

String formatMinutesToHHmmss(int totalMinutes) {
  return TimeFormatter.formatMinutesToHHmmss(totalMinutes);
}
