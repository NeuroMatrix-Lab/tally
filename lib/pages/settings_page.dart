import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart';

enum ConnectionMode {
  local,
  backend,
  database,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ConnectionMode _selectedMode = ConnectionMode.local;
  bool _isLoading = false;

  // 后端服务模式配置
  final TextEditingController _backendIpController = TextEditingController();
  final TextEditingController _backendPortController = TextEditingController();

  // 数据库直通模式配置
  final TextEditingController _dbHostController = TextEditingController();
  final TextEditingController _dbPortController = TextEditingController();
  final TextEditingController _dbUserController = TextEditingController();
  final TextEditingController _dbPasswordController = TextEditingController();
  final TextEditingController _dbNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('connectionMode') ?? 0;
    setState(() {
      _selectedMode = ConnectionMode.values[modeIndex];
      _backendIpController.text = prefs.getString('backendIp') ?? '';
      _backendPortController.text = prefs.getString('backendPort') ?? '7378';
      _dbHostController.text = prefs.getString('dbHost') ?? '';
      _dbPortController.text = prefs.getString('dbPort') ?? '3306';
      _dbUserController.text = prefs.getString('dbUser') ?? '';
      _dbPasswordController.text = prefs.getString('dbPassword') ?? '';
      _dbNameController.text = prefs.getString('dbName') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('connectionMode', _selectedMode.index);
      await prefs.setString('backendIp', _backendIpController.text.trim());
      await prefs.setString('backendPort', _backendPortController.text.trim());
      await prefs.setString('dbHost', _dbHostController.text.trim());
      await prefs.setString('dbPort', _dbPortController.text.trim());
      await prefs.setString('dbUser', _dbUserController.text.trim());
      await prefs.setString('dbPassword', _dbPasswordController.text.trim());
      await prefs.setString('dbName', _dbNameController.text.trim());

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

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String message;
      bool success = false;

      if (_selectedMode == ConnectionMode.backend) {
        final ip = _backendIpController.text.trim();
        final port = _backendPortController.text.trim();
        
        if (ip.isEmpty) {
          message = '请输入服务器地址';
        } else {
          try {
            final response = await http.get(
              Uri.parse('http://$ip:$port/health'),
            ).timeout(
              const Duration(seconds: 10),
            );
            
            if (response.statusCode == 200) {
              message = '连接成功！服务器正常运行';
              success = true;
            } else {
              message = '连接失败：服务器返回状态码 ${response.statusCode}';
            }
          } catch (e) {
            message = '连接失败：无法连接到服务器\n错误: $e';
          }
        }
      } else if (_selectedMode == ConnectionMode.database) {
        final host = _dbHostController.text.trim();
        final portStr = _dbPortController.text.trim();
        final dbName = _dbNameController.text.trim();
        final user = _dbUserController.text.trim();
        final password = _dbPasswordController.text.trim();
        
        if (host.isEmpty || dbName.isEmpty || user.isEmpty) {
          message = '请填写完整的数据库连接信息';
        } else {
          try {
            final port = int.tryParse(portStr) ?? 3306;
            
            final settings = ConnectionSettings(
              host: host,
              port: port,
              user: user,
              password: password,
              db: dbName,
              timeout: Duration(seconds: 10),
            );
            
            final connection = await MySqlConnection.connect(settings);
            await connection.close();
            
            message = '数据库连接成功！';
            success = true;
          } catch (e) {
            message = '数据库连接失败：$e';
          }
        }
      } else {
        message = '本地模式无需测试连接';
        success = true;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('测试失败: $e'),
            backgroundColor: Colors.red,
          ),
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
    _backendIpController.dispose();
    _backendPortController.dispose();
    _dbHostController.dispose();
    _dbPortController.dispose();
    _dbUserController.dispose();
    _dbPasswordController.dispose();
    _dbNameController.dispose();
    super.dispose();
  }

  Widget _buildModeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '连接模式',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildModeOption(
              ConnectionMode.local,
              '本地模式',
              '数据存储在本地设备',
              Icons.phone_android,
            ),
            const Divider(),
            _buildModeOption(
              ConnectionMode.backend,
              '后端服务模式',
              '连接自定义后端API服务器',
              Icons.cloud,
            ),
            const Divider(),
            _buildModeOption(
              ConnectionMode.database,
              '数据库直通模式',
              '直接连接MySQL/MariaDB数据库',
              Icons.storage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(
    ConnectionMode mode,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = mode;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Radio<ConnectionMode>(
              value: mode,
              groupValue: _selectedMode,
              onChanged: (value) {
                setState(() {
                  _selectedMode = value!;
                });
              },
            ),
            Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackendSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '后端服务器配置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _backendIpController,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: '例如: 192.168.1.100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _backendPortController,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '例如: 8080',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据库配置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dbHostController,
              decoration: const InputDecoration(
                labelText: '数据库主机',
                hintText: '例如: 192.168.1.100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.storage),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dbPortController,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '例如: 3306',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dbNameController,
              decoration: const InputDecoration(
                labelText: '数据库名称',
                hintText: '例如: tally_db',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dbUserController,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '数据库用户名',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dbPasswordController,
              decoration: const InputDecoration(
                labelText: '密码',
                hintText: '数据库密码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              keyboardType: TextInputType.text,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeDescription() {
    String description;
    switch (_selectedMode) {
      case ConnectionMode.local:
        description = '本地模式：所有数据将存储在设备本地，无需网络连接。';
        break;
      case ConnectionMode.backend:
        description = '后端服务模式：通过API连接自定义后端服务器，需要配置服务器地址和端口。';
        break;
      case ConnectionMode.database:
        description = '数据库直通模式：直接连接MySQL/MariaDB数据库，需要配置完整的数据库连接信息。';
        break;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeSelector(),
            const SizedBox(height: 16),
            _buildModeDescription(),
            const SizedBox(height: 16),
            if (_selectedMode == ConnectionMode.backend) _buildBackendSettings(),
            if (_selectedMode == ConnectionMode.database) _buildDatabaseSettings(),
            const SizedBox(height: 24),
            if (_selectedMode != ConnectionMode.local)
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _testConnection,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(_isLoading ? '测试中...' : '测试连接'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            if (_selectedMode != ConnectionMode.local) const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
