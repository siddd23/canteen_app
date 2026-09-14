import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/order_sound_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/owner_settings.dart';
import '../../../../shared/services/owner_account_service.dart';
import '../../../../shared/widgets/dashboard_shell.dart';

class OwnerSettingsWorkspace extends StatefulWidget {
  const OwnerSettingsWorkspace({
    required this.onSessionExpired,
    required this.onPasswordChanged,
    super.key,
  });

  final Future<void> Function() onSessionExpired;
  final Future<void> Function() onPasswordChanged;

  @override
  State<OwnerSettingsWorkspace> createState() =>
      _OwnerSettingsWorkspaceState();
}

class _OwnerSettingsWorkspaceState extends State<OwnerSettingsWorkspace> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _businessController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  OwnerSettings? _settings;
  bool _loading = true;
  bool _savingProfile = false;
  bool _savingPreferences = false;
  bool _changingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _orderSoundEnabled = true;
  bool _payLaterEnabled = true;
  int _defaultPreparationTime = 15;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await OwnerAccountService.instance.getProfile();
      if (!mounted) return;
      _apply(settings);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load account settings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(OwnerSettings settings) {
    setState(() {
      _settings = settings;
      _nameController.text = settings.name;
      _businessController.text = settings.businessName;
      _emailController.text = settings.email;
      _mobileController.text = settings.mobile;
      _orderSoundEnabled = settings.preferences.orderSoundEnabled;
      _payLaterEnabled = settings.preferences.payLaterEnabled;
      _defaultPreparationTime = settings.preferences.defaultPreparationTime;
      OrderSoundService.instance.enabled = _orderSoundEnabled;
    });
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate() || _savingProfile) return;
    setState(() => _savingProfile = true);
    try {
      final settings = await OwnerAccountService.instance.updateProfile(
        name: _nameController.text,
        businessName: _businessController.text,
        email: _emailController.text,
        mobile: _mobileController.text,
      );
      if (!mounted) return;
      _apply(settings);
      _message('Profile updated successfully', AppColors.success);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
      } else {
        _message(error.message, AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePreferences() async {
    if (_savingPreferences) return;
    setState(() => _savingPreferences = true);
    try {
      final settings = await OwnerAccountService.instance.updatePreferences(
        orderSoundEnabled: _orderSoundEnabled,
        payLaterEnabled: _payLaterEnabled,
        defaultPreparationTime: _defaultPreparationTime,
      );
      if (!mounted) return;
      _apply(settings);
      _message('Preferences updated successfully', AppColors.success);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
      } else {
        _message(error.message, AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate() || _changingPassword) return;
    setState(() => _changingPassword = true);
    try {
      final message = await OwnerAccountService.instance.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      _message(message, AppColors.success);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await widget.onPasswordChanged();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
      } else {
        _message(error.message, AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  void _message(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  String? _required(String? value, String label, {int min = 2}) {
    final text = value?.trim() ?? '';
    if (text.length < min) return 'Enter a valid $label';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_error!),
        ),
      );
    }

    return DashboardPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 44),
        children: [
          const Text(
            'Account settings',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_settings!.businessName} • ${_settings!.approvalStatus}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final profile = _SettingsCard(
                title: 'Profile and business',
                icon: Icons.badge_outlined,
                child: _profileForm(),
              );
              final preferences = _SettingsCard(
                title: 'Order preferences',
                icon: Icons.tune_rounded,
                child: _preferencesForm(),
              );
              if (!wide) {
                return Column(
                  children: [
                    profile,
                    const SizedBox(height: 18),
                    preferences,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: profile),
                  const SizedBox(width: 18),
                  Expanded(child: preferences),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _SettingsCard(
            title: 'Change password',
            icon: Icons.lock_outline_rounded,
            child: _passwordForm(),
          ),
        ],
      ),
    );
  }

  Widget _profileForm() => Form(
    key: _profileFormKey,
    child: Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Owner name'),
          validator: (value) => _required(value, 'owner name'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _businessController,
          decoration: const InputDecoration(labelText: 'Business name'),
          validator: (value) => _required(value, 'business name'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
          validator: (value) {
            final text = value?.trim() ?? '';
            return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
                ? null
                : 'Enter a valid email address';
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(labelText: 'Mobile number'),
          validator: (value) => RegExp(r'^[6-9]\d{9}$').hasMatch(value ?? '')
              ? null
              : 'Enter a valid mobile number',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _savingProfile ? null : _saveProfile,
            icon: _savingProfile
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save profile'),
          ),
        ),
      ],
    ),
  );

  Widget _preferencesForm() => Column(
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('New-order sound'),
        subtitle: const Text('Play the doorbell sound for incoming orders.'),
        value: _orderSoundEnabled,
        onChanged: (value) => setState(() => _orderSoundEnabled = value),
      ),
      const Divider(),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Allow Pay Later'),
        subtitle: const Text('Permit delivered orders to be added to Pay Later.'),
        value: _payLaterEnabled,
        onChanged: (value) => setState(() => _payLaterEnabled = value),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        initialValue: _defaultPreparationTime,
        decoration: const InputDecoration(
          labelText: 'Default preparation time',
          helperText: 'Used when menu items do not specify a time.',
        ),
        items: const [0, 5, 10, 15, 20, 30, 45, 60]
            .map(
              (minutes) => DropdownMenuItem(
                value: minutes,
                child: Text(minutes == 0 ? 'Not specified' : '$minutes minutes'),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _defaultPreparationTime = value);
        },
      ),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _savingPreferences ? null : _savePreferences,
          icon: _savingPreferences
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.tune_rounded),
          label: const Text('Save preferences'),
        ),
      ),
    ],
  );

  Widget _passwordForm() => Form(
    key: _passwordFormKey,
    child: Column(
      children: [
        TextFormField(
          controller: _currentPasswordController,
          obscureText: _obscureCurrent,
          decoration: InputDecoration(
            labelText: 'Current password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
          validator: (value) => _required(value, 'current password', min: 1),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            labelText: 'New password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
              icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
          validator: (value) => _required(value, 'new password', min: 8),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm new password'),
          validator: (value) => value == _newPasswordController.text
              ? null
              : 'Passwords do not match',
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _changingPassword ? null : _changePassword,
            icon: const Icon(Icons.password_rounded),
            label: Text(_changingPassword ? 'Changing...' : 'Change password'),
          ),
        ),
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
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
