import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('schema v1 decoder consumes the canonical reader seam', () {
    final source = File(
      'lib/src/codec/schema_v1_decoder.dart',
    ).readAsStringSync();

    expect(source, isNotEmpty);
    expect(source, contains(RegExp(r"import 'schema_v1_reader\.dart';")));
    expect(source, contains(RegExp(r'readSchemaV1Document\(')));
    expect(source, contains(RegExp(r'readSchemaV1DocumentFromJson\(')));
    _expectNoIndependentSchemaTraversal(source);
  });
}

void _expectNoIndependentSchemaTraversal(String source) {
  expect(source, isNot(contains("import 'dart:convert';")));
  expect(source, isNot(contains('jsonDecode')));
  expect(source, isNot(contains('validateRawJsonLength')));
  expect(source, isNot(contains('validateSchemaV1Root')));
  expect(source, isNot(contains(RegExp(r'_read[A-Za-z0-9_]*\('))));
  expect(source, isNot(contains(RegExp(r'_read[A-Za-z0-9_]*\s*\{'))));
  expect(source, isNot(contains(RegExp(r'_read[A-Za-z0-9_]*\s*=>'))));
  expect(source, isNot(contains(RegExp(r'''map\[['"]kind['"]\]'''))));
  expect(
    source,
    isNot(
      contains(
        RegExp(
          r'''json\[['"](?:resources|layers|backgroundLayer|camera|background|palette|metadata)['"]\]''',
        ),
      ),
    ),
  );
  expect(source, isNot(contains('List<Object?> _')));
  expect(source, isNot(contains('Map<String, Object?> _')));
}
