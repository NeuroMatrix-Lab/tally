import 'dart:convert';

import '../../models/record.dart';
import '../app_time.dart';
import '../record_mappers.dart';
import '../sync_service.dart';
import 'mode_dispatch.dart';

/// 记录 + 回收站：三种连接模式实现。
class RecordsOps {
  static Future<List<Record>> getAll() {
    return runForMode(
      local: _getAllLocal,
      backend: _getAllBackend,
      database: _getAllDatabase,
    );
  }

  static Future<List<Record>> _getAllLocal() async {
    final db = await localDb();
    final results = await db.query(
      'records',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC',
    );
    return results.map((row) => RecordMappers.fromLocalMap(row)).toList();
  }

  static Future<List<Record>> _getAllBackend() async {
    final data = await httpGet('/api/v1/records');
    return (data as List).map((item) => Record.fromMap(item)).toList();
  }

  static Future<List<Record>> _getAllDatabase() {
    return withMySqlConnection((conn) async {
      final results = await conn.query('''
        SELECT * FROM records
        WHERE deleted_at IS NULL
        ORDER BY date DESC
      ''');
      return results.map((row) => RecordMappers.fromDbRow(row)).toList();
    });
  }

  static Future<List<Record>> getRecent({int months = 3}) {
    return runForMode(
      local: () => _getRecentLocal(months),
      backend: () => _getRecentBackend(months),
      database: () => _getRecentDatabase(months),
    );
  }

  static Future<List<Record>> _getRecentLocal(int months) async {
    final db = await localDb();
    final cutoffDate = AppTime.now().subtract(Duration(days: months * 30));
    final results = await db.query(
      'records',
      where: 'deleted_at IS NULL AND date >= ?',
      whereArgs: [serializeDateForBackend(cutoffDate)],
      orderBy: 'date DESC',
    );
    return results.map((row) => RecordMappers.fromLocalMap(row)).toList();
  }

  static Future<List<Record>> _getRecentBackend(int months) async {
    final data = await httpGet('/api/v1/records/recent?months=$months');
    return (data as List).map((item) => Record.fromMap(item)).toList();
  }

  static Future<List<Record>> _getRecentDatabase(int months) {
    return withMySqlConnection((conn) async {
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
    });
  }

  static Future<List<Record>> search({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
    String? ledger,
  }) {
    return runForMode(
      local: () => _searchLocal(startDate, endDate, category, ledger),
      backend: () => _searchBackend(startDate, endDate, category, ledger),
      database: () => _searchDatabase(startDate, endDate, category, ledger),
    );
  }

  static Future<List<Record>> _searchLocal(
    DateTime startDate,
    DateTime endDate,
    String? category,
    String? ledger,
  ) async {
    final db = await localDb();
    var whereClause = 'deleted_at IS NULL AND date BETWEEN ? AND ?';
    var whereArgs = [
      serializeDateForBackend(startDate),
      serializeDateForBackend(endDate),
    ];

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

  static Future<List<Record>> _searchBackend(
    DateTime startDate,
    DateTime endDate,
    String? category,
    String? ledger,
  ) async {
    final data = await httpPost('/api/v1/records/search', {
      'startDate': serializeDateForBackend(startDate),
      'endDate': serializeDateForBackend(endDate),
      'category': category,
      'ledger': ledger,
    });
    return (data as List).map((item) => Record.fromMap(item)).toList();
  }

  static Future<List<Record>> _searchDatabase(
    DateTime startDate,
    DateTime endDate,
    String? category,
    String? ledger,
  ) {
    return withMySqlConnection((conn) async {
      var query = '''
        SELECT * FROM records
        WHERE deleted_at IS NULL AND date BETWEEN ? AND ?
      ''';
      var params = [
        serializeDateForBackend(startDate),
        serializeDateForBackend(endDate),
      ];

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
    });
  }

  static Future<Record> create(Record record) {
    return runForMode(
      local: () => _createLocal(record),
      backend: () async {
        final result = await _createBackend(record);
        await SyncService.performIncrementalSync();
        return result;
      },
      database: () => _createDatabase(record),
    );
  }

  static Future<Record> _createLocal(Record record) async {
    final db = await localDb();
    await db.insert('records', {
      'id': record.id,
      'record_id': record.id,
      'date': serializeDateForBackend(record.date),
      'category': record.category,
      'work_content': record.workContent,
      'amount': record.amount,
      'ledger': record.ledger,
      'image_url': record.imageUrl,
      'staff_ids': json.encode(record.staffIds),
    });
    return record;
  }

  static Future<Record> _createBackend(Record record) async {
    final data = await httpPost('/api/v1/records', {
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

  static Future<Record> _createDatabase(Record record) {
    return withMySqlConnection((conn) async {
      await conn.query(
        '''
        INSERT INTO records (record_id, date, category, work_content, amount, ledger, image_url, staff_ids)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          record.id,
          serializeDateForBackend(record.date),
          record.category,
          record.workContent,
          record.amount,
          record.ledger,
          record.imageUrl,
          json.encode(record.staffIds),
        ],
      );
      return record;
    });
  }

  static Future<Record> update(Record record) {
    return runForMode(
      local: () => _updateLocal(record),
      backend: () async {
        final result = await _updateBackend(record);
        await SyncService.performIncrementalSync();
        return result;
      },
      database: () => _updateDatabase(record),
    );
  }

  static Future<Record> _updateLocal(Record record) async {
    final db = await localDb();
    await db.update(
      'records',
      {
        'date': serializeDateForBackend(record.date),
        'category': record.category,
        'work_content': record.workContent,
        'amount': record.amount,
        'ledger': record.ledger,
        'image_url': record.imageUrl,
        'staff_ids': json.encode(record.staffIds),
        'updated_at': AppTime.now().toIso8601String(),
      },
      where: 'record_id = ?',
      whereArgs: [record.id],
    );
    return record;
  }

  static Future<Record> _updateBackend(Record record) async {
    final data = await httpPut('/api/v1/records/${record.id}', {
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

  static Future<Record> _updateDatabase(Record record) {
    return withMySqlConnection((conn) async {
      await conn.query(
        '''
        UPDATE records
        SET date = ?, category = ?, work_content = ?, amount = ?, ledger = ?, image_url = ?, staff_ids = ?
        WHERE record_id = ? AND deleted_at IS NULL
      ''',
        [
          serializeDateForBackend(record.date),
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
    });
  }

  static Future<void> delete(String recordId) async {
    await runForMode(
      local: () => _deleteLocal(recordId),
      backend: () async {
        await _deleteBackend(recordId);
        await SyncService.performIncrementalSync();
      },
      database: () => _deleteDatabase(recordId),
    );
  }

  static Future<void> _deleteLocal(String recordId) async {
    final db = await localDb();
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
        {'deleted_at': AppTime.now().toIso8601String()},
        where: 'record_id = ?',
        whereArgs: [recordId],
      );
    }
  }

  static Future<void> _deleteBackend(String recordId) {
    return httpDelete('/api/v1/records/$recordId');
  }

  static Future<void> _deleteDatabase(String recordId) {
    return withMySqlConnection((conn) async {
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
    });
  }

  static Future<List<Record>> getDeleted() {
    return runForMode(
      local: _getDeletedLocal,
      backend: _getDeletedBackend,
      database: _getDeletedDatabase,
    );
  }

  static Future<List<Record>> _getDeletedLocal() async {
    final db = await localDb();
    final results = await db.query('deleted_records', orderBy: 'deleted_at DESC');
    return results.map((row) => RecordMappers.fromDeletedMap(row)).toList();
  }

  static Future<List<Record>> _getDeletedBackend() async {
    final data = await httpGet('/api/v1/records/deleted');
    return (data as List).map((item) => Record.fromMap(item)).toList();
  }

  static Future<List<Record>> _getDeletedDatabase() {
    return withMySqlConnection((conn) async {
      final results = await conn.query('''
        SELECT * FROM deleted_records
        ORDER BY deleted_at DESC
      ''');
      return results.map((row) => RecordMappers.fromDbRow(row)).toList();
    });
  }

  static Future<void> restore(String recordId) async {
    await runForMode(
      local: () => _restoreLocal(recordId),
      backend: () async {
        await _restoreBackend(recordId);
        await SyncService.performIncrementalSync();
      },
      database: () => _restoreDatabase(recordId),
    );
  }

  static Future<void> _restoreLocal(String recordId) async {
    final db = await localDb();
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

  static Future<void> _restoreBackend(String recordId) {
    return httpPost('/api/v1/records/$recordId/restore', {});
  }

  static Future<void> _restoreDatabase(String recordId) {
    return withMySqlConnection((conn) async {
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
    });
  }

  static Future<void> permanentlyDelete(String recordId) {
    return runForMode(
      local: () => _permanentlyDeleteLocal(recordId),
      backend: () => _permanentlyDeleteBackend(recordId),
      database: () => _permanentlyDeleteDatabase(recordId),
    );
  }

  static Future<void> _permanentlyDeleteLocal(String recordId) async {
    final db = await localDb();
    await db.delete(
      'deleted_records',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
  }

  static Future<void> _permanentlyDeleteBackend(String recordId) {
    return httpDelete('/api/v1/records/$recordId/permanent');
  }

  static Future<void> _permanentlyDeleteDatabase(String recordId) {
    return withMySqlConnection((conn) {
      return conn.query('DELETE FROM deleted_records WHERE record_id = ?', [
        recordId,
      ]);
    });
  }
}
