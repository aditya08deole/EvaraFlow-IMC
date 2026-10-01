import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evara_flow_dash/providers/device_provider.dart';
import 'package:evara_flow_dash/services/api_service.dart';
import 'package:evara_flow_dash/screens/main_layout.dart';
import 'package:evara_flow_dash/theme/app_theme.dart';

void main() {
  testWidgets('EvaraFlow dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DeviceProvider(
          enableLiveSimulation: false,
          apiService: ApiService(useMockFixtures: true, simulateLatency: false),
        ),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainLayout(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MainLayout), findsOneWidget);
  });
}
