import 'package:flutter/material.dart';

import 'emberlink/relay_coordinator.dart';
import 'screens/loading_screen.dart';

class PyrofallRidgeApp extends StatelessWidget {
  const PyrofallRidgeApp({super.key, this.coordinator});

  final RelayCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pyrofall Ridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1420),
      ),
      home: LoadingScreen(coordinator: coordinator),
    );
  }
}
