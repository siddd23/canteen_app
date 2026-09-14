import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/menu_snapshot.dart';
import 'api_service.dart';

class MenuService {
  MenuService._();

  static final MenuService instance = MenuService._();

  String _menuPath(String canteenId) => '/canteens/$canteenId/menu';

  Future<MenuSnapshot> getMenu(String canteenId) async {
    final response = await ApiService.instance.get(_menuPath(canteenId));
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return MenuSnapshot.fromJson(data);
  }

  Future<MenuCategory> createCategory({
    required String canteenId,
    required String name,
    required int displayOrder,
    required String status,
  }) async {
    final response = await ApiService.instance.post(
      '${_menuPath(canteenId)}/categories',
      body: {
        'name': name.trim(),
        'displayOrder': displayOrder,
        'status': status,
      },
    );
    return _categoryFromResponse(response);
  }

  Future<MenuCategory> updateCategory({
    required String canteenId,
    required String categoryId,
    required String name,
    required int displayOrder,
    required String status,
  }) async {
    final response = await ApiService.instance.patch(
      '${_menuPath(canteenId)}/categories/$categoryId',
      body: {
        'name': name.trim(),
        'displayOrder': displayOrder,
        'status': status,
      },
    );
    return _categoryFromResponse(response);
  }

  Future<CanteenMenuItem> createItem({
    required String canteenId,
    required String categoryId,
    required String name,
    required String description,
    required double price,
    required String foodType,
    required int preparationTime,
    required String imageUrl,
    required bool isAvailable,
  }) async {
    final response = await ApiService.instance.post(
      '${_menuPath(canteenId)}/items',
      body: {
        'categoryId': categoryId,
        'name': name.trim(),
        'description': description.trim(),
        'price': price,
        'foodType': foodType,
        'preparationTime': preparationTime,
        'imageUrl': imageUrl.trim(),
        'isAvailable': isAvailable,
      },
    );
    return _itemFromResponse(response);
  }

  Future<CanteenMenuItem> updateItem({
    required String canteenId,
    required String itemId,
    required String categoryId,
    required String name,
    required String description,
    required double price,
    required String foodType,
    required int preparationTime,
    required String imageUrl,
    required bool isAvailable,
  }) async {
    final response = await ApiService.instance.patch(
      '${_menuPath(canteenId)}/items/$itemId',
      body: {
        'categoryId': categoryId,
        'name': name.trim(),
        'description': description.trim(),
        'price': price,
        'foodType': foodType,
        'preparationTime': preparationTime,
        'imageUrl': imageUrl.trim(),
        'isAvailable': isAvailable,
      },
    );
    return _itemFromResponse(response);
  }

  Future<CanteenMenuItem> updateAvailability({
    required String canteenId,
    required String itemId,
    required bool isAvailable,
  }) async {
    final response = await ApiService.instance.patch(
      '${_menuPath(canteenId)}/items/$itemId/availability',
      body: {'isAvailable': isAvailable},
    );
    return _itemFromResponse(response);
  }

  MenuCategory _categoryFromResponse(Map<String, dynamic> response) {
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return MenuCategory.fromJson(
      Map<String, dynamic>.from(data['category'] as Map? ?? {}),
    );
  }

  CanteenMenuItem _itemFromResponse(Map<String, dynamic> response) {
    final data = Map<String, dynamic>.from(response['data'] as Map? ?? {});
    return CanteenMenuItem.fromJson(
      Map<String, dynamic>.from(data['item'] as Map? ?? {}),
    );
  }
}
