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
    );
  }
}
