import 'package:flutter/material.dart';
import '../models/record.dart';

class RecordActionsWidget extends StatelessWidget {
  final bool isCalculateMode;
  final Set<String> selectedRecordIds;
  final List<Record> filteredRecords;
  final Function(bool) onCalculateModeChanged;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback onCalculate;
  final void Function(int) onExport;
  final VoidCallback? onSync;

  const RecordActionsWidget({
    super.key,
    required this.isCalculateMode,
    required this.selectedRecordIds,
    required this.filteredRecords,
    required this.onCalculateModeChanged,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onCalculate,
    required this.onExport,
    this.onSync,
  });

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 计算模式切换
        Row(
          children: [
            const Text('计算模式', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Switch(
              value: isCalculateMode,
              onChanged: onCalculateModeChanged,
            ),
          ],
        ),
        
        // 计算模式下的操作
        if (isCalculateMode) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.select_all,
                label: '全选',
                onPressed: onSelectAll,
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.clear_all,
                label: '清空',
                onPressed: onDeselectAll,
              ),
              const Spacer(),
              Text(
                '已选择 ${selectedRecordIds.length} 条记录',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            icon: Icons.calculate,
            label: '计算选中记录',
            onPressed: onCalculate,
            color: Colors.green,
          ),
        ],
        
        // 常规操作
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionButton(
              icon: Icons.file_download,
              label: '导出记录',
              onPressed: () => onExport(filteredRecords.length),
            ),
            if (onSync != null) ...[
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.sync,
                label: '同步服务器',
                onPressed: onSync!,
              ),
            ],
          ],
        ),
        
        // 统计信息
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('总记录数: ${filteredRecords.length}'),
              Text(
                '总金额: ¥${_calculateTotalAmount().toStringAsFixed(2)}',
                style: const TextStyle(
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

  double _calculateTotalAmount() {
    if (isCalculateMode && selectedRecordIds.isNotEmpty) {
      return filteredRecords
          .where((record) => selectedRecordIds.contains(record.id))
          .map((record) => record.amount)
          .fold(0.0, (sum, amount) => sum + amount);
    }
    return filteredRecords
        .map((record) => record.amount)
        .fold(0.0, (sum, amount) => sum + amount);
  }
}