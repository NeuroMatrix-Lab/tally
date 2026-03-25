import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/operation_log.dart';
import '../widgets/custom_date_picker.dart';
import 'settings_page.dart';

class OperationLogPage extends StatefulWidget {
  final List<OperationLog> operationLogs;

  const OperationLogPage({super.key, required this.operationLogs});

  @override
  State<OperationLogPage> createState() => _OperationLogPageState();
}

class _OperationLogPageState extends State<OperationLogPage> {
  String? _selectedType;
  String _searchKeyword = '';
  DateTime? _startDate;
  DateTime? _endDate;

  List<String> get _operationTypes {
    final types = widget.operationLogs.map((log) => log.type).toSet().toList();
    types.sort();
    return types;
  }

  List<OperationLog> get _filteredLogs {
    var filtered = widget.operationLogs;

    if (_selectedType != null) {
      filtered = filtered.where((log) => log.type == _selectedType).toList();
    }

    if (_searchKeyword.isNotEmpty) {
      filtered = filtered.where((log) {
        return log.description.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
            (log.details?.toLowerCase().contains(_searchKeyword.toLowerCase()) ?? false);
      }).toList();
    }

    if (_startDate != null) {
      filtered = filtered.where((log) => log.timestamp.isAfter(_startDate!)).toList();
    }

    if (_endDate != null) {
      filtered = filtered.where((log) => log.timestamp.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
    }

    return filtered..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showCustomDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showCustomDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '搜索关键词',
                          prefixIcon: Icon(Icons.search, color: theme.iconTheme.color),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchKeyword = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        );
                      },
                      tooltip: '设置',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectStartDate,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            border: Border.all(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _startDate == null
                                      ? '开始日期'
                                      : DateFormat('yyyy-MM-dd').format(_startDate!),
                                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                                ),
                              ),
                              if (_startDate != null)
                                IconButton(
                                  icon: Icon(Icons.clear, size: 20, color: colorScheme.onSurface),
                                  onPressed: () {
                                    setState(() {
                                      _startDate = null;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              Icon(Icons.calendar_today, size: 20, color: colorScheme.onSurface),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectEndDate,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            border: Border.all(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _endDate == null
                                      ? '结束日期'
                                      : DateFormat('yyyy-MM-dd').format(_endDate!),
                                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                                ),
                              ),
                              if (_endDate != null)
                                IconButton(
                                  icon: Icon(Icons.clear, size: 20, color: colorScheme.onSurface),
                                  onPressed: () {
                                    setState(() {
                                      _endDate = null;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              Icon(Icons.calendar_today, size: 20, color: colorScheme.onSurface),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('全部'),
                        selected: _selectedType == null,
                        showCheckmark: false,
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._operationTypes.map((type) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(type),
                          selected: _selectedType == type,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setState(() {
                              _selectedType = selected ? type : null;
                            });
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredLogs.isEmpty
                ? const Center(child: Text('暂无操作记录'))
                : ListView.builder(
                    itemCount: _filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = _filteredLogs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Icon(_getTypeIcon(log.type)),
                          title: Text(log.description),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp)),
                              if (log.details != null)
                                Text(
                                  log.details!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Chip(
                            label: Text(log.type),
                            backgroundColor: _getTypeColor(log.type),
                            labelStyle: TextStyle(color: _getTypeLabelColor(log.type), fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case '添加':
        return Icons.add_circle;
      case '删除':
        return Icons.delete;
      case '编辑':
        return Icons.edit;
      case '恢复':
        return Icons.restore;
      case '导出':
        return Icons.file_download;
      default:
        return Icons.history;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case '添加':
        return Colors.green;
      case '删除':
        return Colors.red;
      case '编辑':
        return Colors.blue;
      case '恢复':
        return Colors.orange;
      case '导出':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeLabelColor(String type) {
    final background = _getTypeColor(type);
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }
}
