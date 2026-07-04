import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

String get baseUrl {
  final envUrl = Platform.environment['API_BASE_URL'];
  if (envUrl != null && envUrl.trim().isNotEmpty) {
    return envUrl.trim().replaceAll(RegExp(r'/\s*$'), '');
  }
  return 'http://127.0.0.1:7378';
}

void main() async {
  print('🧪 后端 API 测试脚本');
  print('=' * 50);

  await testHealthCheck();
  await testMetrics();
  await testGetRecords();
  await testCreateRecord();
  await testGetLedgers();
  await testGetStaff();
  await testGetWorkContents();
  await testGetCategories();
  await testSync();

  print('\n✨ 所有测试完成！');
}

Future<void> testHealthCheck() async {
  print('\n📋 测试健康检查...');
  try {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/health'));
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

Future<void> testMetrics() async {
  print('\n📊 测试指标接口...');
  try {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/metrics'));
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
    final response = await http.get(Uri.parse('$baseUrl/api/v1/records'));
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

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/records'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(testRecord),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ 创建记录成功: ${data['recordId']}');

      // 测试删除创建的记录
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
    final response = await http.get(Uri.parse('$baseUrl/api/v1/ledgers'));
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
    final response = await http.get(Uri.parse('$baseUrl/api/v1/staff'));
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
    final response = await http.get(Uri.parse('$baseUrl/api/v1/work-contents'));
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
    final response = await http.get(Uri.parse('$baseUrl/api/v1/categories'));
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
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/sync'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'lastSyncTime': null}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ 增量同步成功');
      print('   记录数: ${(data['records'] as List).length}');
      print('   人员数: ${(data['staff'] as List).length}');
      print('   账本数: ${(data['ledgers'] as List).length}');
      print('   服务器时间: ${data['serverTime']}');
    } else {
      print('❌ 增量同步失败: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}

Future<void> _cleanupRecord(String recordId) async {
  try {
    await http.delete(Uri.parse('$baseUrl/api/v1/records/$recordId/permanent'));
    print('   🗑️ 已清理测试记录');
  } catch (e) {
    print('   ⚠️ 清理测试记录失败: $e');
  }
}
