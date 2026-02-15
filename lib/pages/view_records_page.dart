import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import '../models/record.dart';
import '../widgets/custom_date_picker.dart';
import '../services/api_service.dart';
import 'ledger_manage_page.dart';

class ViewRecordsPage extends StatefulWidget {
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

  const ViewRecordsPage({
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
  State<ViewRecordsPage> createState() => _ViewRecordsPageState();
}

class _ViewRecordsPageState extends State<ViewRecordsPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedWorkContent;
  String? _selectedCategory;
  bool _isCalculateMode = false;
  final Set<String> _selectedRecordIds = {};
  List<Record> _serverRecords = [];
  bool _isLoading = false;
  String? _selectedLedger;
  String _searchKeyword = '';
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _selectedLedger = widget.defaultLedger;
  }

  List<Record> get _filteredRecords {
    if (_isLoading) {
      return [];
    }

    // 如果正在进行服务器搜索，优先显示服务器结果
    if (_serverRecords.isNotEmpty && (_startDate != null || _endDate != null || _selectedCategory != null)) {
      return _serverRecords;
    }

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
      onTap: () {
        _showLedgerOverlay();
      },
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
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final itemCount = widget.ledgers.isEmpty ? 1 : widget.ledgers.length + 2;
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

  double get _totalAmount {
    return _filteredRecords.fold(0.0, (sum, record) => sum + record.amount);
  }

  double get _selectedTotalAmount {
    return _filteredRecords
        .where((record) => _selectedRecordIds.contains(record.id))
        .fold(0.0, (sum, record) => sum + record.amount);
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showCustomDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        _serverRecords = [];
      });
      _searchFromServer();
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showCustomDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
        _serverRecords = [];
      });
      _searchFromServer();
    }
  }

  Future<void> _searchFromServer() async {
    if (_startDate == null || _endDate == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final startDate = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final endDate = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      
      final records = await ApiService.searchRecords(
        startDate: startDate,
        endDate: endDate,
        category: _selectedCategory,
        ledger: _selectedLedger,
      );

      if (mounted) {
        setState(() {
          _serverRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error searching from server: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshFromServer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records = await ApiService.getRecentRecords(months: 12);

      if (mounted) {
        setState(() {
          _serverRecords = records;
          _isLoading = false;
        });
        widget.onSync?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从服务器更新数据')),
        );
      }
    } catch (e) {
      print('Error refreshing from server: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
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
          widget.onExport(_filteredRecords.length);
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
    File? selectedImage;
    String? imageUrl = record.imageUrl;
    final ImagePicker imagePicker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickImage(ImageSource source) async {
            try {
              final XFile? pickedFile = await imagePicker.pickImage(
                source: source,
                imageQuality: 80,
              );
              
              if (pickedFile != null) {
                setDialogState(() {
                  selectedImage = File(pickedFile.path);
                  imageUrl = null;
                });
              }
            } catch (e) {
              print('Error picking image: $e');
            }
          }

          void removeImage() {
            setDialogState(() {
              selectedImage = null;
              imageUrl = null;
            });
          }

          void showImagePickerDialog() {
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('选择图片'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('拍照'),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        pickImage(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('从相册选择'),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        pickImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('编辑记录'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
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
                              const Text('图片', style: TextStyle(fontSize: 14)),
                              Row(
                                children: [
                                  if (selectedImage != null || imageUrl != null)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: removeImage,
                                      tooltip: '删除图片',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ElevatedButton.icon(
                                    onPressed: showImagePickerDialog,
                                    icon: const Icon(Icons.add_photo_alternate, size: 16),
                                    label: const Text('选择', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 28),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (selectedImage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  selectedImage!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else if (imageUrl != null && imageUrl!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 150,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                '暂无图片',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showCustomDatePicker(
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
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('确认删除'),
                      content: const Text('确定要删除这条记录吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('取消'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            Navigator.pop(context);
                            widget.onDelete(record.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('记录已删除')),
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('删除'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
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

                  String? finalImageUrl = imageUrl;
                  if (selectedImage != null) {
                    try {
                      finalImageUrl = await ApiService.uploadImage(selectedImage!);
                    } catch (e) {
                      print('Error uploading image: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('图片上传失败: $e')),
                      );
                      return;
                    }
                  }

                  final updatedRecord = Record(
                    id: record.id,
                    date: selectedDate,
                    workContent: workContentController.text,
                    amount: amount,
                    category: categoryController.text,
                    ledger: record.ledger,
                    imageUrl: finalImageUrl,
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
          );
        },
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
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (!_showFilters) {
                          setState(() {
                            _showFilters = true;
                          });
                        }
                      },
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '搜索账目...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixIcon: _searchKeyword.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchKeyword = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchKeyword = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(
                      _showFilters ? Icons.expand_less : Icons.expand_more,
                      color: _showFilters ? Colors.blue : Colors.grey,
                    ),
                    tooltip: '筛选',
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _showFilters ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _toggleCalculateMode,
                          icon: Icon(_isCalculateMode ? Icons.close : Icons.calculate, size: 18),
                          label: Text(_isCalculateMode ? '取消计算' : '选择&计算'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCalculateMode ? Colors.red.shade100 : Colors.blue.shade100,
                            foregroundColor: _isCalculateMode ? Colors.red.shade800 : Colors.blue.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: _exportToExcel,
                          icon: const Icon(Icons.file_download, size: 18),
                          label: const Text('导出'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade100,
                            foregroundColor: Colors.green.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/recycle_bin');
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('回收站'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade100,
                            foregroundColor: Colors.orange.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLedgerSelector(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _showFilters ? _selectStartDate : null,
                            child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              height: 48,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _startDate == null
                                          ? '开始日期'
                                          : DateFormat('dd').format(_startDate!),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  if (_startDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _startDate = null;
                                          _serverRecords = [];
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
                            onTap: _showFilters ? _selectEndDate : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              height: 48,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _endDate == null
                                          ? '结束日期'
                                          : DateFormat('dd').format(_endDate!),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  if (_endDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _endDate = null;
                                          _serverRecords = [];
                                        });
                                        _searchFromServer();
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            height: 48,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                hint: const Text('全部类别'),
                                value: _selectedCategory,
                                itemHeight: 48,
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
                                    _serverRecords = [];
                                  });
                                  _searchFromServer();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isCalculateMode) ...[
                    ],
                  ],
                ),
              ),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '总计:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${_filteredRecords.length} 条账目',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
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
                            child: Column(
                              children: [
                                if (record.imageUrl != null && record.imageUrl!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    child: Image.network(
                                      record.imageUrl!,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 150,
                                          color: Colors.grey.shade200,
                                          child: const Center(
                                            child: Icon(Icons.broken_image, color: Colors.grey),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ListTile(
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
                                    ],
                                  ),
                                ),
                              ],
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
