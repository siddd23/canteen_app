import 'package:flutter/material.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/services/employee_canteen_service.dart';
import 'employee_order_menu_screen.dart';

const _navy = Color(0xFF14233A);
const _teal = Color(0xFF147D77);
const _paper = Color(0xFFF5F7FA);

class EmployeeCanteensScreen extends StatefulWidget {
  const EmployeeCanteensScreen({super.key, this.pickForOrder = false});
  final bool pickForOrder;
  @override
  State<EmployeeCanteensScreen> createState() => _EmployeeCanteensScreenState();
}

class _EmployeeCanteensScreenState extends State<EmployeeCanteensScreen> {
  List<Map<String, dynamic>> _saved = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await EmployeeCanteenService.instance.saved();
      if (mounted) setState(() => _saved = data);
    } catch (e) { if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not load canteens'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _add() async {
    final controller = TextEditingController();
    final code = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 30),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: _teal.withValues(alpha: .09), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.add_business_rounded, color: _teal, size: 28)),
          const SizedBox(height: 18), const Text('Connect a canteen', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8), const Text('Enter the unique code provided by your canteen. It will be saved to your account.', style: TextStyle(height: 1.5, color: Colors.black54)),
          const SizedBox(height: 22),
          TextField(controller: controller, textCapitalization: TextCapitalization.characters, autocorrect: false,
            decoration: InputDecoration(labelText: 'Unique canteen code', hintText: 'CNT-1234ABCD', prefixIcon: const Icon(Icons.key_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
            onSubmitted: (v) => Navigator.pop(context, v)),
          const SizedBox(height: 20), SizedBox(width: double.infinity, height: 54, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () => Navigator.pop(context, controller.text), child: const Text('Add this canteen'))),
        ]),
      ),
    );
    // The input is no longer needed after the bottom sheet closes.
    if (!mounted || code == null || code.trim().isEmpty) return;
    try {
      await EmployeeCanteenService.instance.add(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canteen added to your collection')));
      await _refresh();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Unable to add canteen'))); }
  }

  Future<void> _remove(Map<String, dynamic> canteen) async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Remove canteen?'), content: Text('Remove ${canteen['name']} from your collection?'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove'))]));
    if (yes != true) return;
    try { await EmployeeCanteenService.instance.remove(canteen['id'].toString()); await _refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(backgroundColor: _paper, title: Text(widget.pickForOrder ? 'Choose a canteen' : 'My canteens', style: const TextStyle(fontWeight: FontWeight.w800, color: _navy))),
    floatingActionButton: FloatingActionButton.extended(backgroundColor: _teal, foregroundColor: Colors.white, onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add canteen')),
    body: RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 110), children: [
      const Text('YOUR COLLECTION', style: TextStyle(color: _teal, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
      const SizedBox(height: 8), Text(widget.pickForOrder ? 'Where are we ordering from?' : 'Your favourite food spots', style: const TextStyle(color: _navy, fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8), Text('${_saved.length} connected canteen${_saved.length == 1 ? '' : 's'} • Available across your devices', style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 24),
      if (_loading) const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator()))
      else if (_error != null) Center(child: Column(children: [Text(_error!), TextButton(onPressed: _refresh, child: const Text('Try again'))]))
      else if (_saved.isEmpty) Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: Column(children: [
        const Icon(Icons.storefront_outlined, color: _teal, size: 65), const SizedBox(height: 14),
        const Text('Your next meal starts here', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: _navy)),
        const SizedBox(height: 8), const Text('Add your first canteen using its unique code to browse the menu and order.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 20), FilledButton(onPressed: _add, child: const Text('Connect a canteen')),
      ]))
      else ..._saved.map((c) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(22), child: InkWell(
        borderRadius: BorderRadius.circular(22), onTap: c['available'] == true ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeOrderMenuScreen(code: c['publicCode'].toString()))) : null,
        child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Container(width: 64, height: 68, decoration: BoxDecoration(color: _teal.withValues(alpha: .09), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.restaurant_rounded, color: _teal, size: 30)),
          const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c['name']}', style: const TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 5),
            Text('${c['city']} • ${c['publicCode']}', style: const TextStyle(color: Colors.black54, fontSize: 12)), const SizedBox(height: 8),
            Text(c['available'] == true ? 'VIEW MENU  →' : 'CURRENTLY UNAVAILABLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: .6, color: c['available'] == true ? _teal : Colors.orange.shade800)),
          ])), PopupMenuButton<String>(tooltip: 'Canteen options', onSelected: (v) { if (v == 'remove') _remove(c); }, itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove canteen'))]),
        ])),
      )))),
    ])),
  );
}

class EmployeeOrderChoiceScreen extends StatelessWidget {
  const EmployeeOrderChoiceScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: _paper,
    appBar: AppBar(backgroundColor: _paper, title: const Text('Order food', style: TextStyle(fontWeight: FontWeight.w800))),
    body: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16), const Text('How would you like to order?', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: _navy)),
      const SizedBox(height: 10), const Text('Your next delicious break is just a few taps away.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 30), _ChoiceCard(icon: Icons.qr_code_scanner_rounded, heading: 'Scan a QR code', detail: 'Use the QR code displayed at your office or canteen', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera scanning requires a QR scanner plugin. Use your saved canteens to order now.')))),
      const SizedBox(height: 16), _ChoiceCard(icon: Icons.storefront_rounded, heading: 'Added canteens', detail: 'Browse all the canteens you have saved and order directly', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeCanteensScreen(pickForOrder: true)))),
    ])),
  );
}
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.icon, required this.heading, required this.detail, required this.onTap});
  final IconData icon; final String heading; final String detail; final VoidCallback onTap;
  @override Widget build(BuildContext context) => Material(color: Colors.white, borderRadius: BorderRadius.circular(22), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Padding(padding: const EdgeInsets.all(22), child: Row(children: [
    Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: _teal.withValues(alpha: .10), borderRadius: BorderRadius.circular(18)), child: Icon(icon, size: 32, color: _teal)),
    const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(heading, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)), const SizedBox(height: 5), Text(detail, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4))])), const Icon(Icons.arrow_forward_ios, size: 17, color: _teal),
  ]))));
}
