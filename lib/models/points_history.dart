import 'points_entry.dart';
import 'loyalty_summary.dart';

class PointsHistory {
  const PointsHistory({
    required this.loyalty,
    required this.transactions,
  });

  final LoyaltySummary loyalty;
  final List<PointsEntry> transactions;

  factory PointsHistory.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PointsHistory(
        loyalty: LoyaltySummary(),
        transactions: [],
      );
    }
    final normalized = json.cast<String, dynamic>();
    final loyalty = LoyaltySummary.fromJson(
      (normalized['loyalty'] as Map?)?.cast<String, dynamic>(),
    );
    final transactions = <PointsEntry>[];
    final rawTransactions = normalized['transactions'];
    if (rawTransactions is List) {
      for (final item in rawTransactions.whereType<Map>()) {
        transactions.add(
          PointsEntry.fromJson(item.cast<String, dynamic>()),
        );
      }
    }
    return PointsHistory(
      loyalty: loyalty,
      transactions: transactions,
    );
  }
}
