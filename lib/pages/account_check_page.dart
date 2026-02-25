import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../models/staff.dart';
import '../services/api_service.dart';
import '../widgets/custom_date_picker.dart';
import 'edit_record_dialog.dart';

class AccountCheckPage extends StatefulWidget {
  final List<Record> records;
  final List<Staff> staffList;
  final List<String> ledgers;
  final String defaultLedger;
  final Function(String) onLedgerChanged;
  final Function(Record) onUpdate;
  final Function(Record) onDelete;

  const AccountCheckPage({
    super.key,
    required this.records,
    required this.staffList,
    required this.ledgers,
    required this.defaultLedger,
    required this.onLedgerChanged,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<AccountCheckPage> createState() => _AccountCheckPageState();
}

class _AccountCheckPageState extends State<AccountCheckPage> {
  String? _selectedLedger;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCategory;
  String? _selectedStaff;
  String _searchKeyword = '';
  bool _showFilters = false;
  Set<String> _selectedRecordIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _selectedLedger = widget.defaultLedger;
  }

  // 按日期分组记录
  Map<String, List<Record>> get _groupedRecords {
    final filteredRecords = _filteredRecords;
    final grouped = <String, List<Record>>{};
    
    for (final record in filteredRecords) {
      final dateKey = _formatDate(record.date);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(record);
    }
    
    // 按日期排序
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedMap = <String, List<Record>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }
    
    return sortedMap;
  }

  List<Record> get _filteredRecords {
    var filtered = widget.records;

    // 按账本筛选
    if (_selectedLedger != null) {
      filtered = filtered.where((record) => record.ledger == _selectedLedger).toList();
    }

    // 按日期范围筛选
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

    // 按类别筛选
    if (_selectedCategory != null) {
      filtered = filtered.where((record) => record.category == _selectedCategory).toList();
    }

    // 按参与人员筛选
    if (_selectedStaff != null) {
      filtered = filtered.where((record) {
        return record.staffIds.contains(_selectedStaff);
      }).toList();
    }

    // 按关键词搜索
    if (_searchKeyword.isNotEmpty) {
      final keyword = _searchKeyword.toLowerCase();
      filtered = filtered.where((record) {
        return record.workContent.toLowerCase().contains(keyword) ||
            record.category.toLowerCase().contains(keyword) ||
            record.amount.toString().contains(keyword) ||
            _getStaffNames(record.staffIds).toLowerCase().contains(keyword);
      }).toList();
    }

    return filtered..sort((a, b) => b.date.compareTo(a.date));
  }

  // 获取人员名称
  String _getStaffNames(List<String> staffIds) {
    if (staffIds.isEmpty) return '无';
    
    final staffNames = staffIds.map((id) {
      final staff = widget.staffList.firstWhere((s) => s.id == id, orElse: () => Staff(id: '', name: '未知'));
      return staff.name;
    }).toList();
    
    return staffNames.join(', ');
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy年MM月dd日').format(date);
  }

  List<String> get _uniqueCategories {
    final categories = widget.records.map((r) => r.category).toSet().toList();
    categories.sort();
    return categories;
  }

  List<String> get _uniqueStaffNames {
    final staffNames = widget.staffList.map((s) => s.name).toSet().toList();
    staffNames.sort();
    return staffNames;
  }

  List<String> _getUniqueWorkContents() {
    final workContents = widget.records.map((r) => r.workContent).toSet().toList();
    workContents.sort();
    return workContents;
  }

  Widget _buildDateHeader(String date) {
    final records = _groupedRecords[date] ?? [];
    final totalAmount = records.fold(0.0, (sum, record) => sum + record.amount);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(25),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            date,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            '总计: ¥${totalAmount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(Record record) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: InkWell(
        onTap: () => _showRecordOptions(record),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // 左侧图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // 中间内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.workContent,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '类别: ${record.category}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '参与人员: ${_getStaffNames(record.staffIds)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // 右侧金额和操作按钮
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${record.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    record.ledger,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // 编辑按钮
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () => _editRecord(record),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // 删除按钮
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          size: 18,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => _deleteRecord(record),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('日期范围', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _startDate != null
                            ? DateFormat('MM/dd').format(_startDate!)
                            : '开始日期',
                        style: TextStyle(
                          fontSize: 12,
                          color: _startDate != null 
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 14),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _endDate != null
                            ? DateFormat('MM/dd').format(_endDate!)
                            : '结束日期',
                        style: TextStyle(
                          fontSize: 12,
                          color: _endDate != null 
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownFilter({
    required String? value,
    required List<String> options,
    required String hintText,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(
            hintText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
            ),
          ),
        ),
        ...options.map((option) => DropdownMenuItem(
          value: option,
          child: Text(option),
        )),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
  
  // 紧凑版本的筛选器
  Widget _buildCompactDropdownFilter({
    required String? value,
    required List<String> options,
    required String hintText,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(
            hintText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
              fontSize: 12,
            ),
          ),
        ),
        ...options.map((option) => DropdownMenuItem(
          value: option,
          child: Text(
            option,
            style: const TextStyle(fontSize: 12),
          ),
        )),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildLedgerSelector() {
    final displayLedger = _selectedLedger ?? '全部账本';
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('选择账本'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.ledgers.isEmpty ? 1 : widget.ledgers.length + 1,
                itemBuilder: (context, index) {
                  if (widget.ledgers.isEmpty) {
                    return const ListTile(
                      title: Text('暂无账本'),
                    );
                  }
                  
                  if (index == 0) {
                    return ListTile(
                      title: const Text('全部账本'),
                      trailing: _selectedLedger == null
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedLedger = null;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }
                  
                  final ledger = widget.ledgers[index - 1];
                  return ListTile(
                    title: Text(ledger),
                    trailing: _selectedLedger == ledger
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLedger = ledger;
                        widget.onLedgerChanged(ledger);
                      });
                      Navigator.pop(context);
                    },
                  );
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
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
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
                  color: displayLedger == '全部账本' 
                      ? Theme.of(context).colorScheme.onSurface.withAlpha(153)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (widget.ledgers.isNotEmpty)
              Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurface),
          ],
        ),
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

  void _showRecordOptions(Record record) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              title: const Text('编辑记录'),
              onTap: () {
                Navigator.pop(context);
                _editRecord(record);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: const Text('删除记录'),
              onTap: () {
                Navigator.pop(context);
                _deleteRecord(record);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  void _editRecord(Record record) {
    showDialog(
      context: context,
      builder: (context) => EditRecordDialog(
        record: record,
        categories: _uniqueCategories,
        workContents: _getUniqueWorkContents(),
        ledgers: widget.ledgers,
        defaultLedger: widget.defaultLedger,
        staffList: widget.staffList,
        onUpdate: (updatedRecord) {
          widget.onUpdate(updatedRecord);
        },
      ),
    );
  }

  void _deleteRecord(Record record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除记录"${record.workContent}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete(record);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除记录: ${record.workContent}')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedRecords = _groupedRecords;
    
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          // 搜索框
          TextField(
            decoration: InputDecoration(
              hintText: '搜索工作内容、类别、金额、参与人员...',
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withAlpha(153)),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            onChanged: (value) => setState(() => _searchKeyword = value),
          ),
          
          const SizedBox(height: 8),
          
          // 筛选开关
          Row(
            children: [
              const Text('高级筛选', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: _showFilters,
                onChanged: (value) => setState(() => _showFilters = value),
              ),
            ],
          ),
          
          // 筛选条件
          if (_showFilters) ...[
            const SizedBox(height: 8),
            _buildDateFilter(),
            const SizedBox(height: 8),
            _buildDropdownFilter(
              value: _selectedLedger,
              options: ['全部账本'] + widget.ledgers,
              hintText: '选择账本',
              onChanged: (value) => setState(() => _selectedLedger = value == '全部账本' ? null : value),
            ),
            const SizedBox(height: 8),
            // 类别和人员筛选项放在一行
            Row(
              children: [
                Expanded(
                  child: _buildCompactDropdownFilter(
                    value: _selectedCategory,
                    options: _uniqueCategories,
                    hintText: '类别',
                    onChanged: (value) => setState(() => _selectedCategory = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactDropdownFilter(
                    value: _selectedStaff,
                    options: _uniqueStaffNames,
                    hintText: '参与人员',
                    onChanged: (value) => setState(() => _selectedStaff = value),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 4),
          
          // 选择并计算功能
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _selectionMode = !_selectionMode),
                  icon: Icon(_selectionMode ? Icons.check_circle : Icons.calculate, size: 16),
                  label: Text(_selectionMode ? '退出选择模式' : '选择并计算', style: const TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    backgroundColor: _selectionMode 
                      ? Theme.of(context).colorScheme.primaryContainer 
                      : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_filteredRecords.length}条 ¥${_filteredRecords.fold(0.0, (sum, record) => sum + record.amount).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // 记录列表
          Expanded(
            child: groupedRecords.isEmpty
                ? Center(
                    child: Text(
                      '暂无记录',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(0),
                    itemCount: groupedRecords.length * 2, // 每个日期组包含日期标题和记录
                    itemBuilder: (context, index) {
                      if (index.isEven) {
                        // 日期标题
                        final dateIndex = index ~/ 2;
                        final date = groupedRecords.keys.elementAt(dateIndex);
                        return _buildDateHeader(date);
                      } else {
                        // 该日期的记录列表
                        final dateIndex = (index - 1) ~/ 2;
                        final date = groupedRecords.keys.elementAt(dateIndex);
                        final records = groupedRecords[date]!;
                        
                        return Column(
                          children: records.map((record) => _buildRecordItem(record)).toList(),
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  // 显示选择计算对话框
  void _showSelectionCalculation() {
    setState(() {
      _selectionMode = true;
      _selectedRecordIds.clear();
    });
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedRecords = _filteredRecords.where((record) => _selectedRecordIds.contains(record.id)).toList();
          final totalAmount = selectedRecords.fold(0.0, (sum, record) => sum + record.amount);
          
          return AlertDialog(
            title: const Text('选择并计算'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 选择模式说明
                  Text(
                    '请选择要计算的记录（已选择 ${selectedRecords.length} 条）',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 记录列表
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = _filteredRecords[index];
                        final isSelected = _selectedRecordIds.contains(record.id);
                        
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                _selectedRecordIds.add(record.id);
                              } else {
                                _selectedRecordIds.remove(record.id);
                              }
                            });
                          },
                          title: Text(
                            record.workContent,
                            style: TextStyle(
                              fontSize: 14,
                              decoration: isSelected ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            '¥${record.amount.toStringAsFixed(2)} - ${_formatDate(record.date)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                          secondary: Text(
                            '¥${record.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 统计信息
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '已选择: ${selectedRecords.length}条',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '总计: ¥${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    _selectedRecordIds.clear();
                  });
                },
                child: const Text('清空选择'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectionMode = false;
                    _selectedRecordIds.clear();
                  });
                },
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: selectedRecords.isEmpty ? null : () {
                  // 可以在这里添加导出或其他操作
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已计算 ${selectedRecords.length} 条记录，总计 ¥${totalAmount.toStringAsFixed(2)}'),
                    ),
                  );
                  Navigator.pop(context);
                  setState(() {
                    _selectionMode = false;
                    _selectedRecordIds.clear();
                  });
                },
                child: const Text('确认计算'),
              ),
            ],
          );
        },
      ),
    );
  }
}