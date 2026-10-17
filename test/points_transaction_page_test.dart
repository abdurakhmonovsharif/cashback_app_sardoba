import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/models/points_transaction_page.dart';

void main() {
  test('parses filtered transaction page and pagination metadata', () {
    final page = PointsTransactionPage.fromJson({
      'loyalty': {'cashback_balance': '10642.50'},
      'summary': {'credited': '9142.50', 'debited': '500.25'},
      'items': [
        {
          'id': 7,
          'user_id': 3,
          'amount': '-500.25',
          'branch_id': null,
          'source': 'MANUAL',
          'staff_id': null,
          'balance_after': '10642.50',
          'created_at': '2026-10-16T12:00:00Z',
          'direction': 'debit',
        }
      ],
      'pagination': {
        'limit': 20,
        'has_more': true,
        'next_cursor': 'next-page',
      },
    });

    expect(page.loyalty.pointsBalance, 10642.5);
    expect(page.summary.credited, 9142.5);
    expect(page.summary.debited, 500.25);
    expect(page.items.single.id, 7);
    expect(page.items.single.amount, -500.25);
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'next-page');
    expect(page.items.single.createdAt.isUtc, isFalse);
  });
}
