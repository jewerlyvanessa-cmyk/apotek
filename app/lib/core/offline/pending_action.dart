class PendingAction {
  const PendingAction({
    required this.id,
    required this.createdAtIso,
    required this.type,
    required this.payload,
    this.status = 'QUEUED',
    this.attempts = 0,
    this.lastHttpStatus,
    this.lastError,
    this.updatedAtIso,
  });

  final String id;
  final String createdAtIso;
  final String type;
  final Map<String, dynamic> payload;
  final String status; // QUEUED | CONFLICT | FAILED
  final int attempts;
  final int? lastHttpStatus;
  final String? lastError;
  final String? updatedAtIso;

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAtIso,
        'type': type,
        'payload': payload,
        'status': status,
        'attempts': attempts,
        'last_http_status': lastHttpStatus,
        'last_error': lastError,
        'updated_at': updatedAtIso,
      };

  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: json['id'] as String? ?? '',
      createdAtIso: json['created_at'] as String? ?? '',
      type: json['type'] as String? ?? '',
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      status: json['status'] as String? ?? 'QUEUED',
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastHttpStatus: (json['last_http_status'] as num?)?.toInt(),
      lastError: json['last_error'] as String?,
      updatedAtIso: json['updated_at'] as String?,
    );
  }

  PendingAction copyWith({
    String? status,
    int? attempts,
    int? lastHttpStatus,
    String? lastError,
    String? updatedAtIso,
    Map<String, dynamic>? payload,
  }) {
    return PendingAction(
      id: id,
      createdAtIso: createdAtIso,
      type: type,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastHttpStatus: lastHttpStatus ?? this.lastHttpStatus,
      lastError: lastError ?? this.lastError,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }
}

