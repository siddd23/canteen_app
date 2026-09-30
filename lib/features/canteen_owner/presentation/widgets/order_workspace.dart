import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/order_sound_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/canteen.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/services/order_service.dart';
import '../../../../shared/widgets/canteen_selector.dart';
import '../../../../shared/widgets/dashboard_shell.dart';

class OrderWorkspace extends StatefulWidget {
  const OrderWorkspace({
    required this.canteens,
    required this.initialCanteenId,
    required this.onCanteenChanged,
    required this.onSessionExpired,
    this.initialOrderId,
    this.realtimeVersion = 0,
    super.key,
  });

  final List<Canteen> canteens;
  final String? initialCanteenId;
  final ValueChanged<String> onCanteenChanged;
  final Future<void> Function() onSessionExpired;
  final String? initialOrderId;
  final int realtimeVersion;

  @override
  State<OrderWorkspace> createState() => _OrderWorkspaceState();
}

class _OrderWorkspaceState extends State<OrderWorkspace>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 12);
  static const _filters = ['Active', 'Pending', 'Accepted', 'Delivered', 'All'];
  List<CanteenOrder> _orders = [];
  String? _canteenId;
  String _filter = 'Active';
  String? _processingId;
  String? _error;
  bool _loading = true;
  bool _polling = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _canteenId = _validCanteenId(widget.initialCanteenId);
    _load().then((_) {
      if (mounted) _startPolling();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrderWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextCanteenId = _validCanteenId(widget.initialCanteenId);
    if (nextCanteenId != null && nextCanteenId != _canteenId) {
      _canteenId = nextCanteenId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    if (oldWidget.realtimeVersion != widget.realtimeVersion) {
      _load(silent: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
      _startPolling();
    } else {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _load(silent: true));
  }

  String? _validCanteenId(String? value) {
    if (widget.canteens.isEmpty) return null;
    return widget.canteens.any((item) => item.id == value)
        ? value
        : widget.canteens.first.id;
  }

  Future<void> _load({bool silent = false}) async {
    if (_canteenId == null) {
      if (!silent) setState(() => _loading = false);
      return;
    }
    if (_polling) {
      if (!silent) {
        Future<void>.delayed(
          const Duration(milliseconds: 350),
          () => mounted ? _load() : Future<void>.value(),
        );
      }
      return;
    }
    final requestedCanteenId = _canteenId!;
    _polling = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final orders = await OrderService.instance.getMyOrders(
        canteenId: requestedCanteenId,
      );
      if (mounted && requestedCanteenId == _canteenId) {
        setState(() => _orders = orders);
        final initialOrderId = widget.initialOrderId;
        if (initialOrderId != null && initialOrderId.isNotEmpty) {
          CanteenOrder? matching;
          for (final order in orders) {
            if (order.id == initialOrderId) {
              matching = order;
              break;
            }
          }
          if (matching != null) {
            if (matching.isPending) {
              unawaited(
                OrderSoundService.instance.startPendingOrderAlert(matching.id),
              );
            } else {
              unawaited(
                OrderSoundService.instance.stopPendingOrderAlert(matching.id),
              );
            }
          }
        }
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      if (!silent) setState(() => _error = error.message);
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _error = 'Unable to load orders right now.');
      }
    } finally {
      _polling = false;
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  List<CanteenOrder> get _visibleOrders => switch (_filter) {
    'Active' => _orders.where((o) => o.isPending || o.isAccepted).toList(),
    'Pending' => _orders.where((o) => o.isPending).toList(),
    'Accepted' => _orders.where((o) => o.isAccepted).toList(),
    'Delivered' => _orders.where((o) => o.isDelivered).toList(),
    _ => _orders,
  };

  Future<void> _update(
    CanteenOrder order,
    String status, {
    bool payment = false,
  }) async {
    if (status == 'Rejected') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject order?'),
          content: Text(
            '${order.orderNumber} will be permanently marked rejected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _processingId = order.id);
    try {
      final updated = payment
          ? await OrderService.instance.updatePayment(order.id, status)
          : await OrderService.instance.updateStatus(order.id, status);
      if (!mounted) return;
      setState(() {
        final index = _orders.indexWhere((item) => item.id == updated.id);
        if (index >= 0) _orders[index] = updated;
      });
      if (!updated.isPending) {
        unawaited(
          OrderSoundService.instance.stopPendingOrderAlert(updated.id),
        );
      }
      _message(
        payment
            ? (status == 'Paid' ? 'Payment received.' : 'Added to Pay Later.')
            : 'Order marked ${status.toLowerCase()}.',
        AppColors.success,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      _message(error.message, AppColors.error);
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  void _message(String text, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.canteens.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return const _OrderState(
        icon: Icons.storefront_outlined,
        title: 'Create a canteen before receiving orders.',
      );
    }
    if (_canteenId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return _OrderState(
        icon: Icons.cloud_off_outlined,
        title: _error!,
        action: _load,
      );

    return RefreshIndicator(
      onRefresh: _load,
      child: DashboardPage(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
          children: [
            _Toolbar(
              canteens: widget.canteens,
              selectedId: _canteenId!,
              onChanged: (id) {
                if (id == null) return;
                setState(() => _canteenId = id);
                widget.onCanteenChanged(id);
                _load();
              },
              onRefresh: _load,
            ),
            const SizedBox(height: 22),
            _OrderMetrics(orders: _orders),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters
                    .map(
                      (filter) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 18),
            if (_visibleOrders.isEmpty)
              const _OrderState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders in this view.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1050 ? 2 : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 14) / columns;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: _visibleOrders
                        .map(
                          (order) => SizedBox(
                            width: width,
                            child: _OrderCard(
                              order: order,
                              processing: _processingId == order.id,
                              onStatus: (status) => _update(order, status),
                              onPayment: (status) =>
                                  _update(order, status, payment: true),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.canteens,
    required this.selectedId,
    required this.onChanged,
    required this.onRefresh,
  });
  final List<Canteen> canteens;
  final String selectedId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final selector = CanteenSelector(
        canteens: canteens,
        selectedId: selectedId,
        onChanged: onChanged,
      );
      final title = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orders',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Live updates every 12 seconds',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      );
      if (constraints.maxWidth < 650)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 16), selector],
        );
      return Row(
        children: [
          Expanded(child: title),
          SizedBox(width: 310, child: selector),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onRefresh,
            tooltip: 'Refresh orders',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      );
    },
  );
}

class _OrderMetrics extends StatelessWidget {
  const _OrderMetrics({required this.orders});
  final List<CanteenOrder> orders;
  @override
  Widget build(BuildContext context) {
    final data = [
      (
        'Pending',
        orders.where((o) => o.isPending).length,
        Icons.schedule_rounded,
        AppColors.warning,
      ),
      (
        'Accepted',
        orders.where((o) => o.isAccepted).length,
        Icons.restaurant_rounded,
        const Color(0xFF2563EB),
      ),
      (
        'Delivered',
        orders.where((o) => o.isDelivered).length,
        Icons.task_alt_rounded,
        AppColors.success,
      ),
      (
        'Pay later',
        orders.where((o) => o.isPayLater).length,
        Icons.account_balance_wallet_outlined,
        AppColors.error,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: data
              .map(
                (m) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: m.$4.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(m.$3, color: m.$4),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${m.$2}',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              m.$1,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.processing,
    required this.onStatus,
    required this.onPayment,
  });
  final CanteenOrder order;
  final bool processing;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onPayment;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _time(order.createdAt),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _Chip(order.orderStatus),
          ],
        ),
        const SizedBox(height: 17),
        Row(
          children: [
            const Icon(
              Icons.person_outline_rounded,
              size: 19,
              color: AppColors.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '${order.customerName} · ${order.mobile}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.apartment_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '${order.companyName} · ${order.building}${order.floor.isEmpty ? '' : ', ${order.floor}'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            children: order.items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${item.quantity} × ${item.name}'),
                        ),
                        Text(
                          '₹${_money(item.lineTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (order.customerNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '“${order.customerNote}”',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Text(
                    'Total ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    '₹${_money(order.grandTotal)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            _Chip(order.paymentStatus),
          ],
        ),
        if (order.isPending) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: processing ? null : () => onStatus('Rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: processing ? null : () => onStatus('Accepted'),
                  child: processing
                      ? const _Spinner()
                      : const Text('Accept order'),
                ),
              ),
            ],
          ),
        ],
        if (order.isAccepted) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: processing ? null : () => onStatus('Delivered'),
              icon: const Icon(Icons.task_alt_rounded),
              label: processing
                  ? const _Spinner()
                  : const Text('Mark delivered'),
            ),
          ),
        ],
        if (order.needsPaymentDecision) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: processing ? null : () => onPayment('PayLater'),
                  child: const Text('Pay later'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: processing ? null : () => onPayment('Paid'),
                  child: processing
                      ? const _Spinner()
                      : const Text('Mark paid'),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  static String _money(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
  static String _time(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} · $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Pending' || 'Unpaid' => AppColors.warning,
      'Accepted' => const Color(0xFF2563EB),
      'Delivered' || 'Paid' => AppColors.success,
      _ => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label == 'PayLater' ? 'Pay Later' : label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
  );
}

class _OrderState extends StatelessWidget {
  const _OrderState({required this.icon, required this.title, this.action});
  final IconData icon;
  final String title;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(42),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.primary),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
