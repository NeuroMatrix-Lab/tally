import 'package:flutter/material.dart';
import 'UI/operation_log.dart';
import 'UI/audit_page.dart';
import 'UI/tally_page.dart';

void main() {
  runApp(MaterialApp(home: HomeScreen()));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    TallyPage(),
    AuditPage(),
    OperationLogPage(),

  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Tally',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'sans-serif',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: Colors.white,
            onPressed: () {
              // 登出逻辑，跳转到登录页
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),

      // 显示当前选中的页面，SafeArea适配安全区
      body: SafeArea(child: _screens[_currentIndex]),
      bottomNavigationBar: MediaQuery.removePadding(
        context: context,
        removeBottom: true, // 移除底部安全区padding
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, // 5个项必须设为fixed
          currentIndex: _currentIndex, // 当前选中索引
          iconSize: 22, // 图标大小
          selectedFontSize: 11, // 选中文字大小
          unselectedFontSize: 10, // 未选中文字大小
          selectedItemColor: Colors.green, // 选中颜色
          unselectedItemColor: Colors.grey.shade600, // 未选中颜色
          backgroundColor: Colors.white, // 背景色
          showSelectedLabels: true, // 显示选中文字
          showUnselectedLabels: true, // 显示未选中文字
          // 点击切换
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          // 导航项配置
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '记账',
              activeIcon: Icon(Icons.home_filled),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder),
              label: '查账',
              activeIcon: Icon(Icons.folder_open),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome),
              label: '操作记录',
              activeIcon: Icon(Icons.auto_awesome_outlined),
            ),
          ]
        ),
      ),
    );
  }
}

