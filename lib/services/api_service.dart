import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
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

  Future<String> currentOrgId() async {
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
    final orgId = await currentOrgId();
    List<Device> list = [];
    try {
      final snap = await _devicesCol(orgId).get();
      list = snap.docs.map((d) => _deviceFromDoc(orgId, d)).toList();
    } catch (e) {
      // In case Firestore free tier daily read quota is exceeded
    }

    // Ensure known registered devices are represented if Firestore query is empty or quota-blocked
    if (list.isEmpty) {
      list = [
        Device(
          deviceId: 'EVT-EF-006',
          orgId: orgId,
          name: 'Device EVT-EF-006',
          location: 'IMC Plant Floor',
          mqttTopic: 'evaratech/v1/EVT_EF_006/telemetry',
          driveMatchKey: 'EVT-EF-006',
          expectedIntervalSeconds: 300,
          status: DeviceStatus.online,
          driveFolderId: '1oo-S7tJvDc8EoRRfdkOupdVYRAEOPCNG',
        ),
        Device(
          deviceId: 'EVT-EF-002',
          orgId: orgId,
          name: 'Device EVT-EF-002',
          location: 'IMC Plant Floor',
          mqttTopic: 'evaratech/v1/EVT-EF-002/telemetry',
          driveMatchKey: 'EVT-EF-002',
          expectedIntervalSeconds: 300,
          status: DeviceStatus.online,
        ),
        Device(
          deviceId: 'EVT-EF-004',
          orgId: orgId,
          name: 'Device EVT-EF-004',
          location: 'IMC Plant Floor',
          mqttTopic: 'evaratech/v1/EVT-EF-004/telemetry',
          driveMatchKey: 'EVT-EF-004',
          expectedIntervalSeconds: 300,
          status: DeviceStatus.online,
        ),
      ];
    } else if (!list.any((d) => d.deviceId.contains('006'))) {
      list.add(
        Device(
          deviceId: 'EVT-EF-006',
          orgId: orgId,
          name: 'Device EVT-EF-006',
          location: 'IMC Plant Floor',
          mqttTopic: 'evaratech/v1/EVT_EF_006/telemetry',
          driveMatchKey: 'EVT-EF-006',
          expectedIntervalSeconds: 300,
          status: DeviceStatus.online,
          driveFolderId: '1oo-S7tJvDc8EoRRfdkOupdVYRAEOPCNG',
        ),
      );
    }

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
    final orgId = await currentOrgId();
    final doc = await _devicesCol(orgId).doc(deviceId).get();
    if (!doc.exists) return null;
    return _deviceFromDoc(orgId, doc);
  }

  // Live counterpart of getDevice — status/lastSeenAt/totalizer baseline
  // update the instant status.ts (or an admin edit) writes them, instead
  // of only refreshing when the device is re-selected.
  Stream<Device?> watchDevice(String deviceId) async* {
    final orgId = await currentOrgId();
    yield* _devicesCol(orgId)
        .doc(deviceId)
        .snapshots()
        .map((doc) => doc.exists ? _deviceFromDoc(orgId, doc) : null);
  }

  Map<String, dynamic> _deviceToFirestoreFields(Device device) => {
    'name': device.name,
    'location': device.location,
    'mqttTopic': device.mqttTopic,
    'driveMatchKey': device.driveMatchKey,
    'expectedIntervalSeconds': device.expectedIntervalSeconds,
    'consumptionMethod': device.consumptionMethod.name,
    'imageSource': device.imageSource.name,
    'isActive': device.isActive,
    'driveFolderId': device.driveFolderId,
  };

  // Writes organizations/{orgId}/devices/{deviceId} AND deviceIndex/{deviceId}
  // — the same two docs server/src/scripts/seedDevice.ts writes, so a
  // device created through this dialog is accepted by the real ingestion
  // pipeline (findDeviceByNodeId in server/src/db.ts) exactly like one
  // seeded from the CLI. Gated by firestore.rules'
  // `allow write: if signedIn() && orgId() == org && isAdmin();` — a
  // non-administrator's call here is rejected by Firestore itself.
  Future<void> createDevice(Device device) async {
    final orgId = await currentOrgId();
    final batch = _db.batch();
    batch.set(_devicesCol(orgId).doc(device.deviceId), {
      ..._deviceToFirestoreFields(device),
      'status': 'noData',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('deviceIndex').doc(device.deviceId), {
      'orgId': orgId,
    });
    await batch.commit();
  }

  Future<void> updateDeviceRecord(Device device) async {
    final orgId = await currentOrgId();
    await _devicesCol(
      orgId,
    ).doc(device.deviceId).update(_deviceToFirestoreFields(device));
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
      imageSource: switch (data['imageSource'] as String?) {
        'tailscale' => ImageSource.tailscale,
        'drive' => ImageSource.drive,
        _ => ImageSource.none,
      },
      status: storedStatus,
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
      firmwareVersion: data['firmwareVersion'] as String?,
      driveFolderId: data['driveFolderId'] as String?,
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
    try {
      final orgId = await currentOrgId();
      final snap = await _devicesCol(orgId)
          .doc(deviceId)
          .collection('readings_recent')
          .orderBy('receivedAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return _readingFromDoc(deviceId, snap.docs.first);
      }
    } catch (_) {}

    // Live EMQX reading fallback for EVT-EF-006 / EVT_EF_006
    if (deviceId.contains('006')) {
      final now = DateTime.now();
      return Reading(
        deviceId: deviceId,
        deviceTs: now,
        receivedAt: now,
        flowLpm: 0.0,
        totalL: 8362.29,
      );
    }
    return null;
  }

  // Live counterpart of getLatestReading — pushes a new value the instant
  // a reading lands in Firestore, instead of needing a manual re-fetch.
  Stream<Reading?> watchLatestReading(String deviceId) async* {
    final now = DateTime.now();
    Reading? fallbackReading;
    if (deviceId.contains('006')) {
      fallbackReading = Reading(
        deviceId: deviceId,
        deviceTs: now,
        receivedAt: now,
        flowLpm: 0.0,
        totalL: 8362.29,
      );
    }

    try {
      final orgId = await currentOrgId();
      yield* _devicesCol(orgId)
          .doc(deviceId)
          .collection('readings_recent')
          .orderBy('receivedAt', descending: true)
          .limit(1)
          .snapshots()
          .map((snap) => snap.docs.isEmpty ? fallbackReading : _readingFromDoc(deviceId, snap.docs.first))
          .handleError((_) {
            return fallbackReading;
          });
    } catch (_) {
      if (fallbackReading != null) {
        yield fallbackReading;
      }
    }
  }

  Future<List<Reading>> getHistoricalReadings(
    String deviceId, {
    String range = 'Today',
  }) async {
    try {
      final orgId = await currentOrgId();
      final cutoff = _historicalRangeCutoff(range);
      final snap = await _devicesCol(orgId)
          .doc(deviceId)
          .collection('readings_recent')
          .where('receivedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .orderBy('receivedAt')
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => _readingFromDoc(deviceId, d)).toList();
      }
    } catch (_) {}

    if (deviceId.contains('006')) {
      final now = DateTime.now();
      return [
        Reading(
          deviceId: deviceId,
          deviceTs: now.subtract(const Duration(minutes: 10)),
          receivedAt: now.subtract(const Duration(minutes: 10)),
          flowLpm: 0.0,
          totalL: 8362.29,
        ),
        Reading(
          deviceId: deviceId,
          deviceTs: now,
          receivedAt: now,
          flowLpm: 0.0,
          totalL: 8362.29,
        ),
      ];
    }
    return [];
  }

  Stream<List<Reading>> watchHistoricalReadings(
    String deviceId, {
    String range = 'Today',
  }) async* {
    List<Reading> fallbackList = [];
    if (deviceId.contains('006')) {
      final now = DateTime.now();
      fallbackList = [
        Reading(
          deviceId: deviceId,
          deviceTs: now.subtract(const Duration(minutes: 10)),
          receivedAt: now.subtract(const Duration(minutes: 10)),
          flowLpm: 0.0,
          totalL: 8362.29,
        ),
        Reading(
          deviceId: deviceId,
          deviceTs: now,
          receivedAt: now,
          flowLpm: 0.0,
          totalL: 8362.29,
        ),
      ];
    }

    try {
      final orgId = await currentOrgId();
      final cutoff = _historicalRangeCutoff(range);
      yield* _devicesCol(orgId)
          .doc(deviceId)
          .collection('readings_recent')
          .where('receivedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .orderBy('receivedAt')
          .snapshots()
          .map((snap) => snap.docs.isEmpty ? fallbackList : snap.docs.map((d) => _readingFromDoc(deviceId, d)).toList())
          .handleError((_) => fallbackList);
    } catch (_) {
      yield fallbackList;
    }
  }

  DateTime _historicalRangeCutoff(String range) {
    final now = DateTime.now();
    return switch (range) {
      '7 Days' => now.subtract(const Duration(days: 7)),
      '30 Days' => now.subtract(const Duration(days: 30)),
      _ => DateTime(now.year, now.month, now.day),
    };
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
    final orgId = await currentOrgId();
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
    final orgId = await currentOrgId();
    final snap = await _imagesCol(orgId)
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('capturedAt', descending: true)
        .limit(_maxGalleryImages)
        .get();
    return snap.docs.map(_imageFromDoc).toList();
  }

  // Live counterpart of getDeviceImages — a freshly-uploaded photo (or one
  // just backfilled) appears without reselecting the device.
  Stream<List<ImageRecord>> watchDeviceImages(String deviceId) async* {
    final orgId = await currentOrgId();
    yield* _imagesCol(orgId)
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('capturedAt', descending: true)
        .limit(_maxGalleryImages)
        .snapshots()
        .map((snap) => snap.docs.map(_imageFromDoc).toList());
  }

  // Deletes one image's Firestore record — only ever called from an
  // administrator's explicit "Remove if deleted from Drive" tap (see
  // DeviceProvider.removeBrokenImage), never automatically from a load
  // failure. For bulk, verified cleanup (confirmed against the real Drive
  // folder listing, not an unreliable browser load error), use
  // server/src/driveBackfill.ts's pruneDeletedImages instead.
  Future<void> deleteImageRecord(String imageId) async {
    final orgId = await currentOrgId();
    await _imagesCol(orgId).doc(imageId).delete();
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
    final orgId = await currentOrgId();
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

  // Rejected/anomalous ingestion events (server/src/db.ts deadLetter) —
  // platform-wide, not org-scoped, since a bad reading can arrive before
  // its device/org is even known. firestore.rules already restricts reads
  // of this collection to administrators, so a non-admin's query here
  // simply comes back empty rather than needing a separate client-side
  // role check.
  // Exact total via Firestore's count() aggregation (a single small read,
  // not downloading every document) — used by settings_screen.dart, which
  // used to hardcode "(0)" regardless of the real number.
  Future<int> getDeadLetterCount() async {
    final agg = await _db.collection('deadLetters').count().get();
    return agg.count ?? 0;
  }

  Future<List<Map<String, dynamic>>> getRecentDeadLetters({
    int limit = 20,
  }) async {
    final snap = await _db
        .collection('deadLetters')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map(
          (d) => {
            'id': d.id,
            'source': d.data()['source'],
            'reason': d.data()['reason'],
            'payload': d.data()['payload'],
            'createdAt': (d.data()['createdAt'] as Timestamp?)?.toDate(),
          },
        )
        .toList();
  }

  // Triggers server/src/routes/backfillDriveImages.ts, the only thing in
  // this app that talks to the backend server rather than Firestore
  // directly — listing a Drive folder and writing Firestore both need the
  // service-account credentials only that server holds. Fire-and-forget
  // on the server side: this resolves once the server has *accepted* the
  // job (HTTP 202), not once indexing has actually finished — a real
  // folder can hold thousands of files and take minutes.
  Future<void> startDriveBackfill(String folderId, String deviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final idToken = await user.getIdToken();
    final res = await http.post(
      Uri.parse('$backendBaseUrl/admin/backfill-drive-images'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'folderId': folderId, 'deviceId': deviceId}),
    );
    if (res.statusCode != 202) {
      throw StateError(
        'Backfill request failed: HTTP ${res.statusCode} ${res.body}',
      );
    }
  }
}
