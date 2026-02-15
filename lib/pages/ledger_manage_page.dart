import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LedgerManagePage extends StatefulWidget {
  final List<String> ledgers;
  final Function(List<String>) onLedgersUpdated;
  final String defaultLedger;

  const LedgerManagePage({
    super.key,
    required this.ledgers,
    required this.onLedgersUpdated,
    required this.defaultLedger,
  });

  @override
  State<LedgerManagePage> createState() => _LedgerManagePageState();
}

class _LedgerManagePageState extends State<LedgerManagePage> {
  late List<String> _ledgers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ledgers = List.from(widget.ledgers);
  }

  Future<void> _addLedger() async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加账本'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入账本名称',
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

    if (result != null && result.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ApiService.createLedger(result);
        setState(() {
          _ledgers.add(result);
          _isLoading = false;
        });
        widget.onLedgersUpdated(_ledgers);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('账本添加成功')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _editLedger(String oldName) async {
    final TextEditingController controller = TextEditingController(text: oldName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑账本'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入新的账本名称',
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
              if (name.isNotEmpty && name != oldName) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != oldName) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ApiService.updateLedger(oldName, result);
        setState(() {
          final index = _ledgers.indexOf(oldName);
          if (index != -1) {
            _ledgers[index] = result;
          }
          _isLoading = false;
        });
        widget.onLedgersUpdated(_ledgers);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('账本更新成功')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteLedger(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除账本"$name"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ApiService.deleteLedger(name);
        setState(() {
          _ledgers.remove(name);
          _isLoading = false;
        });
        widget.onLedgersUpdated(_ledgers);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('账本删除成功')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _syncLedgers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final syncedLedgers = await ApiService.syncLedgers();
      setState(() {
        for (final ledger in _ledgers) {
          if (!syncedLedgers.contains(ledger)) {
            syncedLedgers.add(ledger);
          }
        }
        _ledgers = syncedLedgers;
        _isLoading = false;
      });
      widget.onLedgersUpdated(_ledgers);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('账本同步成功')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('账本管理'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _syncLedgers,
              tooltip: '同步账本',
            ),
        ],
      ),
      body: _ledgers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '暂无账本',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '点击下方按钮添加第一个账本',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _ledgers.length,
              itemBuilder: (context, index) {
                final ledger = _ledgers[index];
                final isDefault = ledger == widget.defaultLedger;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDefault
                          ? Colors.blue
                          : Colors.grey.shade300,
                      child: Icon(
                        Icons.book,
                        color: isDefault ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                    title: Text(
                      ledger,
                      style: TextStyle(
                        fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: isDefault
                        ? const Text(
                            '默认账本',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editLedger(ledger),
                          tooltip: '编辑',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _deleteLedger(ledger),
                          tooltip: '删除',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLedger,
        child: const Icon(Icons.add),
      ),
    );
  }
}
