import 'package:test/test.dart';

import '../../tool/guardrails/src/frame_cache_guardrail_checks.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  test('cache key revision guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'cache.keys_use_next_revisions_only',
        suites: {'blocking', 'cache'},
        proofPaths: [
          'test/frame/cache_keys_do_not_use_legacy_snapshot_shape_test.dart',
        ],
      ),
      isTrue,
    );
  });

  test('legacy snapshot cache key fixture is rejected structurally', () async {
    final violations = checkCacheKeysUseNextRevisionsOnlySources({
      'lib/src/frame/bad_cache_key.dart':
          'final class BadCacheKey { final SceneSnapshot snapshot; BadCacheKey(this.snapshot); }',
    });

    expect(violations.map((violation) => violation.guardrailId), {
      'cache.keys_use_next_revisions_only',
    });
    expect(
      await guardrailRejectsStructuralViolations(
        id: 'cache.keys_use_next_revisions_only',
        violations: violations,
      ),
      isTrue,
    );
  });
}
