class AdminOverview {
  const AdminOverview({
    required this.totalOwners,
    required this.pendingOwners,
    required this.approvedOwners,
    required this.rejectedOwners,
    required this.totalCanteens,
    required this.activeCanteens,
    required this.totalOffices,
    required this.activeOffices,
    required this.totalOrders,
    required this.todayOrders,
    required this.pendingOrders,
    required this.todaySales,
    required this.payLaterOutstanding,
    required this.payLaterOrderCount,
    required this.recentOrders,
    required this.updatedAt,
  });

  final int totalOwners;
  final int pendingOwners;
  final int approvedOwners;
  final int rejectedOwners;
  final int totalCanteens;
  final int activeCanteens;
  final int totalOffices;
  final int activeOffices;
  final int totalOrders;
  final int todayOrders;
  final int pendingOrders;
  final double todaySales;
  final double payLaterOutstanding;
  final int payLaterOrderCount;
  final List<AdminRecentOrder> recentOrders;
  final DateTime? updatedAt;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    final owners = Map<String, dynamic>.from(json['owners'] as Map? ?? {});
    final canteens = Map<String, dynamic>.from(json['canteens'] as Map? ?? {});
    final offices = Map<String, dynamic>.from(json['offices'] as Map? ?? {});
    final orders = Map<String, dynamic>.from(json['orders'] as Map? ?? {});
    return AdminOverview(
      totalOwners: (owners['total'] as num?)?.toInt() ?? 0,
      pendingOwners: (owners['pending'] as num?)?.toInt() ?? 0,
      approvedOwners: (owners['approved'] as num?)?.toInt() ?? 0,
      rejectedOwners: (owners['rejected'] as num?)?.toInt() ?? 0,
      totalCanteens: (canteens['total'] as num?)?.toInt() ?? 0,
      activeCanteens: (canteens['active'] as num?)?.toInt() ?? 0,
      totalOffices: (offices['total'] as num?)?.toInt() ?? 0,
      activeOffices: (offices['active'] as num?)?.toInt() ?? 0,
      totalOrders: (orders['total'] as num?)?.toInt() ?? 0,
      todayOrders: (orders['today'] as num?)?.toInt() ?? 0,
      pendingOrders: (orders['pending'] as num?)?.toInt() ?? 0,
      todaySales: (json['todaySales'] as num?)?.toDouble() ?? 0,
      payLaterOutstanding:
          (json['payLaterOutstanding'] as num?)?.toDouble() ?? 0,
      payLaterOrderCount:
          (json['payLaterOrderCount'] as num?)?.toInt() ?? 0,
      recentOrders: (json['recentOrders'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => AdminRecentOrder.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class AdminRecentOrder {
  const AdminRecentOrder({
    required this.orderNumber,
    required this.customerName,
    required this.canteenName,
    required this.officeName,
    required this.amount,
    required this.orderStatus,
    required this.paymentStatus,
    required this.createdAt,
  });

  final String orderNumber;
  final String customerName;
  final String canteenName;
  final String officeName;
  final double amount;
  final String orderStatus;
  final String paymentStatus;
  final DateTime? createdAt;

  factory AdminRecentOrder.fromJson(Map<String, dynamic> json) {
    final canteen = Map<String, dynamic>.from(
      json['canteenSnapshot'] as Map? ?? {},
    );
    final office = Map<String, dynamic>.from(
      json['officeSnapshot'] as Map? ?? {},
    );
    return AdminRecentOrder(
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      canteenName: canteen['name']?.toString() ?? 'Canteen',
      officeName: office['companyName']?.toString() ?? 'Office',
      amount: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      orderStatus: json['orderStatus']?.toString() ?? 'Pending',
      paymentStatus: json['paymentStatus']?.toString() ?? 'Unpaid',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
