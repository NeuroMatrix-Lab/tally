import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Function(DateTime) onDateSelected;

  const CustomDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  });

  @override
  State<CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  late DateTime _currentDate;
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate;
    _selectedYear = _currentDate.year;
    _selectedMonth = _currentDate.month;
    _selectedDay = _currentDate.day;
  }

  List<int> _getDaysInMonth(int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return List.generate(daysInMonth, (index) => index + 1);
  }

  List<int> _getYears() {
    final years = <int>[];
    for (int year = widget.firstDate.year; year <= widget.lastDate.year; year++) {
      years.add(year);
    }
    return years;
  }

  List<int> _getMonths() {
    final months = <int>[];
    for (int month = 1; month <= 12; month++) {
      months.add(month);
    }
    return months;
  }

  void _onConfirm() {
    final selectedDate = DateTime(_selectedYear, _selectedMonth, _selectedDay);
    if (selectedDate.isBefore(widget.firstDate)) {
      widget.onDateSelected(widget.firstDate);
    } else if (selectedDate.isAfter(widget.lastDate)) {
      widget.onDateSelected(widget.lastDate);
    } else {
      widget.onDateSelected(selectedDate);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final years = _getYears();
    final months = _getMonths();
    final days = _getDaysInMonth(_selectedYear, _selectedMonth);

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '选择日期',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildYearPicker(years),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMonthPicker(months),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDayPicker(days),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _onConfirm,
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearPicker(List<int> years) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: const Border(
                bottom: BorderSide(color: Colors.grey),
              ),
            ),
            child: const Text(
              '年',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            height: 150,
            child: ListWheelScrollView.useDelegate(
              itemExtent: 40,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedYear = years[index];
                });
              },
              controller: FixedExtentScrollController(
                initialItem: years.indexOf(_selectedYear),
              ),
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  return Center(
                    child: Text(
                      '${years[index]}年',
                      style: TextStyle(
                        fontSize: 16,
                        color: years[index] == _selectedYear
                            ? Colors.blue
                            : Colors.black,
                        fontWeight: years[index] == _selectedYear
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
                childCount: years.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker(List<int> months) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: const Border(
                bottom: BorderSide(color: Colors.grey),
              ),
            ),
            child: const Text(
              '月',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            height: 150,
            child: ListWheelScrollView.useDelegate(
              itemExtent: 40,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedMonth = months[index];
                });
              },
              controller: FixedExtentScrollController(
                initialItem: _selectedMonth - 1,
              ),
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  return Center(
                    child: Text(
                      '${months[index]}月',
                      style: TextStyle(
                        fontSize: 16,
                        color: months[index] == _selectedMonth
                            ? Colors.blue
                            : Colors.black,
                        fontWeight: months[index] == _selectedMonth
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
                childCount: months.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayPicker(List<int> days) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: const Border(
                bottom: BorderSide(color: Colors.grey),
              ),
            ),
            child: const Text(
              '日',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            height: 150,
            child: ListWheelScrollView.useDelegate(
              itemExtent: 40,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedDay = days[index];
                });
              },
              controller: FixedExtentScrollController(
                initialItem: _selectedDay - 1,
              ),
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  return Center(
                    child: Text(
                      '${days[index]}日',
                      style: TextStyle(
                        fontSize: 16,
                        color: days[index] == _selectedDay
                            ? Colors.blue
                            : Colors.black,
                        fontWeight: days[index] == _selectedDay
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
                childCount: days.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> showCustomDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  DateTime? selectedDate;
  
  await showDialog(
    context: context,
    builder: (context) => CustomDatePicker(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      onDateSelected: (date) {
        selectedDate = date;
      },
    ),
  );
  
  return selectedDate;
}
