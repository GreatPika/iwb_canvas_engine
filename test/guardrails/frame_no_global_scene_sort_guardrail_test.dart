import 'package:test/test.dart';

import '../../tool/guardrails/src/frame_cache_guardrail_checks.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  _registerRunnerBackedTest();
  _registerRejectedSortFixtures();
  _registerRejectedCrossFileHelperFixtures();
  _registerAllowedSortFixture();
}

void _registerRunnerBackedTest() {
  test('global scene sort guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'frame.no_global_scene_sort',
        suites: {'blocking', 'frame'},
        proofPaths: [
          'test/frame/selected_supplement_staging_no_global_sort_test.dart',
        ],
      ),
      isTrue,
    );
  });
}

void _registerRejectedSortFixtures() {
  for (final fixture in _forbiddenSortFixtures) {
    test('${fixture.label} sort fixture is rejected structurally', () async {
      final violations = _sceneSortViolations(fixture.source);

      expect(_sceneSortGuardrailIds(violations), {
        'frame.no_global_scene_sort',
      });
      expect(await _sceneSortViolationsAreRunnerRejected(violations), isTrue);
    });
  }
}

void _registerRejectedCrossFileHelperFixtures() {
  for (final fixture in _crossFileHelperFixtures) {
    test('${fixture.label} fixture is rejected structurally', () async {
      final violations = checkFrameNoGlobalSceneSortSources({
        'lib/src/frame/order_token_comparator.dart': fixture.helperSource,
        'lib/src/frame/bad_selected_supplement.dart': fixture.consumerSource,
      });

      expect(_sceneSortGuardrailIds(violations), {
        'frame.no_global_scene_sort',
      });
      expect(await _sceneSortViolationsAreRunnerRejected(violations), isTrue);
    });
  }
}

const _crossFileHelperFixtures = [
  (
    label: 'cross-file comparator helper',
    helperSource: '''
int compareByOrderToken(dynamic left, dynamic right) {
  return left.orderToken.compareTo(right.orderToken);
}
''',
    consumerSource: '''
void bad(List<dynamic> records) {
  records.sort(compareByOrderToken);
}
''',
  ),
  (
    label: 'import-aliased cross-file comparator helper',
    helperSource: '''
int compareByOrderToken(dynamic left, dynamic right) {
  return left.orderToken.compareTo(right.orderToken);
}
''',
    consumerSource: '''
import 'order_token_comparator.dart' as order;

void bad(List<dynamic> records) {
  records.sort(order.compareByOrderToken);
}
''',
  ),
  (
    label: 'cross-file static comparator helper',
    helperSource: '''
class OrderTokenComparators {
  static int compare(dynamic left, dynamic right) {
    return left.orderToken.compareTo(right.orderToken);
  }
}
''',
    consumerSource: '''
void bad(List<dynamic> records) {
  records.sort(OrderTokenComparators.compare);
}
''',
  ),
  (
    label: 'import-aliased cross-file static comparator helper',
    helperSource: '''
class OrderTokenComparators {
  static int compare(dynamic left, dynamic right) {
    return left.orderToken.compareTo(right.orderToken);
  }
}
''',
    consumerSource: '''
import 'order_token_comparator.dart' as order;

void bad(List<dynamic> records) {
  records.sort(order.OrderTokenComparators.compare);
}
''',
  ),
  (
    label: 'cross-file comparator instance helper',
    helperSource: '''
class OrderTokenComparators {
  int compare(dynamic left, dynamic right) {
    return left.orderToken.compareTo(right.orderToken);
  }
}
''',
    consumerSource: '''
void bad(List<dynamic> records) {
  final OrderTokenComparators comparators = OrderTokenComparators();
  records.sort(comparators.compare);
}
''',
  ),
  (
    label: 'constructor-inferred comparator instance',
    helperSource: '''
class OrderTokenComparators {
  int compare(dynamic left, dynamic right) {
    return left.orderToken.compareTo(right.orderToken);
  }
}
''',
    consumerSource: '''
void bad(List<dynamic> records) {
  final comparators = OrderTokenComparators();
  records.sort(comparators.compare);
}
''',
  ),
  (
    label: 'constructor-expression comparator instance',
    helperSource: '''
class OrderTokenComparators {
  int compare(dynamic left, dynamic right) {
    return left.orderToken.compareTo(right.orderToken);
  }
}
''',
    consumerSource: '''
void bad(List<dynamic> records) {
  records.sort(OrderTokenComparators().compare);
}
''',
  ),
];

void _registerAllowedSortFixture() {
  test('non-scene local sort fixture is allowed structurally', () {
    final violations = checkFrameNoGlobalSceneSortSources({
      'lib/src/frame/local_debug_order.dart': '''
void ok(List<String> labels, List<int> counts) {
  labels.sort();
  counts.sort((left, right) => left.compareTo(right));
}
''',
    });

    expect(violations, isEmpty);
  });

  test('local scalar comparator with colliding helper name is allowed', () {
    final violations = checkFrameNoGlobalSceneSortSources({
      'lib/src/frame/order_token_comparator.dart': '''
int compareByOrderToken(dynamic left, dynamic right) {
  return left.orderToken.compareTo(right.orderToken);
}
''',
      'lib/src/frame/local_debug_order.dart': '''
void sortLabels(List<String> labels) {
  int compareByOrderToken(String left, String right) {
    return left.compareTo(right);
  }

  labels.sort(compareByOrderToken);
}
''',
    });

    expect(violations, isEmpty);
  });

  test(
    'local scalar class comparator with colliding helper name is allowed',
    () {
      final violations = checkFrameNoGlobalSceneSortSources({
        'lib/src/frame/order_token_comparator.dart': '''
class OrderTokenComparators {
  int compare(dynamic left, dynamic right) {
    return left.orderToken.compareTo(right.orderToken);
  }
}
''',
        'lib/src/frame/local_debug_order.dart': '''
class OrderTokenComparators {
  int compare(String left, String right) {
    return left.compareTo(right);
  }
}

void sortLabels(List<String> labels) {
  labels.sort(OrderTokenComparators().compare);
}
''',
      });

      expect(violations, isEmpty);
    },
  );

  test(
    'local scalar comparator parameter with colliding helper name is allowed',
    () {
      final violations = checkFrameNoGlobalSceneSortSources({
        'lib/src/frame/order_token_comparator.dart': '''
int compareByOrderToken(dynamic left, dynamic right) {
  return left.orderToken.compareTo(right.orderToken);
}
''',
        'lib/src/frame/local_debug_order.dart': '''
void sortLabels(
  List<String> labels,
  int Function(String left, String right) compareByOrderToken,
) {
  labels.sort(compareByOrderToken);
}
''',
      });

      expect(violations, isEmpty);
    },
  );
}

const _forbiddenSortFixtures = [
  (
    label: 'inline order-token',
    source: '''
void bad(List<dynamic> records) {
  records.sort((a, b) => a.orderToken.compareTo(b.orderToken));
}
''',
  ),
  (
    label: 'multi-line comparator',
    source: '''
void bad(List<dynamic> records) {
  records.sort(
    (left, right) {
      return left.orderToken.compareTo(right.orderToken);
    },
  );
}
''',
  ),
  (
    label: 'cascade order-token',
    source: '''
void bad(List<dynamic> records) {
  records..sort((left, right) => left.orderToken.compareTo(right.orderToken));
}
''',
  ),
  (
    label: 'named comparator helper',
    source: '''
int compareByOrderToken(dynamic left, dynamic right) {
  return left.orderToken.compareTo(right.orderToken);
}

void bad(List<dynamic> records) {
  records.sort(compareByOrderToken);
}
''',
  ),
  (
    label: 'wrapped named comparator helper',
    source: '''
int compareByOrderToken(dynamic left, dynamic right) {
  return left.orderToken.compareTo(right.orderToken);
}

void bad(List<dynamic> records) {
  records.sort((left, right) => compareByOrderToken(left, right));
}
''',
  ),
  (
    label: 'variable comparator helper',
    source: '''
void bad(List<dynamic> records) {
  final compareByOrderToken = (dynamic left, dynamic right) {
    return left.orderToken.compareTo(right.orderToken);
  };
  records.sort(compareByOrderToken);
}
''',
  ),
  (
    label: 'record stream order-token',
    source: '''
void bad(List<({int orderToken, Object record})> records) {
  records.sort((left, right) {
    return left.orderToken.compareTo(right.orderToken);
  });
}
''',
  ),
  (
    label: 'renamed stream',
    source: '''
void bad(List<dynamic> rows) {
  rows.sort((a, b) => a.orderToken.compareTo(b.orderToken));
}
''',
  ),
  (
    label: 'order-token projection stream',
    source: '''
void bad(List<dynamic> records) {
  final keyed = records
      .map((record) => (sortKey: record.orderToken, record: record))
      .toList();
  keyed.sort((left, right) => left.sortKey.compareTo(right.sortKey));
}
''',
  ),
  (
    label: 'order-token projection cascade stream',
    source: '''
void bad(List<dynamic> records) {
  final keyed = records
      .map((record) => (sortKey: record.orderToken, record: record))
      .toList();
  keyed..sort((left, right) => left.sortKey.compareTo(right.sortKey));
}
''',
  ),
  (
    label: 'order-token projection fluent cascade stream',
    source: '''
void bad(List<dynamic> records) {
  records
      .map((record) => (sortKey: record.orderToken, record: record))
      .toList()
    ..sort((left, right) => left.sortKey.compareTo(right.sortKey));
}
''',
  ),
  (
    label: 'split order-token projection stream',
    source: '''
void bad(List<dynamic> records) {
  final keyed = records
      .map((record) => (sortKey: record.orderToken, record: record));
  final keyedList = keyed.toList();
  keyedList.sort((left, right) => left.sortKey.compareTo(right.sortKey));
}
''',
  ),
  (
    label: 'order-token projection list literal stream',
    source: '''
void bad(List<dynamic> records) {
  final keyed = [
    for (final record in records) (sortKey: record.orderToken, record: record),
  ];
  keyed.sort((left, right) => left.sortKey.compareTo(right.sortKey));
}
''',
  ),
];

List<GuardrailViolation> _sceneSortViolations(String source) {
  return checkFrameNoGlobalSceneSortSources({
    'lib/src/frame/bad_selected_supplement.dart': source,
  });
}

Set<String> _sceneSortGuardrailIds(List<GuardrailViolation> violations) {
  return violations.map((violation) => violation.guardrailId).toSet();
}

Future<bool> _sceneSortViolationsAreRunnerRejected(
  List<GuardrailViolation> violations,
) {
  return guardrailRejectsStructuralViolations(
    id: 'frame.no_global_scene_sort',
    violations: violations,
  );
}
