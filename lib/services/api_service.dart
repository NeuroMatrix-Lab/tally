import 'dart:convert';
import 'dart:io';

import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';

import '../models/record.dart';
import '../models/staff.dart';
import 'api_config.dart';
import 'backend_client.dart';
import 'connection_mode.dart';
import 'local_database.dart';
import 'record_mappers.dart';
import 'sync_service.dart';

export 'connection_mode.dart';

class ApiService {
  static Stream<bool> get syncStream => SyncService.syncStream;
  static Stream<void> get syncCompletedStream =>
      SyncService.syncCompletedStream;
  static bool get isConnected => SyncService.isConnected;

  static Future<T> _runForMode<T>({
    required Future<T> Function() local,
    required Future<T> Function() backend,
    required Future<T> Function() database,
  }) async {
    final mode = await ApiConfig.getConnectionMode();
    switch (mode) {
      case ConnectionMode.local:
        return await local();
      case ConnectionMode.backend:
        return await backend();
      case ConnectionMode.database:
        return await database();
    }
  }

  static String serializeDateForBackend(DateTime date) {
    return ApiConfig.serializeDateForBackend(date);
  }

  static Future<Database> _getLocalDb() => LocalDatabase.get();

  static Future<ConnectionSettings> _getDbConnectionSettings() =>
      ApiConfig.getDbConnectionSettings();

  // ==================== WebSocket 同步 ====================

  static Future<void> connectWebSocket() => SyncService.connectWebSocket();

  static Future<void> disconnectWebSocket() =>
      SyncService.disconnectWebSocket();

  static Future<void> performIncrementalSync() =>
      SyncService.performIncrementalSync();

  // ==================== HTTP API 调用（后端服务模式）====================

  static Future<dynamic> _httpGet(String endpoint) =>
      BackendClient.get(endpoint);

  static Future<dynamic> _httpPost(String endpoint, dynamic body) =>
      BackendClient.post(endpoint, body);

  static Future<dynamic> _httpPut(String endpoint, dynamic body) =>
      BackendClient.put(endpoint, body);

  static Future<void> _httpDelete(String endpoint) =>
      BackendClient.delete(endpoint);

  // ==================== 记录操作 ====================

  static Future<List<Record>> getAllRecords() async {
    return _runForMode(
      local: _getAllRecordsLocal,
      backend: _getAllRecordsBackend,
      database: _getAllRecordsDatabase,
    );
  }

  static Future<List<Record>> _getAllRecordsLocal() async {
    final db = await _getLocalDb();
    final results = await db.query(
      'records',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC',
    );
    return results.map((row) => RecordMappers.fromLocalMap(row)).toList();
  }

  static Future<List<Record>> _getAllRecordsBackend() async {
    final data = await _httpGet('/api/v1/records');
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

      return results.map((row) => RecordMappers.fromDbRow(row)).toList();
    } finally {
      await conn.close();
    }
  }

  static Future<List<Record>> getRecentRecords({int months = 3}) async {
    return _runForMode(
      local: () => _getRecentRecordsLocal(months),
      backend: () => _getRecentRecordsBackend(months),
      database: () => _getRecentRecordsDatabase(months),
    );
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
    return results.map((row) => RecordMappers.fromLocalMap(row)).toList();
  }

  static Future<List<Record>> _getRecentRecordsBackend(int months) async {
    final data = await _httpGet('/api/v1/records/recent?months=$months');
    return (data as List).map((item) => Record.fromMap(item)).toList();
  }

  static Future<List<Record>> _getRecentRecordsDatabase(int months) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query(
        '''
        SELECT * FROM records
        WHERE deleted_at IS NULL
        AND date >= DATE_SUB(NOW(), INTERVAL ? MONTH)
        ORDER BY date DESC
      ''',
        [months],
      );

      return results.map((row) => RecordMappers.fromDbRow(row)).toList();
    } finally {
      await conn.close();
    }
  }

  static Future<List<Record>> searchRecords({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
    String? ledger,
  }) async {
    return _runForMode(
      local: () => _searchRecordsLocal(startDate, endDate, category, ledger),
      backend: () =>
          _searchRecordsBackend(startDate, endDate, category, ledger),
      database: () =>
          _searchRecordsDatabase(startDate, endDate, category, ledger),
    );
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
    return results.map((row) => RecordMappers.fromLocalMap(row)).toList();
  }

  static Future<List<Record>> _searchRecordsBackend(
    DateTime startDate,
    DateTime endDate,
    String? category,
    String? ledger,
  ) async {
    final data = await _httpPost('/api/v1/records/search', {
      'startDate': serializeDateForBackend(startDate),
      'endDate': serializeDateForBackend(endDate),
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
      return results.map((row) => RecordMappers.fromDbRow(row)).toList();
    } finally {
      await conn.close();
    }
  }

  static Future<Record> createRecord(Record record) async {
    return _runForMode(
      local: () => _createRecordLocal(record),
      backend: () async {
        final result = await _createRecordBackend(record);
        performIncrementalSync();
        return result;
      },
      database: () => _createRecordDatabase(record),
    );
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
    final data = await _httpPost('/api/v1/records', {
      'id': record.id,
      'date': serializeDateForBackend(record.date),
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
      await conn.query(
        '''
        INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          record.id,
          record.date.toIso8601String(),
          record.category,
          record.workContent,
          record.amount,
          record.ledger,
          record.imageUrl,
          json.encode(record.staffIds),
        ],
      );
      return record;
    } finally {
      await conn.close();
    }
  }

  static Future<Record> updateRecord(Record record) async {
    return _runForMode(
      local: () => _updateRecordLocal(record),
      backend: () async {
        final result = await _updateRecordBackend(record);
        performIncrementalSync();
        return result;
      },
      database: () => _updateRecordDatabase(record),
    );
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
    final data = await _httpPut('/api/v1/records/${record.id}', {
      'date': serializeDateForBackend(record.date),
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
      await conn.query(
        '''
        UPDATE records
        SET date = ?, category = ?, work_content = ?, amount = ?, ledger = ?, image_url = ?, staff_ids = ?
        WHERE record_id = ? AND deleted_at IS NULL
      ''',
        [
          record.date.toIso8601String(),
          record.category,
          record.workContent,
          record.amount,
          record.ledger,
          record.imageUrl,
          json.encode(record.staffIds),
          record.id,
        ],
      );
      return record;
    } finally {
      await conn.close();
    }
  }

  static Future<void> deleteRecord(String recordId) async {
    await _runForMode(
      local: () => _deleteRecordLocal(recordId),
      backend: () async {
        await _deleteRecordBackend(recordId);
        performIncrementalSync();
      },
      database: () => _deleteRecordDatabase(recordId),
    );
  }

  static Future<void> _deleteRecordLocal(String recordId) async {
    final db = await _getLocalDb();
    final record = await db.query(
      'records',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );

    if (record.isNotEmpty) {
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

      await db.update(
        'records',
        {'deleted_at': DateTime.now().toIso8601String()},
        where: 'record_id = ?',
        whereArgs: [recordId],
      );
    }
  }

  static Future<void> _deleteRecordBackend(String recordId) async {
    await _httpDelete('/api/v1/records/$recordId');
  }

  static Future<void> _deleteRecordDatabase(String recordId) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query(
        'SELECT * FROM records WHERE record_id = ?',
        [recordId],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        await conn.query(
          '''
          INSERT INTO deleted_records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids, deleted_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ''',
          [
            row['record_id'],
            row['date'],
            row['category'],
            row['work_content'],
            row['amount'],
            row['ledger'],
            row['image_url'],
            row['staff_ids'],
          ],
        );

        await conn.query(
          'UPDATE records SET deleted_at = NOW() WHERE record_id = ?',
          [recordId],
        );
      }
    } finally {
      await conn.close();
    }
  }

  static Future<List<Record>> getDeletedRecords() async {
    return _runForMode(
      local: _getDeletedRecordsLocal,
      backend: _getDeletedRecordsBackend,
      database: _getDeletedRecordsDatabase,
    );
  }

  static Future<List<Record>> _getDeletedRecordsLocal() async {
    final db = await _getLocalDb();
    final results = await db.query(
      'deleted_records',
      orderBy: 'deleted_at DESC',
    );
    return results.map((row) => RecordMappers.fromDeletedMap(row)).toList();
  }

  static Future<List<Record>> _getDeletedRecordsBackend() async {
    final data = await _httpGet('/api/v1/records/deleted');
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
      return results.map((row) => RecordMappers.fromDbRow(row)).toList();
    } finally {
      await conn.close();
    }
  }

  static Future<void> restoreRecord(String recordId) async {
    await _runForMode(
      local: () => _restoreRecordLocal(recordId),
      backend: () async {
        await _restoreRecordBackend(recordId);
        performIncrementalSync();
      },
      database: () => _restoreRecordDatabase(recordId),
    );
  }

  static Future<void> _restoreRecordLocal(String recordId) async {
    final db = await _getLocalDb();
    final deletedRecord = await db.query(
      'deleted_records',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );

    if (deletedRecord.isNotEmpty) {
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

      await db.delete(
        'deleted_records',
        where: 'record_id = ?',
        whereArgs: [recordId],
      );
    }
  }

  static Future<void> _restoreRecordBackend(String recordId) async {
    await _httpPost('/api/v1/records/$recordId/restore', {});
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
        await conn.query(
          '''
          INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE deleted_at = NULL
        ''',
          [
            row['record_id'],
            row['date'],
            row['category'],
            row['work_content'],
            row['amount'],
            row['ledger'],
            row['image_url'],
            row['staff_ids'],
          ],
        );

        await conn.query('DELETE FROM deleted_records WHERE record_id = ?', [
          recordId,
        ]);
      }
    } finally {
      await conn.close();
    }
  }

  static Future<void> permanentlyDeleteRecord(String recordId) async {
    await _runForMode(
      local: () => _permanentlyDeleteRecordLocal(recordId),
      backend: () => _permanentlyDeleteRecordBackend(recordId),
      database: () => _permanentlyDeleteRecordDatabase(recordId),
    );
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
    await _httpDelete('/api/v1/records/$recordId/permanent');
  }

  static Future<void> _permanentlyDeleteRecordDatabase(String recordId) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('DELETE FROM deleted_records WHERE record_id = ?', [
        recordId,
      ]);
    } finally {
      await conn.close();
    }
  }

  // ==================== 账本操作 ====================

  static Future<List<String>> getAllLedgers() async {
    return _runForMode(
      local: _getAllLedgersLocal,
      backend: _getAllLedgersBackend,
      database: _getAllLedgersDatabase,
    );
  }

  static Future<List<String>> _getAllLedgersLocal() async {
    final db = await _getLocalDb();
    final results = await db.query('ledgers', orderBy: 'name');
    return results.map((row) => row['name'] as String).toList();
  }

  static Future<List<String>> _getAllLedgersBackend() async {
    final data = await _httpGet('/api/v1/ledgers');
    return (data as List).map((item) => item as String).toList();
  }

  static Future<List<String>> _getAllLedgersDatabase() async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query(
        'SELECT name FROM ledgers ORDER BY name',
      );
      return results.map((row) => row['name'] as String).toList();
    } finally {
      await conn.close();
    }
  }

  static Future<List<String>> syncLedgers() async {
    return await getAllLedgers();
  }

  static Future<String> createLedger(String name) async {
    return _runForMode(
      local: () => _createLedgerLocal(name),
      backend: () async {
        final result = await _createLedgerBackend(name);
        performIncrementalSync();
        return result;
      },
      database: () => _createLedgerDatabase(name),
    );
  }

  static Future<String> _createLedgerLocal(String name) async {
    final db = await _getLocalDb();
    await db.insert('ledgers', {'name': name});
    return name;
  }

  static Future<String> _createLedgerBackend(String name) async {
    await _httpPost('/api/v1/ledgers', name);
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
    return _runForMode(
      local: () => _updateLedgerLocal(oldName, newName),
      backend: () async {
        final result = await _updateLedgerBackend(oldName, newName);
        performIncrementalSync();
        return result;
      },
      database: () => _updateLedgerDatabase(oldName, newName),
    );
  }

  static Future<String> _updateLedgerLocal(
    String oldName,
    String newName,
  ) async {
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

  static Future<String> _updateLedgerBackend(
    String oldName,
    String newName,
  ) async {
    await _httpPut('/api/v1/ledgers/$oldName', newName);
    return newName;
  }

  static Future<String> _updateLedgerDatabase(
    String oldName,
    String newName,
  ) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('UPDATE ledgers SET name = ? WHERE name = ?', [
        newName,
        oldName,
      ]);
      await conn.query('UPDATE records SET ledger = ? WHERE ledger = ?', [
        newName,
        oldName,
      ]);
      return newName;
    } finally {
      await conn.close();
    }
  }

  static Future<void> deleteLedger(String name) async {
    await _runForMode(
      local: () => _deleteLedgerLocal(name),
      backend: () async {
        await _deleteLedgerBackend(name);
        performIncrementalSync();
      },
      database: () => _deleteLedgerDatabase(name),
    );
  }

  static Future<void> _deleteLedgerLocal(String name) async {
    final db = await _getLocalDb();
    await db.delete('records', where: 'ledger = ?', whereArgs: [name]);
    await db.delete('ledgers', where: 'name = ?', whereArgs: [name]);
  }

  static Future<void> _deleteLedgerBackend(String name) async {
    final records = await _getAllRecordsBackend();
    final ledgerRecords = records.where((r) => r.ledger == name).toList();
    for (final record in ledgerRecords) {
      await _deleteRecordBackend(record.id);
    }
    await _httpDelete('/api/v1/ledgers/$name');
  }

  static Future<void> _deleteLedgerDatabase(String name) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('DELETE FROM records WHERE ledger = ?', [name]);
      await conn.query('DELETE FROM ledgers WHERE name = ?', [name]);
    } finally {
      await conn.close();
    }
  }

  // ==================== 人员操作 ====================

  static Future<List<Staff>> getAllStaff() async {
    return _runForMode(
      local: _getAllStaffLocal,
      backend: _getAllStaffBackend,
      database: _getAllStaffDatabase,
    );
  }

  static Future<List<Staff>> _getAllStaffLocal() async {
    final db = await _getLocalDb();
    final results = await db.query('staff', orderBy: 'name');
    return results
        .map(
          (row) => Staff(id: row['id'].toString(), name: row['name'] as String),
        )
        .toList();
  }

  static Future<List<Staff>> _getAllStaffBackend() async {
    final data = await _httpGet('/api/v1/staff');
    return (data as List).map((item) => Staff.fromMap(item)).toList();
  }

  static Future<List<Staff>> _getAllStaffDatabase() async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final results = await conn.query('SELECT * FROM staff ORDER BY name');
      return results
          .map(
            (row) =>
                Staff(id: row['id'].toString(), name: row['name'] as String),
          )
          .toList();
    } finally {
      await conn.close();
    }
  }

  static Future<List<Staff>> getStaffList() async {
    return await getAllStaff();
  }

  static Future<Staff> addStaff(Staff staff) async {
    return _runForMode(
      local: () => _addStaffLocal(staff),
      backend: () async {
        final result = await _addStaffBackend(staff);
        performIncrementalSync();
        return result;
      },
      database: () => _addStaffDatabase(staff),
    );
  }

  static Future<Staff> _addStaffLocal(Staff staff) async {
    final db = await _getLocalDb();
    final id = await db.insert('staff', {'name': staff.name});
    return Staff(id: id.toString(), name: staff.name);
  }

  static Future<Staff> _addStaffBackend(Staff staff) async {
    final data = await _httpPost('/api/v1/staff', {'name': staff.name});
    return Staff.fromMap(data);
  }

  static Future<Staff> _addStaffDatabase(Staff staff) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      final result = await conn.query('INSERT INTO staff (name) VALUES (?)', [
        staff.name,
      ]);
      return Staff(id: result.insertId.toString(), name: staff.name);
    } finally {
      await conn.close();
    }
  }

  static Future<Staff> updateStaff(Staff staff) async {
    return _runForMode(
      local: () => _updateStaffLocal(staff),
      backend: () async {
        final result = await _updateStaffBackend(staff);
        performIncrementalSync();
        return result;
      },
      database: () => _updateStaffDatabase(staff),
    );
  }

  static Future<Staff> _updateStaffLocal(Staff staff) async {
    final db = await _getLocalDb();
    await db.update(
      'staff',
      {'name': staff.name},
      where: 'id = ?',
      whereArgs: [int.tryParse(staff.id) ?? 0],
    );
    return staff;
  }

  static Future<Staff> _updateStaffBackend(Staff staff) async {
    await _httpPut('/api/v1/staff/${staff.id}', {'name': staff.name});
    return staff;
  }

  static Future<Staff> _updateStaffDatabase(Staff staff) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('UPDATE staff SET name = ? WHERE id = ?', [
        staff.name,
        int.tryParse(staff.id) ?? 0,
      ]);
      return staff;
    } finally {
      await conn.close();
    }
  }

  static Future<void> deleteStaff(String staffId) async {
    await _runForMode(
      local: () => _deleteStaffLocal(staffId),
      backend: () async {
        await _deleteStaffBackend(staffId);
        performIncrementalSync();
      },
      database: () => _deleteStaffDatabase(staffId),
    );
  }

  static Future<void> _deleteStaffLocal(String staffId) async {
    final db = await _getLocalDb();
    await db.delete(
      'staff',
      where: 'id = ?',
      whereArgs: [int.tryParse(staffId) ?? 0],
    );
  }

  static Future<void> _deleteStaffBackend(String staffId) async {
    await _httpDelete('/api/v1/staff/$staffId');
  }

  static Future<void> _deleteStaffDatabase(String staffId) async {
    final settings = await _getDbConnectionSettings();
    final conn = await MySqlConnection.connect(settings);
    try {
      await conn.query('DELETE FROM staff WHERE id = ?', [
        int.tryParse(staffId) ?? 0,
      ]);
    } finally {
      await conn.close();
    }
  }

  // ==================== 工作内容和类别 ====================

  static Future<List<String>> getWorkContents() async {
    return _runForMode(
      local: _getWorkContentsLocal,
      backend: _getWorkContentsBackend,
      database: _getWorkContentsDatabase,
    );
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
    final data = await _httpGet('/api/v1/work-contents');
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
    return _runForMode(
      local: _getCategoriesLocal,
      backend: _getCategoriesBackend,
      database: _getCategoriesDatabase,
    );
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
    final data = await _httpGet('/api/v1/categories');
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
    final bytes = await imageFile.readAsBytes();
    final base64Str = base64Encode(bytes);
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final dataUrl = 'data:$mime;base64,$base64Str';
    if (dataUrl.length > 60000) {
      throw Exception('图片过大，请选择更小的图片（建议小于 40KB）');
    }
    return dataUrl;
  }

  static Future<void> restoreDeletedRecord(String recordId) async {
    return await restoreRecord(recordId);
  }

  static void dispose() {
    SyncService.dispose();
  }
}
