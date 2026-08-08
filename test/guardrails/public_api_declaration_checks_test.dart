import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_declaration_checks.dart';

void main() {
  test('dartdoc summary check rejects delimiter-only comments', () {
    for (final comment in _delimiterOnlyDartdoc) {
      expect(hasDartdocSummaryText(comment), isFalse);
    }
    for (final comment in _meaningfulDartdoc) {
      expect(hasDartdocSummaryText(comment), isTrue);
    }
  });

  test('class modifier check rejects abstract-only policy', () {
    expect(hasPublicSubtypePolicyModifier(const []), isFalse);
    expect(hasPublicSubtypePolicyModifier(const [true]), isTrue);
  });
}

const _delimiterOnlyDartdoc = [null, '///', '///   ', '/** */', '/**\n *\n */'];

const _meaningfulDartdoc = ['/// Summary.', '/** Summary. */'];
