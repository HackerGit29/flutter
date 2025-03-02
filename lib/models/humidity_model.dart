class HumidityModel {
  final String id;
  final String deviceId;
  final double humidity;
  final DateTime createdAt;
  final String userId;

  HumidityModel({
    required this.id,
    required this.deviceId,
    required this.humidity,
    required this.createdAt,
    required this.userId,
  });

  factory HumidityModel.fromJson(Map<String, dynamic> json) {
    return HumidityModel(
      id: json['id'],
      deviceId: json['device_id'],
      humidity: (json['humidity'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      userId: json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'humidity': humidity,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
    };
  }
}