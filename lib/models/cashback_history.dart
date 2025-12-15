import 'cashback_entry.dart';
import 'loyalty_summary.dart';

class CashbackHistory {
  const CashbackHistory({
    required this.loyalty,
    required this.transactions,
  });

  final LoyaltySummary loyalty;
  final List<CashbackEntry> transactions;

  factory CashbackHistory.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CashbackHistory(
        loyalty: LoyaltySummary(),
        transactions: [],
      );
    }
    final normalized = json.cast<String, dynamic>();
    final loyalty = LoyaltySummary.fromJson(
      (normalized['loyalty'] as Map?)?.cast<String, dynamic>(),
    );
    final transactions = <CashbackEntry>[];
    final rawTransactions = normalized['transactions'];
    if (rawTransactions is List) {
      for (final item in rawTransactions.whereType<Map>()) {
        transactions.add(
          CashbackEntry.fromJson(item.cast<String, dynamic>()),
        );
      }
    }
    return CashbackHistory(
      loyalty: loyalty,
      transactions: transactions,
    );
  }
}
