import 'order.dart';

class PayLaterEmployee {
  const PayLaterEmployee({
    required this.employeeKey,
    required this.customerName,
    required this.mobile,
    required this.totalOutstanding,
    required this.orderCount,
    required this.itemCount,
    required this.orders,
  });

  final String employeeKey;
  final String customerName;
  final String mobile;
  final double totalOutstanding;
  final int orderCount;
  final int itemCount;
  final List<CanteenOrder> orders;

  factory PayLaterEmployee.fromJson(Map<String, dynamic> json) {
    final rawOrders = json['orders'] as List? ?? const [];
    return PayLaterEmployee(
      employeeKey: json['employeeKey']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      totalOutstanding: (json['totalOutstanding'] as num?)?.toDouble() ?? 0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      orders: rawOrders
          .whereType<Map>()
          .map(
            (order) => CanteenOrder.fromJson(Map<String, dynamic>.from(order)),
          )
          .toList(),
    );
  }
}

class PayLaterSummary {
  const PayLaterSummary({
    required this.employeeCount,
    required this.orderCount,
    required this.totalOutstanding,
  });

  final int employeeCount;
  final int orderCount;
  final double totalOutstanding;
}

class PayLaterResult {
  const PayLaterResult({required this.employees, required this.summary});

  final List<PayLaterEmployee> employees;
  final PayLaterSummary summary;
}
