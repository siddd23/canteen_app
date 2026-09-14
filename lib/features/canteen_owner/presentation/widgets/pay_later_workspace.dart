import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/canteen.dart';
import '../../../../shared/models/pay_later_employee.dart';
import '../../../../shared/services/order_service.dart';
import '../../../../shared/widgets/dashboard_shell.dart';

class PayLaterWorkspace extends StatefulWidget {
  const PayLaterWorkspace({
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
  State<PayLaterWorkspace> createState() => _PayLaterWorkspaceState();
}

class _PayLaterWorkspaceState extends State<PayLaterWorkspace> {
  List<PayLaterEmployee> _employees = [];
  PayLaterSummary _summary = const PayLaterSummary(
    employeeCount: 0,
    orderCount: 0,
    totalOutstanding: 0,
  );
  String? _canteenId;
  String? _processingKey;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _canteenId = widget.canteens.any((c) => c.id == widget.initialCanteenId)
        ? widget.initialCanteenId
        : (widget.canteens.isEmpty ? null : widget.canteens.first.id);
    _load();
  }

  Future<void> _load() async {
    if (_canteenId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await OrderService.instance.getPayLaterEmployees(
        canteenId: _canteenId,
      );
      if (mounted) {
        setState(() {
          _employees = result.employees;
          _summary = result.summary;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Unable to load Pay Later accounts.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _settleAll(PayLaterEmployee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm full payment?'),
        content: Text(
          'Mark all ${employee.orderCount} bills for ${employee.customerName} '
          '(₹${_money(employee.totalOutstanding)}) as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Payment received'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _processingKey = employee.employeeKey);
    try {
      await OrderService.instance.settleEmployeePayLater(
        customerName: employee.customerName,
        mobile: employee.mobile,
        canteenId: _canteenId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All outstanding bills marked as paid.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton(onPressed: _load, child: Text(_error!)),
      );
    }
    if (widget.canteens.isEmpty) {
      return const Center(child: Text('Create a canteen first.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: DashboardPage(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay Later',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Outstanding employee accounts',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                );
                final selector = DropdownButtonFormField<String>(
                  initialValue: _canteenId,
                  decoration: const InputDecoration(
                    labelText: 'Canteen',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  items: widget.canteens
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    setState(() => _canteenId = id);
                    widget.onCanteenChanged(id);
                    _load();
                  },
                );
                if (constraints.maxWidth < 650) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 16), selector],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    SizedBox(width: 310, child: selector),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            _Summary(summary: _summary),
            const SizedBox(height: 22),
            if (_employees.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: Column(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 54,
                      color: AppColors.success,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'No outstanding employee bills',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._employees.map(
                (employee) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _EmployeeAccountCard(
                    employee: employee,
                    processing: _processingKey == employee.employeeKey,
                    onSettleAll: () => _settleAll(employee),
                    onSinglePaid: (orderId) async {
                      setState(() => _processingKey = employee.employeeKey);
                      try {
                        await OrderService.instance.updatePayment(
                          orderId,
                          'Paid',
                        );
                        await _load();
                      } finally {
                        if (mounted) setState(() => _processingKey = null);
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});
  final PayLaterSummary summary;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _Metric('Employees', '${summary.employeeCount}', Icons.people_outline),
      _Metric(
        'Unpaid bills',
        '${summary.orderCount}',
        Icons.receipt_long_outlined,
      ),
      _Metric(
        'Total outstanding',
        '₹${_money(summary.totalOutstanding)}',
        Icons.account_balance_wallet_outlined,
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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

class _EmployeeAccountCard extends StatelessWidget {
  const _EmployeeAccountCard({
    required this.employee,
    required this.processing,
    required this.onSettleAll,
    required this.onSinglePaid,
  });
  final PayLaterEmployee employee;
  final bool processing;
  final VoidCallback onSettleAll;
  final ValueChanged<String> onSinglePaid;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    backgroundColor: AppColors.surface,
    collapsedBackgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
    collapsedShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
    leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
    title: Text(
      employee.customerName,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    subtitle: Text(
      '${employee.mobile} · ${employee.orderCount} unpaid bill${employee.orderCount == 1 ? '' : 's'}',
    ),
    trailing: Text(
      '₹${_money(employee.totalOutstanding)}',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.error,
      ),
    ),
    children: [
      ...employee.orders.map(
        (order) => Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '₹${_money(order.grandTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('${item.quantity} × ${item.name}')),
                      Text('₹${_money(item.lineTotal)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: processing ? null : () => onSinglePaid(order.id),
                  child: const Text('Mark this bill paid'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: processing ? null : onSettleAll,
          icon: const Icon(Icons.payments_outlined),
          label: Text(
            processing
                ? 'Updating...'
                : 'Receive full payment · ₹${_money(employee.totalOutstanding)}',
          ),
        ),
      ),
    ],
  );
}

String _money(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
