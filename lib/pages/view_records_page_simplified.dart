import 'package:flutter/material.dart';
import '../models/record.dart';
import '../widgets/custom_date_picker.dart';
import './record_list_widget.dart';
import './record_filters_widget.dart';
import './record_actions_widget.dart';
import 'ledger_manage_page.dart';

class ViewRecordsPageSimplified extends StatefulWidget {
  final List<Record> records;
  final List<Record> deletedRecords;
  final Function(String id) onDelete;
  final Function(Record record) onUpdate;
  final Function(Record record) onRestore;
  final List<String> ledgers;
  final String defaultLedger;
  final Function(String) onLedgerChanged;
  final Function(String) onAddLedger;
  final Function(int) onExport;
  final Function(List<String>)? onLedgersUpdated;
  final Function()? onSync;

  const ViewRecordsPageSimplified({
    super.key, 
    required this.records, 
    required this.deletedRecords,
    required this.onDelete, 
    required this.onUpdate,
    required this.onRestore,
    required this.ledgers,
    required this.defaultLedger,
    required this.onLedgerChanged,
    required this.onAddLedger,
    required this.onExport,
    this.onLedgersUpdated,
    this.onSync,
  });

  @override
  State<ViewRecordsPageSimplified> createState() => _ViewRecordsPageSimplifiedState();
}

class _ViewRecordsPageSimplifiedState extends State<ViewRecordsPageSimplified> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedWorkContent;
  String? _selectedCategory;
  String? _selectedLedger;
  bool _isCalculateMode = false;
  final Set<String> _selectedRecordIds = {};
  String _searchKeyword = '';
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _selectedLedger = widget.defaultLedger;
  }

  List<Record> get _filteredRecords {
    var filtered = widget.records;

    if (_searchKeyword.isNotEmpty) {
      final keyword = _searchKeyword.toLowerCase();
      filtered = filtered.where((record) {
        return record.workContent.toLowerCase().contains(keyword) ||
            record.category.toLowerCase().contains(keyword) ||
            record.amount.toString().contains(keyword);
      }).toList();
    }

    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((record) {
        return record.date.isAtSameMomentAs(_startDate!) ||
            record.date.isAtSameMomentAs(_endDate!) ||
            (record.date.isAfter(_startDate!) && record.date.isBefore(_endDate!));
      }).toList();
    } else if (_startDate != null) {
      filtered = filtered.where((record) {
        return record.date.year == _startDate!.year &&
            record.date.month == _startDate!.month &&
            record.date.day == _startDate!.day;
      }).toList();
    } else if (_endDate != null) {
      filtered = filtered.where((record) {
        return record.date.year == _endDate!.year &&
            record.date.month == _endDate!.month &&
            record.date.day == _endDate!.day;
      }).toList();
    }

    if (_selectedWorkContent != null) {
      filtered = filtered
          .where((record) => record.workContent == _selectedWorkContent)
          .toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where((record) => record.category == _selectedCategory)
          .toList();
    }

    if (_selectedLedger != null) {
      filtered = filtered
          .where((record) => record.ledger == _selectedLedger)
          .toList();
    }

    return filtered..sort((a, b) => b.date.compareTo(a.date));
  }

  List<String> get _uniqueWorkContents {
    final contents = widget.records.map((r) => r.workContent).toSet().toList();
    contents.sort();
    return contents;
  }

  List<String> get _uniqueCategories {
    final categories = widget.records.map((r) => r.category).toSet().toList();
    categories.sort();
    return categories;
  }

  Widget _buildLedgerSelector() {
    final displayLedger = _selectedLedger ?? '全部账本';
    return GestureDetector(
      onTap: _showLedgerOverlay,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                displayLedger,
                style: TextStyle(
                  fontSize: 14,
                  color: displayLedger == '全部账本' ? Colors.grey : Colors.black,
                ),
              ),
            ),
            if (widget.ledgers.isNotEmpty)
              const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  void _showLedgerOverlay() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择账本'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.ledgers.isEmpty ? 2 : widget.ledgers.length + 2,
            itemBuilder: (context, index) {
              if (widget.ledgers.isEmpty) {
                if (index == 0) {
                  return ListTile(
                    title: const Text('全部账本'),
                    trailing: _selectedLedger == null
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLedger = null;
                      });
                      Navigator.pop(context);
                    },
                  );
                }
                return ListTile(
                  leading: const Icon(Icons.settings, color: Colors.orange),
                  title: const Text('管理账本', style: TextStyle(color: Colors.orange)),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LedgerManagePage(
                          ledgers: widget.ledgers,
                          defaultLedger: widget.defaultLedger,
                          onLedgersUpdated: widget.onLedgersUpdated ?? (updatedLedgers) {},
                        ),
                      ),
                    );
                  },
                );
              } else {
                if (index == 0) {
                  return ListTile(
                    title: const Text('全部账本'),
                    trailing: _selectedLedger == null
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLedger = null;
                      });
                      Navigator.pop(context);
                    },
                  );
                }
                if (index == widget.ledgers.length + 1) {
                  return ListTile(
                    leading: const Icon(Icons.settings, color: Colors.orange),
                    title: const Text('管理账本', style: TextStyle(color: Colors.orange)),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LedgerManagePage(
                            ledgers: widget.ledgers,
                            defaultLedger: widget.defaultLedger,
                            onLedgersUpdated: widget.onLedgersUpdated ?? (updatedLedgers) {},
                          ),
                        ),
                      );
                    },
                  );
                }
                final ledger = widget.ledgers[index - 1];
                return ListTile(
                  title: Text(ledger),
                  trailing: _selectedLedger == ledger
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedLedger = ledger;
                    });
                    Navigator.pop(context);
                  },
                );
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showCustomDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _toggleCalculateMode(bool value) {
    setState(() {
      _isCalculateMode = value;
      if (!value) {
        _selectedRecordIds.clear();
      }
    });
  }

  void _toggleRecordSelection(String id) {
    setState(() {
      if (_selectedRecordIds.contains(id)) {
        _selectedRecordIds.remove(id);
      } else {
        _selectedRecordIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedRecordIds.clear();
      for (final record in _filteredRecords) {
        _selectedRecordIds.add(record.id);
      }
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedRecordIds.clear();
    });
  }

  void _calculateSelected() {
    final total = _filteredRecords
        .where((record) => _selectedRecordIds.contains(record.id))
        .fold(0.0, (sum, record) => sum + record.amount);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('计算结果'),
        content: Text('选中 ${_selectedRecordIds.length} 条记录，总金额: ¥${total.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _editRecord(Record record) {
    // 简化的编辑功能 - 实际使用时需要完整实现
    widget.onUpdate(record);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 筛选组件
            RecordFiltersWidget(
              startDate: _startDate,
              endDate: _endDate,
              selectedWorkContent: _selectedWorkContent,
              selectedCategory: _selectedCategory,
              selectedLedger: _selectedLedger,
              searchKeyword: _searchKeyword,
              showFilters: _showFilters,
              workContents: _uniqueWorkContents,
              categories: _uniqueCategories,
              ledgers: widget.ledgers,
              onStartDateChanged: (date) => _selectDate(true),
              onEndDateChanged: (date) => _selectDate(false),
              onWorkContentChanged: (value) => setState(() => _selectedWorkContent = value),
              onCategoryChanged: (value) => setState(() => _selectedCategory = value),
              onLedgerChanged: (value) => setState(() => _selectedLedger = value),
              onSearchChanged: (value) => setState(() => _searchKeyword = value),
              onShowFiltersChanged: (value) => setState(() => _showFilters = value),
              ledgerSelectorBuilder: _buildLedgerSelector,
            ),
            
            const SizedBox(height: 16),
            
            // 操作组件
            RecordActionsWidget(
              isCalculateMode: _isCalculateMode,
              selectedRecordIds: _selectedRecordIds,
              filteredRecords: _filteredRecords,
              onCalculateModeChanged: _toggleCalculateMode,
              onSelectAll: _selectAll,
              onDeselectAll: _deselectAll,
              onCalculate: _calculateSelected,
              onExport: widget.onExport,
              onSync: widget.onSync,
            ),
            
            const SizedBox(height: 16),
            
            // 记录列表组件
            Expanded(
              child: RecordListWidget(
                records: _filteredRecords,
                selectedRecordIds: _selectedRecordIds,
                isCalculateMode: _isCalculateMode,
                onToggleSelection: _toggleRecordSelection,
                onEdit: _editRecord,
                onDelete: widget.onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}