class DashboardSummary {
  const DashboardSummary({
    required this.todayOrders,
    required this.pendingOrders,
    required this.activeOrders,
    required this.todaySales,
    required this.availableMenuItems,
    required this.payLaterOutstanding,
    required this.payLaterOrderCount,
    required this.businessDate,
    required this.updatedAt,
  });

  final int todayOrders;
  final int pendingOrders;
  final int activeOrders;
  final double todaySales;
  final int availableMenuItems;
  final double payLaterOutstanding;
  final int payLaterOrderCount;
  final String businessDate;
  final DateTime? updatedAt;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      todayOrders: (json['todayOrders'] as num?)?.toInt() ?? 0,
      pendingOrders: (json['pendingOrders'] as num?)?.toInt() ?? 0,
      activeOrders: (json['activeOrders'] as num?)?.toInt() ?? 0,
      todaySales: (json['todaySales'] as num?)?.toDouble() ?? 0,
      availableMenuItems: (json['availableMenuItems'] as num?)?.toInt() ?? 0,
      payLaterOutstanding:
          (json['payLaterOutstanding'] as num?)?.toDouble() ?? 0,
      payLaterOrderCount: (json['payLaterOrderCount'] as num?)?.toInt() ?? 0,
      businessDate: json['businessDate']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}
