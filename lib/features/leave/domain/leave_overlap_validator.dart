import 'leave_request.dart';

class LeaveOverlapResult {
  final bool hasOverlap;
  final String? message;
  final Map<String, String> dateStatusMap;
  final List<LeaveRequest> conflictingRequests;

  const LeaveOverlapResult({
    required this.hasOverlap,
    this.message,
    this.dateStatusMap = const {},
    this.conflictingRequests = const [],
  });
}

class LeaveOverlapValidator {
  static DateTime? parseDate(String? str) {
    if (str == null) return null;
    final s = str.trim();
    if (s.isEmpty) return null;

    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    final parts = s.split('-');
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      } else {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) return DateTime(y, m, d);
      }
    }

    final slashParts = s.split('/');
    if (slashParts.length == 3) {
      final d = int.tryParse(slashParts[0]);
      final m = int.tryParse(slashParts[1]);
      final y = int.tryParse(slashParts[2]);
      if (d != null && m != null && y != null) return DateTime(y, m, d);
    }

    return null;
  }

  static String normalizePeriod(String? period) {
    if (period == null) return 'first_half';
    final p = period.toLowerCase().trim();
    if (p.contains('second') || p.contains('afternoon') || p.contains('2nd')) {
      return 'second_half';
    }
    return 'first_half';
  }

  static String formatDisplayDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  static bool isStatusActive(String status) {
    final s = status.trim().toLowerCase();
    return s == 'pending' || s == 'approved';
  }

  static LeaveOverlapResult checkOverlap({
    required String newFromDate,
    required String newToDate,
    required bool isHalfDay,
    String? halfDayPeriod,
    required List<LeaveRequest> existingRequests,
    int? excludeRequestId,
    int? employeeId,
  }) {
    final start = parseDate(newFromDate);
    final end = parseDate(newToDate);

    if (start == null || end == null) {
      return const LeaveOverlapResult(hasOverlap: false);
    }

    final newPeriod = isHalfDay ? normalizePeriod(halfDayPeriod) : 'full_day';

    // Generate date range for new request
    final List<DateTime> newDates = [];
    var curr = start;
    final last = end.isBefore(start) ? start : end;
    while (!curr.isAfter(last)) {
      newDates.add(DateTime(curr.year, curr.month, curr.day));
      curr = curr.add(const Duration(days: 1));
    }

    // Filter existing active requests
    final activeRequests = existingRequests.where((req) {
      if (excludeRequestId != null && req.id != 0 && req.id == excludeRequestId) {
        return false;
      }
      if (employeeId != null && req.employeeId != 0 && req.employeeId != employeeId) {
        return false;
      }
      return isStatusActive(req.status);
    }).toList();

    final Map<String, String> dateStatusMap = {};
    final List<LeaveRequest> conflictingRequests = [];
    final Set<int> addedConflictIds = {};

    for (final dt in newDates) {
      final dtStr = formatDisplayDate(dt);

      bool firstHalfOccupied = false;
      bool secondHalfOccupied = false;

      LeaveRequest? occupantRequest;
      String occupantDetail = '';

      for (final req in activeRequests) {
        final reqStart = parseDate(req.fromDate);
        final reqEnd = parseDate(req.toDate);
        if (reqStart == null || reqEnd == null) continue;

        final reqLast = reqEnd.isBefore(reqStart) ? reqStart : reqEnd;

        // Check if req covers dt
        if ((dt.isAfter(reqStart) || dt.isAtSameMomentAs(reqStart)) &&
            (dt.isBefore(reqLast) || dt.isAtSameMomentAs(reqLast))) {
          final reqIsHalf = req.isHalfDay || req.numDays < 1.0;
          final reqPeriod = reqIsHalf ? normalizePeriod(req.halfDayPeriod) : 'full_day';

          if (!reqIsHalf || reqPeriod == 'full_day') {
            firstHalfOccupied = true;
            secondHalfOccupied = true;
            occupantRequest = req;
            occupantDetail = '${req.leaveType} — ${req.status} (Full Day)';
          } else if (reqPeriod == 'first_half') {
            firstHalfOccupied = true;
            occupantRequest = req;
            occupantDetail = '${req.leaveType} — ${req.status} (First Half)';
          } else if (reqPeriod == 'second_half') {
            secondHalfOccupied = true;
            occupantRequest = req;
            occupantDetail = '${req.leaveType} — ${req.status} (Second Half)';
          }

          if (occupantRequest != null && !addedConflictIds.contains(occupantRequest.id)) {
            conflictingRequests.add(occupantRequest);
            if (occupantRequest.id != 0) {
              addedConflictIds.add(occupantRequest.id);
            }
          }
        }
      }

      // Check if new request has conflict on dt
      bool dateHasConflict = false;
      if (!isHalfDay) {
        // Full day requires both halves free
        if (firstHalfOccupied || secondHalfOccupied) {
          dateHasConflict = true;
        }
      } else {
        // Half day requires its specific period free
        if (newPeriod == 'first_half' && firstHalfOccupied) {
          dateHasConflict = true;
        } else if (newPeriod == 'second_half' && secondHalfOccupied) {
          dateHasConflict = true;
        }
      }

      if (dateHasConflict) {
        dateStatusMap[dtStr] = occupantDetail.isNotEmpty ? occupantDetail : 'Leave already requested';
      } else {
        dateStatusMap[dtStr] = 'Available';
      }
    }

    final hasOverlap = dateStatusMap.values.any((val) => val != 'Available');

    if (!hasOverlap) {
      return LeaveOverlapResult(
        hasOverlap: false,
        dateStatusMap: dateStatusMap,
      );
    }

    // Build user-friendly message
    String message;
    if (newDates.length == 1) {
      final singleDateStr = formatDisplayDate(newDates.first);
      final detail = dateStatusMap[singleDateStr] ?? 'Leave already requested';
      message = 'Leave already requested for $singleDateStr ($detail). You cannot submit another leave request for the same date/period.';
    } else {
      final buf = StringBuffer('Date conflict:\n');
      dateStatusMap.forEach((d, status) {
        buf.writeln('$d: $status');
      });
      buf.write('Please change the leave dates.');
      message = buf.toString();
    }

    return LeaveOverlapResult(
      hasOverlap: true,
      message: message,
      dateStatusMap: dateStatusMap,
      conflictingRequests: conflictingRequests,
    );
  }
}
