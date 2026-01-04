enum PointsSource { qr, branch, manual, visit, unknown }

PointsSource pointsSourceFrom(String? value) {
  final normalized = value?.trim().toUpperCase();
  switch (normalized) {
    case 'QR':
      return PointsSource.qr;
    case 'ORDER':
    case 'VISIT':
      return PointsSource.visit;
    case 'BRANCH':
      return PointsSource.branch;
    case 'MANUAL':
      return PointsSource.manual;
    default:
      return PointsSource.unknown;
  }
}

class PointsEntry {
  const PointsEntry({
    required this.id,
    required this.userId,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.branchId,
    this.source = PointsSource.unknown,
    this.staffId,
  });

  final int id;
  final int userId;
  final double amount;
  final double balanceAfter;
  final DateTime createdAt;
  final int? branchId;
  final PointsSource source;
  final int? staffId;

  factory PointsEntry.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final cleaned = value.replaceAll(RegExp(r'[\s\u00A0]'), '');
        final normalized =
            cleaned.replaceAll(RegExp(r'[^0-9,.\-]'), '').replaceAll(',', '.');
        return double.tryParse(normalized) ?? 0;
      }
      return 0;
    }

    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      final text = value?.toString() ?? '';
      final normalized = text.replaceAll(' ', 'T');
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) return parsed;
      if (text.contains('.')) {
        final parts = text.split('.');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
      return DateTime.now();
    }

    return PointsEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      amount: parseDouble(json['amount']),
      branchId: (json['branch_id'] as num?)?.toInt(),
      source: pointsSourceFrom(json['source']?.toString()),
      staffId: (json['staff_id'] as num?)?.toInt(),
      balanceAfter: parseDouble(json['balance_after']),
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'branch_id': branchId,
      'source': source.name,
      'staff_id': staffId,
      'balance_after': balanceAfter,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
