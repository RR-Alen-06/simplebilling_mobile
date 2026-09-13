class AuditLogModel {
  final String id;
  final String auditNumber;
  final String? userId;
  final String userName;
  final String action;
  final String entity;
  final String? previousValue;
  final String? newValue;
  final String createdAt;

  AuditLogModel({
    required this.id,
    String? auditNumber,
    this.userId,
    this.userName = 'Super Admin',
    required this.action,
    required this.entity,
    this.previousValue,
    this.newValue,
    required this.createdAt,
  }) : auditNumber = auditNumber ?? 'AUDIT-${id.length >= 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase()}';

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] as String? ?? '000001';
    final auditNum = json['audit_number'] as String? ??
        (rawId.startsWith('AUDIT')
            ? rawId
            : 'AUDIT-${rawId.length >= 6 ? rawId.substring(0, 6).toUpperCase() : rawId.toUpperCase()}');

    return AuditLogModel(
      id: rawId,
      auditNumber: auditNum,
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String? ?? 'Super Admin',
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
      'audit_number': auditNumber,
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
