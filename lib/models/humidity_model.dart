class HumidityModel {
  final int id;
  final double? humidity;
  final DateTime createdAt;
  final DateTime updatedAt;

  HumidityModel({
    required this.id,
    this.humidity,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HumidityModel.fromJson(Map<String, dynamic> json) {
    return HumidityModel(
      id: json['id'],
      humidity:
          json['humidity'] != null
              ? (json['humidity'] as num).toDouble()
              : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'humidity': humidity,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
