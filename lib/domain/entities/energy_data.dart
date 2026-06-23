class EnergyData {
  final String id;
  final String userId;
  final String applianceId;
  final DateTime date;
  final double totalDay;
  final double totalWeek;
  final double totalMonth;
  final double totalYear;
  final int week;
  final int month;
  final int year;
  final DateTime createdAt;

  const EnergyData({
    required this.id,
    required this.userId,
    required this.applianceId,
    required this.date,
    this.totalDay = 0,
    this.totalWeek = 0,
    this.totalMonth = 0,
    this.totalYear = 0,
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
    totalDay: (json['total_day'] as num?)?.toDouble() ?? 0,
    totalWeek: (json['total_week'] as num?)?.toDouble() ?? 0,
    totalMonth: (json['total_month'] as num?)?.toDouble() ?? 0,
    totalYear: (json['total_year'] as num?)?.toDouble() ?? 0,
    week: json['week'] as int,
    month: json['month'] as int,
    year: json['year'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'appliance_id': applianceId,
    'date': date.toIso8601String(),
    'total_day': totalDay, 'total_week': totalWeek,
    'total_month': totalMonth, 'total_year': totalYear,
    'week': week, 'month': month, 'year': year,
    'created_at': createdAt.toIso8601String(),
  };
}
