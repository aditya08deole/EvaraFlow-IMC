import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../models/reading.dart';
import '../models/image_record.dart';
import '../models/alert.dart';
import '../services/api_service.dart';

class DeviceProvider with ChangeNotifier {
  late final ApiService _apiService;

  List<Device> _devices = [];
  final List<String> _recentDeviceIds = [];

  String? _selectedDeviceId;
  Device? _selectedDevice;

  Reading? _latestReading;
  List<Reading> _historicalReadings = [];
  ImageRecord? _latestImage;
  List<ImageRecord> _deviceImages = [];
  List<AlertItem> _alerts = [];

  bool _isDevicesLoading = true;
  bool _isDashboardLoading = true;
  bool _isImagesLoading = true;
  String? _dashboardError;
  String? _imagesError;

  // Live Firestore listeners for whichever device is currently selected —
  // replaced (not merely re-fetched) on every selectDevice/setRange, so a
  // new real MQTT reading or a freshly backfilled/deleted image reflects
  // immediately instead of needing a manual refresh or device reselect.
  StreamSubscription<Device?>? _deviceSub;
  StreamSubscription<Reading?>? _latestReadingSub;
  StreamSubscription<List<Reading>>? _historicalSub;
  StreamSubscription<List<ImageRecord>>? _imagesSub;

  String _selectedRange = 'Today';
  int _tablePage = 1;
  final int _pageSize = 10;

  // Getters
  List<Device> get devices => _devices;
  List<String> get recentDeviceIds => _recentDeviceIds;
  String? get selectedDeviceId => _selectedDeviceId;
  Device? get selectedDevice => _selectedDevice;

  Reading? get latestReading => _latestReading;
  List<Reading> get historicalReadings => _historicalReadings;
  ImageRecord? get latestImage => _latestImage;
  List<ImageRecord> get deviceImages => _deviceImages;
  List<AlertItem> get alerts => _alerts;

  bool get isDevicesLoading => _isDevicesLoading;
  bool get isDashboardLoading => _isDashboardLoading;
  bool get isImagesLoading => _isImagesLoading;
  String? get dashboardError => _dashboardError;
  String? get imagesError => _imagesError;

  String get selectedRange => _selectedRange;
  int get tablePage => _tablePage;
  int get pageSize => _pageSize;

  // Paginated past readings
  List<Reading> get paginatedReadings {
    final reversed = _historicalReadings.reversed.toList();
    final startIndex = (_tablePage - 1) * _pageSize;
    if (startIndex >= reversed.length) return [];
    final endIndex = (startIndex + _pageSize).clamp(0, reversed.length);
    return reversed.sublist(startIndex, endIndex);
  }

  int get totalTablePages =>
      (_historicalReadings.length / _pageSize).ceil().clamp(1, 999);

  // Today's calculated total consumption in Liters (FR-C4)
  double get todaysConsumption {
    if (_historicalReadings.isEmpty) return 0.0;

    // Totalizer method
    if (_selectedDevice?.consumptionMethod == ConsumptionMethod.totalizer) {
      final validTotalizers = _historicalReadings
          .where((r) => r.totalL != null)
          .toList();
      if (validTotalizers.length < 2) return 0.0;
      final diff = validTotalizers.last.totalL! - validTotalizers.first.totalL!;
      return diff > 0 ? diff : 0.0;
    } else {
      // Integrated flow method
      double total = 0.0;
      for (int i = 1; i < _historicalReadings.length; i++) {
        final durationMinutes =
            _historicalReadings[i].deviceTs
                .difference(_historicalReadings[i - 1].deviceTs)
                .inSeconds /
            60.0;
        final avgFlow =
            (_historicalReadings[i].flowLpm +
                _historicalReadings[i - 1].flowLpm) /
            2.0;
        total += avgFlow * durationMinutes;
      }
      return double.parse(total.toStringAsFixed(1));
    }
  }

  // Firestore listeners only push a rebuild when data actually changes —
  // but "4m ago" labels and the isStale() offline check in
  // ApiService._deviceFromDoc both depend on comparing stored timestamps
  // against DateTime.now(), which keeps moving even when nothing in
  // Firestore does. Without this, those would freeze at whatever they
  // said the moment the last real update arrived instead of counting up
  // live. This never touches the network — it's a local-only rebuild
  // trigger, so it's cheap enough to run often.
  Timer? _tickTimer;

  DeviceProvider({ApiService? apiService})
    : _apiService = apiService ?? ApiService() {
    init();
    _tickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      notifyListeners();
    });
  }

  Future<void> init() async {
    await fetchDevices();
    if (_devices.isNotEmpty) {
      selectDevice(_devices.first.deviceId);
    }
    await fetchAlerts();
  }

  Future<void> fetchDevices() async {
    _isDevicesLoading = true;
    notifyListeners();
    try {
      _devices = await _apiService.getDevices();
    } catch (e) {
      debugPrint('Error fetching devices: $e');
    } finally {
      _isDevicesLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAlerts() async {
    try {
      _alerts = await _apiService.getAlerts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching alerts: $e');
    }
  }

  /// SECTION 3.7: Device Switching Implementation
  void selectDevice(String deviceId) {
    if (_selectedDeviceId == deviceId && !_isDashboardLoading) return;

    _selectedDeviceId = deviceId;
    _selectedDevice = _devices.firstWhere(
      (d) => d.deviceId == deviceId,
      orElse: () => Device(
        deviceId: deviceId,
        orgId: _selectedDevice?.orgId ?? '',
        name: deviceId,
        location: 'Unknown',
        mqttTopic: 'evaratech/v1/$deviceId/telemetry',
        driveMatchKey: deviceId,
        expectedIntervalSeconds: 300,
        status: DeviceStatus.noData,
      ),
    );

    // Rule 2: Clear old data immediately. Never leave previous device data visible.
    _latestReading = null;
    _historicalReadings = [];
    _latestImage = null;
    _deviceImages = [];
    _dashboardError = null;
    _imagesError = null;
    _isDashboardLoading = true;
    _isImagesLoading = true;
    _selectedRange = 'Today';
    _tablePage = 1;

    // Persist recents
    if (!_recentDeviceIds.contains(deviceId)) {
      _recentDeviceIds.insert(0, deviceId);
      if (_recentDeviceIds.length > 5) _recentDeviceIds.removeLast();
    }

    notifyListeners();

    _subscribeToDevice(deviceId);
  }

  // Live — not a one-shot fetch. Cancels whatever the previous device (or
  // range) was subscribed to and resubscribes, so exactly one listener per
  // stream is ever active at a time.
  void _subscribeToDevice(String deviceId) {
    _deviceSub?.cancel();
    _latestReadingSub?.cancel();
    _imagesSub?.cancel();

    _deviceSub = _apiService.watchDevice(deviceId).listen(
      (device) {
        if (_selectedDeviceId != deviceId) return;
        if (device != null) {
          _selectedDevice = device;
          final idx = _devices.indexWhere((d) => d.deviceId == deviceId);
          if (idx != -1) _devices[idx] = device;
        }
        notifyListeners();
      },
      onError: (e) {
        if (_selectedDeviceId != deviceId) return;
        debugPrint('watchDevice error: $e');
      },
    );

    _latestReadingSub = _apiService.watchLatestReading(deviceId).listen(
      (reading) {
        if (_selectedDeviceId != deviceId) return;
        _latestReading = reading;
        _isDashboardLoading = false;
        notifyListeners();
      },
      onError: (e) {
        if (_selectedDeviceId != deviceId) return;
        _dashboardError = 'Unable to retrieve device telemetry data.';
        _isDashboardLoading = false;
        notifyListeners();
      },
    );

    _subscribeToHistoricalReadings(deviceId);

    _imagesSub = _apiService.watchDeviceImages(deviceId).listen(
      (images) {
        if (_selectedDeviceId != deviceId) return;
        _deviceImages = images;
        _latestImage = images.isNotEmpty ? images.first : null;
        _isImagesLoading = false;
        notifyListeners();
      },
      onError: (e) {
        if (_selectedDeviceId != deviceId) return;
        _imagesError = 'Unable to retrieve device images.';
        _isImagesLoading = false;
        notifyListeners();
      },
    );
  }

  void _subscribeToHistoricalReadings(String deviceId) {
    _historicalSub?.cancel();
    _historicalSub = _apiService
        .watchHistoricalReadings(deviceId, range: _selectedRange)
        .listen(
          (readings) {
            if (_selectedDeviceId != deviceId) return;
            _historicalReadings = readings;
            notifyListeners();
          },
          onError: (e) {
            if (_selectedDeviceId != deviceId) return;
            _dashboardError = 'Unable to retrieve device telemetry data.';
            notifyListeners();
          },
        );
  }

  void setRange(String range) {
    if (_selectedRange == range) return;
    _selectedRange = range;
    _tablePage = 1;
    if (_selectedDeviceId != null) {
      _subscribeToHistoricalReadings(_selectedDeviceId!);
    }
    notifyListeners();
  }

  // Called only when an administrator explicitly taps "Remove if deleted
  // from Drive" on a broken-image placeholder (see image_gallery_modal.dart
  // / latest_image_card.dart) — deliberately never automatic. A failed
  // image load can't be told apart from lh3.googleusercontent.com
  // transiently throttling an unauthenticated hotlink request (unofficial
  // hotlinking, not a supported API), so auto-deleting on load error would
  // risk wiping a record for a photo that's still really there. The live
  // image stream above updates the UI on its own once this succeeds; no
  // local list mutation needed here.
  Future<void> removeBrokenImage(String imageId) async {
    try {
      await _apiService.deleteImageRecord(imageId);
    } catch (e) {
      debugPrint('removeBrokenImage failed for $imageId: $e');
    }
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _latestReadingSub?.cancel();
    _historicalSub?.cancel();
    _imagesSub?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  void setTablePage(int page) {
    _tablePage = page.clamp(1, totalTablePages);
    notifyListeners();
  }

  // Writes through to Firestore before updating local state — errors
  // (e.g. permission-denied from firestore.rules for a non-administrator)
  // propagate to the caller rather than being swallowed, since the old
  // local-only-mutation version let a failed write look like it had
  // succeeded.
  Future<void> updateDevice(Device updated) async {
    await _apiService.updateDeviceRecord(updated);
    final idx = _devices.indexWhere((d) => d.deviceId == updated.deviceId);
    if (idx != -1) {
      _devices[idx] = updated;
      if (_selectedDeviceId == updated.deviceId) {
        _selectedDevice = updated;
      }
      notifyListeners();
    }
  }

  Future<void> addDevice(Device newDev) async {
    await _apiService.createDevice(newDev);
    _devices.add(newDev);
    notifyListeners();
    selectDevice(newDev.deviceId);
  }

  void acknowledgeAlert(String alertId) {
    final idx = _alerts.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      _alerts[idx] = _alerts[idx].copyWith(
        status: AlertStatus.acknowledged,
        acknowledgedBy: FirebaseAuth.instance.currentUser?.email ?? 'unknown',
      );
      notifyListeners();
    }
  }
}
