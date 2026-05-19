import 'package:test/test.dart';

import '../../tool/guardrails/src/diagram_checks.dart';

void main() {
  test('P0 required diagrams are cataloged and present', () {
    expect(checkRequiredDiagramsPresent(), isEmpty);
  });
}
