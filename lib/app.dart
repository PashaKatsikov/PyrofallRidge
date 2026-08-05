import 'package:flutter/material.dart';

import 'screens/loading_screen.dart';

class PyrofallRidgeApp extends StatelessWidget {
  const PyrofallRidgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pyrofall Ridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1420),
      ),
      home: const LoadingScreen(),
    );
  }
}
