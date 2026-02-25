class Staff {
  final String id;
  final String name;
  final bool isActive;

  Staff({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive,
    };
  }

  factory Staff.fromMap(Map<String, dynamic> map) {
    return Staff(
      id: map['id'],
      name: map['name'],
      isActive: map['isActive'] ?? true,
    );
  }

  Staff copyWith({
    String? id,
    String? name,
    bool? isActive,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }
}