class AuthResult {
  const AuthResult({
    required this.message,
    required this.destination,
    required this.user,
    this.token,
  });

  final String message;
  final String destination;
  final String? token;
  final AuthUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['data'] as Map? ?? {});

    return AuthResult(
      message: json['message']?.toString() ?? '',
      destination: data['destination']?.toString() ?? '',
      token: data['token']?.toString(),
      user: AuthUser.fromJson(
        Map<String, dynamic>.from(data['user'] as Map? ?? {}),
      ),
    );
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.businessName,
    this.mobile,
    this.approvalStatus,
    this.rejectionReason,
    this.hasCanteens = false,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? businessName;
  final String? mobile;
  final String? approvalStatus;
  final String? rejectionReason;
  final bool hasCanteens;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      businessName: json['businessName']?.toString(),
      mobile: json['mobile']?.toString(),
      approvalStatus: json['approvalStatus']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      hasCanteens: json['hasCanteens'] == true,
    );
  }
}
