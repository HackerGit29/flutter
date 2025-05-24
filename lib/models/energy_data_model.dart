class EnergyDataModel {
  final int id;
  final double? totalDay;
  final double? totalWeek;
  final double? totalMonth;
  final double? totalYear;
  final DateTime? date;
  final int? week;
  final int? month;
  final int? year;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EnergyDataModel({
    required this.id,
    this.totalDay,
    this.totalWeek,
    this.totalMonth,
    this.totalYear,
    this.date,
    this.week,
    this.month,
    this.year,
    this.createdAt,
    this.updatedAt,
  });

  factory EnergyDataModel.fromJson(Map<String, dynamic> json) {
    return EnergyDataModel(
      id: json['id'],
     totalDay:
          json['total_day'] != null
              ? (json['total_day'] as num).toDouble()
              : null,
      totalWeek:
          json['total_week'] != null
              ? (json['total_week'] as num).toDouble()
              : null,
      totalMonth:
          json['total_month'] != null
              ? (json['total_month'] as num).toDouble()
              : null,
      totalYear:
          json['total_year'] != null
              ? (json['total_year'] as num).toDouble()
              : null,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      week: json['week'],
      month: json['month'],
      year: json['year'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'total_day': totalDay,
      'total_week': totalWeek,
      'total_month': totalMonth,
      'total_year': totalYear,
      'date': date?.toIso8601String(),
      'week': week,
      'month': month,
      'year': year,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
