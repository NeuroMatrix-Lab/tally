import '../../models/staff.dart';
import '../sync_service.dart';
import 'mode_dispatch.dart';

/// 人员三种连接模式实现。
class StaffOps {
  static Future<List<Staff>> getAll() {
    return runForMode(
      local: _getAllLocal,
      backend: _getAllBackend,
      database: _getAllDatabase,
    );
  }

  static Future<List<Staff>> _getAllLocal() async {
    final db = await localDb();
    final results = await db.query('staff', orderBy: 'name');
    return results
        .map(
          (row) => Staff(id: row['id'].toString(), name: row['name'] as String),
        )
        .toList();
  }

  static Future<List<Staff>> _getAllBackend() async {
    final data = await httpGet('/api/v1/staff');
    return (data as List).map((item) => Staff.fromMap(item)).toList();
  }

  static Future<List<Staff>> _getAllDatabase() {
    return withMySqlConnection((conn) async {
      final results = await conn.query('SELECT * FROM staff ORDER BY name');
      return results
          .map(
            (row) =>
                Staff(id: row['id'].toString(), name: row['name'] as String),
          )
          .toList();
    });
  }

  static Future<Staff> add(Staff staff) {
    return runForMode(
      local: () => _addLocal(staff),
      backend: () async {
        final result = await _addBackend(staff);
        await SyncService.performIncrementalSync();
        return result;
      },
      database: () => _addDatabase(staff),
    );
  }

  static Future<Staff> _addLocal(Staff staff) async {
    final db = await localDb();
    final id = await db.insert('staff', {'name': staff.name});
    return Staff(id: id.toString(), name: staff.name);
  }

  static Future<Staff> _addBackend(Staff staff) async {
    final data = await httpPost('/api/v1/staff', {'name': staff.name});
    return Staff.fromMap(data);
  }

  static Future<Staff> _addDatabase(Staff staff) {
    return withMySqlConnection((conn) async {
      final result = await conn.query('INSERT INTO staff (name) VALUES (?)', [
        staff.name,
      ]);
      return Staff(id: result.insertId.toString(), name: staff.name);
    });
  }

  static Future<Staff> update(Staff staff) {
    return runForMode(
      local: () => _updateLocal(staff),
      backend: () async {
        final result = await _updateBackend(staff);
        await SyncService.performIncrementalSync();
        return result;
      },
      database: () => _updateDatabase(staff),
    );
  }

  static Future<Staff> _updateLocal(Staff staff) async {
    final db = await localDb();
    await db.update(
      'staff',
      {'name': staff.name},
      where: 'id = ?',
      whereArgs: [int.tryParse(staff.id) ?? 0],
    );
    return staff;
  }

  static Future<Staff> _updateBackend(Staff staff) async {
    await httpPut('/api/v1/staff/${staff.id}', {'name': staff.name});
    return staff;
  }

  static Future<Staff> _updateDatabase(Staff staff) {
    return withMySqlConnection((conn) async {
      await conn.query('UPDATE staff SET name = ? WHERE id = ?', [
        staff.name,
        int.tryParse(staff.id) ?? 0,
      ]);
      return staff;
    });
  }

  static Future<void> delete(String staffId) async {
    await runForMode(
      local: () => _deleteLocal(staffId),
      backend: () async {
        await _deleteBackend(staffId);
        await SyncService.performIncrementalSync();
      },
      database: () => _deleteDatabase(staffId),
    );
  }

  static Future<void> _deleteLocal(String staffId) async {
    final db = await localDb();
    await db.delete(
      'staff',
      where: 'id = ?',
      whereArgs: [int.tryParse(staffId) ?? 0],
    );
  }

  static Future<void> _deleteBackend(String staffId) {
    return httpDelete('/api/v1/staff/$staffId');
  }

  static Future<void> _deleteDatabase(String staffId) {
    return withMySqlConnection((conn) {
      return conn.query('DELETE FROM staff WHERE id = ?', [
        int.tryParse(staffId) ?? 0,
      ]);
    });
  }
}
