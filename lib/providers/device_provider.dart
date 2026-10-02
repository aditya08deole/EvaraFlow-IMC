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

  DeviceProvider({ApiService? apiService})
    : _apiService = apiService ?? ApiService() {
    init();
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
        orgId: 'org-001',
        name: deviceId,
        location: 'Unknown',
        mqttTopic: 'evaraflow/org-001/$deviceId/telemetry',
        driveMatchKey: '${deviceId}_',
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

    // Load data for the new device with device ID guard
    _loadDeviceDashboardData(deviceId);
  }

  Future<void> _loadDeviceDashboardData(String deviceId) async {
    try {
      // Pipeline A: Readings
      final latest = await _apiService.getLatestReading(deviceId);
      final historical = await _apiService.getHistoricalReadings(
        deviceId,
        range: _selectedRange,
      );

      // Rule 4: Guard by device ID (ignore late response if user switched away)
      if (_selectedDeviceId != deviceId) return;

      _latestReading = latest;
      _historicalReadings = historical;
      _isDashboardLoading = false;
      notifyListeners();
    } catch (e) {
      if (_selectedDeviceId != deviceId) return;
      _dashboardError = 'Unable to retrieve device telemetry data.';
      _isDashboardLoading = false;
      notifyListeners();
    }

    try {
      // Pipeline B: Images
      final latestImg = await _apiService.getLatestImage(deviceId);
      final gallery = await _apiService.getDeviceImages(deviceId);

      if (_selectedDeviceId != deviceId) return;

      _latestImage = latestImg;
      _deviceImages = gallery;
      _isImagesLoading = false;
      notifyListeners();
    } catch (e) {
      if (_selectedDeviceId != deviceId) return;
      _imagesError = 'Unable to retrieve Google Drive images.';
      _isImagesLoading = false;
      notifyListeners();
    }
  }

  void setRange(String range) {
    if (_selectedRange == range) return;
    _selectedRange = range;
    _tablePage = 1;
    if (_selectedDeviceId != null) {
      _isDashboardLoading = true;
      notifyListeners();
      _loadDeviceDashboardData(_selectedDeviceId!);
    }
  }

  void setTablePage(int page) {
    _tablePage = page.clamp(1, totalTablePages);
    notifyListeners();
  }

  void updateDevice(Device updated) {
    final idx = _devices.indexWhere((d) => d.deviceId == updated.deviceId);
    if (idx != -1) {
      _devices[idx] = updated;
      if (_selectedDeviceId == updated.deviceId) {
        _selectedDevice = updated;
      }
      notifyListeners();
    }
  }

  void addDevice(Device newDev) {
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
