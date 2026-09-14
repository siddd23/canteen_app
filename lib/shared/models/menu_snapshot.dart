import 'canteen.dart';
import 'menu_category.dart';
import 'menu_item.dart';

class MenuSummary {
  const MenuSummary({
    required this.totalCategories,
    required this.activeCategories,
    required this.totalItems,
    required this.availableItems,
    required this.unavailableItems,
  });

  final int totalCategories;
  final int activeCategories;
  final int totalItems;
  final int availableItems;
  final int unavailableItems;

  factory MenuSummary.fromJson(Map<String, dynamic> json) {
    return MenuSummary(
      totalCategories: (json['totalCategories'] as num?)?.toInt() ?? 0,
      activeCategories: (json['activeCategories'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      availableItems: (json['availableItems'] as num?)?.toInt() ?? 0,
      unavailableItems: (json['unavailableItems'] as num?)?.toInt() ?? 0,
    );
  }
}

class MenuSnapshot {
  const MenuSnapshot({
    required this.canteen,
    required this.categories,
    required this.items,
    required this.summary,
  });

  final Canteen canteen;
  final List<MenuCategory> categories;
  final List<CanteenMenuItem> items;
  final MenuSummary summary;

  factory MenuSnapshot.fromJson(Map<String, dynamic> data) {
    final canteenJson = Map<String, dynamic>.from(
      data['canteen'] as Map? ?? const {},
    );
    final categoryList = data['categories'] as List? ?? const [];
    final itemList = data['items'] as List? ?? const [];
    final summaryJson = Map<String, dynamic>.from(
      data['summary'] as Map? ?? const {},
    );

    return MenuSnapshot(
      canteen: Canteen.fromJson(canteenJson),
      categories: categoryList
          .whereType<Map>()
          .map(
            (category) =>
                MenuCategory.fromJson(Map<String, dynamic>.from(category)),
          )
          .toList(),
      items: itemList
          .whereType<Map>()
          .map(
            (item) => CanteenMenuItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      summary: MenuSummary.fromJson(summaryJson),
    );
  }
}
