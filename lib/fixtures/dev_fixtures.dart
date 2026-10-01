import '../models/device.dart';
import '../models/reading.dart';
import '../models/image_record.dart';
import '../models/alert.dart';

/// Separated development fixtures for UI testing and local development.
/// TR-6: Sample data lives only in this separated fixture file.
class DevFixtures {
  static final List<Device> sampleDevices = [
    Device(
      deviceId: 'EF-001',
      orgId: 'org-evaratech-01',
      name: 'Main Inlet Flow Meter',
      location: 'Building A - Utility Basement',
      mqttTopic: 'evaraflow/org-evaratech-01/EF-001/telemetry',
      driveMatchKey: 'EF-001_',
      expectedIntervalSeconds: 300,
      consumptionMethod: ConsumptionMethod.totalizer,
      status: DeviceStatus.online,
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 2)),
      firmwareVersion: '1.4.2',
    ),
    Device(
      deviceId: 'EF-002',
      orgId: 'org-evaratech-01',
      name: 'Cooling Tower Return',
      location: 'HVAC Plant Room - Roof Level',
      mqttTopic: 'evaraflow/org-evaratech-01/EF-002/telemetry',
      driveMatchKey: 'EF-002_',
      expectedIntervalSeconds: 300,
      consumptionMethod: ConsumptionMethod.totalizer,
      status: DeviceStatus.online,
      lastSeenAt: DateTime.now().subtract(const Duration(seconds: 45)),
      firmwareVersion: '1.4.2',
    ),
    Device(
      deviceId: 'EF-003',
      orgId: 'org-evaratech-01',
      name: 'Process Water Feed Line',
      location: 'Block B - Production Floor 1',
      mqttTopic: 'evaraflow/org-evaratech-01/EF-003/telemetry',
      driveMatchKey: 'EF-003_',
      expectedIntervalSeconds: 300,
      consumptionMethod: ConsumptionMethod.integratedFlow,
      status: DeviceStatus.offline,
      lastSeenAt: DateTime.now().subtract(
        const Duration(hours: 4, minutes: 12),
      ),
      firmwareVersion: '1.3.9',
    ),
    Device(
      deviceId: 'EF-004',
      orgId: 'org-evaratech-01',
      name: 'Wastewater Discharge Meter',
      location: 'STP Plant - Treatment Outlet',
      mqttTopic: 'evaraflow/org-evaratech-01/EF-004/telemetry',
      driveMatchKey: 'EF-004_',
      expectedIntervalSeconds: 600,
      consumptionMethod: ConsumptionMethod.totalizer,
      status: DeviceStatus.noData,
      lastSeenAt: null,
      firmwareVersion: '1.4.0',
    ),
    Device(
      deviceId: 'EF-005',
      orgId: 'org-evaratech-01',
      name: 'RO Booster Pump Discharge',
      location: 'Water Treatment Plant 2',
      mqttTopic: 'evaraflow/org-evaratech-01/EF-005/telemetry',
      driveMatchKey: 'EF-005_',
      expectedIntervalSeconds: 300,
      consumptionMethod: ConsumptionMethod.totalizer,
      status: DeviceStatus.online,
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 1)),
      firmwareVersion: '1.4.2',
    ),
  ];

  static List<Reading> generateSampleReadings(
    String deviceId, {
    int count = 48,
  }) {
    final now = DateTime.now();
    final List<Reading> readings = [];
    double baseTotal = 4820.0;

    for (int i = count - 1; i >= 0; i--) {
      final ts = now.subtract(Duration(minutes: i * 15));
      // Simulate realistic diurnal flow pattern (higher in morning & afternoon)
      final hour = ts.hour;
      final double wave = (hour >= 8 && hour <= 18) ? 14.5 : 4.2;
      final double noise = (i % 5) * 0.7 - 1.2;
      final double flow = (wave + noise).clamp(0.0, 35.0);

      baseTotal += (flow * 15); // 15 minutes total flow

      readings.add(
        Reading(
          deviceId: deviceId,
          deviceTs: ts,
          receivedAt: ts.add(const Duration(seconds: 2)),
          flowLpm: double.parse(flow.toStringAsFixed(1)),
          totalL: double.parse(baseTotal.toStringAsFixed(1)),
          sensorStatus: 'ok',
          firmwareVersion: '1.4.2',
        ),
      );
    }
    return readings;
  }

  static List<ImageRecord> generateSampleImages(String deviceId) {
    final now = DateTime.now();
    // High-resolution real industrial water flow meter images for realistic UI preview
    final imageUrls = [
      'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&q=80',
      'https://images.unsplash.com/photo-1581092335397-9583fe92d232?w=800&q=80',
      'https://images.unsplash.com/photo-1581092580497-e0d23cbdf1dc?w=800&q=80',
      'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800&q=80',
    ];

    return [
      ImageRecord(
        id: 'img-101',
        deviceId: deviceId,
        driveFileId: '1A2b3C4d5E6f_001',
        fileName: '${deviceId}_20260929T163000.jpg',
        capturedAt: now.subtract(const Duration(hours: 2, minutes: 15)),
        receivedAt: now.subtract(const Duration(hours: 2, minutes: 14)),
        storageUrl: imageUrls[0],
        thumbnailUrl: imageUrls[0],
        syncStatus: 'synced',
      ),
      ImageRecord(
        id: 'img-102',
        deviceId: deviceId,
        driveFileId: '1A2b3C4d5E6f_002',
        fileName: '${deviceId}_20260929T120000.jpg',
        capturedAt: now.subtract(const Duration(hours: 6, minutes: 45)),
        receivedAt: now.subtract(const Duration(hours: 6, minutes: 43)),
        storageUrl: imageUrls[1],
        thumbnailUrl: imageUrls[1],
        syncStatus: 'synced',
      ),
      ImageRecord(
        id: 'img-103',
        deviceId: deviceId,
        driveFileId: '1A2b3C4d5E6f_003',
        fileName: '${deviceId}_20260928T180000.jpg',
        capturedAt: now.subtract(const Duration(hours: 24, minutes: 10)),
        receivedAt: now.subtract(const Duration(hours: 24, minutes: 8)),
        storageUrl: imageUrls[2],
        thumbnailUrl: imageUrls[2],
        syncStatus: 'synced',
      ),
      ImageRecord(
        id: 'img-104',
        deviceId: deviceId,
        driveFileId: '1A2b3C4d5E6f_004',
        fileName: '${deviceId}_20260927T093000.jpg',
        capturedAt: now.subtract(const Duration(hours: 56)),
        receivedAt: now.subtract(const Duration(hours: 55, minutes: 58)),
        storageUrl: imageUrls[3],
        thumbnailUrl: imageUrls[3],
        syncStatus: 'synced',
      ),
    ];
  }

  static List<AlertItem> sampleAlerts = [
    AlertItem(
      id: 'alt-001',
      deviceId: 'EF-003',
      deviceName: 'Process Water Feed Line',
      type: AlertType.deviceOffline,
      severity: 'critical',
      status: AlertStatus.newAlert,
      description: 'Device stopped reporting telemetry. Last seen 4 hours ago.',
      openedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    AlertItem(
      id: 'alt-002',
      deviceId: 'EF-001',
      deviceName: 'Main Inlet Flow Meter',
      type: AlertType.highFlow,
      severity: 'warning',
      status: AlertStatus.acknowledged,
      description:
          'Instantaneous flow rate reached 34.2 L/min (threshold: 30.0 L/min)',
      openedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
      acknowledgedBy: 'admin@evaratech.com',
    ),
  ];
}
