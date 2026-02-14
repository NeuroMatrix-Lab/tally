class OperationLog {
  final String id;
  final DateTime timestamp;
  final String type;
  final String description;
  final String? details;

  OperationLog({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.description,
    this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type,
      'description': description,
      'details': details,
    };
  }

  factory OperationLog.fromMap(Map<String, dynamic> map) {
    return OperationLog(
      id: map['id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      type: map['type'] as String,
      description: map['description'] as String,
      details: map['details'] as String?,
    );
  }
}
