import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/canteen.dart';
import '../../../../shared/models/menu_category.dart';
import '../../../../shared/models/menu_item.dart';
import '../../../../shared/models/menu_snapshot.dart';
import '../../../../shared/services/menu_service.dart';
import '../../../../shared/widgets/canteen_selector.dart';
import '../../../../shared/widgets/dashboard_shell.dart';

class MenuWorkspace extends StatefulWidget {
  const MenuWorkspace({
    required this.canteens,
    required this.initialCanteenId,
    required this.onCanteenChanged,
    required this.onSessionExpired,
    super.key,
  });

  final List<Canteen> canteens;
  final String? initialCanteenId;
  final ValueChanged<String> onCanteenChanged;
  final Future<void> Function() onSessionExpired;

  @override
  State<MenuWorkspace> createState() => _MenuWorkspaceState();
}

class _MenuWorkspaceState extends State<MenuWorkspace> {
  final _searchController = TextEditingController();
  MenuSnapshot? _snapshot;
  String? _selectedCanteenId;
  String? _selectedCategoryId;
  bool _isLoading = true;
  String? _processingItemId;
  String? _errorMessage;

  List<CanteenMenuItem> get _visibleItems {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];

    final query = _searchController.text.trim().toLowerCase();
    return snapshot.items.where((item) {
      final categoryMatches =
          _selectedCategoryId == null || item.categoryId == _selectedCategoryId;
      final searchMatches =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
      return categoryMatches && searchMatches;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedCanteenId = _resolveInitialCanteenId();
    _loadMenu();
  }

  @override
  void didUpdateWidget(covariant MenuWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentStillExists = widget.canteens.any(
      (canteen) => canteen.id == _selectedCanteenId,
    );

    if (widget.canteens.isNotEmpty && !currentStillExists) {
      _selectedCanteenId = _resolveInitialCanteenId();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMenu();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _resolveInitialCanteenId() {
    if (widget.canteens.isEmpty) return null;
    if (widget.canteens.any((item) => item.id == widget.initialCanteenId)) {
      return widget.initialCanteenId;
    }
    return widget.canteens.first.id;
  }

  Future<void> _loadMenu() async {
    final canteenId = _selectedCanteenId;
    if (canteenId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await MenuService.instance.getMenu(canteenId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        if (!snapshot.categories.any(
          (category) => category.id == _selectedCategoryId,
        )) {
          _selectedCategoryId = null;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to load this menu right now.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectCanteen(String? canteenId) async {
    if (canteenId == null || canteenId == _selectedCanteenId) return;
    setState(() {
      _selectedCanteenId = canteenId;
      _selectedCategoryId = null;
      _snapshot = null;
    });
    widget.onCanteenChanged(canteenId);
    await _loadMenu();
  }

  Future<void> _openCategoryDialog([MenuCategory? category]) async {
    final result = await showDialog<_CategoryFormValue>(
      context: context,
      builder: (context) => _CategoryDialog(category: category),
    );
    if (result == null || _selectedCanteenId == null) return;

    try {
      if (category == null) {
        await MenuService.instance.createCategory(
          canteenId: _selectedCanteenId!,
          name: result.name,
          displayOrder: result.displayOrder,
          status: result.status,
        );
      } else {
        await MenuService.instance.updateCategory(
          canteenId: _selectedCanteenId!,
          categoryId: category.id,
          name: result.name,
          displayOrder: result.displayOrder,
          status: result.status,
        );
      }
      if (!mounted) return;
      _showMessage(
        category == null ? 'Category created.' : 'Category updated.',
      );
      await _loadMenu();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message, isError: true);
    }
  }

  Future<void> _showCategoryActions(MenuCategory category) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(category.name),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'edit'),
            child: const ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit category'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: Text(
                'Delete category',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await _openCategoryDialog(category);
    } else if (action == 'delete') {
      await _deleteCategory(category);
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete permanently'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteCategory(MenuCategory category) async {
    final canteenId = _selectedCanteenId;
    if (canteenId == null) return;
    final itemCount = (_snapshot?.items ?? const <CanteenMenuItem>[])
        .where((item) => item.categoryId == category.id)
        .length;
    final confirmed = await _confirmDelete(
      title: 'Delete ${category.name}?',
      message: itemCount == 0
          ? 'This category will be permanently removed.'
          : 'This category contains $itemCount menu item${itemCount == 1 ? '' : 's'}. The category and all of those items will be permanently deleted.',
    );
    if (!confirmed || !mounted) return;

    try {
      await MenuService.instance.deleteCategory(
        canteenId: canteenId,
        categoryId: category.id,
        deleteItems: itemCount > 0,
      );
      if (!mounted) return;
      if (_selectedCategoryId == category.id) _selectedCategoryId = null;
      _showMessage(
        itemCount == 0
            ? 'Category deleted.'
            : 'Category and $itemCount item${itemCount == 1 ? '' : 's'} deleted.',
      );
      await _loadMenu();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message, isError: true);
    }
  }

  Future<void> _openItemDialog([CanteenMenuItem? item]) async {
    final categories = _snapshot?.categories ?? const <MenuCategory>[];
    if (categories.isEmpty) {
      _showMessage(
        'Create a category before adding menu items.',
        isError: true,
      );
      return;
    }

    final result = await showDialog<_ItemFormValue>(
      context: context,
      builder: (context) => _ItemDialog(categories: categories, item: item),
    );
    if (result == null || _selectedCanteenId == null) return;

    try {
      if (item == null) {
        await MenuService.instance.createItem(
          canteenId: _selectedCanteenId!,
          categoryId: result.categoryId,
          name: result.name,
          description: result.description,
          price: result.price,
          foodType: result.foodType,
          preparationTime: result.preparationTime,
          imageUrl: result.imageUrl,
          isAvailable: result.isAvailable,
          availableDays: result.availableDays,
        );
      } else {
        await MenuService.instance.updateItem(
          canteenId: _selectedCanteenId!,
          itemId: item.id,
          categoryId: result.categoryId,
          name: result.name,
          description: result.description,
          price: result.price,
          foodType: result.foodType,
          preparationTime: result.preparationTime,
          imageUrl: result.imageUrl,
          isAvailable: result.isAvailable,
          availableDays: result.availableDays,
        );
      }
      if (!mounted) return;
      _showMessage(item == null ? 'Menu item created.' : 'Menu item updated.');
      await _loadMenu();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message, isError: true);
    }
  }

  Future<void> _toggleAvailability(CanteenMenuItem item, bool value) async {
    final canteenId = _selectedCanteenId;
    if (canteenId == null) return;

    setState(() => _processingItemId = item.id);
    try {
      await MenuService.instance.updateAvailability(
        canteenId: canteenId,
        itemId: item.id,
        isAvailable: value,
      );
      if (!mounted) return;
      await _loadMenu();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _processingItemId = null);
    }
  }

  Future<void> _deleteItem(CanteenMenuItem item) async {
    final canteenId = _selectedCanteenId;
    if (canteenId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete ${item.name}?',
      message:
          'This menu item will be permanently removed. Past order history will remain unchanged.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _processingItemId = item.id);
    try {
      await MenuService.instance.deleteItem(
        canteenId: canteenId,
        itemId: item.id,
      );
      if (!mounted) return;
      _showMessage('Menu item deleted.');
      await _loadMenu();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _processingItemId = null);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.canteens.isEmpty) {
      return const _MenuState(
        icon: Icons.storefront_outlined,
        title: 'Create a canteen first',
        message: 'Menu items must belong to a canteen.',
      );
    }

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return _MenuState(
        icon: Icons.cloud_off_outlined,
        title: 'Menu unavailable',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onAction: _loadMenu,
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: DashboardPage(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 44),
          children: [
            _MenuHeader(
              canteens: widget.canteens,
              selectedCanteenId: _selectedCanteenId!,
              onCanteenChanged: _selectCanteen,
              onAddCategory: () => _openCategoryDialog(),
              onAddItem: () => _openItemDialog(),
            ),
            const SizedBox(height: 22),
            _MenuMetrics(summary: snapshot.summary),
            const SizedBox(height: 22),
            _CategoryStrip(
              categories: snapshot.categories,
              selectedCategoryId: _selectedCategoryId,
              onSelected: (id) => setState(() => _selectedCategoryId = id),
              onManage: _showCategoryActions,
            ),
            const SizedBox(height: 16),
            _MenuToolbar(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              onRefresh: _loadMenu,
            ),
            const SizedBox(height: 18),
            if (snapshot.categories.isEmpty)
              _MenuState(
                icon: Icons.category_outlined,
                title: 'Create your first category',
                message:
                    'Start with categories such as Breakfast or Beverages.',
                actionLabel: 'Add category',
                onAction: () => _openCategoryDialog(),
                embedded: true,
              )
            else if (snapshot.items.isEmpty)
              _MenuState(
                icon: Icons.ramen_dining_outlined,
                title: 'Add your first menu item',
                message: 'Items added here will later appear to employees.',
                actionLabel: 'Add menu item',
                onAction: () => _openItemDialog(),
                embedded: true,
              )
            else if (_visibleItems.isEmpty)
              const _NoItemsFound()
            else
              _MenuItemGrid(
                items: _visibleItems,
                categories: snapshot.categories,
                processingItemId: _processingItemId,
                onEdit: _openItemDialog,
                onDelete: _deleteItem,
                onAvailabilityChanged: _toggleAvailability,
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.canteens,
    required this.selectedCanteenId,
    required this.onCanteenChanged,
    required this.onAddCategory,
    required this.onAddItem,
  });

  final List<Canteen> canteens;
  final String selectedCanteenId;
  final ValueChanged<String?> onCanteenChanged;
  final VoidCallback onAddCategory;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
        final selector = SizedBox(
          width: compact ? double.infinity : 290,
          child: CanteenSelector(
            canteens: canteens,
            selectedId: selectedCanteenId,
            onChanged: onCanteenChanged,
          ),
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onAddCategory,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Add category'),
            ),
            FilledButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add item'),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Menu',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 16),
              selector,
              const SizedBox(height: 12),
              actions,
            ],
          );
        }

        return Row(
          children: [
            const Expanded(
              child: Text(
                'Menu',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            selector,
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );
  }
}

class _MenuMetrics extends StatelessWidget {
  const _MenuMetrics({required this.summary});
  final MenuSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'Categories',
        summary.totalCategories,
        Icons.category_outlined,
        const Color(0xFF7C3AED),
      ),
      (
        'Menu items',
        summary.totalItems,
        Icons.restaurant_menu_rounded,
        const Color(0xFF2563EB),
      ),
      (
        'Available',
        summary.availableItems,
        Icons.check_circle_outline_rounded,
        AppColors.success,
      ),
      (
        'Unavailable',
        summary.unavailableItems,
        Icons.pause_circle_outline_rounded,
        AppColors.warning,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MenuMetricCard(
                    label: metric.$1,
                    value: metric.$2,
                    icon: metric.$3,
                    color: metric.$4,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MenuMetricCard extends StatelessWidget {
  const _MenuMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
    required this.onManage,
  });
  final List<MenuCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;
  final ValueChanged<MenuCategory> onManage;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All items'),
              selected: selectedCategoryId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                avatar: Icon(
                  category.isActive
                      ? Icons.circle
                      : Icons.pause_circle_outline_rounded,
                  size: category.isActive ? 9 : 17,
                  color: category.isActive
                      ? AppColors.success
                      : AppColors.textMuted,
                ),
                label: Text(category.name),
                selected: selectedCategoryId == category.id,
                onSelected: (_) => onSelected(category.id),
                onDeleted: () => onManage(category),
                deleteIcon: const Icon(Icons.more_horiz_rounded, size: 18),
                deleteButtonTooltipMessage: 'Category actions',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuToolbar extends StatelessWidget {
  const _MenuToolbar({
    required this.controller,
    required this.onChanged,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: const InputDecoration(
              hintText: 'Search menu items',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.outlined(
          tooltip: 'Refresh menu',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _MenuItemGrid extends StatelessWidget {
  const _MenuItemGrid({
    required this.items,
    required this.categories,
    required this.processingItemId,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailabilityChanged,
  });
  final List<CanteenMenuItem> items;
  final List<MenuCategory> categories;
  final String? processingItemId;
  final ValueChanged<CanteenMenuItem> onEdit;
  final ValueChanged<CanteenMenuItem> onDelete;
  final void Function(CanteenMenuItem item, bool value) onAvailabilityChanged;

  String _categoryName(String id) {
    for (final category in categories) {
      if (category.id == id) return category.name;
    }
    return 'Uncategorized';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1160
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 16)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _MenuItemCard(
                    item: item,
                    categoryName: _categoryName(item.categoryId),
                    isProcessing: processingItemId == item.id,
                    onEdit: () => onEdit(item),
                    onDelete: () => onDelete(item),
                    onAvailabilityChanged: (value) =>
                        onAvailabilityChanged(item, value),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.categoryName,
    required this.isProcessing,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailabilityChanged,
  });
  final CanteenMenuItem item;
  final String categoryName;
  final bool isProcessing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemImage(item: item),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _FoodTypeMark(vegetarian: item.isVegetarian),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Item actions',
                      enabled: !isProcessing,
                      icon: const Icon(Icons.more_vert_rounded, size: 21),
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit item'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                            ),
                            title: Text(
                              'Delete item',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  categoryName,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Text(
                  item.availableDays.isEmpty || item.availableDays.length == 7
                      ? 'Every day'
                      : item.availableDays.map((day) => day.substring(0, 3)).join(' · '),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Text(
                      '₹${_formatPrice(item.price)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (item.preparationTime > 0) ...[
                      const Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${item.preparationTime} min',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 13),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.isAvailable ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          color: item.isAvailable
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isProcessing)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.3),
                      )
                    else
                      Switch(
                        value: item.isAvailable,
                        onChanged: onAvailabilityChanged,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatPrice(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

class _ItemImage extends StatelessWidget {
  const _ItemImage({required this.item});
  final CanteenMenuItem item;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: 150,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF1E8), Color(0xFFFFE4D2)],
        ),
      ),
      child: const Icon(
        Icons.ramen_dining_rounded,
        color: AppColors.primary,
        size: 48,
      ),
    );
    if (item.imageUrl.isEmpty) return placeholder;
    return Image.network(
      item.imageUrl,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

class _FoodTypeMark extends StatelessWidget {
  const _FoodTypeMark({required this.vegetarian});
  final bool vegetarian;

  @override
  Widget build(BuildContext context) {
    final color = vegetarian ? AppColors.success : AppColors.error;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(border: Border.all(color: color, width: 1.5)),
      alignment: Alignment.center,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _CategoryFormValue {
  const _CategoryFormValue({
    required this.name,
    required this.displayOrder,
    required this.status,
  });
  final String name;
  final int displayOrder;
  final String status;
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});
  final MenuCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _orderController;
  late String _status;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _orderController = TextEditingController(
      text: (widget.category?.displayOrder ?? 0).toString(),
    );
    _status = widget.category?.status ?? 'Active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Add category' : 'Edit category'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Category name'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) return 'Enter at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Display order'),
                validator: (value) {
                  final number = int.tryParse(value?.trim() ?? '');
                  if (number == null || number < 0 || number > 999) {
                    return 'Enter a number between 0 and 999';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _CategoryFormValue(
                name: _nameController.text.trim(),
                displayOrder: int.parse(_orderController.text.trim()),
                status: _status,
              ),
            );
          },
          child: Text(
            widget.category == null ? 'Create category' : 'Save changes',
          ),
        ),
      ],
    );
  }
}

class _ItemFormValue {
  const _ItemFormValue({
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
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String foodType;
  final int preparationTime;
  final String imageUrl;
  final bool isAvailable;
  final List<String> availableDays;
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.categories, this.item});
  final List<MenuCategory> categories;
  final CanteenMenuItem? item;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _timeController;
  late final TextEditingController _imageController;
  late String _categoryId;
  late String _foodType;
  late bool _isAvailable;
  late Set<String> _availableDays;
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _priceController = TextEditingController(
      text: item == null ? '' : item.price.toString(),
    );
    _timeController = TextEditingController(
      text: (item?.preparationTime ?? 0).toString(),
    );
    _imageController = TextEditingController(text: item?.imageUrl ?? '');
    _categoryId =
        widget.categories.any((category) => category.id == item?.categoryId)
        ? item!.categoryId
        : widget.categories.first.id;
    _foodType = item?.foodType ?? 'Vegetarian';
    _isAvailable = item?.isAvailable ?? true;
    _availableDays = (item == null || item.availableDays.isEmpty)
        ? _days.toSet()
        : item.availableDays.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _timeController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add menu item' : 'Edit menu item'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: widget.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _categoryId = value);
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 2) return 'Enter at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: '₹ ',
                        ),
                        validator: (value) {
                          final number = double.tryParse(value?.trim() ?? '');
                          if (number == null || number < 0 || number > 100000) {
                            return 'Enter a valid price';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _timeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Preparation time',
                          suffixText: 'min',
                        ),
                        validator: (value) {
                          final number = int.tryParse(value?.trim() ?? '');
                          if (number == null || number < 0 || number > 180) {
                            return 'Use 0 to 180 minutes';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: _foodType,
                  decoration: const InputDecoration(labelText: 'Food type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Vegetarian',
                      child: Text('Vegetarian'),
                    ),
                    DropdownMenuItem(
                      value: 'Non-Vegetarian',
                      child: Text('Non-Vegetarian'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _foodType = value);
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _imageController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final uri = Uri.tryParse(text);
                    if (uri == null ||
                        !uri.hasScheme ||
                        uri.host.isEmpty ||
                        !['http', 'https'].contains(uri.scheme)) {
                      return 'Enter a valid HTTP or HTTPS URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for ordering'),
                  value: _isAvailable,
                  onChanged: (value) => setState(() => _isAvailable = value),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Available days', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _days.map((day) => FilterChip(
                      label: Text(day.substring(0, 3)),
                      selected: _availableDays.contains(day),
                      onSelected: (selected) => setState(() {
                        if (selected) { _availableDays.add(day); } else if (_availableDays.length > 1) { _availableDays.remove(day); }
                      }),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ItemFormValue(
                categoryId: _categoryId,
                name: _nameController.text.trim(),
                description: _descriptionController.text.trim(),
                price: double.parse(_priceController.text.trim()),
                foodType: _foodType,
                preparationTime: int.parse(_timeController.text.trim()),
                imageUrl: _imageController.text.trim(),
                isAvailable: _isAvailable,
                availableDays: _days.where(_availableDays.contains).toList(),
              ),
            );
          },
          child: Text(widget.item == null ? 'Create item' : 'Save changes'),
        ),
      ],
    );
  }
}

class _MenuState extends StatelessWidget {
  const _MenuState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.embedded = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 54, color: AppColors.primary),
        const SizedBox(height: 15),
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 19),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
    if (embedded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: content,
      );
    }
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
  }
}

class _NoItemsFound extends StatelessWidget {
  const _NoItemsFound();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 46),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No matching menu items',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
