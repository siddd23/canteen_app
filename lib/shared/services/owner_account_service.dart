import '../../core/constants/api_constants.dart';
import '../models/owner_settings.dart';
import 'api_service.dart';

class OwnerAccountService {
  OwnerAccountService._();

  static final OwnerAccountService instance = OwnerAccountService._();

  Future<OwnerSettings> getProfile() async {
    final response = await ApiService.instance.get(
      '${ApiConstants.account}/profile',
    );
    return _owner(response);
  }

  Future<OwnerSettings> updateProfile({
    required String name,
    required String businessName,
    required String email,
    required String mobile,
  }) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.account}/profile',
      body: {
        'name': name.trim(),
        'businessName': businessName.trim(),
        'email': email.trim().toLowerCase(),
        'mobile': mobile.trim(),
      },
    );
    return _owner(response);
  }

  Future<OwnerSettings> updatePreferences({
    required bool orderSoundEnabled,
    required bool payLaterEnabled,
    required int defaultPreparationTime,
  }) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.account}/preferences',
      body: {
        'orderSoundEnabled': orderSoundEnabled,
        'payLaterEnabled': payLaterEnabled,
        'defaultPreparationTime': defaultPreparationTime,
      },
    );
    return _owner(response);
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.account}/password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    return response['message']?.toString() ?? 'Password changed successfully';
  }

  OwnerSettings _owner(Map<String, dynamic> response) {
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return OwnerSettings.fromJson(
      Map<String, dynamic>.from(data['owner'] as Map? ?? {}),
    );
  }
}
