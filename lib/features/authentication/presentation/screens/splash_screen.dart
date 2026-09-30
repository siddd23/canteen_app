import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../shared/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final results = await Future.wait<dynamic>([
      AuthService.instance.restoreSession(),
      PushNotificationService.instance.ready,
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);
    if (!mounted) return;

    final destination = results.first as String?;
    var route = switch (destination) {
      'admin_dashboard' => AppRoutes.adminDashboard,
      'owner_dashboard' => AppRoutes.ownerDashboard,
      'create_canteen' => AppRoutes.createCanteen,
      _ => AppRoutes.welcome,
    };
    if (destination == 'owner_dashboard') {
      final pending = PushNotificationService.instance.takePendingOrder();
      if (pending != null) route = pending.ownerRoute;
    }
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Logo(),
              SizedBox(height: 18),
              Text(
                'Fresh food. Faster ordering.',
                style: TextStyle(color: AppColors.white, fontSize: 16),
              ),
              SizedBox(height: 36),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/bookfood_logo_white.png',
      width: 276,
      fit: BoxFit.contain,
      semanticLabel: 'BookFood',
    );
  }
}
