import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/employee_order_tracking.dart';
import '../../../../shared/services/public_order_tracking_service.dart';
import '../../../../shared/services/realtime_service.dart';

class EmployeeOrderTrackingScreen extends StatefulWidget {
  const EmployeeOrderTrackingScreen({
    required this.orderNumber,
    required this.trackingToken,
    super.key,
  });

  final String orderNumber;
  final String trackingToken;

  @override
  State<EmployeeOrderTrackingScreen> createState() =>
      _EmployeeOrderTrackingScreenState();
}

class _EmployeeOrderTrackingScreenState
    extends State<EmployeeOrderTrackingScreen> {
  Timer? _pollTimer;
  EmployeeOrderTracking? _order;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _realtimeSubscription = RealtimeService.instance.orderUpdates.listen(
      _handleRealtimeUpdate,
    );
    RealtimeService.instance.connectEmployee(
      orderNumber: widget.orderNumber,
      trackingToken: widget.trackingToken,
    );
    _loadOrder();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _realtimeSubscription?.cancel();
    RealtimeService.instance.disconnect();
    super.dispose();
  }

  void _handleRealtimeUpdate(Map<String, dynamic> data) {
    if (!mounted || data['orderNumber']?.toString() != widget.orderNumber) return;
    final status = data['orderStatus']?.toString();
    _loadOrder(silent: true);
    if (status != null && status.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Order status updated: $status')));
    }
  }

  Future<void> _loadOrder({bool silent = false}) async {
    if (_isRefreshing) return;
    if (widget.orderNumber.isEmpty || widget.trackingToken.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'This order tracking link is incomplete.';
      });
      return;
    }

    _isRefreshing = true;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final order = await PublicOrderTrackingService.instance.getOrder(
        orderNumber: widget.orderNumber,
        trackingToken: widget.trackingToken,
      );
      if (!mounted) return;
      setState(() {
        _order = order;
        _isLoading = false;
        _errorMessage = null;
      });
      _schedulePolling(order);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (!silent || _order == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.message;
        });
      }
    } catch (_) {
      if (mounted && (!silent || _order == null)) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to refresh this order right now.';
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void _schedulePolling(EmployeeOrderTracking order) {
    _pollTimer?.cancel();
    if (!order.isFinal) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _loadOrder(silent: true),
      );
    } else {
      RealtimeService.instance.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Track your order'),
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            onPressed: _isRefreshing ? null : _loadOrder,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null && _order == null) {
      return _TrackingError(message: _errorMessage!, onRetry: _loadOrder);
    }

    final order = _order!;
    return RefreshIndicator(
      onRefresh: _loadOrder,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
        children: [
          _OrderHeader(order: order),
          const SizedBox(height: 16),
          _StatusTimeline(status: order.orderStatus),
          const SizedBox(height: 16),
          _OrderItems(order: order),
          const SizedBox(height: 16),
          _PaymentCard(order: order),
          const SizedBox(height: 14),
          Center(
            child: Text(
              order.isFinal
                  ? 'Final status received'
                  : 'Status refreshes automatically every 5 seconds',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});
  final EmployeeOrderTracking order;

  @override
  Widget build(BuildContext context) {
    final rejected = order.orderStatus == 'Rejected' ||
        order.orderStatus == 'Cancelled';
    final color = rejected ? AppColors.error : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              rejected ? Icons.cancel_outlined : Icons.restaurant_rounded,
              color: color,
              size: 29,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            order.orderStatus,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            order.orderNumber,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${order.canteenName} • ${order.companyName}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (order.estimatedPreparationTime > 0 && !order.isFinal) ...[
            const SizedBox(height: 12),
            Text(
              'Estimated preparation: ${order.estimatedPreparationTime} min',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    if (status == 'Rejected' || status == 'Cancelled') {
      return _InfoCard(
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status == 'Rejected'
                    ? 'The canteen could not accept this order.'
                    : 'This order has been cancelled.',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    const steps = ['Pending', 'Accepted', 'Delivered'];
    final current = steps.indexOf(status).clamp(0, steps.length - 1);
    return _InfoCard(
      child: Row(
        children: [
          for (var index = 0; index < steps.length; index++) ...[
            Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: index <= current
                        ? AppColors.success
                        : AppColors.border,
                    child: Icon(
                      index < current ? Icons.check_rounded : _icon(steps[index]),
                      color: AppColors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    steps[index],
                    style: TextStyle(
                      color: index <= current
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (index != steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: index < current ? AppColors.success : AppColors.border,
                ),
              ),
          ],
        ],
      ),
    );
  }

  IconData _icon(String value) => switch (value) {
    'Accepted' => Icons.restaurant_menu_rounded,
    'Delivered' => Icons.task_alt_rounded,
    _ => Icons.schedule_rounded,
  };
}

class _OrderItems extends StatelessWidget {
  const _OrderItems({required this.order});
  final EmployeeOrderTracking order;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order items',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          for (final item in order.items) ...[
            Row(
              children: [
                Expanded(child: Text('${item.quantity} × ${item.name}')),
                Text('₹${item.lineTotal.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 10),
          ],
          const Divider(),
          Row(
            children: [
              Text('${order.itemCount} items'),
              const Spacer(),
              Text(
                '₹${order.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});
  final EmployeeOrderTracking order;

  @override
  Widget build(BuildContext context) {
    final paid = order.paymentStatus == 'Paid';
    return _InfoCard(
      child: Row(
        children: [
          Icon(
            paid ? Icons.verified_outlined : Icons.account_balance_wallet_outlined,
            color: paid ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Payment status',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            order.paymentStatus,
            style: TextStyle(
              color: paid ? AppColors.success : AppColors.warning,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function({bool silent}) onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_off_rounded, size: 52, color: AppColors.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
