import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/services/customer_auth_service.dart';

class EmployeeAuthScreen extends StatefulWidget {
  const EmployeeAuthScreen({this.startWithRegister = false, super.key});

  final bool startWithRegister;

  @override
  State<EmployeeAuthScreen> createState() => _EmployeeAuthScreenState();
}

class _EmployeeAuthScreenState extends State<EmployeeAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _officeId = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  late bool _register;
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _register = widget.startWithRegister;
  }

  @override
  void dispose() {
    for (final controller in [_name, _mobile, _email, _officeId, _password, _confirmPassword]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _switchMode(bool register) {
    if (_busy || register == _register) return;
    setState(() => _register = register);
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      if (_register) {
        await CustomerAuthService.instance.signup(
          name: _name.text,
          mobile: _mobile.text,
          email: _email.text,
          officeId: _officeId.text,
          password: _password.text,
        );
      } else {
        await CustomerAuthService.instance.login(
          mobile: _mobile.text,
          password: _password.text,
        );
      }
      if (mounted) context.go(AppRoutes.employeeDashboard);
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('Unable to continue. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Employee access')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/bookfood_logo_dark.png', height: 54),
                    const SizedBox(height: 26),
                    Text(
                      _register ? 'Create employee account' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _register
                          ? 'Save your details, track orders and view your complete order history.'
                          : 'Login to view active orders, history and saved details.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Login'), icon: Icon(Icons.login)),
                        ButtonSegment(value: true, label: Text('Register'), icon: Icon(Icons.person_add_alt_1)),
                      ],
                      selected: {_register},
                      onSelectionChanged: (value) => _switchMode(value.first),
                    ),
                    const SizedBox(height: 24),
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                        validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter your full name' : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _mobile,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      maxLength: 10,
                      decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined), counterText: ''),
                      validator: (value) => RegExp(r'^[6-9]\d{9}$').hasMatch(value?.trim() ?? '') ? null : 'Enter a valid 10-digit mobile number',
                    ),
                    if (_register) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email address (optional)', prefixIcon: Icon(Icons.email_outlined)),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return null;
                          return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ? null : 'Enter a valid email address';
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _officeId,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Office ID (optional)', prefixIcon: Icon(Icons.business_outlined)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      textInputAction: _register ? TextInputAction.next : TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_register) _submit();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.length < 8) return 'Use at least 8 characters';
                        if (_register && (!RegExp('[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password))) {
                          return 'Password must contain letters and numbers';
                        }
                        return null;
                      },
                    ),
                    if (_register) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_reset_outlined)),
                        validator: (value) => value != _password.text ? 'Passwords do not match' : null,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_register ? Icons.person_add_alt_1 : Icons.login),
                      label: Text(_register ? 'Create account' : 'Login'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy ? null : () => context.pop(),
                      child: const Text('Continue as guest by scanning a canteen QR'),
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
