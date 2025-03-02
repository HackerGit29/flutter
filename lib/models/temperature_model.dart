class TemperatureModel {
  final String id;
  final String deviceId;
  final double temperature;
  final DateTime createdAt;
  final String userId;

  TemperatureModel({
    required this.id,
    required this.deviceId,
    required this.temperature,
    required this.createdAt,
    required this.userId,
  });

  factory TemperatureModel.fromJson(Map<String, dynamic> json) {
    return TemperatureModel(
      id: json['id'],
      deviceId: json['device_id'],
      temperature: (json['temperature'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      userId: json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'temperature': temperature,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
    };
  }
}