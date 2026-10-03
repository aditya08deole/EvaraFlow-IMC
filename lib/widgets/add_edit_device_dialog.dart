import 'dart:math';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/api_service.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';

/// Returned by [AddEditDeviceDialog] instead of a bare [Device] so an
/// optional Drive folder link/id pasted into the dialog can travel back to
/// the caller (all_devices_screen.dart) alongside it, to trigger
/// ApiService.startDriveBackfill once the device itself has been saved.
class DeviceFormResult {
  final Device device;
  final String? driveFolderId;

  const DeviceFormResult(this.device, this.driveFolderId);
}

/// Accepts a bare Drive folder id, a `.../drive/folders/<id>...` link, or a
/// `.../open?id=<id>` link; returns null for anything else — including an
/// obvious *file* link (`/file/d/...`), which is a different concept and
/// must not be silently treated as a folder.
String? extractDriveFolderId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  final bareId = RegExp(r'^[A-Za-z0-9_-]{10,}$');
  if (bareId.hasMatch(trimmed)) return trimmed;

  final folderLink = RegExp(r'/folders/([A-Za-z0-9_-]{10,})');
  final folderMatch = folderLink.firstMatch(trimmed);
  if (folderMatch != null) return folderMatch.group(1);

  final openLink = RegExp(r'[?&]id=([A-Za-z0-9_-]{10,})');
  final openMatch = openLink.firstMatch(trimmed);
  if (openMatch != null) return openMatch.group(1);

  return null;
}

class AddEditDeviceDialog extends StatefulWidget {
  final Device? initialDevice;

  const AddEditDeviceDialog({super.key, this.initialDevice});

  @override
  State<AddEditDeviceDialog> createState() => _AddEditDeviceDialogState();
}

class _AddEditDeviceDialogState extends State<AddEditDeviceDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _intervalController;
  late TextEditingController _mqttPasswordController;
  late TextEditingController _driveFolderController;
  ConsumptionMethod _consumptionMethod = ConsumptionMethod.totalizer;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _driveFolderError;
  String? _submitError;

  final ApiService _apiService = ApiService();

  bool get isEditing => widget.initialDevice != null;

  // Derived per the confirmed real-firmware convention
  // (EVARAFLOW_GROUND_TRUTH.md D-004, D-006) — not independently editable,
  // since the device firmware hardcodes this exact pattern itself. The
  // real firmware sets MQTT_CLIENT_ID and the Drive filename prefix equal
  // to the device's own id directly (e.g. "EVT-EF-002", which already
  // carries its own "EVT-" as part of its own naming, not a prefix added
  // on top) — these used to add a second "EVT-" prefix / a trailing "_",
  // producing values the real backend wouldn't actually match against.
  String get _mqttClientId => _idController.text.trim();
  String get _mqttUsername => 'device-${_idController.text.trim()}';
  String get _mqttTopic =>
      'evaratech/v1/${_idController.text.trim()}/telemetry';
  String get _driveMatchKey => _idController.text.trim();

  @override
  void initState() {
    super.initState();
    final d = widget.initialDevice;
    _idController = TextEditingController(text: d?.deviceId ?? 'EF-');
    _nameController = TextEditingController(text: d?.name ?? '');
    _locationController = TextEditingController(text: d?.location ?? '');
    _intervalController = TextEditingController(
      text: d?.expectedIntervalSeconds.toString() ?? '300',
    );
    _mqttPasswordController = TextEditingController();
    _driveFolderController = TextEditingController();
    if (d != null) {
      _consumptionMethod = d.consumptionMethod;
    }
    // Redraws the derived-identity panel as the ID is typed.
    _idController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _intervalController.dispose();
    _mqttPasswordController.dispose();
    _driveFolderController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789-_';
    final rng = Random.secure();
    final value = List.generate(
      24,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
    setState(() {
      _mqttPasswordController.text = value;
      _obscurePassword = false;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _driveFolderError = null;
      _submitError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final folderInput = _driveFolderController.text;
    String? driveFolderId;
    if (folderInput.trim().isNotEmpty) {
      driveFolderId = extractDriveFolderId(folderInput);
      if (driveFolderId == null) {
        setState(
          () => _driveFolderError =
              "Doesn't look like a Drive folder link or id — paste the folder's share link, or just its id.",
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      // Real org_id claim, not a typed/hardcoded value — a device must
      // belong to the signed-in administrator's own org for
      // firestore.rules to accept the write that follows.
      final orgId = await _apiService.currentOrgId();

      final device = Device(
        deviceId: _idController.text.trim(),
        orgId: orgId,
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        mqttTopic: _mqttTopic,
        driveMatchKey: _driveMatchKey,
        expectedIntervalSeconds: int.tryParse(_intervalController.text) ?? 300,
        consumptionMethod: _consumptionMethod,
        status: isEditing ? widget.initialDevice!.status : DeviceStatus.noData,
        lastSeenAt: widget.initialDevice?.lastSeenAt,
        firmwareVersion: widget.initialDevice?.firmwareVersion,
      );

      // The MQTT password is write-only by design (TR-2 / the backend plan's
      // §06): it would be sent once to a real backend to store in a secret
      // manager, never kept in the Device model or redisplayed. There's no
      // real backend yet, so it's intentionally dropped here rather than
      // threaded onto Device as if it were ordinary state.

      if (!mounted) return;
      Navigator.of(context).pop(DeviceFormResult(device, driveFolderId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = 'Could not save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: 560,
        child: SurfaceCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 18,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing
                          ? 'Edit EvaraFlow Device'
                          : 'Add New EvaraFlow Device',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Device ID & Name
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildTextField(
                        controller: _idController,
                        label: 'Device / Node ID *',
                        hint: 'EF-006',
                        enabled: !isEditing,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'ID required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: _buildTextField(
                        controller: _nameController,
                        label: 'Device Name *',
                        hint: 'Secondary Outlet Meter',
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Name required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Location
                _buildTextField(
                  controller: _locationController,
                  label: 'Location / Deployment Note *',
                  hint: 'Building C - Utility Shaft',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Location required' : null,
                ),
                const SizedBox(height: 16),

                // Derived connection identity — read-only, matches the
                // real firmware convention exactly (see backend plan §05).
                const Text(
                  'Connection Identity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Derived from the Device ID above — matches what the device firmware publishes to, not independently editable.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AppShapes.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _identityRow('MQTT client ID', _mqttClientId),
                      _identityRow('MQTT username', _mqttUsername),
                      _identityRow('MQTT topic', _mqttTopic),
                      _identityRow(
                        'Drive filename prefix',
                        _driveMatchKey,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // MQTT password — write-only
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MQTT Password',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _mqttPasswordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              hintText: isEditing
                                  ? 'Leave blank to keep the current credential'
                                  : 'Paste the credential issued when the device was provisioned',
                              hintStyle: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _generatePassword,
                          child: const Text(
                            'Generate',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Stored only as a secret-manager reference once a real backend is wired up — never shown again after saving.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Google Drive folder — optional. Paste a share link or a
                // bare folder id; on save this triggers a one-time backfill
                // of whatever's already in that folder (server/src/driveBackfill.ts)
                // so pre-existing photos show up in the gallery without
                // needing someone to run a script by hand. Live ingestion
                // doesn't need this at all — it routes by filename, not
                // folder — this is purely a one-time catch-up convenience.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Drive Folder (optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _driveFolderController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Paste the folder\'s share link, or just its id',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        isDense: true,
                        errorText: _driveFolderError,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'If this device already has photos sitting in Drive, pasting its folder here indexes them into the gallery in the background — can take a few minutes for a large folder.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Interval & Calculation method
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _intervalController,
                        label: 'Expected Interval (seconds)',
                        hint: '300',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Consumption Method',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<ConsumptionMethod>(
                            initialValue: _consumptionMethod,
                            isDense: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: ConsumptionMethod.totalizer,
                                child: Text(
                                  'Totalizer (Cum. Liters)',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              DropdownMenuItem(
                                value: ConsumptionMethod.integratedFlow,
                                child: Text(
                                  'Integrated Flow',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _consumptionMethod = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(AppShapes.radiusSm),
                    ),
                    child: Text(
                      _submitError!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.dangerRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditing ? 'Save Changes' : 'Create Device'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
            isDense: true,
          ),
          validator: validator,
        ),
      ],
    );
  }
}
