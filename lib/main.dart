import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/record.dart';
import 'pages/add_record_page.dart';
import 'pages/view_records_page.dart';

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
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  List<Record> _records = [];
  List<Record> _deletedRecords = [];
  final List<String> _pageTitles = ['记账', '查账'];
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
    _pageController = PageController();
    _loadRecords();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getString('records');
    if (recordsJson != null) {
      final List<dynamic> decoded = json.decode(recordsJson);
      setState(() {
        _records = decoded.map((item) => Record.fromMap(item)).toList();
      });
    }
    final deletedRecordsJson = prefs.getString('deletedRecords');
    if (deletedRecordsJson != null) {
      final List<dynamic> decoded = json.decode(deletedRecordsJson);
      setState(() {
        _deletedRecords = decoded.map((item) => Record.fromMap(item)).toList();
      });
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = json.encode(_records.map((r) => r.toMap()).toList());
    await prefs.setString('records', recordsJson);
    final deletedRecordsJson = json.encode(_deletedRecords.map((r) => r.toMap()).toList());
    await prefs.setString('deletedRecords', deletedRecordsJson);
  }

  void _addRecord(DateTime date, String workContent, double amount, String category) {
    final newRecord = Record(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date,
      workContent: workContent,
      amount: amount,
      category: category,
    );
    setState(() {
      _records.add(newRecord);
    });
    _saveRecords();
  }

  void _deleteRecord(String id) {
    final recordToDelete = _records.firstWhere((record) => record.id == id, orElse: () => Record(id: '', date: DateTime.now(), workContent: '', amount: 0, category: ''));
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
  }

  void _updateRecord(Record updatedRecord) {
    setState(() {
      final index = _records.indexWhere((record) => record.id == updatedRecord.id);
      if (index != -1) {
        _records[index] = updatedRecord;
      }
    });
    _saveRecords();
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
        ],
      ),
    );
  }
}
