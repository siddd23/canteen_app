import '../../core/constants/api_constants.dart';
import '../../core/utils/api_exception.dart';
import '../../core/services/push_notification_service.dart';
import '../models/auth_result.dart';
import 'api_service.dart';
import 'token_storage_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  Future<String> registerOwner({
    required String name,
    required String businessName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    final response = await ApiService.instance.post(
      ApiConstants.register,
      authenticated: false,
      body: {
        'name': name.trim(),
        'businessName': businessName.trim(),
        'email': email.trim().toLowerCase(),
        'mobile': mobile.trim(),
        'password': password,
      },
    );

    return response['message']?.toString() ??
        'Registration submitted successfully';
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiService.instance.post(
      ApiConstants.login,
      authenticated: false,
      body: {'email': email.trim().toLowerCase(), 'password': password},
    );

    final result = AuthResult.fromJson(response);

    if (result.token != null && result.token!.isNotEmpty) {
      await TokenStorageService.instance.saveSession(
        token: result.token!,
        role: result.user.role,
        userId: result.user.id,
        destination: result.destination,
      );
      if (result.user.role == 'canteen_owner') {
        await PushNotificationService.instance.registerCurrentDeviceToken();
      }
    } else {
      await TokenStorageService.instance.clearSession();
    }

    return result;
  }

  Future<void> logout() async {
    await PushNotificationService.instance.unregisterCurrentDeviceToken();
    await TokenStorageService.instance.clearSession();
  }

  Future<String?> restoreSession() async {
    final storage = TokenStorageService.instance;
    try {
      if (!await storage.hasSession) return null;
      final response = await ApiService.instance.get(ApiConstants.session);
      final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
      final destination = data['destination']?.toString();

      if (destination == null || destination.isEmpty) {
        await storage.clearSession();
        return null;
      }
      await storage.saveDestination(destination);
      if (await storage.getRole() == 'canteen_owner') {
        await PushNotificationService.instance.registerCurrentDeviceToken();
      }
      return destination;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await storage.clearSession();
        return null;
      }

      // Temporary network/backend failures must not destroy a valid login.
      final savedDestination = await storage.getDestination();
      if (savedDestination != null && savedDestination.isNotEmpty) {
        return savedDestination;
      }
      final role = await storage.getRole();
      return role == 'super_admin' ? 'admin_dashboard' : 'owner_dashboard';
    } catch (_) {
      return null;
    }
  }
}
