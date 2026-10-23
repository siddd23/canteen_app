import '../../core/constants/api_constants.dart';
import '../models/customer_profile.dart';
import 'api_service.dart';
import 'token_storage_service.dart';

class CustomerAuthService {
  CustomerAuthService._();

  static final CustomerAuthService instance = CustomerAuthService._();

  Future<CustomerProfile> signup({
    required String name,
    required String mobile,
    required String password,
    String email = '',
    String officeId = '',
  }) async {
    final response = await ApiService.instance.post(
      '${ApiConstants.customers}/signup',
      authenticated: false,
      body: {
        'name': name.trim(),
        'mobile': mobile.trim(),
        'email': email.trim().toLowerCase(),
        'officeId': officeId.trim().toUpperCase(),
        'password': password,
      },
    );
    return _saveCustomerSession(response);
  }

  Future<CustomerProfile> login({
    required String mobile,
    required String password,
  }) async {
    final response = await ApiService.instance.post(
      '${ApiConstants.customers}/login',
      authenticated: false,
      body: {'mobile': mobile.trim(), 'password': password},
    );
    return _saveCustomerSession(response);
  }

  Future<CustomerProfile> _saveCustomerSession(
    Map<String, dynamic> response,
  ) async {
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    final token = data['token']?.toString() ?? '';
    final customer = CustomerProfile.fromJson(
      Map<String, dynamic>.from(data['customer'] as Map? ?? {}),
    );
    if (token.isEmpty || customer.id.isEmpty) {
      throw StateError('The employee session response is incomplete.');
    }
    await TokenStorageService.instance.saveSession(
      token: token,
      role: 'customer',
      userId: customer.id,
      destination: 'employee_dashboard',
    );
    return customer;
  }

  Future<CustomerProfile> profile() async {
    final response = await ApiService.instance.get('${ApiConstants.customers}/me');
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return CustomerProfile.fromJson(
      Map<String, dynamic>.from(data['customer'] as Map? ?? {}),
    );
  }

  Future<CustomerProfile> updateProfile({
    required String name,
    required String mobile,
    required String email,
    required String officeId,
  }) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.customers}/me',
      body: {
        'name': name.trim(),
        'mobile': mobile.trim(),
        'email': email.trim().toLowerCase(),
        'officeId': officeId.trim().toUpperCase(),
      },
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return CustomerProfile.fromJson(
      Map<String, dynamic>.from(data['customer'] as Map? ?? {}),
    );
  }

  Future<List<Map<String, dynamic>>> orders() async {
    final response = await ApiService.instance.get('${ApiConstants.customers}/orders');
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return (data['orders'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> logout() => TokenStorageService.instance.clearSession();
}
