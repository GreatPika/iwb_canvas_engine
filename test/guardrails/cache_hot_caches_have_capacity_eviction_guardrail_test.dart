import 'package:test/test.dart';

import '../../tool/guardrails/src/frame_cache_guardrail_checks.dart';
import '../../tool/guardrails/src/guardrail_violation.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  test('hot cache capacity guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'cache.hot_caches_have_capacity_eviction',
        suites: {'blocking', 'cache'},
        proofPaths: ['test/frame/cache_capacity_eviction_policy_test.dart'],
      ),
      isTrue,
    );
  });

  test('hot cache without capacity fixture is rejected structurally', () async {
    expect(
      await _hotCacheFixtureIsRejected(
        'final class BadHotCache extends FrameLruCache<Object, Object> {}',
      ),
      isTrue,
    );
  });

  test('one good cache does not hide a bad cache in the same file', () async {
    final violations = _hotCacheViolations('''
final class GoodHotCache extends FrameLruCache<Object, Object> {
  GoodHotCache() : super(capacity: 4);
}
final class BadHotCache extends FrameLruCache<Object, Object> {}
''');

    expect(_hotCacheGuardrailIds(violations), {
      'cache.hot_caches_have_capacity_eviction',
    });
    expect(violations.single.message, contains('BadHotCache'));
    expect(await _hotCacheViolationsAreRunnerRejected(violations), isTrue);
  });
}

Future<bool> _hotCacheFixtureIsRejected(String source) async {
  final violations = _hotCacheViolations(source);

  return _hotCacheGuardrailIds(
        violations,
      ).contains('cache.hot_caches_have_capacity_eviction') &&
      await _hotCacheViolationsAreRunnerRejected(violations);
}

List<GuardrailViolation> _hotCacheViolations(String source) {
  return checkCacheHotCachesHaveCapacityEvictionSources({
    'lib/src/frame/bad_hot_cache.dart': source,
  });
}

Set<String> _hotCacheGuardrailIds(List<GuardrailViolation> violations) {
  return violations.map((violation) => violation.guardrailId).toSet();
}

Future<bool> _hotCacheViolationsAreRunnerRejected(
  List<GuardrailViolation> violations,
) {
  return guardrailRejectsStructuralViolations(
    id: 'cache.hot_caches_have_capacity_eviction',
    violations: violations,
  );
}
