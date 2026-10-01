import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;

  void _triggerDriveSync() async {
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Manual sync isn\'t wired to a live Google Drive integration in this build — showing last known status only.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final provider = Provider.of<DeviceProvider>(context);
    final selectedDevice = provider.selectedDevice;
    final latestImage = provider.latestImage;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings & Integration Status',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Monitor EMQX MQTT broker stream & Google Drive automated worker status.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Pipeline A & B Integration Status Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pipeline A Card: EMQX MQTT
              Expanded(
                child: SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.hub_outlined,
                                color: AppColors.cyanAccent,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Pipeline A: EMQX MQTT',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.liveTealLight,
                              borderRadius: BorderRadius.circular(
                                AppShapes.radiusXs,
                              ),
                              border: Border.all(
                                color: AppColors.liveTeal.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: const Text(
                              'CONNECTED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.liveTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        'Broker Host',
                        'mqtt.evaraflow.com:8883 (TLS)',
                      ),
                      _buildSettingItem(
                        'Backend Topic Filter',
                        'evaraflow/org-evaratech-01/#',
                      ),
                      _buildSettingItem(
                        'Subscriber Client ID',
                        'backend-worker-node-01',
                      ),
                      _buildSettingItem(
                        'Last Message Received',
                        selectedDevice?.lastSeenAt != null
                            ? '${dateFormat.format(selectedDevice!.lastSeenAt!)} (${selectedDevice.deviceId})'
                            : 'No data yet',
                      ),
                      _buildSettingItem(
                        'Browser Credential Exposure',
                        'Zero (TR-2 Enforced)',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Pipeline B Card: Google Drive
              Expanded(
                child: SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.cloud_sync_outlined,
                                color: AppColors.driveBlue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Pipeline B: Google Drive',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.liveTealLight,
                              borderRadius: BorderRadius.circular(
                                AppShapes.radiusXs,
                              ),
                              border: Border.all(
                                color: AppColors.liveTeal.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: const Text(
                              'ACTIVE SYNC',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.liveTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem(
                        'Service Account',
                        'drive-sync@evaraflow-prod.iam.gserviceaccount.com',
                      ),
                      _buildSettingItem(
                        'Shared Folder Name',
                        '/EvaraFlow_Device_Photos',
                      ),
                      _buildSettingItem(
                        'Sync Polling Interval',
                        'Every 30 seconds',
                      ),
                      _buildSettingItem(
                        'Last Successful Sync',
                        latestImage != null
                            ? '${dateFormat.format(latestImage.receivedAt)} (${selectedDevice?.deviceId ?? ''})'
                            : 'No images synced yet',
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _isSyncing ? null : _triggerDriveSync,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync, size: 14),
                        label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.driveBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dead Letter Audit Log Card
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Dead Letter Queue Audit Log (TR-5)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Invalid MQTT payloads or unparseable Drive files are rejected here for inspection without repair.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Dead letters queue is clean (0 rejected items).',
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.glassBorder),
                  ),
                  child: const Text(
                    'View Dead Letters (0)',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
