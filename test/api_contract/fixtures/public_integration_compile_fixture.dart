// This fixture intentionally keeps the external public integration proof in one
// root-barrel consumer so it exercises the app-facing API as an adapter would,
// instead of passing through metric-shaped fragments.
// ignore_for_file: type=metrics

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

CanvasDeletionDecision _acceptDeletionCommit(CanvasDeletionCommitRequest _) =>
    CanvasDeletionDecision.accept;

final class PublicIntegrationCompileFixture {
  PublicIntegrationCompileFixture({CanvasRuntime? runtime})
    : runtime = runtime ?? CanvasRuntime(config: _runtimeConfig());

  final CanvasRuntime runtime;

  CanvasSurface createSurface() {
    return CanvasSurface(
      runtime: runtime,
      resourceResolver: const PublicIntegrationResourceResolver(),
      selectionStyle: CanvasSelectionStyle.defaultStyle,
      gridStyle: CanvasGridStyle.defaultStyle,
      interactive: false,
    );
  }

  CanvasTextEditingOverlay createTextEditingOverlay() {
    return CanvasTextEditingOverlay(
      runtime: runtime,
      inlineEditOnDoubleTap: true,
      maxEditorHeight: 160,
      autofocus: false,
      commitOnFocusLoss: false,
    );
  }

  CanvasDocument observeDocumentAndState() {
    final runtimeAppearance = runtime.readAppearance();
    final document = runtime.readDocument();
    final state = runtime.state.value;
    final revisions = state.revisions;
    final summary = state.summary;

    _use(document.camera);
    _use(document.background);
    _use(document.palette);
    _use(document.resources);
    _use(document.backgroundElements);
    _use(document.layers);
    _use(document.metadata);
    _use(runtimeAppearance.backgroundColor);
    _use(runtimeAppearance.grid);
    _use(runtimeAppearance.palette);
    _use(revisions.document);
    _use(revisions.selection);
    _use(revisions.preview);
    _use(revisions.viewCamera);
    _use(revisions.resourceVisual);
    _use(revisions.interaction);
    _use(revisions.epoch);
    _use(summary.elementCount);
    _use(summary.layerCount);
    _use(summary.resourceCount);
    _use(summary.selectedCount);
    _use(runtime.preview.kind);

    return document;
  }

  void exerciseEditAndLoad({
    required CanvasDocument document,
    required CanvasElement element,
    required CanvasElementUpdate update,
    required CanvasResource resource,
    required CanvasElementId elementId,
    required CanvasLayerId layerId,
    required CanvasResourceId resourceId,
  }) {
    runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));
    runtime.edits.edit((edit) {
      _use(edit.readDraftDocument());
      _use(edit.draftSummary);
      edit.ensureLayer(layerId);
      edit.addElement(element, layerId: layerId);
      edit.addBackgroundElement(element);
      edit.updateElement(update);
      edit.removeElement(elementId);
      edit.upsertResource(resource);
      edit.removeUnusedResource(resourceId);
      edit.setBackgroundColor(_compileOnly());
      edit.setGrid(CanvasGrid());
      edit.setPalette(const CanvasPalette.defaults());
      edit.updatePalette(
        CanvasPaletteUpdate(penColors: [const CanvasBackground().color]),
      );
      edit.setCameraOffset(_compileOnly());
      final clearResult = edit.clearContent(removeUnusedResources: true);
      _use(clearResult.removedElementIds);
      _use(clearResult.removedResourceIds);
      _use(clearResult.didClearContent);
      edit.replaceDraftDocument(document);
    });
  }

  void exerciseSelectionCameraToolsAndCommands({
    required CanvasElementId elementId,
    required CanvasInteractionRequestId requestId,
  }) {
    _use(runtime.selection.selectedElementIds);
    runtime.selection.setSelection([elementId]);
    runtime.selection.toggleSelection(elementId);
    runtime.selection.clearSelection();
    runtime.selection.selectAll();
    runtime.selection.moveSelection(_compileOnly());
    runtime.selection.rotateSelectionClockwise();
    runtime.selection.rotateSelectionCounterClockwise();
    runtime.selection.flipSelectionVertical();
    runtime.selection.flipSelectionHorizontal();
    runtime.selection.deleteSelection();

    _use(runtime.camera.camera);
    _use(runtime.camera.offset);
    runtime.camera.setOffset(_compileOnly());
    runtime.camera.panBy(_compileOnly());

    _use(runtime.tools.mode);
    _use(runtime.tools.drawStyle);
    _use(runtime.tools.pointerPolicy);
    runtime.tools.setMode(CanvasInteractionMode.draw);
    runtime.tools.setDrawStyle(CanvasDrawStyle());
    runtime.tools.setDrawTool(CanvasDrawTool.marker);
    runtime.tools.setDrawColor(_compileOnly());
    runtime.tools.setPointerPolicy(CanvasPointerPolicy());
    runtime.tools.handlePointer(
      CanvasPointerSample(
        pointerId: 1,
        position: _compileOnly(),
        phase: CanvasPointerLifecyclePhase.down,
        kind: _compileOnly(),
      ),
    );
    runtime.tools.handleDoubleTap(position: _compileOnly());

    runtime.commands.removeElement(elementId);
    runtime.commands.commitTextEdit(requestId, 'updated');
    runtime.commands.clearContent(removeUnusedResources: true);
  }

  void exerciseResourcesAndEvents({required CanvasResourceId resourceId}) {
    _use(runtime.resources.resources);
    _use(runtime.resources.resourceById(resourceId));
    runtime.resources.markResourceDirty(resourceId);
    runtime.resources.markAllResourcesDirty();

    runtime.actions.listen((event) {
      _use(event.actionId);
      _use(event.type);
      _use(event.elementIds);
      _use(event.timestampMs);
      _use(event.payload);
    });
    runtime.contextActionRequests.listen((request) {
      _use(request.requestId);
      _use(request.trigger);
      _use(request.target);
      _use(request.controllerEpoch);
      _use(request.documentRevision);
      _use(request.timestampMs);
      _use(request.viewPosition);
      _use(request.worldPosition);
    });
  }

  void dispose() {
    runtime.dispose();
  }
}

final class PublicIntegrationResourceResolver
    implements CanvasResourceResolver {
  const PublicIntegrationResourceResolver();

  @override
  Never resolveImage(CanvasImageResource resource) {
    _use(resource);

    return _compileOnly();
  }

  @override
  Never resolveVector(CanvasVectorResource resource) {
    _use(resource);

    return _compileOnly();
  }
}

CanvasRuntimeConfig _runtimeConfig() {
  return CanvasRuntimeConfig(
    deletionCommitResolver: _acceptDeletionCommit,
    pointerPolicy: CanvasPointerPolicy(),
    initialMode: CanvasInteractionMode.move,
    initialDrawStyle: CanvasDrawStyle(),
    clearSelectionOnDrawModeEnter: true,
    moveCommitResolver: (request) {
      _use(request.documentSummary);
      _use(request.movedElements);
      _use(request.proposedDelta);
      _use(request.selectionBoundsWorld);

      return const CanvasMoveCancel();
    },
    diagnosticPolicy: CanvasDiagnosticPolicy.verbose(),
  );
}

T _compileOnly<T>() => throw StateError('compile-only fixture value');

int _use(Object? value) => Object.hash(value, null);
