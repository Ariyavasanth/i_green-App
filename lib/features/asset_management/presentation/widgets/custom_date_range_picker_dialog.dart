import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

class CustomDateRangePickerDialog extends StatefulWidget {
  final DateTimeRange? initialDateRange;

  const CustomDateRangePickerDialog({
    super.key,
    this.initialDateRange,
  });

  @override
  State<CustomDateRangePickerDialog> createState() => _CustomDateRangePickerDialogState();
}

class _CustomDateRangePickerDialogState extends State<CustomDateRangePickerDialog> {
  late DateTime _currentMonthPage;
  DateTime? _startRange;
  DateTime? _endRange;
  String? _selectedPreset;

  final List<String> _presets = [
    'Today',
    'Yesterday',
    'This week',
    'Last week',
    'This month',
    'Last month',
    'This year',
    'Last year',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDateRange != null) {
      _startRange = DateTime(
        widget.initialDateRange!.start.year,
        widget.initialDateRange!.start.month,
        widget.initialDateRange!.start.day,
      );
      _endRange = DateTime(
        widget.initialDateRange!.end.year,
        widget.initialDateRange!.end.month,
        widget.initialDateRange!.end.day,
      );
      _currentMonthPage = DateTime(_startRange!.year, _startRange!.month, 1);
    } else {
      final now = DateTime.now();
      _currentMonthPage = DateTime(now.year, now.month, 1);
    }
  }

  DateTimeRange? _getPresetRange(String preset) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (preset) {
      case 'Today':
        return DateTimeRange(start: todayStart, end: todayStart);
      case 'Yesterday':
        final y = todayStart.subtract(const Duration(days: 1));
        return DateTimeRange(start: y, end: y);
      case 'This week':
        final weekday = now.weekday; // 1 = Mon, 7 = Sun
        final start = todayStart.subtract(Duration(days: weekday - 1));
        final end = todayStart.add(Duration(days: 7 - weekday));
        return DateTimeRange(start: start, end: end);
      case 'Last week':
        final weekday = now.weekday;
        final end = todayStart.subtract(Duration(days: weekday));
        final start = end.subtract(const Duration(days: 6));
        return DateTimeRange(start: start, end: end);
      case 'This month':
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(start: start, end: end);
      case 'Last month':
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0);
        return DateTimeRange(start: start, end: end);
      case 'This year':
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        return DateTimeRange(start: start, end: end);
      case 'Last year':
        final start = DateTime(now.year - 1, 1, 1);
        final end = DateTime(now.year - 1, 12, 31);
        return DateTimeRange(start: start, end: end);
      default:
        return null;
    }
  }

  void _applyPreset(String preset) {
    final range = _getPresetRange(preset);
    if (range != null) {
      setState(() {
        _selectedPreset = preset;
        _startRange = range.start;
        _endRange = range.end;
        _currentMonthPage = DateTime(range.start.year, range.start.month, 1);
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onDaySelected(DateTime date) {
    final cellDay = DateTime(date.year, date.month, date.day);
    setState(() {
      _selectedPreset = null;
      if (_startRange == null || (_startRange != null && _endRange != null)) {
        _startRange = cellDay;
        _endRange = null;
      } else if (_startRange != null && _endRange == null) {
        if (cellDay.isBefore(_startRange!)) {
          _startRange = cellDay;
          _endRange = null;
        } else {
          _endRange = cellDay;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    final firstOfMonth = DateTime(_currentMonthPage.year, _currentMonthPage.month, 1);
    final firstWeekday = firstOfMonth.weekday; // 1 Mon.. 7 Sun
    final gridStartDate = firstOfMonth.subtract(Duration(days: firstWeekday - 1));

    final fromStr = _startRange != null ? DateFormat('dd/MM/yyyy').format(_startRange!) : '';
    final toStr = _endRange != null ? DateFormat('dd/MM/yyyy').format(_endRange!) : '';
    final rangeDays = (_startRange != null && _endRange != null)
        ? _endRange!.difference(_startRange!).inDays + 1
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isCompact ? 360 : 640,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Preset Sidebar
                  Container(
                    width: isCompact ? 110 : 140,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AppColors.divider)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _presets.map((preset) {
                        final isSelected = _selectedPreset == preset;
                        return InkWell(
                          onTap: () => _applyPreset(preset),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            color: isSelected ? const Color(0xFFE3F2FD) : Colors.transparent,
                            child: Text(
                              preset,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? const Color(0xFF0288D1) : const Color(0xFF444444),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Center/Main Calendar Area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Month Header Navigation
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, color: Color(0xFF0288D1)),
                                onPressed: () {
                                  setState(() {
                                    _currentMonthPage = DateTime(
                                      _currentMonthPage.year,
                                      _currentMonthPage.month - 1,
                                      1,
                                    );
                                  });
                                },
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('MMMM yyyy').format(_currentMonthPage),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, color: Color(0xFF0288D1)),
                                onPressed: () {
                                  setState(() {
                                    _currentMonthPage = DateTime(
                                      _currentMonthPage.year,
                                      _currentMonthPage.month + 1,
                                      1,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Weekdays Header Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                                .map((d) => Expanded(
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF757575),
                                          ),
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 6),

                          // Calendar 42-day Grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 42,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1.1,
                            ),
                            itemBuilder: (context, index) {
                              final cellDate = DateTime(
                                gridStartDate.year,
                                gridStartDate.month,
                                gridStartDate.day + index,
                              );

                              final isCurrentMonth = cellDate.month == _currentMonthPage.month;
                              final isStart = _startRange != null && _isSameDay(cellDate, _startRange!);
                              final isEnd = _endRange != null && _isSameDay(cellDate, _endRange!);
                              final isInBetween = _startRange != null &&
                                  _endRange != null &&
                                  cellDate.isAfter(_startRange!) &&
                                  cellDate.isBefore(_endRange!);

                              final isBoundary = isStart || isEnd;

                              BoxDecoration? cellDeco;
                              Color textColor = isCurrentMonth ? const Color(0xFF333333) : Colors.grey.shade400;

                              if (isBoundary) {
                                cellDeco = BoxDecoration(
                                  color: const Color(0xFF0288D1),
                                  borderRadius: BorderRadius.circular(4),
                                );
                                textColor = Colors.white;
                              } else if (isInBetween) {
                                cellDeco = const BoxDecoration(
                                  color: Color(0xFFE1F5FE),
                                );
                                textColor = const Color(0xFF0288D1);
                              }

                              return InkWell(
                                onTap: () => _onDaySelected(cellDate),
                                child: Container(
                                  margin: const EdgeInsets.all(1),
                                  decoration: cellDeco,
                                  child: Center(
                                    child: Text(
                                      '${cellDate.day}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isBoundary ? FontWeight.bold : FontWeight.normal,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 1),

              // Bottom Inputs and Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // From Date box
                        Container(
                          width: 105,
                          height: 36,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fromStr.isNotEmpty ? fromStr : 'DD/MM/YYYY',
                            style: TextStyle(
                              fontSize: 12,
                              color: fromStr.isNotEmpty ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('-', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        // To Date box
                        Container(
                          width: 105,
                          height: 36,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            toStr.isNotEmpty ? toStr : 'DD/MM/YYYY',
                            style: TextStyle(
                              fontSize: 12,
                              color: toStr.isNotEmpty ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                        if (rangeDays != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            'Range : $rangeDays days',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0288D1),
                            ),
                          ),
                        ],
                      ],
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => Navigator.pop(context, null),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0288D1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: (_startRange != null && _endRange != null)
                              ? () {
                                  Navigator.pop(
                                    context,
                                    DateTimeRange(
                                      start: _startRange!,
                                      end: _endRange!,
                                    ),
                                  );
                                }
                              : null,
                          child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
