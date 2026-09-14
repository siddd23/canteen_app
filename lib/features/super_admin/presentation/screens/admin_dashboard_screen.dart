import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../../shared/models/owner_registration.dart';
import '../../../../shared/models/admin_overview.dart';
import '../../../../shared/services/admin_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/dashboard_shell.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _destinations = [
    DashboardDestination(
      label: 'Overview',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
    ),
    DashboardDestination(
      label: 'Requests',
      icon: Icons.pending_actions_outlined,
      selectedIcon: Icons.pending_actions_rounded,
    ),
    DashboardDestination(
      label: 'Owners',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
    ),
    DashboardDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  List<OwnerRegistration> _owners = [];
  AdminOverview? _overview;
  int _selectedNavigationIndex = 0;
  bool _isLoading = true;
  String? _processingOwnerId;
  String? _errorMessage;

  List<OwnerRegistration> get _pendingOwners =>
      _owners.where((owner) => owner.approvalStatus == 'Pending').toList();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<Object>([
        AdminService.instance.getOwners(),
        AdminService.instance.getOverview(),
      ]);
      if (!mounted) return;
      setState(() {
        _owners = results[0] as List<OwnerRegistration>;
        _overview = results[1] as AdminOverview;
      });
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
          _errorMessage = 'Unable to load the platform overview right now.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveOwner(OwnerRegistration owner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.verified_user_outlined,
          color: AppColors.success,
          size: 34,
        ),
        title: const Text('Approve this owner?'),
        content: Text(
          '${owner.name} will be allowed to create and manage canteens.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Approve owner'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingOwnerId = owner.id);
    try {
      final updated = await AdminService.instance.approveOwner(owner.id);
      if (!mounted) return;
      _replaceOwner(updated);
      _showMessage('${owner.name} was approved.', AppColors.success);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _expireSession();
        return;
      }
      _showMessage(error.message, AppColors.error);
    } finally {
      if (mounted) setState(() => _processingOwnerId = null);
    }
  }

  Future<void> _rejectOwner(OwnerRegistration owner) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.cancel_outlined,
          color: AppColors.error,
          size: 34,
        ),
        title: const Text('Reject registration'),
        content: SizedBox(
          width: 430,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Explain what the owner needs to correct.',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 5) {
                  return 'Enter a reason of at least 5 characters';
                }
                return null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Reject owner'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (reason == null) return;

    setState(() => _processingOwnerId = owner.id);
    try {
      final updated = await AdminService.instance.rejectOwner(
        ownerId: owner.id,
        reason: reason,
      );
      if (!mounted) return;
      _replaceOwner(updated);
      _showMessage('${owner.name} was rejected.', AppColors.success);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _expireSession();
        return;
      }
      _showMessage(error.message, AppColors.error);
    } finally {
      if (mounted) setState(() => _processingOwnerId = null);
    }
  }

  void _replaceOwner(OwnerRegistration updated) {
    setState(() {
      final index = _owners.indexWhere((owner) => owner.id == updated.id);
      if (index == -1) {
        _owners.insert(0, updated);
      } else {
        _owners[index] = updated;
      }
    });
    _refreshOverview();
  }

  Future<void> _refreshOverview() async {
    try {
      final overview = await AdminService.instance.getOverview();
      if (mounted) setState(() => _overview = overview);
    } catch (_) {
      // The owner action already succeeded; the next manual refresh will retry.
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _expireSession() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    _showMessage(
      'Your session expired. Please sign in again.',
      AppColors.error,
    );
    context.go(AppRoutes.login);
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Super Admin',
      subtitle: '',
      destinations: _destinations,
      selectedIndex: _selectedNavigationIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedNavigationIndex = index);
      },
      onLogout: _logout,
      actions: [
        IconButton(
          tooltip: 'Refresh data',
          onPressed: _isLoading ? null : _loadDashboard,
          icon: const Icon(Icons.refresh_rounded),
        ),
        PopupMenuButton<String>(
          tooltip: 'Admin account',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
          onSelected: (value) {
            if (value == 'logout') _logout();
          },
          itemBuilder: (context) => const [
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
              Icons.admin_panel_settings_outlined,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _AdminError(message: _errorMessage!, onRetry: _loadDashboard);
    }

    if (_selectedNavigationIndex == 3) {
      return const _SettingsPlaceholder();
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: DashboardPage(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          children: [
            _PageHeading(
              title: _selectedNavigationIndex == 0
                  ? 'Platform overview'
                  : _selectedNavigationIndex == 1
                  ? 'Registration requests'
                  : 'Canteen owners',

              trailing:
                  _selectedNavigationIndex == 1 && _pendingOwners.isNotEmpty
                  ? _CountBadge(count: _pendingOwners.length)
                  : null,
            ),
            if (_selectedNavigationIndex == 0) ...[
              const SizedBox(height: 22),
              _AdminMetrics(
                overview: _overview,
              ),
              if (_overview != null) ...[
                const SizedBox(height: 30),
                const _SectionTitle(title: 'Recent platform orders'),
                const SizedBox(height: 15),
                _RecentOrders(orders: _overview!.recentOrders),
              ],
              const SizedBox(height: 30),
              const _SectionTitle(title: 'Pending approvals'),
              const SizedBox(height: 15),
              _OwnerCollection(
                owners: _pendingOwners.take(5).toList(),
                processingOwnerId: _processingOwnerId,
                showActions: true,
                onApprove: _approveOwner,
                onReject: _rejectOwner,
                emptyTitle: 'No pending approvals',
                emptyMessage: 'All owner registrations have been reviewed.',
              ),
            ] else if (_selectedNavigationIndex == 1) ...[
              const SizedBox(height: 22),
              _OwnerCollection(
                owners: _pendingOwners,
                processingOwnerId: _processingOwnerId,
                showActions: true,
                onApprove: _approveOwner,
                onReject: _rejectOwner,
                emptyTitle: 'All caught up',
                emptyMessage: 'There are no pending owner registrations.',
              ),
            ] else ...[
              const SizedBox(height: 22),
              _OwnerCollection(
                owners: _owners,
                processingOwnerId: _processingOwnerId,
                showActions: false,
                onApprove: _approveOwner,
                onReject: _rejectOwner,
                emptyTitle: 'No owners found',
                emptyMessage: 'Registered owners will appear here.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count pending',
        style: const TextStyle(
          color: Color(0xFFB45309),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdminMetrics extends StatelessWidget {
  const _AdminMetrics({required this.overview});

  final AdminOverview? overview;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Total owners', '${overview?.totalOwners ?? 0}', Icons.groups_outlined, const Color(0xFF2563EB)),
      ('Pending owners', '${overview?.pendingOwners ?? 0}', Icons.schedule_outlined, AppColors.warning),
      ('Active canteens', '${overview?.activeCanteens ?? 0}', Icons.storefront_outlined, AppColors.success),
      ('Active offices', '${overview?.activeOffices ?? 0}', Icons.business_outlined, const Color(0xFF7C3AED)),
      ('Orders today', '${overview?.todayOrders ?? 0}', Icons.receipt_long_outlined, const Color(0xFF0891B2)),
      ('Pending orders', '${overview?.pendingOrders ?? 0}', Icons.pending_actions_outlined, AppColors.warning),
      ('Sales today', _money(overview?.todaySales ?? 0), Icons.currency_rupee_rounded, AppColors.success),
      ('Pay Later due', _money(overview?.payLaterOutstanding ?? 0), Icons.account_balance_wallet_outlined, AppColors.error),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _AdminMetricCard(
                    label: metric.$1,
                    value: metric.$2,
                    icon: metric.$3,
                    color: metric.$4,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  static String _money(double value) => '₹${value.toStringAsFixed(0)}';
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
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

class _RecentOrders extends StatelessWidget {
  const _RecentOrders({required this.orders});

  final List<AdminRecentOrder> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _EmptyOwners(
        title: 'No orders yet',
        message: 'New orders from all canteens will appear here.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < orders.length; index++) ...[
            _RecentOrderRow(order: orders[index]),
            if (index != orders.length - 1)
              const Divider(height: 1, indent: 20, endIndent: 20),
          ],
        ],
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  const _RecentOrderRow({required this.order});

  final AdminRecentOrder order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.orderNumber} • ${order.customerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.canteenName} • ${order.officeName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${order.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${order.orderStatus} • ${order.paymentStatus}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _OwnerCollection extends StatelessWidget {
  const _OwnerCollection({
    required this.owners,
    required this.processingOwnerId,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<OwnerRegistration> owners;
  final String? processingOwnerId;
  final bool showActions;
  final ValueChanged<OwnerRegistration> onApprove;
  final ValueChanged<OwnerRegistration> onReject;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (owners.isEmpty) {
      return _EmptyOwners(title: emptyTitle, message: emptyMessage);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100 ? 2 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: owners
              .map(
                (owner) => SizedBox(
                  width: width,
                  child: _OwnerCard(
                    owner: owner,
                    isProcessing: processingOwnerId == owner.id,
                    showActions: showActions,
                    onApprove: () => onApprove(owner),
                    onReject: () => onReject(owner),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    required this.owner,
    required this.isProcessing,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
  });

  final OwnerRegistration owner;
  final bool isProcessing;
  final bool showActions;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.11),
                child: Text(
                  owner.name.isEmpty ? '?' : owner.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      owner.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: owner.approvalStatus),
            ],
          ),
          const SizedBox(height: 18),
          _OwnerDetail(icon: Icons.email_outlined, value: owner.email),
          const SizedBox(height: 9),
          _OwnerDetail(icon: Icons.phone_outlined, value: owner.mobile),
          if (owner.createdAt != null) ...[
            const SizedBox(height: 9),
            _OwnerDetail(
              icon: Icons.calendar_today_outlined,
              value: _formatDate(owner.createdAt!),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 19),
            const Divider(),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 46),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isProcessing ? null : onApprove,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _OwnerDetail extends StatelessWidget {
  const _OwnerDetail({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      'Approved' => (AppColors.success, const Color(0xFFDCFCE7)),
      'Rejected' => (AppColors.error, const Color(0xFFFEE2E2)),
      'Blocked' => (AppColors.textSecondary, const Color(0xFFF3F4F6)),
      _ => (const Color(0xFFB45309), const Color(0xFFFEF3C7)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyOwners extends StatelessWidget {
  const _EmptyOwners({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: AppColors.success,
              size: 34,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Dashboard unavailable',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
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
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const _EmptyOwners(
            title: 'Platform settings',
            message:
                'Configuration controls will be added with the deployment module.',
          ),
        ),
      ),
    );
  }
}
