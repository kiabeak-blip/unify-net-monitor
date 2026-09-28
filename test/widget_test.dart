import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitor/main.dart';
import 'package:provider/provider.dart';
import 'package:network_monitor/services/device_manager.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DeviceManager(),
        child: const NetworkMonitorApp(),
      ),
    );
    expect(find.byType(NetworkMonitorApp), findsOneWidget);
  });
}
