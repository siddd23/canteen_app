import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/canteen.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/models/order_history.dart';
import '../../../../shared/services/order_service.dart';
import '../../../../shared/widgets/dashboard_shell.dart';

class OrderHistoryWorkspace extends StatefulWidget {
  const OrderHistoryWorkspace({
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
  State<OrderHistoryWorkspace> createState() => _OrderHistoryWorkspaceState();
}

class _OrderHistoryWorkspaceState extends State<OrderHistoryWorkspace> {
  static const _all = 'all';
  static const _statuses = [
    _all,
    'Pending',
    'Accepted',
    'Delivered',
    'Rejected',
    'Cancelled',
  ];
  static const _paymentStatuses = [_all, 'Unpaid', 'Paid', 'PayLater'];

  final TextEditingController _searchController = TextEditingController();
  OrderHistoryResult? _result;
  String _canteenId = _all;
  String _status = _all;
  String _paymentStatus = _all;
  DateTimeRange? _dateRange;
  String? _error;
  bool _loading = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    final initialId = widget.initialCanteenId;
    if (initialId != null && widget.canteens.any((c) => c.id == initialId)) {
      _canteenId = initialId;
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final requestedPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await OrderService.instance.getOrderHistory(
        canteenId: _canteenId == _all ? null : _canteenId,
        status: _status == _all ? null : _status,
        paymentStatus: _paymentStatus == _all ? null : _paymentStatus,
        search: _searchController.text,
        dateFrom: _dateRange?.start,
        dateTo: _dateRange?.end,
        page: requestedPage,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _page = result.page;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load order history.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _dateRange,
      helpText: 'Filter orders by date',
    );
    if (selected == null || !mounted) return;
    setState(() => _dateRange = selected);
    _load(page: 1);
  }

  void _reset() {
    _searchController.clear();
    setState(() {
      _canteenId = _all;
      _status = _all;
      _paymentStatus = _all;
      _dateRange = null;
      _page = 1;
    });
    _load(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
        children: [
          const Text(
            'Order History',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Search and review orders across your canteens',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          _HistoryFilters(
            canteens: widget.canteens,
            canteenId: _canteenId,
            status: _status,
            paymentStatus: _paymentStatus,
            dateRange: _dateRange,
            searchController: _searchController,
            onCanteenChanged: (value) {
              if (value == null) return;
              setState(() => _canteenId = value);
              if (value != _all) widget.onCanteenChanged(value);
              _load(page: 1);
            },
            onStatusChanged: (value) {
              if (value == null) return;
              setState(() => _status = value);
              _load(page: 1);
            },
            onPaymentChanged: (value) {
              if (value == null) return;
              setState(() => _paymentStatus = value);
              _load(page: 1);
            },
            onSearch: () => _load(page: 1),
            onPickDates: _pickDates,
            onClearDates: () {
              setState(() => _dateRange = null);
              _load(page: 1);
            },
            onReset: _reset,
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _HistoryMessage(
              icon: Icons.cloud_off_outlined,
              message: _error!,
              action: () => _load(),
            )
          else if (_result == null || _result!.orders.isEmpty)
            const _HistoryMessage(
              icon: Icons.manage_search_rounded,
              message: 'No orders match the selected filters.',
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_result!.totalOrders} '
                    '${_result!.totalOrders == 1 ? 'order' : 'orders'} found',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Page ${_result!.page} of ${_result!.totalPages}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._result!.orders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryOrderCard(order: order),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _result!.hasPreviousPage
                      ? () => _load(page: _page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Previous'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _result!.hasNextPage
                      ? () => _load(page: _page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Next'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.canteens,
    required this.canteenId,
    required this.status,
    required this.paymentStatus,
    required this.dateRange,
    required this.searchController,
    required this.onCanteenChanged,
    required this.onStatusChanged,
    required this.onPaymentChanged,
    required this.onSearch,
    required this.onPickDates,
    required this.onClearDates,
    required this.onReset,
  });

  final List<Canteen> canteens;
  final String canteenId;
  final String status;
  final String paymentStatus;
  final DateTimeRange? dateRange;
  final TextEditingController searchController;
  final ValueChanged<String?> onCanteenChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPaymentChanged;
  final VoidCallback onSearch;
  final VoidCallback onPickDates;
  final VoidCallback onClearDates;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
          decoration: InputDecoration(
            labelText: 'Search orders',
            hintText: 'Employee, mobile, office or order number',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: onSearch,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    initialValue: canteenId,
                    decoration: const InputDecoration(labelText: 'Canteen'),
                    items: [
                      const DropdownMenuItem(
                        value: _OrderHistoryWorkspaceState._all,
                        child: Text('All canteens'),
                      ),
                      ...canteens.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: onCanteenChanged,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Order status',
                    ),
                    items: _OrderHistoryWorkspaceState._statuses
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value == _OrderHistoryWorkspaceState._all
                                  ? 'All statuses'
                                  : value,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: onStatusChanged,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    initialValue: paymentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Payment status',
                    ),
                    items: _OrderHistoryWorkspaceState._paymentStatuses
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value == _OrderHistoryWorkspaceState._all
                                  ? 'All payments'
                                  : value == 'PayLater'
                                  ? 'Pay Later'
                                  : value,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: onPaymentChanged,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickDates,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  dateRange == null
                      ? 'Select date range'
                      : '${_shortDate(dateRange!.start)} – ${_shortDate(dateRange!.end)}',
                ),
              ),
            ),
            if (dateRange != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Clear dates',
                onPressed: onClearDates,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
            const SizedBox(width: 8),
            TextButton(onPressed: onReset, child: const Text('Reset filters')),
          ],
        ),
      ],
    ),
  );
}

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({required this.order});
  final CanteenOrder order;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
    backgroundColor: AppColors.surface,
    collapsedBackgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: const BorderSide(color: AppColors.border),
    ),
    collapsedShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: const BorderSide(color: AppColors.border),
    ),
    title: Row(
      children: [
        Expanded(
          child: Text(
            order.orderNumber,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '₹${_money(order.grandTotal)}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '${order.customerName} · ${order.mobile}\n${order.canteenName} · ${order.companyName}\n${_dateTime(order.createdAt)}',
      ),
    ),
    trailing: Wrap(
      spacing: 6,
      children: [
        _StatusChip(order.orderStatus),
        _StatusChip(order.paymentStatus),
      ],
    ),
    children: [
      const Divider(),
      ...order.items.map(
        (item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text('${item.quantity} × ${item.name}')),
              Text(
                '₹${_money(item.lineTotal)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
      if (order.customerNote.isNotEmpty) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Instruction: ${order.customerNote}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.value);
  final String value;
  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      'Delivered' || 'Paid' => AppColors.success,
      'Pending' || 'Unpaid' => AppColors.warning,
      'Accepted' => const Color(0xFF2563EB),
      _ => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value == 'PayLater' ? 'Pay Later' : value,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        Icon(icon, size: 52, color: AppColors.primary),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (action != null) ...[
          const SizedBox(height: 14),
          FilledButton(onPressed: action, child: const Text('Try again')),
        ],
      ],
    ),
  );
}

String _shortDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';
String _money(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
String _dateTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} · $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}
