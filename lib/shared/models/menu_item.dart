class CanteenMenuItem {
  const CanteenMenuItem({
    required this.id,
    required this.canteenId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.foodType,
    required this.preparationTime,
    required this.imageUrl,
    required this.isAvailable,
    required this.availableDays,
  });

  final String id;
  final String canteenId;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String foodType;
  final int preparationTime;
  final String imageUrl;
  final bool isAvailable;
  final List<String> availableDays;

  bool get isVegetarian => foodType == 'Vegetarian';

  factory CanteenMenuItem.fromJson(Map<String, dynamic> json) {
    return CanteenMenuItem(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      canteenId: json['canteenId']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      foodType: json['foodType']?.toString() ?? 'Vegetarian',
      preparationTime: (json['preparationTime'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl']?.toString() ?? '',
      isAvailable: json['isAvailable'] as bool? ?? true,
      availableDays: (json['availableDays'] as List? ?? const <String>[])
          .map((day) => day.toString()).toList(),
    );
  }
}
