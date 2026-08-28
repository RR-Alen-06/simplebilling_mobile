enum SyncStatus { pending, syncing, synced, failed }

class SyncTask {
  final String id;
  final String action;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final String? errorMessage;
  final DateTime createdAt;

  SyncTask({
    required this.id,
    required this.action,
    required this.payload,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  SyncTask copyWith({
    SyncStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SyncTask(
      id: id,
      action: action,
      payload: payload,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'payload': payload,
        'status': status.name,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SyncTask.fromJson(Map<String, dynamic> json) => SyncTask(
        id: json['id'] as String,
        action: json['action'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        status: SyncStatus.values.byName(json['status'] as String),
        errorMessage: json['errorMessage'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}