import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/operation_log.dart';
import '../models/record.dart';
import '../models/staff.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'account_check_page.dart';
import 'add_record_page.dart';
import 'operation_log_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  /// 供回收站路由取数据/恢复回调。
  static HomePageState? state;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  List<Record> _records = [];
  List<Record> _deletedRecords = [];
  List<OperationLog> _operationLogs = [];
  late PageController _pageController;
  String _defaultLedger = '默认账本';
  final List<String> _ledgers = ['默认账本'];
  bool _isSyncing = false;
  bool _isServerConnected = false;
  List<Staff> _staffList = [];

  List<Record> get deletedRecords => _deletedRecords;

  List<String> get _categories {
    final categories = _records.map((r) => r.category).toSet().toList();
    categories.sort();
    return categories;
  }

  List<String> get _workContents {
    final contents = _records.map((r) => r.workContent).toSet().toList();
    contents.sort();
    return contents;
  }

  @override
  void initState() {
    super.initState();
    HomePage.state = this;
    _pageController = PageController();
    _loadRecords();
    _loadStaffList();
    _initSync();
  }

  Future<void> _initSync() async {
    ApiService.syncStream.listen((shouldSync) {
      if (!mounted) return;
      setState(() {
        _isServerConnected = shouldSync;
      });
      if (shouldSync) {
        _loadRecords();
        _loadStaffList();
      }
    });

    ApiService.syncCompletedStream.listen((_) {
      if (!mounted) return;
      _loadRecords();
      _loadStaffList();
    });

    ApiService.connectWebSocket();
  }

  @override
  void dispose() {
    if (HomePage.state == this) {
      HomePage.state = null;
    }
    _pageController.dispose();
    ApiService.dispose();
    super.dispose();
  }

  Future<void> _loadStaffList() async {
    try {
      final staffList = await ApiService.getStaffList();
      setState(() {
        _staffList = staffList;
      });
    } catch (e) {
      print('Error loading staff list: $e');
    }
  }

  Future<void> _syncStaffList() async {
    try {
      final updatedStaffList = await ApiService.getStaffList();
      setState(() {
        _staffList = updatedStaffList;
      });
    } catch (e) {
      print('Error syncing staff list: $e');
    }
  }

  Future<void> _syncFromServer() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      await ApiService.performIncrementalSync();
      final records = await ApiService.getRecentRecords(months: 3);
      final ledgers = await ApiService.syncLedgers();
      final staffList = await ApiService.getStaffList();

      if (mounted) {
        setState(() {
          _records = records;
          _staffList = staffList;
          _ledgers
            ..clear()
            ..addAll(ledgers);
          if (!_ledgers.contains(_defaultLedger) && _ledgers.isNotEmpty) {
            _defaultLedger = _ledgers.first;
          }
          _isSyncing = false;
          _isServerConnected = true;
        });
        _saveRecords();
      }
    } catch (e) {
      print('Sync error: $e');
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _isServerConnected = false;
        });
      }
    }
  }

  Future<void> _loadRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      try {
        final records = await ApiService.getRecentRecords(months: 3);
        setState(() {
          _records = records;
          _isServerConnected = true;
        });
      } catch (e) {
        print('Error loading records from server: $e');
        setState(() {
          _isServerConnected = false;
          _records = [];
        });
      }

      try {
        final ledgers = await ApiService.syncLedgers();
        setState(() {
          _ledgers
            ..clear()
            ..addAll(ledgers);
          if (!_ledgers.contains(_defaultLedger) && _ledgers.isNotEmpty) {
            _defaultLedger = _ledgers.first;
          }
        });
      } catch (e) {
        print('Error syncing ledgers from server: $e');
      }

      try {
        final deletedRecords = await ApiService.getDeletedRecords();
        setState(() {
          _deletedRecords = deletedRecords;
        });
      } catch (e) {
        print('Error loading deleted records from server: $e');
        setState(() {
          _deletedRecords = [];
        });
      }

      final operationLogsJson = prefs.getString('operationLogs');
      if (operationLogsJson != null) {
        final List<dynamic> decoded = json.decode(operationLogsJson);
        setState(() {
          _operationLogs =
              decoded.map((item) => OperationLog.fromMap(item)).toList();
        });
      }
    } catch (e) {
      print('Error loading records: $e');
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = json.encode(_records.map((r) => r.toMap()).toList());
    await prefs.setString('records', recordsJson);
    final operationLogsJson = json.encode(
      _operationLogs.map((log) => log.toMap()).toList(),
    );
    await prefs.setString('operationLogs', operationLogsJson);
    final ledgersJson = json.encode(_ledgers);
    await prefs.setString('ledgers', ledgersJson);
  }

  void _addOperationLog(String type, String description, {String? details}) {
    final log = OperationLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: type,
      description: description,
      details: details,
    );
    setState(() {
      _operationLogs.insert(0, log);
      if (_operationLogs.length > 1000) {
        _operationLogs = _operationLogs.sublist(0, 1000);
      }
    });
    _saveRecords();
  }

  void _addRecord(
    DateTime date,
    String workContent,
    double amount,
    String category,
    List<String> staffIds, {
    String? imageUrl,
  }) async {
    final newRecord = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date,
      workContent: workContent,
      amount: amount,
      category: category,
      ledger: _defaultLedger,
      imageUrl: imageUrl,
      staffIds: staffIds,
    );
    setState(() {
      _records.add(newRecord);
    });
    _saveRecords();
    _addOperationLog(
      '添加',
      '添加记录',
      details: '工作内容: $workContent, 金额: ¥$amount, 类别: $category',
    );

    try {
      await ApiService.createRecord(newRecord);
    } catch (e) {
      print('Error creating record on server: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _deleteRecord(Record record) async {
    setState(() {
      _records.removeWhere((r) => r.id == record.id);
      _deletedRecords.insert(0, record);
      if (_deletedRecords.length > 300) {
        _deletedRecords = _deletedRecords.sublist(0, 300);
      }
    });
    _saveRecords();
    _addOperationLog(
      '删除',
      '删除记录',
      details:
          '工作内容: ${record.workContent}, 金额: ¥${record.amount}, 类别: ${record.category}',
    );

    try {
      await ApiService.deleteRecord(record.id);
    } catch (e) {
      print('Error deleting record on server: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除同步失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _updateRecord(Record updatedRecord) async {
    setState(() {
      final index = _records.indexWhere((record) => record.id == updatedRecord.id);
      if (index != -1) {
        _records[index] = updatedRecord;
      }
    });
    _saveRecords();
    _addOperationLog(
      '编辑',
      '编辑记录',
      details:
          '工作内容: ${updatedRecord.workContent}, 金额: ¥${updatedRecord.amount}, 类别: ${updatedRecord.category}, 人员: ${updatedRecord.staffIds.length}人',
    );

    try {
      await ApiService.updateRecord(updatedRecord);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ 记录已更新并同步到服务器'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 记录更新失败: ${e.toString().split(':').first}'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  void restoreFromRecycleBin(Record record) async {
    try {
      await ApiService.restoreDeletedRecord(record.id);
      setState(() {
        _deletedRecords.removeWhere((r) => r.id == record.id);
        _records.add(record);
      });
      _saveRecords();
      _addOperationLog(
        '恢复',
        '恢复记录',
        details:
            '工作内容: ${record.workContent}, 金额: ¥${record.amount}, 类别: ${record.category}',
      );
    } catch (e) {
      print('Error restoring record from server: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          RepaintBoundary(
            child: AddRecordPage(
              onAdd: _addRecord,
              categories: _categories,
              workContents: _workContents,
              ledgers: _ledgers,
              defaultLedger: _defaultLedger,
              onLedgerChanged: (ledger) {
                setState(() {
                  _defaultLedger = ledger;
                });
                _saveRecords();
              },
              onAddLedger: (ledger) {
                setState(() {
                  if (!_ledgers.contains(ledger)) {
                    _ledgers.add(ledger);
                    _defaultLedger = ledger;
                  }
                });
                _saveRecords();
              },
              onLedgersUpdated: (updatedLedgers) {
                setState(() {
                  _ledgers
                    ..clear()
                    ..addAll(updatedLedgers);
                  if (!_ledgers.contains(_defaultLedger) &&
                      _ledgers.isNotEmpty) {
                    _defaultLedger = _ledgers.first;
                  }
                });
                _saveRecords();
              },
              staffList: _staffList,
              onStaffListUpdated: _syncStaffList,
              isSyncing: _isSyncing,
              isServerConnected: _isServerConnected,
              onSync: _syncFromServer,
            ),
          ),
          RepaintBoundary(
            child: AccountCheckPage(
              records: _records,
              staffList: _staffList,
              ledgers: _ledgers,
              defaultLedger: _defaultLedger,
              onLedgerChanged: (ledger) {
                setState(() {
                  _defaultLedger = ledger;
                });
                _saveRecords();
              },
              onUpdate: _updateRecord,
              onDelete: _deleteRecord,
              isSyncing: _isSyncing,
              isServerConnected: _isServerConnected,
              onSync: _syncFromServer,
            ),
          ),
          RepaintBoundary(
            child: OperationLogPage(
              operationLogs: _operationLogs,
              isSyncing: _isSyncing,
              isServerConnected: _isServerConnected,
              onSync: _syncFromServer,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: '记账',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '查账'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '操作记录'),
        ],
      ),
    );
  }
}
