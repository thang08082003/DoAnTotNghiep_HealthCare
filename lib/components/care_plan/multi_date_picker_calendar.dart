import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

/// Component cho phép chọn nhiều ngày trên lịch
class MultiDatePickerCalendar extends StatefulWidget {
  final List<DateTime> initialSelectedDates;
  final DateTime? minDate;
  final DateTime? maxDate;
  final Function(List<DateTime> selectedDates) onDatesSelected;

  const MultiDatePickerCalendar({
    super.key,
    this.initialSelectedDates = const [],
    this.minDate,
    this.maxDate,
    required this.onDatesSelected,
  });

  @override
  State<MultiDatePickerCalendar> createState() =>
      _MultiDatePickerCalendarState();
}

class _MultiDatePickerCalendarState extends State<MultiDatePickerCalendar> {
  late Set<DateTime> _selectedDates;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    // Normalize dates to remove time component
    _selectedDates = widget.initialSelectedDates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
    _focusedDay = DateTime.now();
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      final normalizedDate = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
      );

      if (_selectedDates.any((date) => _isSameDay(date, normalizedDate))) {
        _selectedDates.removeWhere((date) => _isSameDay(date, normalizedDate));
      } else {
        _selectedDates.add(normalizedDate);
      }

      widget.onDatesSelected(_selectedDates.toList()..sort());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selected dates summary
        if (_selectedDates.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã chọn ${_selectedDates.length} ngày:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedDates.map((date) {
                    return Chip(
                      label: Text(
                        DateFormat('dd/MM/yyyy').format(date),
                        style: const TextStyle(fontSize: 12),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _selectedDates.remove(date);
                          widget.onDatesSelected(
                            _selectedDates.toList()..sort(),
                          );
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

        // Calendar
        TableCalendar(
          firstDay: widget.minDate ?? DateTime(2020),
          lastDay: widget.maxDate ?? DateTime(2030),
          focusedDay: _focusedDay,
          locale: 'vi_VN',
          selectedDayPredicate: (day) {
            return _selectedDates.any((date) => _isSameDay(date, day));
          },
          onDaySelected: _onDaySelected,
          calendarStyle: CalendarStyle(
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextFormatter: (date, locale) {
              return DateFormat.yMMMM('vi_VN').format(date);
            },
          ),
          calendarBuilders: CalendarBuilders(
            // Custom marker for selected dates
            markerBuilder: (context, date, events) {
              if (_selectedDates.any((d) => _isSameDay(d, date))) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    date.day.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}
