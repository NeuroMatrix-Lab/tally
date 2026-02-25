import 'package:flutter/material.dart';
import '../models/record.dart';
import '../models/staff.dart';
import '../widgets/custom_date_picker.dart';
import 'staff_selection_page.dart';

class EditRecordDialog extends StatefulWidget {
  final Record record;
  final List<String> categories;
  final List<String> workContents;
  final List<String> ledgers;
  final String defaultLedger;
  final List<Staff> staffList;
  final Function(Record) onUpdate;

  const EditRecordDialog({
    super.key,
    required this.record,
    required this.categories,
    required this.workContents,
    required this.ledgers,
    required this.defaultLedger,
    required this.staffList,
    required this.onUpdate,
  });

  @override
  State<EditRecordDialog> createState() => _EditRecordDialogState();
}

class _EditRecordDialogState extends State<EditRecordDialog> {
  late DateTime _selectedDate;
  late TextEditingController _workContentController;
  late TextEditingController _amountController;
  late TextEditingController _categoryController;
  late List<String> _selectedStaffIds;
  late String _selectedLedger;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.record.date;
    _workContentController = TextEditingController(text: widget.record.workContent);
    _amountController = TextEditingController(text: widget.record.amount.toString());
    _categoryController = TextEditingController(text: widget.record.category);
    _selectedStaffIds = List.from(widget.record.staffIds);
    _selectedLedger = widget.record.ledger;
  }

  @override
  void dispose() {
    _workContentController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showCustomDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStaff() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => StaffSelectionPage(
          staffList: widget.staffList,
          selectedStaffIds: _selectedStaffIds,
          onStaffListUpdated: () {},
        ),
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _selectedStaffIds = result;
      });
    }
  }

  void _saveChanges() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的金额')),
      );
      return;
    }

    if (_workContentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入工作内容')),
      );
      return;
    }

    if (_categoryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入类别')),
      );
      return;
    }

    final updatedRecord = Record(
      id: widget.record.id,
      date: _selectedDate,
      workContent: _workContentController.text,
      amount: amount,
      category: _categoryController.text,
      ledger: _selectedLedger,
      staffIds: _selectedStaffIds,
      imageUrl: widget.record.imageUrl,
    );

    widget.onUpdate(updatedRecord);
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已更新记录: ${_workContentController.text}')),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '日期: ${_formatDate(_selectedDate)}',
              style: const TextStyle(fontSize: 16),
            ),
            Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffField() {
    final staffNames = _selectedStaffIds.map((id) {
      final staff = widget.staffList.firstWhere((s) => s.id == id, orElse: () => Staff(id: '', name: '未知'));
      return staff.name;
    }).toList();
    
    final displayText = staffNames.isEmpty ? '选择参与人员' : staffNames.join(', ');
    
    return GestureDetector(
      onTap: _selectStaff,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '参与人员: $displayText',
                style: TextStyle(
                  fontSize: 16,
                  color: staffNames.isEmpty 
                      ? Theme.of(context).colorScheme.onSurface.withAlpha(153) // 0.6 opacity
                      : Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.people, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerField() {
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
                itemCount: widget.ledgers.length,
                itemBuilder: (context, index) {
                  final ledger = widget.ledgers[index];
                  return ListTile(
                    title: Text(ledger),
                    trailing: _selectedLedger == ledger
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedLedger = ledger;
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
                child: const Text('取消'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '账本: $_selectedLedger',
              style: const TextStyle(fontSize: 16),
            ),
            Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '编辑记录',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // 日期选择
            _buildDateField(),
            const SizedBox(height: 12),
            
            // 工作内容
            TextField(
              controller: _workContentController,
              decoration: const InputDecoration(
                labelText: '工作内容',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            
            // 金额
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '金额',
                border: OutlineInputBorder(),
                prefixText: '¥',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            
            // 类别
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: '类别',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            
            // 参与人员
            _buildStaffField(),
            const SizedBox(height: 12),
            
            // 账本
            _buildLedgerField(),
            const SizedBox(height: 20),
            
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}