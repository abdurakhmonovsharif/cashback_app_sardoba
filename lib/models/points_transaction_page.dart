import 'loyalty_summary.dart';
import 'points_entry.dart';

class PointsTransactionSummary {
  const PointsTransactionSummary({this.credited = 0, this.debited = 0});

  final double credited;
  final double debited;

  factory PointsTransactionSummary.fromJson(Map<String, dynamic>? json) {
    double parse(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return PointsTransactionSummary(
      credited: parse(json?['credited']),
      debited: parse(json?['debited']),
    );
  }
}

class PointsTransactionPage {
  const PointsTransactionPage({
    required this.loyalty,
    required this.summary,
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final LoyaltySummary loyalty;
  final PointsTransactionSummary summary;
  final List<PointsEntry> items;
  final bool hasMore;
  final String? nextCursor;

  factory PointsTransactionPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => PointsEntry.fromJson(item.cast<String, dynamic>()))
            .toList(growable: false)
        : const <PointsEntry>[];
    final pagination = (json['pagination'] as Map?)?.cast<String, dynamic>();
    return PointsTransactionPage(
      loyalty: LoyaltySummary.fromJson(
        (json['loyalty'] as Map?)?.cast<String, dynamic>(),
      ),
      summary: PointsTransactionSummary.fromJson(
        (json['summary'] as Map?)?.cast<String, dynamic>(),
      ),
      items: items,
      hasMore: pagination?['has_more'] == true,
      nextCursor: pagination?['next_cursor']?.toString(),
    );
  }
}
