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
    final paintCandidateStageSource = _read(
      'lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart',
    );
    final selectedPaintOrderCacheSource = _read(
      'lib/src/interactive/internal/scene_controller_selected_paint_order_cache.dart',
    );
    final sceneSpatialIndexSource = _read(
      'lib/src/core/scene_spatial_index.dart',
    );
    final spatialIndexCacheSource = _read(
      'lib/src/controller/internal/spatial_index_cache.dart',
    );
    final sceneStoreControllerSource = _read(
      'lib/src/controller/scene_store_controller.dart',
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
    final mutationAccessSource = _read(
      'lib/src/controller/scene_controller_committed_mutation_access.dart',
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
    final movePreviewStateSource = _read(
      'lib/src/interactive/internal/interactive_move_preview_state.dart',
    );
    final moveSessionSource = _read(
      'lib/src/interactive/internal/interactive_move_session.dart',
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

    expect(graphSource, contains('SceneControllerInteractionOwner('));
    expect(graphSource, contains('SceneControllerSelectionOwner('));
    expect(graphSource, contains('SceneControllerSceneOwner('));
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
    expect(runtimeContractSource, contains('void detach();'));
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
    expect(viewRuntimeSource, contains('overlayRepaintListenable'));
    expect(viewRuntimeSource, contains('scheduleSceneRepaint()'));
    expect(viewRuntimeSource, contains('scheduleOverlayRepaint()'));
    expect(viewRuntimeSource, contains('SceneControllerSceneRepaintChannel()'));
    expect(
      viewRuntimeSource,
      contains('SceneControllerOverlayRepaintChannel()'),
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
    expect(viewRuntimeSource, contains('detachPointerSession:'));
    expect(
      viewRuntimeSource,
      contains('_interactionRuntime.detachPointerSession'),
    );
    expect(
      viewRuntimeSource,
      isNot(contains('_DisposedSceneViewPointerSession')),
    );
    expect(
      viewRuntimeSource,
      isNot(contains('if (_interactionRuntime.isDisposed)')),
    );
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
    final captureFrameReadBody = _extractMethodBody(
      source: viewRuntimeSource,
      methodStart: 'SceneViewFrameRead captureFrameRead()',
    );
    expect(
      captureFrameReadBody,
      contains('selectionRevision: _storeController.selectionRevision,'),
    );
    final preparePaintPlanBody = _extractMethodBody(
      source: viewRuntimeSource,
      methodStart: 'ScenePreparedPaintPlan preparePaintPlan(',
    );
    expect(
      preparePaintPlanBody,
      contains('return _paintCandidateStage.prepareCommittedPaintPlan('),
    );
    expect(
      preparePaintPlanBody,
      contains('return ScenePreparedPaintCandidateList('),
    );
    expect(preparePaintPlanBody, isNot(contains('queryPaintCandidates(')));
    expect(
      preparePaintPlanBody,
      isNot(contains('resolveSpatialCandidateSnapshot((')),
    );
    expect(preparePaintPlanBody, isNot(contains('resolveSnapshotNodeById(')));
    expect(
      preparePaintPlanBody,
      isNot(contains('_storeController.selectionRevision')),
    );

    final stageBody = _extractMethodBody(
      source: paintCandidateStageSource,
      methodStart: 'ScenePreparedPaintPlan prepareCommittedPaintPlan({',
    );
    final ordinaryBody = _extractMethodBody(
      source: paintCandidateStageSource,
      methodStart: 'void _stageOrdinaryCandidates({',
    );
    final supplementBody = _extractMethodBody(
      source: paintCandidateStageSource,
      methodStart: 'void _stageSelectedSupplements({',
    );
    expect(stageBody, contains('_stageOrdinaryCandidates('));
    expect(stageBody, contains('_stageSelectedSupplements('));
    expect(stageBody, contains('_mergeOrderedCandidates(buffers)'));
    expect(stageBody, isNot(contains('.sort(')));
    expect(
      supplementBody,
      contains('_selectedOrderCache.orderedSelectedTokens('),
    );
    expect(supplementBody, contains('selectionRevision: selectionRevision,'));
    expect(supplementBody, contains('structuralRevision: structuralRevision,'));
    expect(supplementBody, contains('for (final token in selectedTokens)'));
    expect(
      supplementBody,
      isNot(contains('for (final nodeId in selectedNodeIds)')),
    );
    expect(supplementBody, isNot(contains('.sort(')));
    expect(
      paintCandidateStageSource,
      contains('SceneControllerSelectedPaintOrderCache _selectedOrderCache'),
    );
    expect(
      selectedPaintOrderCacheSource,
      contains('final class SceneControllerSelectedPaintOrderCache'),
    );
    expect(
      selectedPaintOrderCacheSource,
      contains('SceneControllerSelectedPaintOrderToken'),
    );
    expect(
      selectedPaintOrderCacheSource,
      contains('_selectionRevision == selectionRevision'),
    );
    expect(selectedPaintOrderCacheSource, contains('nextTokens.sort('));
    expect(
      selectedPaintOrderCacheSource,
      isNot(contains('_sameOrderedTokens')),
    );
    expect(
      selectedPaintOrderCacheSource,
      isNot(contains('ScenePaintCandidate')),
    );
    expect(
      selectedPaintOrderCacheSource,
      isNot(contains('ScenePreparedPaintPlan')),
    );
    expect(selectedPaintOrderCacheSource, isNot(contains('paintBoundsWorld')));
    expect(
      ordinaryBody,
      contains(
        'scope: ScenePaintSpatialQueryScope.backgroundAndContentLayers,',
      ),
    );
    expect(ordinaryBody, contains('_store.resolveSpatialCandidateSnapshot(('));
    expect(
      ordinaryBody,
      contains('paintBoundsWorld: candidate.paintBoundsWorld,'),
    );
    expect(
      paintCandidateStageSource,
      isNot(contains('snapshot.backgroundLayer.nodes')),
    );
    expect(
      paintCandidateStageSource,
      isNot(contains('resolveSnapshotNodeById(candidate.nodeId)')),
    );
    expect(ordinaryBody, isNot(contains('_snapshotPaintBoundsWorld(')));
    expect(ordinaryBody, isNot(contains('nodeSnapshotPaintBoundsWorld(')));
    expect(ordinaryBody, isNot(contains('nodePaintBoundsWorld(')));
    expect(ordinaryBody, isNot(contains('.sort(')));

    final cachePaintQueryBody = _extractMethodBody(
      source: spatialIndexCacheSource,
      methodStart:
          'List<ScenePaintSpatialCandidate> writeQueryPaintCandidates({',
    );
    final storePaintQueryBody = _extractMethodBody(
      source: sceneStoreControllerSource,
      methodStart: 'List<ScenePaintSpatialCandidate> queryPaintCandidates(',
    );
    expect(cachePaintQueryBody, contains('return index.queryPaintCandidates('));
    expect(storePaintQueryBody, contains('return _commitRuntime'));
    expect(cachePaintQueryBody, isNot(contains('.sort(')));
    expect(cachePaintQueryBody, isNot(contains('..sort(')));
    expect(storePaintQueryBody, isNot(contains('.sort(')));
    expect(storePaintQueryBody, isNot(contains('..sort(')));

    final spatialPaintResolveBody = _extractMethodBody(
      source: sceneSpatialIndexSource,
      methodStart: 'List<ScenePaintSpatialCandidate> _resolvePaintCandidates(',
    );
    final spatialPaintOrderBody = _extractMethodBody(
      source: sceneSpatialIndexSource,
      methodStart: 'int _comparePaintCandidateIds(',
    );
    final paintSpatialEntryBody = _extractMethodBody(
      source: sceneSpatialIndexSource,
      methodStart: 'class _PaintSpatialEntry {',
    );
    expect(
      spatialPaintResolveBody,
      contains('_orderedPaintCandidateIds(index, candidateIds)'),
    );
    expect(spatialPaintResolveBody, isNot(contains('_visitResolved')));
    expect(spatialPaintOrderBody, contains('index._nodeLocator'));
    expect(paintSpatialEntryBody, isNot(contains('int layerIndex')));
    expect(paintSpatialEntryBody, isNot(contains('int nodeIndex')));

    expect(viewRuntimeSource, isNot(contains('BackgroundSpatialIndex')));
    expect(viewRuntimeSource, isNot(contains('SceneBackgroundSpatialIndex')));
    expect(viewRuntimeSource, isNot(contains('BackgroundPaintCandidateCache')));
    expect(viewRuntimeSource, isNot(contains('_backgroundPaintCells')));
    expect(viewRuntimeSource, isNot(contains('_backgroundLargePaintNodeIds')));

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
    expect(pointerSessionSource, contains('detachPointerSession'));
    expect(pointerSessionSource, contains('releasePointerSessionToken'));
    expect(pointerSessionSource, contains('PointerSessionToken token'));
    expect(pointerSessionSource, contains('void detach()'));
    expect(pointerSessionSource, contains('_detachPointerSession(_token);'));
    expect(pointerSessionSource, contains('_releaseOwnedResources();'));
    expect(pointerSessionSource, contains('_handlePointerFromSession('));
    expect(pointerSessionSource, contains('_handleDoubleTapFromSession('));
    expect(pointerSessionSource, contains('void _releaseOwnedResources()'));
    expect(
      pointerSessionSource,
      contains('_ownerListenable.removeListener(_ownerListener);'),
    );
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
      contains(
        "import '../../controller/scene_controller_committed_mutation_access.dart';",
      ),
    );
    expect(
      mutationBoundarySource,
      contains('final SceneControllerCommittedMutationAccess mutationAccess;'),
    );
    expect(
      mutationBoundarySource,
      contains('if (!mutationAccess.replaceSelection(nodeIds)) {'),
    );
    expect(
      mutationBoundarySource,
      contains('if (!mutationAccess.clearSelection()) {'),
    );
    expect(
      mutationBoundarySource,
      contains('mutationAccess.deleteSelection();'),
    );
    expect(
      mutationBoundarySource,
      contains('mutationAccess.transformSelection(delta);'),
    );
    expect(mutationBoundarySource, contains('mutationAccess.replaceScene('));
    expect(
      mutationBoundarySource,
      contains('mutationAccess.commitDrawStroke('),
    );
    expect(
      mutationBoundarySource,
      contains('mutationAccess.commitDrawLineFromWorldSegment('),
    );
    expect(
      mutationBoundarySource,
      contains('mutationAccess.commitEraseNodes(ids);'),
    );
    expect(
      mutationBoundarySource,
      contains(
        'mutationAccess.replaceScene(snapshot, beforeApply: interruptBeforeApply);',
      ),
    );
    expect(mutationBoundarySource, isNot(contains('SceneStoreController')));
    expect(
      mutationBoundarySource,
      isNot(contains('storeController.commands.')),
    );
    expect(mutationBoundarySource, isNot(contains('storeController.draw.')));
    expect(
      mutationBoundarySource,
      isNot(contains('storeController.writeReplaceScene(snapshot);')),
    );

    expect(
      mutationAccessSource,
      contains(
        'abstract interface class SceneControllerCommittedMutationAccess',
      ),
    );
    expect(
      mutationAccessSource,
      contains('final class SceneStoreControllerCommittedMutationAccess'),
    );
    expect(mutationAccessSource, isNot(contains('commands;')));
    expect(mutationAccessSource, isNot(contains('draw;')));
    expect(
      mutationAccessSource,
      contains('SceneControllerCommittedMutationWriteResult<T> writeExact<T>('),
    );
    expect(
      mutationAccessSource,
      contains('bool replaceSelection(Iterable<NodeId> nodeIds);'),
    );
    expect(mutationAccessSource, contains('void replaceScene('));
    expect(
      mutationAccessSource,
      contains(
        'return _storeController.commands.writeSelectionSelectAllExactResult(',
      ),
    );
    expect(
      mutationAccessSource,
      contains('writer.runtime.writeStagedDocumentReplace('),
    );
    expect(mutationAccessSource, contains('beforeApply();'));
    expect(mutationAccessSource, contains('writeDocumentReplaceNow();'));

    final writerRuntimeSource = _read(
      'lib/src/controller/scene_writer_runtime.dart',
    );
    expect(writerRuntimeSource, contains('void writeStagedDocumentReplace('));
    expect(writerRuntimeSource, isNot(contains('void writeReplaceScene(')));
    expect(
      writerRuntimeSource,
      isNot(contains('PreparedSceneReplacement prepareSceneReplacement(')),
    );

    expect(sceneMutationsSource, contains('mutations.setGridCellSize(value);'));
    expect(sceneMutationsSource, contains('interruptForExternalMutation();'));
    expect(
      sceneMutationsSource,
      contains('interruptBeforeApply: interruptForExternalMutation,'),
    );
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
      movePreviewStateSource,
      contains('bool get hasSceneEffect => hasTranslation;'),
    );
    expect(movePreviewStateSource, isNot(contains('bool get isActive')));
    expect(
      movePreviewStateSource,
      isNot(contains('bool start(Set<NodeId> nodeIds)')),
    );
    expect(moveSessionSource, contains('_previewState.hasSceneEffect'));
    expect(moveSessionSource, isNot(contains('_previewState.isActive')));
    expect(
      moveSessionSource,
      isNot(contains('if (_moveHandleDown(scenePoint))')),
    );
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
      contains(
        "import '../../controller/scene_controller_committed_mutation_access.dart';",
      ),
    );
    expect(
      interactionRuntimeSource,
      contains('PointerSessionToken createPointerSessionToken()'),
    );
    expect(
      interactionRuntimeSource,
      contains('void detachPointerSession(PointerSessionToken token)'),
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
    expect(interactionRuntimeSource, contains('required this.mutationAccess,'));
    expect(
      interactionRuntimeSource,
      contains('final SceneControllerCommittedMutationAccess mutationAccess;'),
    );
    expect(
      interactionRuntimeSource,
      contains('mutationAccess: request.mutationAccess,'),
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
      graphSource,
      contains(
        "import '../../controller/scene_controller_committed_mutation_access.dart';",
      ),
    );
    expect(
      graphSource,
      contains('mutationAccess: SceneStoreControllerCommittedMutationAccess('),
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
      contains('late SceneViewRuntime _activeRuntime;'),
    );
    expect(
      sceneViewRuntimeSource,
      isNot(contains('late SceneViewRuntime _requestedRuntime;')),
    );
    expect(
      sceneViewRuntimeSource,
      contains('_activeRuntime.createPointerSession('),
    );
    expect(
      sceneViewRuntimeSource,
      contains('return runtime.createPointerSession('),
    );
    expect(
      sceneViewRuntimeSource,
      contains('_createReplacementPointerSession('),
    );
    expect(
      sceneViewRuntimeSource,
      isNot(contains('FlutterError.reportError(')),
    );
    expect(
      sceneViewRuntimeSource,
      contains('_pointerHost.replacePointerSession('),
    );
    expect(
      sceneViewRuntimeSource,
      contains('final nextPointerSession = _createReplacementPointerSession('),
    );
    expect(
      sceneViewRuntimeSource,
      contains('if (_activeRuntime == widget.runtime) {'),
    );
    expect(
      sceneViewRuntimeSource,
      isNot(contains('_requestedRuntime = widget.runtime;')),
    );
    expect(
      sceneViewRuntimeSource,
      isNot(contains('if (nextPointerSession == null) {')),
    );
    expect(
      sceneViewRuntimeSource,
      contains('final renderState = _activeRuntime.renderState;'),
    );
    expect(
      sceneViewRuntimeSource,
      isNot(contains('final renderState = widget.runtime.renderState;')),
    );
    expect(
      sceneViewRuntimeSource,
      contains('foregroundPainter: SceneViewInteractiveOverlayPainter('),
    );
    expect(sceneViewRuntimeSource, contains('child: SceneViewRenderSurface('));
    final runtimeHostBody = sceneViewRuntimeSource.substring(
      sceneViewRuntimeSource.indexOf('class _SceneViewRuntimeHostState'),
    );
    final didUpdateWidgetBody = _extractMethodBody(
      source: runtimeHostBody,
      methodStart: 'void didUpdateWidget(SceneViewRuntimeHost oldWidget)',
    );
    expect(
      didUpdateWidgetBody.indexOf('if (_activeRuntime == widget.runtime) {') <
          didUpdateWidgetBody.indexOf('return;'),
      isTrue,
    );
    expect(
      didUpdateWidgetBody.indexOf(
            'final nextPointerSession = _createReplacementPointerSession(',
          ) <
          didUpdateWidgetBody.indexOf(
            '_pointerHost.replacePointerSession(nextPointerSession);',
          ),
      isTrue,
    );
    expect(
      didUpdateWidgetBody.indexOf(
            '_pointerHost.replacePointerSession(nextPointerSession);',
          ) <
          didUpdateWidgetBody.indexOf('_activeRuntime = widget.runtime;'),
      isTrue,
    );

    expect(pointerHostSource, contains('SceneViewPointerSession'));
    expect(pointerHostSource, contains('replacePointerSession('));
    final pointerRuntimeSource = pointerHostSource.substring(
      pointerHostSource.indexOf('class _SceneViewInteractivePointerRuntime'),
    );
    final replacePointerSessionBody = _extractMethodBody(
      source: pointerRuntimeSource,
      methodStart: 'void replacePointerSession(SceneViewPointerSession next)',
    );
    expect(
      replacePointerSessionBody.indexOf('current.detach();') <
          replacePointerSessionBody.indexOf('current.dispose();'),
      isTrue,
    );
    expect(
      replacePointerSessionBody.indexOf('current.dispose();') <
          replacePointerSessionBody.indexOf('_pointerRouter.reset();'),
      isTrue,
    );
    expect(
      replacePointerSessionBody.indexOf('_pointerRouter.reset();') <
          replacePointerSessionBody.indexOf('_pointerSession = next;'),
      isTrue,
    );
    final disposePointerHostBody = _extractMethodBody(
      source: pointerRuntimeSource,
      methodStart: 'void dispose()',
    );
    expect(
      disposePointerHostBody.indexOf('_pointerSession.detach();') <
          disposePointerHostBody.indexOf('_pointerSession.dispose();'),
      isTrue,
    );
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

    expect(
      overlayPainterSource,
      contains('super(repaint: renderState.overlayRepaintListenable)'),
    );
    expect(
      overlayPainterSource,
      contains('sanitizeFiniteOffset(renderState.cameraOffset)'),
    );
    expect(overlayPainterSource, contains('_paintMarqueeSelection('));

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
