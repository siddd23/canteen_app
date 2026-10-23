import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/screens/approval_pending_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/register_screen.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/authentication/presentation/screens/welcome_screen.dart';
import '../../features/canteen_owner/presentation/screens/create_canteen_screen.dart';
import '../../features/canteen_owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/canteen_owner/presentation/screens/register_office_screen.dart';
import '../../features/employee/presentation/screens/employee_menu_screen.dart';
import '../../features/employee/presentation/screens/employee_order_tracking_screen.dart';
import '../../features/employee/presentation/screens/employee_auth_screen.dart';
import '../../features/employee/presentation/screens/employee_dashboard_screen.dart';
import '../../features/super_admin/presentation/screens/admin_dashboard_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String approvalPending = '/approval-pending';

  static const String createCanteen = '/owner/canteens/create';
  static const String ownerDashboard = '/owner/dashboard';
  static const String registerOffice = '/owner/offices/register';

  static const String adminDashboard = '/admin/dashboard';

  static const String employeeOrder = '/order/:qrToken';
  static const String employeeOrderTracking = '/track/:orderNumber';
  static const String employeeAuth = '/employee/auth';
  static const String employeeDashboard = '/employee/dashboard';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.approvalPending,
      builder: (context, state) => const ApprovalPendingScreen(),
    ),
    GoRoute(
      path: AppRoutes.createCanteen,
      builder: (context, state) => const CreateCanteenScreen(),
    ),
    GoRoute(
      path: AppRoutes.ownerDashboard,
      builder: (context, state) {
        return OwnerDashboardScreen(
          initialCanteenName: state.uri.queryParameters['canteen'],
          initialCanteenId: state.uri.queryParameters['canteenId'],
          initialOrderId: state.uri.queryParameters['orderId'],
          initialSection: state.uri.queryParameters['section'],
        );
      },
    ),
    GoRoute(
      path: AppRoutes.registerOffice,
      builder: (context, state) => const RegisterOfficeScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.employeeAuth,
      builder: (context, state) => EmployeeAuthScreen(
        startWithRegister: state.uri.queryParameters['mode'] == 'register',
      ),
    ),
    GoRoute(
      path: AppRoutes.employeeDashboard,
      builder: (context, state) => const EmployeeDashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.employeeOrder,
      builder: (context, state) {
        return EmployeeMenuScreen(
          qrToken: state.pathParameters['qrToken'] ?? '',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.employeeOrderTracking,
      builder: (context, state) => EmployeeOrderTrackingScreen(
        orderNumber: state.pathParameters['orderNumber'] ?? '',
        trackingToken: state.uri.queryParameters['token'] ?? '',
      ),
    ),
  ],
  errorBuilder: (context, state) {
    return Scaffold(
      body: Center(
        child: Text(
          state.error?.toString() ?? 'Page not found',
          textAlign: TextAlign.center,
        ),
      ),
    );
  },
);
