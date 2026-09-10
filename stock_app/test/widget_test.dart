import 'package:flutter_test/flutter_test.dart';
import 'package:stock_app/main.dart';

void main() {
  testWidgets('Stock app renders splash', (WidgetTester tester) async {
    await tester.pumpWidget(const StockApp());
    await tester.pump();
    expect(find.text('STOCK'), findsOneWidget);
  });
}