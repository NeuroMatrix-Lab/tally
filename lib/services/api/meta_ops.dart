import 'mode_dispatch.dart';

/// 工作内容 / 类别：三种连接模式实现。
class MetaOps {
  static Future<List<String>> getWorkContents() {
    return runForMode(
      local: _getWorkContentsLocal,
      backend: _getWorkContentsBackend,
      database: _getWorkContentsDatabase,
    );
  }

  static Future<List<String>> _getWorkContentsLocal() async {
    final db = await localDb();
    final results = await db.rawQuery('''
      SELECT DISTINCT work_content FROM records
      WHERE deleted_at IS NULL
      ORDER BY work_content
    ''');
    return results.map((row) => row['work_content'] as String).toList();
  }

  static Future<List<String>> _getWorkContentsBackend() async {
    final data = await httpGet('/api/v1/work-contents');
    return (data as List).map((item) => item as String).toList();
  }

  static Future<List<String>> _getWorkContentsDatabase() {
    return withMySqlConnection((conn) async {
      final results = await conn.query('''
        SELECT DISTINCT work_content FROM records
        WHERE deleted_at IS NULL
        ORDER BY work_content
      ''');
      return results.map((row) => row['work_content'] as String).toList();
    });
  }

  static Future<List<String>> getCategories() {
    return runForMode(
      local: _getCategoriesLocal,
      backend: _getCategoriesBackend,
      database: _getCategoriesDatabase,
    );
  }

  static Future<List<String>> _getCategoriesLocal() async {
    final db = await localDb();
    final results = await db.rawQuery('''
      SELECT DISTINCT category FROM records
      WHERE deleted_at IS NULL
      ORDER BY category
    ''');
    return results.map((row) => row['category'] as String).toList();
  }

  static Future<List<String>> _getCategoriesBackend() async {
    final data = await httpGet('/api/v1/categories');
    return (data as List).map((item) => item as String).toList();
  }

  static Future<List<String>> _getCategoriesDatabase() {
    return withMySqlConnection((conn) async {
      final results = await conn.query('''
        SELECT DISTINCT category FROM records
        WHERE deleted_at IS NULL
        ORDER BY category
      ''');
      return results.map((row) => row['category'] as String).toList();
    });
  }
}
