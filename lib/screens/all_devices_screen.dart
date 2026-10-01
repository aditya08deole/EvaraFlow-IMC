import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/device.dart';
import '../widgets/add_edit_device_dialog.dart';
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

  void _openAddDialog(BuildContext context, DeviceProvider provider) async {
    final newDev = await showDialog<Device>(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.12),
      builder: (ctx) => const AddEditDeviceDialog(),
    );
    if (newDev != null) {
      provider.addDevice(newDev);
    }
  }

  void _openEditDialog(
    BuildContext context,
    DeviceProvider provider,
    Device dev,
  ) async {
    final updated = await showDialog<Device>(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.12),
      builder: (ctx) => AddEditDeviceDialog(initialDevice: dev),
    );
    if (updated != null) {
      provider.updateDevice(updated);
    }
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
                    'All EvaraFlow Devices',
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
        ],
      ),
    );
  }
}
