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
        'HH:mm:ss',
        'HH:mm',
        'hh:mm:ss a',
        'hh:mm a',
        'h:mm:ss a',
        'h:mm a',
        'H:m:s',
        'H:m',
      ];

      for (final fmt in formats) {
        try {
          final parsed = DateFormat(fmt).parse(trimmed);
          final hasSecondsInInput = trimmed.split(':').length >= 3 && !trimmed.contains(' ');
          final useSeconds = forceSeconds || hasSecondsInInput;
          final outFmt = useSeconds ? 'hh:mm:ss a' : 'hh:mm a';
          return DateFormat(outFmt).format(parsed);
        } catch (_) {}
      }
    } catch (_) {}

    return trimmed;
  }
}

String formatToLocal12HourTime(String timeStr, {bool forceSeconds = false}) {
  return TimeFormatter.formatToLocal12HourTime(timeStr, forceSeconds: forceSeconds);
}
