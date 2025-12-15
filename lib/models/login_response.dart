class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final access = json['access_token'] as String? ?? '';
    final refresh = json['refresh_token'] as String? ?? '';
    final type = (json['token_type'] as String? ?? 'bearer').trim();

    return LoginResponse(
      accessToken: access,
      refreshToken: refresh,
      tokenType: type.isNotEmpty ? type : 'bearer',
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
      };

  LoginResponse copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
  }) {
    return LoginResponse(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
    );
  }

  String get authorizationHeaderValue {
    return '$normalizedTokenType $accessToken';
  }

  String get normalizedTokenType {
    final trimmed = tokenType.trim();
    if (trimmed.toLowerCase() == 'bearer') return 'Bearer';
    return trimmed.isEmpty ? 'Bearer' : trimmed;
  }
}
