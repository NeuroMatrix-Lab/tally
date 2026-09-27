import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../widgets/custom_date_picker.dart';
import '../widgets/glass_controls.dart';
import '../services/app_time.dart';
import '../services/api_service.dart';
import '../window/immersive_window.dart';
import 'ledger_manage_page.dart';
import 'staff_selection_page.dart';
import '../models/staff.dart';

class AddRecordPage extends StatefulWidget {
  final Function(
    DateTime date,
    String workContent,
    double amount,
    String category,
    List<String> staffIds, {
    String? imageUrl,
  })
  onAdd;
  final List<String> categories;
  final List<String> workContents;
  final List<String> ledgers;
  final String defaultLedger;
  final Function(String) onLedgerChanged;
  final Function(String) onAddLedger;
  final Function(List<String>)? onLedgersUpdated;
  final List<Staff> staffList;
  final Function() onStaffListUpdated;
  final bool isSyncing;
  final bool isServerConnected;
  final VoidCallback onSync;

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
    required this.staffList,
    required this.onStaffListUpdated,
    required this.isSyncing,
    required this.isServerConnected,
    required this.onSync,
  });

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  DateTime _selectedDate = AppTime.now();
  final TextEditingController _workContentController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  bool _isUploading = false;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  List<String> _selectedStaffIds = [];

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
        imageQuality: 100,
      );

      if (pickedFile != null && mounted) {
        final file = File(pickedFile.path);
        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.path,
          '${file.parent.path}/compressed_${AppTime.now().millisecondsSinceEpoch}.jpg',
          quality: 30,
          minWidth: 800,
          minHeight: 800,
        );
        setState(() {
          _selectedImage = compressed != null ? File(compressed.path) : file;
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

  Future<void> _selectStaff() async {
    final List<String>? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaffSelectionPage(
          selectedStaffIds: _selectedStaffIds,
          staffList: widget.staffList,
          onStaffListUpdated: widget.onStaffListUpdated,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedStaffIds = result;
      });
    }
  }

  void _saveRecord() async {
    final category = _categoryController.text.trim();
    if (_workContentController.text.isEmpty ||
        _amountController.text.isEmpty ||
        category.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写完整信息')));
      return;
    }

    final double? amount = double.tryParse(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的金额')));
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('图片上传失败: $e')));
          setState(() {
            _isUploading = false;
          });
        }
        return;
      }
    }

    widget.onAdd(
      _selectedDate,
      _workContentController.text,
      amount,
      category,
      _selectedStaffIds,
      imageUrl: imageUrl,
    );
    _workContentController.clear();
    _amountController.clear();
    _categoryController.clear();
    setState(() {
      _selectedDate = AppTime.now();
      _isUploading = false;
      _selectedImage = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('记录已保存并上传')));
  }

  @override
  void dispose() {
    _workContentController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Widget _buildLedgerSelector() {
    return GlassSelector(
      value: widget.defaultLedger.isEmpty ? '选择账本' : widget.defaultLedger,
      placeholder: widget.defaultLedger.isEmpty,
      onTap: _showLedgerOverlay,
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
                  title: const Text(
                    '管理账本',
                    style: TextStyle(color: Colors.orange),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
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
                    title: const Text(
                      '管理账本',
                      style: TextStyle(color: Colors.orange),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
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
            },
          ),
        ),
        actions: [
          GlassTextAction(
            label: '关闭',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showOptionPicker({
    required String title,
    required List<String> options,
    required ValueChanged<String> onPick,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: options.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('暂无已有选项', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return ListTile(
                      title: Text(option),
                      onTap: () => Navigator.pop(context, option),
                    );
                  },
                ),
        ),
        actions: [
          GlassTextAction(
            label: '关闭',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
    if (selected != null) {
      onPick(selected);
    }
  }

  Widget _buildAutocompleteField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required List<String> options,
    VoidCallback? onPick,
  }) {
    return _CustomAutocomplete(
      label: label,
      hint: hint,
      controller: controller,
      options: options,
      onPick: onPick,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageTitleBar(
              title: '记账',
              isSyncing: widget.isSyncing,
              isServerConnected: widget.isServerConnected,
              onSync: widget.onSync,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            // 始终水平排列账本和日期
            Row(
              children: [
                Expanded(child: _buildLedgerSelector()),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassSelector(
                    value: DateFormat('yyyy-MM-dd').format(_selectedDate),
                    onTap: _selectDate,
                    trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAutocompleteField(
              label: '类别',
              hint: '输入或选择类别',
              controller: _categoryController,
              options: widget.categories,
              onPick: () => _showOptionPicker(
                title: '选择类别',
                options: widget.categories,
                onPick: (value) {
                  setState(() {
                    _categoryController.text = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildAutocompleteField(
              label: '工作内容',
              hint: '输入或选择工作内容',
              controller: _workContentController,
              options: widget.workContents,
              onPick: () => _showOptionPicker(
                title: '选择工作内容',
                options: widget.workContents,
                onPick: (value) {
                  setState(() {
                    _workContentController.text = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            GlassSelector(
              value: _selectedStaffIds.isEmpty
                  ? '选择人员'
                  : '已选择 ${_selectedStaffIds.length} 人',
              placeholder: _selectedStaffIds.isEmpty,
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.group, size: 18, color: Colors.grey),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: _selectStaff,
            ),
            const SizedBox(height: 16),
            GlassField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              hintText: '金额',
            ),
            const SizedBox(height: 16),
            GlassContainer(
              useOwnLayer: true,
              shape: const LiquidRoundedRectangle(borderRadius: 16),
              settings: LiquidGlassSettings(
                glassColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.62),
                thickness: 16,
                refractiveIndex: 1.1,
                lightIntensity: 0.5,
              ),
              padding: const EdgeInsets.all(16),
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
                          GlassSecondaryButton(
                            label: '选择图片',
                            height: 36,
                            width: 100,
                            onPressed: _showImagePickerDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_selectedImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                      child: Text('暂无图片', style: TextStyle(color: Colors.grey)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlassPrimaryButton(
              label: '保存&上传',
              onPressed: _isUploading ? null : _saveRecord,
              height: 52,
            ),
          ],
        ),
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
  final VoidCallback? onPick;

  const _CustomAutocomplete({
    required this.label,
    required this.hint,
    required this.controller,
    required this.options,
    this.onPick,
  });

  @override
  State<_CustomAutocomplete> createState() => _CustomAutocompleteState();
}

class _CustomAutocompleteState extends State<_CustomAutocomplete> {
  TextEditingController? _internalController;

  @override
  void dispose() {
    _internalController?.removeListener(_syncToParent);
    super.dispose();
  }

  void _syncToParent() {
    if (_internalController != null) {
      widget.controller.text = _internalController!.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return widget.options;
        }
        return widget.options.where((o) => o.contains(textEditingValue.text));
      },
      onSelected: (String selection) {
        widget.controller.text = selection;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: selection.length),
        );
        if (_internalController != null) {
          _internalController!.text = selection;
          _internalController!.selection = widget.controller.selection;
        }
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onSubmitted) {
        if (_internalController != textEditingController) {
          _internalController?.removeListener(_syncToParent);
          _internalController = textEditingController;
          _internalController!.addListener(_syncToParent);
          if (widget.controller.text.isNotEmpty) {
            textEditingController.text = widget.controller.text;
            textEditingController.selection = widget.controller.selection;
          }
        }
        return GlassField(
          controller: textEditingController,
          focusNode: focusNode,
          hintText: widget.hint,
          labelText: widget.label,
          suffixIcon: widget.onPick == null
              ? (widget.options.isEmpty
                    ? null
                    : const Icon(Icons.arrow_drop_down))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      '选择',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  ],
                ),
          onSuffixTap: widget.onPick,
          onSubmitted: (_) => onSubmitted(),
        );
      },
    );
  }
}

