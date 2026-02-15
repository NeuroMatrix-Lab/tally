import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_date_picker.dart';
import '../services/api_service.dart';
import 'ledger_manage_page.dart';

class AddRecordPage extends StatefulWidget {
  final Function(DateTime date, String workContent, double amount, String category, {String? imageUrl}) onAdd;
  final List<String> categories;
  final List<String> workContents;
  final List<String> ledgers;
  final String defaultLedger;
  final Function(String) onLedgerChanged;
  final Function(String) onAddLedger;
  final Function(List<String>)? onLedgersUpdated;

  const AddRecordPage({
    super.key, 
    required this.onAdd, 
    required this.categories, 
    required this.workContents,
    required this.ledgers,
    required this.defaultLedger,
    required this.onLedgerChanged,
    required this.onAddLedger,
    this.onLedgersUpdated,
  });

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _workContentController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  bool _isUploading = false;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择图片'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _saveRecord() async {
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

    setState(() {
      _isUploading = true;
    });

    String? imageUrl;
    if (_selectedImage != null) {
      try {
        imageUrl = await ApiService.uploadImage(_selectedImage!);
      } catch (e) {
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片上传失败: $e')),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      }
    }

    widget.onAdd(_selectedDate, _workContentController.text, amount, category, imageUrl: imageUrl);
    _workContentController.clear();
    _amountController.clear();
    _categoryController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _isUploading = false;
      _selectedImage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('记录已保存并上传')),
    );
  }

  @override
  void dispose() {
    _workContentController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Widget _buildLedgerSelector() {
    return GestureDetector(
      onTap: () {
        _showLedgerOverlay();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('账本', style: TextStyle(fontSize: 16)),
            Row(
              children: [
                Text(
                  widget.defaultLedger.isEmpty ? '选择账本' : widget.defaultLedger,
                  style: const TextStyle(fontSize: 16),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLedgerOverlay() {
    final itemCount = widget.ledgers.isEmpty ? 1 : widget.ledgers.length + 1;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择账本'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (widget.ledgers.isEmpty) {
                return ListTile(
                  leading: const Icon(Icons.settings, color: Colors.orange),
                  title: const Text('管理账本', style: TextStyle(color: Colors.orange)),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LedgerManagePage(
                          ledgers: widget.ledgers,
                          defaultLedger: widget.defaultLedger,
                          onLedgersUpdated: (updatedLedgers) {
                            if (widget.onLedgersUpdated != null) {
                              widget.onLedgersUpdated!(updatedLedgers);
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              } else {
                if (index == widget.ledgers.length) {
                  return ListTile(
                    leading: const Icon(Icons.settings, color: Colors.orange),
                    title: const Text('管理账本', style: TextStyle(color: Colors.orange)),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LedgerManagePage(
                            ledgers: widget.ledgers,
                            defaultLedger: widget.defaultLedger,
                            onLedgersUpdated: (updatedLedgers) {
                              if (widget.onLedgersUpdated != null) {
                                widget.onLedgersUpdated!(updatedLedgers);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  );
                }
                final ledger = widget.ledgers[index];
                return ListTile(
                  title: Text(ledger),
                  trailing: widget.defaultLedger == ledger
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    widget.onLedgerChanged(ledger);
                    Navigator.pop(context);
                  },
                );
              }
              return const SizedBox.shrink();
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

  void _showAddLedgerDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加账本'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入账本名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.onAddLedger(name);
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const Text(
            '添加记录',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildLedgerSelector(),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('图片', style: TextStyle(fontSize: 16)),
                    Row(
                      children: [
                        if (_selectedImage != null)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _removeImage,
                            tooltip: '删除图片',
                          ),
                        ElevatedButton.icon(
                          onPressed: _showImagePickerDialog,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('选择图片'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      '暂无图片',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isUploading ? null : _saveRecord,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存&上传', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
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
