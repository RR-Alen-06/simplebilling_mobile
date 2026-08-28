import 'package:uuid/uuid.dart';

enum SyncStatus { pending, syncing, synced, failed }

class SyncTask {
  final String id;
  final String action;
  final String clientRef;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final String? errorMessage;
  final DateTime createdAt;

  SyncTask({
    required this.id,
    required this.action,
    String? clientRef,
    required this.payload,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  }) : clientRef = clientRef ?? (payload['client_ref'] as String? ?? const Uuid().v4());

  SyncTask copyWith({
    SyncStatus? status,
    String? errorMessage,
    bool clearError = false,
    Map<String, dynamic>? payload,
  }) {
    return SyncTask(
      id: id,
      action: action,
      clientRef: clientRef,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'clientRef': clientRef,
        'payload': payload,
        'status': status.name,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SyncTask.fromJson(Map<String, dynamic> json) => SyncTask(
        id: json['id'] as String,
        action: json['action'] as String,
        clientRef: json['clientRef'] as String? ?? json['payload']?['client_ref'] as String? ?? const Uuid().v4(),
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        status: SyncStatus.values.byName(json['status'] as String),
        errorMessage: json['errorMessage'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}