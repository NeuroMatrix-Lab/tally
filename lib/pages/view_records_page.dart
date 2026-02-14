import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/record.dart';

class ViewRecordsPage extends StatefulWidget {
  final List<Record> records;
  final Function(String id) onDelete;
  final Function(Record record) onUpdate;

  const ViewRecordsPage({super.key, required this.records, required this.onDelete, required this.onUpdate});

  @override
  State<ViewRecordsPage> createState() => _ViewRecordsPageState();
}

class _ViewRecordsPageState extends State<ViewRecordsPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedWorkContent;
  String? _selectedCategory;
  bool _isCalculateMode = false;
  final Set<String> _selectedRecordIds = {};

  List<Record> get _filteredRecords {
    var filtered = widget.records;

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

  double get _totalAmount {
    return _filteredRecords.fold(0.0, (sum, record) => sum + record.amount);
  }

  double get _selectedTotalAmount {
    return _filteredRecords
        .where((record) => _selectedRecordIds.contains(record.id))
        .fold(0.0, (sum, record) => sum + record.amount);
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
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
    final DateTime? picked = await showDatePicker(
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

  void _toggleCalculateMode() {
    setState(() {
      _isCalculateMode = !_isCalculateMode;
      if (!_isCalculateMode) {
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

  Future<void> _exportToExcel() async {
    if (_filteredRecords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可导出的记录')),
        );
      }
      return;
    }

    try {
      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['账目记录'];

      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = excel.TextCellValue('日期');
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value = excel.TextCellValue('类别');
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value = excel.TextCellValue('工作内容');
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value = excel.TextCellValue('金额');

      for (var i = 0; i < _filteredRecords.length; i++) {
        final record = _filteredRecords[i];
        final rowIndex = i + 1;
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = excel.TextCellValue(DateFormat('yyyy-MM-dd').format(record.date));
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = excel.TextCellValue(record.category);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = excel.TextCellValue(record.workContent);
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = excel.TextCellValue(record.amount.toString());
      }

      final directory = await getTemporaryDirectory();
      final fileName = '账目记录_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${directory.path}/$fileName');
      final bytes = excelFile.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes, flush: true);
        if (mounted) {
          await Share.shareXFiles([XFile(file.path)], text: '导出账目记录');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  void _editRecord(Record record) {
    final TextEditingController dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(record.date));
    final TextEditingController workContentController = TextEditingController(text: record.workContent);
    final TextEditingController amountController = TextEditingController(text: record.amount.toString());
    final TextEditingController categoryController = TextEditingController(text: record.category);
    DateTime selectedDate = record.date;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑记录'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                          dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: dateController,
                        decoration: const InputDecoration(
                          labelText: '日期',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _EditAutocomplete(
                    label: '类别',
                    hint: '输入或选择类别',
                    controller: categoryController,
                    options: _uniqueCategories,
                    onSelected: (selection) {
                      categoryController.text = selection;
                      categoryController.selection = TextSelection.fromPosition(TextPosition(offset: selection.length));
                    },
                  ),
                  const SizedBox(height: 16),
                  _EditAutocomplete(
                    label: '工作内容',
                    hint: '输入或选择工作内容',
                    controller: workContentController,
                    options: _uniqueWorkContents,
                    onSelected: (selection) {
                      workContentController.text = selection;
                      workContentController.selection = TextSelection.fromPosition(TextPosition(offset: selection.length));
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '金额',
                      border: OutlineInputBorder(),
                      prefixText: '¥ ',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (workContentController.text.isEmpty || amountController.text.isEmpty || categoryController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写完整信息')),
                  );
                  return;
                }

                final double? amount = double.tryParse(amountController.text);
                if (amount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入有效的金额')),
                  );
                  return;
                }

                final updatedRecord = Record(
                  id: record.id,
                  date: selectedDate,
                  workContent: workContentController.text,
                  amount: amount,
                  category: categoryController.text,
                );

                widget.onUpdate(updatedRecord);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('记录已更新')),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleCalculateMode,
                    icon: Icon(_isCalculateMode ? Icons.close : Icons.calculate),
                    label: Text(_isCalculateMode ? '取消计算' : '计算'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCalculateMode ? Colors.red : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _exportToExcel,
                    icon: const Icon(Icons.file_download),
                    label: const Text('导出'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
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
                          border: Border.all(color: Colors.grey),
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
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (_startDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _startDate = null;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            const Icon(Icons.calendar_today, size: 20),
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
                          border: Border.all(color: Colors.grey),
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
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (_endDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _endDate = null;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '工作内容',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('全部'),
                              value: _selectedWorkContent,
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('全部'),
                                ),
                                ..._uniqueWorkContents.map((content) {
                                  return DropdownMenuItem<String>(
                                    value: content,
                                    child: Text(content),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedWorkContent = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '类别',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('全部'),
                              value: _selectedCategory,
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('全部'),
                                ),
                                ..._uniqueCategories.map((category) {
                                  return DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isCalculateMode) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _selectAll,
                      icon: const Icon(Icons.select_all),
                      label: const Text('全选'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _deselectAll,
                      icon: const Icon(Icons.deselect),
                      label: const Text('取消全选'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _filteredRecords.isEmpty
              ? const Center(child: Text('暂无记录'))
              : Column(
                  children: [
                    if (_isCalculateMode)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.blue.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '总计:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '¥${_totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = _filteredRecords[index];
                          final isSelected = _selectedRecordIds.contains(record.id);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            color: isSelected ? Colors.blue.shade50 : null,
                            child: ListTile(
                              onTap: _isCalculateMode ? null : () => _editRecord(record),
                              leading: _isCalculateMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (_) {
                                        _toggleRecordSelection(record.id);
                                      },
                                    )
                                  : null,
                              title: Text(record.workContent),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('yyyy-MM-dd').format(record.date)),
                                  Text(
                                    record.category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '¥${record.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!_isCalculateMode)
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () {
                                        widget.onDelete(record.id);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        if (_isCalculateMode && _selectedRecordIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已选 ${_selectedRecordIds.length} 条记录合计:',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '¥${_selectedTotalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EditAutocomplete extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final List<String> options;
  final Function(String) onSelected;

  const _EditAutocomplete({
    required this.label,
    required this.hint,
    required this.controller,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_EditAutocomplete> createState() => _EditAutocompleteState();
}

class _EditAutocompleteState extends State<_EditAutocomplete> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final GlobalKey _textFieldKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.options.isNotEmpty) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    
    final renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _hideOverlay,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            top: position.dy + size.height + 8,
            left: position.dx,
            width: size.width,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.options.length,
                  itemBuilder: (context, index) {
                    final option = widget.options[index];
                    return InkWell(
                      onTap: () {
                        widget.onSelected(option);
                        _hideOverlay();
                        _focusNode.unfocus();
                      },
                      child: ListTile(
                        title: Text(option),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        key: _textFieldKey,
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            hintText: widget.hint,
            suffixIcon: widget.options.isEmpty ? null : const Icon(Icons.arrow_drop_down),
          ),
          onTap: () {
            if (widget.options.isNotEmpty) {
              _showOverlay();
            }
          },
          onChanged: (value) {
            _hideOverlay();
          },
        ),
      ),
    );
  }
}
