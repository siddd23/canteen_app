class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.officeId,
    required this.deliveryAddress,
  });

  final String id;
  final String name;
  final String mobile;
  final String email;
  final String officeId;
  final Map<String, dynamic> deliveryAddress;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      officeId: json['officeId']?.toString() ?? '',
      deliveryAddress: Map<String, dynamic>.from(json['deliveryAddress'] as Map? ?? const {}),
    );
  }
}
