import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysql1/mysql1.dart';
import '../models/record.dart';
import '../models/staff.dart';

class ApiService {
  // 数据库连接配置
  static Future<ConnectionSettings> _getDbSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Docker容器数据库连接配置
    final serverIp = prefs.getString('serverIp') ?? '120.220.73.186'; // 您的服务器IP
    final dbPort = prefs.getInt('dbPort') ?? 7378;
    final dbUser = prefs.getString('dbUser') ?? 'tally_user';
    final dbPassword = prefs.getString('dbPassword') ?? 'tally_password';
    final dbName = prefs.getString('dbName') ?? 'tally_db';
    
    return ConnectionSettings(
      host: serverIp,
      port: dbPort,
      user: dbUser,
      password: dbPassword,
      db: dbName,
    );
  }

  // 获取数据库连接
  static Future<MySqlConnection> _getConnection() async {
    final settings = await _getDbSettings();
    return await MySqlConnection.connect(settings);
  }

  // 获取所有记录
  static Future<List<Record>> getAllRecords() async {
    final conn = await _getConnection();
    try {
      final results = await conn.query('''
        SELECT * FROM records 
        WHERE deleted_at IS NULL 
        ORDER BY date DESC
      ''');
      
      return results.map((row) {
        // 调试输出，查看实际的数据类型
        print('🔍 数据库返回的行数据: $row');
        
        // 处理日期字段 - 可能是字符串或DateTime
        String dateString;
        if (row['date'] is DateTime) {
          dateString = (row['date'] as DateTime).toIso8601String();
        } else if (row['date'] is String) {
          // 如果是MySQL格式的字符串，需要转换为ISO格式
          final mysqlDate = row['date'] as String;
          try {
            // 尝试解析MySQL格式 (YYYY-MM-DD HH:MM:SS)
            final parts = mysqlDate.split(' ');
            if (parts.length == 2) {
              final datePart = parts[0];
              final timePart = parts[1];
              dateString = '${datePart}T${timePart}Z';
            } else {
              dateString = mysqlDate;
            }
          } catch (e) {
            dateString = DateTime.now().toIso8601String();
          }
        } else {
          dateString = DateTime.now().toIso8601String();
        }
        
        // 处理金额字段
        double amountValue;
        if (row['amount'] is double) {
          amountValue = row['amount'];
        } else if (row['amount'] is int) {
          amountValue = (row['amount'] as int).toDouble();
        } else if (row['amount'] is String) {
          amountValue = double.tryParse(row['amount']) ?? 0.0;
        } else {
          amountValue = 0.0;
        }
        
        // 处理staff_ids字段
        List<String> staffIds = [];
        if (row['staff_ids'] != null) {
          if (row['staff_ids'] is String) {
            try {
              staffIds = List<String>.from(json.decode(row['staff_ids']));
            } catch (e) {
              print('❌ JSON解析失败: $e');
              staffIds = [];
            }
          } else if (row['staff_ids'] is List) {
            staffIds = List<String>.from(row['staff_ids']);
          }
        }
        
        return Record.fromMap({
          'id': row['id'].toString(),
          'recordId': row['record_id']?.toString() ?? '',
          'date': dateString,
          'category': row['category']?.toString() ?? '其他',
          'workContent': row['work_content']?.toString() ?? '',
          'amount': amountValue,
          'ledger': row['ledger']?.toString() ?? '默认账本',
          'imageUrl': row['image_url']?.toString(),
          'staffIds': staffIds,
        });
      }).toList();
    } finally {
      await conn.close();
    }
  }

  // 获取最近记录
  static Future<List<Record>> getRecentRecords({int months = 3}) async {
    final conn = await _getConnection();
    try {
      final results = await conn.query('''
        SELECT * FROM records 
        WHERE deleted_at IS NULL 
        AND date >= DATE_SUB(NOW(), INTERVAL ? MONTH)
        ORDER BY date DESC
      ''', [months]);
      
      return results.map((row) {
        // 处理日期字段 - 可能是字符串或DateTime
        String dateString;
        if (row['date'] is DateTime) {
          dateString = (row['date'] as DateTime).toIso8601String();
        } else if (row['date'] is String) {
          // 如果是MySQL格式的字符串，需要转换为ISO格式
          final mysqlDate = row['date'] as String;
          try {
            // 尝试解析MySQL格式 (YYYY-MM-DD HH:MM:SS)
            final parts = mysqlDate.split(' ');
            if (parts.length == 2) {
              final datePart = parts[0];
              final timePart = parts[1];
              dateString = '${datePart}T${timePart}Z';
            } else {
              dateString = mysqlDate;
            }
          } catch (e) {
            dateString = DateTime.now().toIso8601String();
          }
        } else {
          dateString = DateTime.now().toIso8601String();
        }
        
        // 处理金额字段
        double amountValue;
        if (row['amount'] is double) {
          amountValue = row['amount'];
        } else if (row['amount'] is int) {
          amountValue = (row['amount'] as int).toDouble();
        } else if (row['amount'] is String) {
          amountValue = double.tryParse(row['amount']) ?? 0.0;
        } else {
          amountValue = 0.0;
        }
        
        // 处理staff_ids字段
        List<String> staffIds = [];
        if (row['staff_ids'] != null) {
          if (row['staff_ids'] is String) {
            try {
              staffIds = List<String>.from(json.decode(row['staff_ids']));
            } catch (e) {
              print('❌ JSON解析失败: $e');
              staffIds = [];
            }
          } else if (row['staff_ids'] is List) {
            staffIds = List<String>.from(row['staff_ids']);
          }
        }
        
        return Record.fromMap({
          'id': row['id'].toString(),
          'recordId': row['record_id']?.toString() ?? '',
          'date': dateString,
          'category': row['category']?.toString() ?? '其他',
          'workContent': row['work_content']?.toString() ?? '',
          'amount': amountValue,
          'ledger': row['ledger']?.toString() ?? '默认账本',
          'imageUrl': row['image_url']?.toString(),
          'staffIds': staffIds,
        });
      }).toList();
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
    final conn = await _getConnection();
    try {
      var query = '''
        SELECT * FROM records 
        WHERE deleted_at IS NULL 
        AND date BETWEEN ? AND ?
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
      
      return results.map((row) => Record.fromMap({
        'id': row['id'].toString(),
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
  static Future<Record> createRecord(Record record) async {
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
  // 格式化日期为MySQL兼容格式
  static String _formatDateForMySQL(DateTime date) {
    // MySQL兼容的日期时间格式: YYYY-MM-DD HH:MM:SS
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    
    return '$year-$month-$day $hour:$minute:$second';
  }

  static Future<Record> updateRecord(Record record) async {
    final conn = await _getConnection();
    try {
      print('🔧 更新记录: ID=${record.id}, 内容=${record.workContent}, 金额=${record.amount}');
      
      // 处理ID字段 - 可能是字符串或数字
      dynamic recordId;
      if (record.id is int) {
        recordId = record.id;
      } else if (record.id is String) {
        recordId = int.tryParse(record.id) ?? record.id;
      } else {
        recordId = record.id;
      }
      
      await conn.query('''
        UPDATE records 
        SET date = ?, category = ?, work_content = ?, amount = ?, ledger = ?, image_url = ?, staff_ids = ?
        WHERE id = ?
      ''', [
        _formatDateForMySQL(record.date),
        record.category,
        record.workContent,
        record.amount,
        record.ledger,
        record.imageUrl,
        json.encode(record.staffIds),
        recordId,
      ]);
      
      print('✅ 记录更新成功');
      return record;
    } catch (e) {
      print('❌ 更新记录失败: $e');
      rethrow;
    } finally {
      await conn.close();
    }
  }

  // 删除记录
  static Future<void> deleteRecord(String recordId) async {
    final conn = await _getConnection();
    try {
      await conn.query('UPDATE records SET deleted_at = NOW() WHERE id = ?', [int.parse(recordId)]);
    } finally {
      await conn.close();
    }
  }

  // 获取所有账本
  static Future<List<String>> getAllLedgers() async {
    final conn = await _getConnection();
    try {
      final results = await conn.query('SELECT name FROM ledgers ORDER BY name');
      return results.map((row) => row['name'] as String).toList();
    } finally {
      await conn.close();
    }
  }

  // 同步账本
  static Future<List<String>> syncLedgers() async {
    return await getAllLedgers();
  }

  // 创建账本
  static Future<String> createLedger(String name) async {
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

  // 获取已删除记录
  static Future<List<Record>> getDeletedRecords() async {
    final conn = await _getConnection();
    try {
      final results = await conn.query('''
        SELECT * FROM records 
        WHERE deleted_at IS NOT NULL 
        ORDER BY deleted_at DESC
      ''');
      
      return results.map((row) => Record.fromMap({
        'id': row['id'].toString(),
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

  // 恢复已删除记录
  static Future<void> restoreRecord(String recordId) async {
    final conn = await _getConnection();
    try {
      await conn.query('UPDATE records SET deleted_at = NULL WHERE id = ?', [int.parse(recordId)]);
    } finally {
      await conn.close();
    }
  }

  // 永久删除记录
  static Future<void> permanentlyDeleteRecord(String recordId) async {
    final conn = await _getConnection();
    try {
      await conn.query('DELETE FROM records WHERE id = ?', [int.parse(recordId)]);
    } finally {
      await conn.close();
    }
  }

  // 上传图片（保留原有逻辑）
  static Future<String> uploadImage(File imageFile) async {
    // 这里可以保留原有的图片上传逻辑
    // 或者修改为将图片保存到服务器并返回URL
    return 'https://example.com/uploaded_image.jpg';
  }

  // 更新账本（缺失的方法）
  static Future<String> updateLedger(String oldName, String newName) async {
    final conn = await _getConnection();
    try {
      await conn.query('UPDATE ledgers SET name = ? WHERE name = ?', [newName, oldName]);
      return newName;
    } finally {
      await conn.close();
    }
  }

  // 删除账本（缺失的方法）
  static Future<void> deleteLedger(String name) async {
    final conn = await _getConnection();
    try {
      await conn.query('DELETE FROM ledgers WHERE name = ?', [name]);
    } finally {
      await conn.close();
    }
  }

  // 获取人员列表（缺失的方法）
  static Future<List<Staff>> getStaffList() async {
    return await getAllStaff();
  }

  // 更新人员（缺失的方法）
  static Future<Staff> updateStaff(Staff staff) async {
    final conn = await _getConnection();
    try {
      await conn.query('UPDATE staff SET name = ? WHERE id = ?', [staff.name, int.parse(staff.id)]);
      return staff;
    } finally {
      await conn.close();
    }
  }

  // 删除人员（缺失的方法）
  static Future<void> deleteStaff(String staffId) async {
    final conn = await _getConnection();
    try {
      await conn.query('DELETE FROM staff WHERE id = ?', [int.parse(staffId)]);
    } finally {
      await conn.close();
    }
  }

  // 恢复已删除记录（别名方法，与main.dart中的调用匹配）
  static Future<void> restoreDeletedRecord(String recordId) async {
    return await restoreRecord(recordId);
  }
}