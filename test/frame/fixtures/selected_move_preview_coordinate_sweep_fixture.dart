// This fixture intentionally combines frame capture, the real spatial kernel,
// ordinary planning, and selected-move supplement planning so the coordinate
// sweep proves the same selected-preview path used by painting.
// ignore_for_file: number-of-imports

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_geometry.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/paint_plan.dart';
import 'package:iwb_canvas_engine/src/frame/selected_move_supplement_planner.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';

import 'ordinary_paint_test_support.dart';

const _viewport = Rect.fromLTWH(0, 0, 640, 480);
const _imageSize = Size(120, 180);
const _origin = Offset(240, 180);
final _selectedId = CanvasElementId('selected');

/// Rationale: the coordinate sweep and membership exclusion share the same
/// frame path, so this fixture keeps their paint-plan relation visible.
// ignore: halstead-volume, source-lines-of-code, reason: The sweep and membership exclusion share one real frame path.
void main() {
  test('selected image preview renders at every swept integer coordinate', () {
    final failures = <String>[];
    for (final target in _sweptTargetPositions()) {
      final outcome = _renderSelectedMoveAt(target);
      if (outcome == null) {
        failures.add('missing selected preview at ${_formatOffset(target)}');
        continue;
      }
      if (outcome.actualTranslation != outcome.expectedTranslation) {
        failures.add(
          'stale selected preview at ${_formatOffset(target)}: '
          'expected ${_formatOffset(outcome.expectedTranslation)}, '
          'got ${_formatOffset(outcome.actualTranslation)}',
        );
      }
    }

    expect(failures, isEmpty, reason: failures.take(12).join('\n'));
  });
  test('selected move preview shifts only captured participants', () {
    final frameFacts = frameFactsPort(elements: _selectedMoveRows());
    final spatialKernel = SpatialKernel()..rebuild(frameFacts);
    final frame = capturedMainFrame(
      frameFacts: frameFacts,
      selectionFacts: SelectionFacts(
        selectedElementIds: [_selectedId, CanvasElementId('neighbor')],
        selectionRevision: 2,
      ),
      selectedMoveParticipantIds: [_selectedId],
      preview: const CanvasSelectedMovePreview(delta: Offset(10, 0)),
      viewport: _viewport,
      queryPaint: spatialKernel.queryPaint,
    );
    final ordinary =
        OrdinaryPaintPlanner().buildOrdinaryPlan(frame)
            as OrdinaryPaintPlanReady;
    final output = _buildSelectedMoveSupplement(
      frame: frame,
      ordinaryPlan: ordinary.plan,
      frameFacts: frameFacts,
      spatialKernel: spatialKernel,
    );

    final selected = output.mergedRecords.singleWhere(
      (record) => record.id == _selectedId,
    );
    final newlyEligible = output.mergedRecords.singleWhere(
      (record) => record.id == CanvasElementId('neighbor'),
    );
    expect(selected.transform.translation, _origin + const Offset(10, 0));
    expect(newlyEligible.transform.translation, const Offset(8, 8));
  });
}

_SelectedMoveRenderOutcome? _renderSelectedMoveAt(Offset target) {
  final frameFacts = frameFactsPort(elements: _selectedMoveRows());
  final spatialKernel = SpatialKernel()..rebuild(frameFacts);
  final frame = _captureSelectedMoveFrame(
    target: target,
    frameFacts: frameFacts,
    spatialKernel: spatialKernel,
  );
  final ordinary =
      OrdinaryPaintPlanner().buildOrdinaryPlan(frame) as OrdinaryPaintPlanReady;
  final supplement = _buildSelectedMoveSupplement(
    frame: frame,
    ordinaryPlan: ordinary.plan,
    frameFacts: frameFacts,
    spatialKernel: spatialKernel,
  );
  final selectedRecord = supplement.mergedRecords
      .where((record) => record.id == _selectedId)
      .singleOrNull;

  if (selectedRecord == null) {
    return null;
  }

  return _SelectedMoveRenderOutcome(
    expectedTranslation: target,
    actualTranslation: selectedRecord.transform.translation,
  );
}

List<FrameElementFacts> _selectedMoveRows() {
  final selected = imageFacts(
    'selected',
    orderToken: 1,
    resourceId: CanvasResourceId('cat'),
    size: _imageSize,
  );

  return [
    _translated(selected, _origin),
    translatedRectFacts(
      'neighbor',
      orderToken: 2,
      translation: const Offset(8, 8),
    ),
  ];
}

CapturedMainFrame _captureSelectedMoveFrame({
  required Offset target,
  required TestFrameFactsPort frameFacts,
  required SpatialKernel spatialKernel,
}) {
  return capturedMainFrame(
    frameFacts: frameFacts,
    selectionFacts: SelectionFacts(
      selectedElementIds: [_selectedId],
      selectionRevision: 1,
    ),
    preview: CanvasSelectedMovePreview(delta: target - _origin),
    viewport: _viewport,
    selectedMoveParticipantIds: [_selectedId],
    queryPaint: spatialKernel.queryPaint,
  );
}

SelectedMoveSupplementPlan _buildSelectedMoveSupplement({
  required CapturedMainFrame frame,
  required PaintPlan ordinaryPlan,
  required TestFrameFactsPort frameFacts,
  required SpatialKernel spatialKernel,
}) {
  return SelectedMoveSupplementPlanner(
    frameFacts: frameFacts,
    queryPaint: spatialKernel.queryPaint,
  ).build(frame: frame, ordinaryPlan: ordinaryPlan);
}

Iterable<Offset> _sweptTargetPositions() sync* {
  for (final y in _horizontalSweepRows()) {
    for (var x = 0; x <= _viewport.width - _imageSize.width; x += 1) {
      yield Offset(x.toDouble(), y);
    }
  }
  for (final x in _verticalSweepColumns()) {
    for (var y = 0; y <= _viewport.height - _imageSize.height; y += 1) {
      yield Offset(x, y.toDouble());
    }
  }
}

List<double> _horizontalSweepRows() {
  return const [0, 1, 127, 255, 256, 257, 300];
}

List<double> _verticalSweepColumns() {
  return const [0, 1, 127, 255, 256, 257, 520];
}

String _formatOffset(Offset offset) {
  return '(${offset.dx}, ${offset.dy})';
}

FrameElementFacts _translated(FrameElementFacts facts, Offset translation) {
  return FrameElementFacts(
    id: facts.id,
    kind: facts.kind,
    revision: facts.revision,
    generation: facts.generation,
    orderToken: facts.orderToken,
    locationKind: facts.locationKind,
    transform: CanvasTransform.translation(translation),
    opacity: facts.opacity,
    hitPadding: facts.hitPadding,
    isVisible: facts.isVisible,
    isSelectable: facts.isSelectable,
    isLocked: facts.isLocked,
    isDeletable: facts.isDeletable,
    isTransformable: facts.isTransformable,
    metadata: facts.metadata,
    resourceId: facts.resourceId,
    size: facts.size,
    naturalSize: facts.naturalSize,
  );
}

final class _SelectedMoveRenderOutcome {
  const _SelectedMoveRenderOutcome({
    required this.expectedTranslation,
    required this.actualTranslation,
  });

  final Offset expectedTranslation;
  final Offset actualTranslation;
}
