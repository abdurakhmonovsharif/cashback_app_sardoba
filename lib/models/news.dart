class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.imageUrl,
    this.startsAt,
    this.endsAt,
    this.priority = 0,
  });

  final int id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? imageUrl;
  final int priority;

  bool get isActive {
    final now = DateTime.now();
    final startOk = startsAt == null || !now.isBefore(startsAt!);
    final endOk = endsAt == null || !now.isAfter(endsAt!);
    return startOk && endOk;
  }

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      final text = value.toString();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return NewsItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      imageUrl: () {
        final raw = json['image_url'];
        if (raw is String) {
          final trimmed = raw.trim();
          if (trimmed.isNotEmpty) {
            return trimmed;
          }
        }
        return null;
      }(),
      startsAt: parseDate(json['starts_at']),
      endsAt: parseDate(json['ends_at']),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
    );
  }
}
