import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../models/canteen.dart';

/// Shared canteen selector used throughout the owner workspace.
///
/// A modal sheet is used instead of an Android dropdown so the choices never
/// render over the field or the page content.
class CanteenSelector extends StatelessWidget {
  const CanteenSelector({
    required this.canteens,
    required this.selectedId,
    required this.onChanged,
    this.label = 'Canteen',
    this.includeAll = false,
    this.allValue = 'all',
    super.key,
  });

  final List<Canteen> canteens;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool includeAll;
  final String allValue;

  String get _selectedName {
    if (includeAll && selectedId == allValue) return 'All canteens';
    for (final canteen in canteens) {
      if (canteen.id == selectedId) return canteen.name;
    }
    return canteens.isEmpty ? 'No canteens available' : canteens.first.name;
  }

  Future<void> _showPicker(BuildContext context) async {
    if (canteens.isEmpty && !includeAll) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select canteen',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (includeAll)
                      _CanteenChoice(
                        name: 'All canteens',
                        selected: selectedId == allValue,
                        icon: Icons.store_mall_directory_outlined,
                        onTap: () => Navigator.pop(sheetContext, allValue),
                      ),
                    ...canteens.map(
                      (canteen) => _CanteenChoice(
                        name: canteen.name,
                        selected: canteen.id == selectedId,
                        onTap: () => Navigator.pop(sheetContext, canteen.id),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected != selectedId) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _selectedName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CanteenChoice extends StatelessWidget {
  const _CanteenChoice({
    required this.name,
    required this.selected,
    required this.onTap,
    this.icon = Icons.storefront_outlined,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      tileColor: selected
          ? AppColors.primary.withValues(alpha: 0.07)
          : AppColors.surface,
      leading: Icon(
        icon,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
    ),
  );
}
