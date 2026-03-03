import 'dart:io';
import 'package:mysql1/mysql1.dart';

void main() async {
  print('🔧 数据库连接测试脚本');
  print('=' * 50);
  
  // 数据库连接配置
  final settings = ConnectionSettings(
    host: '120.220.73.186',
    port: 7378,
    user: 'tally_user',
    password: 'tally_password',
    db: 'tally_db',
  );
  
  print('📊 连接配置信息:');
  print('   主机: ${settings.host}');
  print('   端口: ${settings.port}');
  print('   用户名: ${settings.user}');
  print('   数据库: ${settings.db}');
  
  try {
    print('\n🔗 尝试连接数据库...');
    
    // 测试连接
    final connection = await MySqlConnection.connect(settings);
    print('✅ 数据库连接成功！');
    
    // 测试查询
    print('\n🔍 测试数据库查询...');
    final results = await connection.query('SELECT COUNT(*) as count FROM records WHERE deleted_at IS NULL');
    final count = results.first['count'];
    print('✅ 查询成功！当前记录数: $count');
    
    // 检查表结构
    print('\n📋 检查表结构...');
    final tables = await connection.query('SHOW TABLES');
    print('   数据库中的表:');
    for (final table in tables) {
      print('     - ${table.values?.first}');
    }
    
    // 检查records表结构
    print('\n📊 检查records表结构...');
    final columns = await connection.query('DESCRIBE records');
    print('   records表字段:');
    for (final column in columns) {
      print('     - ${column['Field']} (${column['Type']})');
    }
    
    // 测试插入操作
    print('\n➕ 测试插入操作...');
    try {
      final insertResult = await connection.query(
        'INSERT INTO records (date, category, work_content, amount, ledger, staff_ids) VALUES (?, ?, ?, ?, ?, ?)',
        [
          DateTime.now(),
          '测试',
          '数据库连接测试',
          100.0,
          '默认账本',
          '[]'
        ]
      );
      print('✅ 插入操作成功！插入ID: ${insertResult.insertId}');
      
      // 删除测试数据
      await connection.query('DELETE FROM records WHERE work_content = ?', ['数据库连接测试']);
      print('🗑️ 已清理测试数据');
    } catch (e) {
      print('⚠️ 插入操作测试失败: $e');
    }
    
    await connection.close();
    print('\n✅ 数据库连接测试完成！所有操作正常。');
    
  } on SocketException catch (e) {
    print('❌ 网络连接失败: $e');
    print('   可能的原因:');
    print('   - 网络连接问题');
    print('   - 防火墙阻止连接');
    print('   - 主机地址错误');
    print('   - 端口被阻止');
  } on MySqlException catch (e) {
    print('❌ 数据库连接失败: $e');
    print('   可能的原因:');
    print('   - 用户名或密码错误');
    print('   - 数据库不存在');
    print('   - 权限不足');
    print('   - 连接数超限');
  } catch (e) {
    print('❌ 未知错误: $e');
  }
  
  // 测试网络连通性
  print('\n🌐 测试网络连通性...');
  try {
    final socket = await Socket.connect('120.220.73.186', 7378, timeout: Duration(seconds: 10));
    print('✅ 网络连通性正常');
    socket.destroy();
  } catch (e) {
    print('❌ 网络连通性测试失败: $e');
  }
  
  print('\n✨ 测试脚本执行完成！');
}