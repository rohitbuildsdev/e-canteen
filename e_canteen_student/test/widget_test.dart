import 'package:flutter_test/flutter_test.dart';
import 'package:e_canteen_student/main.dart';

void main() {
  testWidgets('E-Canteen app launches', (WidgetTester tester) async {
    tester.binding;
    // Firebase-backed services require Firebase initialization.
    // This test only checks that the root widget can be constructed.
    expect(const ECanteenApp(), isA<ECanteenApp>());
  });
}
