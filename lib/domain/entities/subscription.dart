enum SubscriptionType { free, vip }

class Subscription {
  final String id;
  final String userId;
  final SubscriptionType type;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool autoRenew;
  final DateTime createdAt;

  const Subscription({
    required this.id, required this.userId, required this.type,
    required this.startDate, this.endDate,
    required this.isActive, required this.autoRenew, required this.createdAt,
  });

  bool get isVip => type == SubscriptionType.vip;
  bool get isValid => isActive && (endDate == null || DateTime.now().isBefore(endDate!));

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    type: SubscriptionType.values.firstWhere((t) => t.name == json['type']),
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
    isActive: json['is_active'] as bool? ?? true,
    autoRenew: json['auto_renew'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'type': type.name, 'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(), 'is_active': isActive, 'auto_renew': autoRenew,
    'created_at': createdAt.toIso8601String(),
  };
}
