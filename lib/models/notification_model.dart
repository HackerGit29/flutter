import 'package:uuid/uuid.dart';

class NotificationModel {
  final String id;
  final String title;
  final String description;
  final String severity;
  final DateTime createdAt;
  final String userId;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.createdAt,
    required this.userId,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? const Uuid().v4(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      severity: json['severity'] ?? 'info',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      userId: json['user_id'] ?? '',
      isRead: json['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'severity': severity,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
      'is_read': isRead,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? description,
    String? severity,
    DateTime? createdAt,
    String? userId,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      isRead: isRead ?? this.isRead,
    );
  }
}