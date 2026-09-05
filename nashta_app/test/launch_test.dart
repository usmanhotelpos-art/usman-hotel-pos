import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nashta_app/main.dart';
import 'package:nashta_app/login_screen.dart';

void main() {
  testWidgets('SplashScreen builds without throwing', (tester) async {
    await tester.pumpWidget(const NashtaApp());
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('LoginScreen builds without throwing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
