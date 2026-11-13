import 'package:flutter/material.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/services/employee_address_service.dart';

const _black = Color(0xFF101010);
const _grey = Color(0xFF6B7280);
const _background = Color(0xFFF6F7F9);
const _line = Color(0xFFE4E7EB);
const _teal = Color(0xFF147D77);

class EmployeeSavedAddressesScreen extends StatefulWidget {
  const EmployeeSavedAddressesScreen({this.selectForCheckout = false, super.key});
  final bool selectForCheckout;

  @override
  State<EmployeeSavedAddressesScreen> createState() => _EmployeeSavedAddressesScreenState();
}

class _EmployeeSavedAddressesScreenState extends State<EmployeeSavedAddressesScreen> {
  List<Map<String, dynamic>> addresses = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { loading = true; error = null; });
    try {
      final list = await EmployeeAddressService.instance.list();
      if (mounted) setState(() => addresses = list);
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : 'Unable to load addresses');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? address]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => _AddressFormScreen(existing: address),
    ));
    if (saved == true) await _refresh();
  }

  Future<void> _action(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Unable to update address')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(widget.selectForCheckout ? 'Delivery address' : 'Saved addresses',
          style: const TextStyle(fontWeight: FontWeight.w800, color: _black)),
      ),
      body: loading && addresses.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(error!, textAlign: TextAlign.center), TextButton(onPressed: _refresh, child: const Text('Retry')),
            ]))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  if (addresses.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                      child: const Column(children: [
                        Icon(Icons.location_on_outlined, color: _teal, size: 45),
                        SizedBox(height: 12),
                        Text('No saved addresses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      ]),
                    ),
                  for (final address in addresses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _line)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              const Icon(Icons.location_on_outlined, color: _teal),
                              const SizedBox(width: 9),
                              Expanded(child: Text('${address['label'] ?? 'Work'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                              if (address['isDefault'] == true)
                                const Text('DEFAULT', style: TextStyle(color: _teal, fontWeight: FontWeight.w800, fontSize: 11)),
                            ]),
                            const SizedBox(height: 10),
                            Text(addressDisplayText(address), style: const TextStyle(color: _grey, height: 1.4)),
                            const SizedBox(height: 14),
                            Wrap(spacing: 10, runSpacing: 8, children: [
                              if (widget.selectForCheckout)
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: _black),
                                  onPressed: () => Navigator.pop(context, Map<String, dynamic>.from(address)),
                                  child: const Text('Deliver here'),
                                ),
                              TextButton(onPressed: () => _edit(address), child: const Text('Edit')),
                              if (address['isDefault'] != true)
                                TextButton(onPressed: () => _action(() => EmployeeAddressService.instance.setDefault('${address['id']}')), child: const Text('Set default')),
                              TextButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                                    title: const Text('Delete address?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                    ],
                                  ));
                                  if (confirmed == true) _action(() => EmployeeAddressService.instance.remove('${address['id']}'));
                                },
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add new address'),
            ),
          ),
        ),
      ),
    );
  }
}

String addressDisplayText(Map<String, dynamic> address) => [
  address['buildingName'], address['floorOrRoom'], address['streetArea'],
  address['city'], address['pincode'],
].where((v) => (v?.toString().trim() ?? '').isNotEmpty).join(', ');

class _AddressFormScreen extends StatefulWidget {
  const _AddressFormScreen({this.existing});
  final Map<String, dynamic>? existing;
  @override
  State<_AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<_AddressFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final label = TextEditingController(text: widget.existing?['label']?.toString() ?? 'Work');
  late final building = TextEditingController(text: widget.existing?['buildingName']?.toString() ?? '');
  late final room = TextEditingController(text: widget.existing?['floorOrRoom']?.toString() ?? '');
  late final street = TextEditingController(text: widget.existing?['streetArea']?.toString() ?? '');
  late final city = TextEditingController(text: widget.existing?['city']?.toString() ?? '');
  late final pin = TextEditingController(text: widget.existing?['pincode']?.toString() ?? '');
  late bool isDefault = widget.existing?['isDefault'] == true;
  bool saving = false;

  @override
  void dispose() {
    for (final c in [label, building, room, street, city, pin]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    final address = <String, dynamic>{
      'label': label.text.trim(), 'buildingName': building.text.trim(),
      'floorOrRoom': room.text.trim(), 'streetArea': street.text.trim(),
      'city': city.text.trim(), 'pincode': pin.text.trim(), 'isDefault': isDefault,
    };
    try {
      if (widget.existing == null) {
        await EmployeeAddressService.instance.add(address);
      } else {
        await EmployeeAddressService.instance.update('${widget.existing!['id']}', address);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Unable to save address')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(backgroundColor: Colors.white, title: Text(widget.existing == null ? 'Add address' : 'Edit address', style: const TextStyle(fontWeight: FontWeight.w800))),
    body: Form(key: formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          _field(label, 'Address label (Home / Work)', 1, max: 30),
          _field(building, 'Building / office name', 2, max: 120),
          _field(room, 'Floor / room / desk', 1, max: 80),
          _field(street, 'Street / area', 3, max: 200),
          _field(city, 'City', 2, max: 80),
          _field(pin, '6-digit PIN code', 6, numeric: true, max: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set as default', style: TextStyle(fontWeight: FontWeight.w700)),
            value: isDefault, activeColor: _teal,
            onChanged: (value) => setState(() => isDefault = value),
          ),
        ]),
      ),
    ])),
    bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: SizedBox(height: 54, child: FilledButton(
      onPressed: saving ? null : _save,
      style: FilledButton.styleFrom(backgroundColor: _black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: Text(saving ? 'Saving...' : 'Save address'),
    )))),
  );

  Widget _field(TextEditingController controller, String title, int min, {bool numeric = false, int max = 80}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: title, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (numeric) return RegExp(r'^\d{6}$').hasMatch(v) ? null : 'Enter a valid PIN';
        return v.length < min || v.length > max ? 'Enter a valid ${title.toLowerCase()}' : null;
      },
    ),
  );
}
