class Staff {
  final String id;
  final String name;
  final bool isActive;
  final DateTime? updatedAt;

  Staff({
    required this.id,
    required this.name,
    this.isActive = true,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Staff.fromMap(Map<String, dynamic> map) {
    DateTime? updatedAt;
    if (map['updatedAt'] != null) {
      try {
        updatedAt = DateTime.parse(map['updatedAt'] as String);
      } catch (e) {
        updatedAt = null;
      }
    }
    
    return Staff(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      isActive: map['isActive'] ?? true,
      updatedAt: updatedAt,
    );
  }

  Staff copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}