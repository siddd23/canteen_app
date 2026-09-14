import 'order.dart';

class OrderHistoryResult {
  const OrderHistoryResult({
    required this.orders,
    required this.page,
    required this.limit,
    required this.totalOrders,
    required this.totalPages,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<CanteenOrder> orders;
  final int page;
  final int limit;
  final int totalOrders;
  final int totalPages;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory OrderHistoryResult.fromJson(Map<String, dynamic> data) {
    final rawOrders = data['orders'] as List? ?? const [];
    final pagination = Map<String, dynamic>.from(
      data['pagination'] as Map? ?? const {},
    );
    return OrderHistoryResult(
      orders: rawOrders
          .whereType<Map>()
          .map((item) => CanteenOrder.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      limit: (pagination['limit'] as num?)?.toInt() ?? 20,
      totalOrders: (pagination['totalOrders'] as num?)?.toInt() ?? 0,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
      hasPreviousPage: pagination['hasPreviousPage'] == true,
      hasNextPage: pagination['hasNextPage'] == true,
    );
  }
}
