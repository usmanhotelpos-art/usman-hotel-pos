import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gate.dart';
import 'notify.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await NotifyService.init();
  runApp(const ActiveOrdersApp());
}

class ActiveOrdersApp extends StatelessWidget {
  const ActiveOrdersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Active Orders',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const Gate(),
    );
  }
}
