import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/services/canteen_service.dart';
import '../../../../shared/services/auth_service.dart';

class CreateCanteenScreen extends StatefulWidget {
  const CreateCanteenScreen({super.key});

  @override
  State<CreateCanteenScreen> createState() => _CreateCanteenScreenState();
}

class _CreateCanteenScreenState extends State<CreateCanteenScreen> {
  final _formKey = GlobalKey<FormState>();

  final _canteenNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _contactController = TextEditingController();
  final _openingTimeController = TextEditingController();
  final _closingTimeController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _canteenNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _contactController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }

    return null;
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null && mounted) {
      controller.text = MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(selectedTime);
    }
  }

  Future<void> _createCanteen() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final canteen = await CanteenService.instance.createCanteen(
        name: _canteenNameController.text,
        address: _addressController.text,
        city: _cityController.text,
        contactNumber: _contactController.text,
        openingTime: _openingTimeController.text,
        closingTime: _closingTimeController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Canteen created successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      final location = Uri(
        path: AppRoutes.ownerDashboard,
        queryParameters: {'canteen': canteen.name},
      ).toString();

      context.go(location);
    } on ApiException catch (error) {
      if (!mounted) return;

      if (error.statusCode == 401) {
        await AuthService.instance.logout();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your session has expired. Please log in again.'),
            backgroundColor: AppColors.error,
          ),
        );

        context.go(AppRoutes.login);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create the canteen. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Canteen')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 42,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Add your first canteen to start managing menus, '
                              'orders, payments and offices.',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _canteenNameController,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          _requiredValidator(value, 'canteen name'),
                      decoration: const InputDecoration(
                        labelText: 'Canteen name',
                        prefixIcon: Icon(Icons.restaurant_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 3,
                      validator: (value) =>
                          _requiredValidator(value, 'canteen address'),
                      decoration: const InputDecoration(
                        labelText: 'Complete address',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      textInputAction: TextInputAction.next,
                      validator: (value) => _requiredValidator(value, 'city'),
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final contact = value?.trim() ?? '';

                        if (contact.length != 10 ||
                            int.tryParse(contact) == null) {
                          return 'Enter a valid 10-digit contact number';
                        }

                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Canteen contact number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _openingTimeController,
                            readOnly: true,
                            onTap: () => _selectTime(_openingTimeController),
                            validator: (value) =>
                                _requiredValidator(value, 'opening time'),
                            decoration: const InputDecoration(
                              labelText: 'Opening time',
                              prefixIcon: Icon(Icons.schedule_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _closingTimeController,
                            readOnly: true,
                            onTap: () => _selectTime(_closingTimeController),
                            validator: (value) =>
                                _requiredValidator(value, 'closing time'),
                            decoration: const InputDecoration(
                              labelText: 'Closing time',
                              prefixIcon: Icon(Icons.schedule_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _createCanteen,
                      icon: _isLoading
                          ? const SizedBox.shrink()
                          : const Icon(Icons.add_business_outlined),
                      label: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Create Canteen'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
