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
import '../../../../shared/services/office_service.dart';
import '../../../../shared/widgets/dashboard_shell.dart';

class OfficeWorkspace extends StatefulWidget {
  const OfficeWorkspace({
    required this.canteens,
    required this.onSessionExpired,
    super.key,
  });

  final List<Canteen> canteens;
  final Future<void> Function() onSessionExpired;

  @override
  State<OfficeWorkspace> createState() => _OfficeWorkspaceState();
}

class _OfficeWorkspaceState extends State<OfficeWorkspace> {
  final _searchController = TextEditingController();
  List<Office> _offices = [];
  bool _isLoading = true;
  String? _processingOfficeId;
  String? _errorMessage;
  String _statusFilter = 'All';

  List<Office> get _visibleOffices {
    final query = _searchController.text.trim().toLowerCase();
    return _offices.where((office) {
      final matchesStatus =
          _statusFilter == 'All' || office.status == _statusFilter;
      final searchable = [
        office.companyName,
        office.building,
        office.city,
        office.officeCode,
        office.contactPerson,
      ].join(' ').toLowerCase();
      return matchesStatus && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  int get _activeCount => _offices.where((office) => office.isActive).length;
  int get _connectionCount =>
      _offices.fold(0, (total, office) => total + office.canteens.length);

  @override
  void initState() {
    super.initState();
    _loadOffices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOffices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offices = await OfficeService.instance.getMyOffices();
      if (!mounted) return;
      setState(() => _offices = offices);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to load offices right now.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerOffice() async {
    final created = await context.push<bool>(AppRoutes.registerOffice);
    if (created == true) await _loadOffices();
  }

  Future<void> _changeStatus(Office office) async {
    final nextStatus = office.isActive ? 'Inactive' : 'Active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          office.isActive
              ? Icons.pause_circle_outline
              : Icons.play_circle_outline,
          color: office.isActive ? AppColors.warning : AppColors.success,
          size: 34,
        ),
        title: Text('${office.isActive ? 'Pause' : 'Activate'} this office?'),
        content: Text(
          office.isActive
              ? 'Employees will not be able to order through this QR until it is activated again.'
              : 'Employees will be able to access assigned canteens through this QR.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(office.isActive ? 'Pause office' : 'Activate office'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingOfficeId = office.id);
    try {
      final updated = await OfficeService.instance.updateOfficeStatus(
        officeId: office.id,
        status: nextStatus,
      );
      if (!mounted) return;
      _replaceOffice(updated);
      _showMessage('Office marked as ${nextStatus.toLowerCase()}.');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _processingOfficeId = null);
    }
  }

  Future<void> _manageCanteens(Office office) async {
    final selected = office.canteens.map((canteen) => canteen.id).toSet();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Connected canteens'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.canteens.map((canteen) {
                final checked = selected.contains(canteen.id);
                return CheckboxListTile(
                  value: checked,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(canteen.name),
                  subtitle: Text(canteen.city),
                  onChanged: (value) {
                    setDialogState(() {
                      value == true
                          ? selected.add(canteen.id)
                          : selected.remove(canteen.id);
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, selected.toList()),
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;

    setState(() => _processingOfficeId = office.id);
    try {
      final updated = await OfficeService.instance.updateOfficeCanteens(
        officeId: office.id,
        canteenIds: result,
      );
      if (!mounted) return;
      _replaceOffice(updated);
      _showMessage('Connected canteens updated.');
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionExpired();
        return;
      }
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _processingOfficeId = null);
    }
  }

  void _replaceOffice(Office updated) {
    setState(() {
      final index = _offices.indexWhere((office) => office.id == updated.id);
      if (index >= 0) _offices[index] = updated;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return _OfficeState(
        icon: Icons.cloud_off_outlined,
        title: 'Offices unavailable',
        message: _errorMessage!,
        buttonLabel: 'Try again',
        onPressed: _loadOffices,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOffices,
      child: DashboardPage(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 44),
          children: [
            _WorkspaceHeader(onRegister: _registerOffice),
            const SizedBox(height: 22),
            _OfficeMetrics(
              total: _offices.length,
              active: _activeCount,
              inactive: _offices.length - _activeCount,
              connections: _connectionCount,
            ),
            const SizedBox(height: 24),
            _OfficeToolbar(
              controller: _searchController,
              selectedStatus: _statusFilter,
              onSearchChanged: (_) => setState(() {}),
              onStatusChanged: (value) {
                if (value != null) setState(() => _statusFilter = value);
              },
              onRefresh: _loadOffices,
            ),
            const SizedBox(height: 18),
            if (_offices.isEmpty)
              _OfficeState(
                icon: Icons.domain_add_outlined,
                title: 'Register your first office',
                message:
                    'Create one office QR and connect one or more canteens.',
                buttonLabel: 'Register office',
                onPressed: _registerOffice,
                embedded: true,
              )
            else if (_visibleOffices.isEmpty)
              const _NoSearchResults()
            else
              _OfficeGrid(
                offices: _visibleOffices,
                processingOfficeId: _processingOfficeId,
                onQr: _showQr,
                onManageCanteens: _manageCanteens,
                onStatus: _changeStatus,
              ),
          ],
        ),
      ),
    );
  }

  void _showQr(Office office) {
    showDialog<void>(
      context: context,
      builder: (context) => _QrDialog(office: office),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.onRegister});
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        const title = Text(
          'Offices',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        );
        final button = FilledButton.icon(
          onPressed: onRegister,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Register office'),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 16), button],
          );
        }
        return Row(
          children: [
            const Expanded(child: title),
            button,
          ],
        );
      },
    );
  }
}

class _OfficeMetrics extends StatelessWidget {
  const _OfficeMetrics({
    required this.total,
    required this.active,
    required this.inactive,
    required this.connections,
  });
  final int total;
  final int active;
  final int inactive;
  final int connections;

  @override
  Widget build(BuildContext context) {
    final data = [
      (
        'Total offices',
        total,
        Icons.apartment_rounded,
        const Color(0xFF4F46E5),
      ),
      ('Active', active, Icons.bolt_rounded, AppColors.success),
      ('Inactive', inactive, Icons.pause_circle_outline, AppColors.warning),
      ('Connections', connections, Icons.hub_outlined, AppColors.primary),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: data
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _MetricTile(
                    label: item.$1,
                    value: item.$2,
                    icon: item.$3,
                    color: item.$4,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfficeToolbar extends StatelessWidget {
  const _OfficeToolbar({
    required this.controller,
    required this.selectedStatus,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onRefresh,
  });
  final TextEditingController controller;
  final String selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 660;
          final search = TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search office, location or code',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          );
          final filters = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: const ['All', 'Active', 'Inactive']
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: onStatusChanged,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Refresh offices',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          );
          if (compact) {
            return Column(
              children: [search, const SizedBox(height: 12), filters],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              SizedBox(width: 220, child: filters),
            ],
          );
        },
      ),
    );
  }
}

class _OfficeGrid extends StatelessWidget {
  const _OfficeGrid({
    required this.offices,
    required this.processingOfficeId,
    required this.onQr,
    required this.onManageCanteens,
    required this.onStatus,
  });
  final List<Office> offices;
  final String? processingOfficeId;
  final ValueChanged<Office> onQr;
  final ValueChanged<Office> onManageCanteens;
  final ValueChanged<Office> onStatus;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080 ? 2 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 16)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: offices
              .map(
                (office) => SizedBox(
                  width: width,
                  child: _OfficeCard(
                    office: office,
                    isProcessing: processingOfficeId == office.id,
                    onQr: () => onQr(office),
                    onManageCanteens: () => onManageCanteens(office),
                    onStatus: () => onStatus(office),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _OfficeCard extends StatelessWidget {
  const _OfficeCard({
    required this.office,
    required this.isProcessing,
    required this.onQr,
    required this.onManageCanteens,
    required this.onStatus,
  });
  final Office office;
  final bool isProcessing;
  final VoidCallback onQr;
  final VoidCallback onManageCanteens;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      office.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      office.officeCode,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(active: office.isActive),
            ],
          ),
          const SizedBox(height: 18),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: office.locationLine,
          ),
          const SizedBox(height: 9),
          _InfoLine(
            icon: Icons.person_outline_rounded,
            text: '${office.contactPerson} · ${office.contactNumber}',
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: office.canteens
                .map(
                  (canteen) => Chip(
                    avatar: const Icon(Icons.storefront_outlined, size: 16),
                    label: Text(canteen.name),
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.border),
                    backgroundColor: AppColors.backgroundSoft,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          if (isProcessing)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onQr,
                    icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                    label: const Text('View QR'),
                  ),
                ),
                const SizedBox(width: 9),
                PopupMenuButton<String>(
                  tooltip: 'Office actions',
                  position: PopupMenuPosition.under,
                  onSelected: (value) {
                    if (value == 'canteens') onManageCanteens();
                    if (value == 'status') onStatus();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'canteens',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.hub_outlined),
                        title: Text('Connected canteens'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'status',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          office.isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                        ),
                        title: Text(
                          office.isActive ? 'Pause office' : 'Activate office',
                        ),
                      ),
                    ),
                  ],
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.more_horiz_rounded),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
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

class _QrDialog extends StatelessWidget {
  const _QrDialog({required this.office});
  final Office office;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(
        office.qrCode.contains(',')
            ? office.qrCode.split(',').last
            : office.qrCode,
      );
    } catch (_) {}

    return AlertDialog(
      title: Text(office.companyName),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              office.officeCode,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 260,
              height: 260,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: bytes == null
                  ? const Icon(Icons.qr_code_2_rounded, size: 150)
                  : Image.memory(bytes),
            ),
            const SizedBox(height: 14),
            SelectableText(
              office.orderingUrl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: office.orderingUrl));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ordering link copied')),
            );
          },
          icon: const Icon(Icons.content_copy_rounded, size: 18),
          label: const Text('Copy link'),
        ),
      ],
    );
  }
}

class _OfficeState extends StatelessWidget {
  const _OfficeState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    this.embedded = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 54),
        const SizedBox(height: 15),
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 19),
        FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
      ],
    );
    if (embedded) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: content,
      );
    }
    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No matching offices',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
