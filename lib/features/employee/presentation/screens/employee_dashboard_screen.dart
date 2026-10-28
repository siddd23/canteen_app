import 'package:flutter/material.dart';
import 'employee_canteens_screen.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/customer_profile.dart';
import '../../../../shared/services/customer_auth_service.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  int _index = 0;
  CustomerProfile? _profile;
  List<Map<String, dynamic>> _orders = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait<dynamic>([
        CustomerAuthService.instance.profile(),
        CustomerAuthService.instance.orders(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = values[0] as CustomerProfile;
        _orders = values[1] as List<Map<String, dynamic>>;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await CustomerAuthService.instance.logout();
    if (mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(profile: _profile, orders: _orders, onOrders: () => setState(() => _index = 1)),
      _OrdersTab(orders: _orders, loading: _loading, onRefresh: _load),
      _ProfileTab(profile: _profile, onSaved: (profile) => setState(() => _profile = profile), onLogout: _logout),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/bookfood_logo_dark.png', height: 34),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
      ),
      body: _error != null && _profile == null
          ? _LoadError(message: _error!, onRetry: _load)
          : IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.profile, required this.orders, required this.onOrders});
  final CustomerProfile? profile;
  final List<Map<String, dynamic>> orders;
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) {
    final active = orders.where((o) => !['delivered', 'rejected', 'cancelled'].contains(o['orderStatus']?.toString().toLowerCase())).length;
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Hello, ${profile?.name.isNotEmpty == true ? profile!.name.split(' ').first : 'there'}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Order food, track your current order and keep your history in one place.', style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF14233A), Color(0xFF204D53)]), borderRadius: BorderRadius.circular(26)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.restaurant_menu_rounded, size: 35, color: Color(0xFF91E8D4)),
              const SizedBox(height: 17),
              const Text('Good food. Great workdays.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Your favourite canteens, one effortless ordering experience.', style: TextStyle(color: Colors.white70, height: 1.5)),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF14233A)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeOrderChoiceScreen())),
                icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Order food'))),
            ]),
          ),
          const SizedBox(height: 15),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: const CircleAvatar(backgroundColor: Color(0xFFE3F4F0), child: Icon(Icons.storefront_rounded, color: Color(0xFF147D77))),
            title: const Text('My canteens', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Connect with a unique code • Browse saved places'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeCanteensScreen())),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _SummaryCard(label: 'Active orders', value: '$active', icon: Icons.pending_actions_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(label: 'Past orders', value: '${orders.length}', icon: Icons.history)),
          ]),
          const SizedBox(height: 18),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
            leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
            title: const Text('View order history', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Check current and previous orders'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOrders,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 14), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: AppColors.textSecondary))])));
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.orders, required this.loading, required this.onRefresh});
  final List<Map<String, dynamic>> orders;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading && orders.isEmpty) return const Center(child: CircularProgressIndicator());
    if (orders.isEmpty) return RefreshIndicator(onRefresh: onRefresh, child: ListView(children: const [SizedBox(height: 180), Icon(Icons.receipt_long_outlined, size: 54), SizedBox(height: 14), Center(child: Text('No orders yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))), SizedBox(height: 6), Center(child: Text('Scan a BookFood QR to place your first order.'))]));
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: orders.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) return Text('Your orders', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800));
          final order = orders[index - 1];
          final canteen = Map<String, dynamic>.from(order['canteenSnapshot'] as Map? ?? {});
          final status = order['orderStatus']?.toString() ?? 'pending';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order['orderNumber']?.toString() ?? 'Order',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _StatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canteen['name']?.toString() ?? 'BookFood canteen',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order['itemCount'] ?? 0} items  •  ₹${_money(order['grandTotal'])}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (order['fulfillmentType'] == 'scheduled') ...[
                    const SizedBox(height: 8),
                    Text(
                      'Scheduled: ${_date(order['scheduledFor'])}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _money(dynamic value) => ((value as num?)?.toDouble() ?? 0).toStringAsFixed(0);
  static String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '-';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} $hour:$minute';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) { 'delivered' => AppColors.success, 'rejected' || 'cancelled' => AppColors.error, 'accepted' => Colors.blue, _ => AppColors.warning };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)), child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)));
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.profile, required this.onSaved, required this.onLogout});
  final CustomerProfile? profile;
  final ValueChanged<CustomerProfile> onSaved;
  final Future<void> Function() onLogout;
  @override State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile?.name);
  late final _mobile = TextEditingController(text: widget.profile?.mobile);
  late final _email = TextEditingController(text: widget.profile?.email);
  late final _office = TextEditingController(text: widget.profile?.officeId);
  bool _busy = false;

  @override void didUpdateWidget(covariant _ProfileTab oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.profile == null && widget.profile != null) { _name.text = widget.profile!.name; _mobile.text = widget.profile!.mobile; _email.text = widget.profile!.email; _office.text = widget.profile!.officeId; } }
  @override void dispose() { _name.dispose(); _mobile.dispose(); _email.dispose(); _office.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final profile = await CustomerAuthService.instance.updateProfile(name: _name.text, mobile: _mobile.text, email: _email.text, officeId: _office.text);
      widget.onSaved(profile);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
    } on ApiException catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    Text('Your profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 18),
    Form(key: _formKey, child: Column(children: [
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)), validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Enter your name' : null),
      const SizedBox(height: 14),
      TextFormField(controller: _mobile, keyboardType: TextInputType.phone, maxLength: 10, decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined), counterText: ''), validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid mobile number'),
      const SizedBox(height: 14),
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined))),
      const SizedBox(height: 14),
      TextFormField(controller: _office, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Office ID', prefixIcon: Icon(Icons.business_outlined))),
      const SizedBox(height: 22),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_busy ? 'Saving...' : 'Save changes'))),
    ])),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _busy ? null : widget.onLogout, icon: const Icon(Icons.logout), label: const Text('Logout'))),
  ]);
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 52), const SizedBox(height: 14), Text(message, textAlign: TextAlign.center), const SizedBox(height: 18), FilledButton(onPressed: onRetry, child: const Text('Try again'))])));
}
