import 'dart:convert';

class Record {
  final String id;
  final DateTime date;
  final String workContent;
  final double amount;
  final String category;
  final String ledger;
  final String? imageUrl;

  Record({
    required this.id,
    required this.date,
    required this.workContent,
    required this.amount,
    required this.category,
    required this.ledger,
    this.imageUrl,
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
    };
  }

  factory Record.fromMap(Map<String, dynamic> map) {
    return Record(
      id: map['recordId'] ?? map['id'],
      date: DateTime.parse(map['date']),
      workContent: map['workContent'],
      amount: map['amount'],
      category: map['category'] ?? '其他',
      ledger: map['ledger'] ?? '默认账本',
      imageUrl: map['imageUrl'],
    );
  }

  String toJson() => json.encode(toMap());

  factory Record.fromJson(String source) => Record.fromMap(json.decode(source));
}
