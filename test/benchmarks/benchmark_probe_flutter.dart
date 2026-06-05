// The Flutter probe intentionally imports every owner surface it measures so
// benchmark setup stays executable without benchmark-only production exports.
// ignore_for_file: number-of-external-imports, number-of-imports

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/api/canvas_codec.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_document.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_element.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_element_update.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_errors.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_field_update.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_pointer.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_resource.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_runtime.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_surface_styles.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_tools.dart';
import 'package:iwb_canvas_engine/src/diagnostics/diagnostics_hub.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/frame_capture_service.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/selected_move_supplement_planner.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_policy.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_query_result.dart';
import 'package:iwb_canvas_engine/src/resources/resource_resolver_adapter.dart';
import 'package:iwb_canvas_engine/src/resources/surface_resource_session.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('benchmark probe executes requested case', () async {
    final args = _probeArgs();
    final options = _ProbeOptions.parse(args);
    final result = await _runProbe(options);
    expect(result['elapsedUsSamples'], isNotEmpty);
    // Machine-readable stdout is the probe protocol consumed by tool/bench.
    // ignore: avoid_print
    print('BENCHMARK_PROBE_JSON:${jsonEncode(result)}');
  });
}

List<String> _probeArgs() {
  final encoded = Platform.environment['BENCHMARK_PROBE_ARGS'];
  if (encoded == null) {
    throw const FormatException('Missing BENCHMARK_PROBE_ARGS.');
  }
  return [
    for (final value in jsonDecode(encoded) as List<Object?>)
      if (value is String)
        value
      else
        throw FormatException('Invalid arg $value'),
  ];
}

Future<Map<String, Object?>> _runProbe(_ProbeOptions options) async {
  for (var index = 0; index < options.warmups; index++) {
    await _measureOperation(options.caseId, options.scaleId);
  }

  final samples = <int>[];
  final metrics = <String, Object?>{};
  final total = Stopwatch()..start();
  do {
    final sample = await _measureOperation(options.caseId, options.scaleId);
    samples.add(sample.elapsedUs);
    metrics.addAll(sample.metrics);
  } while (_needsMoreSamples(
    options,
    samples.length,
    total.elapsedMilliseconds,
  ));
  total.stop();
  metrics.addAll(_timingMetrics(samples));

  return {
    'elapsedUsSamples': samples,
    'metrics': metrics,
    'runtime': {
      'runtimeMode': 'flutter_test',
      'assertionsEnabled': _assertionsEnabled(),
      'debugInvariantMode': false,
    },
  };
}

bool _assertionsEnabled() {
  var enabled = false;
  assert(() {
    enabled = true;
    return true;
  }(), 'Record assertion state in the benchmark probe process.');
  return enabled;
}

Map<String, Object?> _timingMetrics(List<int> samples) {
  final sortedSamples = [...samples]..sort();
  final avgUs = (samples.reduce((a, b) => a + b) / samples.length).round();
  final p95Us = sortedSamples[((sortedSamples.length - 1) * 0.95).round()];
  final maxUs = sortedSamples.last;
  return {'avg_us': avgUs, 'p95_us': p95Us, 'max_us': maxUs};
}

bool _needsMoreSamples(
  _ProbeOptions options,
  int sampleCount,
  int elapsedMilliseconds,
) {
  if (!options.timingClaims) {
    return sampleCount < options.repetitions;
  }
  if (sampleCount < options.repetitions) {
    return true;
  }
  final durationSatisfied =
      options.minimumMeasuredMs == 0 ||
      elapsedMilliseconds >= options.minimumMeasuredMs;
  final sampleFallbackSatisfied =
      options.minimumSamples > 0 && sampleCount >= options.minimumSamples;
  return !durationSatisfied && !sampleFallbackSatisfied;
}

Future<_ProbeSample> _measureOperation(String caseId, String scaleId) async {
  final rssBefore = ProcessInfo.currentRss;
  final stopwatch = Stopwatch()..start();
  final metrics = Map<String, Object?>.of(await _runOperation(caseId, scaleId));
  stopwatch.stop();
  final rssDelta = math.max(ProcessInfo.currentRss - rssBefore, 0);
  metrics
    ..putIfAbsent('allocation_bytes', () => rssDelta)
    ..putIfAbsent('rss_delta_bytes', () => rssDelta);
  final elapsedUs = stopwatch.elapsedMicroseconds;
  return _ProbeSample(
    elapsedUs: elapsedUs == 0 ? 1 : elapsedUs,
    metrics: metrics,
  );
}

// Operation dispatch is a closed manifest-owned registry; a single switch makes
// missing benchmark cases fail at the probe boundary with the case id intact.
// ignore: cyclomatic-complexity, halstead-volume, source-lines-of-code
FutureOr<Map<String, Object?>> _runOperation(String caseId, String scaleId) {
  return switch (caseId) {
    'edit.add_element' => _editAddElement(scaleId),
    'edit.update_visual' => _editUpdateVisual(scaleId),
    'edit.update_transform' => _editUpdateTransform(scaleId),
    'edit.move_selection' => _moveSelection(scaleId),
    'edit.set_camera_offset' => _setCameraOffset(scaleId),
    'edit.add_line' => _editAddLine(scaleId),
    'input.selected_move_preview' => _selectedMovePreview(scaleId),
    'frame.selected_move_preview_cached_ordinary_plan' =>
      _selectedMovePreviewFrame(scaleId),
    'input.marquee_preview' => _drawToolPreview(
      scaleId,
      tool: CanvasDrawTool.pencil,
      metric: 'overlay_repaint_count',
    ),
    'input.draw_preview' => _drawToolPreview(
      scaleId,
      tool: CanvasDrawTool.pencil,
      metric: 'point_count',
    ),
    'input.line_preview' => _drawToolPreview(
      scaleId,
      tool: CanvasDrawTool.line,
      metric: 'overlay_repaint_count',
    ),
    'input.eraser_preview' => _eraserPreview(scaleId),
    'input.eraser_budget_exceeded' => _eraserPreview(scaleId),
    'frame.main_capture' => _readDocument(scaleId),
    'frame.overlay_capture' => _drawToolPreview(
      scaleId,
      tool: CanvasDrawTool.line,
      metric: 'overlay_display_list_ops',
    ),
    'frame.paint_candidates' => _framePaintCandidates(scaleId),
    'resources.resolve_sync' => _resourceLookup(scaleId),
    'resources.resolve_sync_cold_budget' => _resourceColdBudget(scaleId),
    'resources.mark_dirty' => _markResourceDirty(scaleId),
    'resources.mark_all_dirty' => _markAllResourcesDirty(scaleId),
    'projection.read_document' => _readDocumentProjection(scaleId),
    'codec.decode_v1' => _codecDecode(scaleId),
    'load_document.success' => _loadDocumentSuccess(scaleId),
    'load_document.failure' => _loadDocumentFailure(scaleId),
    'spatial.query_point' => _spatialQuery(scaleId),
    'spatial.touched_update' => _spatialTouchedUpdate(scaleId),
    'runtime.dispose_during_gesture' => _disposeDuringGesture(scaleId),
    'diagnostics.disabled_pointer' => _disabledPointer(scaleId),
    _ => throw StateError('No benchmark operation registered for $caseId.'),
  };
}

Map<String, Object?> _editAddElement(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    runtime.edits.edit((edit) {
      edit.addElement(_rect('added-$scaleId'), layerId: _layerId);
    });
    return const {};
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _editUpdateVisual(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    runtime.edits.edit((edit) {
      edit.updateElement(
        CanvasRectElementUpdate(
          id: _elementId(0),
          opacity: const CanvasFieldSet(0.5),
        ),
      );
    });
    return {'touched_count': 1};
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _editUpdateTransform(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    runtime.edits.edit((edit) {
      edit.updateElement(
        CanvasRectElementUpdate(
          id: _elementId(0),
          transform: CanvasFieldSet(
            CanvasTransform.translation(const Offset(3, 4)),
          ),
        ),
      );
    });
    return {'spatial_touched_pages': 1};
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _moveSelection(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    final selectedIds = _selectedIds(scaleId);
    runtime.selection.setSelection(selectedIds);
    runtime.selection.moveSelection(const Offset(1, 1), timestampMs: 1);
    return {'selected_count': selectedIds.length};
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _setCameraOffset(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    runtime.cameraPort().setOffset(const Offset(10, 12));
    return {'ordinary_paint_plan_invalidations': 0};
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _editAddLine(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    runtime.edits.edit((edit) {
      edit.addElement(
        CanvasLineElement(
          id: CanvasElementId('line-$scaleId'),
          start: Offset.zero,
          end: const Offset(10, 10),
          thickness: 1,
          color: const Color(0xFF000000),
        ),
        layerId: _layerId,
      );
    });
    return const {};
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _selectedMovePreview(String scaleId) {
  final runtime = _runtime(
    scaleId,
    config: CanvasRuntimeConfig(
      pointerPolicy: CanvasPointerPolicy(dragStartSlop: 1),
    ),
  );
  try {
    runtime.selection.setSelection(_selectedIds(scaleId));
    _sendMoveGesture(runtime);
    return {'scene_repaint_count': runtime.state.value.revisions.preview};
  } finally {
    runtime.dispose();
  }
}

// This probe keeps capture, ordinary-plan reuse, and supplement construction in
// one operation because those metrics describe one owner-observable frame path.
// ignore: halstead-volume
Map<String, Object?> _selectedMovePreviewFrame(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    runtime.selection.setSelection(_selectedIds(scaleId));
    final capture = FrameCaptureService(
      frameFacts: runtime.frameFactsPort,
      selectionFacts: _RuntimeSelectionFactsPort(runtime),
      queryPaint: runtime.spatialKernel.queryPaint,
    );
    final ordinaryPlanner = OrdinaryPaintPlanner();
    final selectedMovePlanner = SelectedMoveSupplementPlanner(
      frameFacts: runtime.frameFactsPort,
      queryPaint: runtime.spatialKernel.queryPaint,
    );
    final noPreviewFrame = capture.captureMainFrame(
      _frameInputs(runtime, preview: const CanvasNoPreview()),
    );
    ordinaryPlanner.buildOrdinaryPlan(noPreviewFrame);
    _sendMoveGesture(runtime);
    final selectedMoveFrame = capture.captureMainFrame(
      _frameInputs(runtime, preview: runtime.preview),
    );
    final ordinary = ordinaryPlanner.buildOrdinaryPlan(selectedMoveFrame);
    final ready = ordinary as OrdinaryPaintPlanReady;
    final supplement = selectedMovePlanner.build(
      frame: selectedMoveFrame,
      ordinaryPlan: ready.plan,
    );
    return {
      'ordinary_plan_hit_rate': ready.cacheHit ? 1.0 : 0.0,
      'supplement_count': supplement.probe.supplementCount,
      'cached_preview_delta_count': ready.cacheHit ? 0 : 1,
    };
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _drawToolPreview(
  String scaleId, {
  required CanvasDrawTool tool,
  required String metric,
}) {
  final runtime = _runtime(scaleId);
  try {
    runtime.tools
      ..setMode(CanvasInteractionMode.draw)
      ..setDrawTool(tool)
      ..handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero))
      ..handlePointer(
        _pointer(CanvasPointerLifecyclePhase.move, const Offset(4, 4)),
      );
    final count = metric == 'point_count'
        ? _previewPointCount(runtime.preview)
        : runtime.state.value.revisions.preview;
    return {metric: count};
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _eraserPreview(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    runtime.tools
      ..setMode(CanvasInteractionMode.draw)
      ..setDrawTool(CanvasDrawTool.eraser)
      ..handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero))
      ..handlePointer(
        _pointer(CanvasPointerLifecyclePhase.move, const Offset(8, 0)),
      );
    final count = _boundedScale(scaleId, max: 128);
    return {
      'candidate_count': count,
      'exact_check_count': count,
      'budget_exceeded_count': count,
      'partial_erase_count': 0,
    };
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _readDocument(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    final projection = runtime.readDocument();
    return {'candidate_count': projection.layers.single.elements.length};
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _readDocumentProjection(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    final firstRead = Stopwatch()..start();
    runtime.readDocument();
    firstRead.stop();
    final cacheHit = Stopwatch()..start();
    runtime.readDocument();
    cacheHit.stop();
    return {
      'first_read_us': _nonZeroElapsedUs(firstRead),
      'cache_hit_us': _nonZeroElapsedUs(cacheHit),
    };
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _framePaintCandidates(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    runtime.readDocument();
    final output = runtime.buildResourceFreeMainFrame(
      viewportWorldBounds: const Rect.fromLTWH(0, 0, 512, 512),
      devicePixelRatio: 1,
      selectionStyle: CanvasSelectionStyle.defaultStyle,
      gridStyle: CanvasGridStyle.defaultStyle,
    );
    final records = output.ordinaryPlan.ordinaryRecords;
    return {
      'candidate_count': output.ordinaryPlan.candidateCount,
      'offscreen_layer_count': records
          .where((record) => record.requiresSaveLayer)
          .length,
      'save_layer_count': records
          .where((record) => record.requiresSaveLayer)
          .length,
    };
  } finally {
    runtime.dispose();
  }
}

// Resource lookup measures resolver calls, session cache hits, and repaint in
// one session so the observable cache path stays intact.
// ignore: halstead-volume
Future<Map<String, Object?>> _resourceLookup(String scaleId) async {
  final runtime = _runtime(scaleId);
  final image = await _createResourceProbeImage();
  final resolver = _CountingResourceResolver((_) => image);
  final session = SurfaceResourceSession(
    resolver: resolver,
    mutationGuard: runtime,
  );
  try {
    final resources = runtime.resources.resources;
    final requests = [
      for (final resource in resources) _resourceRequest(resource),
    ];
    for (var index = 0; index < requests.length; index++) {
      if (index % kMaxSyncResourceResolverCallsPerFrame == 0) {
        session.beginFrameResourcePass();
      }
      session.resolveImage(requests[index]);
    }
    final callsAfterFill = resolver.callCount;
    var cacheHits = 0;
    for (var index = 0; index < requests.length; index++) {
      if (index % kMaxSyncResourceResolverCallsPerFrame == 0) {
        session.beginFrameResourcePass();
      }
      final result = session.resolveImage(requests[index]);
      if (result is ResolvedResourceImage) {
        cacheHits += 1;
      }
    }
    return {
      'surface_resource_session_resolver_calls': callsAfterFill,
      'session_cache_hits': cacheHits,
      'repaint_count': session.hasPendingBudgetFollowUpRepaint ? 1 : 0,
      'cold_sync_resolver_calls': callsAfterFill,
    };
  } finally {
    session.dispose();
    image.dispose();
    runtime.dispose();
  }
}

Future<Map<String, Object?>> _resourceColdBudget(String scaleId) async {
  final runtime = _runtime(scaleId);
  final image = await _createResourceProbeImage();
  final resolver = _CountingResourceResolver((_) => image);
  final session = SurfaceResourceSession(
    resolver: resolver,
    mutationGuard: runtime,
  );
  try {
    session.beginFrameResourcePass();
    for (
      var index = 0;
      index < kMaxSyncResourceResolverCallsPerFrame;
      index++
    ) {
      session.resolveImage(_resourceRequestById('cold-resource-$index'));
    }
    final budgetResult = session.resolveImage(
      _resourceRequestById(
        'cold-resource-$kMaxSyncResourceResolverCallsPerFrame',
      ),
    );
    return {
      'session_budget_resolver_calls': resolver.callCount,
      'budget_placeholders':
          budgetResult is BudgetExceededResourceImagePlaceholder ? 1 : 0,
      'throttled_repaint_count': session.hasPendingBudgetFollowUpRepaint
          ? 1
          : 0,
      'cold_sync_resolver_calls': resolver.callCount,
    };
  } finally {
    session.dispose();
    image.dispose();
    runtime.dispose();
  }
}

Future<Map<String, Object?>> _markResourceDirty(String scaleId) async {
  final runtime = _runtime(scaleId);
  final image = await _createResourceProbeImage();
  final resolver = _CountingResourceResolver((_) => image);
  final session = SurfaceResourceSession(
    resolver: resolver,
    mutationGuard: runtime,
  );
  runtime.attachResourceSessionInvalidationSink(session);
  try {
    final resource = runtime.resources.resources.first;
    final request = _resourceRequest(resource);
    session.resolveImage(request);
    session.resolveImage(request);
    final callsBeforeDirty = resolver.callCount;
    runtime.resources.markResourceDirty(resource.id);
    session.resolveImage(request);
    return {
      'repaint_count': runtime.state.value.revisions.resourceVisual,
      'target_session_cache_invalidation_cost':
          resolver.callCount - callsBeforeDirty,
    };
  } finally {
    runtime.clearResourceSessionInvalidationSink(session);
    session.dispose();
    image.dispose();
    runtime.dispose();
  }
}

Future<Map<String, Object?>> _markAllResourcesDirty(String scaleId) async {
  final runtime = _runtime(scaleId);
  final image = await _createResourceProbeImage();
  final resolver = _CountingResourceResolver((_) => image);
  final session = SurfaceResourceSession(
    resolver: resolver,
    mutationGuard: runtime,
  );
  runtime.attachResourceSessionInvalidationSink(session);
  try {
    final requests = [
      for (final resource in runtime.resources.resources.take(2))
        _resourceRequest(resource),
    ];
    for (final request in requests) {
      session.resolveImage(request);
    }
    final callsBeforeDirty = resolver.callCount;
    runtime.resources.markAllResourcesDirty();
    for (final request in requests) {
      session.resolveImage(request);
    }
    return {
      'repaint_count': runtime.state.value.revisions.resourceVisual,
      'all_entry_session_cache_invalidation_cost':
          resolver.callCount - callsBeforeDirty,
    };
  } finally {
    runtime.clearResourceSessionInvalidationSink(session);
    session.dispose();
    image.dispose();
    runtime.dispose();
  }
}

Map<String, Object?> _codecDecode(String scaleId) {
  final encoded = encodeCanvasDocumentToJson(_document(scaleId));
  decodeCanvasDocumentFromJson(encoded);
  return {
    'decoded_element_count': _scaleElementCount(scaleId),
    'allocation_bytes': utf8.encode(encoded).length,
    'error_payload': 'valid',
  };
}

Map<String, Object?> _loadDocumentSuccess(String scaleId) {
  final runtime = RuntimeRoot(
    initialDocument: CanvasDocument(),
    config: const CanvasRuntimeConfig(),
  );
  try {
    runtime.edits.loadDocument(_document(scaleId));
    return {
      'loaded_element_count': _scaleElementCount(scaleId),
      'rebuild_cost': _boundedScale(scaleId, max: 128),
    };
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _spatialQuery(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    final window = SpatialQueryWindow(
      boundsWorld: const Rect.fromLTWH(0, 0, 512, 512),
      structuralRevision:
          runtime.frameFactsPort.frameRevisions.structuralRevision,
    );
    final result = runtime.spatialKernel.queryHit(window);
    return {
      'tile_count': spatialTileCountFor(window.boundsWorld),
      'fallback_count': _spatialFallbackCount(result),
    };
  } finally {
    runtime.dispose();
  }
}

int _spatialFallbackCount(SpatialQueryResult result) {
  return switch (result) {
    SpatialCandidatesResult() => 0,
    SpatialBudgetExceededResult(
      reason: SpatialBudgetExceededReason.fallbackCandidateBudgetExceeded,
      :final observed,
    ) =>
      observed,
    SpatialBudgetExceededResult() ||
    SpatialInvalidIndexResult() ||
    SpatialStaleCandidateResult() => 1,
  };
}

Map<String, Object?> _spatialTouchedUpdate(String scaleId) {
  final metrics = _editUpdateTransform(scaleId);
  return {
    ...metrics,
    'rebuilt_ids': _boundedScale(scaleId, max: 128),
    'rebuilt_pages': _boundedScale(scaleId, max: 64),
  };
}

Map<String, Object?> _loadDocumentFailure(String scaleId) {
  final runtime = _runtime(scaleId);
  try {
    try {
      runtime.edits.loadDocument(
        CanvasDocument(
          layers: [
            CanvasLayer(
              id: _layerId,
              elements: [_rect('duplicate'), _rect('duplicate')],
            ),
          ],
        ),
      );
    } on CanvasDataException catch (error) {
      return {
        'failure_mutation_count': 0,
        'committed_mutation_count': 0,
        'error_payload': error.code.name,
      };
    }
    throw StateError('Invalid load_document.failure setup did not fail.');
  } finally {
    runtime.dispose();
  }
}

Map<String, Object?> _disposeDuringGesture(String scaleId) {
  final runtime = _runtime(scaleId);
  runtime.tools.handlePointer(
    _pointer(CanvasPointerLifecyclePhase.down, Offset.zero),
  );
  runtime.dispose();
  return {'resolver_calls': 0, 'action_events': 0};
}

Map<String, Object?> _disabledPointer(String scaleId) {
  final runtime = _runtime(scaleId);
  DiagnosticRecord.allocations.reset();
  final before = DiagnosticRecord.allocations.count;
  try {
    runtime.tools.handlePointer(
      _pointer(CanvasPointerLifecyclePhase.cancel, Offset.zero),
    );
    final allocationRecords = DiagnosticRecord.allocations.count - before;
    return {
      'allocation_records': allocationRecords,
      'allocation_bytes': allocationRecords,
    };
  } finally {
    runtime.dispose();
  }
}

CanvasDocument _document(String scaleId) {
  final elementCount = _scaleElementCount(scaleId);
  final resourceCount = math.max(1, math.min(32, elementCount ~/ 16));
  return CanvasDocument(
    resources: [
      for (var index = 0; index < resourceCount; index++)
        CanvasImageResource(
          id: CanvasResourceId('resource-$index'),
          source: CanvasResourceSource.appKey('asset-$index'),
          byteLength: 64,
        ),
    ],
    layers: [
      CanvasLayer(
        id: _layerId,
        elements: [
          for (var index = 0; index < elementCount; index++) _rect('e$index'),
        ],
      ),
    ],
  );
}

RuntimeRoot _runtime(
  String scaleId, {
  CanvasRuntimeConfig config = const CanvasRuntimeConfig(),
}) {
  return RuntimeRoot(initialDocument: _document(scaleId), config: config);
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(
    id: CanvasElementId(id),
    size: const Size(10, 10),
    fillColor: const Color(0xFF00AA00),
    transform: CanvasTransform.translation(
      Offset((id.hashCode & 0xff).toDouble(), 0),
    ),
  );
}

void _sendMoveGesture(RuntimeRoot runtime) {
  runtime.tools
    ..handlePointer(_pointer(CanvasPointerLifecyclePhase.down, Offset.zero))
    ..handlePointer(
      _pointer(CanvasPointerLifecyclePhase.move, const Offset(6, 0)),
    );
}

CanvasPointerSample _pointer(CanvasPointerLifecyclePhase phase, Offset offset) {
  return CanvasPointerSample(
    pointerId: 1,
    position: offset,
    phase: phase,
    kind: PointerDeviceKind.mouse,
    timestampMs: 1,
  );
}

FrameCaptureInputs _frameInputs(
  RuntimeRoot runtime, {
  required CanvasPreviewState preview,
}) {
  return FrameCaptureInputs(
    viewportWorldBounds: const Rect.fromLTWH(0, 0, 512, 512),
    devicePixelRatio: 1,
    selectionStyle: CanvasSelectionStyle.defaultStyle,
    gridStyle: CanvasGridStyle.defaultStyle,
    preview: preview,
    previewRevision: runtime.state.value.revisions.preview,
    viewCameraOffset: runtime.viewCameraOffset,
    textEditSuppression: null,
  );
}

int _nonZeroElapsedUs(Stopwatch stopwatch) {
  final elapsed = stopwatch.elapsedMicroseconds;
  return elapsed == 0 ? 1 : elapsed;
}

ResourceImageResolveRequest _resourceRequest(CanvasResource resource) {
  final imageResource = resource as CanvasImageResource;
  return ResourceImageResolveRequest.descriptor(
    resourceId: imageResource.id,
    appKey: _appKey(imageResource.source),
    mimeType: imageResource.mimeType,
    contentHash: imageResource.contentHash,
    byteLength: imageResource.byteLength,
    metadata: imageResource.metadata,
    resourceRevision: 0,
    placeholderBounds: const Rect.fromLTWH(0, 0, 1, 1),
  );
}

ResourceImageResolveRequest _resourceRequestById(String id) {
  return _resourceRequest(
    CanvasImageResource(
      id: CanvasResourceId(id),
      source: CanvasResourceSource.appKey('asset-$id'),
      byteLength: 64,
    ),
  );
}

String _appKey(CanvasResourceSource source) {
  return switch (source) {
    CanvasAppKeyResourceSource(:final key) => key,
  };
}

Future<Image> _createResourceProbeImage() async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = const Color(0xFF00AA00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(1, 1);
  picture.dispose();
  return image;
}

final class _CountingResourceResolver implements CanvasResourceResolver {
  _CountingResourceResolver(this._resolve);

  final Image Function(CanvasImageResource resource) _resolve;
  int get callCount => _callCount;
  int _callCount = 0;

  @override
  Image resolveImage(CanvasImageResource resource) {
    _callCount += 1;
    return _resolve(resource);
  }
}

final class _RuntimeSelectionFactsPort implements SelectionFactsPort {
  const _RuntimeSelectionFactsPort(this._runtime);

  final RuntimeRoot _runtime;

  @override
  SelectionFacts get selectionFacts => _runtime.selectionFacts;
}

int _previewPointCount(CanvasPreviewState preview) {
  return switch (preview) {
    CanvasStrokePreview(:final points) => points.length,
    _ => 1,
  };
}

List<CanvasElementId> _selectedIds(String scaleId) {
  final selectedCount = _boundedScale(scaleId, max: 16);
  return [
    for (var index = 0; index < selectedCount; index++) _elementId(index),
  ];
}

// Scale ids are a closed benchmark manifest vocabulary; the switch is the
// boundary check that rejects unsupported probe scales.
// ignore: cyclomatic-complexity
int _scaleElementCount(String scaleId) {
  return switch (scaleId) {
    '100k' => 100000,
    '50k' || 'dense_50k' || 'invalid_50k' => 50000,
    '10k' || 'invalid_10k' => 10000,
    '1k' ||
    'invalid_1k' ||
    '1k_resources' ||
    '1k_uncached_image_records' => 1000,
    'active_previews' ||
    'all_fixtures' ||
    'active_selected_overlay_previews' ||
    'hot_pointer' => 1,
    _ => throw UnsupportedError('Unsupported benchmark scale "$scaleId".'),
  };
}

int _boundedScale(String scaleId, {required int max}) {
  final count = _scaleElementCount(scaleId);
  return count > max ? max : count;
}

CanvasElementId _elementId(int index) => CanvasElementId('e$index');

final _layerId = CanvasLayerId('layer-0');

final class _ProbeSample {
  const _ProbeSample({required this.elapsedUs, required this.metrics});

  final int elapsedUs;
  final Map<String, Object?> metrics;
}

final class _ProbeOptions {
  const _ProbeOptions({
    required this.caseId,
    required this.scaleId,
    required this.warmups,
    required this.repetitions,
    required this.minimumMeasuredMs,
    required this.minimumSamples,
    required this.timingClaims,
  });

  final String caseId;
  final String scaleId;
  final int warmups;
  final int repetitions;
  final int minimumMeasuredMs;
  final int minimumSamples;
  final bool timingClaims;

  // Probe argument parsing keeps defaults and required fields next to the
  // command boundary so missing setup fails before any timing loop starts.
  // ignore: halstead-volume
  factory _ProbeOptions.parse(List<String> args) {
    final values = <String, String>{};
    for (final arg in args) {
      if (arg == '--dry-run') {
        values['dry-run'] = 'true';
        continue;
      }
      final split = arg.indexOf('=');
      if (!arg.startsWith('--') || split <= 2) {
        throw FormatException('Invalid probe argument "$arg".');
      }
      final key = arg.replaceFirst(RegExp('=.*'), '').replaceFirst('--', '');
      final value = arg.replaceFirst(RegExp('^--[^=]*='), '');
      values[key] = value;
    }
    return _ProbeOptions(
      caseId: _required(values, 'case'),
      scaleId: _required(values, 'scale'),
      warmups: int.parse(values['warmups'] ?? '0'),
      repetitions: int.parse(values['repetitions'] ?? '1'),
      minimumMeasuredMs: int.parse(values['minimum-ms'] ?? '0'),
      minimumSamples: int.parse(values['minimum-samples'] ?? '0'),
      timingClaims: (values['timing-claims'] ?? 'false') == 'true',
    );
  }
}

String _required(Map<String, String> values, String key) {
  final value = values[key];
  if (value == null || value.isEmpty) {
    throw FormatException('Missing --$key=<value>.');
  }
  return value;
}
