import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/image_record.dart';
import '../widgets/device_header.dart';
import '../widgets/current_reading_card.dart';
import '../widgets/latest_image_card.dart';
import '../widgets/historical_chart.dart';
import '../widgets/past_readings_table.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/image_gallery_modal.dart';
import '../widgets/add_edit_device_dialog.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLogsExpanded = false;

  void _showGallery(
    BuildContext context,
    DeviceProvider provider, {
    ImageRecord? selectedImage,
  }) {
    if (provider.selectedDevice == null) return;
    showDialog(
      context: context,
      // A light scrim instead of Flutter's default 54%-black barrier — the
      // glass dialog refracts whatever sits behind it, and a near-black
      // barrier reads as flat/muddy instead of actual glass.
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.12),
      builder: (ctx) => ImageGalleryModal(
        device: provider.selectedDevice!,
        images: provider.deviceImages,
        initialSelectedImage: selectedImage,
      ),
    );
  }

  void _showEditDialog(BuildContext context, DeviceProvider provider) async {
    if (provider.selectedDevice == null) return;
    final updated = await showDialog(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.12),
      builder: (ctx) =>
          AddEditDeviceDialog(initialDevice: provider.selectedDevice),
    );
    if (updated != null) {
      provider.updateDevice(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeviceProvider>(context);
    final device = provider.selectedDevice;

    if (device == null && provider.isDevicesLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: DashboardSkeleton(),
      );
    }

    if (device == null && !provider.isDevicesLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.devices_other, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No devices assigned to your account.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Contact your administrator to register an EvaraFlow device.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 960;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Desktop / Mobile Top Section
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Current Reading Card + Historical Chart
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CurrentReadingCard(
                        reading: provider.latestReading,
                        todaysConsumption: provider.todaysConsumption,
                        device: device,
                      ),
                      const SizedBox(height: 12),
                      HistoricalChartCard(
                        readings: provider.historicalReadings,
                        selectedRange: provider.selectedRange,
                        onRangeChanged: (range) => provider.setRange(range),
                        isLoading: provider.isDashboardLoading,
                        chartHeight: 315,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Right Side: Device Header + Latest Image Card
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DeviceHeader(
                        device: device!,
                        onEditPressed: () => _showEditDialog(context, provider),
                      ),
                      const SizedBox(height: 12),
                      LatestImageCard(
                        image: provider.latestImage,
                        device: device,
                        onViewAllPressed: () => _showGallery(context, provider),
                        onImageClick: (img) =>
                            _showGallery(context, provider, selectedImage: img),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                DeviceHeader(
                  device: device!,
                  onEditPressed: () => _showEditDialog(context, provider),
                ),
                const SizedBox(height: 12),
                CurrentReadingCard(
                  reading: provider.latestReading,
                  todaysConsumption: provider.todaysConsumption,
                  device: device,
                ),
                const SizedBox(height: 12),
                HistoricalChartCard(
                  readings: provider.historicalReadings,
                  selectedRange: provider.selectedRange,
                  onRangeChanged: (range) => provider.setRange(range),
                  isLoading: provider.isDashboardLoading,
                ),
                const SizedBox(height: 12),
                LatestImageCard(
                  image: provider.latestImage,
                  device: device,
                  onViewAllPressed: () => _showGallery(context, provider),
                  onImageClick: (img) =>
                      _showGallery(context, provider, selectedImage: img),
                ),
              ],
            ),

          const SizedBox(height: 14),

          // 2. Expandable "See Logs" Section (Replaces static logs card)
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _isLogsExpanded = !_isLogsExpanded;
                    });
                  },
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
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF007AFF),
                                    Color(0xFF38BDF8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF007AFF,
                                    ).withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isLogsExpanded
                                  ? 'Telemetry Logs (${provider.historicalReadings.length} entries)'
                                  : 'See Telemetry Logs (${provider.historicalReadings.length} entries)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(
                                  AppShapes.radiusXs,
                                ),
                                border: Border.all(
                                  color: AppColors.primaryBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _isLogsExpanded ? 'Hide Logs' : 'See Logs',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    turns: _isLogsExpanded ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isLogsExpanded) ...[
                  const SizedBox(height: 10),
                  PastReadingsTableCard(readings: provider.historicalReadings),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
