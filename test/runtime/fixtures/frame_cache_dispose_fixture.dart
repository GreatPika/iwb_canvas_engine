import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import '../../support/runtime_root_with_committed_document_seed.dart';

void main() {
  test(
    'RuntimeRoot dispose releases frame-owned static background picture',
    () {
      final root = runtimeRootWithCommittedDocumentSeed(CanvasDocument());
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
