// Basic smoke test: the app boots into the loading screen without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ridgegame/app.dart';

void main() {
  testWidgets('App boots and shows the loading screen', (tester) async {
    await tester.pumpWidget(const PyrofallRidgeApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsWidgets);
  });
}
