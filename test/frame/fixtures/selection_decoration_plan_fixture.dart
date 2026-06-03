import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_ids.dart';
import 'package:iwb_canvas_engine/src/contracts/public/canvas_preview.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/selection_decoration_planner.dart';

import 'ordinary_paint_test_support.dart';

// This fixture keeps decoration-key churn and ordinary-key non-churn together
// so selection invalidation cannot accidentally become an ordinary cache input.
void main() {
  test(
    'selection decoration key includes selection, style, DPR, and bounds',
    () => expect(_expectSelectionDecorationKeyIncludesInputs(), 3),
  );

  test(
    'multi-select emits one ordered union group primitive',
    () => expect(
      _expectMultiSelectEmitsOrderedUnionGroupPrimitive().selectedElementCount,
      2,
    ),
  );

  test(
    'single image is box chrome and line or stroke stays outline chrome',
    () => expect(_expectSingleImageBoxChromeAndLineStrokeOutlineChrome(), [
      SelectionDecorationStrokePlacement.insideBox,
      SelectionDecorationStrokePlacement.boundsOutline,
      SelectionDecorationStrokePlacement.boundsOutline,
    ]),
  );

  test(
    'multi-select line and stroke selection is group box chrome',
    () => expect(
      _expectLineStrokeMultiSelectIsGroupBoxChrome().strokePlacement,
      SelectionDecorationStrokePlacement.insideBox,
    ),
  );

  test(
    'selected top order change invalidates decoration key',
    () => expect(_expectSelectedTopOrderChangeInvalidatesDecorationKey(), 5),
  );

  test(
    'structural revision change invalidates decoration placement',
    () => expect(
      _expectStructuralRevisionChangeInvalidatesDecorationPlacement(),
      SelectionDecorationStrokePlacement.boundsOutline,
    ),
  );
}

int _expectSelectionDecorationKeyIncludesInputs() {
  final frames = _singleDecorationKeyFrames();
  final ordinaryKey = OrdinaryPaintPlanner().paintPlanKeyFor(frames.frame);
  final planner = SelectionDecorationPlanner();

  final first = planner.build(frames.frame);
  final again = planner.build(frames.frame);
  final changed = planner.build(frames.changedBounds);
  final moved = planner.build(frames.movedPreview);

  expect(again, same(first));
  _expectSingleDecorationKeyAndPrimitive(first);
  expect(changed, isNot(same(first)));
  _expectMovedSelectionDecoration(moved, changed);
  expect(planner.probe.selectedCount, 1);
  expect(planner.probe.rebuildCount, 3);
  expect(
    OrdinaryPaintPlanner().paintPlanKeyFor(frames.changedSelectionOnly),
    ordinaryKey,
  );

  return planner.probe.rebuildCount;
}

SelectionDecorationPrimitive
_expectMultiSelectEmitsOrderedUnionGroupPrimitive() {
  final frame = capturedMainFrame(
    frameFacts: frameFactsPort(
      elements: [
        translatedRectFacts(
          'a',
          orderToken: 10,
          translation: const Offset(20, 0),
        ),
        rectFacts('b', orderToken: 2),
      ],
    ),
    selectionFacts: SelectionFacts(
      selectedElementIds: [CanvasElementId('b'), CanvasElementId('a')],
      selectionRevision: 1,
    ),
    preview: const CanvasSelectedMovePreview(delta: Offset(3, 4)),
    previewRevision: 2,
  );
  final plan = SelectionDecorationPlanner().build(frame);

  expect(plan.selectedCount, 2);
  expect(plan.key.selectedTopOrderToken, 10);
  expect(plan.primitives, hasLength(1));
  _expectGroupPrimitive(
    plan.primitives.single,
    bounds: const Rect.fromLTRB(-2, -1, 28, 9),
    paintOrderToken: 10,
    selectedElementCount: 2,
  );

  return plan.primitives.single;
}

List<SelectionDecorationStrokePlacement>
_expectSingleImageBoxChromeAndLineStrokeOutlineChrome() {
  final planner = SelectionDecorationPlanner();
  final image = _singlePrimitiveFor(
    planner,
    _singleSelectionFrame(
      id: 'image',
      revision: 1,
      facts: imageFacts(
        'image',
        orderToken: 3,
        resourceId: CanvasResourceId('image-resource'),
      ),
    ),
  );
  final line = _singlePrimitiveFor(
    planner,
    _singleSelectionFrame(
      id: 'line',
      revision: 2,
      facts: lineFacts('line', orderToken: 4),
    ),
  );
  final stroke = _singlePrimitiveFor(
    planner,
    _singleSelectionFrame(
      id: 'stroke',
      revision: 3,
      facts: strokeFacts('stroke', orderToken: 5),
    ),
  );

  expect(image.strokePlacement, SelectionDecorationStrokePlacement.insideBox);
  expect(
    line.strokePlacement,
    SelectionDecorationStrokePlacement.boundsOutline,
  );
  expect(
    stroke.strokePlacement,
    SelectionDecorationStrokePlacement.boundsOutline,
  );

  return [image.strokePlacement, line.strokePlacement, stroke.strokePlacement];
}

SelectionDecorationPrimitive _expectLineStrokeMultiSelectIsGroupBoxChrome() {
  final plan = SelectionDecorationPlanner().build(
    capturedMainFrame(
      frameFacts: frameFactsPort(
        elements: [
          lineFacts('line', orderToken: 4),
          translatedStrokeFacts(
            'stroke',
            orderToken: 8,
            translation: const Offset(20, 0),
          ),
        ],
      ),
      selectionFacts: SelectionFacts(
        selectedElementIds: [
          CanvasElementId('line'),
          CanvasElementId('stroke'),
        ],
        selectionRevision: 1,
      ),
    ),
  );

  expect(plan.primitives, hasLength(1));
  _expectGroupPrimitive(
    plan.primitives.single,
    bounds: const Rect.fromLTRB(-1, -1, 31, 11),
    paintOrderToken: 8,
    selectedElementCount: 2,
  );

  return plan.primitives.single;
}

int _expectSelectedTopOrderChangeInvalidatesDecorationKey() {
  final selected = _selection(['a', 'b'], revision: 1);
  final planner = SelectionDecorationPlanner();
  final first = planner.build(
    capturedMainFrame(
      frameFacts: frameFactsPort(
        elements: [
          rectFacts('a', orderToken: 1),
          rectFacts('b', orderToken: 2),
        ],
      ),
      selectionFacts: selected,
    ),
  );
  final reordered = planner.build(
    capturedMainFrame(
      frameFacts: frameFactsPort(
        elements: [
          rectFacts('a', orderToken: 5),
          rectFacts('b', orderToken: 2),
        ],
      ),
      selectionFacts: selected,
    ),
  );

  expect(reordered, isNot(same(first)));
  expect(first.key.selectedTopOrderToken, 2);
  expect(reordered.key.selectedTopOrderToken, 5);
  expect(reordered.primitives.single.paintOrderToken, 5);

  return reordered.primitives.single.paintOrderToken;
}

SelectionDecorationStrokePlacement
_expectStructuralRevisionChangeInvalidatesDecorationPlacement() {
  final selected = _selection(['a'], revision: 1);
  final planner = SelectionDecorationPlanner();
  final rectPlan = _singleSelectionPlan(
    planner,
    selected: selected,
    revisions: revisionsFor(structural: 10, bounds: 10),
    facts: rectFacts('a', orderToken: 1),
  );
  final linePlan = _singleSelectionPlan(
    planner,
    selected: selected,
    revisions: revisionsFor(structural: 11, bounds: 10),
    facts: lineFacts('a', orderToken: 1),
  );

  expect(linePlan, isNot(same(rectPlan)));
  expect(rectPlan.key.structuralRevision, 10);
  expect(linePlan.key.structuralRevision, 11);
  expect(
    rectPlan.key.selectedTopOrderToken,
    linePlan.key.selectedTopOrderToken,
  );
  expect(
    rectPlan.primitives.single.strokePlacement,
    SelectionDecorationStrokePlacement.insideBox,
  );
  expect(
    linePlan.primitives.single.strokePlacement,
    SelectionDecorationStrokePlacement.boundsOutline,
  );

  return linePlan.primitives.single.strokePlacement;
}

SelectionDecorationPlan _singleSelectionPlan(
  SelectionDecorationPlanner planner, {
  required SelectionFacts selected,
  required FrameRevisionFacts revisions,
  required FrameElementFacts facts,
}) {
  return planner.build(
    capturedMainFrame(
      frameFacts: frameFactsPort(revisions: revisions, elements: [facts]),
      selectionFacts: selected,
    ),
  );
}

_SingleDecorationKeyFrames _singleDecorationKeyFrames() {
  final selected = _selection(['a'], revision: 5);
  final style = selectionStyleFor(
    color: const Color(0xFF00AAFF),
    strokeWidth: 3,
  );
  final frame = capturedMainFrame(
    frameFacts: frameFactsPort(revisions: revisionsFor(bounds: 10)),
    selectionFacts: selected,
    selectionStyle: style,
    devicePixelRatio: 2,
  );

  return _SingleDecorationKeyFrames(
    frame: frame,
    changedBounds: capturedMainFrame(
      frameFacts: frameFactsPort(revisions: revisionsFor(bounds: 11)),
      selectionFacts: selected,
      selectionStyle: style,
      devicePixelRatio: 2,
    ),
    changedSelectionOnly: capturedMainFrame(
      frameFacts: frameFactsPort(revisions: revisionsFor(bounds: 10)),
      selectionFacts: _selection(['a', 'b'], revision: 6),
      selectionStyle: style,
      devicePixelRatio: 2,
    ),
    movedPreview: capturedMainFrame(
      frameFacts: frameFactsPort(revisions: revisionsFor(bounds: 10)),
      selectionFacts: selected,
      selectionStyle: style,
      preview: const CanvasSelectedMovePreview(delta: Offset(7, 9)),
      previewRevision: 12,
      devicePixelRatio: 2,
    ),
  );
}

CapturedMainFrame _singleSelectionFrame({
  required String id,
  required int revision,
  required FrameElementFacts facts,
}) {
  return capturedMainFrame(
    frameFacts: frameFactsPort(elements: [facts]),
    selectionFacts: _selection([id], revision: revision),
  );
}

SelectionDecorationPrimitive _singlePrimitiveFor(
  SelectionDecorationPlanner planner,
  CapturedMainFrame frame,
) {
  return planner.build(frame).primitives.single;
}

SelectionFacts _selection(List<String> ids, {required int revision}) {
  return SelectionFacts(
    selectedElementIds: [for (final id in ids) CanvasElementId(id)],
    selectionRevision: revision,
  );
}

void _expectSingleDecorationKeyAndPrimitive(SelectionDecorationPlan plan) {
  expect(plan.key.selectionRevision, 5);
  expect(plan.key.selectedElementIds, {CanvasElementId('a')});
  expect(plan.key.structuralRevision, 2);
  expect(plan.key.boundsRevision, 10);
  expect(plan.key.selectedTopOrderToken, 1);
  expect(plan.key.selectedMoveDelta, Offset.zero);
  expect(plan.key.previewRevision, 0);
  expect(plan.key.devicePixelRatio, 2);
  expect(plan.selectedCount, 1);
  _expectSingleBoxPrimitive(plan.primitives.single);
}

void _expectSingleBoxPrimitive(SelectionDecorationPrimitive primitive) {
  expect(primitive.boundsWorld, const Rect.fromLTRB(-5, -5, 5, 5));
  expect(primitive.paintOrderToken, 1);
  expect(primitive.selectedElementCount, 1);
  expect(primitive.chromeForm, SelectionDecorationChromeForm.singleElement);
  expect(
    primitive.strokePlacement,
    SelectionDecorationStrokePlacement.insideBox,
  );
  expect(primitive.color, const Color(0xFF00AAFF));
  expect(primitive.strokeWidth, 3);
}

void _expectGroupPrimitive(
  SelectionDecorationPrimitive primitive, {
  required Rect bounds,
  required int paintOrderToken,
  required int selectedElementCount,
}) {
  expect(primitive.boundsWorld, bounds);
  expect(primitive.paintOrderToken, paintOrderToken);
  expect(primitive.selectedElementCount, selectedElementCount);
  expect(primitive.chromeForm, SelectionDecorationChromeForm.groupBox);
  expect(
    primitive.strokePlacement,
    SelectionDecorationStrokePlacement.insideBox,
  );
}

final class _SingleDecorationKeyFrames {
  const _SingleDecorationKeyFrames({
    required this.frame,
    required this.changedBounds,
    required this.changedSelectionOnly,
    required this.movedPreview,
  });

  final CapturedMainFrame frame;
  final CapturedMainFrame changedBounds;
  final CapturedMainFrame changedSelectionOnly;
  final CapturedMainFrame movedPreview;
}

void _expectMovedSelectionDecoration(
  SelectionDecorationPlan moved,
  SelectionDecorationPlan changed,
) {
  expect(moved, isNot(same(changed)));
  expect(moved.key.selectedMoveDelta, const Offset(7, 9));
  expect(moved.key.previewRevision, 12);
  expect(
    moved.primitives.single.boundsWorld,
    const Rect.fromLTRB(2, 4, 12, 14),
  );
}
