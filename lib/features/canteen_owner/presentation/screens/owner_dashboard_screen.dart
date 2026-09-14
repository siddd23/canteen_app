import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/services/order_sound_service.dart';
import '../../../../core/services/system_notification_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/canteen.dart';
import '../../../../shared/models/dashboard_summary.dart';
import '../../../../shared/models/order_notification.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/canteen_service.dart';
import '../../../../shared/services/order_service.dart';
import '../../../../shared/services/owner_account_service.dart';
import '../../../../shared/services/realtime_service.dart';
import '../../../../shared/widgets/dashboard_shell.dart';
import '../widgets/office_workspace.dart';
import '../widgets/menu_workspace.dart';
import '../widgets/order_history_workspace.dart';
import '../widgets/order_workspace.dart';
import '../widgets/pay_later_workspace.dart';
import '../widgets/sales_reports_workspace.dart';
import '../widgets/owner_settings_workspace.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({
    this.initialCanteenName,
    this.initialSection,
    super.key,
  });

  final String? initialCanteenName;
  final String? initialSection;

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen>
    with WidgetsBindingObserver {
  static const _notificationPollInterval = Duration(seconds: 12);
  static const _destinations = [
    DashboardDestination(
      label: 'Dashboard',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
    ),
    DashboardDestination(
      label: 'Offices',
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment_rounded,
    ),
    DashboardDestination(
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    DashboardDestination(
      label: 'Menu',
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu_rounded,
    ),
    DashboardDestination(
      label: 'Pay Later',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
    ),
    DashboardDestination(
      label: 'History',
      icon: Icons.history_rounded,
      selectedIcon: Icons.history_toggle_off_rounded,
    ),
    DashboardDestination(
      label: 'Reports',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment_rounded,
    ),
    DashboardDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  List<Canteen> _canteens = [];
  String? _selectedCanteenId;
  String? _errorMessage;
  String? _dashboardError;
  DashboardSummary? _dashboardSummary;
  int _selectedNavigationIndex = 0;
  bool _isLoading = true;
  bool _isDashboardLoading = false;
  final List<OrderNotification> _orderNotifications = [];
  final Set<String> _knownNotificationIds = {};
  Timer? _notificationTimer;
  DateTime? _notificationCheckpoint;
  bool _checkingNotifications = false;
  int _unreadNotifications = 0;
  int _orderRealtimeVersion = 0;
  StreamSubscription<Map<String, dynamic>>? _newOrderSubscription;
  StreamSubscription<Map<String, dynamic>>? _orderUpdateSubscription;

  Canteen? get _selectedCanteen {
    if (_canteens.isEmpty) return null;

    return _canteens.firstWhere(
      (canteen) => canteen.id == _selectedCanteenId,
      orElse: () => _canteens.first,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSection == 'orders') {
      _selectedNavigationIndex = 2;
    }
    WidgetsBinding.instance.addObserver(this);
    _loadCanteens();
    _loadOwnerPreferences();
    _initializeNotifications();
    _connectRealtime();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _newOrderSubscription?.cancel();
    _orderUpdateSubscription?.cancel();
    RealtimeService.instance.disconnect();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connectRealtime();
      _pollNotifications();
      _startNotificationPolling();
    } else {
      _notificationTimer?.cancel();
    }
  }

  Future<void> _connectRealtime() async {
    await _newOrderSubscription?.cancel();
    await _orderUpdateSubscription?.cancel();
    _newOrderSubscription = RealtimeService.instance.newOrders.listen(
      _handleRealtimeNewOrder,
    );
    _orderUpdateSubscription = RealtimeService.instance.orderUpdates.listen((_) {
      if (!mounted) return;
      setState(() => _orderRealtimeVersion++);
      if (_selectedNavigationIndex == 0) _loadDashboardSummary();
    });
    await RealtimeService.instance.connectOwner();
  }

  void _handleRealtimeNewOrder(Map<String, dynamic> data) {
    if (!mounted) return;
    final notification = OrderNotification.fromJson(data);
    if (notification.id.isEmpty || !_knownNotificationIds.add(notification.id)) return;

    setState(() {
      _orderNotifications.insert(0, notification);
      if (_orderNotifications.length > 50) _orderNotifications.removeLast();
      _unreadNotifications++;
      _orderRealtimeVersion++;
    });
    if (_selectedNavigationIndex == 0) _loadDashboardSummary();
    unawaited(OrderSoundService.instance.playNewOrderBell());
    SystemNotificationService.instance.show(
      title: 'New canteen order',
      body: '${notification.orderNumber} from ${notification.customerName}',
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'New order ${notification.orderNumber} from ${notification.customerName}',
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _openNotification(notification),
          ),
        ),
      );
  }

  Future<void> _initializeNotifications() async {
    try {
      final result = await OrderService.instance.getOrderNotifications();
      if (!mounted) return;
      _notificationCheckpoint = result.checkedAt;
      _startNotificationPolling();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _expireSession();
      }
    }
  }

  void _startNotificationPolling() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(
      _notificationPollInterval,
      (_) => _pollNotifications(),
    );
  }

  Future<void> _pollNotifications() async {
    if (_checkingNotifications || _notificationCheckpoint == null) return;
    _checkingNotifications = true;
    try {
      final result = await OrderService.instance.getOrderNotifications(
        after: _notificationCheckpoint,
      );
      if (!mounted) return;
      _notificationCheckpoint = result.checkedAt;
      final fresh = result.notifications
          .where((item) => _knownNotificationIds.add(item.id))
          .toList();
      if (fresh.isEmpty) return;

      setState(() {
        _orderNotifications.insertAll(0, fresh.reversed);
        if (_orderNotifications.length > 50) {
          _orderNotifications.removeRange(50, _orderNotifications.length);
        }
        _unreadNotifications += fresh.length;
        _orderRealtimeVersion += fresh.length;
      });

      if (_selectedNavigationIndex == 0) {
        _loadDashboardSummary();
      }
      final latest = fresh.last;
      unawaited(OrderSoundService.instance.playNewOrderBell());
      SystemNotificationService.instance.show(
        title: fresh.length == 1 ? 'New canteen order' : '${fresh.length} new orders',
        body: fresh.length == 1
            ? '${latest.orderNumber} from ${latest.customerName}'
            : 'Open the owner dashboard to review them.',
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              fresh.length == 1
                  ? 'New order ${latest.orderNumber} from ${latest.customerName}'
                  : '${fresh.length} new orders received',
            ),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => _openNotification(latest),
            ),
          ),
        );
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _notificationTimer?.cancel();
        await _expireSession();
      }
    } finally {
      _checkingNotifications = false;
    }
  }

  void _openNotification(OrderNotification notification) {
    if (_canteens.any((canteen) => canteen.id == notification.canteenId)) {
      setState(() {
        _selectedCanteenId = notification.canteenId;
        _selectedNavigationIndex = 2;
      });
    } else {
      setState(() => _selectedNavigationIndex = 2);
    }
  }

  Future<void> _showNotifications() async {
    await SystemNotificationService.instance.requestPermission();
    setState(() => _unreadNotifications = 0);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _NotificationSheet(
        notifications: _orderNotifications,
        onOpen: (notification) {
          Navigator.pop(sheetContext);
          _openNotification(notification);
        },
      ),
    );
  }

  Future<void> _loadCanteens() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final canteens = await CanteenService.instance.getMyCanteens();

      if (!mounted) return;

      String? selectedId = _selectedCanteenId;
      if (canteens.isNotEmpty &&
          !canteens.any((canteen) => canteen.id == selectedId)) {
        final initialName = widget.initialCanteenName?.trim();
        final matchingCanteen = initialName == null
            ? null
            : canteens.cast<Canteen?>().firstWhere(
                (canteen) => canteen?.name == initialName,
                orElse: () => null,
              );
        selectedId = matchingCanteen?.id ?? canteens.first.id;
      }

      setState(() {
        _canteens = canteens;
        _selectedCanteenId = selectedId;
      });

      if (selectedId != null) {
        await _loadDashboardSummary(canteenId: selectedId);
      }
    } on ApiException catch (error) {
      if (!mounted) return;

      if (error.statusCode == 401 || error.statusCode == 403) {
        await _expireSession();
        return;
      }

      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load your canteens right now.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDashboardSummary({String? canteenId}) async {
    final selectedId = canteenId ?? _selectedCanteenId;
    if (selectedId == null) return;

    setState(() {
      _isDashboardLoading = true;
      _dashboardError = null;
    });

    try {
      final summary = await OrderService.instance.getDashboardSummary(
        canteenId: selectedId,
      );
      if (!mounted || selectedId != _selectedCanteenId) return;
      setState(() => _dashboardSummary = summary);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _expireSession();
        return;
      }
      setState(() => _dashboardError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _dashboardError = 'Unable to load dashboard statistics.',
        );
      }
    } finally {
      if (mounted && selectedId == _selectedCanteenId) {
        setState(() => _isDashboardLoading = false);
      }
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadCanteens();
  }

  Future<void> _loadOwnerPreferences() async {
    try {
      final settings = await OwnerAccountService.instance.getProfile();
      OrderSoundService.instance.enabled =
          settings.preferences.orderSoundEnabled;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _expireSession();
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _expireSession() async {
    await AuthService.instance.logout();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session expired. Please sign in again.'),
        backgroundColor: AppColors.error,
      ),
    );
    context.go(AppRoutes.login);
  }

  void _selectNavigation(int index) {
    setState(() => _selectedNavigationIndex = index);
    if (index == 0) _loadDashboardSummary();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature will be connected in the next phase.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Owner workspace',
      subtitle: '',
      destinations: _destinations,
      selectedIndex: _selectedNavigationIndex,
      onDestinationSelected: _selectNavigation,
      onLogout: _logout,
      actions: [
        if (_selectedNavigationIndex == 0)
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _isLoading || _isDashboardLoading
                ? null
                : _refreshDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
        IconButton(
          tooltip: 'Order notifications',
          onPressed: _showNotifications,
          icon: _NotificationBell(unread: _unreadNotifications),
        ),
        PopupMenuButton<String>(
          tooltip: 'Account',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
          onSelected: (value) {
            if (value == 'settings') _selectNavigation(7);
            if (value == 'logout') _logout();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined),
                  SizedBox(width: 10),
                  Text('Account settings'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded),
                  SizedBox(width: 10),
                  Text('Sign out'),
                ],
              ),
            ),
          ],
          icon: const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFFFE5D5),
            child: Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      child: _buildSelectedPage(),
    );
  }

  Widget _buildSelectedPage() {
    if (_selectedNavigationIndex == 1) {
      return OfficeWorkspace(
        canteens: _canteens,
        onSessionExpired: _expireSession,
      );
    }

    if (_selectedNavigationIndex == 3) {
      return MenuWorkspace(
        canteens: _canteens,
        initialCanteenId: _selectedCanteenId,
        onCanteenChanged: (canteenId) {
          setState(() => _selectedCanteenId = canteenId);
        },
        onSessionExpired: _expireSession,
      );
    }

    if (_selectedNavigationIndex == 2) {
      return OrderWorkspace(
        canteens: _canteens,
        initialCanteenId: _selectedCanteenId,
        onCanteenChanged: (canteenId) {
          setState(() => _selectedCanteenId = canteenId);
        },
        onSessionExpired: _expireSession,
        realtimeVersion: _orderRealtimeVersion,
      );
    }

    if (_selectedNavigationIndex == 4) {
      return PayLaterWorkspace(
        canteens: _canteens,
        initialCanteenId: _selectedCanteenId,
        onCanteenChanged: (canteenId) {
          setState(() => _selectedCanteenId = canteenId);
        },
        onSessionExpired: _expireSession,
      );
    }

    if (_selectedNavigationIndex == 5) {
      return OrderHistoryWorkspace(
        canteens: _canteens,
        initialCanteenId: _selectedCanteenId,
        onCanteenChanged: (canteenId) {
          setState(() => _selectedCanteenId = canteenId);
        },
        onSessionExpired: _expireSession,
      );
    }

    if (_selectedNavigationIndex == 6) {
      return SalesReportsWorkspace(
        canteens: _canteens,
        initialCanteenId: _selectedCanteenId,
        onCanteenChanged: (canteenId) {
          setState(() => _selectedCanteenId = canteenId);
        },
        onSessionExpired: _expireSession,
      );
    }

    if (_selectedNavigationIndex == 7) {
      return OwnerSettingsWorkspace(
        onSessionExpired: _expireSession,
        onPasswordChanged: _logout,
      );
    }

    if (_selectedNavigationIndex != 0) {
      return _FeaturePlaceholder(
        icon: _destinations[_selectedNavigationIndex].icon,
        title: _destinations[_selectedNavigationIndex].label,
        onBack: () => _selectNavigation(0),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _DashboardError(message: _errorMessage!, onRetry: _loadCanteens);
    }

    if (_canteens.isEmpty) {
      return _NoCanteens(onCreate: () => context.push(AppRoutes.createCanteen));
    }

    final canteen = _selectedCanteen!;

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: DashboardPage(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 700 ? 16 : 24,
            MediaQuery.sizeOf(context).width < 700 ? 18 : 28,
            MediaQuery.sizeOf(context).width < 700 ? 16 : 24,
            36,
          ),
          children: [
            _OwnerWelcomeHeader(
              canteen: canteen,
              canteens: _canteens,
              selectedCanteenId: _selectedCanteenId!,
              onCanteenChanged: (id) {
                if (id != null) {
                  setState(() {
                    _selectedCanteenId = id;
                    _dashboardSummary = null;
                  });
                  _loadDashboardSummary(canteenId: id);
                }
              },
              onAddCanteen: () => context.push(AppRoutes.createCanteen),
            ),
            const SizedBox(height: 24),
            const _SectionHeading(title: 'Today at a glance'),
            const SizedBox(height: 16),
            if (_isDashboardLoading && _dashboardSummary == null)
              const _DashboardMetricsLoading()
            else if (_dashboardError != null && _dashboardSummary == null)
              _DashboardMetricsError(
                message: _dashboardError!,
                onRetry: _loadDashboardSummary,
              )
            else
              _MetricsGrid(summary: _dashboardSummary!),
            if (_dashboardSummary?.updatedAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Updated ${_dashboardUpdatedTime(_dashboardSummary!.updatedAt!)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                final details = _CanteenDetailsCard(canteen: canteen);
                final actions = _QuickActionsCard(
                  onOrders: () => _selectNavigation(2),
                  onMenu: () => _selectNavigation(3),
                  onAddCanteen: () => context.push(AppRoutes.createCanteen),
                );

                if (!wide) {
                  return Column(
                    children: [details, const SizedBox(height: 16), actions],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: details),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: actions),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerWelcomeHeader extends StatelessWidget {
  const _OwnerWelcomeHeader({
    required this.canteen,
    required this.canteens,
    required this.selectedCanteenId,
    required this.onCanteenChanged,
    required this.onAddCanteen,
  });

  final Canteen canteen;
  final List<Canteen> canteens;
  final String selectedCanteenId;
  final ValueChanged<String?> onCanteenChanged;
  final VoidCallback onAddCanteen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              canteen.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${canteen.city} · ${canteen.openingTime}–${canteen.closingTime}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        );

        final controls = SizedBox(
          width: compact ? double.infinity : 330,
          child: Row(
            children: [
              Expanded(
                child: DropdownMenu<String>(
                  key: ValueKey(selectedCanteenId),
                  initialSelection: selectedCanteenId,
                  expandedInsets: EdgeInsets.zero,
                  menuHeight: 280,
                  label: const Text('Managing canteen'),
                  leadingIcon: const Icon(Icons.storefront_outlined),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  dropdownMenuEntries: canteens
                      .map(
                        (item) => DropdownMenuEntry(
                          value: item.id,
                          label: item.name,
                          leadingIcon: const Icon(
                            Icons.storefront_outlined,
                            size: 20,
                          ),
                        ),
                      )
                      .toList(),
                  onSelected: onCanteenChanged,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Add canteen',
                onPressed: onAddCanteen,
                icon: const Icon(Icons.add_business_outlined),
              ),
            ],
          ),
        );

        if (compact) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF182235), Color(0xFF2B3850)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F172033),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            canteen.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${canteen.city}  •  ${canteen.openingTime}–${canteen.closingTime}',
                            style: const TextStyle(
                              color: Color(0xFFB9C2D3),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        canteen.status,
                        style: const TextStyle(
                          color: Color(0xFF86EFAC),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 7),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Managing canteen',
                      style: TextStyle(
                        color: Color(0xFFD5DCE8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCanteenId,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: canteens
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: onCanteenChanged,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: IconButton.filled(
                        tooltip: 'Add canteen',
                        onPressed: onAddCanteen,
                        icon: const Icon(Icons.add_business_outlined),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 24),
            controls,
          ],
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        'Today\'s orders',
        '${summary.todayOrders}',
        Icons.receipt_long_outlined,
        AppColors.primary,
      ),
      (
        'Active orders',
        '${summary.activeOrders}',
        Icons.pending_actions_outlined,
        AppColors.warning,
      ),
      (
        'Today\'s sales',
        '₹${_money(summary.todaySales)}',
        Icons.currency_rupee_rounded,
        AppColors.success,
      ),
      (
        'Available items',
        '${summary.availableMenuItems}',
        Icons.restaurant_menu_outlined,
        const Color(0xFF2563EB),
      ),
      (
        'Pay later',
        '₹${_money(summary.payLaterOutstanding)}',
        Icons.account_balance_wallet_outlined,
        AppColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 360
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: compact ? 12 : 14,
          runSpacing: compact ? 12 : 14,
          children: metrics
              .indexed
              .map(
                (entry) => SizedBox(
                  width: compact && entry.$1 == metrics.length - 1
                      ? constraints.maxWidth
                      : width,
                  child: _MetricCard(
                    title: entry.$2.$1,
                    value: entry.$2.$2,
                    icon: entry.$2.$3,
                    color: entry.$2.$4,
                    compact: compact && entry.$1 != metrics.length - 1,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DashboardMetricsLoading extends StatelessWidget {
  const _DashboardMetricsLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 112,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _DashboardMetricsError extends StatelessWidget {
  const _DashboardMetricsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.error),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

String _money(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

String _dashboardUpdatedTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.compact = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 132 : null,
      padding: EdgeInsets.all(compact ? 15 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(compact ? 17 : 18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A172033),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CanteenDetailsCard extends StatelessWidget {
  const _CanteenDetailsCard({required this.canteen});

  final Canteen canteen;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Canteen details',

      child: Column(
        children: [
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: '${canteen.address}, ${canteen.city}',
          ),
          _DetailRow(
            icon: Icons.schedule_outlined,
            label: 'Operating hours',
            value: '${canteen.openingTime} – ${canteen.closingTime}',
          ),
          _DetailRow(
            icon: Icons.phone_outlined,
            label: 'Contact',
            value: canteen.contactNumber,
          ),
          _DetailRow(
            icon: Icons.radio_button_checked_rounded,
            label: 'Status',
            value: canteen.status,
            valueColor: canteen.status == 'Active'
                ? AppColors.success
                : AppColors.textSecondary,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onOrders,
    required this.onMenu,
    required this.onAddCanteen,
  });

  final VoidCallback onOrders;
  final VoidCallback onMenu;
  final VoidCallback onAddCanteen;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Quick actions',

      child: Column(
        children: [
          _ActionTile(
            icon: Icons.receipt_long_outlined,
            title: 'Manage orders',
            onTap: onOrders,
          ),
          _ActionTile(
            icon: Icons.add_circle_outline_rounded,
            title: 'Update menu',
            onTap: onMenu,
          ),
          _ActionTile(
            icon: Icons.add_business_outlined,
            title: 'Add another canteen',
            onTap: onAddCanteen,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle?.trim().isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hasSubtitle) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary, size: 21),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        color: valueColor ?? AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        if (showDivider) const Divider(),
      ],
    );
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  const _FeaturePlaceholder({
    required this.icon,
    required this.title,
    required this.onBack,
  });

  final IconData icon;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _Panel(
            title: title,
            subtitle: 'This workspace is ready for the next backend module.',
            child: Column(
              children: [
                Icon(icon, size: 56, color: AppColors.primary),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onBack,
                  child: const Text('Back to dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoCanteens extends StatelessWidget {
  const _NoCanteens({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: _Panel(
            title: 'Create your first canteen',
            subtitle: 'Add a canteen before managing menus and orders.',
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Create canteen'),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _Panel(
            title: 'Dashboard unavailable',
            subtitle: message,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_rounded),
        if (unread > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({required this.notifications, required this.onOpen});

  final List<OrderNotification> notifications;
  final ValueChanged<OrderNotification> onOpen;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 4, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order notifications',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'New orders received while this app is open',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (notifications.isEmpty)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 52,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No new order notifications',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 7,
                      ),
                      onTap: () => onOpen(notification),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        '${notification.orderNumber} · ₹${_notificationMoney(notification.grandTotal)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${notification.customerName} · ${notification.itemCount} '
                          '${notification.itemCount == 1 ? 'item' : 'items'}\n'
                          '${notification.canteenName} · ${_notificationTime(notification.createdAt)}',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _notificationMoney(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

String _notificationTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month} · $hour:$minute '
      '${local.hour >= 12 ? 'PM' : 'AM'}';
}
