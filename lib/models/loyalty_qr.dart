/// The server alone selects and confirms the exact loyalty QR payload.
class LoyaltyQr {
  const LoyaltyQr({required this.status, this.payload});

  final String status;
  final String? payload;

  String? get confirmedPayload =>
      status == 'confirmed' && payload != null && payload!.trim().isNotEmpty
          ? payload
          : null;

  factory LoyaltyQr.fromJson(Map<String, dynamic>? json) {
    final status = json?['status'];
    final payload = json?['payload'];
    return LoyaltyQr(
      status: status is String ? status : 'unavailable',
      payload: status == 'confirmed' && payload is String ? payload : null,
    );
  }

  Map<String, dynamic> toJson() =>
      {'status': status, 'payload': confirmedPayload};
}
