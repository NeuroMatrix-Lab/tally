import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

String get baseUrl {
  final envUrl = Platform.environment['API_BASE_URL'];
  if (envUrl != null && envUrl.trim().isNotEmpty) {
    return envUrl.trim().replaceAll(RegExp(r'/+$'), '');
  }
  return 'http://127.0.0.1:7378';
}

Map<String, String> get apiHeaders {
  final password = Platform.environment['API_PASSWORD']?.trim() ?? '';
  final headers = {'Content-Type': 'application/json'};
  if (password.isNotEmpty) {
    headers['X-Api-Password'] = password;
  }
  return headers;
}

const _timeout = Duration(seconds: 15);

Future<http.Response> request(
  String method,
  String path, {
  Object? body,
  int retries = 2,
}) async {
  final uri = Uri.parse('$baseUrl$path');
  Object? lastError;
  for (var attempt = 0; attempt <= retries; attempt++) {
    try {
      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: apiHeaders).timeout(_timeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: apiHeaders, body: body == null ? null : json.encode(body))
              .timeout(_timeout);
          break;
        case 'DELETE':
          response =
              await http.delete(uri, headers: apiHeaders).timeout(_timeout);
          break;
        default:
          throw UnsupportedError(method);
      }
      return response;
    } catch (e) {
      lastError = e;
      if (attempt < retries) {
        print('   ↻ 重试 ${attempt + 1}/$retries ($e)');
        await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
  }
  throw Exception('请求失败 $method $path: $lastError');
}

void main() async {
  print('🧪 后端 API 测试脚本');
  print('目标: $baseUrl');
  print('=' * 50);

  await testHealthCheck();
  await testAuth();
  await testMetrics();
  await testGetRecords();
  await testCreateRecord();
  await testGetLedgers();
  await testGetStaff();
  await testGetWorkContents();
  await testGetCategories();
  await testSync();
  await testDeletedRecordsEndpoint();

  print('\n✨ 所有测试完成！');
}

Future<void> testHealthCheck() async {
  print('\n📋 测试健康检查...');
  try {
    final response = await request('GET', '/api/v1/health');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ 健康检查通过: ${data['status']}');
      print('   数据库: ${data['database']}');
    } else {
      print('❌ 健康检查失败: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}

Future<void> testAuth() async {
  print('\n🔐 测试鉴权检查...');
  try {
    final response = await request('GET', '/api/v1/auth');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ 鉴权接口通过: authRequired=${data['authRequired']}');
    } else {
      print('❌ 鉴权接口失败: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    print('❌ 鉴权接口异常: $e');
  }
}

Future<void> testMetrics() async {
  print('\n📊 测试指标接口...');
  try {
    final response = await request('GET', '/api/v1/metrics');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ 指标获取成功');
      print('   记录数: ${data['database']['totalRecords']}');
    } else {
      print('❌ 指标获取失败: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}

Future<void> testGetRecords() async {
  print('\n📝 测试获取记录...');
  try {
    final response = await request('GET', '/api/v1/records');
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ 获取记录成功: ${data.length} 条记录');
    } else {
      print('❌ 获取记录失败: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}

Future<void> testCreateRecord() async {
  print('\n➕ 测试创建记录...');
  try {
    final testRecord = {
      'id': 'test-${DateTime.now().millisecondsSinceEpoch}',
      'date': DateTime.now().toUtc().toIso8601String(),
      'category': '测试类别',
      'workContent': '测试工作内容',
      'amount': 100.50,
      'ledger': '默认账本',
      'imageUrl': null,
      'staffIds': <String>[],
    };

    final response = await request('POST', '/api/v1/records', body: testRecord);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ 创建记录成功: ${data['recordId']} amount=${data['amount']}');
      await _cleanupRecord(data['recordId']);
    } else {
      print('❌ 创建记录失败: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}

Future<void> testGetLedgers() async {
  print('\n📒 测试获取账本...');
  try {
    final response = await request('GET', '/api/v1/ledgers');
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ 获取账本成功: ${data.join(", ")}');
    } else {
      print('❌ 获取账本失败: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}

Future<void> testGetStaff() async {
  print('\n👥 测试获取人员...');
  try {
    final response = await request('GET', '/api/v1/staff');
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ 获取人员成功: ${data.length} 人');
    } else {
      print('❌ 获取人员失败: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}

Future<void> testGetWorkContents() async {
  print('\n💼 测试获取工作内容...');
  try {
    final response = await request('GET', '/api/v1/work-contents');
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ 获取工作内容成功: ${data.length} 项');
    } else {
      print('❌ 获取工作内容失败: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}

Future<void> testGetCategories() async {
  print('\n🏷️ 测试获取类别...');
  try {
    final response = await request('GET', '/api/v1/categories');
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ 获取类别成功: ${data.length} 项');
    } else {
      print('❌ 获取类别失败: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}

Future<void> testSync() async {
  print('\n🔄 测试增量同步...');
  try {
    final response = await request('POST', '/api/v1/sync', body: {
      'lastSyncTime': null,
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ 增量同步成功');
      print('   记录数: ${(data['records'] as List).length}');
      print('   人员数: ${(data['staff'] as List).length}');
      print('   账本数: ${(data['ledgers'] as List).length}');
      print('   已删记录: ${(data['deletedRecordIds'] as List).length}');
      print('   已删人员: ${(data['deletedStaffIds'] as List).length}');
      print('   服务器时间: ${data['serverTime']}');
    } else {
      print('❌ 增量同步失败: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}

Future<void> testDeletedRecordsEndpoint() async {
  print('\n🗂️ 测试回收站接口...');
  try {
    final response = await request('GET', '/api/v1/records/deleted');
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      print('✅ 回收站接口正常: ${data.length} 条');
      for (final item in data.take(3)) {
        print('   - ${item['recordId']} amount=${item['amount']}');
      }
    } else {
      print('❌ 回收站接口失败: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 回收站接口异常: $e');
  }
}

Future<void> _cleanupRecord(String recordId) async {
  try {
    // 先软删再永久删（后端永久删除只处理 deleted_at IS NOT NULL）
    final soft = await request('DELETE', '/api/v1/records/$recordId');
    print('   soft-delete: ${soft.statusCode}');
    final hard =
        await request('DELETE', '/api/v1/records/$recordId/permanent');
    if (hard.statusCode == 204 || hard.statusCode == 200) {
      print('   🗑️ 已清理测试记录');
    } else {
      print('   ⚠️ 永久删除失败: ${hard.statusCode} ${hard.body}');
    }
  } catch (e) {
    print('   ⚠️ 清理测试记录失败: $e');
  }
}
