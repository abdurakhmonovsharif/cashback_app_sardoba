enum SavedLocationType { home, work, other }

SavedLocationType savedLocationTypeFromJson(String? value) {
  switch (value) {
    case 'home':
      return SavedLocationType.home;
    case 'work':
      return SavedLocationType.work;
    default:
      return SavedLocationType.other;
  }
}

String savedLocationTypeToJson(SavedLocationType type) {
  switch (type) {
    case SavedLocationType.home:
      return 'home';
    case SavedLocationType.work:
      return 'work';
    case SavedLocationType.other:
      return 'other';
  }
}

class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.label,
    required this.addressLine,
    this.details,
    this.type = SavedLocationType.other,
  });

  final String id;
  final String label;
  final String addressLine;
  final String? details;
  final SavedLocationType type;

  SavedLocation copyWith({
    String? id,
    String? label,
    String? addressLine,
    String? details,
    SavedLocationType? type,
  }) {
    return SavedLocation(
      id: id ?? this.id,
      label: label ?? this.label,
      addressLine: addressLine ?? this.addressLine,
      details: details ?? this.details,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'addressLine': addressLine,
        'details': details,
        'type': savedLocationTypeToJson(type),
      };

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      addressLine: json['addressLine'] as String? ?? '',
      details: json['details'] as String?,
      type: savedLocationTypeFromJson(json['type'] as String?),
    );
  }
}
