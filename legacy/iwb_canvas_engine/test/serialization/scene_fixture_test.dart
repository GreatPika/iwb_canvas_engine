import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test('scene.json round-trip is stable', () {
    final raw = File('test/fixtures/scene.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final decoded = decodeScene(json);
    final encoded = encodeScene(decoded);

    expect(encoded, json);
  });
}
