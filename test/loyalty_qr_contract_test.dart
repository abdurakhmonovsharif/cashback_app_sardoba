import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sardoba_app/models/account.dart';
import 'package:sardoba_app/models/loyalty_qr.dart';
import 'package:sardoba_app/services/auth_service.dart';

void main() {
  for (final status in ['pending', 'unavailable', 'unknown']) {
    test('$status cannot expose an injected payload', () {
      final qr = LoyaltyQr.fromJson({'status': status, 'payload': '12345'});
      expect(qr.confirmedPayload, isNull);
      expect(qr.toJson()['payload'], isNull);
    });
  }
  test('legacy local account never promotes cardTracks or phone to QR', () {
    final account = Account.fromJson({
      'name': 'Fixture',
      'phone': '998900000001',
      'cardTracks': ['001234'],
    });
    expect(account.loyaltyQr?.confirmedPayload, isNull);
  });
  test('confirmed payload retains exact leading zeros through storage', () {
    const account = Account(
        name: 'Fixture',
        phone: '998900000001',
        loyaltyQr: LoyaltyQr(status: 'confirmed', payload: '0000123456'));
    expect(Account.fromJson(account.toJson()).loyaltyQr?.confirmedPayload,
        '0000123456');
    expect(account.copyWith(name: 'Changed').loyaltyQr?.confirmedPayload,
        '0000123456');
  });
  for (final qr in [
    null,
    {'status': 'pending', 'payload': 'wrong'},
    {'status': 'confirmed', 'payload': '0000123456'},
  ]) {
    test('profile API uses only explicit loyalty_qr: $qr', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        handler
            .resolve(Response(requestOptions: options, statusCode: 200, data: {
          'profile': {'id': 1, 'phone': '+998900000001', 'name': 'Fixture'},
          'cashback': {
            'cards': [
              {'card_track': 'OTHER_TRACK', 'card_number': 'OTHER_NUMBER'}
            ],
            if (qr != null) 'loyalty_qr': qr,
          },
        }));
      }));
      final service = AuthService(dio: dio);
      final account = await service.fetchProfileWithToken(accessToken: 'test');
      expect(account?.loyaltyQr?.confirmedPayload,
          qr?['status'] == 'confirmed' ? '0000123456' : null);
      service.dispose();
    });
  }
}
