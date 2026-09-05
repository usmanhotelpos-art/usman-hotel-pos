import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nashta_app/api.dart';
import 'package:nashta_app/order_taker_screen.dart';

void main() {
  testWidgets('OrderTakerScreen initial build', (tester) async {
    ApiClient.host = 'http://127.0.0.1:9';
    await tester.pumpWidget(
      MaterialApp(
        home: OrderTakerScreen(
          token: 'dummy.token.value',
          user: <String, dynamic>{'role': 'Order Taker', 'name': 'Test'},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
