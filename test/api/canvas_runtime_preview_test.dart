import 'package:test/test.dart';

import '../support/flutter_consumer_test_harness.dart';

void main() {
  test(
    'CanvasRuntime exposes a read-only default preview',
    () => expectLater(
      runFlutterConsumerTest(
        packageName: 'iwb_canvas_engine_runtime_preview_consumer',
        testFileName: 'runtime_preview_test.dart',
        testSource: _source,
      ),
      completes,
    ),
  );
}

const _source = r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

CanvasRuntimeConfig _acceptDeletionRuntimeConfig() {
  return CanvasRuntimeConfig(
    commitResolver: _acceptCommit,
  );
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

final class _CommitLease implements CanvasCommitLease {
  const _CommitLease();
  @override
  void aborted() {}
  @override
  void committed() {}
}

void main() {
  test('preview is readable and remains default', () {
    final runtime = CanvasRuntime(config: _acceptDeletionRuntimeConfig());
    addTearDown(runtime.dispose);

    expect(runtime.preview, isA<CanvasNoPreview>());
    expect(runtime.preview.kind, CanvasPreviewKind.none);
    expect(runtime.state.value.revisions.preview, 0);

    runtime.selection.clearSelection();

    expect(runtime.preview, isA<CanvasNoPreview>());
    expect(runtime.state.value.revisions.preview, 0);
  });
}
''';
