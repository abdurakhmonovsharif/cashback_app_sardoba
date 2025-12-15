import 'package:flutter_test/flutter_test.dart';

import 'package:sardoba_app/models/login_response.dart';

void main() {
  test('fromJson maps snake_case keys and defaults token type', () {
    final json = {
      'access_token': 'abc',
      'refresh_token': 'def',
    };
    final response = LoginResponse.fromJson(json);
    expect(response.accessToken, 'abc');
    expect(response.refreshToken, 'def');
    expect(response.tokenType, 'bearer');
    expect(response.authorizationHeaderValue, 'Bearer abc');
  });

  test('copyWith and toJson behave as expected', () {
    final original = LoginResponse(
      accessToken: 'first',
      refreshToken: 'second',
      tokenType: 'custom',
    );
    final modified = original.copyWith(
      accessToken: 'updated',
      tokenType: 'Bearer',
    );
    expect(modified.accessToken, 'updated');
    expect(modified.refreshToken, 'second');
    expect(modified.authorizationHeaderValue, 'Bearer updated');
    expect(modified.toJson(), {
      'access_token': 'updated',
      'refresh_token': 'second',
      'token_type': 'Bearer',
    });
  });
}
