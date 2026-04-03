import 'package:flutter_test/flutter_test.dart';

import 'package:pw_dev/main.dart';
import 'package:pw_dev/src/services/platform_api.dart';

void main() {
  testWidgets('App renders core tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      DeltaCompanionApp(api: MockPlatformApi(), skipAuthGate: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('大厅'), findsWidgets);
    expect(find.text('订单'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('用更少的信息噪声，快速找到合适的房间。'), findsOneWidget);
  });
}
