import 'dart:convert';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.type,
    this.payload,
    this.language,
    this.isRead = false,
    this.isSent = false,
    this.sentAt,
  });

  final int id;
  final String title;
  final String description;
  final DateTime createdAt;
  final String? type;
  final Map<String, dynamic>? payload;
  final String? language;
  final bool isRead;
  final bool isSent;
  final DateTime? sentAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      final text = value?.toString() ?? '';
      return DateTime.tryParse(text) ?? DateTime.now();
    }

    Map<String, dynamic>? parsePayload(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is String && value.isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return AppNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdAt: parseDate(json['created_at']),
      type: (json['type'] ?? '').toString().isEmpty
          ? null
          : (json['type'] ?? '').toString(),
      payload: parsePayload(json['payload']),
      language: (json['language'] ?? '').toString().isEmpty
          ? null
          : (json['language'] ?? '').toString(),
      isRead: json['is_read'] == true,
      isSent: json['is_sent'] == true,
      sentAt: parseDate(json['sent_at']),
    );
  }
}
