import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddRecordPage extends StatefulWidget {
  final Function(DateTime date, String workContent, double amount, String category) onAdd;
  final List<String> categories;
  final List<String> workContents;

  const AddRecordPage({super.key, required this.onAdd, required this.categories, required this.workContents});

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _workContentController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
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

  void _saveRecord() {
    final category = _categoryController.text.trim();
    if (_workContentController.text.isEmpty || _amountController.text.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整信息')),
      );
      return;
    }

    final double? amount = double.tryParse(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的金额')),
      );
      return;
    }

    widget.onAdd(_selectedDate, _workContentController.text, amount, category);
    _workContentController.clear();
    _amountController.clear();
    _categoryController.clear();
    setState(() {
      _selectedDate = DateTime.now();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('记录已保存')),
    );
  }

  @override
  void dispose() {
    _workContentController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Widget _buildAutocompleteField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required List<String> options,
    required Function(String) onSelected,
  }) {
    return _CustomAutocomplete(
      label: label,
      hint: hint,
      controller: controller,
      options: options,
      onSelected: onSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '添加记录',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('日期', style: TextStyle(fontSize: 16)),
                  Row(
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildAutocompleteField(
            label: '类别',
            hint: '输入或选择类别',
            controller: _categoryController,
            options: widget.categories,
            onSelected: (selection) {
              _categoryController.text = selection;
              _categoryController.selection = TextSelection.fromPosition(TextPosition(offset: selection.length));
            },
          ),
          const SizedBox(height: 16),
          _buildAutocompleteField(
            label: '工作内容',
            hint: '输入或选择工作内容',
            controller: _workContentController,
            options: widget.workContents,
            onSelected: (selection) {
              _workContentController.text = selection;
              _workContentController.selection = TextSelection.fromPosition(TextPosition(offset: selection.length));
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '金额',
              border: OutlineInputBorder(),
              prefixText: '¥ ',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveRecord,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('保存', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

class _CustomAutocomplete extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final List<String> options;
  final Function(String) onSelected;

  const _CustomAutocomplete({
    required this.label,
    required this.hint,
    required this.controller,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_CustomAutocomplete> createState() => _CustomAutocompleteState();
}

class _CustomAutocompleteState extends State<_CustomAutocomplete> {
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
