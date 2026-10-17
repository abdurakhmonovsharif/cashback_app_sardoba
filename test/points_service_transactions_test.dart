import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/services/points_service.dart';

void main() {
  test('transaction request sends filters, dates and cursor', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    RequestOptions? captured;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      captured = options;
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'loyalty': {'cashback_balance': 10},
          'summary': {'credited': 10, 'debited': 0},
          'items': [],
          'pagination': {
            'limit': 20,
            'has_more': false,
            'next_cursor': null,
          },
        },
      ));
    }));
    final service = PointsService(dio: dio);

    await service.fetchTransactions(
      direction: 'credit',
      fromDate: DateTime(2026, 10, 1),
      toDate: DateTime(2026, 10, 7),
      cursor: 'cursor-value',
      accessToken: 'access-token',
      tokenType: 'bearer',
    );

    expect(captured?.path, '/api/v1/cashback/me/transactions');
    expect(captured?.queryParameters, {
      'direction': 'credit',
      'limit': 20,
      'from_date': '2026-10-01',
      'to_date': '2026-10-07',
      'cursor': 'cursor-value',
    });
    expect(captured?.headers['Authorization'], 'Bearer access-token');
  });
}
