import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/device.dart';
import '../services/api_service.dart';
import '../widgets/add_edit_device_dialog.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';

class AllDevicesScreen extends StatefulWidget {
  final VoidCallback onOpenDashboard;

  const AllDevicesScreen({super.key, required this.onOpenDashboard});

  @override
  State<AllDevicesScreen> createState() => _AllDevicesScreenState();
}

class _AllDevicesScreenState extends State<AllDevicesScreen> {
  String _search = '';
  String _statusFilter = 'all';

  final ApiService _apiService = ApiService();
  bool _isDataQualityExpanded = false;
  List<Map<String, dynamic>> _deadLetters = [];

  @override
  void initState() {
    super.initState();
    _loadDeadLetters();
  }

  Future<void> _loadDeadLetters() async {
    try {
      final items = await _apiService.getRecentDeadLetters();
      if (!mounted) return;
      setState(() => _deadLetters = items);
    } catch (e) {
      // A non-administrator's query is correctly rejected by
      // firestore.rules — treat that the same as "nothing to show" rather
      // than surfacing a Firestore permission error in this list.
    }
  }

  void _openAddDialog(BuildContext context, DeviceProvider provider) async {
    final result = await showDialog<DeviceFormResult>(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.12),
      builder: (ctx) => const AddEditDeviceDialog(),
    );
    if (result == null) return;
    try {
      await provider.addDevice(result.device);
      if (!context.mounted) return;
      await _maybeStartBackfill(context, result);
    } catch (e) {
      if (!context.mounted) return;
      _showSaveError(context, e);
    }
  }

  void _openEditDialog(
    BuildContext context,
    DeviceProvider provider,
    Device dev,
  ) async {
    final result = await showDialog<DeviceFormResult>(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.12),
      builder: (ctx) => AddEditDeviceDialog(initialDevice: dev),
    );
    if (result == null) return;
    try {
      await provider.updateDevice(result.device);
      if (!context.mounted) return;
      await _maybeStartBackfill(context, result);
    } catch (e) {
      if (!context.mounted) return;
      _showSaveError(context, e);
    }
  }

  Future<void> _maybeStartBackfill(
    BuildContext context,
    DeviceFormResult result,
  ) async {
    if (result.driveFolderId == null) return;
    try {
      await _apiService.startDriveBackfill(
        result.driveFolderId!,
        result.device.deviceId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Drive backfill started in the background — the gallery will '
            'fill in over the next few minutes for a large folder.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device saved, but the Drive backfill failed to start: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  void _showSaveError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not save device: $error'),
        backgroundColor: AppColors.dangerRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeviceProvider>(context);
    final devices = provider.devices;

    final filtered = devices.where((d) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!d.deviceId.toLowerCase().contains(q) &&
            !d.name.toLowerCase().contains(q) &&
            !d.location.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_statusFilter != 'all') {
        if (d.status.name != _statusFilter) return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All EvaraTech Devices',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Total ${devices.length} registered meters across organization',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _openAddDialog(context, provider),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add New Device'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search & Filter Bar
          SurfaceCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Search device ID, name or location...',
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Statuses'),
                        ),
                        DropdownMenuItem(
                          value: 'online',
                          child: Text('Online Only'),
                        ),
                        DropdownMenuItem(
                          value: 'offline',
                          child: Text('Offline Only'),
                        ),
                        DropdownMenuItem(
                          value: 'noData',
                          child: Text('No Data Yet'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _statusFilter = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Devices Table Card
          Expanded(
            child: SurfaceCard(
              padding: const EdgeInsets.all(16),
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) =>
                    const Divider(color: AppColors.glassBorder),
                itemBuilder: (ctx, index) {
                  final dev = filtered[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: dev.status == DeviceStatus.online
                            ? AppColors.liveTealLight
                            : (dev.status == DeviceStatus.offline
                                  ? AppColors.dangerLight
                                  : AppColors.glassSurface),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.sensors,
                        color: dev.status == DeviceStatus.online
                            ? AppColors.liveTeal
                            : (dev.status == DeviceStatus.offline
                                  ? AppColors.dangerRed
                                  : AppColors.textMuted),
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          dev.deviceId,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppColors.cyanAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dev.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${dev.location}  |  ID: ${dev.deviceId}  |  Drive Key: ${dev.driveMatchKey}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            provider.selectDevice(dev.deviceId);
                            widget.onOpenDashboard();
                          },
                          icon: const Icon(Icons.dashboard_outlined, size: 14),
                          label: const Text('Open Dashboard'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                              color: AppColors.glassBorder,
                            ),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () =>
                              _openEditDialog(context, provider, dev),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Data Quality: rejected/anomalous ingestion events
          // (deadLetters). Empty for a non-administrator (the query is
          // rejected by firestore.rules) and for an administrator with
          // nothing currently flagged — both render as "show nothing"
          // rather than an always-present-but-empty section.
          if (_deadLetters.isNotEmpty) ...[
            const SizedBox(height: 14),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(
                      () => _isDataQualityExpanded = !_isDataQualityExpanded,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.warningAmber.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.rule_folder_outlined,
                                  size: 15,
                                  color: AppColors.warningAmber,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Data Quality — Rejected Readings (${_deadLetters.length})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _isDataQualityExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isDataQualityExpanded) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _deadLetters.length,
                        separatorBuilder: (ctx, i) =>
                            const Divider(color: AppColors.glassBorder),
                        itemBuilder: (ctx, i) {
                          final dl = _deadLetters[i];
                          final createdAt = dl['createdAt'] as DateTime?;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.glassSurface,
                                        borderRadius: BorderRadius.circular(
                                          AppShapes.radiusXs,
                                        ),
                                      ),
                                      child: Text(
                                        '${dl['source']}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.cyanAccent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (createdAt != null)
                                      Text(
                                        DateFormat(
                                          'yyyy-MM-dd HH:mm:ss',
                                        ).format(createdAt),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${dl['reason']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
