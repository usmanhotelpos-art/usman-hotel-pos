import 'package:flutter_test/flutter_test.dart';
import 'package:nashta_app/main.dart';

void main() {
  testWidgets('full app boot flow', (tester) async {
    await tester.pumpWidget(const NashtaApp());
    // drive splash animation + decide (1.2s + 400ms) and a bit more
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  });
}
