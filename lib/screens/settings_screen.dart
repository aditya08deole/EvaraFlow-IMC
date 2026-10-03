import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Previously showed entirely fabricated status values (a fake broker
/// hostname, a fake service account, "Sync Polling Interval: Every 30
/// seconds" for a pipeline that's actually push-based, and a dead-letter
/// counter hardcoded to always read "(0)" regardless of the real number)
/// — found during a pass looking for exactly this kind of thing, per the
/// project's own "never present an assumption as fact" rule. Every value
/// below is either a real constant confirmed in EVARAFLOW_GROUND_TRUTH.md
/// (D-004/D-006/D-018-D-020) or fetched live from Firestore.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  int? _deadLetterCount;

  @override
  void initState() {
    super.initState();
    _loadDeadLetterCount();
  }

  Future<void> _loadDeadLetterCount() async {
    try {
      final count = await _apiService.getDeadLetterCount();
      if (mounted) setState(() => _deadLetterCount = count);
    } catch (_) {
      // Most likely cause: signed-in user isn't an administrator —
      // firestore.rules restricts this collection to admins, so a
      // non-admin's query errors rather than returning 0. Leave the
      // count as "—" (not a fabricated 0) rather than claiming a count
      // this user isn't even allowed to see.
    }
  }

  Future<void> _showDeadLetters() async {
    List<Map<String, dynamic>> entries;
    try {
      entries = await _apiService.getRecentDeadLetters(limit: 20);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load dead letters: $e')),
      );
      return;
    }
    if (!mounted) return;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recent Dead Letters (${entries.length} of total)'),
        content: SizedBox(
          width: 520,
          height: 400,
          child: entries.isEmpty
              ? const Text('None — nothing has been rejected.')
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final createdAt = e['createdAt'] as DateTime?;
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${e['source']} — ${e['reason']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        createdAt != null ? dateFormat.format(createdAt) : '',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
            'Live status of the MQTT telemetry pipeline and both image pipelines (Google Drive, Tailscale).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Pipeline A, B, C Integration Status Cards
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
                      _cardHeader(
                        Icons.hub_outlined,
                        AppColors.cyanAccent,
                        'Pipeline A: MQTT',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem('Broker', 'mqtt.evaratech.com'),
                      _buildSettingItem('Transport', 'wss://:443 (TLS)'),
                      _buildSettingItem(
                        'Topic Filter',
                        'evaratech/v1/+/telemetry',
                      ),
                      _buildSettingItem(
                        'Last Message Received',
                        selectedDevice?.lastSeenAt != null
                            ? '${dateFormat.format(selectedDevice!.lastSeenAt!)} (${selectedDevice.deviceId})'
                            : 'No data yet',
                      ),
                      _buildSettingItem(
                        'Browser Credential Exposure',
                        'Zero (TR-2 — this app never connects to MQTT)',
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
                      _cardHeader(
                        Icons.cloud_sync_outlined,
                        AppColors.driveBlue,
                        'Pipeline B: Google Drive',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem('Delivery', 'Push (Apps Script → webhook)'),
                      _buildSettingItem(
                        'Folder Scope',
                        'Per-device (Add/Edit Device dialog)',
                      ),
                      _buildSettingItem(
                        'Filename Contract',
                        '{node_id}_{YYYYMMDD}_{HHMMSS}.jpg',
                      ),
                      _buildSettingItem(
                        'Last Successful Sync',
                        latestImage != null
                            ? '${dateFormat.format(latestImage.receivedAt)} (${selectedDevice?.deviceId ?? ''})'
                            : 'No images synced yet',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Pipeline C Card: Tailscale
              Expanded(
                child: SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(
                        Icons.lan_outlined,
                        AppColors.liveTeal,
                        'Pipeline C: Tailscale',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingItem('Delivery', 'Pull, every 5 minutes'),
                      _buildSettingItem(
                        'Viewing',
                        'Live proxy per view (no cached copy)',
                      ),
                      _buildSettingItem(
                        'Why no cache',
                        'Avoids Firebase Storage\'s paid plan',
                      ),
                      _buildSettingItem(
                        'Last Successful Sync',
                        latestImage != null
                            ? '${dateFormat.format(latestImage.receivedAt)} (${selectedDevice?.deviceId ?? ''})'
                            : 'No images synced yet',
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
                      'Invalid MQTT payloads or unparseable Drive/Tailscale files are rejected here for inspection without repair.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: _showDeadLetters,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    _deadLetterCount == null
                        ? 'View Dead Letters'
                        : 'View Dead Letters (${_deadLetterCount!})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardHeader(IconData icon, Color color, String title) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
