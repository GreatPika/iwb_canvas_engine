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

String _read(String path) => File(path).readAsStringSync();

void main() {
  // INV:INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY
  // INV:INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY
  // INV:INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY
  test('SceneController architecture boundary remains structurally split', () {
    final facadeSource = _read('lib/src/interactive/scene_controller.dart');
    final interactionSource = _read(
      'lib/src/interactive/scene_controller_interaction.dart',
    );
    final graphSource = _read(
      'lib/src/interactive/internal/scene_controller_graph.dart',
    );
    final viewRuntimeSource = _read(
      'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart',
    );
    final pointerSessionSource = _read(
      'lib/src/interactive/internal/scene_controller_pointer_session.dart',
    );
    final pointerSessionTokenSource = _read(
      'lib/src/interactive/internal/pointer_session_token.dart',
    );
    final runtimeContractSource = _read(
      'lib/src/contract/scene_view_runtime.dart',
    );
    final mutationBoundarySource = _read(
      'lib/src/interactive/internal/scene_controller_mutation_boundary.dart',
    );
    final sceneMutationsSource = _read(
      'lib/src/interactive/internal/scene_controller_scene_mutations.dart',
    );
    final selectionMutationsSource = _read(
      'lib/src/interactive/internal/scene_controller_selection_mutations.dart',
    );
    final selectionActionsSource = _read(
      'lib/src/interactive/internal/interactive_selection_actions.dart',
    );
    final runtimeSource = _read(
      'lib/src/interactive/internal/interactive_runtime.dart',
    );
    final interactionRuntimeSource = _read(
      'lib/src/interactive/internal/scene_controller_interaction_runtime.dart',
    );
    final internalAccessSource = _read(
      'lib/src/interactive/internal/scene_controller_internal_access.dart',
    );
    final pointerHostSource = _read(
      'lib/src/view/scene_view_interactive_pointer_host.dart',
    );
    final sceneViewInteractiveSource = _read(
      'lib/src/view/scene_view_interactive.dart',
    );
    final sceneViewRuntimeSource = _read(
      'lib/src/view/scene_view_runtime_host.dart',
    );
    final renderSurfaceSource = _read(
      'lib/src/view/scene_view_render_surface.dart',
    );
    final overlayPainterSource = _read(
      'lib/src/view/scene_view_interactive_overlay_painter.dart',
    );
    final eventSource = _read(
      'lib/src/interactive/internal/interactive_event_dispatcher.dart',
    );
    final drawCoordinatorSource = _read(
      'lib/src/interactive/internal/interactive_draw_coordinator.dart',
    );
    final eraserSource = _read(
      'lib/src/interactive/internal/interactive_draw_eraser_engine.dart',
    );
    final eraserExactHitSource = _read(
      'lib/src/interactive/internal/interactive_draw_eraser_exact_hit.dart',
    );
    final eraserLineHitSource = _read(
      'lib/src/interactive/internal/interactive_draw_eraser_line_hit.dart',
    );
    final eraserProjectionSource = _read(
      'lib/src/interactive/internal/interactive_draw_eraser_projection.dart',
    );
    final eraserStrokeHitSource = _read(
      'lib/src/interactive/internal/interactive_draw_eraser_stroke_hit.dart',
    );

    expect(
      File(
        'lib/src/interactive/internal/scene_controller_facade_assembly.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'lib/src/interactive/internal/scene_controller_pointer_semantics.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'lib/src/interactive/scene_view_pointer_semantics.dart',
      ).existsSync(),
      isFalse,
    );

    expect(
      facadeSource,
      contains("import 'internal/scene_controller_graph.dart';"),
    );
    expect(
      facadeSource,
      contains("import '../contract/scene_view_runtime.dart';"),
    );
    expect(facadeSource, contains('createSceneControllerGraph('));
    expect(facadeSource, contains('SceneControllerGraphRequest('));
    expect(
      facadeSource,
      isNot(contains('registerSceneControllerInternalAccess(')),
    );
    expect(
      facadeSource,
      contains('SceneViewRuntime sceneControllerViewRuntimeOf('),
    );
    expect(facadeSource, isNot(contains('implements SceneViewRenderState')));
    expect(facadeSource, isNot(contains('createPointerSemanticsBridge(')));
    expect(
      facadeSource,
      isNot(
        contains("import 'internal/scene_controller_internal_access.dart';"),
      ),
    );
    expect(
      facadeSource,
      isNot(
        contains("import 'internal/scene_controller_pointer_session.dart';"),
      ),
    );

    expect(graphSource, contains('SceneControllerInteraction('));
    expect(graphSource, contains('SceneControllerSelection('));
    expect(graphSource, contains('SceneControllerScene('));
    expect(graphSource, contains('SceneControllerSceneViewRuntime('));
    expect(graphSource, contains('SceneControllerInternalAccessRegistration('));
    expect(
      graphSource,
      contains('readInteraction: () => request.owner.interaction,'),
    );
    expect(
      graphSource,
      contains('interactionRuntime.ensurePublicSideEffectAllowed'),
    );
    expect(graphSource, contains('createSceneControllerGraph('));
    expect(graphSource, isNot(contains('createPointerSemanticsBridge')));

    expect(
      runtimeContractSource,
      contains('abstract interface class SceneViewRuntime'),
    );
    expect(
      runtimeContractSource,
      contains('SceneViewPointerSession createPointerSession({'),
    );
    expect(
      runtimeContractSource,
      contains('abstract interface class SceneViewPointerSession'),
    );
    expect(runtimeContractSource, isNot(contains('handleControllerChanged')));
    expect(runtimeContractSource, isNot(contains('updateController(')));

    expect(
      viewRuntimeSource,
      contains('final class SceneControllerSceneViewRuntime'),
    );
    expect(
      viewRuntimeSource,
      contains('final class SceneControllerSceneViewRenderState'),
    );
    expect(viewRuntimeSource, contains('SceneControllerPointerSession('));
    expect(
      viewRuntimeSource,
      contains("_ensurePublicSideEffectAllowed('createPointerSession');"),
    );
    expect(
      viewRuntimeSource,
      contains('SceneControllerInteraction get _interaction'),
    );
    expect(viewRuntimeSource, contains('createPointerSessionToken()'));
    expect(viewRuntimeSource, contains('releasePointerSessionToken:'));
    expect(
      viewRuntimeSource,
      contains('_interactionRuntime.releasePointerSessionToken'),
    );
    expect(
      viewRuntimeSource,
      contains(
        'handlePointerFromSession: _interactionRuntime.handlePointerFromSession,',
      ),
    );
    expect(viewRuntimeSource, contains('snapshot => _readSnapshot()'));

    expect(
      pointerSessionTokenSource,
      contains('final class PointerSessionToken'),
    );
    expect(pointerSessionTokenSource, isNot(contains('operator ==')));
    expect(pointerSessionTokenSource, isNot(contains('hashCode')));

    expect(
      pointerSessionSource,
      contains('final class SceneControllerPointerSession'),
    );
    expect(pointerSessionSource, contains('PointerInputTracker('));
    expect(pointerSessionSource, contains('_PendingTapFlushScheduler'));
    expect(pointerSessionSource, contains('_ownerListenable.addListener('));
    expect(pointerSessionSource, contains('PointerSessionToken token,'));
    expect(pointerSessionSource, contains('releasePointerSessionToken'));
    expect(pointerSessionSource, contains('PointerSessionToken token'));
    expect(pointerSessionSource, contains('_handlePointerFromSession('));
    expect(pointerSessionSource, contains('_handleDoubleTapFromSession('));
    expect(
      pointerSessionSource,
      contains('_releasePointerSessionToken(_token);'),
    );
    expect(pointerSessionSource, isNot(contains('handleControllerChanged(')));
    expect(pointerSessionSource, isNot(contains('SceneControllerInteraction')));
    expect(pointerSessionSource, isNot(contains('_readInteraction')));
    expect(pointerSessionSource, isNot(contains('Object? owner')));
    expect(pointerSessionSource, isNot(contains('Object? session')));
    expect(pointerSessionSource, isNot(contains('Object? context')));
    expect(pointerSessionSource, isNot(contains('runtimeType')));

    final handlePointerBody = _extractMethodBody(
      source: interactionSource,
      methodStart: 'void handlePointer(CanvasPointerInput input)',
    );
    expect(
      handlePointerBody,
      contains('_access.runtime.handlePublicPointer(input);'),
    );
    expect(handlePointerBody, isNot(contains('_pointerNormalizer')));
    expect(handlePointerBody, isNot(contains('_gestureRouter')));
    expect(handlePointerBody, isNot(contains('PointerSessionToken')));

    final handleDoubleTapBody = _extractMethodBody(
      source: interactionSource,
      methodStart:
          'void handleDoubleTap({required Offset position, int? timestampMs})',
    );
    expect(
      handleDoubleTapBody,
      contains('_access.runtime.handlePublicDoubleTap('),
    );
    expect(handleDoubleTapBody, isNot(contains('PointerSessionToken')));

    expect(
      mutationBoundarySource,
      contains('class SceneControllerMutationBoundary'),
    );
    expect(
      mutationBoundarySource,
      contains('storeController.commands.writeSelectionReplace(nodeIds);'),
    );
    expect(
      mutationBoundarySource,
      contains('storeController.commands.writeSelectionClear();'),
    );
    expect(
      mutationBoundarySource,
      contains('storeController.commands.writeDeleteSelection();'),
    );
    expect(
      mutationBoundarySource,
      contains('storeController.commands.writeSelectionTransform(delta);'),
    );
    expect(
      mutationBoundarySource,
      contains('storeController.prepareSceneReplacement(snapshot);'),
    );
    expect(
      mutationBoundarySource,
      contains('storeController.draw.writeDrawStroke('),
    );
    expect(
      mutationBoundarySource,
      contains('storeController.draw.writeDrawLineFromWorldSegment('),
    );
    expect(
      mutationBoundarySource,
      contains('storeController.draw.writeEraseNodes(ids);'),
    );
    expect(
      mutationBoundarySource,
      contains('storeController.writePreparedSceneReplacement(replacement);'),
    );
    expect(
      mutationBoundarySource,
      isNot(contains('storeController.writeReplaceScene(snapshot);')),
    );

    expect(sceneMutationsSource, contains('mutations.setGridCellSize(value);'));
    expect(sceneMutationsSource, contains('interruptForExternalMutation();'));
    expect(
      selectionMutationsSource,
      contains('mutations.setSelection(nodeIds);'),
    );
    expect(
      selectionActionsSource,
      contains('return mutations.commitMoveSelection(proposedDelta);'),
    );

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
      contains('void handlePublicPointer(CanvasPointerInput input)'),
    );
    expect(runtimeSource, contains('void handlePointerFromSession('));
    expect(
      runtimeSource,
      contains('void interruptForInteractionConfigChange()'),
    );
    expect(runtimeSource, contains('void interruptForExternalMutation()'));
    expect(runtimeSource, contains('void detachPointerSession('));
    expect(
      runtimeSource,
      contains(
        'void handlePublicDoubleTap({required Offset position, int? timestampMs})',
      ),
    );
    expect(runtimeSource, contains('void handleDoubleTapFromSession({'));
    expect(
      runtimeSource,
      isNot(contains('void handlePointer(CanvasPointerInput input)')),
    );
    expect(
      runtimeSource,
      isNot(
        contains(
          'void handleDoubleTap({required Offset position, int? timestampMs})',
        ),
      ),
    );
    expect(
      interactionRuntimeSource,
      contains("import 'pointer_session_token.dart';"),
    );
    expect(
      interactionRuntimeSource,
      contains('PointerSessionToken createPointerSessionToken()'),
    );
    expect(
      interactionRuntimeSource,
      contains('void releasePointerSessionToken(PointerSessionToken token)'),
    );
    expect(
      interactionRuntimeSource,
      contains('void interruptForInteractionConfigChange()'),
    );
    expect(
      interactionRuntimeSource,
      contains('void interruptForExternalMutation()'),
    );
    expect(
      interactionRuntimeSource,
      contains('void handlePublicPointer(CanvasPointerInput input)'),
    );
    expect(
      interactionRuntimeSource,
      contains(
        'void handlePublicDoubleTap({required Offset position, int? timestampMs})',
      ),
    );
    expect(
      interactionRuntimeSource,
      contains('void handlePointerFromSession('),
    );
    expect(
      interactionRuntimeSource,
      contains('void handleDoubleTapFromSession({'),
    );
    expect(
      interactionRuntimeSource,
      contains('_ensureKnownPointerSessionToken(token);'),
    );
    expect(
      interactionRuntimeSource,
      isNot(contains('void handlePointer(CanvasPointerInput input)')),
    );
    expect(
      interactionRuntimeSource,
      isNot(
        contains(
          'void handleDoubleTap({required Offset position, int? timestampMs})',
        ),
      ),
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
      contains('commitDrawStroke: mutationBoundary.commitDrawStroke,'),
    );
    expect(
      interactionRuntimeSource,
      contains(
        'commitDrawLineFromWorldSegment:\n'
        '          mutationBoundary.commitDrawLineFromWorldSegment,',
      ),
    );
    expect(
      interactionRuntimeSource,
      contains('commitEraseNodes: mutationBoundary.commitEraseNodes,'),
    );
    expect(
      interactionRuntimeSource,
      isNot(contains('request.storeController.draw.writeDrawStroke')),
    );
    expect(
      interactionRuntimeSource,
      isNot(
        contains('request.storeController.draw.writeDrawLineFromWorldSegment'),
      ),
    );
    expect(
      interactionRuntimeSource,
      isNot(contains('request.storeController.draw.writeEraseNodes')),
    );

    expect(
      internalAccessSource,
      contains('registerSceneControllerInternalAccess('),
    );
    expect(internalAccessSource, isNot(contains('SceneViewRuntime')));
    expect(internalAccessSource, isNot(contains('SceneViewPointerSession')));

    expect(
      sceneViewInteractiveSource,
      contains("import '../interactive/scene_controller.dart';"),
    );
    expect(
      sceneViewInteractiveSource,
      contains("import 'scene_view_runtime_host.dart';"),
    );
    expect(
      sceneViewInteractiveSource,
      contains('runtime: sceneControllerViewRuntimeOf(controller),'),
    );
    expect(sceneViewInteractiveSource, isNot(contains('Listener(')));
    expect(
      sceneViewInteractiveSource,
      isNot(contains('SceneViewRenderSurface(')),
    );

    expect(
      sceneViewRuntimeSource,
      contains('class SceneViewRuntimeHost extends StatefulWidget'),
    );
    expect(
      sceneViewRuntimeSource,
      contains('widget.runtime.createPointerSession('),
    );
    expect(
      sceneViewRuntimeSource,
      contains('_pointerHost.replacePointerSession('),
    );
    expect(
      sceneViewRuntimeSource,
      contains('foregroundPainter: SceneViewInteractiveOverlayPainter('),
    );
    expect(sceneViewRuntimeSource, contains('child: SceneViewRenderSurface('));

    expect(pointerHostSource, contains('SceneViewPointerSession'));
    expect(pointerHostSource, contains('replacePointerSession('));
    expect(pointerHostSource, isNot(contains('SceneController')));
    expect(pointerHostSource, isNot(contains('createPointerSemanticsBridge(')));
    expect(pointerHostSource, isNot(contains('PointerInputTracker(')));
    expect(pointerHostSource, isNot(contains('_PendingTapFlushScheduler')));
    expect(pointerHostSource, isNot(contains('_pendingPointerSettings')));

    expect(
      renderSurfaceSource,
      contains('required SceneViewRenderState renderState,'),
    );
    expect(
      renderSurfaceSource,
      isNot(contains('SceneViewRenderSurface.store(')),
    );
    expect(
      renderSurfaceSource,
      isNot(contains('SceneViewRenderSurface.interactive(')),
    );
    expect(
      renderSurfaceSource,
      isNot(contains("import '../interactive/scene_controller.dart';")),
    );
    expect(
      renderSurfaceSource,
      isNot(contains("import '../controller/scene_store_controller.dart';")),
    );
    expect(
      renderSurfaceSource,
      contains('widget._renderState.controllerEpoch'),
    );

    expect(overlayPainterSource, contains('super(repaint: renderState)'));
    expect(
      overlayPainterSource,
      contains('sanitizeFiniteOffset(renderState.cameraOffset)'),
    );

    expect(eventSource, contains('class InteractiveEventDispatcher'));
    expect(eventSource, contains('resolveTimestampMs('));
    expect(eventSource, contains('emitAction('));
    expect(eventSource, contains('emitEditTextRequested('));

    expect(
      drawCoordinatorSource,
      contains("import 'interactive_draw_eraser_engine.dart';"),
    );
    expect(eraserSource, contains('InteractiveDrawEraserExactHit('));
    expect(
      eraserExactHitSource,
      contains("import 'interactive_draw_eraser_line_hit.dart';"),
    );
    expect(eraserLineHitSource, contains('class InteractiveDrawEraserLineHit'));
    expect(
      eraserProjectionSource,
      contains('typedef InteractiveDrawProjectedEraser = ({'),
    );
    expect(
      eraserStrokeHitSource,
      contains('class InteractiveDrawEraserStrokeHit'),
    );
  });
}
