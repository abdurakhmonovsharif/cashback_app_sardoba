class LoyaltySummary {
  const LoyaltySummary({
    this.level,
    this.currentPoints,
    this.currentLevelMin,
    this.currentLevelMax,
    this.currentLevelPoints,
    this.nextLevel,
    this.nextLevelPoints,
    this.pointsToNext,
    this.isMaxLevel = false,
    this.cashbackPercent,
    this.nextLevelCashbackPercent,
    this.cashbackBalance,
  });

  final String? level;
  final double? currentPoints;
  final double? currentLevelMin;
  final double? currentLevelMax;
  final double? currentLevelPoints;
  final String? nextLevel;
  final double? nextLevelPoints;
  final double? pointsToNext;
  final bool isMaxLevel;
  final double? cashbackPercent;
  final double? nextLevelCashbackPercent;
  final double? cashbackBalance;

  factory LoyaltySummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LoyaltySummary();
    return LoyaltySummary(
      level: json['level'] as String?,
      currentPoints: _firstDouble(
        json,
        ['current_points', 'points_total'],
      ),
      currentLevelMin: _firstDouble(
        json,
        ['current_level_min', 'current_level_min_points'],
      ),
      currentLevelMax: _firstDouble(
        json,
        ['current_level_max', 'current_level_max_points'],
      ),
      currentLevelPoints: _firstDouble(
        json,
        ['current_level_points'],
      ),
      nextLevel: json['next_level'] as String?,
      nextLevelPoints: _firstDouble(
        json,
        ['next_level_points', 'next_level_required_points'],
      ),
      pointsToNext: _firstDouble(
        json,
        ['points_to_next', 'points_to_next_level'],
      ),
      isMaxLevel: json['is_max_level'] as bool? ?? false,
      cashbackPercent: _firstDouble(json, ['cashback_percent']),
      nextLevelCashbackPercent:
          _firstDouble(json, ['next_level_cashback_percent']),
      cashbackBalance: _firstDouble(json, ['cashback_balance']),
    );
  }

  LoyaltySummary copyWith({
    String? level,
    double? currentPoints,
    double? currentLevelMin,
    double? currentLevelMax,
    double? currentLevelPoints,
    String? nextLevel,
    double? nextLevelPoints,
    double? pointsToNext,
    bool? isMaxLevel,
    double? cashbackPercent,
    double? nextLevelCashbackPercent,
    double? cashbackBalance,
  }) {
    return LoyaltySummary(
      level: level ?? this.level,
      currentPoints: currentPoints ?? this.currentPoints,
      currentLevelMin: currentLevelMin ?? this.currentLevelMin,
      currentLevelMax: currentLevelMax ?? this.currentLevelMax,
      currentLevelPoints: currentLevelPoints ?? this.currentLevelPoints,
      nextLevel: nextLevel ?? this.nextLevel,
      nextLevelPoints: nextLevelPoints ?? this.nextLevelPoints,
      pointsToNext: pointsToNext ?? this.pointsToNext,
      isMaxLevel: isMaxLevel ?? this.isMaxLevel,
      cashbackPercent: cashbackPercent ?? this.cashbackPercent,
      nextLevelCashbackPercent:
          nextLevelCashbackPercent ?? this.nextLevelCashbackPercent,
      cashbackBalance: cashbackBalance ?? this.cashbackBalance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'current_points': currentPoints,
      'current_level_min': currentLevelMin,
      'current_level_max': currentLevelMax,
      'current_level_points': currentLevelPoints,
      'next_level': nextLevel,
      'next_level_points': nextLevelPoints,
      'points_to_next': pointsToNext,
      'is_max_level': isMaxLevel,
      'cashback_percent': cashbackPercent,
      'next_level_cashback_percent': nextLevelCashbackPercent,
      'cashback_balance': cashbackBalance,
    };
  }

  static double? _firstDouble(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      final doubleValue = _toDouble(value);
      if (doubleValue != null) {
        return doubleValue;
      }
    }
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;

    // Direct numeric types
    if (value is num) return value.toDouble();

    // Convert everything else to string
    String input = value.toString().trim();
    if (input.isEmpty) return null;

    // Clean spaces (normal + NBSP)
    input = input.replaceAll(' ', '').replaceAll('\u00A0', '');

    // Keep only digits, minus, dot, comma
    final buffer = StringBuffer();
    for (final char in input.runes) {
      final c = String.fromCharCode(char);
      if ('0123456789'.contains(c) || c == '.' || c == ',' || c == '-') {
        buffer.write(c);
      }
    }

    String s = buffer.toString();

    // If both comma and dot exist → assume thousand separators
    if (s.contains('.') && s.contains(',')) {
      // Keep the last separator as decimal
      if (s.lastIndexOf('.') > s.lastIndexOf(',')) {
        s = s.replaceAll(',', '');
      } else {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      }
    } else {
      // If only comma exists → treat as decimal
      if (s.contains(',')) {
        s = s.replaceAll(',', '.');
      }
    }

    return double.tryParse(s);
  }
}
