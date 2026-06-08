import 'package:test/test.dart';

import '../../tool/guardrails/src/frame_cache_guardrail_checks.dart';
import 'fixtures/runner_backed_guardrail_test_support.dart';

void main() {
  _registerRunnerProof();
  _registerFieldAllowlistProofs();
  _registerFieldSyntaxBypassProofs();
  _registerAcceptedKeyShapeProofs();
}

void _registerRunnerProof() {
  test('cache key revision guardrail is runner-backed', () async {
    expect(
      await guardrailIsRunnerBacked(
        id: 'cache.keys_use_next_revisions_only',
        suites: {'blocking', 'cache'},
        proofPaths: ['test/frame/cache_keys_use_current_revisions_test.dart'],
      ),
      isTrue,
    );
  });
}

void _registerFieldAllowlistProofs() {
  test(
    'ordinary paint plan key non-owned revision fixture is rejected',
    () async {
      expect(
        await _cacheKeyFixtureIsRejected(
          'final class PaintPlanKey { final int documentRevision; const PaintPlanKey(this.documentRevision); }',
        ),
        isTrue,
      );
    },
  );

  test('ordinary record key resource revision fixture is rejected', () async {
    expect(
      await _cacheKeyFixtureIsRejected(
        'final class OrdinaryPaintRecordKey { final int resourceRevision; const OrdinaryPaintRecordKey(this.resourceRevision); }',
      ),
      isTrue,
    );
  });

  test('ordinary key forbidden constructor token fixture is rejected', () async {
    expect(
      await _cacheKeyFixtureIsRejected(
        'final class PaintPlanKey { final int structuralRevision; const PaintPlanKey({required int documentRevision}) : structuralRevision = documentRevision; }',
      ),
      isTrue,
    );
  });
}

void _registerFieldSyntaxBypassProofs() {
  test('multi-field ordinary key fixture is rejected structurally', () async {
    expect(
      await _cacheKeyFixtureIsRejected(
        'final class PaintPlanKey { final int structuralRevision, documentRevision; const PaintPlanKey(this.structuralRevision, this.documentRevision); }',
      ),
      isTrue,
    );
  });

  test('complex typed ordinary key fixture is rejected structurally', () async {
    expect(
      await _cacheKeyFixtureIsRejected(
        'final class PaintPlanKey { final Map<String, int> documentRevision; const PaintPlanKey(this.documentRevision); }',
      ),
      isTrue,
    );
  });
}

void _registerAcceptedKeyShapeProofs() {
  test('ordinary cache key allowlist fixture is accepted', () {
    final violations = checkCacheKeysUseNextRevisionsOnlySources({
      'lib/src/frame/paint_plan.dart': '''
final class PaintPlanKey {
  final int structuralRevision;
  final int boundsRevision;
  final int elementVisualRevision;
  final Object viewportRect;
  final double devicePixelRatio;
  const PaintPlanKey(this.structuralRevision, this.boundsRevision, this.elementVisualRevision, this.viewportRect, this.devicePixelRatio);
}
final class OrdinaryPaintRecordKey {
  final Object id;
  final int structuralRevision;
  final int boundsRevision;
  final int elementVisualRevision;
  final int generation;
  final int orderToken;
  const OrdinaryPaintRecordKey(this.id, this.structuralRevision, this.boundsRevision, this.elementVisualRevision, this.generation, this.orderToken);
}
''',
    });

    expect(violations, isEmpty);
  });

  test('commented forbidden declarations are ignored', () {
    final violations = checkCacheKeysUseNextRevisionsOnlySources({
      'lib/src/frame/paint_plan.dart': '''
final class PaintPlanKey {
  final int structuralRevision;
  const PaintPlanKey(this.structuralRevision);
  // final int resourceRevision;
}
''',
    });

    expect(violations, isEmpty);
  });
}

Future<bool> _cacheKeyFixtureIsRejected(String paintPlanSource) async {
  final violations = checkCacheKeysUseNextRevisionsOnlySources({
    'lib/src/frame/paint_plan.dart': paintPlanSource,
  });
  final guardrailIds = violations
      .map((violation) => violation.guardrailId)
      .toSet();

  return guardrailIds.length == 1 &&
      guardrailIds.contains('cache.keys_use_next_revisions_only') &&
      await guardrailRejectsStructuralViolations(
        id: 'cache.keys_use_next_revisions_only',
        violations: violations,
      );
}
