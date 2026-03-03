import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysql1/mysql1.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _ipController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;
  String _connectionStatus = '未测试';
  Color _statusColor = Colors.grey;
  
  // 添加状态重置方法
  void _resetStatus() {
    setState(() {
      _connectionStatus = '未测试';
      _statusColor = Colors.grey;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // 延迟自动测试连接
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _autoTestConnection();
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final serverIp = prefs.getString('serverIp') ?? '';
    setState(() {
      _ipController.text = serverIp;
    });
  }
  
  // 自动测试连接
  Future<void> _autoTestConnection() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    
    try {
      // 直接测试MariaDB数据库连接
      final settings = ConnectionSettings(
        host: ip,
        port: 7378,
        user: 'tally_user',
        password: 'tally_password',
        db: 'tally_db',
      );
      
      final conn = await MySqlConnection.connect(settings).timeout(
        const Duration(seconds: 3),
      );
      
      // 测试数据库查询
      final result = await conn.query('SELECT COUNT(*) FROM ledgers');
      final count = result.first.first as int;
      
      await conn.close();

      if (mounted) {
        setState(() {
          _connectionStatus = '连接正常 (账本数: $count)';
          _statusColor = Colors.green;
        });
      }
    } catch (e) {
      // 自动测试失败时不显示错误，保持灰色状态
      if (mounted) {
        setState(() {
          _connectionStatus = '未测试';
          _statusColor = Colors.grey;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入服务器IP地址')),
      );
      return;
    }

    // 重置状态
    _resetStatus();
    
    setState(() {
      _isTesting = true;
      _connectionStatus = '测试中...';
      _statusColor = Colors.orange;
    });

    try {
      // 直接测试MariaDB数据库连接
      final settings = ConnectionSettings(
        host: ip,
        port: 7378,
        user: 'tally_user',
        password: 'tally_password',
        db: 'tally_db',
      );
      
      final conn = await MySqlConnection.connect(settings).timeout(
        const Duration(seconds: 5),
      );
      
      // 测试数据库查询
      final result = await conn.query('SELECT COUNT(*) FROM ledgers');
      final count = result.first.first as int;
      
      await conn.close();

      setState(() {
        _connectionStatus = '连接成功 (账本数: $count)';
        _statusColor = Colors.green;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = '连接失败: ${e.toString().split(':').first}';
          _statusColor = Colors.red;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入服务器IP地址')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('serverIp', ip);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Text(
              '设置',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: '后端服务器IP地址',
                hintText: '',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            const Text(
              '默认端口: 7378',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.wifi),
                    label: Text(_isTesting ? '测试中...' : '连接测试'),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusColor == Colors.green
                            ? Icons.check_circle
                            : _statusColor == Colors.red
                                ? Icons.error
                                : Icons.info,
                        size: 16,
                        color: _statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _connectionStatus,
                        style: TextStyle(
                          fontSize: 14,
                          color: _statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveSettings,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isLoading ? '保存中...' : '保存设置'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.cancel),
              label: const Text('取消'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}