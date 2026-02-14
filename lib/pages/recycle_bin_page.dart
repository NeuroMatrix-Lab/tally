import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';

class RecycleBinPage extends StatelessWidget {
  final List<Record> deletedRecords;
  final Function(Record record) onRestore;
  final VoidCallback onClose;

  const RecycleBinPage({
    super.key,
    required this.deletedRecords,
    required this.onRestore,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('回收站'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onClose,
        ),
      ),
      body: deletedRecords.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('回收站为空', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: deletedRecords.length,
              itemBuilder: (context, index) {
                final record = deletedRecords[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(record.workContent),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('yyyy-MM-dd').format(record.date)),
                        Text(
                          record.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '¥${record.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.restore, color: Colors.green),
                          onPressed: () => onRestore(record),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
