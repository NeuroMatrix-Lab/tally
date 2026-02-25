import 'package:flutter/material.dart';
import '../models/record.dart';

class RecordListWidget extends StatelessWidget {
  final List<Record> records;
  final Set<String> selectedRecordIds;
  final bool isCalculateMode;
  final Function(String) onToggleSelection;
  final Function(Record) onEdit;
  final Function(String) onDelete;

  const RecordListWidget({
    super.key,
    required this.records,
    required this.selectedRecordIds,
    required this.isCalculateMode,
    required this.onToggleSelection,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _buildRecordItem(Record record) {
    final isSelected = selectedRecordIds.contains(record.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        leading: isCalculateMode
            ? Checkbox(
                value: isSelected,
                onChanged: (value) => onToggleSelection(record.id),
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
        title: Text(
          record.workContent,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('类别: ${record.category}'),
            Text('账本: ${record.ledger}'),
            Text('日期: ${_formatDate(record.date)}'),
            if (record.staffIds.isNotEmpty)
              Text('参与人员: ${record.staffIds.length}人'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '¥${record.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            if (!isCalculateMode)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => onEdit(record),
                    tooltip: '编辑',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () => onDelete(record.id),
                    tooltip: '删除',
                  ),
                ],
              ),
          ],
        ),
        onTap: isCalculateMode
            ? () => onToggleSelection(record.id)
            : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(
        child: Text(
          '暂无记录',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        return _buildRecordItem(records[index]);
      },
    );
  }
}