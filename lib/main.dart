import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/record.dart';
import 'models/operation_log.dart';
import 'pages/add_record_page.dart';
import 'pages/view_records_page.dart';
import 'pages/operation_log_page.dart';
import 'pages/recycle_bin_page.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账软件',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'MiSans',
      ),
      home: const HomePage(),
      routes: {
        '/recycle_bin': (context) => RecycleBinPage(
          deletedRecords: _HomePageState._instance?._deletedRecords ?? [],
          onRestore: (record) {
            _HomePageState._instance?._restoreFromRecycleBin(record);
          },
          onClose: () {
            Navigator.pop(context);
          },
        ),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static _HomePageState? _instance;
  int _currentIndex = 0;
  List<Record> _records = [];
  List<Record> _deletedRecords = [];
  List<OperationLog> _operationLogs = [];
  final List<String> _pageTitles = ['记账', '查账', '操作记录'];
  late PageController _pageController;
  String _defaultLedger = '默认账本';
  final List<String> _ledgers = ['默认账本'];
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isServerConnected = false;

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
    _instance = this;
    _pageController = PageController();
    _loadRecords();
    _startAutoSync();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _syncFromServer();
    });
  }

  Future<void> _syncFromServer() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
    });

    try {
      final records = await ApiService.getRecentRecords(months: 3);
      if (mounted) {
        setState(() {
          _records = records;
          _isSyncing = false;
          _isServerConnected = true;
        });
      }
    } catch (e) {
      print('Error syncing from server: $e');
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
        });
        final recordsJson = prefs.getString('records');
        if (recordsJson != null) {
          final List<dynamic> decoded = json.decode(recordsJson);
          setState(() {
            _records = decoded.map((item) => Record.fromMap(item)).toList();
          });
        }
      }
      
      try {
        final ledgers = await ApiService.syncLedgers();
        final ledgersJson = prefs.getString('ledgers');
        if (ledgersJson != null) {
          final List<dynamic> decoded = json.decode(ledgersJson);
          final localLedgers = decoded.map((item) => item.toString()).toList();
          for (final ledger in localLedgers) {
            if (!ledgers.contains(ledger)) {
              ledgers.add(ledger);
            }
          }
        }
        setState(() {
          _ledgers.clear();
          _ledgers.addAll(ledgers);
          if (!_ledgers.contains(_defaultLedger) && _ledgers.isNotEmpty) {
            _defaultLedger = _ledgers.first;
          }
        });
      } catch (e) {
        print('Error syncing ledgers from server: $e');
        final ledgersJson = prefs.getString('ledgers');
        if (ledgersJson != null) {
          final List<dynamic> decoded = json.decode(ledgersJson);
          setState(() {
            _ledgers.clear();
            _ledgers.addAll(decoded.map((item) => item.toString()));
          });
        }
      }
      
      try {
        final deletedRecords = await ApiService.getDeletedRecords();
        setState(() {
          _deletedRecords = deletedRecords;
        });
      } catch (e) {
        print('Error loading deleted records from server: $e');
        final deletedRecordsJson = prefs.getString('deletedRecords');
        if (deletedRecordsJson != null) {
          final List<dynamic> decoded = json.decode(deletedRecordsJson);
          setState(() {
            _deletedRecords = decoded.map((item) => Record.fromMap(item)).toList();
          });
        }
      }
      
      final operationLogsJson = prefs.getString('operationLogs');
      if (operationLogsJson != null) {
        final List<dynamic> decoded = json.decode(operationLogsJson);
        setState(() {
          _operationLogs = decoded.map((item) => OperationLog.fromMap(item)).toList();
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
    final operationLogsJson = json.encode(_operationLogs.map((log) => log.toMap()).toList());
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

  void _addRecord(DateTime date, String workContent, double amount, String category, {String? imageUrl}) async {
    final newRecord = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date,
      workContent: workContent,
      amount: amount,
      category: category,
      ledger: _defaultLedger,
      imageUrl: imageUrl,
    );
    setState(() {
      _records.add(newRecord);
    });
    _saveRecords();
    _addOperationLog('添加', '添加记录', details: '工作内容: $workContent, 金额: ¥$amount, 类别: $category');
    
    try {
      await ApiService.createRecord(newRecord);
      await _syncFromServer();
    } catch (e) {
      print('Error creating record on server: $e');
    }
  }

  void _deleteRecord(String id) async {
    final recordToDelete = _records.firstWhere((record) => record.id == id, orElse: () => Record(id: '', date: DateTime.now(), workContent: '', amount: 0, category: '', ledger: ''));
    setState(() {
      _records.removeWhere((record) => record.id == id);
      if (recordToDelete.id.isNotEmpty) {
        _deletedRecords.insert(0, recordToDelete);
        if (_deletedRecords.length > 300) {
          _deletedRecords = _deletedRecords.sublist(0, 300);
        }
      }
    });
    _saveRecords();
    _addOperationLog('删除', '删除记录', details: '工作内容: ${recordToDelete.workContent}, 金额: ¥${recordToDelete.amount}, 类别: ${recordToDelete.category}');
    
    try {
      await ApiService.deleteRecord(id);
      await _syncFromServer();
    } catch (e) {
      print('Error deleting record on server: $e');
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
    _addOperationLog('编辑', '编辑记录', details: '工作内容: ${updatedRecord.workContent}, 金额: ¥${updatedRecord.amount}, 类别: ${updatedRecord.category}');
    
    try {
      await ApiService.updateRecord(updatedRecord);
      await _syncFromServer();
    } catch (e) {
      print('Error updating record on server: $e');
    }
  }

  void _restoreFromRecycleBin(Record record) async {
    try {
      await ApiService.restoreDeletedRecord(record.id);
      setState(() {
        _deletedRecords.removeWhere((r) => r.id == record.id);
        _records.add(record);
      });
      _saveRecords();
      _addOperationLog('恢复', '恢复记录', details: '工作内容: ${record.workContent}, 金额: ¥${record.amount}, 类别: ${record.category}');
      await _syncFromServer();
    } catch (e) {
      print('Error restoring record on server: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          children: [
            Text(_pageTitles[_currentIndex]),
            const SizedBox(width: 8),
            if (_isSyncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else if (_isServerConnected)
              const Icon(Icons.cloud_done, size: 20, color: Colors.green)
            else
              const Icon(Icons.cloud_off, size: 20, color: Colors.red),
          ],
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          AddRecordPage(
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
                _ledgers.clear();
                _ledgers.addAll(updatedLedgers);
                if (!_ledgers.contains(_defaultLedger) && _ledgers.isNotEmpty) {
                  _defaultLedger = _ledgers.first;
                }
              });
              _saveRecords();
            },
          ),
          ViewRecordsPage(
            records: _records,
            deletedRecords: _deletedRecords,
            onDelete: _deleteRecord,
            onUpdate: _updateRecord,
            onRestore: (record) {
              setState(() {
                _deletedRecords.removeWhere((r) => r.id == record.id);
                _records.add(record);
              });
              _saveRecords();
              _addOperationLog('恢复', '恢复记录', details: '工作内容: ${record.workContent}, 金额: ¥${record.amount}, 类别: ${record.category}');
            },
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
                _ledgers.clear();
                _ledgers.addAll(updatedLedgers);
                if (!_ledgers.contains(_defaultLedger) && _ledgers.isNotEmpty) {
                  _defaultLedger = _ledgers.first;
                }
              });
              _saveRecords();
            },
            onExport: (count) {
              _addOperationLog('导出', '导出账目记录', details: '导出了$count条记录');
            },
          ),
          OperationLogPage(
            operationLogs: _operationLogs,
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
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: '查账',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '操作记录',
          ),
        ],
      ),
    );
  }
}
