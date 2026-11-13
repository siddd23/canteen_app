import 'package:flutter/material.dart';

import '../../../../core/utils/api_exception.dart';
import '../../../../shared/services/customer_auth_service.dart';

const _statusInk = Color(0xFF121212);
const _statusMuted = Color(0xFF6B7280);
const _statusBorder = Color(0xFFE5E7EB);
const _statusBg = Color(0xFFF6F7F9);
const _statusTeal = Color(0xFF147D77);

class EmployeeOrderStatusScreen extends StatefulWidget {
  const EmployeeOrderStatusScreen({required this.initialOrder, super.key});

  final Map<String, dynamic> initialOrder;

  @override
  State<EmployeeOrderStatusScreen> createState() =>
      _EmployeeOrderStatusScreenState();
}

class _EmployeeOrderStatusScreenState extends State<EmployeeOrderStatusScreen> {
  late Map<String, dynamic> _order;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.initialOrder);
  }

  Future<void> _refresh() async {
    final orderNumber = _order['orderNumber']?.toString() ?? '';
    if (orderNumber.isEmpty) return;
    setState(() => _refreshing = true);
    try {
      final latest = await CustomerAuthService.instance.orderByNumber(orderNumber);
      if (!mounted) return;
      setState(() => _order = latest);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to refresh this order right now')),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _order['orderStatus']?.toString() ?? 'Pending';
    final canteen = Map<String, dynamic>.from(
      _order['canteenSnapshot'] as Map? ?? const {},
    );
    final office = Map<String, dynamic>.from(
      _order['officeSnapshot'] as Map? ?? const {},
    );
    final items = (_order['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final address = Map<String, dynamic>.from(
      _order['deliveryAddress'] as Map? ?? const {},
    );

    return Scaffold(
      backgroundColor: _statusBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Order status',
          style: TextStyle(fontWeight: FontWeight.w800, color: _statusInk),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _StatusHeroCard(
              orderNumber: _order['orderNumber']?.toString() ?? 'Order',
              status: status,
              canteenName: canteen['name']?.toString() ?? 'Bookfood Canteen',
              officeName: office['companyName']?.toString() ?? '',
              amount: _money(_order['grandTotal']),
              itemCount: (_order['itemCount'] as num?)?.toInt() ?? items.length,
            ),
            const SizedBox(height: 14),
            _StatusSteps(status: status),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Items',
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i != 0) const Divider(height: 22, color: _statusBorder),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[i]['name']?.toString() ?? 'Item',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _statusInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty ${items[i]['quantity'] ?? 0}',
                                style: const TextStyle(color: _statusMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${_money(items[i]['lineTotal'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _statusInk,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 24, color: _statusBorder),
                  _RowLine(
                    label: 'Total',
                    value: '₹${_money(_order['grandTotal'])}',
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Order details',
              child: Column(
                children: [
                  _RowLine(label: 'Payment', value: _order['paymentStatus']?.toString() ?? 'Unpaid'),
                  const SizedBox(height: 10),
                  _RowLine(label: 'Fulfilment', value: (_order['fulfillmentType']?.toString() ?? 'asap').toUpperCase()),
                  if ((_order['scheduledSlot']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _RowLine(label: 'Slot', value: _order['scheduledSlot']?.toString() ?? ''),
                  ],
                  const SizedBox(height: 10),
                  _RowLine(label: 'Placed', value: _dateTime(_order['createdAt']?.toString())),
                  if ((_order['updatedAt']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _RowLine(label: 'Updated', value: _dateTime(_order['updatedAt']?.toString())),
                  ],
                ],
              ),
            ),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Delivery address',
                child: Text(
                  [
                    address['buildingName'],
                    address['floorOrRoom'],
                    address['streetArea'],
                    address['city'],
                    address['pincode'],
                  ].where((part) => (part?.toString().trim() ?? '').isNotEmpty).join(', '),
                  style: const TextStyle(height: 1.5, color: _statusInk),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({
    required this.orderNumber,
    required this.status,
    required this.canteenName,
    required this.officeName,
    required this.amount,
    required this.itemCount,
  });

  final String orderNumber;
  final String status;
  final String canteenName;
  final String officeName;
  final String amount;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _statusBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(style.icon, color: style.color),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontWeight: FontWeight.w800, color: style.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            canteenName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _statusInk,
            ),
          ),
          if (officeName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(officeName, style: const TextStyle(color: _statusMuted, fontSize: 14)),
          ],
          const SizedBox(height: 14),
          Text(
            orderNumber,
            style: const TextStyle(
              letterSpacing: 0.4,
              color: _statusMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MetricChip(label: 'Items', value: '$itemCount')),
              const SizedBox(width: 10),
              Expanded(child: _MetricChip(label: 'Amount', value: '₹$amount')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _statusMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: _statusInk)),
        ],
      ),
    );
  }
}

class _StatusSteps extends StatelessWidget {
  const _StatusSteps({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    if (status == 'Rejected' || status == 'Cancelled') {
      final style = _statusStyle(status);
      return _SectionCard(
        title: 'Status',
        child: Row(
          children: [
            Icon(style.icon, color: style.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status == 'Rejected'
                    ? 'The canteen could not accept this order.'
                    : 'This order has been cancelled.',
                style: const TextStyle(color: _statusInk, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    const steps = ['Pending', 'Accepted', 'Delivered'];
    final current = steps.indexOf(status);
    final activeIndex = current < 0 ? 0 : current;

    return _SectionCard(
      title: 'Status',
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: i <= activeIndex ? _statusTeal : _statusBorder,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      i < activeIndex ? Icons.check_rounded : _stepIcon(steps[i]),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: i <= activeIndex ? _statusInk : _statusMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (i != steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: i < activeIndex ? _statusTeal : _statusBorder,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _statusBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _statusInk,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RowLine extends StatelessWidget {
  const _RowLine({required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? _statusInk : _statusMuted,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: _statusInk,
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.color, this.background, this.icon);
  final Color color;
  final Color background;
  final IconData icon;
}

_StatusStyle _statusStyle(String status) {
  switch (status) {
    case 'Accepted':
      return const _StatusStyle(Color(0xFF0F8A5F), Color(0xFFE9F8F0), Icons.restaurant_rounded);
    case 'Delivered':
      return const _StatusStyle(Color(0xFF2563EB), Color(0xFFEAF1FF), Icons.check_circle_rounded);
    case 'Rejected':
      return const _StatusStyle(Color(0xFFDC2626), Color(0xFFFDECEC), Icons.cancel_rounded);
    case 'Cancelled':
      return const _StatusStyle(Color(0xFFB45309), Color(0xFFFFF4E5), Icons.remove_shopping_cart_rounded);
    default:
      return const _StatusStyle(_statusTeal, Color(0xFFE9F7F6), Icons.hourglass_top_rounded);
  }
}

IconData _stepIcon(String step) {
  switch (step) {
    case 'Pending':
      return Icons.receipt_long_rounded;
    case 'Accepted':
      return Icons.restaurant_rounded;
    case 'Delivered':
      return Icons.delivery_dining_rounded;
    default:
      return Icons.circle;
  }
}

String _money(dynamic value) {
  final amount = (value as num?)?.toDouble() ?? double.tryParse('$value') ?? 0;
  return amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
}

String _dateTime(String? raw) {
  final date = DateTime.tryParse(raw ?? '');
  if (date == null) return '—';
  final local = date.toLocal();
  final month = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][local.month - 1];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day} $month, $hour:$minute $period';
}
