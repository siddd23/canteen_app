import '../../core/constants/api_constants.dart';
import '../models/owner_registration.dart';
import '../models/admin_overview.dart';
import 'api_service.dart';

class AdminService {
  AdminService._();

  static final AdminService instance = AdminService._();

  Future<AdminOverview> getOverview() async {
    final response = await ApiService.instance.get(ApiConstants.adminOverview);
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return AdminOverview.fromJson(
      Map<String, dynamic>.from(data['overview'] as Map? ?? {}),
    );
  }

  Future<List<OwnerRegistration>> getOwners({String? status}) async {
    final response = await ApiService.instance.get(
      ApiConstants.owners,
      queryParameters: status == null ? null : {'status': status},
    );

    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    final owners = data['owners'] as List? ?? [];

    return owners
        .map(
          (owner) => OwnerRegistration.fromJson(
            Map<String, dynamic>.from(owner as Map),
          ),
        )
        .toList();
  }

  Future<List<OwnerRegistration>> getPendingOwners() async {
    final response = await ApiService.instance.get(ApiConstants.pendingOwners);

    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});

    final owners = data['owners'] as List? ?? [];

    return owners
        .map(
          (owner) => OwnerRegistration.fromJson(
            Map<String, dynamic>.from(owner as Map),
          ),
        )
        .toList();
  }

  Future<OwnerRegistration> approveOwner(String ownerId) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.owners}/$ownerId/approve',
    );

    return _ownerFromResponse(response);
  }

  Future<OwnerRegistration> rejectOwner({
    required String ownerId,
    required String reason,
  }) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.owners}/$ownerId/reject',
      body: {'reason': reason.trim()},
    );

    return _ownerFromResponse(response);
  }

  OwnerRegistration _ownerFromResponse(Map<String, dynamic> response) {
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});

    final owner = Map<String, dynamic>.from(data['owner'] as Map? ?? {});

    return OwnerRegistration.fromJson(owner);
  }
}
