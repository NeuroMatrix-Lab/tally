import 'package:flutter/material.dart';
import '../models/staff.dart';
import '../services/api_service.dart';

class StaffSelectionPage extends StatefulWidget {
  final List<String> selectedStaffIds;
  final List<Staff> staffList;
  final Function() onStaffListUpdated;
  
  const StaffSelectionPage({
    super.key,
    required this.selectedStaffIds,
    required this.staffList,
    required this.onStaffListUpdated,
  });

  @override
  State<StaffSelectionPage> createState() => _StaffSelectionPageState();
}

class _StaffSelectionPageState extends State<StaffSelectionPage> {
  List<String> _selectedStaffIds = [];
  List<Staff> _localStaffList = [];

  @override
  void initState() {
    super.initState();
    _selectedStaffIds = List.from(widget.selectedStaffIds);
    _localStaffList = List.from(widget.staffList);
  }



  void _toggleStaffSelection(String staffId) {
    setState(() {
      if (_selectedStaffIds.contains(staffId)) {
        _selectedStaffIds.remove(staffId);
      } else {
        _selectedStaffIds.add(staffId);
      }
    });
  }

  Future<void> _addStaff() async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加人员'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入人员姓名',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        await ApiService.addStaff(result);
        // 重新从服务器获取人员列表
        final updatedStaffList = await ApiService.getStaffList();
        setState(() {
          _localStaffList = updatedStaffList;
        });
        widget.onStaffListUpdated();
        _showSuccessMessage('添加人员成功');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加人员失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _editStaff(Staff staff) async {
    final TextEditingController controller = TextEditingController(text: staff.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑人员'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入人员姓名',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        await ApiService.updateStaff(staff.id, result);
        // 重新从服务器获取人员列表
        final updatedStaffList = await ApiService.getStaffList();
        setState(() {
          _localStaffList = updatedStaffList;
        });
        widget.onStaffListUpdated();
        _showSuccessMessage('编辑人员成功');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('编辑人员失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteStaff(Staff staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除人员"${staff.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService.deleteStaff(staff.id);
        // 重新从服务器获取人员列表
        final updatedStaffList = await ApiService.getStaffList();
        setState(() {
          _localStaffList = updatedStaffList;
          _selectedStaffIds.remove(staff.id);
        });
        widget.onStaffListUpdated();
        _showSuccessMessage('删除人员成功');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除人员失败: $e')),
          );
        }
      }
    }
  }

  void _saveAndReturn() {
    Navigator.pop(context, _selectedStaffIds);
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _syncStaffList() async {
    try {
      // 重新从服务器获取人员列表
      final updatedStaffList = await ApiService.getStaffList();
      setState(() {
        _localStaffList = updatedStaffList;
      });
      widget.onStaffListUpdated();
      _showSuccessMessage('同步人员列表成功');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    }
  }

  Widget _buildStaffItem(Staff staff) {
    final isSelected = _selectedStaffIds.contains(staff.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (value) => _toggleStaffSelection(staff.id),
        ),
        title: Text(staff.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editStaff(staff),
              tooltip: '编辑',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteStaff(staff),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择参与人员'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncStaffList,
            tooltip: '同步人员列表',
          ),
          TextButton(
            onPressed: _saveAndReturn,
            child: const Text('确认', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '已选择 ${_selectedStaffIds.length} 人',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _localStaffList.isEmpty
                ? const Center(
                    child: Text(
                      '暂无人员，请点击右下角加号添加',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _localStaffList.length,
                    itemBuilder: (context, index) {
                      return _buildStaffItem(_localStaffList[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStaff,
        child: const Icon(Icons.add),
      ),
    );
  }
}