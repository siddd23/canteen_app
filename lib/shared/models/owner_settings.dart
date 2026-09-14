class OwnerPreferences {
  const OwnerPreferences({
    required this.orderSoundEnabled,
    required this.payLaterEnabled,
    required this.defaultPreparationTime,
  });

  final bool orderSoundEnabled;
  final bool payLaterEnabled;
  final int defaultPreparationTime;

  factory OwnerPreferences.fromJson(Map<String, dynamic> json) =>
      OwnerPreferences(
        orderSoundEnabled: json['orderSoundEnabled'] != false,
        payLaterEnabled: json['payLaterEnabled'] != false,
        defaultPreparationTime:
            (json['defaultPreparationTime'] as num?)?.toInt() ?? 15,
      );
}

class OwnerSettings {
  const OwnerSettings({
    required this.id,
    required this.name,
    required this.businessName,
    required this.email,
    required this.mobile,
    required this.approvalStatus,
    required this.preferences,
  });

  final String id;
  final String name;
  final String businessName;
  final String email;
  final String mobile;
  final String approvalStatus;
  final OwnerPreferences preferences;

  factory OwnerSettings.fromJson(Map<String, dynamic> json) => OwnerSettings(
    id: (json['_id'] ?? json['id'])?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    businessName: json['businessName']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    mobile: json['mobile']?.toString() ?? '',
    approvalStatus: json['approvalStatus']?.toString() ?? 'Approved',
    preferences: OwnerPreferences.fromJson(
      Map<String, dynamic>.from(json['preferences'] as Map? ?? const {}),
    ),
  );
}
