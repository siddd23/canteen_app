import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/role_card.dart';
import '../../../../core/routes/app_router.dart';
import 'package:go_router/go_router.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _showNextStep(BuildContext context, String role) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$role flow will be created next.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool useHorizontalLayout = constraints.maxWidth >= 900;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1150),
                  child: Column(
                    children: [
                      const _PageHeader(),
                      const SizedBox(height: 40),
                      if (useHorizontalLayout)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildRoleCards(context)
                              .map(
                                (card) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: card,
                                  ),
                                ),
                              )
                              .toList(),
                        )
                      else
                        Column(
                          children: _buildRoleCards(context)
                              .map(
                                (card) => Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: card,
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildRoleCards(BuildContext context) {
    return [
      RoleCard(
        title: AppStrings.employee,
        description: AppStrings.employeeDescription,
        icon: Icons.badge_outlined,
        onTap: () => context.push(AppRoutes.employeeAuth),
      ),
      RoleCard(
        title: AppStrings.canteenOwner,
        description: AppStrings.canteenOwnerDescription,
        icon: Icons.storefront_outlined,
        onTap: () => _showNextStep(context, AppStrings.canteenOwner),
      ),
      RoleCard(
        title: AppStrings.superAdmin,
        description: AppStrings.superAdminDescription,
        icon: Icons.admin_panel_settings_outlined,
        onTap: () => _showNextStep(context, AppStrings.superAdmin),
      ),
    ];
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/bookfood_logo_dark.png',
          width: 230,
          fit: BoxFit.contain,
          semanticLabel: 'BookFood',
        ),
        const SizedBox(height: 22),
        Text(
          AppStrings.chooseRole,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          AppStrings.chooseRoleDescription,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
