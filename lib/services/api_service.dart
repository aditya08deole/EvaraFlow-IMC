import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/device.dart';
import '../models/reading.dart';
import '../models/image_record.dart';
import '../models/alert.dart';

/// Reads real data straight from Firestore (Firestore/Storage/Auth stay on
/// Firebase per EVARAFLOW_GROUND_TRUTH.md D-013; this app never calls the
/// Railway server for reads, only Apps Script/EMQX write into Firestore via
/// that server). Every query is scoped to the signed-in user's `org_id`
/// custom claim, matching firestore.rules — there is no fixture/mock path
/// here: a signed-in user without that claim set sees empty data, not
/// fabricated data, until an administrator sets it.
class ApiService {
  final FirebaseFirestore _db;
  String? _cachedOrgId;

  ApiService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Future<String> _orgId() async {
    final cached = _cachedOrgId;
    if (cached != null) return cached;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final tokenResult = await user.getIdTokenResult();
    final orgId = tokenResult.claims?['org_id'] as String?;
    if (orgId == null || orgId.isEmpty) {
      throw StateError(
        'Signed-in user has no org_id claim set — contact an administrator.',
      );
    }
    _cachedOrgId = orgId;
    return orgId;
  }

  CollectionReference<Map<String, dynamic>> _devicesCol(String orgId) =>
      _db.collection('organizations').doc(orgId).collection('devices');

  CollectionReference<Map<String, dynamic>> _imagesCol(String orgId) =>
      _db.collection('organizations').doc(orgId).collection('images');

  CollectionReference<Map<String, dynamic>> _alertsCol(String orgId) =>
      _db.collection('organizations').doc(orgId).collection('alerts');

  Future<List<Device>> getDevices({
    String search = '',
    String statusFilter = 'all',
  }) async {
    final orgId = await _orgId();
    final snap = await _devicesCol(orgId).get();
    var list = snap.docs.map((d) => _deviceFromDoc(orgId, d)).toList();

    if (search.isNotEmpty) {
      final query = search.toLowerCase();
      list = list
          .where(
            (d) =>
                d.deviceId.toLowerCase().contains(query) ||
                d.name.toLowerCase().contains(query) ||
                d.location.toLowerCase().contains(query),
          )
          .toList();
    }
    if (statusFilter != 'all') {
      list = list.where((d) => d.status.name == statusFilter).toList();
    }
    return list;
  }

  Future<Device?> getDevice(String deviceId) async {
    final orgId = await _orgId();
    final doc = await _devicesCol(orgId).doc(deviceId).get();
    if (!doc.exists) return null;
    return _deviceFromDoc(orgId, doc);
  }

  Device _deviceFromDoc(
    String orgId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final statusStr = data['status'] as String? ?? 'noData';
    final storedStatus = switch (statusStr) {
      'online' => DeviceStatus.online,
      'offline' => DeviceStatus.offline,
      _ => DeviceStatus.noData,
    };

    final device = Device(
      deviceId: doc.id,
      orgId: orgId,
      name: data['name'] as String? ?? doc.id,
      location: data['location'] as String? ?? 'Unset',
      mqttTopic: data['mqttTopic'] as String? ?? '',
      driveMatchKey: data['driveMatchKey'] as String? ?? doc.id,
      expectedIntervalSeconds:
          (data['expectedIntervalSeconds'] as num?)?.toInt() ?? 300,
      consumptionMethod: data['consumptionMethod'] == 'integratedFlow'
          ? ConsumptionMethod.integratedFlow
          : ConsumptionMethod.totalizer,
      status: storedStatus,
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
      firmwareVersion: data['firmwareVersion'] as String?,
    );

    // server/src/status.ts (TR-12) can only ever prove a device *online* —
    // it has no scheduled sweep to flip a device back to offline after it
    // goes silent (a known, documented gap), so the stored `status` field
    // can be stale forever. Device.isStale applies the same 3x-interval
    // rule client-side at read time so the dashboard doesn't claim a device
    // is online when it's actually gone quiet.
    if (storedStatus == DeviceStatus.online && device.isStale) {
      return device.copyWith(status: DeviceStatus.offline);
    }
    return device;
  }

  // Pipeline A: MQTT telemetry, written by server/src/db.ts insertReading
  // into organizations/{orgId}/devices/{deviceId}/readings_recent.
  Future<Reading?> getLatestReading(String deviceId) async {
    final orgId = await _orgId();
    final snap = await _devicesCol(orgId)
        .doc(deviceId)
        .collection('readings_recent')
        .orderBy('receivedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _readingFromDoc(deviceId, snap.docs.first);
  }

  Future<List<Reading>> getHistoricalReadings(
    String deviceId, {
    String range = 'Today',
  }) async {
    final orgId = await _orgId();
    final now = DateTime.now();
    final cutoff = switch (range) {
      '7 Days' => now.subtract(const Duration(days: 7)),
      '30 Days' => now.subtract(const Duration(days: 30)),
      _ => DateTime(now.year, now.month, now.day),
    };

    final snap = await _devicesCol(orgId)
        .doc(deviceId)
        .collection('readings_recent')
        .where('receivedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .orderBy('receivedAt')
        .get();
    return snap.docs.map((d) => _readingFromDoc(deviceId, d)).toList();
  }

  Reading _readingFromDoc(
    String deviceId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final deviceTs = (data['deviceTs'] as Timestamp?)?.toDate();
    final receivedAt = (data['receivedAt'] as Timestamp?)?.toDate();
    return Reading(
      deviceId: deviceId,
      deviceTs: deviceTs ?? receivedAt ?? DateTime.now(),
      receivedAt: receivedAt ?? deviceTs ?? DateTime.now(),
      flowLpm: (data['flowLpm'] as num?)?.toDouble() ?? 0.0,
      totalL: (data['totalL'] as num?)?.toDouble(),
      sensorStatus: data['sensorStatus'] as String? ?? 'ok',
      firmwareVersion: data['firmwareVersion'] as String?,
    );
  }

  // Pipeline B: Drive images, written by server/src/db.ts insertImage into
  // organizations/{orgId}/images (flat collection, deviceId as a field —
  // not a per-device subcollection).
  Future<ImageRecord?> getLatestImage(String deviceId) async {
    final orgId = await _orgId();
    final snap = await _imagesCol(orgId)
        .where('deviceId', isEqualTo: deviceId)
        // Ordered by capturedAt (parsed from the filename's timestamp —
        // when the photo was actually taken), not receivedAt (when our
        // backend found out about it). Those two only coincide for images
        // ingested live; a bulk backfill of pre-existing Drive files
        // inserts everything within the same few minutes, so receivedAt
        // would sort them in whatever order the Drive API happened to
        // list them in, not true chronological order.
        .orderBy('capturedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _imageFromDoc(snap.docs.first);
  }

  // Capped — a device can accumulate thousands of images (one every few
  // minutes), and the gallery grid (image_gallery_modal.dart) has no
  // pagination of its own, so an unbounded query would pull the device's
  // entire history over the network on every open.
  static const int _maxGalleryImages = 100;

  Future<List<ImageRecord>> getDeviceImages(String deviceId) async {
    final orgId = await _orgId();
    final snap = await _imagesCol(orgId)
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('capturedAt', descending: true)
        .limit(_maxGalleryImages)
        .get();
    return snap.docs.map(_imageFromDoc).toList();
  }

  ImageRecord _imageFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final capturedAtStr = data['capturedAt'] as String?;
    return ImageRecord(
      id: doc.id,
      deviceId: data['deviceId'] as String?,
      driveFileId: data['driveFileId'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      capturedAt: capturedAtStr != null
          ? DateTime.tryParse(capturedAtStr)
          : null,
      receivedAt:
          (data['receivedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      storageUrl: data['storageUrl'] as String? ?? '',
      thumbnailUrl: data['thumbUrl'] as String? ?? '',
    );
  }

  // Alerts: no writer exists yet (server/src/status.ts has this as an
  // explicit extension point pending EVARAFLOW_GROUND_TRUTH.md D-008), so
  // this will honestly return an empty list until that's built — not a
  // fixture fallback.
  Future<List<AlertItem>> getAlerts() async {
    final orgId = await _orgId();
    final snap = await _alertsCol(
      orgId,
    ).orderBy('openedAt', descending: true).get();
    return snap.docs.map(_alertFromDoc).toList();
  }

  AlertItem _alertFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final typeStr = data['type'] as String? ?? 'deviceOffline';
    final statusStr = data['status'] as String? ?? 'newAlert';
    return AlertItem(
      id: doc.id,
      deviceId: data['deviceId'] as String? ?? '',
      deviceName: data['deviceName'] as String? ?? '',
      type: switch (typeStr) {
        'noFlow' => AlertType.noFlow,
        'highFlow' => AlertType.highFlow,
        _ => AlertType.deviceOffline,
      },
      severity: data['severity'] as String? ?? 'info',
      status: switch (statusStr) {
        'acknowledged' => AlertStatus.acknowledged,
        'resolved' => AlertStatus.resolved,
        _ => AlertStatus.newAlert,
      },
      description: data['description'] as String? ?? '',
      openedAt:
          (data['openedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acknowledgedBy: data['acknowledgedBy'] as String?,
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }
}
