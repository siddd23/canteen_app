class SalesReportSummary {
  const SalesReportSummary({
    required this.placedOrders,
    required this.deliveredOrders,
    required this.grossSales,
    required this.averageOrderValue,
    required this.collectedAmount,
    required this.collectedOrders,
    required this.payLaterCreated,
    required this.payLaterCreatedOrders,
    required this.currentOutstanding,
    required this.currentOutstandingOrders,
  });

  final int placedOrders;
  final int deliveredOrders;
  final double grossSales;
  final double averageOrderValue;
  final double collectedAmount;
  final int collectedOrders;
  final double payLaterCreated;
  final int payLaterCreatedOrders;
  final double currentOutstanding;
  final int currentOutstandingOrders;

  factory SalesReportSummary.fromJson(Map<String, dynamic> json) =>
      SalesReportSummary(
        placedOrders: (json['placedOrders'] as num?)?.toInt() ?? 0,
        deliveredOrders: (json['deliveredOrders'] as num?)?.toInt() ?? 0,
        grossSales: (json['grossSales'] as num?)?.toDouble() ?? 0,
        averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0,
        collectedAmount: (json['collectedAmount'] as num?)?.toDouble() ?? 0,
        collectedOrders: (json['collectedOrders'] as num?)?.toInt() ?? 0,
        payLaterCreated: (json['payLaterCreated'] as num?)?.toDouble() ?? 0,
        payLaterCreatedOrders:
            (json['payLaterCreatedOrders'] as num?)?.toInt() ?? 0,
        currentOutstanding:
            (json['currentOutstanding'] as num?)?.toDouble() ?? 0,
        currentOutstandingOrders:
            (json['currentOutstandingOrders'] as num?)?.toInt() ?? 0,
      );
}

class DailySalesPoint {
  const DailySalesPoint({
    required this.date,
    required this.orderCount,
    required this.sales,
  });
  final String date;
  final int orderCount;
  final double sales;
  factory DailySalesPoint.fromJson(Map<String, dynamic> json) =>
      DailySalesPoint(
        date: json['date']?.toString() ?? '',
        orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
        sales: (json['sales'] as num?)?.toDouble() ?? 0,
      );
}

class TopSellingItem {
  const TopSellingItem({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
  final String name;
  final int quantity;
  final double revenue;
  factory TopSellingItem.fromJson(Map<String, dynamic> json) => TopSellingItem(
    name: json['name']?.toString() ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
  );
}

class OfficeSalesPoint {
  const OfficeSalesPoint({
    required this.companyName,
    required this.orderCount,
    required this.sales,
  });
  final String companyName;
  final int orderCount;
  final double sales;
  factory OfficeSalesPoint.fromJson(Map<String, dynamic> json) =>
      OfficeSalesPoint(
        companyName: json['companyName']?.toString() ?? 'Office',
        orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
        sales: (json['sales'] as num?)?.toDouble() ?? 0,
      );
}

class PaymentBreakdownPoint {
  const PaymentBreakdownPoint({
    required this.paymentStatus,
    required this.orderCount,
    required this.amount,
  });
  final String paymentStatus;
  final int orderCount;
  final double amount;
  factory PaymentBreakdownPoint.fromJson(Map<String, dynamic> json) =>
      PaymentBreakdownPoint(
        paymentStatus: json['paymentStatus']?.toString() ?? 'Unpaid',
        orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );
}

class SalesReport {
  const SalesReport({
    required this.dateFrom,
    required this.dateTo,
    required this.summary,
    required this.dailySales,
    required this.topItems,
    required this.officeSales,
    required this.paymentBreakdown,
  });
  final String dateFrom;
  final String dateTo;
  final SalesReportSummary summary;
  final List<DailySalesPoint> dailySales;
  final List<TopSellingItem> topItems;
  final List<OfficeSalesPoint> officeSales;
  final List<PaymentBreakdownPoint> paymentBreakdown;

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    final period = Map<String, dynamic>.from(
      json['period'] as Map? ?? const {},
    );
    List<T> list<T>(String key, T Function(Map<String, dynamic>) convert) =>
        (json[key] as List? ?? const [])
            .whereType<Map>()
            .map((item) => convert(Map<String, dynamic>.from(item)))
            .toList();
    return SalesReport(
      dateFrom: period['dateFrom']?.toString() ?? '',
      dateTo: period['dateTo']?.toString() ?? '',
      summary: SalesReportSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      ),
      dailySales: list('dailySales', DailySalesPoint.fromJson),
      topItems: list('topItems', TopSellingItem.fromJson),
      officeSales: list('officeSales', OfficeSalesPoint.fromJson),
      paymentBreakdown: list(
        'paymentBreakdown',
        PaymentBreakdownPoint.fromJson,
      ),
    );
  }
}
