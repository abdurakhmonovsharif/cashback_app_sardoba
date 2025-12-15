import 'dart:convert';

import 'cashback_entry.dart';
import 'loyalty_summary.dart';

class Account {
  const Account({
    required this.name,
    required this.phone,
    this.surname,
    this.middleName,
    this.referralCode,
    this.isVerified = false,
    this.id,
    this.cashbackBalance,
    this.dateOfBirth,
    this.profilePhotoUrl,
    this.waiterId,
    this.loyalty,
    this.level,
    this.cashbackHistory,
    this.cardTracks,
  });

  final String name;
  final String? surname;
  final String? middleName;
  final String phone;
  final String? referralCode;
  final bool isVerified;
  final int? id;
  final double? cashbackBalance;
  final DateTime? dateOfBirth;
  final String? profilePhotoUrl;
  final int? waiterId;
  final LoyaltySummary? loyalty;
  final String? level;
  final List<CashbackEntry>? cashbackHistory;
  final List<String>? cardTracks;

  Account copyWith({
    String? name,
    String? surname,
    String? middleName,
    String? phone,
    String? referralCode,
    bool? isVerified,
    int? id,
    double? cashbackBalance,
    DateTime? dateOfBirth,
    String? profilePhotoUrl,
    int? waiterId,
    LoyaltySummary? loyalty,
    String? level,
    List<CashbackEntry>? cashbackHistory,
    List<String>? cardTracks,
  }) {
    return Account(
      name: name ?? this.name,
      surname: surname ?? this.surname,
      middleName: middleName ?? this.middleName,
      phone: phone ?? this.phone,
      referralCode: referralCode ?? this.referralCode,
      isVerified: isVerified ?? this.isVerified,
      id: id ?? this.id,
      cashbackBalance: cashbackBalance ?? this.cashbackBalance,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      waiterId: waiterId ?? this.waiterId,
      loyalty: loyalty ?? this.loyalty,
      level: level ?? this.level,
      cashbackHistory: cashbackHistory ?? this.cashbackHistory,
      cardTracks: cardTracks ?? this.cardTracks,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'surname': surname,
        'middleName': middleName,
        'phone': phone,
        'referralCode': referralCode,
        'isVerified': isVerified,
        'id': id,
        'cashbackBalance': cashbackBalance,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'profilePhotoUrl': profilePhotoUrl,
        'waiterId': waiterId,
        'loyalty': loyalty?.toJson(),
        'level': level,
        'cashbackHistory':
            cashbackHistory?.map((entry) => entry.toJson()).toList(),
        'cardTracks': cardTracks,
      };

  static Account fromJson(Map<String, dynamic> json) {
    return Account(
      name: json['name'] as String? ?? '',
      surname: (json['surname'] as String?) ?? (json['last_name'] as String?),
      middleName:
          (json['middleName'] as String?) ?? (json['middle_name'] as String?),
      phone: json['phone'] as String? ?? '',
      referralCode: json['referralCode'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      id: json['id'] as int?,
      cashbackBalance: (json['cashbackBalance'] as num?)?.toDouble(),
      dateOfBirth: _parseDate(json['dateOfBirth'] ?? json['date_of_birth']),
      profilePhotoUrl: (json['profilePhotoUrl'] as String?) ??
          (json['profile_photo_url'] as String?),
      waiterId:
          json['waiterId'] as int? ?? (json['waiter_id'] as num?)?.toInt(),
      loyalty: LoyaltySummary.fromJson(
        (json['loyalty'] as Map?)?.cast<String, dynamic>(),
      ),
      level: json['level'] as String?,
      cashbackHistory: (json['cashbackHistory'] as List?)
          ?.whereType<Map>()
          .map((e) => CashbackEntry.fromJson(e.cast<String, dynamic>()))
          .toList(),
      cardTracks:
          (json['cardTracks'] as List?)?.whereType<String>().toList(),
    );
  }

  static List<Account> listFromJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    final decoded = json.decode(jsonString);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Account.fromJson)
        .toList();
  }

  static String listToJson(List<Account> accounts) {
    return json.encode(accounts.map((e) => e.toJson()).toList());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
