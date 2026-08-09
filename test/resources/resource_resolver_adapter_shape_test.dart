import 'dart:io';

import 'package:test/test.dart';

void main() {
  _testResourceBoundary();
}

void _testResourceBoundary() {
  test('resource resolver values stay resource-owned', () {
    final source = _adapterSource();
    final forbiddenImports = RegExp(
      r"(\.\./(runtime|store|frame|surface|interaction|diagnostics)/|"
      r"package:iwb_canvas_engine/src/(runtime|store|frame|surface|interaction|diagnostics)|"
      r"package:flutter/|dart:io)",
    );

    expect(source, isNot(matches(forbiddenImports)));
    expect(source, isNot(contains('AssetBundle')));
    expect(source, isNot(contains('File')));
    expect(source, isNot(contains('Network')));
    expect(source, isNot(contains('HttpClient')));
  });
}

String _adapterSource() {
  return File(
    'lib/src/resources/resource_resolver_adapter.dart',
  ).readAsStringSync();
}
