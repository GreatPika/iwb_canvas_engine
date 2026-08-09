import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/frame/captured_frame.dart';
import 'package:iwb_canvas_engine/src/frame/ordinary_paint_planner.dart';
import 'package:iwb_canvas_engine/src/frame/selection_decoration_planner.dart';

import 'ordinary_paint_test_support.dart';

// This fixture keeps decoration-key churn and ordinary-key non-churn together
// so selection invalidation cannot accidentally become an ordinary cache input.
void main() {
  test(
    'selection decoration key includes stable visual inputs',
    () => expect(_expectSelectionDecorationKeyIncludesInputs(), 3),
  );

  test(
    'multi-select emits one union group primitive',
    () => expect(
      _expectMultiSelectEmitsUnionGroupPrimitive().selectedElementCount,
      2,
    ),
  );

  test(
    'single image is outside box chrome and line or stroke stays outline chrome',
    () => expect(_expectSingleImageBoxChromeAndLineStrokeOutlineChrome(), [
      SelectionDecorationStrokePlacement.outsideBox,
      SelectionDecorationStrokePlacement.boundsOutline,
      SelectionDecorationStrokePlacement.boundsOutline,
    ]),
  );

  test(
    'multi-select line and stroke selection is outside group box chrome',
    () => expect(
      _expectLineStrokeMultiSelectIsGroupBoxChrome().strokePlacement,
      SelectionDecorationStrokePlacement.outsideBox,
    ),
  );

  test(
    'structural revision change invalidates decoration placement',
    () => expect(
      _expectStructuralRevisionChangeInvalidatesDecorationPlacement(),
      SelectionDecorationStrokePlacement.boundsOutline,
    ),
  );

  test(
    'vector is outside-box alone and keeps mixed selection group chrome',
    () {
      expect(_expectVectorSelectionPlacement, returnsNormally);
    },
  );
}

void _expectVectorSelectionPlacement() {
  final vector = _singlePrimitiveFor(
    SelectionDecorationPlanner(),
    _singleSelectionFrame(
      id: 'vector',
      revision: 1,
      facts: vectorFacts(
        'vector',
        orderToken: 1,
        resourceId: CanvasResourceId('vector-resource'),
      ),
    ),
  );
  expect(vector.strokePlacement, SelectionDecorationStrokePlacement.outsideBox);

  final mixed = SelectionDecorationPlanner().build(
    capturedMainFrame(
      frameFacts: frameFactsPort(
        elements: [
          vectorFacts(
            'vector',
            orderToken: 1,
            resourceId: CanvasResourceId('vector-resource'),
          ),
          translatedRectFacts(
            'rect',
            orderToken: 2,
            translation: const Offset(20, 0),
          ),
        ],
      ),
      selectionFacts: _selection(['vector', 'rect'], revision: 2),
    ),
  );
  _expectGroupPrimitive(
    mixed.primitives.single,
    bounds: const Rect.fromLTRB(-5, -5, 25, 5),
    selectedElementCount: 2,
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
  final movedAgain = planner.build(frames.movedPreviewAgain);

  expect(again, same(first));
  _expectSingleDecorationKeyAndPrimitive(first);
  expect(changed, isNot(same(first)));
  _expectHiddenSelectionDecorationDuringMove(moved, changed);
  expect(movedAgain, same(moved));
  expect(planner.probe.selectedCount, 1);
  expect(planner.probe.rebuildCount, 3);
  expect(
    OrdinaryPaintPlanner().paintPlanKeyFor(frames.changedSelectionOnly),
    ordinaryKey,
  );

  return planner.probe.rebuildCount;
}

SelectionDecorationPrimitive _expectMultiSelectEmitsUnionGroupPrimitive() {
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
  );
  final plan = SelectionDecorationPlanner().build(frame);

  expect(plan.selectedCount, 2);
  expect(plan.primitives, hasLength(1));
  _expectGroupPrimitive(
    plan.primitives.single,
    bounds: const Rect.fromLTRB(-5, -5, 25, 5),
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

  expect(image.strokePlacement, SelectionDecorationStrokePlacement.outsideBox);
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
    selectedElementCount: 2,
  );

  return plan.primitives.single;
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
    rectPlan.primitives.single.strokePlacement,
    SelectionDecorationStrokePlacement.outsideBox,
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

  return _SingleDecorationKeyFrames(
    frame: _decorationKeyFrame(selectionFacts: selected, selectionStyle: style),
    changedBounds: _decorationKeyFrame(
      selectionFacts: selected,
      selectionStyle: style,
      boundsRevision: 11,
    ),
    changedSelectionOnly: _decorationKeyFrame(
      selectionFacts: _selection(['a', 'b'], revision: 6),
      selectionStyle: style,
    ),
    movedPreview: _selectedMoveDecorationKeyFrame(
      selectionFacts: selected,
      selectionStyle: style,
      delta: const Offset(7, 9),
      previewRevision: 12,
    ),
    movedPreviewAgain: _selectedMoveDecorationKeyFrame(
      selectionFacts: selected,
      selectionStyle: style,
      delta: const Offset(9, 11),
      previewRevision: 13,
    ),
  );
}

CapturedMainFrame _decorationKeyFrame({
  required SelectionFacts selectionFacts,
  required CanvasSelectionStyle selectionStyle,
  int boundsRevision = 10,
}) {
  return capturedMainFrame(
    frameFacts: frameFactsPort(revisions: revisionsFor(bounds: boundsRevision)),
    selectionFacts: selectionFacts,
    selectionStyle: selectionStyle,
    devicePixelRatio: 2,
  );
}

CapturedMainFrame _selectedMoveDecorationKeyFrame({
  required SelectionFacts selectionFacts,
  required CanvasSelectionStyle selectionStyle,
  required Offset delta,
  required int previewRevision,
}) {
  return capturedMainFrame(
    frameFacts: frameFactsPort(revisions: revisionsFor(bounds: 10)),
    selectionFacts: selectionFacts,
    selectionStyle: selectionStyle,
    preview: CanvasSelectedMovePreview(delta: delta),
    previewRevision: previewRevision,
    devicePixelRatio: 2,
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
  expect(plan.key.hiddenForSelectedMovePreview, isFalse);
  expect(plan.key.devicePixelRatio, 2);
  expect(plan.selectedCount, 1);
  _expectSingleBoxPrimitive(plan.primitives.single);
}

void _expectSingleBoxPrimitive(SelectionDecorationPrimitive primitive) {
  expect(primitive.boundsWorld, const Rect.fromLTRB(-5, -5, 5, 5));
  expect(primitive.selectedElementCount, 1);
  expect(primitive.chromeForm, SelectionDecorationChromeForm.singleElement);
  expect(
    primitive.strokePlacement,
    SelectionDecorationStrokePlacement.outsideBox,
  );
  expect(primitive.color, const Color(0xFF00AAFF));
  expect(primitive.strokeWidth, 3);
}

void _expectGroupPrimitive(
  SelectionDecorationPrimitive primitive, {
  required Rect bounds,
  required int selectedElementCount,
}) {
  expect(primitive.boundsWorld, bounds);
  expect(primitive.selectedElementCount, selectedElementCount);
  expect(primitive.chromeForm, SelectionDecorationChromeForm.groupBox);
  expect(
    primitive.strokePlacement,
    SelectionDecorationStrokePlacement.outsideBox,
  );
}

final class _SingleDecorationKeyFrames {
  const _SingleDecorationKeyFrames({
    required this.frame,
    required this.changedBounds,
    required this.changedSelectionOnly,
    required this.movedPreview,
    required this.movedPreviewAgain,
  });

  final CapturedMainFrame frame;
  final CapturedMainFrame changedBounds;
  final CapturedMainFrame changedSelectionOnly;
  final CapturedMainFrame movedPreview;
  final CapturedMainFrame movedPreviewAgain;
}

void _expectHiddenSelectionDecorationDuringMove(
  SelectionDecorationPlan moved,
  SelectionDecorationPlan changed,
) {
  expect(moved, isNot(same(changed)));
  expect(moved.key.hiddenForSelectedMovePreview, isTrue);
  expect(moved.primitives, isEmpty);
}
