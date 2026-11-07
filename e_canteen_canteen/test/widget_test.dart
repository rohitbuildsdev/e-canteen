import 'package:flutter_test/flutter_test.dart';
import 'package:e_canteen_canteen/main.dart';

void main() {
  testWidgets('Canteen app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const ECanteenCanteenApp());
    await tester.pump();

    expect(find.byType(ECanteenCanteenApp), findsOneWidget);
  });
}
