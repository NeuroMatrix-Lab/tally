import 'package:flutter/material.dart';

class RecordFiltersWidget extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedWorkContent;
  final String? selectedCategory;
  final String? selectedLedger;
  final String searchKeyword;
  final bool showFilters;
  final List<String> workContents;
  final List<String> categories;
  final List<String> ledgers;
  final Function(DateTime?) onStartDateChanged;
  final Function(DateTime?) onEndDateChanged;
  final Function(String?) onWorkContentChanged;
  final Function(String?) onCategoryChanged;
  final Function(String?) onLedgerChanged;
  final Function(String) onSearchChanged;
  final Function(bool) onShowFiltersChanged;
  final Widget Function() ledgerSelectorBuilder;

  const RecordFiltersWidget({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.selectedWorkContent,
    required this.selectedCategory,
    required this.selectedLedger,
    required this.searchKeyword,
    required this.showFilters,
    required this.workContents,
    required this.categories,
    required this.ledgers,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onWorkContentChanged,
    required this.onCategoryChanged,
    required this.onLedgerChanged,
    required this.onSearchChanged,
    required this.onShowFiltersChanged,
    required this.ledgerSelectorBuilder,
  });

  Widget _buildDateFilter() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(true),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    startDate != null
                        ? _formatDate(startDate!)
                        : '开始日期',
                    style: TextStyle(
                      color: startDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                  const Icon(Icons.calendar_today, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(false),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    endDate != null
                        ? _formatDate(endDate!)
                        : '结束日期',
                    style: TextStyle(
                      color: endDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                  const Icon(Icons.calendar_today, size: 16),
                ],
              ),
            ),
          ),
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
      initialValue: value,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: hintText,
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(hintText, style: const TextStyle(color: Colors.grey)),
        ),
        ...options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    // 这里需要实现日期选择器
    // 由于CustomDatePicker需要context，这里暂时留空
    // 实际使用时需要传入日期选择器函数
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 搜索框
        TextField(
          decoration: const InputDecoration(
            hintText: '搜索工作内容、类别、金额...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: 12),
        
        // 筛选开关
        Row(
          children: [
            const Text('高级筛选', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Switch(
              value: showFilters,
              onChanged: onShowFiltersChanged,
            ),
          ],
        ),
        
        // 筛选条件
        if (showFilters) ...[
          const SizedBox(height: 12),
          _buildDateFilter(),
          const SizedBox(height: 12),
          _buildDropdownFilter(
            value: selectedWorkContent,
            options: workContents,
            hintText: '选择工作内容',
            onChanged: onWorkContentChanged,
          ),
          const SizedBox(height: 12),
          _buildDropdownFilter(
            value: selectedCategory,
            options: categories,
            hintText: '选择类别',
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 12),
          ledgerSelectorBuilder(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}