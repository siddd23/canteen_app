import 'package:flutter/material.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/services/customer_auth_service.dart';
import '../../../../shared/services/employee_canteen_service.dart';

const _ink = Color(0xFF14233A);
const _green = Color(0xFF147D77);

class EmployeeOrderMenuScreen extends StatefulWidget {
  const EmployeeOrderMenuScreen({required this.code, super.key});
  final String code;
  @override State<EmployeeOrderMenuScreen> createState() => _EmployeeOrderMenuScreenState();
}
class _EmployeeOrderMenuScreenState extends State<EmployeeOrderMenuScreen> {
  Map<String, dynamic>? data;
  final Map<String, int> counts = {};
  bool busy = true;
  String? error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { busy = true; error = null; });
    try { final result = await EmployeeCanteenService.instance.menu(widget.code); if (mounted) setState(() => data = result); }
    catch (e) { if (mounted) setState(() => error = e is ApiException ? e.message : 'Unable to load menu'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  List<Map<String, dynamic>> get items => (data?['items'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  double get total => items.fold(0, (sum, e) => sum + (num.tryParse('${e['price']}')?.toDouble() ?? 0) * (counts['${e['_id']}'] ?? 0));
  int get quantity => counts.values.fold(0, (s, n) => s + n);
  void _change(String id, int delta) => setState(() { final next = (counts[id] ?? 0) + delta; if (next <= 0) { counts.remove(id); } else if (next <= 20) { counts[id] = next; } });
  @override Widget build(BuildContext context) {
    final canteen = Map<String, dynamic>.from(data?['canteen'] as Map? ?? {});
    return Scaffold(backgroundColor: const Color(0xFFF5F7FA), appBar: AppBar(title: const Text('Explore menu', style: TextStyle(fontWeight: FontWeight.w800))),
      body: busy ? const Center(child: CircularProgressIndicator()) : error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: _load, child: const Text('Retry'))])) :
        ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 110), children: [
          Container(padding: const EdgeInsets.all(23), decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FRESH FROM THE KITCHEN', style: TextStyle(color: Color(0xFF76DBBF), letterSpacing: 1.5, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 13), Text('${canteen['name'] ?? 'Canteen'}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 6), Text('${canteen['city'] ?? ''} • ${widget.code}', style: const TextStyle(color: Colors.white70)),
          ])),
          const SizedBox(height: 25), const Text('Made for your cravings', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 12), if (items.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No available menu items today.'))),
          ...items.map((item) { final id = '${item['_id']}'; final count = counts[id] ?? 0;
            return Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Row(children: [
              Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: _green.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.lunch_dining_rounded, color: _green, size: 25)),
              const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink, fontSize: 16)),
                if ('${item['description'] ?? ''}'.isNotEmpty) Text('${item['description']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 7), Text('₹${item['price']}', style: const TextStyle(fontWeight: FontWeight.w900, color: _green, fontSize: 16))])),
              count == 0 ? IconButton.filledTonal(onPressed: () => _change(id, 1), icon: const Icon(Icons.add)) : Row(mainAxisSize: MainAxisSize.min, children: [IconButton(onPressed: () => _change(id, -1), icon: const Icon(Icons.remove_circle_outline, color: _green)), Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)), IconButton(onPressed: () => _change(id, 1), icon: const Icon(Icons.add_circle, color: _green))]),
            ])));
          }),
        ]),
      bottomNavigationBar: quantity == 0 ? null : SafeArea(child: Padding(padding: const EdgeInsets.all(15), child: SizedBox(height: 55, child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: _green), onPressed: () async { final placed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _CheckoutScreen(code: widget.code, counts: Map.of(counts), total: total))); if (placed == true && mounted) Navigator.pop(context); },
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('$quantity items'), const Text('Continue to checkout'), Text('₹${total.toStringAsFixed(0)}')]),
      )))),
    );
  }
}

class _CheckoutScreen extends StatefulWidget {
  const _CheckoutScreen({required this.code, required this.counts, required this.total});
  final String code; final Map<String, int> counts; final double total;
  @override State<_CheckoutScreen> createState() => _CheckoutScreenState();
}
class _CheckoutScreenState extends State<_CheckoutScreen> {
  final key = GlobalKey<FormState>();
  final building = TextEditingController(); final room = TextEditingController();
  final street = TextEditingController(); final city = TextEditingController();
  final pin = TextEditingController(); final note = TextEditingController();
  bool sending = false;
  @override void dispose() { for (final c in [building, room, street, city, pin, note]) { c.dispose(); } super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Checkout')), backgroundColor: const Color(0xFFF5F7FA), body: Form(key: key, child: ListView(padding: const EdgeInsets.all(22), children: [
    const Text('Almost there!', style: TextStyle(fontSize: 27, color: _ink, fontWeight: FontWeight.w900)),
    const SizedBox(height: 7), const Text('Tell us where your food should be delivered.', style: TextStyle(color: Colors.black54)), const SizedBox(height: 20),
    _field(building, 'Building / office name'), _field(room, 'Floor / room / desk'), _field(street, 'Street / area'), _field(city, 'City'), _field(pin, '6-digit PIN code', numeric: true),
    TextFormField(controller: note, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Special instructions (optional)', border: OutlineInputBorder())),
    const SizedBox(height: 12), Text('Order total   ₹${widget.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _ink)), const SizedBox(height: 20),
    SizedBox(height: 54, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _green), onPressed: sending ? null : _submit, child: Text(sending ? 'Placing your order...' : 'Place order'))),
  ])));
  Widget _field(TextEditingController c, String name, {bool numeric = false}) => Padding(padding: const EdgeInsets.only(bottom: 13), child: TextFormField(controller: c, keyboardType: numeric ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: name, border: const OutlineInputBorder()), validator: (v) {
    final value = v?.trim() ?? ''; if (numeric) return RegExp(r'^\d{6}$').hasMatch(value) ? null : 'Enter a valid 6-digit PIN'; return value.length < (name == 'Street / area' ? 3 : name == 'Floor / room / desk' ? 1 : 2) ? 'This field is required' : null;
  }));
  Future<void> _submit() async {
    if (!(key.currentState?.validate() ?? false)) return;
    setState(() => sending = true);
    try {
      final profile = await CustomerAuthService.instance.profile();
      await EmployeeCanteenService.instance.placeOrder(widget.code, {
        'customerName': profile.name, 'mobile': profile.mobile, 'customerNote': note.text.trim(),
        'deliveryAddress': {'buildingName': building.text.trim(), 'floorOrRoom': room.text.trim(), 'streetArea': street.text.trim(), 'city': city.text.trim(), 'pincode': pin.text.trim()},
        'items': widget.counts.entries.map((e) => {'menuItemId': e.key, 'quantity': e.value}).toList(),
        'fulfillmentType': 'asap',
      });
      if (!mounted) return;
      await showDialog<void>(context: context, barrierDismissible: false, builder: (c) => AlertDialog(title: const Text('Order placed! 🎉'), content: const Text('Your food is on its way to the kitchen. Track it in your Orders tab.'), actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))]));
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Unable to place order'))); }
    finally { if (mounted) setState(() => sending = false); }
  }
}
