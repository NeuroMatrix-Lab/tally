import 'dart:convert';
import 'package:mysql1/mysql1.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/record.dart';
import '../models/staff.dart';

enum ConnectionMode {
  local,
  backend,
  database,
}

class DatabaseService {
  // 获取当前连接模式
  static Future<ConnectionMode> _getConnectionMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('connectionMode') ?? 0;
    return ConnectionMode.values[modeIndex];
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

  // 获取数据库连接
  static Future<MySqlConnection> _getConnection() async {
    final mode = await _getConnectionMode();

    switch (mode) {
      case ConnectionMode.local:
        throw Exception('本地模式不支持直接数据库连接');
      case ConnectionMode.backend:
        throw Exception('后端服务模式请使用HTTP API');
      case ConnectionMode.database:
        final settings = await _getDbConnectionSettings();
        return await MySqlConnection.connect(settings);
    }
  }

  // 检查当前模式是否支持数据库操作
  static Future<bool> _isDatabaseMode() async {
    final mode = await _getConnectionMode();
    return mode == ConnectionMode.database;
  }

  // 获取所有记录
  static Future<List<Record>> getAllRecords() async {
    if (!await _isDatabaseMode()) {
      throw Exception('当前模式不支持此操作');
    }

    final conn = await _getConnection();
    try {
      final results = await conn.query('''
        SELECT * FROM records 
        WHERE deleted_at IS NULL 
        ORDER BY date DESC
      ''');

      return results.map((row) => Record.fromMap({
        'id': row['id'],
        'recordId': row['record_id'],
        'date': row['date'].toString(),
        'category': row['category'],
        'workContent': row['work_content'],
        'amount': row['amount'],
        'ledger': row['ledger'],
        'imageUrl': row['image_url'],
        'staffIds': row['staff_ids'],
      })).toList();
    } finally {
      await conn.close();
    }
  }

  // 添加记录
  static Future<Record> addRecord(Record record) async {
    if (!await _isDatabaseMode()) {
      throw Exception('当前模式不支持此操作');
    }

    final conn = await _getConnection();
    try {
      final result = await conn.query('''
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
    if (!await _isDatabaseMode()) {
      throw Exception('当前模式不支持此操作');
    }

    final conn = await _getConnection();
    try {
      await conn.query('''
        UPDATE records 
        SET date = ?, category = ?, work_content = ?, amount = ?, ledger = ?, image_url = ?, staff_ids = ?
        WHERE id = ?
      ''', [
        record.date.toIso8601String(),
        record.category,
        record.workContent,
        record.amount,
        record.ledger,
        record.imageUrl,
        json.encode(record.staffIds),
        int.parse(record.id),
      ]);

      return record;
    } finally {
      await conn.close();
    }
  }

  // 删除记录（软删除）
  static Future<void> deleteRecord(String recordId) async {
    if (!await _isDatabaseMode()) {
      throw Exception('当前模式不支持此操作');
    }

    final conn = await _getConnection();
    try {
      await conn.query('''
        UPDATE records SET deleted_at = NOW() WHERE id = ?
      ''', [int.parse(recordId)]);
    } finally {
      await conn.close();
    }
  }

  // 获取所有账本
  static Future<List<String>> getAllLedgers() async {
    if (!await _isDatabaseMode()) {
      throw Exception('当前模式不支持此操作');
    }

    final conn = await _getConnection();
    try {
      final results = await conn.query('SELECT name FROM ledgers ORDER BY name');
      return results.map((row) => row['name'] as String).toList();
    } finally {
      await conn.close();
    }
  }

  // 添加账本
  static Future<String> addLedger(String name) async {
    if (!await _isDatabaseMode()) {
      throw Exception('当前模式不支持此操作');
    }

    final conn = await _getConnection();
    try {
      await conn.query('INSERT INTO ledgers (name) VALUES (?)', [name]);
      return name;
    } finally {
      await conn.close();
    }
  }

  // 获取所有人员
  static Future<List<Staff>> getAllStaff() async {
    if (!await _isDatabaseMode()) {
      throw Exception('当前模式不支持此操作');
    }

    final conn = await _getConnection();
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

  // 添加人员
  static Future<Staff> addStaff(Staff staff) async {
    if (!await _isDatabaseMode()) {
      throw Exception('当前模式不支持此操作');
    }

    final conn = await _getConnection();
    try {
      final result = await conn.query('INSERT INTO staff (name) VALUES (?)', [staff.name]);
      return Staff(
        id: result.insertId.toString(),
        name: staff.name,
      );
    } finally {
      await conn.close();
    }
  }

  // 获取工作内容列表
  static Future<List<String>> getWorkContents() async {
    if (!await _isDatabaseMode()) {
      throw Exception('当前模式不支持此操作');
    }

    final conn = await _getConnection();
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

  // 获取类别列表
  static Future<List<String>> getCategories() async {
    if (!await _isDatabaseMode()) {
      throw Exception('当前模式不支持此操作');
    }

    final conn = await _getConnection();
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
}
