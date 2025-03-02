class EnergyDataModel {
  final String id;
  final String deviceId;
  final double consumption;
  final bool status;
  final DateTime createdAt;
  final String userId;

  EnergyDataModel({
    required this.id,
    required this.deviceId,
    required this.consumption,
    required this.status,
    required this.createdAt,
    required this.userId,
  });

  factory EnergyDataModel.fromJson(Map<String, dynamic> json) {
    return EnergyDataModel(
      id: json['id'],
      deviceId: json['device_id'],
      consumption: (json['consumption'] as num).toDouble(),
      status: json['status'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      userId: json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'consumption': consumption,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
    };
  }
}