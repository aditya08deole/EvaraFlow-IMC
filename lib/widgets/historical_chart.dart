import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/reading.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';

enum ChartMetric { flowRate, meterReading }

class HistoricalChartCard extends StatefulWidget {
  final List<Reading> readings;
  final String selectedRange;
  final Function(String) onRangeChanged;
  final bool isLoading;
  final double chartHeight;

  const HistoricalChartCard({
    super.key,
    required this.readings,
    required this.selectedRange,
    required this.onRangeChanged,
    this.isLoading = false,
    this.chartHeight = 315.0,
  });

  @override
  State<HistoricalChartCard> createState() => _HistoricalChartCardState();
}

class _HistoricalChartCardState extends State<HistoricalChartCard> {
  ChartMetric _selectedMetric = ChartMetric.flowRate;

  @override
  Widget build(BuildContext context) {
    final hasNoData = widget.readings.isEmpty;
    final isFlow = _selectedMetric == ChartMetric.flowRate;
    final unitLabel = isFlow ? 'L/min' : 'L';
    final lineGradient = isFlow
        ? AppColors.liquidSkyBlueGradient
        : const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final accentColor = isFlow ? AppColors.primary : AppColors.liveTeal;

    return SurfaceCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title, Metric Swap Toggle & Range Selector
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              // Title & Icon
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFlow
                        ? Icons.show_chart_rounded
                        : Icons.bubble_chart_rounded,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isFlow ? 'Flow Rate Analytics' : 'Meter Reading Analytics',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced Metric Swap Toggle Button (Flow Rate vs Meter Reading)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary.withValues(
                        alpha: 0.7,
                      ),
                      borderRadius: BorderRadius.circular(AppShapes.radiusSm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMetricTab(
                          label: 'Flow (L/min)',
                          icon: Icons.water_drop_rounded,
                          isSelected: isFlow,
                          activeGradient: AppColors.liquidSkyBlueGradient,
                          activeShadowColor: AppColors.primary,
                          onTap: () => setState(
                            () => _selectedMetric = ChartMetric.flowRate,
                          ),
                        ),
                        const SizedBox(width: 2),
                        _buildMetricTab(
                          label: 'Meter (L)',
                          icon: Icons.speed_rounded,
                          isSelected: !isFlow,
                          activeGradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF14B8A6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          activeShadowColor: AppColors.liveTeal,
                          onTap: () => setState(
                            () => _selectedMetric = ChartMetric.meterReading,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Enhanced Range Selector Buttons (Today, 7 Days, 30 Days)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary.withValues(
                        alpha: 0.7,
                      ),
                      borderRadius: BorderRadius.circular(AppShapes.radiusSm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRangeTab('Today', Icons.today_rounded),
                        const SizedBox(width: 2),
                        _buildRangeTab('7 Days', Icons.date_range_rounded),
                        const SizedBox(width: 2),
                        _buildRangeTab('30 Days', Icons.calendar_month_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Extended Chart Content Area (Taller Height: widget.chartHeight)
          if (hasNoData)
            Container(
              height: widget.chartHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppShapes.radiusSm),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.auto_graph_rounded,
                    size: 28,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'No telemetry readings in this period.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              height: widget.chartHeight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 8),
                child: LineChart(
                  LineChartData(
                    // fl_chart auto-computes axis bounds from the data when
                    // minY/maxY/minX/maxX aren't given — with only one or
                    // two readings (common right after a device's first
                    // real telemetry, or a device with sparse data), that
                    // auto-computed Y-range can collapse to zero width,
                    // which degenerates the chart into rendering nothing
                    // visible instead of a single dot. Bounds are set
                    // explicitly below with padding to avoid that.
                    minX: 0,
                    maxX: (widget.readings.length - 1).toDouble().clamp(
                      1.0,
                      double.infinity,
                    ),
                    minY: _axisBounds(isFlow).$1,
                    maxY: _axisBounds(isFlow).$2,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.borderLight,
                        strokeWidth: 0.8,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: (widget.readings.length / 5).clamp(
                            1.0,
                            50.0,
                          ),
                          getTitlesWidget: (value, meta) {
                            if (!value.isFinite) return const SizedBox();
                            final idx = value.toInt();
                            if (idx < 0 || idx >= widget.readings.length)
                              return const SizedBox();
                            final dt = widget.readings[idx].deviceTs;
                            final fmt = widget.selectedRange == 'Today'
                                ? DateFormat('HH:mm')
                                : DateFormat('MM/dd HH:mm');
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                fmt.format(dt),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isFlow ? 30 : 38,
                          getTitlesWidget: (value, meta) {
                            if (!value.isFinite) return const SizedBox();
                            final valText = value >= 1000
                                ? '${(value / 1000).toStringAsFixed(1)}k'
                                : '${value.toInt()}';
                            return Text(
                              valText,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textMuted,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: widget.readings.asMap().entries.map((e) {
                          final yVal = isFlow
                              ? e.value.flowLpm
                              : (e.value.totalL ?? (e.value.flowLpm * 15.0));
                          return FlSpot(e.key.toDouble(), yVal);
                        }).toList(),
                        isCurved: true,
                        curveSmoothness: 0.35,
                        gradient: lineGradient,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: widget.readings.length < 24,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: accentColor,
                                strokeWidth: 1.5,
                                strokeColor: Colors.white,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withValues(alpha: 0.20),
                              accentColor.withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final idx = spot.spotIndex;
                            if (idx < 0 || idx >= widget.readings.length)
                              return null;
                            final r = widget.readings[idx];
                            final timeStr = DateFormat(
                              'HH:mm:ss',
                            ).format(r.deviceTs);
                            final val = isFlow
                                ? r.flowLpm
                                : (r.totalL ?? (r.flowLpm * 15.0));
                            final valStr = isFlow
                                ? val.toStringAsFixed(1)
                                : val.toStringAsFixed(0);
                            return LineTooltipItem(
                              '$timeStr\n$valStr $unitLabel',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (double, double) _axisBounds(bool isFlow) {
    final values = widget.readings
        .map((r) => isFlow ? r.flowLpm : (r.totalL ?? (r.flowLpm * 15.0)))
        .toList();
    final rawMin = values.reduce((a, b) => a < b ? a : b);
    final rawMax = values.reduce((a, b) => a > b ? a : b);
    final span = rawMax - rawMin;
    // A flat line (including a single point, where span is always 0) needs
    // a minimum padding derived from the value's own magnitude rather than
    // the span, or the chart still collapses to a zero-height plot area.
    final padding = span > 0 ? span * 0.15 : (rawMax.abs() * 0.1).clamp(1.0, double.infinity);
    return (rawMin - padding, rawMax + padding);
  }

  Widget _buildMetricTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Gradient activeGradient,
    required Color activeShadowColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShapes.radiusXs),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: isSelected ? activeGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(AppShapes.radiusXs),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeShadowColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeTab(String range, IconData icon) {
    final isSelected = widget.selectedRange == range;
    return InkWell(
      onTap: () => widget.onRangeChanged(range),
      borderRadius: BorderRadius.circular(AppShapes.radiusXs),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.liquidSkyBlueGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(AppShapes.radiusXs),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 10,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 3),
            Text(
              range,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
