import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/canteen.dart';
import '../../../../shared/models/office.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/canteen_service.dart';
import '../../../../shared/services/office_service.dart';

class RegisterOfficeScreen extends StatefulWidget {
  const RegisterOfficeScreen({super.key});

  @override
  State<RegisterOfficeScreen> createState() => _RegisterOfficeScreenState();
}

class _RegisterOfficeScreenState extends State<RegisterOfficeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();

  List<Canteen> _canteens = [];
  final Set<String> _selectedCanteenIds = {};
  bool _isLoadingCanteens = true;
  bool _isSubmitting = false;
  String? _loadError;
  Office? _createdOffice;

  @override
  void initState() {
    super.initState();
    _loadCanteens();
  }

  @override
  void dispose() {
    _companyController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadCanteens() async {
    setState(() {
      _isLoadingCanteens = true;
      _loadError = null;
    });

    try {
      final canteens = await CanteenService.instance.getMyCanteens();
      if (!mounted) return;
      setState(() => _canteens = canteens);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _expireSession();
        return;
      }
      setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Unable to load your canteens.');
      }
    } finally {
      if (mounted) setState(() => _isLoadingCanteens = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCanteenIds.isEmpty) {
      _showMessage('Select at least one canteen for this office.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final office = await OfficeService.instance.createOffice(
        companyName: _companyController.text,
        building: _buildingController.text,
        floor: _floorController.text,
        address: _addressController.text,
        city: _cityController.text,
        state: _stateController.text,
        pincode: _pincodeController.text,
        contactPerson: _contactPersonController.text,
        contactNumber: _contactNumberController.text,
        canteenIds: _selectedCanteenIds.toList(),
      );

      if (!mounted) return;
      setState(() => _createdOffice = office);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _expireSession();
        return;
      }
      _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Unable to register the office right now.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _expireSession() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
  }

  @override
  Widget build(BuildContext context) {
    final office = _createdOffice;

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(office == null ? 'Register office' : 'Office ready'),
        leading: IconButton(
          tooltip: office == null ? 'Back' : 'Close',
          onPressed: () => context.pop(office != null),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: office == null ? _buildForm() : _OfficeCreated(office: office),
      ),
    );
  }

  Widget _buildForm() {
    if (_isLoadingCanteens) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _CenteredState(
        icon: Icons.cloud_off_outlined,
        title: 'Canteens unavailable',
        message: _loadError!,
        actionLabel: 'Try again',
        onAction: _loadCanteens,
      );
    }

    if (_canteens.isEmpty) {
      return _CenteredState(
        icon: Icons.storefront_outlined,
        title: 'Create a canteen first',
        message: 'An office must be connected to at least one canteen.',
        actionLabel: 'Create canteen',
        onAction: () => context.pushReplacement(AppRoutes.createCanteen),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1060),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 48),
            children: [
              const _FormHero(),
              const SizedBox(height: 24),
              _FormSection(
                icon: Icons.apartment_rounded,
                title: 'Office identity',
                child: _FieldGrid(
                  children: [
                    TextFormField(
                      controller: _companyController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Company or office name',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      validator: (value) => _required(value, 'Company name'),
                    ),
                    TextFormField(
                      controller: _contactPersonController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Contact person',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) => _required(value, 'Contact person'),
                    ),
                    TextFormField(
                      controller: _contactNumberController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Contact number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (!RegExp(
                          r'^[6-9]\d{9}$',
                        ).hasMatch(value?.trim() ?? '')) {
                          return 'Enter a valid 10-digit number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FormSection(
                icon: Icons.location_on_outlined,
                title: 'Delivery location',
                child: Column(
                  children: [
                    _FieldGrid(
                      children: [
                        TextFormField(
                          controller: _buildingController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Building or tower',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          validator: (value) => _required(value, 'Building'),
                        ),
                        TextFormField(
                          controller: _floorController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Floor (optional)',
                            prefixIcon: Icon(Icons.layers_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      textInputAction: TextInputAction.next,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Complete address',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      validator: (value) => _required(value, 'Address'),
                    ),
                    const SizedBox(height: 16),
                    _FieldGrid(
                      children: [
                        TextFormField(
                          controller: _cityController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'City'),
                          validator: (value) => _required(value, 'City'),
                        ),
                        TextFormField(
                          controller: _stateController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'State'),
                          validator: (value) => _required(value, 'State'),
                        ),
                        TextFormField(
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Pincode',
                            counterText: '',
                          ),
                          validator: (value) {
                            if (!RegExp(
                              r'^[1-9]\d{5}$',
                            ).hasMatch(value?.trim() ?? '')) {
                              return 'Enter a valid pincode';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _FormSection(
                icon: Icons.storefront_outlined,
                title: 'Canteens serving this office',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _canteens.map((canteen) {
                    final selected = _selectedCanteenIds.contains(canteen.id);
                    return _CanteenChoice(
                      canteen: canteen,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          selected
                              ? _selectedCanteenIds.remove(canteen.id)
                              : _selectedCanteenIds.add(canteen.id);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 230,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.qr_code_2_rounded),
                    label: Text(
                      _isSubmitting ? 'Creating office...' : 'Create office QR',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required';
    return null;
  }
}

class _FormHero extends StatelessWidget {
  const _FormHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172033), Color(0xFF26344F)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          _HeroIcon(icon: Icons.qr_code_2_rounded),
          SizedBox(width: 18),
          Expanded(
            child: Text(
              'Create one permanent QR for this office and connect every canteen that serves it.',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: AppColors.primary, size: 30),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 16)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class _CanteenChoice extends StatelessWidget {
  const _CanteenChoice({
    required this.canteen,
    required this.selected,
    required this.onTap,
  });
  final Canteen canteen;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 330),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canteen.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        canteen.city,
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
      ),
    );
  }
}

class _OfficeCreated extends StatelessWidget {
  const _OfficeCreated({required this.office});
  final Office office;

  Uint8List? get _qrBytes {
    try {
      final payload = office.qrCode.contains(',')
          ? office.qrCode.split(',').last
          : office.qrCode;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _qrBytes;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x100F172A),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 52,
                ),
                const SizedBox(height: 14),
                Text(
                  office.companyName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  office.officeCode,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 260,
                  height: 260,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: bytes == null
                      ? const Icon(Icons.qr_code_2_rounded, size: 150)
                      : Image.memory(bytes, fit: BoxFit.contain),
                ),
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: office.orderingUrl),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ordering link copied')),
                    );
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Copy ordering link'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.pop(true),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
