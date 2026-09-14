class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.canteenId,
    required this.name,
    required this.displayOrder,
    required this.status,
  });

  final String id;
  final String canteenId;
  final String name;
  final int displayOrder;
  final String status;

  bool get isActive => status == 'Active';

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      canteenId: json['canteenId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'Active',
    );
  }
}
