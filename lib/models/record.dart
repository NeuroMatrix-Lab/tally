import 'dart:convert';

class Record {
  final String id;
  final DateTime date;
  final String workContent;
  final double amount;
  final String category;
  final String ledger;
  final String? imageUrl;
  final List<String> staffIds;

  Record({
    required this.id,
    required this.date,
    required this.workContent,
    required this.amount,
    required this.category,
    required this.ledger,
    this.imageUrl,
    this.staffIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'recordId': id,
      'date': date.toIso8601String(),
      'workContent': workContent,
      'amount': amount,
      'category': category,
      'ledger': ledger,
      'imageUrl': imageUrl,
      'staffIds': staffIds,
    };
  }

  factory Record.fromMap(Map<String, dynamic> map) {
    // 处理id字段
    String idValue;
    if (map['recordId'] != null) {
      idValue = map['recordId'].toString();
    } else if (map['id'] != null) {
      idValue = map['id'].toString();
    } else {
      idValue = DateTime.now().millisecondsSinceEpoch.toString();
    }
    
    // 处理日期字段
    DateTime dateValue;
    try {
      dateValue = DateTime.parse(map['date'].toString());
    } catch (e) {
      dateValue = DateTime.now();
    }
    
    // 处理金额字段
    double amountValue;
    if (map['amount'] is double) {
      amountValue = map['amount'];
    } else if (map['amount'] is int) {
      amountValue = (map['amount'] as int).toDouble();
    } else if (map['amount'] is String) {
      amountValue = double.tryParse(map['amount']) ?? 0.0;
    } else {
      amountValue = 0.0;
    }
    
    // 处理staffIds字段
    List<String> staffIds = [];
    if (map['staffIds'] != null) {
      if (map['staffIds'] is List) {
        staffIds = List<String>.from(map['staffIds'].map((item) => item.toString()));
      } else if (map['staffIds'] is String) {
        try {
          staffIds = List<String>.from(json.decode(map['staffIds']));
        } catch (e) {
          staffIds = [];
        }
      }
    }
    
    return Record(
      id: idValue,
      date: dateValue,
      workContent: map['workContent']?.toString() ?? '',
      amount: amountValue,
      category: map['category']?.toString() ?? '其他',
      ledger: map['ledger']?.toString() ?? '默认账本',
      imageUrl: map['imageUrl']?.toString(),
      staffIds: staffIds,
    );
  }

  String toJson() => json.encode(toMap());

  factory Record.fromJson(String source) => Record.fromMap(json.decode(source));
}
