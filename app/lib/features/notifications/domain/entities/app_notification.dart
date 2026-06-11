class AppNotification {
  const AppNotification({
    required this.id,
    required this.createdAtIso,
    required this.title,
    required this.body,
    required this.type,
    required this.payload,
    this.isRead = false,
  });

  final String id;
  final String createdAtIso;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> payload;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      createdAtIso: createdAtIso,
      title: title,
      body: body,
      type: type,
      payload: payload,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAtIso,
        'title': title,
        'body': body,
        'type': type,
        'payload': payload,
        'is_read': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      createdAtIso: json['created_at'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? '',
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

