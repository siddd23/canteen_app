import 'package:flutter/material.dart';

import '../../../../core/utils/api_exception.dart';
import '../../../../shared/services/customer_auth_service.dart';
import '../../../../shared/services/employee_canteen_service.dart';
import 'employee_order_tracking_screen.dart';
import 'employee_saved_addresses_screen.dart';
import '../../../../shared/services/employee_address_service.dart';

const _ink = Color(0xFF101010);
const _muted = Color(0xFF757575);
const _paper = Color(0xFFF6F7F9);
const _border = Color(0xFFE5E7EB);
const _teal = Color(0xFF147D77);

class EmployeeOrderMenuScreen extends StatefulWidget {
  const EmployeeOrderMenuScreen({required this.code, super.key});

  final String code;

  @override
  State<EmployeeOrderMenuScreen> createState() => _EmployeeOrderMenuScreenState();
}

class _EmployeeOrderMenuScreenState extends State<EmployeeOrderMenuScreen> {
  Map<String, dynamic>? data;
  final Map<String, int> counts = {};
  final TextEditingController searchController = TextEditingController();
  bool busy = true;
  String? error;
  String selectedCategory = 'all';
  String search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await EmployeeCanteenService.instance.menu(widget.code);
      if (!mounted) return;
      setState(() => data = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e is ApiException ? e.message : 'Unable to load menu');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Map<String, dynamic>> get items => (data?['items'] as List? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  List<Map<String, dynamic>> get categories => (data?['categories'] as List? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  Map<String, String> get categoryNameById => {
        for (final category in categories)
          '${category['_id']}': category['name']?.toString() ?? 'Menu',
      };

  List<Map<String, dynamic>> get filteredItems {
    final query = search.trim().toLowerCase();
    return items.where((item) {
      final matchesCategory = selectedCategory == 'all' || '${item['categoryId']}' == selectedCategory;
      final name = item['name']?.toString().toLowerCase() ?? '';
      final description = item['description']?.toString().toLowerCase() ?? '';
      final matchesSearch = query.isEmpty || name.contains(query) || description.contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  double get total => items.fold<double>(
        0,
        (sum, item) => sum + ((_price(item['price'])) * (counts['${item['_id']}'] ?? 0)),
      );

  int get quantity => counts.values.fold<int>(0, (sum, n) => sum + n);

  void _change(String id, int delta) {
    setState(() {
      final next = (counts[id] ?? 0) + delta;
      if (next <= 0) {
        counts.remove(id);
      } else if (next <= 20) {
        counts[id] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canteen = Map<String, dynamic>.from(data?['canteen'] as Map? ?? const {});
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 18,
        title: Image.asset('assets/images/bookfood_logo_dark.png', height: 28),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
                  if (quantity > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            quantity > 9 ? '9+' : '$quantity',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                    children: [
                      _CanteenInfoCard(canteen: canteen),
                      const SizedBox(height: 16),
                      TextField(
                        controller: searchController,
                        onChanged: (value) => setState(() => search = value),
                        decoration: InputDecoration(
                          hintText: 'Search dishes, snacks or drinks',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: const BorderSide(color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _CategoryChip(
                              label: 'All',
                              selected: selectedCategory == 'all',
                              onTap: () => setState(() => selectedCategory = 'all'),
                            ),
                            const SizedBox(width: 10),
                            for (var i = 0; i < categories.length; i++) ...[
                              _CategoryChip(
                                label: categories[i]['name']?.toString() ?? 'Menu',
                                selected: selectedCategory == '${categories[i]['_id']}',
                                onTap: () => setState(() => selectedCategory = '${categories[i]['_id']}'),
                              ),
                              if (i != categories.length - 1) const SizedBox(width: 10),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Explore the menu',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink),
                            ),
                          ),
                          Text(
                            '${filteredItems.length} items',
                            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (filteredItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _border),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 42, color: _muted),
                              SizedBox(height: 12),
                              Text('No items found', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                            ],
                          ),
                        ),
                      for (final item in filteredItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _MenuItemCard(
                            item: item,
                            categoryName: categoryNameById['${item['categoryId']}'] ?? 'Menu',
                            count: counts['${item['_id']}'] ?? 0,
                            onAdd: () => _change('${item['_id']}', 1),
                            onIncrement: () => _change('${item['_id']}', 1),
                            onDecrement: () => _change('${item['_id']}', -1),
                          ),
                        ),
                    ],
                  ),
                ),
      bottomNavigationBar: quantity == 0
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SizedBox(
                  height: 58,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () async {
                      final placed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _CheckoutScreen(
                            code: widget.code,
                            counts: Map.of(counts),
                            total: total,
                          ),
                        ),
                      );
                      if (placed == true && mounted) {
                        counts.clear();
                        setState(() {});
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$quantity item${quantity == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '₹${_money(total)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _CanteenInfoCard extends StatelessWidget {
  const _CanteenInfoCard({required this.canteen});
  final Map<String, dynamic> canteen;

  @override
  Widget build(BuildContext context) {
    final opening = canteen['openingTime']?.toString() ?? '';
    final closing = canteen['closingTime']?.toString() ?? '';
    final city = canteen['city']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.storefront_outlined, color: _ink, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DIRECT CANTEEN ORDERING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  canteen['name']?.toString() ?? 'Canteen',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: _muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [
                          if (city.isNotEmpty) city,
                          if (opening.isNotEmpty || closing.isNotEmpty) '$opening–$closing',
                        ].join(' · '),
                        style: const TextStyle(color: _muted, fontSize: 14),
                      ),
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
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.black : _border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.categoryName,
    required this.count,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  final Map<String, dynamic> item;
  final String categoryName;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item['imageUrl']?.toString() ?? '';
    final foodType = (item['foodType']?.toString() ?? 'Veg').trim();
    final foodTypeLabel = _foodTypeLabel(foodType);
    final description = item['description']?.toString() ?? '';
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 132,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(26),
                      bottomLeft: Radius.circular(26),
                    ),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imageFallback(),
                          )
                        : _imageFallback(),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: _foodTypeColor(foodType), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            foodTypeLabel,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryName.toUpperCase(),
                    style: const TextStyle(fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w900, color: _ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['name']?.toString() ?? 'Menu item',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description.isNotEmpty ? description : 'Freshly prepared and served hot.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.35, color: _muted),
                  ),
                  const Spacer(),
                  Text(
                    '₹${_money(_price(item['price']))}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: count == 0
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: Color(0xFFB9BDC4)),
                              foregroundColor: Colors.black,
                            ),
                            onPressed: onAdd,
                            child: const Text('+ Add', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFB9BDC4)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: IconButton(
                                    onPressed: onDecrement,
                                    icon: const Icon(Icons.remove_rounded),
                                  ),
                                ),
                                Text('$count', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                Expanded(
                                  child: IconButton(
                                    onPressed: onIncrement,
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: const Color(0xFFF2F3F5),
      child: const Center(
        child: Icon(Icons.fastfood_rounded, size: 38, color: Color(0xFF8A8F98)),
      ),
    );
  }
}

class _CheckoutScreen extends StatefulWidget {
  const _CheckoutScreen({required this.code, required this.counts, required this.total});
  final String code;
  final Map<String, int> counts;
  final double total;
  @override State<_CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<_CheckoutScreen> {
  Map<String, dynamic>? selectedAddress;
  bool loadingAddress = true;
  bool sending = false;
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final saved = await EmployeeAddressService.instance.list();
      if (!mounted) return;
      setState(() {
        selectedAddress = saved.isEmpty ? null : saved.firstWhere(
          (a) => a['isDefault'] == true, orElse: () => saved.first);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : 'Unable to load saved addresses')));
    } finally {
      if (mounted) setState(() => loadingAddress = false);
    }
  }

  Future<void> _chooseAddress() async {
    final chosen = await Navigator.push<Map<String, dynamic>>(
      context, MaterialPageRoute(builder: (_) => const EmployeeSavedAddressesScreen(selectForCheckout: true)));
    if (!mounted) return;
    if (chosen != null) {
      setState(() => selectedAddress = chosen);
    } else {
      await _loadAddress();
    }
  }

  @override void dispose() { note.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white,
      title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w800, color: _ink))),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Delivery address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink))),
            if (selectedAddress != null)
              TextButton(onPressed: sending ? null : _chooseAddress, child: const Text('Change')),
          ]),
          const SizedBox(height: 12),
          if (loadingAddress) const LinearProgressIndicator()
          else if (selectedAddress == null) ...[
            const Text('No address saved yet', style: TextStyle(color: _muted)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _chooseAddress, icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add delivery address'),
            )),
          ] else ...[
            Row(children: [
              const Icon(Icons.location_on_outlined, color: _teal),
              const SizedBox(width: 8),
              Text('${selectedAddress!['label'] ?? 'Work'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (selectedAddress!['isDefault'] == true) const Padding(padding: EdgeInsets.only(left: 10), child: Text('DEFAULT', style: TextStyle(fontSize: 11, color: _teal, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 10),
            Text(addressDisplayText(selectedAddress!), style: const TextStyle(color: _muted, height: 1.5)),
          ],
        ]),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _border)),
        child: TextField(
          controller: note, maxLength: 300, maxLines: 2,
          decoration: const InputDecoration(labelText: 'Special instructions (optional)', border: OutlineInputBorder()),
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _border)),
        child: Row(children: [
          const Expanded(child: Text('Order total', style: TextStyle(color: _muted))),
          Text('₹${widget.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
        ]),
      ),
    ]),
    bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(height: 56, child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        onPressed: sending || loadingAddress || selectedAddress == null ? null : _submit,
        child: Text(sending ? 'Placing order...' : 'Place order', style: const TextStyle(fontWeight: FontWeight.w800)),
      )))),
  );

  Future<void> _submit() async {
    final selected = selectedAddress;
    if (selected == null) return;
    setState(() => sending = true);
    try {
      // Verify the selected address still belongs to this employee before checkout.
      final saved = await EmployeeAddressService.instance.list();
      final matches = saved.where((a) => a['id'] == selected['id']).toList();
      if (matches.isEmpty) {
        throw StateError('This address is no longer saved. Choose another address.');
      }
      final currentAddress = matches.first;
      final profile = await CustomerAuthService.instance.profile();
      final result = await EmployeeCanteenService.instance.placeOrder(widget.code, {
        'customerName': profile.name,
        'mobile': profile.mobile,
        'customerNote': note.text.trim(),
        'deliveryAddress': {
          'buildingName': currentAddress['buildingName'],
          'floorOrRoom': currentAddress['floorOrRoom'],
          'streetArea': currentAddress['streetArea'],
          'city': currentAddress['city'],
          'pincode': currentAddress['pincode'],
        },
        'items': widget.counts.entries.map((e) => {'menuItemId': e.key, 'quantity': e.value}).toList(),
        'fulfillmentType': 'asap',
      });
      final order = Map<String, dynamic>.from(result['order'] as Map? ?? {});
      if (!mounted) return;
      if ((order['orderNumber']?.toString() ?? '').isNotEmpty && (order['trackingToken']?.toString() ?? '').isNotEmpty) {
        final navigator = Navigator.of(context);
        navigator.pop(true);
        navigator.push(MaterialPageRoute(builder: (_) => EmployeeOrderTrackingScreen(
          orderNumber: '${order['orderNumber']}', trackingToken: '${order['trackingToken']}',
        )));
      } else {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Order placed'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
        ));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e is StateError ? e.message : 'Unable to place order')));
    } finally { if (mounted) setState(() => sending = false); }
  }
}

String _foodTypeLabel(String foodType) {
  final type = foodType.trim().toLowerCase();
  if (type.contains('non')) return 'Non-veg';
  if (type.contains('egg')) return 'Egg';
  if (type.contains('veg')) return 'Veg';
  return foodType.length > 8 ? '${foodType.substring(0, 8)}…' : foodType;
}

Color _foodTypeColor(String foodType) {
  final lower = foodType.toLowerCase();
  if (lower.contains('non')) return const Color(0xFFDC2626);
  if (lower.contains('egg')) return const Color(0xFFD97706);
  return const Color(0xFF111111);
}

double _price(dynamic value) => (value as num?)?.toDouble() ?? double.tryParse('$value') ?? 0;

String _money(dynamic value) {
  final amount = _price(value);
  return amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
}
