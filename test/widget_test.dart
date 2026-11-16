import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifesync_tracker/main.dart';
import 'package:lifesync_tracker/services/app_time_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LifeSyncApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(LifeSyncApp), findsOneWidget);

    AppTimeService.instance.stopMinuteTicker();
  });
}
