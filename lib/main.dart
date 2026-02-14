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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      try {
        final records = await ApiService.getRecentRecords(months: 3);
        setState(() {
          _records = records;
        });
      } catch (e) {
        print('Error loading records from server: $e');
        final recordsJson = prefs.getString('records');
        if (recordsJson != null) {
          final List<dynamic> decoded = json.decode(recordsJson);
          setState(() {
            _records = decoded.map((item) => Record.fromMap(item)).toList();
          });
        }
      }
      
      final deletedRecordsJson = prefs.getString('deletedRecords');
      if (deletedRecordsJson != null) {
        final List<dynamic> decoded = json.decode(deletedRecordsJson);
        setState(() {
          _deletedRecords = decoded.map((item) => Record.fromMap(item)).toList();
        });
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
    final deletedRecordsJson = json.encode(_deletedRecords.map((r) => r.toMap()).toList());
    await prefs.setString('deletedRecords', deletedRecordsJson);
    final operationLogsJson = json.encode(_operationLogs.map((log) => log.toMap()).toList());
    await prefs.setString('operationLogs', operationLogsJson);
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

  void _addRecord(DateTime date, String workContent, double amount, String category) {
    final newRecord = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date,
      workContent: workContent,
      amount: amount,
      category: category,
      ledger: _defaultLedger,
    );
    setState(() {
      _records.add(newRecord);
    });
    _saveRecords();
    _addOperationLog('添加', '添加记录', details: '工作内容: $workContent, 金额: ¥$amount, 类别: $category');
    
    ApiService.createRecord(newRecord).catchError((e) {
      print('Error creating record on server: $e');
      throw e;
    });
  }

  void _deleteRecord(String id) {
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
    
    ApiService.deleteRecord(id).catchError((e) {
      print('Error deleting record on server: $e');
    });
  }

  void _updateRecord(Record updatedRecord) {
    setState(() {
      final index = _records.indexWhere((record) => record.id == updatedRecord.id);
      if (index != -1) {
        _records[index] = updatedRecord;
      }
    });
    _saveRecords();
    _addOperationLog('编辑', '编辑记录', details: '工作内容: ${updatedRecord.workContent}, 金额: ¥${updatedRecord.amount}, 类别: ${updatedRecord.category}');
    
    ApiService.updateRecord(updatedRecord).catchError((e) {
      print('Error updating record on server: $e');
      throw e;
    });
  }

  void _restoreFromRecycleBin(Record record) {
    setState(() {
      _deletedRecords.removeWhere((r) => r.id == record.id);
      _records.add(record);
    });
    _saveRecords();
    _addOperationLog('恢复', '恢复记录', details: '工作内容: ${record.workContent}, 金额: ¥${record.amount}, 类别: ${record.category}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_pageTitles[_currentIndex]),
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
