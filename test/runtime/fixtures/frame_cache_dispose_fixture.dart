import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
  test(
    'RuntimeRoot dispose releases frame-owned static background picture',
    () {
      final root = runtimeRootWithCommittedDocumentSeed(
        CanvasDocument(),
        config: const CanvasRuntimeConfig(
          deletionCommitResolver: _acceptDeletionCommit,
        ),
      );
      final output = root.buildResourceFreeMainFrame(
        viewportWorldBounds: const Rect.fromLTWH(0, 0, 100, 100),
        devicePixelRatio: 1,
        selectionStyle: CanvasSelectionStyle.defaultStyle,
        gridStyle: CanvasGridStyle.defaultStyle,
      );

      expect(output.staticBackgroundPlan.picture.isDisposed, isFalse);

      root.dispose();
      root.dispose();

      expect(output.staticBackgroundPlan.picture.isDisposed, isTrue);
    },
  );
}

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;
