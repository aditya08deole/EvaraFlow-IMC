import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';

class PastReadingsTableCard extends StatelessWidget {
  final List<Reading> readings;
  final int maxDisplayItems;

  const PastReadingsTableCard({
    super.key,
    required this.readings,
    this.maxDisplayItems = 6,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final recentLog = readings.reversed.take(maxDisplayItems).toList();
    final hasNoData = recentLog.isEmpty;

    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Title & Pipeline A Source Note
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Recent Telemetry Log',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Text(
                  'Showing Last ${recentLog.length} Readings',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (hasNoData)
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppShapes.radiusSm),
              ),
              child: const Center(
                child: Text(
                  'No recent telemetry log available.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(AppShapes.radiusSm),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppShapes.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.8),
                    1: FlexColumnWidth(1.8),
                    2: FlexColumnWidth(2.0),
                  },
                  children: [
                    // Header Row (Without Status column)
                    TableRow(
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Text('DATE & TIME', style: _headerStyle),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Text('FLOW (L/min)', style: _headerStyle),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Text('TOTALIZER (L)', style: _headerStyle),
                        ),
                      ],
                    ),

                    // Log Rows (Without OK Status)
                    ...recentLog.map((r) {
                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.borderLight),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Text(
                              dateFormat.format(r.deviceTs),
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Text(
                              r.flowLpm.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Text(
                              r.totalL != null
                                  ? r.totalL!.toStringAsFixed(1)
                                  : 'N/A',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: AppColors.textMuted,
    letterSpacing: 0.5,
  );
}
