class AuditLogModel {
  final String id;
  final String? userId;
  final String userName;
  final String action;
  final String entity;
  final String? previousValue;
  final String? newValue;
  final String createdAt;

  AuditLogModel({
    required this.id,
    this.userId,
    this.userName = 'Admin',
    required this.action,
    required this.entity,
    this.previousValue,
    this.newValue,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String? ?? 'Admin',
      action: json['action'] as String? ?? 'ACTION',
      entity: json['entity'] as String? ?? 'Entity',
      previousValue: json['previous_value'] as String?,
      newValue: json['new_value'] as String?,
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'user_name': userName,
      'action': action,
      'entity': entity,
      if (previousValue != null) 'previous_value': previousValue,
      if (newValue != null) 'new_value': newValue,
      'created_at': createdAt,
    };
  }
}
