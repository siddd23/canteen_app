import 'order.dart';

class EmployeeOrderTracking {
  const EmployeeOrderTracking({
    required this.orderNumber,
    required this.customerName,
    required this.companyName,
    required this.canteenName,
    required this.items,
    required this.itemCount,
    required this.grandTotal,
    required this.estimatedPreparationTime,
    required this.orderStatus,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String orderNumber;
  final String customerName;
  final String companyName;
  final String canteenName;
  final List<OrderItem> items;
  final int itemCount;
  final double grandTotal;
  final int estimatedPreparationTime;
  final String orderStatus;
  final String paymentStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isFinal => const [
    'Delivered',
    'Rejected',
    'Cancelled',
  ].contains(orderStatus);

  factory EmployeeOrderTracking.fromJson(Map<String, dynamic> json) {
    final office = Map<String, dynamic>.from(
      json['officeSnapshot'] as Map? ?? const {},
    );
    final canteen = Map<String, dynamic>.from(
      json['canteenSnapshot'] as Map? ?? const {},
    );
    return EmployeeOrderTracking(
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      companyName: office['companyName']?.toString() ?? '',
      canteenName: canteen['name']?.toString() ?? '',
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      estimatedPreparationTime:
          (json['estimatedPreparationTime'] as num?)?.toInt() ?? 0,
      orderStatus: json['orderStatus']?.toString() ?? 'Pending',
      paymentStatus: json['paymentStatus']?.toString() ?? 'Unpaid',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}
