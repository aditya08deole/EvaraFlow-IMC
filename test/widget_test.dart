import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:evara_flow_dash/models/device.dart';
import 'package:evara_flow_dash/models/reading.dart';
import 'package:evara_flow_dash/theme/app_theme.dart';
import 'package:evara_flow_dash/widgets/brand_mesh_background.dart';

void main() {
  group('EvaraTech Models Unit Tests', () {
    test('Device model instantiates and exposes fields correctly', () {
      final device = Device(
        deviceId: 'EVT_EF_006',
        orgId: 'evaratech',
        name: 'Device EVT_EF_006',
        location: 'IMC Plant Floor',
        mqttTopic: 'devices/EVT_EF_006/telemetry',
        driveMatchKey: 'EVT_EF_006',
        expectedIntervalSeconds: 60,
        consumptionMethod: ConsumptionMethod.totalizer,
        imageSource: ImageSource.drive,
        status: DeviceStatus.online,
        driveFolderId: '1oo-S7tJvDc8EoRRfdkOupdVYRAEOPCNG',
      );

      expect(device.deviceId, 'EVT_EF_006');
      expect(device.orgId, 'evaratech');
      expect(device.name, 'Device EVT_EF_006');
      expect(device.imageSource, ImageSource.drive);
      expect(device.driveFolderId, '1oo-S7tJvDc8EoRRfdkOupdVYRAEOPCNG');
      expect(device.status, DeviceStatus.online);
    });

    test('Reading model computes values properly', () {
      final now = DateTime.now();
      final reading = Reading(
        deviceId: 'EVT_EF_006',
        deviceTs: now,
        receivedAt: now,
        flowLpm: 12.5,
        totalL: 1540.2,
      );

      expect(reading.deviceId, 'EVT_EF_006');
      expect(reading.flowLpm, 12.5);
      expect(reading.totalL, 1540.2);
    });
  });

  group('EvaraTech UI Widget Tests', () {
    testWidgets('BrandMeshBackground renders its child', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: BrandMeshBackground(
              child: Text('EvaraTech Dashboard Test'),
            ),
          ),
        ),
      );

      expect(find.text('EvaraTech Dashboard Test'), findsOneWidget);
    });

    testWidgets('SurfaceCard renders container with decoration', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SurfaceCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      expect(find.byType(SurfaceCard), findsOneWidget);
    });
  });
}
