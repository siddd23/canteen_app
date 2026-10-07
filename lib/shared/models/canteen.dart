class Canteen {
  const Canteen({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.city,
    required this.contactNumber,
    required this.openingTime,
    required this.closingTime,
    required this.status,
    required this.publicCode,
    required this.masterOrderingUrl,
    required this.masterQrCode,
    required this.masterQrEnabled,
  });

  final String id;
  final String ownerId;
  final String name;
  final String address;
  final String city;
  final String contactNumber;
  final String openingTime;
  final String closingTime;
  final String status;
  final String publicCode;
  final String masterOrderingUrl;
  final String masterQrCode;
  final bool masterQrEnabled;

  factory Canteen.fromJson(Map<String, dynamic> json) {
    return Canteen(
      id: json['_id']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? '',
      openingTime: json['openingTime']?.toString() ?? '',
      closingTime: json['closingTime']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      publicCode: json['publicCode']?.toString() ?? '',
      masterOrderingUrl: json['masterOrderingUrl']?.toString() ?? '',
      masterQrCode: json['masterQrCode']?.toString() ?? '',
      masterQrEnabled: json['masterQrEnabled'] as bool? ?? true,
    );
  }
}
