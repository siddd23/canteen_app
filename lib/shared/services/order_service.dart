import '../../core/constants/api_constants.dart';
import '../models/order.dart';
import '../models/order_notification.dart';
import '../models/order_history.dart';
import '../models/sales_report.dart';
import '../models/pay_later_employee.dart';
import '../models/dashboard_summary.dart';
import 'api_service.dart';

class OrderService {
  OrderService._();

  static final OrderService instance = OrderService._();

  Future<SalesReport> getSalesReport({
    String? canteenId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final response = await ApiService.instance.get(
      '${ApiConstants.orders}/reports',
      queryParameters: {
        if (canteenId != null && canteenId.isNotEmpty) 'canteenId': canteenId,
        if (dateFrom != null) 'dateFrom': date(dateFrom),
        if (dateTo != null) 'dateTo': date(dateTo),
      },
    );
    return SalesReport.fromJson(
      Map<String, dynamic>.from(response['data'] as Map? ?? {}),
    );
  }

  Future<OrderHistoryResult> getOrderHistory({
    String? officeId,
    String? canteenId,
    String? status,
    String? paymentStatus,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';

    final response = await ApiService.instance.get(
      '${ApiConstants.orders}/history',
      queryParameters: {
        if (officeId != null && officeId.isNotEmpty) 'officeId': officeId,
        if (canteenId != null && canteenId.isNotEmpty) 'canteenId': canteenId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (paymentStatus != null && paymentStatus.isNotEmpty)
          'paymentStatus': paymentStatus,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (dateFrom != null) 'dateFrom': date(dateFrom),
        if (dateTo != null) 'dateTo': date(dateTo),
        'page': page,
        'limit': limit,
      },
    );
    return OrderHistoryResult.fromJson(
      Map<String, dynamic>.from(response['data'] as Map? ?? {}),
    );
  }

  Future<int> deleteSelectedHistory(List<String> orderIds) async {
    final response = await ApiService.instance.delete(
      '${ApiConstants.orders}/history',
      body: {'mode': 'selected', 'orderIds': orderIds},
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return (data['deletedCount'] as num?)?.toInt() ?? 0;
  }

  Future<int> deletePaidHistory({
    String? officeId,
    String? canteenId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final response = await ApiService.instance.delete(
      '${ApiConstants.orders}/history',
      body: {
        'mode': 'paid',
        if (officeId != null && officeId.isNotEmpty) 'officeId': officeId,
        if (canteenId != null && canteenId.isNotEmpty) 'canteenId': canteenId,
        if (dateFrom != null) 'dateFrom': date(dateFrom),
        if (dateTo != null) 'dateTo': date(dateTo),
      },
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return (data['deletedCount'] as num?)?.toInt() ?? 0;
  }

  Future<List<CanteenOrder>> getOfficeStatement({
    required String officeId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final response = await ApiService.instance.get(
      '${ApiConstants.orders}/office-statement',
      queryParameters: {
        'officeId': officeId,
        if (dateFrom != null) 'dateFrom': date(dateFrom),
        if (dateTo != null) 'dateTo': date(dateTo),
      },
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    final rawOrders = data['orders'] as List? ?? const [];
    return rawOrders
        .whereType<Map>()
        .map((item) => CanteenOrder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<CanteenOrder>> getCustomerStatement({
    required String customerName,
    required String mobile,
    String? canteenId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    String date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final response = await ApiService.instance.get(
      '${ApiConstants.orders}/customer-statement',
      queryParameters: {
        'customerName': customerName,
        'mobile': mobile,
        if (canteenId != null && canteenId.isNotEmpty) 'canteenId': canteenId,
        if (dateFrom != null) 'dateFrom': date(dateFrom),
        if (dateTo != null) 'dateTo': date(dateTo),
      },
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return (data['orders'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CanteenOrder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<OrderNotificationResult> getOrderNotifications({
    DateTime? after,
  }) async {
    final response = await ApiService.instance.get(
      '${ApiConstants.orders}/notifications',
      queryParameters: {
        if (after != null) 'after': after.toUtc().toIso8601String(),
      },
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    final rawNotifications = data['notifications'] as List? ?? const [];
    return OrderNotificationResult(
      notifications: rawNotifications
          .whereType<Map>()
          .map(
            (item) =>
                OrderNotification.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      checkedAt:
          DateTime.tryParse(data['checkedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  Future<DashboardSummary> getDashboardSummary({
    required String canteenId,
  }) async {
    final response = await ApiService.instance.get(
      '${ApiConstants.orders}/dashboard-summary',
      queryParameters: {'canteenId': canteenId},
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return DashboardSummary.fromJson(
      Map<String, dynamic>.from(data['summary'] as Map? ?? {}),
    );
  }

  Future<List<CanteenOrder>> getMyOrders({String? canteenId}) async {
    final response = await ApiService.instance.get(
      ApiConstants.orders,
      queryParameters: {
        if (canteenId != null && canteenId.isNotEmpty) 'canteenId': canteenId,
      },
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    final orders = data['orders'] as List? ?? const [];
    return orders
        .whereType<Map>()
        .map((order) => CanteenOrder.fromJson(Map<String, dynamic>.from(order)))
        .toList();
  }

  Future<CanteenOrder> updateStatus(String orderId, String status) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.orders}/$orderId/status',
      body: {'status': status},
    );
    return _fromResponse(response);
  }

  Future<CanteenOrder> updatePayment(String orderId, String status) async {
    final response = await ApiService.instance.patch(
      '${ApiConstants.orders}/$orderId/payment',
      body: {'status': status},
    );
    return _fromResponse(response);
  }

  Future<PayLaterResult> getPayLaterEmployees({String? canteenId}) async {
    final response = await ApiService.instance.get(
      '${ApiConstants.orders}/pay-later',
      queryParameters: {
        if (canteenId != null && canteenId.isNotEmpty) 'canteenId': canteenId,
      },
    );
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    final rawEmployees = data['employees'] as List? ?? const [];
    final summary = Map<String, dynamic>.from(data['summary'] as Map? ?? {});
    return PayLaterResult(
      employees: rawEmployees
          .whereType<Map>()
          .map(
            (item) =>
                PayLaterEmployee.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      summary: PayLaterSummary(
        employeeCount: (summary['employeeCount'] as num?)?.toInt() ?? 0,
        orderCount: (summary['orderCount'] as num?)?.toInt() ?? 0,
        totalOutstanding:
            (summary['totalOutstanding'] as num?)?.toDouble() ?? 0,
      ),
    );
  }

  Future<void> settleEmployeePayLater({
    required String customerName,
    required String mobile,
    String? canteenId,
  }) async {
    await ApiService.instance.patch(
      '${ApiConstants.orders}/pay-later/settle',
      body: {
        'customerName': customerName,
        'mobile': mobile,
        if (canteenId != null && canteenId.isNotEmpty) 'canteenId': canteenId,
      },
    );
  }

  CanteenOrder _fromResponse(Map<String, dynamic> response) {
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return CanteenOrder.fromJson(
      Map<String, dynamic>.from(data['order'] as Map? ?? {}),
    );
  }
}
