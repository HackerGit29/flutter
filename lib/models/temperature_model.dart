class TemperatureModel {
  final int id;
  final double? temperature;
  final DateTime createdAt;
  final DateTime updatedAt;

  TemperatureModel({
    required this.id,
    this.temperature,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TemperatureModel.fromJson(Map<String, dynamic> json) {
    return TemperatureModel(
      id: json['id'],
      temperature:
          json['temperature'] != null
              ? (json['temperature'] as num).toDouble()
              : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'temperature': temperature,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
