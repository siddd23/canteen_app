class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.officeId,
  });

  final String id;
  final String name;
  final String mobile;
  final String email;
  final String officeId;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      officeId: json['officeId']?.toString() ?? '',
    );
  }
}
