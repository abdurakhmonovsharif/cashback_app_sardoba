import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/screens/points/wallet_calendar.dart';

void main() {
  test('transaction timestamps use the Tashkent calendar boundary', () {
    final beforeMidnight = DateTime.utc(2026, 10, 1, 18, 59);
    final atMidnight = DateTime.utc(2026, 10, 1, 19);

    expect(walletTashkentDate(beforeMidnight), DateTime(2026, 10, 1));
    expect(walletTashkentDate(atMidnight), DateTime(2026, 10, 2));
    expect(walletTashkentWallTime(beforeMidnight).hour, 23);
    expect(walletTashkentWallTime(atMidnight).hour, 0);
  });

  test('timestamp offset does not change the Tashkent day', () {
    final sameInstant = DateTime.parse('2026-10-01T14:00:00-05:00');

    expect(walletTashkentDate(sameInstant), DateTime(2026, 10, 2));
    expect(walletTashkentWallTime(sameInstant).minute, 0);
  });
}
