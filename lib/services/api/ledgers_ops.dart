import '../../models/record.dart';
import '../sync_service.dart';
import 'mode_dispatch.dart';

/// 账本三种连接模式实现。
class LedgersOps {
  static Future<List<String>> getAll() {
    return runForMode(
      local: _getAllLocal,
      backend: _getAllBackend,
      database: _getAllDatabase,
    );
  }

  static Future<List<String>> _getAllLocal() async {
    final db = await localDb();
    final results = await db.query('ledgers', orderBy: 'name');
    return results.map((row) => row['name'] as String).toList();
  }

  static Future<List<String>> _getAllBackend() async {
    final data = await httpGet('/api/v1/ledgers');
    return (data as List).map((item) => item as String).toList();
  }

  static Future<List<String>> _getAllDatabase() {
    return withMySqlConnection((conn) async {
      final results = await conn.query('SELECT name FROM ledgers ORDER BY name');
      return results.map((row) => row['name'] as String).toList();
    });
  }

  static Future<String> create(String name) {
    return runForMode(
      local: () => _createLocal(name),
      backend: () async {
        final result = await _createBackend(name);
        await SyncService.performIncrementalSync();
        return result;
      },
      database: () => _createDatabase(name),
    );
  }

  static Future<String> _createLocal(String name) async {
    final db = await localDb();
    await db.insert('ledgers', {'name': name});
    return name;
  }

  static Future<String> _createBackend(String name) async {
    await httpPost('/api/v1/ledgers', name);
    return name;
  }

  static Future<String> _createDatabase(String name) {
    return withMySqlConnection((conn) async {
      await conn.query('INSERT INTO ledgers (name) VALUES (?)', [name]);
      return name;
    });
  }

  static Future<String> update(String oldName, String newName) {
    return runForMode(
      local: () => _updateLocal(oldName, newName),
      backend: () async {
        final result = await _updateBackend(oldName, newName);
        await SyncService.performIncrementalSync();
        return result;
      },
      database: () => _updateDatabase(oldName, newName),
    );
  }

  static Future<String> _updateLocal(String oldName, String newName) async {
    final db = await localDb();
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

  static Future<String> _updateBackend(String oldName, String newName) async {
    await httpPut('/api/v1/ledgers/$oldName', newName);
    return newName;
  }

  static Future<String> _updateDatabase(String oldName, String newName) {
    return withMySqlConnection((conn) async {
      await conn.query('UPDATE ledgers SET name = ? WHERE name = ?', [
        newName,
        oldName,
      ]);
      await conn.query('UPDATE records SET ledger = ? WHERE ledger = ?', [
        newName,
        oldName,
      ]);
      return newName;
    });
  }

  static Future<void> delete(String name) async {
    await runForMode(
      local: () => _deleteLocal(name),
      backend: () async {
        await _deleteBackend(name);
        await SyncService.performIncrementalSync();
      },
      database: () => _deleteDatabase(name),
    );
  }

  static Future<void> _deleteLocal(String name) async {
    final db = await localDb();
    await db.delete('records', where: 'ledger = ?', whereArgs: [name]);
    await db.delete('ledgers', where: 'name = ?', whereArgs: [name]);
  }

  static Future<void> _deleteBackend(String name) async {
    final data = await httpGet('/api/v1/records');
    final records = (data as List).map((item) => Record.fromMap(item)).toList();
    final ledgerRecords = records.where((r) => r.ledger == name).toList();
    for (final record in ledgerRecords) {
      await httpDelete('/api/v1/records/${record.id}');
    }
    await httpDelete('/api/v1/ledgers/$name');
  }

  static Future<void> _deleteDatabase(String name) {
    return withMySqlConnection((conn) async {
      await conn.query('DELETE FROM records WHERE ledger = ?', [name]);
      await conn.query('DELETE FROM ledgers WHERE name = ?', [name]);
    });
  }
}
