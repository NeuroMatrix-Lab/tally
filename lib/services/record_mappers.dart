import 'dart:convert';

import '../models/record.dart';

class RecordMappers {
  static Record fromLocalMap(Map<String, dynamic> row) {
    return _fromSnakeCase(row);
  }

  static Record fromDeletedMap(Map<String, dynamic> row) {
    return _fromSnakeCase(row);
  }

  static Record _fromSnakeCase(Map<String, dynamic> row) {
    List<String> staffIds = [];
    if (row['staff_ids'] != null) {
      try {
        staffIds = List<String>.from(json.decode(row['staff_ids'] as String));
      } catch (e) {
        staffIds = [];
      }
    }

    return Record.fromMap({
      'id': row['record_id']?.toString() ?? row['id'].toString(),
      'recordId': row['record_id']?.toString() ?? '',
      'date': row['date'],
      'category': row['category'],
      'workContent': row['work_content'],
      'amount': row['amount'],
      'ledger': row['ledger'],
      'imageUrl': row['image_url'],
      'staffIds': staffIds,
    });
  }

  static Record fromDbRow(dynamic row) {
    String dateString;
    if (row['date'] is DateTime) {
      dateString = (row['date'] as DateTime).toIso8601String();
    } else {
      dateString = row['date'].toString();
    }

    double amount;
    if (row['amount'] is double) {
      amount = row['amount'];
    } else if (row['amount'] is int) {
      amount = (row['amount'] as int).toDouble();
    } else {
      amount = double.tryParse(row['amount'].toString()) ?? 0.0;
    }

    List<String> staffIds = [];
    if (row['staff_ids'] != null) {
      try {
        final staffIdsStr = row['staff_ids'].toString();
        if (staffIdsStr.isNotEmpty) {
          staffIds = List<String>.from(json.decode(staffIdsStr));
        }
      } catch (e) {
        staffIds = [];
      }
    }

    return Record.fromMap({
      'id': row['record_id']?.toString() ?? row['id'].toString(),
      'recordId': row['record_id']?.toString() ?? '',
      'date': dateString,
      'category': row['category']?.toString() ?? '',
      'workContent': row['work_content']?.toString() ?? '',
      'amount': amount,
      'ledger': row['ledger']?.toString() ?? '',
      'imageUrl': row['image_url']?.toString(),
      'staffIds': staffIds,
    });
  }
}
