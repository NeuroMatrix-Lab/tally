import 'package:mysql1/mysql1.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connection_mode.dart';
import 'app_time.dart';

class ApiConfig {
  static Future<ConnectionMode> getConnectionMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('connectionMode') ?? 0;
    return ConnectionMode.values[modeIndex];
  }

  static Future<String> getBackendBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('backendIp')?.trim() ?? '';
    final portStr = prefs.getString('backendPort')?.trim() ?? '7378';

    if (host.isEmpty) {
      throw Exception('后端服务地址未配置，请在设置中填写');
    }

    final port = int.tryParse(portStr);
    if (port == null || port <= 0 || port > 65535) {
      throw Exception('后端服务端口无效，请输入 1-65535 之间的端口');
    }

    final scheme = port == 443 ? 'https' : 'http';
    final defaultPort = port == 443 ? '' : ':$port';
    return '$scheme://$host$defaultPort';
  }

  static Future<String> getWebSocketUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('backendIp')?.trim() ?? '';
    final portStr = prefs.getString('backendPort')?.trim() ?? '7378';
    final password = prefs.getString('backendPassword')?.trim() ?? '';

    if (host.isEmpty) {
      throw Exception('后端服务地址未配置，请在设置中填写');
    }

    final port = int.tryParse(portStr);
    if (port == null || port <= 0 || port > 65535) {
      throw Exception('后端服务端口无效，请输入 1-65535 之间的端口');
    }

    final scheme = port == 443 ? 'wss' : 'ws';
    final defaultPort = port == 443 ? '' : ':$port';
    final passwordQuery = password.isEmpty
        ? ''
        : '?password=${Uri.encodeQueryComponent(password)}';
    return '$scheme://$host$defaultPort/api/v1/ws$passwordQuery';
  }

  static Future<String> getBackendPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('backendPassword')?.trim() ?? '';
  }

  static Future<void> validateDatabaseConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('dbHost')?.trim() ?? '';
    final portStr = prefs.getString('dbPort')?.trim() ?? '3306';
    final user = prefs.getString('dbUser')?.trim() ?? '';
    final dbName = prefs.getString('dbName')?.trim() ?? '';

    if (host.isEmpty || user.isEmpty || dbName.isEmpty) {
      throw Exception('数据库直通模式请填写完整数据库连接信息（host/user/dbName）');
    }

    final port = int.tryParse(portStr);
    if (port == null || port <= 0 || port > 65535) {
      throw Exception('数据库端口无效，请输入 1-65535 之间的端口');
    }
  }

  static Future<ConnectionSettings> getDbConnectionSettings() async {
    await validateDatabaseConfig();

    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('dbHost')?.trim() ?? '';
    final portStr = prefs.getString('dbPort')?.trim() ?? '3306';
    final port = int.tryParse(portStr) ?? 3306;
    final user = prefs.getString('dbUser')?.trim() ?? '';
    final password = prefs.getString('dbPassword')?.trim() ?? '';
    final dbName = prefs.getString('dbName')?.trim() ?? '';

    return ConnectionSettings(
      host: host,
      port: port,
      user: user,
      password: password,
      db: dbName,
    );
  }

  static String serializeDateForBackend(DateTime date) {
    return AppTime.serializeBusinessDate(date);
  }
}
