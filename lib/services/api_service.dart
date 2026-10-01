import 'dart:async';
import '../models/device.dart';
import '../models/reading.dart';
import '../models/image_record.dart';
import '../models/alert.dart';
import '../fixtures/dev_fixtures.dart';

class ApiService {
  final bool useMockFixtures;
  final bool simulateLatency;

  ApiService({this.useMockFixtures = true, this.simulateLatency = true});

  Future<void> _delay([int ms = 200]) async {
    if (simulateLatency) {
      await Future.delayed(Duration(milliseconds: ms));
    }
  }

  // Fetch all available devices
  Future<List<Device>> getDevices({
    String search = '',
    String statusFilter = 'all',
  }) async {
    if (useMockFixtures) {
      await _delay(100);
      var list = List<Device>.from(DevFixtures.sampleDevices);
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
    throw UnimplementedError('Production API endpoint not configured');
  }

  // Fetch device details
  Future<Device?> getDevice(String deviceId) async {
    if (useMockFixtures) {
      await _delay(50);
      final devices = DevFixtures.sampleDevices;
      return devices.firstWhere(
        (d) => d.deviceId == deviceId,
        orElse: () => devices.first,
      );
    }
    throw UnimplementedError();
  }

  // Fetch latest telemetry reading (Pipeline A - MQTT source)
  Future<Reading?> getLatestReading(String deviceId) async {
    if (useMockFixtures) {
      await _delay(50);
      if (deviceId == 'EF-004') return null;
      final readings = DevFixtures.generateSampleReadings(deviceId, count: 1);
      return readings.isNotEmpty ? readings.last : null;
    }
    throw UnimplementedError();
  }

  // Fetch historical readings time series (Pipeline A - MQTT source)
  Future<List<Reading>> getHistoricalReadings(
    String deviceId, {
    String range = 'Today',
  }) async {
    if (useMockFixtures) {
      await _delay(50);
      if (deviceId == 'EF-004') return [];

      int points = 24;
      if (range == '7 Days') points = 56;
      if (range == '30 Days') points = 120;

      return DevFixtures.generateSampleReadings(deviceId, count: points);
    }
    throw UnimplementedError();
  }

  // Fetch latest image (Pipeline B - Google Drive source)
  Future<ImageRecord?> getLatestImage(String deviceId) async {
    if (useMockFixtures) {
      await _delay(50);
      if (deviceId == 'EF-004' || deviceId == 'EF-005') return null;
      final images = DevFixtures.generateSampleImages(deviceId);
      return images.isNotEmpty ? images.first : null;
    }
    throw UnimplementedError();
  }

  // Fetch image gallery (Pipeline B - Google Drive source)
  Future<List<ImageRecord>> getDeviceImages(String deviceId) async {
    if (useMockFixtures) {
      await _delay(50);
      if (deviceId == 'EF-004' || deviceId == 'EF-005') return [];
      return DevFixtures.generateSampleImages(deviceId);
    }
    throw UnimplementedError();
  }

  // Fetch alerts
  Future<List<AlertItem>> getAlerts() async {
    if (useMockFixtures) {
      await _delay(50);
      return List<AlertItem>.from(DevFixtures.sampleAlerts);
    }
    throw UnimplementedError();
  }
}
