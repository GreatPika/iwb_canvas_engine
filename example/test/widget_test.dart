// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iwb_canvas_engine_example/main.dart';

void main() {
  testWidgets('Renders canvas example app', (WidgetTester tester) async {
    await tester.pumpWidget(const CanvasExampleApp());

    expect(find.text('IWB Canvas Engine Example'), findsWidgets);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
