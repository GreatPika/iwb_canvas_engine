import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine_example/perf/performance_fixtures.dart';

void main() {
  test('100k performance fixtures fit current validation limits', () {
    final fixtures = {
      performanceLoadDocument100kFixtureId: performanceRectDocument(100000),
      performanceCameraPan100kFixtureId: performanceRectDocument(100000),
    };

    for (final entry in fixtures.entries) {
      final document = entry.value;
      final json = performanceFixtureJson(document);
      final runtime = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
      addTearDown(runtime.dispose);

      expect(performanceElementCount(document), 100000, reason: entry.key);
      expect(
        () => runtime.edits.loadDocumentFromJson(json),
        returnsNormally,
        reason: entry.key,
      );
    }
  });
}

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;

CanvasRuntimeConfig _acceptDeletionRuntimeConfig() =>
    const CanvasRuntimeConfig(deletionCommitResolver: _acceptDeletionCommit);
