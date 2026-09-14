import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/canteen.dart';
import '../../../../shared/models/sales_report.dart';
import '../../../../shared/services/order_service.dart';
import '../../../../shared/widgets/dashboard_shell.dart';

class SalesReportsWorkspace extends StatefulWidget {
  const SalesReportsWorkspace({
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
  State<SalesReportsWorkspace> createState() => _SalesReportsWorkspaceState();
}

class _SalesReportsWorkspaceState extends State<SalesReportsWorkspace> {
  static const _all = 'all';
  SalesReport? _report;
  String _canteenId = _all;
  late DateTimeRange _range;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _range = DateTimeRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
    );
    final initialId = widget.initialCanteenId;
    if (initialId != null && widget.canteens.any((c) => c.id == initialId)) {
      _canteenId = initialId;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await OrderService.instance.getSalesReport(
        canteenId: _canteenId == _all ? null : _canteenId,
        dateFrom: _range.start,
        dateTo: _range.end,
      );
      if (mounted) setState(() => _report = report);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load sales reports.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _quickRange(int days) {
    final today = DateTime.now();
    setState(() {
      _range = DateTimeRange(
        start: today.subtract(Duration(days: days - 1)),
        end: today,
      );
    });
    _load();
  }

  Future<void> _customRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _range,
      helpText: 'Select report period',
    );
    if (range == null || !mounted) return;
    setState(() => _range = range);
    _load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: DashboardPage(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
        children: [
          const Text(
            'Sales & Collections',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Delivered sales, received payments and outstanding balances',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _ReportToolbar(
            canteens: widget.canteens,
            canteenId: _canteenId,
            range: _range,
            onCanteenChanged: (value) {
              if (value == null) return;
              setState(() => _canteenId = value);
              if (value != _all) widget.onCanteenChanged(value);
              _load();
            },
            onQuickRange: _quickRange,
            onCustomRange: _customRange,
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ReportState(message: _error!, onRetry: _load)
          else if (_report != null) ...[
            _SummaryGrid(summary: _report!.summary),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                final daily = _ReportPanel(
                  title: 'Daily sales',
                  child: _DailySalesList(points: _report!.dailySales),
                );
                final payments = _ReportPanel(
                  title: 'Payment breakdown',
                  child: _PaymentList(points: _report!.paymentBreakdown),
                );
                if (!wide)
                  return Column(
                    children: [daily, const SizedBox(height: 16), payments],
                  );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: daily),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: payments),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                final items = _ReportPanel(
                  title: 'Top-selling items',
                  child: _TopItemsList(items: _report!.topItems),
                );
                final offices = _ReportPanel(
                  title: 'Office-wise sales',
                  child: _OfficeSalesList(items: _report!.officeSales),
                );
                if (!wide)
                  return Column(
                    children: [items, const SizedBox(height: 16), offices],
                  );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: items),
                    const SizedBox(width: 16),
                    Expanded(child: offices),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}

class _ReportToolbar extends StatelessWidget {
  const _ReportToolbar({
    required this.canteens,
    required this.canteenId,
    required this.range,
    required this.onCanteenChanged,
    required this.onQuickRange,
    required this.onCustomRange,
  });
  final List<Canteen> canteens;
  final String canteenId;
  final DateTimeRange range;
  final ValueChanged<String?> onCanteenChanged;
  final ValueChanged<int> onQuickRange;
  final VoidCallback onCustomRange;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String>(
            initialValue: canteenId,
            decoration: const InputDecoration(labelText: 'Canteen'),
            items: [
              const DropdownMenuItem(
                value: _SalesReportsWorkspaceState._all,
                child: Text('All canteens'),
              ),
              ...canteens.map(
                (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
              ),
            ],
            onChanged: onCanteenChanged,
          ),
        ),
        for (final days in [7, 30, 90])
          ChoiceChip(
            label: Text('$days days'),
            selected: _isDays(range, days),
            onSelected: (_) => onQuickRange(days),
          ),
        OutlinedButton.icon(
          onPressed: onCustomRange,
          icon: const Icon(Icons.date_range_outlined),
          label: Text('${_shortDate(range.start)} – ${_shortDate(range.end)}'),
        ),
      ],
    ),
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final SalesReportSummary summary;
  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'Gross sales',
        '₹${_money(summary.grossSales)}',
        Icons.trending_up_rounded,
        AppColors.success,
      ),
      (
        'Collected',
        '₹${_money(summary.collectedAmount)}',
        Icons.payments_outlined,
        const Color(0xFF2563EB),
      ),
      (
        'Outstanding',
        '₹${_money(summary.currentOutstanding)}',
        Icons.account_balance_wallet_outlined,
        AppColors.error,
      ),
      (
        'Delivered orders',
        '${summary.deliveredOrders}',
        Icons.task_alt_rounded,
        AppColors.primary,
      ),
      (
        'Average order',
        '₹${_money(summary.averageOrderValue)}',
        Icons.receipt_outlined,
        AppColors.warning,
      ),
      (
        'Pay Later added',
        '₹${_money(summary.payLaterCreated)}',
        Icons.schedule_outlined,
        AppColors.warning,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics
              .map(
                (m) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: m.$4.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(m.$3, color: m.$4),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.$2,
                                style: const TextStyle(
                                  fontSize: 20,
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

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _DailySalesList extends StatelessWidget {
  const _DailySalesList({required this.points});
  final List<DailySalesPoint> points;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const _EmptyReport();
    final max = points.fold<double>(
      0,
      (value, item) => item.sales > value ? item.sales : value,
    );
    return Column(
      children: points.reversed
          .take(14)
          .map(
            (item) => _BarRow(
              label: item.date,
              value: '₹${_money(item.sales)} · ${item.orderCount} orders',
              fraction: max == 0 ? 0 : item.sales / max,
            ),
          )
          .toList(),
    );
  }
}

class _TopItemsList extends StatelessWidget {
  const _TopItemsList({required this.items});
  final List<TopSellingItem> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyReport();
    return Column(
      children: items
          .asMap()
          .entries
          .map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                child: Text('${entry.key + 1}'),
              ),
              title: Text(
                entry.value.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${entry.value.quantity} sold'),
              trailing: Text(
                '₹${_money(entry.value.revenue)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _OfficeSalesList extends StatelessWidget {
  const _OfficeSalesList({required this.items});
  final List<OfficeSalesPoint> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyReport();
    return Column(
      children: items
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.apartment_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                item.companyName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${item.orderCount} orders'),
              trailing: Text(
                '₹${_money(item.sales)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({required this.points});
  final List<PaymentBreakdownPoint> points;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const _EmptyReport();
    return Column(
      children: points
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.paymentStatus == 'PayLater'
                    ? 'Pay Later'
                    : item.paymentStatus,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${item.orderCount} orders'),
              trailing: Text(
                '₹${_money(item.amount)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.fraction,
  });
  final String label;
  final String value;
  final double fraction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: fraction,
          minHeight: 7,
          borderRadius: BorderRadius.circular(10),
          backgroundColor: AppColors.backgroundSoft,
        ),
      ],
    ),
  );
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        'No data for this period.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}

class _ReportState extends StatelessWidget {
  const _ReportState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 50, color: AppColors.error),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 14),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

bool _isDays(DateTimeRange range, int days) =>
    range.duration.inDays + 1 == days;
String _shortDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';
String _money(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
