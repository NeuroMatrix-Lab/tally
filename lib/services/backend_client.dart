import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class BackendClient {
  static Future<Map<String, String>> _headers() async {
    final password = await ApiConfig.getBackendPassword();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (password.isNotEmpty) {
      headers['X-Api-Password'] = password;
    }
    return headers;
  }

  static Never _rethrowAsFriendly(Object e) {
    if (e is TimeoutException) {
      throw Exception('请求超时，请检查后端服务是否可访问');
    }
    if (e is SocketException) {
      throw Exception('网络异常：$e');
    }
    if (e.toString().contains('HTTP 401')) {
      throw Exception('鉴权失败：后端密码错误或未填写');
    }
    throw Exception('请求失败：$e');
  }

  static Future<dynamic> get(String endpoint) async {
    final baseUrl = await ApiConfig.getBackendBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _headers();

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      _rethrowAsFriendly(e);
    }
  }

  static Future<dynamic> post(String endpoint, dynamic body) async {
    final baseUrl = await ApiConfig.getBackendBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _headers();

    try {
      final response = await http
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      _rethrowAsFriendly(e);
    }
  }

  static Future<dynamic> put(String endpoint, dynamic body) async {
    final baseUrl = await ApiConfig.getBackendBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _headers();

    try {
      final response = await http
          .put(uri, headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return json.decode(response.body);
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      _rethrowAsFriendly(e);
    }
  }

  static Future<void> delete(String endpoint) async {
    final baseUrl = await ApiConfig.getBackendBaseUrl();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _headers();

    try {
      final response = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _rethrowAsFriendly(e);
    }
  }

  /// 连通性检查：健康检查始终开放；鉴权检查会验证密码（若后端已启用）。
  static Future<Map<String, dynamic>> verifyConnection({
    required String scheme,
    required String host,
    required String port,
    required String password,
  }) async {
    final defaultPort = (scheme == 'https' && port == '443') ||
            (scheme == 'http' && port == '80')
        ? ''
        : ':$port';
    final base = '$scheme://$host$defaultPort';

    final healthResponse = await http
        .get(Uri.parse('$base/api/v1/health'))
        .timeout(const Duration(seconds: 10));
    if (healthResponse.statusCode != 200) {
      throw Exception('连接失败：服务器返回状态码 ${healthResponse.statusCode}');
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (password.isNotEmpty) {
      headers['X-Api-Password'] = password;
    }

    final authResponse = await http
        .get(Uri.parse('$base/api/v1/auth'), headers: headers)
        .timeout(const Duration(seconds: 10));
    if (authResponse.statusCode == 401) {
      throw Exception('鉴权失败：后端密码错误或未填写');
    }
    if (authResponse.statusCode != 200) {
      throw Exception('鉴权检查失败：状态码 ${authResponse.statusCode}');
    }

    Map<String, dynamic> body = {};
    try {
      body = Map<String, dynamic>.from(json.decode(authResponse.body));
    } catch (_) {}

    final authRequired = body['authRequired'] == true;
    if (authRequired && password.isEmpty) {
      throw Exception('该后端已启用密码，请在设置中填写访问密码');
    }

    return body;
  }
}
