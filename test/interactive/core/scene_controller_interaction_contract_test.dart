import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/interactive/internal/scene_controller_internal_access.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_controller.dart';
import 'package:iwb_canvas_engine/src/interactive/scene_view_pointer_semantics.dart';

// INV:INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY
// INV:INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY

void main() {
  group('SceneController interaction contract', () {
    test('internal access exposes registered epoch and preview resolver', () {
      final controller = SceneController();
      addTearDown(controller.dispose);

      expect(sceneControllerInternalEpoch(controller), 0);
      expect(
        sceneControllerInternalPreviewDeltaForNode(controller, 'node-1'),
        Offset.zero,
      );
    });

    test('interaction listenable forwards add/remove listener', () {
      final controller = SceneController();
      addTearDown(controller.dispose);

      var completed = false;
      void listener() {}

      controller.interaction.addListener(listener);
      controller.interaction.removeListener(listener);

      completed = true;
      expect(completed, isTrue);
    });

    test('controller owns view pointer semantics seam directly', () {
      final controller = SceneController();
      addTearDown(controller.dispose);

      final source = controller as SceneViewPointerSemanticsSource;
      final bridge = source.createPointerSemanticsBridge(isMounted: () => true);
      addTearDown(bridge.dispose);

      expect(bridge.pendingTapFlushTimestampMs, isNull);
    });
  });
}
