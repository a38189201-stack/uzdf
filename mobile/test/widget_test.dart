import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('SkyCheck app runs', (WidgetTester tester) async {
    await tester.pumpWidget(const SkyCheckApp());
    expect(find.byType(SkyCheckApp), findsOneWidget);
  });
}
