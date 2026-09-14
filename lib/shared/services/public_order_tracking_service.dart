import '../../core/constants/api_constants.dart';
import '../models/employee_order_tracking.dart';
import 'api_service.dart';

class PublicOrderTrackingService {
  PublicOrderTrackingService._();

  static final PublicOrderTrackingService instance =
      PublicOrderTrackingService._();

  Future<EmployeeOrderTracking> getOrder({
    required String orderNumber,
    required String trackingToken,
  }) async {
    final response = await ApiService.instance.get(
      '${ApiConstants.publicOrders}/$orderNumber/track',
      authenticated: false,
      queryParameters: {'token': trackingToken},
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return EmployeeOrderTracking.fromJson(
      Map<String, dynamic>.from(data['order'] as Map? ?? {}),
    );
  }
}
