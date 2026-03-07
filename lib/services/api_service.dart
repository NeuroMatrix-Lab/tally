import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/record.dart';
import '../models/staff.dart';

enum ConnectionMode {
  local,
  backend,
  database,
}

class ApiService {
  static Database? _localDb;

  // 获取当前连接模式
  static Future<ConnectionMode> _getConnectionMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('connectionMode') ?? 0;
    return ConnectionMode.values[modeIndex];
  }

  // 获取后端服务基础URL
  static Future<String> _getBackendBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('backendIp') ?? '';
    final portStr = prefs.getString('backendPort') ?? '7378';
    return 'http://$host:$portStr';
  }

  // 获取数据库连接配置（数据库直通模式）
  static Future<ConnectionSettings> _getDbConnectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('dbHost') ?? '';
    final portStr = prefs.getString('dbPort') ?? '3306';
    final port = int.tryParse(portStr) ?? 3306;
    final user = prefs.getString('dbUser') ?? '';
    final password = prefs.getString('dbPassword') ?? '';
    final dbName = prefs.getString('dbName') ?? '';

    return ConnectionSettings(
      host: host,
      port: port,
      user: user,
      password: password,
      db: dbName,
    );
  }

  // 获取本地SQLite数据库
  static Future<Database> _getLocalDb() async {
    if (_localDb != null) return _localDb!;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'tally.db');

    _localDb = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 创建记录表
        await db.execute('''
          CREATE TABLE records (
            id TEXT PRIMARY KEY,
            record_id TEXT NOT NULL UNIQUE,
            date TEXT NOT NULL,
            category TEXT NOT NULL,
            work_content TEXT NOT NULL,
            amount REAL NOT NULL,
            ledger TEXT NOT NULL,
            image_url TEXT,
            staff_ids TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            deleted_at TEXT DEFAULT NULL
          )
        ''');

        // 创建已删除记录表
        await db.execute('''
          CREATE TABLE deleted_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            record_id TEXT NOT NULL,
            date TEXT NOT NULL,
            category TEXT NOT NULL,
            work_content TEXT NOT NULL,
            amount REAL NOT NULL,
            ledger TEXT NOT NULL,
            image_url TEXT,
            staff_ids TEXT,
            deleted_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // 创建账本表
        await db.execute('''
          CREATE TABLE ledgers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
          )
        ''');

        // 创建人员表
        await db.execute('''
          CREATE TABLE staff (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');

        // 插入默认账本
        await db.insert('ledgers', {'name': '默认账本'});
      },
    );

    return _localDb!;
  }

  // ==================== HTTP API 调用（后端服务模式）====================

  // HTTP GET 请求
  static Future<dynamic> _httpGet(String endpoint) async {
    final baseUrl = await _getBackendBaseUrl();
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // HTTP POST 请求
  static Future<dynamic> _httpPost(String endpoint, dynamic body) async {
    final baseUrl = await _getBackendBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // HTTP PUT 请求
  static Future<dynamic> _httpPut(String endpoint, dynamic body) async {
    final baseUrl = await _getBackendBaseUrl();
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // HTTP DELETE 请求
  static Future<void> _httpDelete(String endpoint) async {
    final baseUrl = await _getBackendBaseUrl();
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // ==================== 记录操作 ====================

  // 获取所有记录
  static Future<List<Record>> getAllRecords() async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _getAllRecordsLocal();
      case ConnectionMode.backend:
        return _getAllRecordsBackend();
      case ConnectionMode.database:
        return _getAllRecordsDatabase();
    }
  }

  static Future<List<Record>> _getAllRecordsLocal() async {
    final db = await _getLocalDb();
    final results = await db.query(
      'records',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC',
    );
    return results.map((row) => _recordFromMap(row)).toList();
  }

  static Future<List<Record>> _getAllRecordsBackend() async {
    final data = await _httpGet('/api/records');
    return (data as List).map((item) => Record.fromMap(item)).toList();
  }

  static Future<List<Record>> _getAllRecordsDatabase() async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query('''
        SELECT * FROM records 
        WHERE deleted_at IS NULL 
        ORDER BY date DESC
      ''');

      return results.map((row) => _recordFromDbRow(row)).toList();
    } finally {
      await conn.close();
    }
  }

  // 获取最近记录
  static Future<List<Record>> getRecentRecords({int months = 3}) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _getRecentRecordsLocal(months);
      case ConnectionMode.backend:
        return _getRecentRecordsBackend(months);
      case ConnectionMode.database:
        return _getRecentRecordsDatabase(months);
    }
  }

  static Future<List<Record>> _getRecentRecordsLocal(int months) async {
    final db = await _getLocalDb();
    final cutoffDate = DateTime.now().subtract(Duration(days: months * 30));
    final results = await db.query(
      'records',
      where: 'deleted_at IS NULL AND date >= ?',
      whereArgs: [cutoffDate.toIso8601String()],
      orderBy: 'date DESC',
    );
    return results.map((row) => _recordFromMap(row)).toList();
  }

  static Future<List<Record>> _getRecentRecordsBackend(int months) async {
    final data = await _httpGet('/api/records/recent?months=$months');
    return (data as List).map((item) => Record.fromMap(item)).toList();
  }

  static Future<List<Record>> _getRecentRecordsDatabase(int months) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query('''
        SELECT * FROM records 
        WHERE deleted_at IS NULL 
        AND date >= DATE_SUB(NOW(), INTERVAL ? MONTH)
        ORDER BY date DESC
      ''', [months]);

      return results.map((row) => _recordFromDbRow(row)).toList();
    } finally {
      await conn.close();
    }
  }

  // 搜索记录
  static Future<List<Record>> searchRecords({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
    String? ledger,
  }) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _searchRecordsLocal(startDate, endDate, category, ledger);
      case ConnectionMode.backend:
        return _searchRecordsBackend(startDate, endDate, category, ledger);
      case ConnectionMode.database:
        return _searchRecordsDatabase(startDate, endDate, category, ledger);
    }
  }

  static Future<List<Record>> _searchRecordsLocal(
    DateTime startDate,
    DateTime endDate,
    String? category,
    String? ledger,
  ) async {
    final db = await _getLocalDb();
    var whereClause = 'deleted_at IS NULL AND date BETWEEN ? AND ?';
    var whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];

    if (category != null) {
      whereClause += ' AND category = ?';
      whereArgs.add(category);
    }
    if (ledger != null) {
      whereClause += ' AND ledger = ?';
      whereArgs.add(ledger);
    }

    final results = await db.query(
      'records',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return results.map((row) => _recordFromMap(row)).toList();
  }

  static Future<List<Record>> _searchRecordsBackend(
    DateTime startDate,
    DateTime endDate,
    String? category,
    String? ledger,
  ) async {
    final data = await _httpPost('/api/records/search', {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'category': category,
      'ledger': ledger,
    });
    return (data as List).map((item) => Record.fromMap(item)).toList();
  }

  static Future<List<Record>> _searchRecordsDatabase(
    DateTime startDate,
    DateTime endDate,
    String? category,
    String? ledger,
  ) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      var query = '''
        SELECT * FROM records 
        WHERE deleted_at IS NULL AND date BETWEEN ? AND ?
      ''';
      var params = [startDate.toIso8601String(), endDate.toIso8601String()];

      if (category != null) {
        query += ' AND category = ?';
        params.add(category);
      }
      if (ledger != null) {
        query += ' AND ledger = ?';
        params.add(ledger);
      }
      query += ' ORDER BY date DESC';

      final results = await conn.query(query, params);
      return results.map((row) => _recordFromDbRow(row)).toList();
    } finally {
      await conn.close();
    }
  }

  // 创建记录
  static Future<Record> createRecord(Record record) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _createRecordLocal(record);
      case ConnectionMode.backend:
        return _createRecordBackend(record);
      case ConnectionMode.database:
        return _createRecordDatabase(record);
    }
  }

  static Future<Record> _createRecordLocal(Record record) async {
    final db = await _getLocalDb();
    await db.insert('records', {
      'id': record.id,
      'record_id': record.id,
      'date': record.date.toIso8601String(),
      'category': record.category,
      'work_content': record.workContent,
      'amount': record.amount,
      'ledger': record.ledger,
      'image_url': record.imageUrl,
      'staff_ids': json.encode(record.staffIds),
    });
    return record;
  }

  static Future<Record> _createRecordBackend(Record record) async {
    final data = await _httpPost('/api/records', {
      'id': record.id,
      'date': record.date.toIso8601String(),
      'category': record.category,
      'workContent': record.workContent,
      'amount': record.amount,
      'ledger': record.ledger,
      'imageUrl': record.imageUrl,
      'staffIds': record.staffIds,
    });
    return Record.fromMap(data);
  }

  static Future<Record> _createRecordDatabase(Record record) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('''
        INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        record.id,
        record.date.toIso8601String(),
        record.category,
        record.workContent,
        record.amount,
        record.ledger,
        record.imageUrl,
        json.encode(record.staffIds),
      ]);
      return record;
    } finally {
      await conn.close();
    }
  }

  // 更新记录
  static Future<Record> updateRecord(Record record) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _updateRecordLocal(record);
      case ConnectionMode.backend:
        return _updateRecordBackend(record);
      case ConnectionMode.database:
        return _updateRecordDatabase(record);
    }
  }

  static Future<Record> _updateRecordLocal(Record record) async {
    final db = await _getLocalDb();
    await db.update(
      'records',
      {
        'date': record.date.toIso8601String(),
        'category': record.category,
        'work_content': record.workContent,
        'amount': record.amount,
        'ledger': record.ledger,
        'image_url': record.imageUrl,
        'staff_ids': json.encode(record.staffIds),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'record_id = ?',
      whereArgs: [record.id],
    );
    return record;
  }

  static Future<Record> _updateRecordBackend(Record record) async {
    final data = await _httpPut('/api/records/${record.id}', {
      'date': record.date.toIso8601String(),
      'category': record.category,
      'workContent': record.workContent,
      'amount': record.amount,
      'ledger': record.ledger,
      'imageUrl': record.imageUrl,
      'staffIds': record.staffIds,
    });
    return Record.fromMap(data);
  }

  static Future<Record> _updateRecordDatabase(Record record) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('''
        UPDATE records 
        SET date = ?, category = ?, work_content = ?, amount = ?, ledger = ?, image_url = ?, staff_ids = ?
        WHERE record_id = ?
      ''', [
        record.date.toIso8601String(),
        record.category,
        record.workContent,
        record.amount,
        record.ledger,
        record.imageUrl,
        json.encode(record.staffIds),
        record.id,
      ]);
      return record;
    } finally {
      await conn.close();
    }
  }

  // 删除记录
  static Future<void> deleteRecord(String recordId) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        await _deleteRecordLocal(recordId);
        break;
      case ConnectionMode.backend:
        await _deleteRecordBackend(recordId);
        break;
      case ConnectionMode.database:
        await _deleteRecordDatabase(recordId);
        break;
    }
  }

  static Future<void> _deleteRecordLocal(String recordId) async {
    final db = await _getLocalDb();
    final record = await db.query(
      'records',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );

    if (record.isNotEmpty) {
      // 插入到deleted_records
      await db.insert('deleted_records', {
        'record_id': record.first['record_id'],
        'date': record.first['date'],
        'category': record.first['category'],
        'work_content': record.first['work_content'],
        'amount': record.first['amount'],
        'ledger': record.first['ledger'],
        'image_url': record.first['image_url'],
        'staff_ids': record.first['staff_ids'],
      });

      // 软删除
      await db.update(
        'records',
        {'deleted_at': DateTime.now().toIso8601String()},
        where: 'record_id = ?',
        whereArgs: [recordId],
      );
    }
  }

  static Future<void> _deleteRecordBackend(String recordId) async {
    await _httpDelete('/api/records/$recordId');
  }

  static Future<void> _deleteRecordDatabase(String recordId) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      // 获取记录
      final results = await conn.query(
        'SELECT * FROM records WHERE record_id = ?',
        [recordId],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        // 插入到deleted_records
        await conn.query('''
          INSERT INTO deleted_records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids, deleted_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ''', [
          row['record_id'],
          row['date'],
          row['category'],
          row['work_content'],
          row['amount'],
          row['ledger'],
          row['image_url'],
          row['staff_ids'],
        ]);

        // 软删除
        await conn.query(
          'UPDATE records SET deleted_at = NOW() WHERE record_id = ?',
          [recordId],
        );
      }
    } finally {
      await conn.close();
    }
  }

  // 获取已删除记录
  static Future<List<Record>> getDeletedRecords() async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _getDeletedRecordsLocal();
      case ConnectionMode.backend:
        return _getDeletedRecordsBackend();
      case ConnectionMode.database:
        return _getDeletedRecordsDatabase();
    }
  }

  static Future<List<Record>> _getDeletedRecordsLocal() async {
    final db = await _getLocalDb();
    final results = await db.query(
      'deleted_records',
      orderBy: 'deleted_at DESC',
    );
    return results.map((row) => _recordFromDeletedMap(row)).toList();
  }

  static Future<List<Record>> _getDeletedRecordsBackend() async {
    final data = await _httpGet('/api/records/deleted');
    return (data as List).map((item) => Record.fromMap(item)).toList();
  }

  static Future<List<Record>> _getDeletedRecordsDatabase() async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query('''
        SELECT * FROM deleted_records 
        ORDER BY deleted_at DESC
      ''');
      return results.map((row) => _recordFromDbRow(row)).toList();
    } finally {
      await conn.close();
    }
  }

  // 恢复已删除记录
  static Future<void> restoreRecord(String recordId) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        await _restoreRecordLocal(recordId);
        break;
      case ConnectionMode.backend:
        await _restoreRecordBackend(recordId);
        break;
      case ConnectionMode.database:
        await _restoreRecordDatabase(recordId);
        break;
    }
  }

  static Future<void> _restoreRecordLocal(String recordId) async {
    final db = await _getLocalDb();
    final deletedRecord = await db.query(
      'deleted_records',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );

    if (deletedRecord.isNotEmpty) {
      // 恢复记录
      await db.insert('records', {
        'id': deletedRecord.first['record_id'],
        'record_id': deletedRecord.first['record_id'],
        'date': deletedRecord.first['date'],
        'category': deletedRecord.first['category'],
        'work_content': deletedRecord.first['work_content'],
        'amount': deletedRecord.first['amount'],
        'ledger': deletedRecord.first['ledger'],
        'image_url': deletedRecord.first['image_url'],
        'staff_ids': deletedRecord.first['staff_ids'],
      });

      // 从deleted_records删除
      await db.delete(
        'deleted_records',
        where: 'record_id = ?',
        whereArgs: [recordId],
      );
    }
  }

  static Future<void> _restoreRecordBackend(String recordId) async {
    await _httpPost('/api/records/$recordId/restore', {});
  }

  static Future<void> _restoreRecordDatabase(String recordId) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query(
        'SELECT * FROM deleted_records WHERE record_id = ?',
        [recordId],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        await conn.query('''
          INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE deleted_at = NULL
        ''', [
          row['record_id'],
          row['date'],
          row['category'],
          row['work_content'],
          row['amount'],
          row['ledger'],
          row['image_url'],
          row['staff_ids'],
        ]);

        await conn.query(
          'DELETE FROM deleted_records WHERE record_id = ?',
          [recordId],
        );
      }
    } finally {
      await conn.close();
    }
  }

  // 永久删除记录
  static Future<void> permanentlyDeleteRecord(String recordId) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        await _permanentlyDeleteRecordLocal(recordId);
        break;
      case ConnectionMode.backend:
        await _permanentlyDeleteRecordBackend(recordId);
        break;
      case ConnectionMode.database:
        await _permanentlyDeleteRecordDatabase(recordId);
        break;
    }
  }

  static Future<void> _permanentlyDeleteRecordLocal(String recordId) async {
    final db = await _getLocalDb();
    await db.delete(
      'deleted_records',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
  }

  static Future<void> _permanentlyDeleteRecordBackend(String recordId) async {
    await _httpDelete('/api/records/$recordId/permanent');
  }

  static Future<void> _permanentlyDeleteRecordDatabase(String recordId) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query(
        'DELETE FROM deleted_records WHERE record_id = ?',
        [recordId],
      );
    } finally {
      await conn.close();
    }
  }

  // ==================== 账本操作 ====================

  static Future<List<String>> getAllLedgers() async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _getAllLedgersLocal();
      case ConnectionMode.backend:
        return _getAllLedgersBackend();
      case ConnectionMode.database:
        return _getAllLedgersDatabase();
    }
  }

  static Future<List<String>> _getAllLedgersLocal() async {
    final db = await _getLocalDb();
    final results = await db.query('ledgers', orderBy: 'name');
    return results.map((row) => row['name'] as String).toList();
  }

  static Future<List<String>> _getAllLedgersBackend() async {
    final data = await _httpGet('/api/ledgers');
    return (data as List).map((item) => item as String).toList();
  }

  static Future<List<String>> _getAllLedgersDatabase() async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query('SELECT name FROM ledgers ORDER BY name');
      return results.map((row) => row['name'] as String).toList();
    } finally {
      await conn.close();
    }
  }

  static Future<List<String>> syncLedgers() async {
    return await getAllLedgers();
  }

  static Future<String> createLedger(String name) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _createLedgerLocal(name);
      case ConnectionMode.backend:
        return _createLedgerBackend(name);
      case ConnectionMode.database:
        return _createLedgerDatabase(name);
    }
  }

  static Future<String> _createLedgerLocal(String name) async {
    final db = await _getLocalDb();
    await db.insert('ledgers', {'name': name});
    return name;
  }

  static Future<String> _createLedgerBackend(String name) async {
    await _httpPost('/api/ledgers', name);
    return name;
  }

  static Future<String> _createLedgerDatabase(String name) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('INSERT INTO ledgers (name) VALUES (?)', [name]);
      return name;
    } finally {
      await conn.close();
    }
  }

  static Future<String> updateLedger(String oldName, String newName) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _updateLedgerLocal(oldName, newName);
      case ConnectionMode.backend:
        return _updateLedgerBackend(oldName, newName);
      case ConnectionMode.database:
        return _updateLedgerDatabase(oldName, newName);
    }
  }

  static Future<String> _updateLedgerLocal(String oldName, String newName) async {
    final db = await _getLocalDb();
    await db.update(
      'ledgers',
      {'name': newName},
      where: 'name = ?',
      whereArgs: [oldName],
    );
    await db.update(
      'records',
      {'ledger': newName},
      where: 'ledger = ?',
      whereArgs: [oldName],
    );
    return newName;
  }

  static Future<String> _updateLedgerBackend(String oldName, String newName) async {
    await _httpPut('/api/ledgers/$oldName', newName);
    return newName;
  }

  static Future<String> _updateLedgerDatabase(String oldName, String newName) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('UPDATE ledgers SET name = ? WHERE name = ?', [newName, oldName]);
      await conn.query('UPDATE records SET ledger = ? WHERE ledger = ?', [newName, oldName]);
      return newName;
    } finally {
      await conn.close();
    }
  }

  static Future<void> deleteLedger(String name) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        await _deleteLedgerLocal(name);
        break;
      case ConnectionMode.backend:
        await _deleteLedgerBackend(name);
        break;
      case ConnectionMode.database:
        await _deleteLedgerDatabase(name);
        break;
    }
  }

  static Future<void> _deleteLedgerLocal(String name) async {
    final db = await _getLocalDb();
    await db.delete(
      'ledgers',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  static Future<void> _deleteLedgerBackend(String name) async {
    await _httpDelete('/api/ledgers/$name');
  }

  static Future<void> _deleteLedgerDatabase(String name) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('DELETE FROM ledgers WHERE name = ?', [name]);
    } finally {
      await conn.close();
    }
  }

  // ==================== 人员操作 ====================

  static Future<List<Staff>> getAllStaff() async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _getAllStaffLocal();
      case ConnectionMode.backend:
        return _getAllStaffBackend();
      case ConnectionMode.database:
        return _getAllStaffDatabase();
    }
  }

  static Future<List<Staff>> _getAllStaffLocal() async {
    final db = await _getLocalDb();
    final results = await db.query('staff', orderBy: 'name');
    return results.map((row) => Staff(
      id: row['id'].toString(),
      name: row['name'] as String,
    )).toList();
  }

  static Future<List<Staff>> _getAllStaffBackend() async {
    final data = await _httpGet('/api/staff');
    return (data as List).map((item) => Staff.fromMap(item)).toList();
  }

  static Future<List<Staff>> _getAllStaffDatabase() async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query('SELECT * FROM staff ORDER BY name');
      return results.map((row) => Staff(
        id: row['id'].toString(),
        name: row['name'] as String,
      )).toList();
    } finally {
      await conn.close();
    }
  }

  static Future<List<Staff>> getStaffList() async {
    return await getAllStaff();
  }

  static Future<Staff> addStaff(Staff staff) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _addStaffLocal(staff);
      case ConnectionMode.backend:
        return _addStaffBackend(staff);
      case ConnectionMode.database:
        return _addStaffDatabase(staff);
    }
  }

  static Future<Staff> _addStaffLocal(Staff staff) async {
    final db = await _getLocalDb();
    final id = await db.insert('staff', {'name': staff.name});
    return Staff(id: id.toString(), name: staff.name);
  }

  static Future<Staff> _addStaffBackend(Staff staff) async {
    final data = await _httpPost('/api/staff', {'name': staff.name});
    return Staff.fromMap(data);
  }

  static Future<Staff> _addStaffDatabase(Staff staff) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final result = await conn.query('INSERT INTO staff (name) VALUES (?)', [staff.name]);
      return Staff(id: result.insertId.toString(), name: staff.name);
    } finally {
      await conn.close();
    }
  }

  static Future<Staff> updateStaff(Staff staff) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _updateStaffLocal(staff);
      case ConnectionMode.backend:
        return _updateStaffBackend(staff);
      case ConnectionMode.database:
        return _updateStaffDatabase(staff);
    }
  }

  static Future<Staff> _updateStaffLocal(Staff staff) async {
    final db = await _getLocalDb();
    await db.update(
      'staff',
      {'name': staff.name},
      where: 'id = ?',
      whereArgs: [int.parse(staff.id)],
    );
    return staff;
  }

  static Future<Staff> _updateStaffBackend(Staff staff) async {
    await _httpPut('/api/staff/${staff.id}', {'name': staff.name});
    return staff;
  }

  static Future<Staff> _updateStaffDatabase(Staff staff) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('UPDATE staff SET name = ? WHERE id = ?', [staff.name, int.parse(staff.id)]);
      return staff;
    } finally {
      await conn.close();
    }
  }

  static Future<void> deleteStaff(String staffId) async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        await _deleteStaffLocal(staffId);
        break;
      case ConnectionMode.backend:
        await _deleteStaffBackend(staffId);
        break;
      case ConnectionMode.database:
        await _deleteStaffDatabase(staffId);
        break;
    }
  }

  static Future<void> _deleteStaffLocal(String staffId) async {
    final db = await _getLocalDb();
    await db.delete(
      'staff',
      where: 'id = ?',
      whereArgs: [int.parse(staffId)],
    );
  }

  static Future<void> _deleteStaffBackend(String staffId) async {
    await _httpDelete('/api/staff/$staffId');
  }

  static Future<void> _deleteStaffDatabase(String staffId) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('DELETE FROM staff WHERE id = ?', [int.parse(staffId)]);
    } finally {
      await conn.close();
    }
  }

  // ==================== 工作内容和类别 ====================

  static Future<List<String>> getWorkContents() async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _getWorkContentsLocal();
      case ConnectionMode.backend:
        return _getWorkContentsBackend();
      case ConnectionMode.database:
        return _getWorkContentsDatabase();
    }
  }

  static Future<List<String>> _getWorkContentsLocal() async {
    final db = await _getLocalDb();
    final results = await db.rawQuery('''
      SELECT DISTINCT work_content FROM records 
      WHERE deleted_at IS NULL 
      ORDER BY work_content
    ''');
    return results.map((row) => row['work_content'] as String).toList();
  }

  static Future<List<String>> _getWorkContentsBackend() async {
    final data = await _httpGet('/api/work-contents');
    return (data as List).map((item) => item as String).toList();
  }

  static Future<List<String>> _getWorkContentsDatabase() async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query('''
        SELECT DISTINCT work_content FROM records 
        WHERE deleted_at IS NULL 
        ORDER BY work_content
      ''');
      return results.map((row) => row['work_content'] as String).toList();
    } finally {
      await conn.close();
    }
  }

  static Future<List<String>> getCategories() async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        return _getCategoriesLocal();
      case ConnectionMode.backend:
        return _getCategoriesBackend();
      case ConnectionMode.database:
        return _getCategoriesDatabase();
    }
  }

  static Future<List<String>> _getCategoriesLocal() async {
    final db = await _getLocalDb();
    final results = await db.rawQuery('''
      SELECT DISTINCT category FROM records 
      WHERE deleted_at IS NULL 
      ORDER BY category
    ''');
    return results.map((row) => row['category'] as String).toList();
  }

  static Future<List<String>> _getCategoriesBackend() async {
    final data = await _httpGet('/api/categories');
    return (data as List).map((item) => item as String).toList();
  }

  static Future<List<String>> _getCategoriesDatabase() async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query('''
        SELECT DISTINCT category FROM records 
        WHERE deleted_at IS NULL 
        ORDER BY category
      ''');
      return results.map((row) => row['category'] as String).toList();
    } finally {
      await conn.close();
    }
  }

  // ==================== 图片上传 ====================

  static Future<String> uploadImage(File imageFile) async {
    // 暂时返回空，后续可以实现实际上传逻辑
    return '';
  }

  // ==================== 辅助方法 ====================

  static Record _recordFromMap(Map<String, dynamic> row) {
    List<String> staffIds = [];
    if (row['staff_ids'] != null) {
      try {
        staffIds = List<String>.from(json.decode(row['staff_ids'] as String));
      } catch (e) {
        staffIds = [];
      }
    }

    return Record.fromMap({
      'id': row['record_id']?.toString() ?? row['id'].toString(),
      'recordId': row['record_id']?.toString() ?? '',
      'date': row['date'],
      'category': row['category'],
      'workContent': row['work_content'],
      'amount': row['amount'],
      'ledger': row['ledger'],
      'imageUrl': row['image_url'],
      'staffIds': staffIds,
    });
  }

  static Record _recordFromDeletedMap(Map<String, dynamic> row) {
    List<String> staffIds = [];
    if (row['staff_ids'] != null) {
      try {
        staffIds = List<String>.from(json.decode(row['staff_ids'] as String));
      } catch (e) {
        staffIds = [];
      }
    }

    return Record.fromMap({
      'id': row['record_id']?.toString() ?? row['id'].toString(),
      'recordId': row['record_id']?.toString() ?? '',
      'date': row['date'],
      'category': row['category'],
      'workContent': row['work_content'],
      'amount': row['amount'],
      'ledger': row['ledger'],
      'imageUrl': row['image_url'],
      'staffIds': staffIds,
    });
  }

  static Record _recordFromDbRow(dynamic row) {
    String dateString;
    if (row['date'] is DateTime) {
      dateString = (row['date'] as DateTime).toIso8601String();
    } else {
      dateString = row['date'].toString();
    }

    double amount;
    if (row['amount'] is double) {
      amount = row['amount'];
    } else if (row['amount'] is int) {
      amount = (row['amount'] as int).toDouble();
    } else {
      amount = double.tryParse(row['amount'].toString()) ?? 0.0;
    }

    List<String> staffIds = [];
    if (row['staff_ids'] != null) {
      try {
        final staffIdsStr = row['staff_ids'].toString();
        if (staffIdsStr.isNotEmpty) {
          staffIds = List<String>.from(json.decode(staffIdsStr));
        }
      } catch (e) {
        staffIds = [];
      }
    }

    return Record.fromMap({
      'id': row['record_id']?.toString() ?? row['id'].toString(),
      'recordId': row['record_id']?.toString() ?? '',
      'date': dateString,
      'category': row['category']?.toString() ?? '',
      'workContent': row['work_content']?.toString() ?? '',
      'amount': amount,
      'ledger': row['ledger']?.toString() ?? '',
      'imageUrl': row['image_url']?.toString(),
      'staffIds': staffIds,
    });
  }

  // 恢复已删除记录（别名方法，与main.dart中的调用匹配）
  static Future<void> restoreDeletedRecord(String recordId) async {
    return await restoreRecord(recordId);
  }
}
