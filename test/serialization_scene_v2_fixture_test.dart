import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/advanced.dart';

void main() {
  test('scene_v2.json round-trip is stable', () {
    final raw = File('test/fixtures/scene_v2.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final decoded = decodeScene(json);
    final encoded = encodeScene(decoded);

    expect(encoded, json);
  });
}
