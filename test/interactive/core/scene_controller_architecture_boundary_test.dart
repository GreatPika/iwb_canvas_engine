import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _extractMethodBody({
  required String source,
  required String methodStart,
}) {
  final startIndex = source.indexOf(methodStart);
  if (startIndex < 0) {
    throw StateError('Method signature not found: $methodStart');
  }
  var bodyStart = -1;
  var parenDepth = 0;
  for (var i = startIndex; i < source.length; i++) {
    final char = source[i];
    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      if (parenDepth > 0) {
        parenDepth -= 1;
      }
    } else if (char == '{' && parenDepth == 0) {
      bodyStart = i;
      break;
    }
  }
  if (bodyStart < 0) {
    throw StateError('Method body start not found: $methodStart');
  }

  var depth = 1;
  for (var i = bodyStart + 1; i < source.length; i++) {
    final char = source[i];
    if (char == '{') {
      depth += 1;
    } else if (char == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(bodyStart + 1, i);
      }
    }
  }
  throw StateError('Method body end not found: $methodStart');
}

void main() {
  // INV:INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY
  // INV:INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY
  test('SceneController architecture boundary remains structurally split', () {
    final facadeSource = File(
      'lib/src/interactive/scene_controller.dart',
    ).readAsStringSync();
    final interactionSource = File(
      'lib/src/interactive/scene_controller_interaction.dart',
    ).readAsStringSync();
    final facadeAssemblySource = File(
      'lib/src/interactive/internal/scene_controller_facade_assembly.dart',
    ).readAsStringSync();
    final mutationBoundarySource = File(
      'lib/src/interactive/internal/scene_controller_mutation_boundary.dart',
    ).readAsStringSync();
    final eligibilityPolicySource = File(
      'lib/src/interactive/interaction_eligibility_policy.dart',
    ).readAsStringSync();
    final sceneMutationsSource = File(
      'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
    ).readAsStringSync();
    final selectionMutationsSource = File(
      'lib/src/interactive/internal/scene_controller_selection_mutations.dart',
    ).readAsStringSync();
    final selectionActionsSource = File(
      'lib/src/interactive/internal/interactive_selection_actions.dart',
    ).readAsStringSync();
    final runtimeSource = File(
      'lib/src/interactive/internal/interactive_runtime.dart',
    ).readAsStringSync();
    final interactionRuntimeSource = File(
      'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
    ).readAsStringSync();
    final pointerSemanticsSource = File(
      'lib/src/interactive/internal/scene_controller_pointer_semantics.dart',
    ).readAsStringSync();
    final pointerSemanticsContractSource = File(
      'lib/src/interactive/scene_view_pointer_semantics.dart',
    ).readAsStringSync();
    final internalAccessSource = File(
      'lib/src/interactive/internal/scene_controller_internal_access.dart',
    ).readAsStringSync();
    final pointerHostSource = File(
      'lib/src/view/scene_view_interactive_pointer_host.dart',
    ).readAsStringSync();
    final sceneViewInteractiveSource = File(
      'lib/src/view/scene_view_interactive.dart',
    ).readAsStringSync();
    final renderSurfaceSource = File(
      'lib/src/view/scene_view_render_surface.dart',
    ).readAsStringSync();
    final overlayPainterSource = File(
      'lib/src/view/scene_view_interactive_overlay_painter.dart',
    ).readAsStringSync();
    final eventSource = File(
      'lib/src/interactive/internal/interactive_event_dispatcher.dart',
    ).readAsStringSync();
    final drawCoordinatorSource = File(
      'lib/src/interactive/internal/interactive_draw_coordinator.dart',
    ).readAsStringSync();
    final eraserSource = File(
      'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
    ).readAsStringSync();
    final eraserExactHitSource = File(
      'lib/src/interactive/internal/interactive_draw_eraser_exact_hit.dart',
    ).readAsStringSync();
    final eraserLineHitSource = File(
      'lib/src/interactive/internal/interactive_draw_eraser_line_hit.dart',
    ).readAsStringSync();
    final eraserProjectionSource = File(
      'lib/src/interactive/internal/interactive_draw_eraser_projection.dart',
    ).readAsStringSync();
    final eraserStrokeHitSource = File(
      'lib/src/interactive/internal/interactive_draw_eraser_stroke_hit.dart',
    ).readAsStringSync();

    expect(
      facadeSource,
      contains("import 'internal/scene_controller_facade_assembly.dart';"),
    );
    expect(
      facadeSource,
      contains("import 'internal/scene_controller_interaction_runtime.dart';"),
    );
    expect(facadeSource, contains('assembleSceneControllerFacade('));
    expect(facadeSource, contains('SceneControllerFacadeRequest('));
    expect(facadeSource, contains('registerSceneControllerInternalAccess('));
    expect(
      facadeSource,
      contains('SceneControllerInternalAccessRegistration('),
    );
    expect(
      facadeSource,
      contains("import 'scene_view_pointer_semantics.dart';"),
    );
    expect(
      facadeSource,
      contains(
        'implements SceneViewRenderState, SceneViewPointerSemanticsSource',
      ),
    );
    expect(
      facadeSource,
      contains('SceneViewPointerSemanticsBridge createPointerSemanticsBridge('),
    );
    expect(
      facadeSource,
      contains("import 'internal/scene_controller_pointer_semantics.dart';"),
    );
    expect(
      facadeSource,
      contains('return SceneControllerPointerSemantics('),
    );
    expect(
      facadeSource,
      isNot(contains("import 'internal/interactive_runtime.dart';")),
    );
    expect(
      facadeSource,
      isNot(contains("import 'internal/interactive_event_dispatcher.dart';")),
    );
    expect(
      facadeSource,
      isNot(contains("import 'internal/interactive_selection_actions.dart';")),
    );
    expect(facadeSource, isNot(contains('_runtime.handlePointer(')));
    expect(facadeSource, isNot(contains('_runtime.handleDoubleTap(')));

    expect(facadeAssemblySource, contains('SceneControllerInteraction('));
    expect(facadeAssemblySource, contains('SceneControllerSelection('));
    expect(facadeAssemblySource, contains('SceneControllerScene('));
    expect(
      facadeAssemblySource,
      contains('mutations: interactionRuntime.mutationBoundary,'),
    );
    expect(
      facadeAssemblySource,
      isNot(contains('createPointerSemanticsBridge')),
    );
    expect(
      facadeAssemblySource,
      isNot(contains('SceneControllerPointerSemantics(')),
    );

    expect(
      mutationBoundarySource,
      contains('class SceneControllerMutationBoundary'),
    );
    expect(
      mutationBoundarySource,
      contains('core.commands.writeSelectionReplace(nodeIds);'),
    );
    expect(
      mutationBoundarySource,
      contains('core.commands.writeSelectionClear();'),
    );
    expect(
      mutationBoundarySource,
      contains('core.commands.writeDeleteSelection();'),
    );
    expect(
      mutationBoundarySource,
      contains('core.commands.writeSelectionTransform(delta);'),
    );
    expect(
      mutationBoundarySource,
      contains('core.prepareSceneReplacement(snapshot);'),
    );
    expect(
      mutationBoundarySource,
      contains('core.writePreparedSceneReplacement(replacement);'),
    );
    expect(
      mutationBoundarySource,
      isNot(contains('core.writeReplaceScene(snapshot);')),
    );
    expect(mutationBoundarySource, isNot(contains('txnSceneFromSnapshot(')));

    expect(sceneMutationsSource, contains('mutations.setGridCellSize(value);'));
    expect(
      sceneMutationsSource,
      contains(
        'final replacement = mutations.prepareSceneReplacement(snapshot);',
      ),
    );
    expect(
      sceneMutationsSource,
      contains('mutations.replaceScene(replacement);'),
    );
    expect(sceneMutationsSource, isNot(contains('core.commands.')));
    expect(sceneMutationsSource, isNot(contains('core.write(')));
    expect(sceneMutationsSource, isNot(contains('core.writeReplaceScene(')));

    expect(
      eligibilityPolicySource,
      isNot(contains("import '../model/document.dart';")),
    );
    expect(eligibilityPolicySource, isNot(contains('txnNodeFromSnapshot(')));

    expect(
      selectionMutationsSource,
      contains('mutations.setSelection(nodeIds);'),
    );
    expect(
      selectionMutationsSource,
      contains('mutations.deleteSelection(timestampMs: timestampMs);'),
    );
    expect(selectionMutationsSource, isNot(contains('core.commands.')));

    expect(
      selectionActionsSource,
      contains('return mutations.commitMoveSelection(proposedDelta);'),
    );
    expect(selectionActionsSource, isNot(contains('core.commands.')));
    expect(selectionActionsSource, isNot(contains('core.write(')));

    final handlePointerBody = _extractMethodBody(
      source: interactionSource,
      methodStart: 'void handlePointer(CanvasPointerInput input)',
    );
    expect(
      handlePointerBody,
      contains('_access.runtime.handlePointer(input);'),
    );
    expect(handlePointerBody, isNot(contains('_pointerNormalizer')));
    expect(handlePointerBody, isNot(contains('_gestureRouter')));

    final handleDoubleTapBody = _extractMethodBody(
      source: interactionSource,
      methodStart:
          'void handleDoubleTap({required Offset position, int? timestampMs})',
    );
    expect(handleDoubleTapBody, contains('_access.runtime.handleDoubleTap('));
    expect(handleDoubleTapBody, isNot(contains('resolveTimestampMs(')));

    expect(
      runtimeSource,
      contains("import 'interactive_draw_coordinator.dart';"),
    );
    expect(
      runtimeSource,
      contains("import 'interactive_event_dispatcher.dart';"),
    );
    expect(runtimeSource, contains("import 'interactive_move_session.dart';"));
    expect(
      runtimeSource,
      contains("import 'interactive_pointer_normalizer.dart';"),
    );
    expect(
      runtimeSource,
      contains("import 'interactive_gesture_router.dart';"),
    );
    expect(
      runtimeSource,
      contains("import 'interactive_double_tap_router.dart';"),
    );
    expect(
      interactionRuntimeSource,
      contains("import 'scene_controller_mutation_boundary.dart';"),
    );
    expect(
      interactionRuntimeSource,
      contains('writeSelectionReplace: mutationBoundary.setSelection,'),
    );
    expect(
      interactionRuntimeSource,
      contains('commitMoveSelection: mutationBoundary.commitMoveSelection,'),
    );
    expect(
      interactionRuntimeSource,
      contains('writeSelectionClear: mutationBoundary.clearSelection,'),
    );
    expect(
      pointerSemanticsSource,
      contains('class SceneControllerPointerSemantics'),
    );
    expect(pointerSemanticsSource, contains('PointerInputTracker('));
    expect(pointerSemanticsSource, contains('_PendingTapFlushScheduler'));
    expect(
      pointerSemanticsContractSource,
      contains('abstract interface class SceneViewPointerSemanticsBridge'),
    );
    expect(
      pointerSemanticsContractSource,
      contains('abstract interface class SceneViewPointerSemanticsSource'),
    );
    expect(
      internalAccessSource,
      isNot(contains('SceneControllerPointerSemanticsBridge')),
    );
    expect(
      internalAccessSource,
      isNot(contains('sceneControllerInternalCreatePointerSemanticsBridge(')),
    );
    expect(
      sceneViewInteractiveSource,
      contains('widget.controller.createPointerSemanticsBridge('),
    );
    expect(
      sceneViewInteractiveSource,
      contains('foregroundPainter: SceneViewInteractiveOverlayPainter('),
    );
    expect(
      sceneViewInteractiveSource,
      contains('renderState: widget.controller,'),
    );
    expect(
      sceneViewInteractiveSource,
      contains("import '../interactive/scene_controller.dart';"),
    );
    expect(
      sceneViewInteractiveSource,
      isNot(
        contains(
          "import '../interactive/internal/scene_controller_internal_access.dart';",
        ),
      ),
    );
    expect(
      sceneViewInteractiveSource,
      isNot(
        contains(
          "import '../interactive/internal/scene_controller_pointer_semantics.dart';",
        ),
      ),
    );
    expect(
      sceneViewInteractiveSource,
      isNot(contains('SceneControllerPointerSemantics(')),
    );
    expect(
      pointerHostSource,
      contains('SceneViewPointerSemanticsBridge'),
    );
    expect(
      pointerHostSource,
      contains('controller.createPointerSemanticsBridge('),
    );
    expect(pointerHostSource, isNot(contains('onControllerChanged')));
    expect(
      pointerHostSource,
      isNot(contains('SceneControllerPointerSemantics(')),
    );
    expect(pointerHostSource, isNot(contains('PointerInputTracker(')));
    expect(pointerHostSource, isNot(contains('_PendingTapFlushScheduler')));
    expect(pointerHostSource, isNot(contains('_pendingPointerSettings')));
    expect(
      pointerHostSource,
      isNot(
        contains(
          "import '../interactive/internal/scene_controller_internal_access.dart';",
        ),
      ),
    );
    expect(
      renderSurfaceSource,
      isNot(
        contains(
          "import '../interactive/internal/scene_controller_internal_access.dart';",
        ),
      ),
    );
    expect(
      renderSurfaceSource,
      isNot(contains('_interactiveControllerEpochReader')),
    );
    expect(
      renderSurfaceSource,
      isNot(contains('_interactivePreviewOffsetResolver')),
    );
    expect(renderSurfaceSource, isNot(contains('_selectionRect')));
    expect(renderSurfaceSource, contains('clearIfEpochChanged('));
    expect(renderSurfaceSource, contains('widget._controller.controllerEpoch'));
    expect(overlayPainterSource, contains('super(repaint: renderState)'));
    expect(
      overlayPainterSource,
      contains('sanitizeFiniteOffset(renderState.cameraOffset)'),
    );
    expect(
      overlayPainterSource,
      isNot(contains('super(repaint: interaction)')),
    );
    expect(
      overlayPainterSource,
      isNot(contains('controller.snapshot.camera.offset')),
    );
    expect(runtimeSource, isNot(contains('StreamController<')));
    expect(runtimeSource, isNot(contains('_timestampCursorMs')));
    expect(runtimeSource, isNot(contains('_actionCounter')));
    expect(runtimeSource, isNot(contains('_eraserHitsLine(')));
    expect(
      interactionRuntimeSource,
      isNot(contains('request.core.commands.writeSelectionReplace')),
    );
    expect(
      interactionRuntimeSource,
      isNot(contains('request.core.commands.writeSelectionClear')),
    );

    expect(eventSource, contains('class InteractiveEventDispatcher'));
    expect(eventSource, contains('resolveTimestampMs('));
    expect(eventSource, contains('emitAction('));
    expect(eventSource, contains('emitEditTextRequested('));

    expect(
      drawCoordinatorSource,
      contains("import 'interactive_draw_eraser_engine.dart';"),
    );
    expect(
      drawCoordinatorSource,
      contains("import 'interactive_draw_line_engine.dart';"),
    );
    expect(
      drawCoordinatorSource,
      contains("import 'interactive_draw_stroke_engine.dart';"),
    );
    expect(
      drawCoordinatorSource,
      contains("import 'interactive_draw_terminal_router.dart';"),
    );
    expect(drawCoordinatorSource, isNot(contains('_eraserHitsLine(')));
    expect(drawCoordinatorSource, isNot(contains('_eraserHitsStroke(')));
    expect(
      drawCoordinatorSource,
      isNot(contains('_localEraserSegmentsHitLine(')),
    );
    expect(
      drawCoordinatorSource,
      isNot(contains('_eraserSegmentHitsStrokeBatch(')),
    );

    expect(
      eraserSource,
      contains("import 'interactive_draw_eraser_exact_hit.dart';"),
    );
    expect(eraserSource, contains('InteractiveDrawEraserExactHit('));
    expect(eraserSource, contains('_exactHit.hitsNode('));
    expect(eraserSource, isNot(contains('_eraserHitsNode(')));
    expect(eraserSource, isNot(contains('_eraserHitsLine(')));
    expect(eraserSource, isNot(contains('_eraserHitsStroke(')));
    expect(eraserSource, isNot(contains('_projectEraserToLocal(')));
    expect(eraserSource, isNot(contains('_fallbackWorldBoundsHit(')));
    expect(eraserSource, isNot(contains('_localEraserSegmentsHitLine(')));
    expect(eraserSource, isNot(contains('_eraserSegmentHitsStrokeBatch(')));

    expect(
      eraserExactHitSource,
      contains("import 'interactive_draw_eraser_line_hit.dart';"),
    );
    expect(
      eraserExactHitSource,
      contains("import 'interactive_draw_eraser_projection.dart';"),
    );
    expect(
      eraserExactHitSource,
      contains("import 'interactive_draw_eraser_stroke_hit.dart';"),
    );
    expect(
      eraserExactHitSource,
      contains('class InteractiveDrawEraserExactHit'),
    );
    expect(eraserExactHitSource, contains('_lineHit.hitsProjectedLine('));
    expect(eraserExactHitSource, contains('_strokeHit.hitsProjectedStroke('));
    expect(eraserExactHitSource, contains('_projectEraserToLocal('));
    expect(eraserExactHitSource, contains('_fallbackWorldBoundsHit('));
    expect(
      eraserExactHitSource,
      isNot(contains('_localEraserSegmentsHitLine(')),
    );
    expect(
      eraserExactHitSource,
      isNot(contains('_eraserSegmentHitsStrokeBatch(')),
    );

    expect(eraserLineHitSource, contains('class InteractiveDrawEraserLineHit'));
    expect(eraserLineHitSource, contains('hitsProjectedLine('));
    expect(eraserLineHitSource, contains('_localEraserSegmentsHitLine('));
    expect(eraserLineHitSource, contains('onPreciseSegmentCheck()'));
    expect(
      eraserLineHitSource,
      isNot(contains('_eraserSegmentHitsStrokeBatch(')),
    );

    expect(
      eraserStrokeHitSource,
      contains('class InteractiveDrawEraserStrokeHit'),
    );
    expect(eraserStrokeHitSource, contains('hitsProjectedStroke('));
    expect(eraserStrokeHitSource, contains('_eraserSegmentHitsStrokeBatch('));
    expect(eraserStrokeHitSource, contains('onPreciseSegmentCheck()'));
    expect(
      eraserStrokeHitSource,
      isNot(contains('_localEraserSegmentsHitLine(')),
    );

    expect(
      eraserProjectionSource,
      contains('typedef InteractiveDrawProjectedEraser = ({'),
    );
  });
}
