class EnergyData {
  final String id;
  final String userId;
  final String applianceId;
  final DateTime date;
  final double kwh;
  final double? cumulativeKwh;
  final int week;
  final int month;
  final int year;
  final DateTime createdAt;

  const EnergyData({
    required this.id,
    required this.userId,
    required this.applianceId,
    required this.date,
    this.kwh = 0,
    this.cumulativeKwh,
    required this.week,
    required this.month,
    required this.year,
    required this.createdAt,
  });

  factory EnergyData.fromJson(Map<String, dynamic> json) => EnergyData(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    applianceId: json['appliance_id'] as String,
    date: DateTime.parse(json['date'] as String),
    kwh: (json['kwh'] as num?)?.toDouble() ?? 0,
    cumulativeKwh: (json['cumulative_kwh'] as num?)?.toDouble(),
    week: json['week'] as int,
    month: json['month'] as int,
    year: json['year'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'appliance_id': applianceId,
    'date': date.toIso8601String(),
    'kwh': kwh, 'cumulative_kwh': cumulativeKwh,
    'week': week, 'month': month, 'year': year,
    'created_at': createdAt.toIso8601String(),
  };
}
