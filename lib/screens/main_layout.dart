import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/alert.dart';
import 'dashboard_screen.dart';
import 'all_devices_screen.dart';
import 'alerts_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mesh_background.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  void _onSelectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeviceProvider>(context);
    final unackAlerts = provider.alerts
        .where((a) => a.status == AlertStatus.newAlert)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BrandMeshBackground(
        child: Stack(
          children: [
            // 3. Main Body Content Pages
            Padding(
              padding: const EdgeInsets.only(top: 108),
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  const DashboardScreen(),
                  AllDevicesScreen(onOpenDashboard: () => _onSelectTab(0)),
                  AlertsScreen(onOpenDashboard: () => _onSelectTab(0)),
                  const ReportsScreen(),
                  const ProfileScreen(),
                ],
              ),
            ),

            // 4. Fixed Centered Floating Top Navigation Bar
            Positioned(
              top: 18,
              left: 24,
              right: 24,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: _buildNavbar(context, unackAlerts),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isNavHovered = false;

  Widget _buildNavbar(BuildContext context, int unackAlerts) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 960;

    return MouseRegion(
      onEnter: (_) => setState(() => _isNavHovered = true),
      onExit: (_) => setState(() => _isNavHovered = false),
      child: AnimatedScale(
        scale: _isNavHovered ? 1.012 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _isNavHovered ? -4.0 : 0.0,
            0,
          ),
          child: DecoratedBox(
            // shape.side is never painted by either render path — the
            // visible rim comes from this real border + glow instead.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: _isNavHovered ? 0.95 : 0.85,
                ),
                width: _isNavHovered ? 1.8 : 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(
                    alpha: _isNavHovered ? 0.6 : 0.45,
                  ),
                  blurRadius: _isNavHovered ? 14 : 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: GlassContainer(
                useOwnLayer: true,
                height: 74,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: const LiquidRoundedSuperellipse(borderRadius: 50),
                settings: LiquidGlassSettings(
                  glassColor: AppColors.primary.withValues(
                    alpha: _isNavHovered ? 0.12 : 0.08,
                  ),
                  blur: _isNavHovered ? 18 : 14,
                  thickness: 30,
                  chromaticAberration: 0.02,
                  lightIntensity: _isNavHovered ? 1.0 : 0.85,
                  refractiveIndex: 1.3,
                  saturation: 1.4,
                  glowIntensity: _isNavHovered ? 1.2 : 1.0,
                  specularSharpness: GlassSpecularSharpness.sharp,
                  shadowElevation: _isNavHovered ? 1.6 : 1.2,
                  standardOpacityMultiplier: 0.45,
                ),
                child: Row(
                  children: [
                    // Left: Brand Emblem (EvaraFlow)
                    InkWell(
                      onTap: () => _onSelectTab(0),
                      borderRadius: BorderRadius.circular(28),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF007AFF),
                                    Color(0xFF34C759),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF007AFF,
                                    ).withValues(alpha: 0.45),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.water_drop_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Evara',
                                    style: TextStyle(color: Color(0xFF0F172A)),
                                  ),
                                  TextSpan(
                                    text: 'Tech',
                                    style: TextStyle(color: Color(0xFF007AFF)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Center: Navigation Items (Dead Centered on Navigation Header Bar)
                    Expanded(
                      child: Center(
                        child: !isCompact
                            ? Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildNavLink(
                                      0,
                                      'Dashboard',
                                      Icons.grid_view_rounded,
                                    ),
                                    _buildNavLink(
                                      1,
                                      'All Devices',
                                      Icons.devices_rounded,
                                    ),
                                    _buildNavLink(
                                      2,
                                      'Alerts',
                                      Icons.notifications_rounded,
                                      badgeCount: unackAlerts,
                                    ),
                                    _buildNavLink(
                                      3,
                                      'Export',
                                      Icons.file_download_outlined,
                                    ),
                                    _buildNavLink(
                                      4,
                                      'Profile',
                                      Icons.person_outline_rounded,
                                    ),
                                  ],
                                ),
                              )
                            : PopupMenuButton<int>(
                                icon: const Icon(
                                  Icons.menu_rounded,
                                  color: AppColors.textPrimary,
                                  size: 26,
                                ),
                                onSelected: _onSelectTab,
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 0,
                                    child: Text('Dashboard'),
                                  ),
                                  const PopupMenuItem(
                                    value: 1,
                                    child: Text('All Devices'),
                                  ),
                                  PopupMenuItem(
                                    value: 2,
                                    child: Text('Alerts'),
                                  ),
                                  const PopupMenuItem(
                                    value: 3,
                                    child: Text('Export Data'),
                                  ),
                                  const PopupMenuItem(
                                    value: 4,
                                    child: Text('Profile'),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // Right Placeholder balancing logo width for perfect geometric centering
                    if (!isCompact) const SizedBox(width: 155),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavLink(
    int index,
    String label,
    IconData icon, {
    int badgeCount = 0,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: _NavItem(
        isSelected: isSelected,
        label: label,
        icon: icon,
        badgeCount: badgeCount,
        onTap: () => _onSelectTab(index),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final bool isSelected;
  final String label;
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: widget.isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : (_isHovered
                        ? LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.75),
                              Colors.white.withValues(alpha: 0.55),
                            ],
                          )
                        : null),
              color: (widget.isSelected || _isHovered)
                  ? null
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: widget.isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : (_isHovered
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.transparent),
                width: 1.2,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.40),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.isSelected
                      ? Colors.white
                      : (_isHovered
                            ? const Color(0xFF007AFF)
                            : AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isSelected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: widget.isSelected
                        ? Colors.white
                        : (_isHovered
                              ? const Color(0xFF0F172A)
                              : AppColors.textSecondary),
                  ),
                ),
                if (widget.badgeCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? Colors.white
                          : const Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${widget.badgeCount}',
                      style: TextStyle(
                        color: widget.isSelected
                            ? const Color(0xFF007AFF)
                            : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
