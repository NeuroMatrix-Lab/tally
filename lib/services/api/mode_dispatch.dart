import 'dart:convert';
import 'dart:io';

import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';

import '../api_config.dart';
import '../backend_client.dart';
import '../connection_mode.dart';
import '../local_database.dart';

/// 按连接模式分发到 local / backend / database 实现。
Future<T> runForMode<T>({
  required Future<T> Function() local,
  required Future<T> Function() backend,
  required Future<T> Function() database,
}) async {
  final mode = await ApiConfig.getConnectionMode();
  switch (mode) {
    case ConnectionMode.local:
      return local();
    case ConnectionMode.backend:
      return backend();
    case ConnectionMode.database:
      return database();
  }
}

Future<Database> localDb() => LocalDatabase.get();

Future<ConnectionSettings> dbSettings() => ApiConfig.getDbConnectionSettings();

String serializeDateForBackend(DateTime date) =>
    ApiConfig.serializeDateForBackend(date);

Future<dynamic> httpGet(String endpoint) => BackendClient.get(endpoint);

Future<dynamic> httpPost(String endpoint, dynamic body) =>
    BackendClient.post(endpoint, body);

Future<dynamic> httpPut(String endpoint, dynamic body) =>
    BackendClient.put(endpoint, body);

Future<void> httpDelete(String endpoint) => BackendClient.delete(endpoint);

/// 数据库直通：连接 → 操作 → 必定关闭。
Future<T> withMySqlConnection<T>(
  Future<T> Function(MySqlConnection conn) action,
) async {
  final settings = await dbSettings();
  final conn = await MySqlConnection.connect(settings);
  try {
    await conn.query("SET time_zone = '+08:00'");
    return await action(conn);
  } finally {
    await conn.close();
  }
}

String mimeFromPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  return ext == 'png' ? 'image/png' : 'image/jpeg';
}

Future<String> fileToDataUrl(File file) async {
  final bytes = await file.readAsBytes();
  final base64Str = base64Encode(bytes);
  final mime = mimeFromPath(file.path);
  return 'data:$mime;base64,$base64Str';
}
