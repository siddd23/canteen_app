class OrderNotification {
  const OrderNotification({
    required this.id,
    required this.orderNumber,
    required this.canteenId,
    required this.canteenName,
    required this.customerName,
    required this.itemCount,
    required this.grandTotal,
    required this.orderStatus,
    required this.createdAt,
  });

  final String id;
  final String orderNumber;
  final String canteenId;
  final String canteenName;
  final String customerName;
  final int itemCount;
  final double grandTotal;
  final String orderStatus;
  final DateTime? createdAt;

  factory OrderNotification.fromJson(Map<String, dynamic> json) {
    return OrderNotification(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      canteenId: json['canteenId']?.toString() ?? '',
      canteenName: json['canteenName']?.toString() ?? 'Canteen',
      customerName: json['customerName']?.toString() ?? '',
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      orderStatus: json['orderStatus']?.toString() ?? 'Pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class OrderNotificationResult {
  const OrderNotificationResult({
    required this.notifications,
    required this.checkedAt,
  });

  final List<OrderNotification> notifications;
  final DateTime checkedAt;
}
