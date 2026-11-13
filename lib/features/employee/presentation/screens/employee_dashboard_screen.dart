import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_router.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/customer_profile.dart';
import '../../../../shared/services/customer_auth_service.dart';
import 'employee_canteens_screen.dart';
import 'employee_order_status_screen.dart';
import 'employee_saved_addresses_screen.dart';

const _dashPaper = Color(0xFFF6F7F9);
const _dashBorder = Color(0xFFE5E7EB);
const _dashInk = Color(0xFF101010);
const _dashMuted = Color(0xFF6B7280);
const _dashTeal = Color(0xFF147D77);

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
    setState(() {
      _loading = true;
      _error = null;
    });
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
      _HomeTab(
        profile: _profile,
        orders: _orders,
        onOrders: () => setState(() => _index = 1),
        onRefresh: _load,
      ),
      _OrdersTab(orders: _orders, loading: _loading, onRefresh: _load),
      _ProfileTab(
        profile: _profile,
        onSaved: (profile) => setState(() => _profile = profile),
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: _dashPaper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Image.asset('assets/images/bookfood_logo_dark.png', height: 32),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
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
  const _HomeTab({
    required this.profile,
    required this.orders,
    required this.onOrders,
    required this.onRefresh,
  });

  final CustomerProfile? profile;
  final List<Map<String, dynamic>> orders;
  final VoidCallback onOrders;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final activeOrders = orders.where((o) {
      final status = o['orderStatus']?.toString().toLowerCase() ?? '';
      return !['delivered', 'rejected', 'cancelled'].contains(status);
    }).toList();
    final latestOrder = orders.isNotEmpty ? orders.first : null;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _dashBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Employee account',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1, color: _dashMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile?.name ?? 'Bookfood employee',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _dashInk),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeOrders.isEmpty
                            ? 'No active orders'
                            : '${activeOrders.length} active order${activeOrders.length == 1 ? '' : 's'} in progress',
                        style: const TextStyle(color: _dashMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.person_outline_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF14233A), Color(0xFF204D53)]),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.restaurant_menu_rounded, color: Color(0xFF95F0D9)),
                    SizedBox(width: 10),
                    Text(
                      'Food ordering',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _dashInk,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmployeeOrderChoiceScreen()),
                    ),
                    child: const Text('Order food', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeCanteensScreen()),
            ),
            child: Ink(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _dashBorder),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFFE8F7F3),
                    child: Icon(Icons.storefront_rounded, color: _dashTeal),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My canteens', style: TextStyle(fontWeight: FontWeight.w800, color: _dashInk)),
                        SizedBox(height: 4),
                        Text('Saved places and quick ordering', style: TextStyle(color: _dashMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _SummaryCard(label: 'Active', value: '${activeOrders.length}', icon: Icons.pending_actions_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(label: 'Total orders', value: '${orders.length}', icon: Icons.receipt_long_rounded)),
            ],
          ),
          if (latestOrder != null) ...[
            const SizedBox(height: 16),
            const Text('Latest order', style: TextStyle(fontWeight: FontWeight.w800, color: _dashInk)),
            const SizedBox(height: 10),
            _OrderCard(
              order: latestOrder,
              compact: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EmployeeOrderStatusScreen(initialOrder: latestOrder)),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextButton(
            onPressed: onOrders,
            child: const Text('View all orders'),
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _dashBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _dashInk),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _dashInk)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _dashMuted)),
        ],
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.orders, required this.loading, required this.onRefresh});

  final List<Map<String, dynamic>> orders;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading && orders.isEmpty) return const Center(child: CircularProgressIndicator());
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 140),
            Icon(Icons.receipt_long_outlined, size: 56, color: _dashMuted),
            SizedBox(height: 14),
            Center(child: Text('No orders yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _dashInk))),
            SizedBox(height: 8),
            Center(child: Text('Your placed orders will appear here.', style: TextStyle(color: _dashMuted))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _OrderCard(
          order: orders[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EmployeeOrderStatusScreen(initialOrder: orders[index])),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap, this.compact = true});

  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final canteen = Map<String, dynamic>.from(order['canteenSnapshot'] as Map? ?? const {});
    final status = order['orderStatus']?.toString() ?? 'Pending';
    final style = _statusStyle(status);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _dashBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order['orderNumber']?.toString() ?? 'Order',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: _dashInk),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(status, style: TextStyle(color: style.color, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(canteen['name']?.toString() ?? 'Bookfood canteen', style: const TextStyle(fontWeight: FontWeight.w700, color: _dashInk)),
            const SizedBox(height: 4),
            Text(
              '${order['itemCount'] ?? 0} items · ₹${_money(order['grandTotal'])}',
              style: const TextStyle(color: _dashMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _date(order['createdAt']?.toString()),
                    style: const TextStyle(color: _dashMuted, fontSize: 12),
                  ),
                ),
                if (!compact)
                  const Text('View status', style: TextStyle(color: _dashTeal, fontWeight: FontWeight.w800, fontSize: 13))
                else
                  const Icon(Icons.chevron_right_rounded, color: _dashMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.profile, required this.onSaved, required this.onLogout});
  final CustomerProfile? profile;
  final ValueChanged<CustomerProfile> onSaved;
  final Future<void> Function() onLogout;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile?.name);
  late final _mobile = TextEditingController(text: widget.profile?.mobile);
  late final _email = TextEditingController(text: widget.profile?.email);
  late final _office = TextEditingController(text: widget.profile?.officeId);
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile == null && widget.profile != null) {
      _name.text = widget.profile!.name;
      _mobile.text = widget.profile!.mobile;
      _email.text = widget.profile!.email;
      _office.text = widget.profile!.officeId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _office.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final profile = await CustomerAuthService.instance.updateProfile(
        name: _name.text,
        mobile: _mobile.text,
        email: _email.text,
        officeId: _office.text,
      );
      widget.onSaved(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _dashBorder),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Enter your name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined), counterText: ''),
                  validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid mobile number',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _office,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Office ID', prefixIcon: Icon(Icons.business_outlined)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_busy ? 'Saving...' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: Colors.white,
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Saved addresses', style: TextStyle(fontWeight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const EmployeeSavedAddressesScreen(),
          )),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : widget.onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _MiniStatusStyle {
  const _MiniStatusStyle(this.color, this.bg);
  final Color color;
  final Color bg;
}

_MiniStatusStyle _statusStyle(String status) {
  switch (status) {
    case 'Accepted':
      return const _MiniStatusStyle(Color(0xFF0F8A5F), Color(0xFFE9F8F0));
    case 'Delivered':
      return const _MiniStatusStyle(Color(0xFF2563EB), Color(0xFFEAF1FF));
    case 'Rejected':
      return const _MiniStatusStyle(Color(0xFFDC2626), Color(0xFFFDECEC));
    case 'Cancelled':
      return const _MiniStatusStyle(Color(0xFFB45309), Color(0xFFFFF4E5));
    default:
      return const _MiniStatusStyle(_dashTeal, Color(0xFFE9F7F6));
  }
}

String _money(dynamic value) {
  final amount = (value as num?)?.toDouble() ?? double.tryParse('$value') ?? 0;
  return amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
}

String _date(String? raw) {
  final date = DateTime.tryParse(raw ?? '');
  if (date == null) return '—';
  final local = date.toLocal();
  final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][local.month - 1];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day} $month · $hour:$minute $period';
}
