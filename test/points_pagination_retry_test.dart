import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sardoba_app/app_language.dart';
import 'package:sardoba_app/app_localizations.dart';
import 'package:sardoba_app/models/account.dart';
import 'package:sardoba_app/models/loyalty_summary.dart';
import 'package:sardoba_app/models/points_entry.dart';
import 'package:sardoba_app/models/points_transaction_page.dart';
import 'package:sardoba_app/screens/points/points_screen.dart';
import 'package:sardoba_app/services/auth_storage.dart';
import 'package:sardoba_app/services/points_service.dart';
import 'package:sardoba_app/theme.dart';

class _PagingPointsService extends PointsService {
  _PagingPointsService() : super(dio: Dio());

  int calls = 0;

  @override
  Future<PointsTransactionPage> fetchTransactions({
    String direction = 'all',
    DateTime? fromDate,
    DateTime? toDate,
    String? cursor,
    int limit = 20,
    String? accessToken,
    String? tokenType,
  }) async {
    calls++;
    if (calls == 2) throw const PointsServiceException('Offline');
    final firstPage = cursor == null;
    final ids = firstPage ? List.generate(20, (index) => index + 1) : [21];
    return PointsTransactionPage(
      loyalty: const LoyaltySummary(pointsBalance: 100),
      summary: const PointsTransactionSummary(credited: 21),
      items: ids
          .map((id) => PointsEntry(
                id: id,
                userId: 1,
                amount: 1,
                balanceAfter: 100,
                createdAt: DateTime.utc(2026, 10, 16, 12),
              ))
          .toList(),
      hasMore: firstPage,
      nextCursor: firstPage ? 'next-page' : null,
    );
  }
}

void main() {
  testWidgets('pagination waits for explicit retry after a page failure',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AuthStorage.instance.resetForTesting();
    await AuthStorage.instance.ensureInitialized();
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _PagingPointsService();
    await tester.pumpWidget(MaterialApp(
      theme: buildThemeData(),
      home: AppLocalizations(
        locale: AppLocale.uz,
        child: PointsScreen(
          account: const Account(name: 'Client', phone: '+998901234567', id: 1),
          threshold: 30000,
          pointsService: service,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(find.text('16.10.2026 • 17:00'), findsWidgets);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.byKey(const ValueKey('wallet-retry')), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 150));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(service.calls, 2);

    final retry = find.byKey(const ValueKey('wallet-retry'));
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(service.calls, 3);
    expect(find.byKey(const ValueKey('wallet-retry')), findsNothing);
    expect(find.byKey(const ValueKey('wallet-transaction-21')), findsOneWidget);
  });
}
