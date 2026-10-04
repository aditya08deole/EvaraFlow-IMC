import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../services/api_service.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';

/// Previously showed an entirely invented identity ("Ops Admin",
/// admin@evaratech.com, "org-evaratech-01", "5 Flow Meters") and invented
/// security/alert settings claimed as "Enabled" (2FA, API token scopes,
/// alert channels) for features that don't exist anywhere in this
/// codebase — found during a pass looking for exactly this kind of thing.
/// Everything below is either the real signed-in Firebase Auth user (incl.
/// its own account-creation/last-sign-in timestamps, which Firebase Auth
/// already tracks — nothing invented) or a real Firestore query; the
/// security/alerts card is labeled as what it actually is (not built yet)
/// rather than claimed as active.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  String? _orgId;
  List<Device>? _devices;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orgId = await _apiService.currentOrgId();
      final devices = await _apiService.getDevices();
      if (mounted) {
        setState(() {
          _orgId = orgId;
          _devices = devices;
        });
      }
    } catch (_) {
      // No org_id claim set yet for this user — leave both as "—" rather
      // than fabricating a value, per this project's own rule against
      // presenting an assumption as fact.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email ?? 'Unknown user');
    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join();
    final dateFormat = DateFormat('MMM d, yyyy \'at\' HH:mm');

    final online = _devices?.where((d) => d.status == DeviceStatus.online).length;
    final offline = _devices?.where((d) => d.status == DeviceStatus.offline).length;
    final noData = _devices?.where((d) => d.status == DeviceStatus.noData).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.liquidSkyBlueGradient,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'User Profile & Identity',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Signed-in account, organization, and fleet overview.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dangerRed,
                  side: const BorderSide(color: AppColors.dangerRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Main Profile Overview Glass Card
          SurfaceCard(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Badge
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Primary Profile Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Information Grid — real data only
                      Row(
                        children: [
                          _buildProfileInfoItem(
                            'Organization ID',
                            _orgId ?? '—',
                            Icons.tag_rounded,
                          ),
                          const SizedBox(width: 16),
                          _buildProfileInfoItem(
                            'Account Created',
                            user?.metadata.creationTime != null
                                ? dateFormat.format(user!.metadata.creationTime!)
                                : '—',
                            Icons.calendar_today_rounded,
                          ),
                          const SizedBox(width: 16),
                          _buildProfileInfoItem(
                            'Last Sign-In',
                            user?.metadata.lastSignInTime != null
                                ? dateFormat.format(user!.metadata.lastSignInTime!)
                                : '—',
                            Icons.login_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fleet Overview — real device-status breakdown, not just a
          // flat count, so this card is actually useful at a glance.
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.sensors_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Fleet Overview',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _fleetStatusChip(
                      'Total',
                      _devices != null ? '${_devices!.length}' : '—',
                      AppColors.textMuted,
                      AppColors.backgroundSecondary,
                    ),
                    const SizedBox(width: 10),
                    _fleetStatusChip(
                      'Online',
                      online != null ? '$online' : '—',
                      AppColors.liveTeal,
                      AppColors.liveTealLight,
                    ),
                    const SizedBox(width: 10),
                    _fleetStatusChip(
                      'Offline',
                      offline != null ? '$offline' : '—',
                      AppColors.dangerRed,
                      AppColors.dangerLight,
                    ),
                    const SizedBox(width: 10),
                    _fleetStatusChip(
                      'No Data Yet',
                      noData != null ? '$noData' : '—',
                      AppColors.warningAmber,
                      AppColors.warningLight,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Honest placeholder — these aren't built yet anywhere in this
          // codebase. Previously this card claimed 2FA/API tokens/sessions
          // were "Enabled" with specific fake values; that was simply
          // false, so it's labeled as not-yet-built instead.
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.construction_outlined,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Security, Sessions & Alert Preferences',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Not built in this version. Authentication is handled entirely by Firebase Auth; there is no 2FA, API token, or alert-channel management layer in this app yet (alert thresholds themselves are still a Proposed decision — EVARAFLOW_GROUND_TRUTH.md D-008).',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fleetStatusChip(
    String label,
    String value,
    Color accent,
    Color background,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppShapes.radiusSm),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoItem(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppShapes.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
