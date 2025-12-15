class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String description;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      final text = value?.toString() ?? '';
      return DateTime.tryParse(text) ?? DateTime.now();
    }

    return AppNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdAt: parseDate(json['created_at']),
    );
  }
}
