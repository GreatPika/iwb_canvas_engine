import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine_example/perf/performance_fixtures.dart';

void main() {
  _registerValidationFixtureTest();
  _registerBatchFixtureTest();
}

void _registerValidationFixtureTest() {
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

void _registerBatchFixtureTest() {
  test('batch performance fixtures express their declared workload', () {
    final eraserDocument = performanceEraserDeletionBatchDocument();
    final contextDocument = performanceContextRequestBatchDocument();
    final runtime = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
    addTearDown(runtime.dispose);

    expect(
      performanceElementCount(eraserDocument),
      performanceEraserDeletionBatchCount,
    );
    expect(performanceElementCount(contextDocument), 0);
    expect(
      () => runtime.edits.loadDocumentFromJson(
        performanceFixtureJson(eraserDocument),
      ),
      returnsNormally,
    );
  });
}

const _commitLease = _CommitLease();

CanvasCommitResolution _acceptCommit(CanvasCommitRequest request) =>
    switch (request) {
      CanvasMoveCommitRequest(:final proposedDelta) => CanvasMoveCommitAccept(
        delta: proposedDelta,
        lease: _commitLease,
      ),
      _ => const CanvasCommitAccept(lease: _commitLease),
    };

CanvasRuntimeConfig _acceptDeletionRuntimeConfig() =>
    const CanvasRuntimeConfig(commitResolver: _acceptCommit);

final class _CommitLease implements CanvasCommitLease {
  const _CommitLease();

  @override
  void aborted() => _ignoreLeaseOutcome();

  @override
  void committed() => _ignoreLeaseOutcome();
}

void _ignoreLeaseOutcome() => Object.hash(null, null);
