import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/record.dart';
import 'models/operation_log.dart';
import 'models/staff.dart';
import 'pages/add_record_page.dart';
import 'pages/view_records_page.dart';
import 'pages/operation_log_page.dart';
import 'pages/recycle_bin_page.dart';
import 'pages/account_check_page.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账软件',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'MiSans',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'MiSans',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
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
  bool _isSyncing = false;
  bool _isServerConnected = false;
  List<Staff> _staffList = [];

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
    _loadStaffList();
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
      final staffList = await ApiService.getStaffList();
      setState(() {
        _staffList = staffList;
      });
    } catch (e) {
      print('Error syncing staff list: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _syncFromServer() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
    });
    
    try {
      // 先测试连接状态
      await _testServerConnection();
      
      final records = await ApiService.getRecentRecords(months: 3);
      final ledgers = await ApiService.syncLedgers();
      if (mounted) {
        setState(() {
          _records = records;
          _ledgers.clear();
          _ledgers.addAll(ledgers);
          if (!_ledgers.contains(_defaultLedger) && _ledgers.isNotEmpty) {
            _defaultLedger = _ledgers.first;
          }
          _isSyncing = false;
          _isServerConnected = true;
        });
        _saveRecords();
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
  
  // 测试服务器连接状态
  Future<void> _testServerConnection() async {
    try {
      // 简单的连接测试
      await ApiService.syncLedgers().timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _isServerConnected = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isServerConnected = false;
        });
      }
      throw e;
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

  void _addRecord(DateTime date, String workContent, double amount, String category, List<String> staffIds, {String? imageUrl}) async {
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
    _addOperationLog('添加', '添加记录', details: '工作内容: $workContent, 金额: ¥$amount, 类别: $category');
    
    try {
      await ApiService.createRecord(newRecord);
      await _syncFromServer();
    } catch (e) {
      print('Error creating record on server: $e');
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
    _addOperationLog('删除', '删除记录', details: '工作内容: ${record.workContent}, 金额: ¥${record.amount}, 类别: ${record.category}');
    
    try {
      await ApiService.deleteRecord(record.id);
      await _syncFromServer();
    } catch (e) {
      print('Error deleting record on server: $e');
    }
  }

  void _updateRecord(Record updatedRecord) async {
    // 先更新本地状态
    setState(() {
      final index = _records.indexWhere((record) => record.id == updatedRecord.id);
      if (index != -1) {
        _records[index] = updatedRecord;
      }
    });
    _saveRecords();
    _addOperationLog('编辑', '编辑记录', details: '工作内容: ${updatedRecord.workContent}, 金额: ¥${updatedRecord.amount}, 类别: ${updatedRecord.category}');
    
    // 尝试上传到服务器
    try {
      print('🔄 开始上传修改的记录到服务器...');
      await ApiService.updateRecord(updatedRecord);
      print('✅ 记录上传成功');
      
      // 重新同步服务器数据
      await _syncFromServer();
      
      // 显示成功消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 记录已更新并同步到服务器'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ 记录上传失败: $e');
      
      // 显示错误消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 记录更新失败: ${e.toString().split(':').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            else
              GestureDetector(
                onTap: _syncFromServer,
                child: Icon(
                  _isServerConnected ? Icons.cloud_done : Icons.cloud_off,
                  size: 20,
                  color: _isServerConnected ? Colors.green : Colors.red,
                ),
              ),
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
                  _ledgers.clear();
                  _ledgers.addAll(updatedLedgers);
                  if (!_ledgers.contains(_defaultLedger) && _ledgers.isNotEmpty) {
                    _defaultLedger = _ledgers.first;
                  }
                });
                _saveRecords();
              },
              staffList: _staffList,
              onStaffListUpdated: _syncStaffList,
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
            ),
          ),
          RepaintBoundary(
            child: OperationLogPage(
              operationLogs: _operationLogs,
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
