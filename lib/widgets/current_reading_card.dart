import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading.dart';
import '../models/device.dart';
import '../theme/app_theme.dart';
import 'animated_metric_tile.dart';

class CurrentReadingCard extends StatelessWidget {
  final Reading? reading;
  final double todaysConsumption;
  final Device? device;

  const CurrentReadingCard({
    super.key,
    required this.reading,
    required this.todaysConsumption,
    required this.device,
  });

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final hasNoData = reading == null;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Header (Emblem + Title)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.waves_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Current Reading',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (hasNoData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 32,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Waiting for first reading',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Telemetry Stream: ${device?.deviceId ?? "EF-001"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                // Metric 1: Current Flow
                Expanded(
                  child: AnimatedMetricTile(
                    label: 'CURRENT FLOW',
                    numericValue: reading!.flowLpm,
                    displayString: reading!.flowLpm.toStringAsFixed(1),
                    unit: 'L/min',
                    icon: Icons.water_drop_rounded,
                    accentColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),

                // Metric 2: Meter Reading
                Expanded(
                  child: AnimatedMetricTile(
                    label: 'METER READING',
                    numericValue: todaysConsumption,
                    displayString: todaysConsumption.toStringAsFixed(1),
                    unit: 'L',
                    icon: Icons.bubble_chart_rounded,
                    accentColor: AppColors.liveTeal,
                    subtitle:
                        device?.consumptionMethod ==
                            ConsumptionMethod.integratedFlow
                        ? '(Integrated)'
                        : '(Totalizer)',
                  ),
                ),
                const SizedBox(width: 12),

                // Metric 3: Last Updated
                Expanded(
                  child: AnimatedMetricTile(
                    label: 'LAST UPDATED',
                    numericValue: 0,
                    displayString: _formatRelativeTime(reading!.deviceTs),
                    unit: '',
                    icon: Icons.timer_rounded,
                    accentColor: const Color(0xFF8E8E93),
                    subtitle: dateFormat.format(reading!.deviceTs),
                    isTime: true,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
