import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/bookfood_logo_dark.png',
                      width: 286,
                      fit: BoxFit.contain,
                      semanticLabel: 'BookFood',
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome to BookFood',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Order food, track deliveries and manage canteens '
                      'from one connected platform.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 42),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.push(AppRoutes.employeeAuth),
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('Employee Login'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('${AppRoutes.employeeAuth}?mode=register'),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Create Employee Account'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Canteen owner')), Expanded(child: Divider())]),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.push(AppRoutes.login),
                        child: const Text('Owner Login'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.push(AppRoutes.register),
                        child: const Text('Register Canteen Owner'),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Guest ordering remains available by scanning an office '
                      'or canteen QR code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
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
