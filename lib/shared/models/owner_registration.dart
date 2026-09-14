class OwnerRegistration {
  const OwnerRegistration({
    required this.id,
    required this.name,
    required this.businessName,
    required this.email,
    required this.mobile,
    required this.approvalStatus,
    required this.createdAt,
    this.rejectionReason,
  });

  final String id;
  final String name;
  final String businessName;
  final String email;
  final String mobile;
  final String approvalStatus;
  final DateTime? createdAt;
  final String? rejectionReason;

  factory OwnerRegistration.fromJson(Map<String, dynamic> json) {
    return OwnerRegistration(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      approvalStatus: json['approvalStatus']?.toString() ?? 'Pending',
      rejectionReason: json['rejectionReason']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
