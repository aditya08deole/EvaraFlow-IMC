import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SkeletonCard extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const SkeletonCard({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.5),
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: _animation.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device header skeleton
          const SkeletonCard(height: 70),
          const SizedBox(height: 20),

          // 2-column or stacked top section skeleton
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Row(
                        children: const [
                          Expanded(child: SkeletonCard(height: 110)),
                          SizedBox(width: 12),
                          Expanded(child: SkeletonCard(height: 110)),
                          SizedBox(width: 12),
                          Expanded(child: SkeletonCard(height: 110)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                const Expanded(flex: 5, child: SkeletonCard(height: 110)),
              ],
            )
          else
            Column(
              children: const [
                SkeletonCard(height: 110),
                SizedBox(height: 12),
                SkeletonCard(height: 110),
              ],
            ),

          const SizedBox(height: 24),
          // Chart Skeleton
          const SkeletonCard(height: 280),

          const SizedBox(height: 24),
          // Table Skeleton
          const SkeletonCard(height: 220),
        ],
      ),
    );
  }
}
