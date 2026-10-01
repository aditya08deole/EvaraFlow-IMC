import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedFormat = 'csv';
  String _selectedTimeRange = '7days';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.liquidSkyBlueGradient,
                ),
                child: const Icon(
                  Icons.file_download_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Export Telemetry Data & Reports',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Generate, customize and download historical telemetry flow metrics and totalizer logs.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Main Export Configuration Card
          SurfaceCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Select Export Format',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFormatCard(
                      'csv',
                      'CSV Telemetry Stream',
                      'Raw 15-minute telemetry readings package',
                      Icons.table_chart_rounded,
                      AppColors.primary,
                    ),
                    const SizedBox(width: 14),
                    _buildFormatCard(
                      'xlsx',
                      'Excel Workbook (.xlsx)',
                      'Aggregated daily consumption & meter totals',
                      Icons.description_rounded,
                      AppColors.liveTeal,
                    ),
                    const SizedBox(width: 14),
                    _buildFormatCard(
                      'pdf',
                      'PDF Executive Report',
                      'Formatted audit report with trend snapshot',
                      Icons.picture_as_pdf_rounded,
                      const Color(0xFFFF3B30),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Text(
                  '2. Select Time Range & Scope',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildRangeTile('today', 'Today (24h)'),
                    const SizedBox(width: 10),
                    _buildRangeTile('7days', 'Last 7 Days'),
                    const SizedBox(width: 10),
                    _buildRangeTile('30days', 'Last 30 Days'),
                    const SizedBox(width: 10),
                    _buildRangeTile('all', 'All Historical Data'),
                  ],
                ),
                const SizedBox(height: 28),

                // Generate & Export Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Export package created! Downloading telemetry log (${_selectedFormat.toUpperCase()} format, $_selectedTimeRange).',
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      'Generate & Download ${_selectedFormat.toUpperCase()} Package',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      // shape omitted — inherits AppShapes.button (continuous
                      // curvature) from the central ElevatedButtonTheme.
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatCard(
    String key,
    String title,
    String desc,
    IconData icon,
    Color accentColor,
  ) {
    final isSelected = _selectedFormat == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFormat = key),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.12)
                : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accentColor : AppColors.border,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: accentColor, size: 24),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: accentColor,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? accentColor : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeTile(String key, String label) {
    final isSelected = _selectedTimeRange == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTimeRange = key),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.liquidSkyBlueGradient : null,
            color: isSelected ? null : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
