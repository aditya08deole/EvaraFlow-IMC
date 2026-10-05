enum DeviceStatus { online, offline, noData }

enum ConsumptionMethod { totalizer, integratedFlow }

/// Which image pipeline this device's photos are expected to come from —
/// purely a UI/display hint (which setup panel the Add/Edit dialog shows,
/// and what badge the gallery shows). Both pipelines actually still work
/// for any device regardless of this field: Tailscale ingestion is a
/// global poll keyed by node id (tailscalePoll.ts), and Drive ingestion
/// routes by filename prefix (ingestDriveImage.ts) — neither checks this
/// field. Nothing server-side depends on it.
enum ImageSource { none, tailscale, drive }

class Device {
  final String deviceId;
  final String orgId;
  final String name;
  final String location;
  final String mqttTopic;
  final String driveMatchKey;
  final int expectedIntervalSeconds;
  final ConsumptionMethod consumptionMethod;
  final ImageSource imageSource;
  final DeviceStatus status;
  final DateTime? lastSeenAt;
  final bool isActive;
  final String? firmwareVersion;

  /// Drive folder id this device's photos live in — persisted so
  /// server/src/drivePoll.ts can re-check the folder for new photos on a
  /// timer. Previously this only ever existed transiently inside the
  /// Add/Edit Device dialog's form state (used once to trigger a single
  /// backfill call, then discarded), so nothing could repeat that check
  /// later — a new photo dropped into the folder just sat there
  /// unindexed until someone manually reopened the dialog and re-pasted
  /// the same folder link (EVARAFLOW_GROUND_TRUTH.md D-034).
  final String? driveFolderId;

  const Device({
    required this.deviceId,
    required this.orgId,
    required this.name,
    required this.location,
    required this.mqttTopic,
    required this.driveMatchKey,
    required this.expectedIntervalSeconds,
    this.consumptionMethod = ConsumptionMethod.totalizer,
    this.imageSource = ImageSource.none,
    required this.status,
    this.lastSeenAt,
    this.isActive = true,
    this.firmwareVersion,
    this.driveFolderId,
  });

  /// Derived from [deviceId] per the confirmed real-firmware convention
  /// (EVARAFLOW_GROUND_TRUTH.md D-004) — not independently configurable,
  /// so these are computed rather than stored/editable. The real firmware
  /// sets MQTT_CLIENT_ID equal to the device's own id (e.g. "EVT-EF-002",
  /// which already carries its own "EVT-" as part of its own naming, not
  /// a prefix added on top) — mqttClientId used to add a second "EVT-"
  /// prefix, producing the wrong "EVT-EVT-EF-002".
  String get mqttClientId => deviceId;
  String get mqttUsername => 'device-$deviceId';

  bool get isStale {
    if (lastSeenAt == null) return true;
    final cutoff = DateTime.now().subtract(
      Duration(seconds: expectedIntervalSeconds * 3),
    );
    return lastSeenAt!.isBefore(cutoff);
  }

  Device copyWith({
    String? name,
    String? location,
    String? mqttTopic,
    String? driveMatchKey,
    int? expectedIntervalSeconds,
    ConsumptionMethod? consumptionMethod,
    ImageSource? imageSource,
    DeviceStatus? status,
    DateTime? lastSeenAt,
    bool? isActive,
    String? firmwareVersion,
    String? driveFolderId,
  }) {
    return Device(
      deviceId: deviceId,
      orgId: orgId,
      name: name ?? this.name,
      location: location ?? this.location,
      mqttTopic: mqttTopic ?? this.mqttTopic,
      driveMatchKey: driveMatchKey ?? this.driveMatchKey,
      expectedIntervalSeconds:
          expectedIntervalSeconds ?? this.expectedIntervalSeconds,
      consumptionMethod: consumptionMethod ?? this.consumptionMethod,
      imageSource: imageSource ?? this.imageSource,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isActive: isActive ?? this.isActive,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      driveFolderId: driveFolderId ?? this.driveFolderId,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['device_id'] as String,
      orgId: json['org_id'] as String? ?? 'org-001',
      name: json['name'] as String,
      location: json['location'] as String,
      mqttTopic: json['mqtt_topic'] as String,
      driveMatchKey: json['drive_match_key'] as String,
      expectedIntervalSeconds: json['expected_interval_s'] as int? ?? 300,
      consumptionMethod: json['consumption_method'] == 'integrated_flow'
          ? ConsumptionMethod.integratedFlow
          : ConsumptionMethod.totalizer,
      status: json['status'] == 'online'
          ? DeviceStatus.online
          : (json['status'] == 'offline'
                ? DeviceStatus.offline
                : DeviceStatus.noData),
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'])
          : null,
      isActive: json['is_active'] as bool? ?? true,
      firmwareVersion: json['fw'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'org_id': orgId,
      'name': name,
      'location': location,
      'mqtt_topic': mqttTopic,
      'drive_match_key': driveMatchKey,
      'expected_interval_s': expectedIntervalSeconds,
      'consumption_method': consumptionMethod.name,
      'status': status.name,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'is_active': isActive,
      'fw': firmwareVersion,
    };
  }
}
