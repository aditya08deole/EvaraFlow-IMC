import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedMetricTile extends StatefulWidget {
  final String label;
  final double numericValue;
  final String displayString;
  final String unit;
  final IconData icon;
  final Color accentColor;
  final String? subtitle;
  final String? trendText;
  final bool isPositiveTrend;
  final bool isTime;

  const AnimatedMetricTile({
    super.key,
    required this.label,
    required this.numericValue,
    required this.displayString,
    required this.unit,
    required this.icon,
    required this.accentColor,
    this.subtitle,
    this.trendText,
    this.isPositiveTrend = true,
    this.isTime = false,
  });

  @override
  State<AnimatedMetricTile> createState() => _AnimatedMetricTileState();
}

class _AnimatedMetricTileState extends State<AnimatedMetricTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _isHovered ? 0.45 : 0.32),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: _isHovered ? 0.95 : 0.85),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(
                  alpha: _isHovered ? 0.18 : 0.08,
                ),
                blurRadius: _isHovered ? 20 : 12,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // iOS Control Center Circular Liquid Icon Badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          widget.accentColor,
                          widget.accentColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, size: 14, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (widget.isTime)
                Text(
                  widget.displayString,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                )
              else
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: widget.numericValue * 0.9,
                    end: widget.numericValue,
                  ),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, child) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          val.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (widget.unit.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            widget.unit,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.accentColor,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),

              if (widget.subtitle != null || widget.trendText != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (widget.trendText != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isPositiveTrend
                              ? AppColors.liveTeal.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.isPositiveTrend
                                ? AppColors.liveTeal.withValues(alpha: 0.4)
                                : AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isPositiveTrend
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 10,
                              color: widget.isPositiveTrend
                                  ? AppColors.liveTeal
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.trendText!,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: widget.isPositiveTrend
                                    ? AppColors.liveTeal
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (widget.subtitle != null)
                      Expanded(
                        child: Text(
                          widget.subtitle!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
