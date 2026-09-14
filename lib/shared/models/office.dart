import 'canteen.dart';

class Office {
  const Office({
    required this.id,
    required this.ownerId,
    required this.canteens,
    required this.companyName,
    required this.building,
    required this.floor,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.contactPerson,
    required this.contactNumber,
    required this.officeCode,
    required this.orderingUrl,
    required this.qrCode,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final List<Canteen> canteens;
  final String companyName;
  final String building;
  final String floor;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String contactPerson;
  final String contactNumber;
  final String officeCode;
  final String orderingUrl;
  final String qrCode;
  final String status;
  final DateTime? createdAt;

  bool get isActive => status == 'Active';

  String get locationLine {
    final parts = [
      if (floor.trim().isNotEmpty) floor.trim(),
      building.trim(),
      city.trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join(', ');
  }

  factory Office.fromJson(Map<String, dynamic> json) {
    final rawCanteens = json['canteenIds'] as List? ?? const [];

    return Office(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      canteens: rawCanteens
          .whereType<Map>()
          .map((item) => Canteen.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      companyName: json['companyName']?.toString() ?? '',
      building: json['building']?.toString() ?? '',
      floor: json['floor']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      contactPerson: json['contactPerson']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? '',
      officeCode: json['officeCode']?.toString() ?? '',
      orderingUrl: json['orderingUrl']?.toString() ?? '',
      qrCode: json['qrCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
