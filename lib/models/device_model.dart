class DeviceModel {
  final String id;
  final String name;
  final String location;
  final String userId;
  final DateTime createdAt;

  DeviceModel({
    required this.id,
    required this.name,
    required this.location,
    required this.userId,
    required this.createdAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    String? location,
    String? userId,
    DateTime? createdAt,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}