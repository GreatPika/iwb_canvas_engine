import 'dart:io';

import 'package:test/test.dart';

import '../../tool/guardrails/src/public_api_registry.dart';
import '../../tool/guardrails/src/repository_paths.dart';

void main() {
  test('public API compiles from an empty consumer package', () async {
    final registryNames = readPublicApiRegistry();
    final analyze = await _analyzeConsumerSource(
      _consumerSource(registryNames),
    );
    expect(analyze.exitCode, 0, reason: _processOutput(analyze));
  });

  test('retired public load and decode routes do not compile', () async {
    for (final source in _retiredPublicRouteSources()) {
      final analyze = await _analyzeConsumerSource(source);
      expect(analyze.exitCode, isNot(0), reason: _processOutput(analyze));
    }
  });
}

Future<ProcessResult> _analyzeConsumerSource(String source) async {
  final packageDir = await Directory.systemTemp.createTemp(
    'iwb_canvas_engine_public_api_consumer_',
  );

  try {
    await Directory('${packageDir.path}/lib').create();
    await File(
      '${packageDir.path}/pubspec.yaml',
    ).writeAsString(_pubspecSource());
    await File(
      '${packageDir.path}/lib/public_api_consumer.dart',
    ).writeAsString(source);

    final pubGet = await Process.run('flutter', [
      'pub',
      'get',
    ], workingDirectory: packageDir.path);
    expect(pubGet.exitCode, 0, reason: _processOutput(pubGet));

    return await Process.run(Platform.resolvedExecutable, [
      'analyze',
      'lib/public_api_consumer.dart',
    ], workingDirectory: packageDir.path);
  } finally {
    await packageDir.delete(recursive: true);
  }
}

List<String> _retiredPublicRouteSources() {
  const prefix = '''
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void main() {
''';
  const suffix = '''
}
''';

  return [
    '''
$prefix
  CanvasRuntime(initialDocument: CanvasDocument());
$suffix
''',
    '''
$prefix
  CanvasRuntime().edits.loadDocument(CanvasDocument());
$suffix
''',
    '''
$prefix
  decodeCanvasDocument({'schemaVersion': 1});
$suffix
''',
    '''
$prefix
  decodeCanvasDocumentFromJson('{"schemaVersion":1}');
$suffix
''',
  ];
}

String _pubspecSource() {
  return '''
name: iwb_canvas_engine_public_api_consumer
publish_to: none

environment:
  sdk: ^3.10.4

dependencies:
  flutter:
    sdk: flutter
  iwb_canvas_engine:
    path: $repositoryRoot
''';
}

String _consumerSource(Set<String> registryNames) {
  final publicUses = (registryNames.toList()..sort())
      .map((name) => '  _use($name);')
      .join('\n');

  return '''
import 'dart:typed_data';
import 'dart:ui' hide Image;
import 'dart:ui' as ui show Image;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';

void acceptPublicSurface() {
$publicUses
  _exerciseP2ContractSurface();
}

void _use(Object? value) {}

void _exerciseP2ContractSurface() {
  final elementId = CanvasElementId('element-1');
  final secondElementId = CanvasElementId('element-2');
  final layerId = CanvasLayerId('layer-1');
  final resourceId = CanvasResourceId('resource-1');
  final actionId = CanvasActionId('action-1');
  final requestId = CanvasInteractionRequestId('request-1');
  _use(actionId);
  _use(requestId);

  final metadata = CanvasMetadata.fromMap({
    'tags': ['p2'],
  });
  final resource = CanvasImageResource(
    id: resourceId,
    source: CanvasResourceSource.appKey('resource-1'),
    mimeType: 'image/png',
    contentHash: 'sha256:resource-1',
    byteLength: 128,
    metadata: metadata,
  );
  final CanvasResourceSource source = CanvasAppKeyResourceSource('resource-2');
  final appKeySource = CanvasResourceSource.appKey('resource-3');
  _use(source);
  _use(appKeySource);

  final imageElement = CanvasImageElement(
    id: elementId,
    resourceId: resourceId,
    size: const Size(10, 20),
    naturalSize: const Size(20, 40),
    opacity: 0.9,
    metadata: metadata,
  );
  final pathElement = CanvasPathElement(
    id: CanvasElementId('path-1'),
    svgPathData: 'M 0 0 L 10 10',
    fillColor: const Color(0xFF00FF00),
    strokeColor: const Color(0xFF0000FF),
    strokeWidth: 1,
    fillRule: CanvasPathFillRule.evenOdd,
  );
  final textElement = CanvasTextElement(
    id: CanvasElementId('text-1'),
    text: 'label',
    color: const Color(0xFF111111),
    textDirection: TextDirection.ltr,
    fontSize: 16,
    align: TextAlign.center,
    isBold: true,
    isItalic: true,
    isUnderline: true,
    fontFamily: 'Roboto',
    maxWidth: 120,
    lineHeight: 1.2,
  );
  final strokeElement = CanvasStrokeElement(
    id: CanvasElementId('stroke-1'),
    points: const [Offset.zero, Offset(2, 2)],
    thickness: 2,
    color: const Color(0xFF222222),
  );
  final onePointStrokeElement = CanvasStrokeElement(
    id: CanvasElementId('stroke-one-point'),
    points: const [Offset(1, 1)],
    thickness: 2,
    color: const Color(0xFF222222),
  );
  final lineElement = CanvasLineElement(
    id: CanvasElementId('line-1'),
    start: Offset.zero,
    end: const Offset(4, 4),
    thickness: 2,
    color: const Color(0xFF333333),
  );
  final samePointLineElement = CanvasLineElement(
    id: CanvasElementId('line-same-point'),
    start: const Offset(2, 2),
    end: const Offset(2, 2),
    thickness: 2,
    color: const Color(0xFF333333),
  );
  final rectElement = CanvasRectElement(
    id: elementId,
    size: const Size(10, 20),
    fillColor: const Color(0xFFFFFFFF),
    strokeColor: const Color(0xFF000000),
    strokeWidth: 1,
    metadata: metadata,
  );
  final List<CanvasElement> elements = [
    imageElement,
    pathElement,
    textElement,
    strokeElement,
    onePointStrokeElement,
    lineElement,
    samePointLineElement,
    rectElement,
  ];
  _use(elements.map((element) => element.kind));

  final camera = CanvasCamera(offset: const Offset(1, 2));
  final grid = CanvasGrid(
    enabled: true,
    cellSize: 16,
    color: const Color(0x22000000),
  );
  final background = CanvasBackground(
    color: const Color(0xFFFFFFFF),
    grid: grid,
  );
  final palette = CanvasPalette(
    penColors: const [Color(0xFF000000)],
    backgroundColors: const [Color(0xFFFFFFFF)],
    gridSizes: const [8, 16],
  );
  final document = CanvasDocument(
    camera: camera,
    background: background,
    palette: palette,
    resources: [resource],
    backgroundElements: [lineElement],
    layers: [
      CanvasLayer(id: layerId, elements: elements, metadata: metadata),
    ],
    metadata: metadata,
  );
  final documentSummary = CanvasDocumentSummary(
    elementCount: elements.length,
    layerCount: document.layers.length,
    resourceCount: document.resources.length,
  );
  _use(documentSummary);

  final runtime = CanvasRuntime(
    config: CanvasRuntimeConfig(
      pointerPolicy: CanvasPointerPolicy(
        tapSlop: 9,
        doubleTapSlop: 18,
        doubleTapMaxDelayMs: 250,
        deferSingleTap: false,
        dragStartSlop: 4,
      ),
      initialMode: CanvasInteractionMode.move,
      initialDrawStyle: CanvasDrawStyle(
        tool: CanvasDrawTool.marker,
        color: const Color(0xFF123456),
        pencilThickness: 3,
        markerThickness: 12,
        markerOpacity: 0.5,
        lineThickness: 4,
        eraserThickness: 20,
      ),
      clearSelectionOnDrawModeEnter: true,
      moveCommitResolver: _resolveMove,
      diagnosticPolicy: CanvasDiagnosticPolicy.verbose(
        maxPreviewLength: 128,
        maxListEntries: 8,
      ),
    ),
  );
  runtime.edits.loadDocumentFromJson(encodeCanvasDocumentToJson(document));

  final ValueListenable<CanvasRuntimeState> state = runtime.state;
  final CanvasTextEditingPort textEditing = runtime.textEditing;
  final CanvasRuntimeState snapshot = state.value;
  final CanvasRuntimeRevisions revisions = snapshot.revisions;
  final CanvasRuntimeSummary summary = snapshot.summary;
  _use(revisions.document);
  _use(summary.elementCount);
  _use(runtime.readDocument());
  _use(const CanvasRuntimeRevisions(
    document: 1,
    selection: 2,
    preview: 3,
    viewCamera: 4,
    resourceVisual: 5,
    interaction: 6,
    epoch: 7,
  ));
  _use(const CanvasRuntimeSummary(
    elementCount: 1,
    layerCount: 1,
    resourceCount: 1,
    selectedCount: 0,
  ));
  _exerciseInlineTextEditingContractSurface(textEditing, requestId, elementId);

  final transform = CanvasTransform.trs(
    translation: const Offset(1, 2),
    rotationDegrees: 90,
    scaleX: 2,
    scaleY: 3,
  );
  final CanvasTransform moved = transform.withTranslation(const Offset(3, 4));
  final CanvasTransform multiplied = moved.multiply(CanvasTransform.identity);
  final Offset point = multiplied.applyToPoint(const Offset(5, 6));
  final Rect bounds = multiplied.applyToRect(const Rect.fromLTWH(0, 0, 1, 2));
  final CanvasTransform? inverse = multiplied.invert();
  final Float64List matrix = multiplied.toCanvasTransform();
  multiplied.writeToCanvasTransform(Float64List(16));
  final Map<String, double> json = multiplied.toJsonMap();
  _use(point);
  _use(bounds);
  _use(inverse);
  _use(matrix);
  _use(json);

  final CanvasFieldUpdate<String> absent = CanvasFieldUpdate.absent();
  final CanvasFieldUpdate<String> set = CanvasFieldSet('value');
  final CanvasFieldUpdate<String?> clear = CanvasFieldClear<String>();
  _use(absent);
  _use(set);
  _use(clear);

  final imageUpdate = CanvasImageElementUpdate(
    id: elementId,
    resourceId: CanvasFieldSet(resourceId),
    size: const CanvasFieldUpdate.absent(),
    naturalSize: const CanvasFieldClear<Size>(),
  );
  final pathUpdate = CanvasPathElementUpdate(
    id: CanvasElementId('path-1'),
    svgPathData: const CanvasFieldSet('M 1 1 L 2 2'),
    fillColor: const CanvasFieldClear<Color>(),
    strokeColor: const CanvasFieldSet(Color(0xFF999999)),
    strokeWidth: const CanvasFieldSet(2),
    fillRule: const CanvasFieldSet(CanvasPathFillRule.nonZero),
  );
  final textUpdate = CanvasTextElementUpdate(
    id: CanvasElementId('text-1'),
    text: const CanvasFieldSet('updated'),
    fontSize: const CanvasFieldSet(18),
    color: const CanvasFieldSet(Color(0xFF444444)),
    align: const CanvasFieldSet(TextAlign.right),
    textDirection: const CanvasFieldSet(TextDirection.rtl),
    isBold: const CanvasFieldSet(false),
    isItalic: const CanvasFieldSet(false),
    isUnderline: const CanvasFieldSet(false),
    fontFamily: const CanvasFieldClear<String>(),
    maxWidth: const CanvasFieldClear<double>(),
    lineHeight: const CanvasFieldSet(1.3),
  );
  final strokeUpdate = CanvasStrokeElementUpdate(
    id: CanvasElementId('stroke-1'),
    points: const CanvasFieldSet([Offset.zero, Offset(1, 1)]),
    thickness: const CanvasFieldSet(3),
    color: const CanvasFieldSet(Color(0xFF555555)),
  );
  final lineUpdate = CanvasLineElementUpdate(
    id: CanvasElementId('line-1'),
    start: const CanvasFieldSet(Offset.zero),
    end: const CanvasFieldSet(Offset(5, 5)),
    thickness: const CanvasFieldSet(2),
    color: const CanvasFieldSet(Color(0xFF666666)),
  );
  final rectUpdate = CanvasRectElementUpdate(
    id: elementId,
    transform: CanvasFieldSet(CanvasTransform.identity),
    opacity: const CanvasFieldSet(0.5),
    hitPadding: const CanvasFieldSet(2),
    isVisible: const CanvasFieldSet(true),
    isSelectable: const CanvasFieldSet(true),
    isLocked: const CanvasFieldSet(false),
    isDeletable: const CanvasFieldSet(true),
    isTransformable: const CanvasFieldSet(true),
    metadata: CanvasFieldSet(metadata),
    size: const CanvasFieldSet(Size(12, 24)),
    fillColor: const CanvasFieldClear<Color>(),
    strokeColor: const CanvasFieldSet(Color(0xFF777777)),
    strokeWidth: const CanvasFieldSet(2),
  );
  final List<CanvasElementUpdate> updates = [
    imageUpdate,
    pathUpdate,
    textUpdate,
    strokeUpdate,
    lineUpdate,
    rectUpdate,
  ];
  _use(updates);

  final pointerSample = CanvasPointerSample(
    pointerId: 1,
    position: const Offset(6, 7),
    phase: CanvasPointerLifecyclePhase.down,
    kind: PointerDeviceKind.touch,
    timestampMs: 10,
  );
  _use(pointerSample.phase);
  _use(CanvasPointerLifecyclePhase.values);

  final previews = <CanvasPreviewState>[
    const CanvasPreviewState.none(),
    const CanvasPreviewState.marquee(rect: Rect.fromLTWH(0, 0, 1, 1)),
    const CanvasPreviewState.selectedMove(delta: Offset(1, 1)),
    CanvasPreviewState.pencilStroke(
      points: const [Offset.zero, Offset(1, 1)],
      color: const Color(0xFF000000),
      thickness: 2,
      opacity: 1,
    ),
    CanvasPreviewState.markerStroke(
      points: const [Offset.zero, Offset(1, 1)],
      color: const Color(0xFF000000),
      thickness: 4,
      opacity: 0.4,
    ),
    const CanvasPreviewState.pendingLineStart(
      start: Offset.zero,
      timestampMs: 1,
      color: Color(0xFF000000),
      thickness: 2,
    ),
    const CanvasPreviewState.linePreview(
      start: Offset.zero,
      end: Offset(3, 3),
      color: Color(0xFF000000),
      thickness: 2,
    ),
    CanvasPreviewState.eraser(
      corridor: const [Offset.zero, Offset(1, 1)],
      thickness: 10,
    ),
    CanvasPreviewState.pencilStroke(
      points: const [Offset(1, 1)],
      color: const Color(0xFF000000),
      thickness: 2,
      opacity: 1,
    ),
    CanvasPreviewState.markerStroke(
      points: const [Offset(1, 1)],
      color: const Color(0xFF000000),
      thickness: 4,
      opacity: 0.4,
    ),
    CanvasPreviewState.eraser(
      corridor: const [Offset(1, 1)],
      thickness: 10,
    ),
  ];
  final CanvasNoPreview noPreview = previews[0] as CanvasNoPreview;
  final CanvasMarqueePreview marqueePreview =
      previews[1] as CanvasMarqueePreview;
  final CanvasSelectedMovePreview selectedMovePreview =
      previews[2] as CanvasSelectedMovePreview;
  final CanvasStrokePreview pencilPreview =
      previews[3] as CanvasPencilStrokePreview;
  final CanvasMarkerStrokePreview markerPreview =
      previews[4] as CanvasMarkerStrokePreview;
  final CanvasPendingLineStartPreview pendingLinePreview =
      previews[5] as CanvasPendingLineStartPreview;
  final CanvasLinePreview linePreview = previews[6] as CanvasLinePreview;
  final CanvasEraserPreview eraserPreview =
      previews[7] as CanvasEraserPreview;
  _use(noPreview.kind);
  _use(marqueePreview.rect);
  _use(selectedMovePreview.delta);
  _use(pencilPreview.points);
  _use(markerPreview.opacity);
  _use(pendingLinePreview.timestampMs);
  _use(linePreview.end);
  _use(eraserPreview.corridor);
  _use(CanvasPreviewKind.values);

  final elementRead = CanvasElementRead(
    id: elementId,
    kind: CanvasElementKind.rect,
    revision: 1,
    boundsWorld: const Rect.fromLTWH(0, 0, 10, 20),
    transform: CanvasTransform.identity,
    isLocked: false,
    isTransformable: true,
  );
  final moveRequest = CanvasMoveCommitRequest(
    documentSummary: documentSummary,
    movedElements: [elementRead],
    proposedDelta: const Offset(1, 1),
    selectionBoundsWorld: const Rect.fromLTWH(0, 0, 10, 10),
    timestampMs: 1,
  );
  final CanvasMoveResolution moveCommit =
      const CanvasMoveCommit(delta: Offset(1, 1));
  final CanvasMoveResolution moveCancel =
      const CanvasMoveCancel(reason: 'blocked');
  _use(moveRequest.movedElements);
  _use(moveCommit);
  _use(moveCancel);
  _use(_resolveMove);

  final actionPayloads = <CanvasActionPayload>[
    CanvasTransformActionPayload(
      delta: CanvasTransform.identity,
      operation: CanvasTransformOperation.move,
      pivotWorld: Offset.zero,
    ),
    CanvasSelectionActionPayload(
      previousSelection: [elementId],
      nextSelection: [secondElementId],
      marqueeRectWorld: const Rect.fromLTWH(0, 0, 10, 10),
    ),
    CanvasDeleteActionPayload(removedElementIds: [elementId]),
    CanvasClearActionPayload(
      removedElementIds: [elementId],
      removedResourceIds: [resourceId],
    ),
    const CanvasDrawStrokeActionPayload(
      tool: CanvasDrawTool.pencil,
      color: Color(0xFF000000),
      thickness: 2,
      opacity: 1,
      pointCount: 2,
    ),
    const CanvasDrawLineActionPayload(
      color: Color(0xFF000000),
      thickness: 2,
      opacity: 1,
      startWorld: Offset.zero,
      endWorld: Offset(4, 4),
    ),
    CanvasEraseActionPayload(
      eraserThickness: 10,
      erasedElementIds: [elementId],
      corridorPointCount: 2,
    ),
    CanvasTextEditActionPayload(
      requestId: requestId,
      previousTextLength: 1,
      nextTextLength: 2,
    ),
  ];
  final action = CanvasActionCommitted(
    actionId: actionId,
    type: CanvasActionType.transformSelection,
    elementIds: [elementId],
    timestampMs: 1,
    payload: actionPayloads.first,
  );
  final contextRequest = CanvasContextActionRequested(
    requestId: requestId,
    trigger: CanvasContextActionTrigger.doubleTap,
    target: CanvasContentElementContextActionTarget(
      elementSnapshot: rectElement,
      boundsWorld: const Rect.fromLTWH(0, 0, 10, 20),
    ),
    controllerEpoch: 1,
    documentRevision: 1,
    timestampMs: 1,
    viewPosition: const Offset(1, 1),
    worldPosition: const Offset(2, 2),
  );
  final CanvasContextActionTarget emptyTarget =
      const CanvasEmptyCanvasContextActionTarget();
  _use(action.type);
  _use(actionPayloads);
  _use(CanvasActionType.values);
  _use(CanvasTransformOperation.values);
  _use(contextRequest.target);
  _use(emptyTarget);

  final disabledDiagnostics = CanvasDiagnosticPolicy.disabled();
  final summaryDiagnostics = CanvasDiagnosticPolicy.summary();
  final verboseDiagnostics = CanvasDiagnosticsVerbose(
    maxPreviewLength: 64,
    maxListEntries: 4,
  );
  _use(disabledDiagnostics);
  _use(summaryDiagnostics);
  _use(verboseDiagnostics.maxPreviewLength);

  final clearResult = CanvasClearResult(
    removedElementIds: [elementId],
    removedResourceIds: [resourceId],
    didClearContent: true,
  );
  _use(clearResult.didClearContent);

  final error = CanvasDataException(
    code: CanvasDataErrorCode.invalidJson,
    message: 'Invalid JSON.',
    path: r'\$',
    details: {'field': 'document'},
  );
  final Map<String, Object?> details = error.details;
  _use(details);
  _use(CanvasDataErrorCode.values);

  final encode = encodeCanvasDocument;
  final encodeJson = encodeCanvasDocumentToJson;
  _use(encode);
  _use(encodeJson);
  _use(canvasSchemaVersionWrite);
  _use(canvasSchemaVersionsRead);

  final resourceResolver = _ConsumerResourceResolver();
  final resourcePort = _ConsumerResourcePort(resource);
  final editPort = _ConsumerEditPort(document);
  final selectionPort = _ConsumerSelectionPort(elementId);
  final toolPort = _ConsumerToolPort(pointerSample);
  final commandPort = _ConsumerCommandPort(clearResult);
  final cameraPort = _ConsumerCameraPort(camera);
  _use(resourceResolver.resolveImage(resource));
  _use(resourcePort.resourceById(resourceId));
  _use(editPort.edit((edit) => edit.draftSummary));
  _use(selectionPort.selectedElementIds);
  _use(toolPort.pointerPolicy);
  _use(commandPort.clearContent());
  _use(cameraPort.offset);

  final Widget surface = CanvasSurface(
    runtime: runtime,
    resourceResolver: resourceResolver,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle(strokeWidth: 0.5),
    interactive: false,
  );
  final Widget textEditingOverlay = CanvasTextEditingOverlay(
    runtime: runtime,
    inlineEditOnDoubleTap: true,
    maxEditorHeight: 120,
    cursorColor: const Color(0xFF1565C0),
    selectionColor: const Color(0x331565C0),
    autofocus: false,
    commitOnFocusLoss: false,
    dismissOnEscape: true,
  );
  final selectionStyle = CanvasSelectionStyle(
    color: const Color(0xFF1565C0),
    strokeWidth: 1,
    marqueeFillOpacity: 0.2,
    haloWidth: 4,
  );
  _use(selectionStyle);
  _use(surface);
  _use(textEditingOverlay);
}

void _exerciseInlineTextEditingContractSurface(
  CanvasTextEditingPort textEditing,
  CanvasInteractionRequestId requestId,
  CanvasElementId elementId,
) {
  final geometry = CanvasTextEditGeometry(
    paintBoundsWorld: const Rect.fromLTWH(1, 2, 3, 4),
    editBoundsWorld: const Rect.fromLTWH(1, 2, 3, 4),
    transform: CanvasTransform.identity,
    maxWidth: 120,
    editBoundsLocal: const Rect.fromLTWH(0, 0, 3, 4),
  );
  final style = CanvasTextEditStyle(
    fontSize: 16,
    fontFamily: 'Roboto',
    isBold: true,
    isItalic: false,
    isUnderline: false,
    color: const Color(0xFF111111),
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
    lineHeight: 1.2,
  );
  final ValueListenable<CanvasTextEditSession?> active =
      textEditing.activeSession;
  final CanvasTextEditSession? session = active.value;
  _use(textEditing.readOnly);
  _use(textEditing.sessionCandidateFor);
  _use(textEditing.start);
  _use(textEditing.startFromContextAction);
  textEditing.setReadOnly(true);
  _use(textEditing.dismissActive);
  _use(session?.geometry ?? geometry);
  _use(session?.style ?? style);
  _use(session?.requestId ?? requestId);
  _use(session?.elementId ?? elementId);
  _use(session?.documentRevision);
  _use(session?.elementRevision);
  _use(session?.generation);
  _use(session?.initialText);
  _use(session?.liveText);
  _use(session?.isActive);
  _use(session?.isStale);
  session?.updateText('draft text');
  _use(session?.commit(timestampMs: 11));
  session?.dismiss();
}

CanvasMoveResolution _resolveMove(CanvasMoveCommitRequest request) {
  return CanvasMoveCommit(delta: request.proposedDelta);
}

final class _ConsumerResourceResolver implements CanvasResourceResolver {
  @override
  ui.Image? resolveImage(CanvasImageResource resource) => null;
}

final class _ConsumerResourcePort implements CanvasResourcePort {
  _ConsumerResourcePort(this._resource);

  final CanvasResource _resource;

  @override
  List<CanvasResource> get resources => [_resource];

  @override
  CanvasResource? resourceById(CanvasResourceId id) => _resource;

  @override
  void markAllResourcesDirty() {}

  @override
  void markResourceDirty(CanvasResourceId id) {}
}

final class _ConsumerEditPort implements CanvasEditPort {
  _ConsumerEditPort(this._document);

  final CanvasDocument _document;

  @override
  T edit<T>(T Function(CanvasEdit edit) fn) => fn(_ConsumerEdit(_document));

  @override
  void loadDocumentFromJson(String json) {}
}

final class _ConsumerEdit implements CanvasEdit {
  _ConsumerEdit(this._document);

  final CanvasDocument _document;

  @override
  CanvasDocumentSummary get draftSummary => CanvasDocumentSummary(
    elementCount: _document.layers.fold<int>(
      _document.backgroundElements.length,
      (count, layer) => count + layer.elements.length,
    ),
    layerCount: _document.layers.length,
    resourceCount: _document.resources.length,
  );

  @override
  CanvasDocument readDraftDocument() => _document;

  @override
  CanvasElementId addBackgroundElement(CanvasElement element, {int? index}) {
    return element.id;
  }

  @override
  CanvasElementId addElement(
    CanvasElement element, {
    CanvasLayerId? layerId,
    int? index,
  }) {
    return element.id;
  }

  @override
  CanvasClearResult clearContent({bool removeUnusedResources = false}) {
    return CanvasClearResult(
      removedElementIds: const [],
      removedResourceIds: const [],
      didClearContent: true,
    );
  }

  @override
  bool ensureLayer(CanvasLayerId id, {int? index}) => true;

  @override
  bool removeElement(CanvasElementId id) => true;

  @override
  bool removeUnusedResource(CanvasResourceId id) => true;

  @override
  void replaceDraftDocument(CanvasDocument document) {}

  @override
  void setBackgroundColor(Color color) {}

  @override
  void setCameraOffset(Offset offset) {}

  @override
  void setGrid(CanvasGrid grid) {}

  @override
  void setPalette(CanvasPalette palette) {}

  @override
  bool updateElement(CanvasElementUpdate update) => true;

  @override
  bool upsertResource(CanvasResource resource) => true;
}

final class _ConsumerSelectionPort implements CanvasSelectionPort {
  _ConsumerSelectionPort(this._id);

  final CanvasElementId _id;

  @override
  Set<CanvasElementId> get selectedElementIds => {_id};

  @override
  void clearSelection() {}

  @override
  void deleteSelection({int? timestampMs}) {}

  @override
  void flipSelectionHorizontal({int? timestampMs}) {}

  @override
  void flipSelectionVertical({int? timestampMs}) {}

  @override
  void moveSelection(Offset delta, {int? timestampMs}) {}

  @override
  void rotateSelectionClockwise({int? timestampMs}) {}

  @override
  void rotateSelectionCounterClockwise({int? timestampMs}) {}

  @override
  void selectAll({bool onlySelectable = true}) {}

  @override
  void setSelection(Iterable<CanvasElementId> ids) {}

  @override
  void toggleSelection(CanvasElementId id) {}
}

final class _ConsumerToolPort implements CanvasToolPort {
  _ConsumerToolPort(this._sample);

  final CanvasPointerSample _sample;

  @override
  CanvasDrawStyle get drawStyle => CanvasDrawStyle.defaultStyle;

  @override
  CanvasInteractionMode get mode => CanvasInteractionMode.move;

  @override
  CanvasPointerPolicy get pointerPolicy => CanvasPointerPolicy.defaultPolicy;

  @override
  void handleDoubleTap({required Offset position, int? timestampMs}) {}

  @override
  void handlePointer(CanvasPointerSample sample) {
    _use(_sample == sample);
  }

  @override
  void setDrawColor(Color color) {}

  @override
  void setDrawStyle(CanvasDrawStyle style) {}

  @override
  void setDrawTool(CanvasDrawTool tool) {}

  @override
  void setMode(CanvasInteractionMode mode) {}

  @override
  void setPointerPolicy(CanvasPointerPolicy policy) {}
}

final class _ConsumerCommandPort implements CanvasCommandPort {
  _ConsumerCommandPort(this._clearResult);

  final CanvasClearResult _clearResult;

  @override
  CanvasClearResult clearContent({
    bool removeUnusedResources = false,
    int? timestampMs,
  }) {
    return _clearResult;
  }

  @override
  bool commitTextEdit(
    CanvasInteractionRequestId requestId,
    String newText, {
    int? timestampMs,
  }) {
    return true;
  }

  @override
  bool removeElement(CanvasElementId id, {int? timestampMs}) => true;
}

final class _ConsumerCameraPort implements CanvasCameraPort {
  _ConsumerCameraPort(this._camera);

  final CanvasCamera _camera;

  @override
  CanvasCamera get camera => _camera;

  @override
  Offset get offset => _camera.offset;

  @override
  void panBy(Offset delta) {}

  @override
  void setOffset(Offset offset) {}
}
''';
}

String _processOutput(ProcessResult result) {
  return '''
stdout:
${result.stdout}

stderr:
${result.stderr}
''';
}
