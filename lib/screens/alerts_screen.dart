import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/device_provider.dart';
import '../models/alert.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  final VoidCallback onOpenDashboard;

  const AlertsScreen({super.key, required this.onOpenDashboard});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeviceProvider>(context);
    final alerts = provider.alerts;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    final filtered = alerts.where((a) {
      if (_filter == 'new' && a.status != AlertStatus.newAlert) return false;
      if (_filter == 'ack' && a.status != AlertStatus.acknowledged)
        return false;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'System Alerts & Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Monitored types: Device Offline, No Flow, High Flow Exceeded',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              // Filter Chips
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Alerts'),
                    selected: _filter == 'all',
                    onSelected: (s) => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('New Only'),
                    selected: _filter == 'new',
                    onSelected: (s) => setState(() => _filter = 'new'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SurfaceCard(
              padding: const EdgeInsets.all(16),
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: AppColors.liveTeal,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No active alerts.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'All EvaraFlow devices operating normally.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) =>
                          const Divider(color: AppColors.glassBorder),
                      itemBuilder: (ctx, idx) {
                        final item = filtered[idx];
                        final isNew = item.status == AlertStatus.newAlert;

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: item.severity == 'critical'
                                  ? AppColors.dangerLight
                                  : AppColors.warningAmber.withValues(
                                      alpha: 0.15,
                                    ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.severity == 'critical'
                                  ? Icons.error_outline
                                  : Icons.warning_amber_rounded,
                              color: item.severity == 'critical'
                                  ? AppColors.dangerRed
                                  : AppColors.warningAmber,
                              size: 22,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                item.typeLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
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
                                  item.deviceId,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cyanAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Opened at: ${dateFormat.format(item.openedAt)} ${item.acknowledgedBy != null ? " | Ack by: ${item.acknowledgedBy!}" : ""}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isNew)
                                ElevatedButton(
                                  onPressed: () =>
                                      provider.acknowledgeAlert(item.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryLight,
                                    foregroundColor: AppColors.primary,
                                    elevation: 0,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  child: const Text('Acknowledge'),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.glassSurface,
                                    borderRadius: BorderRadius.circular(
                                      AppShapes.radiusXs,
                                    ),
                                  ),
                                  child: const Text(
                                    'Acknowledged',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  provider.selectDevice(item.deviceId);
                                  widget.onOpenDashboard();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.glassBorder,
                                  ),
                                ),
                                child: const Text(
                                  'View Device',
                                  style: TextStyle(fontSize: 12),
                                ),
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
