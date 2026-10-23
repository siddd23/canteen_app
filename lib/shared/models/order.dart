class OrderItem {
  const OrderItem({
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  final String menuItemId;
  final String name;
  final double unitPrice;
  final int quantity;
  final double lineTotal;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    menuItemId: json['menuItemId']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
  );
}

class CanteenOrder {
  const CanteenOrder({
    required this.id,
    required this.orderNumber,
    required this.officeId,
    required this.canteenId,
    required this.companyName,
    required this.officeCode,
    required this.building,
    required this.floor,
    required this.officeAddress,
    required this.officeCity,
    required this.canteenName,
    required this.customerName,
    required this.mobile,
    required this.customerNote,
    required this.items,
    required this.itemCount,
    required this.grandTotal,
    required this.orderStatus,
    required this.paymentStatus,
    required this.fulfillmentType,
    required this.scheduledFor,
    required this.scheduledSlot,
    required this.createdAt,
    required this.orderSource,
    required this.deliveryBuildingName,
    required this.deliveryFloorOrRoom,
    required this.deliveryStreetArea,
    required this.deliveryLandmark,
    required this.deliveryCity,
    required this.deliveryPincode,
  });

  final String id;
  final String orderNumber;
  final String officeId;
  final String canteenId;
  final String companyName;
  final String officeCode;
  final String building;
  final String floor;
  final String officeAddress;
  final String officeCity;
  final String canteenName;
  final String customerName;
  final String mobile;
  final String customerNote;
  final List<OrderItem> items;
  final int itemCount;
  final double grandTotal;
  final String orderStatus;
  final String paymentStatus;
  final String fulfillmentType;
  final DateTime? scheduledFor;
  final String scheduledSlot;
  final DateTime? createdAt;
  final String orderSource;
  final String deliveryBuildingName;
  final String deliveryFloorOrRoom;
  final String deliveryStreetArea;
  final String deliveryLandmark;
  final String deliveryCity;
  final String deliveryPincode;

  bool get isMasterQrOrder => orderSource == 'canteen_master_qr';
  String get deliveryAddressLine => [
        deliveryBuildingName,
        deliveryFloorOrRoom,
        deliveryStreetArea,
        deliveryLandmark,
        deliveryCity,
        deliveryPincode,
      ].where((value) => value.trim().isNotEmpty).join(', ');

  bool get isPending => orderStatus == 'Pending';
  bool get isAccepted => orderStatus == 'Accepted';
  bool get isDelivered => orderStatus == 'Delivered';
  bool get needsPaymentDecision => isDelivered && paymentStatus == 'Unpaid';
  bool get isPayLater => paymentStatus == 'PayLater';
  bool get isScheduled => fulfillmentType == 'scheduled' && scheduledFor != null;
  String get billingLabel =>
      orderStatus == 'Rejected' || orderStatus == 'Cancelled'
          ? 'Not billable'
          : paymentStatus;

  factory CanteenOrder.fromJson(Map<String, dynamic> json) {
    final office = Map<String, dynamic>.from(
      json['officeSnapshot'] as Map? ?? const {},
    );
    final canteen = Map<String, dynamic>.from(
      json['canteenSnapshot'] as Map? ?? const {},
    );
    final delivery = Map<String, dynamic>.from(
      json['deliveryAddress'] as Map? ?? const {},
    );
    final rawItems = json['items'] as List? ?? const [];
    final parsedOrderStatus = json['orderStatus']?.toString() ?? 'Pending';
    final rawPaymentStatus = json['paymentStatus']?.toString() ?? 'Unpaid';
    final parsedPaymentStatus =
        parsedOrderStatus == 'Rejected' || parsedOrderStatus == 'Cancelled'
            ? 'Voided'
            : rawPaymentStatus;
    return CanteenOrder(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      officeId: json['officeId']?.toString() ?? '',
      canteenId: json['canteenId']?.toString() ?? '',
      companyName: office['companyName']?.toString() ?? '',
      officeCode: office['officeCode']?.toString() ?? '',
      building: office['building']?.toString() ?? '',
      floor: office['floor']?.toString() ?? '',
      officeAddress: office['address']?.toString() ?? '',
      officeCity: office['city']?.toString() ?? '',
      canteenName: canteen['name']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      customerNote: json['customerNote']?.toString() ?? '',
      items: rawItems
          .whereType<Map>()
          .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      orderStatus: parsedOrderStatus,
      paymentStatus: parsedPaymentStatus,
      fulfillmentType: json['fulfillmentType']?.toString() ?? 'asap',
      scheduledFor: DateTime.tryParse(json['scheduledFor']?.toString() ?? ''),
      scheduledSlot: json['scheduledSlot']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      orderSource: json['orderSource']?.toString() ?? 'office_qr',
      deliveryBuildingName: delivery['buildingName']?.toString() ?? '',
      deliveryFloorOrRoom: delivery['floorOrRoom']?.toString() ?? '',
      deliveryStreetArea: delivery['streetArea']?.toString() ?? '',
      deliveryLandmark: delivery['landmark']?.toString() ?? '',
      deliveryCity: delivery['city']?.toString() ?? '',
      deliveryPincode: delivery['pincode']?.toString() ?? '',
    );
  }
}
