import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/selection_facts_port.dart';
import 'package:iwb_canvas_engine/src/geometry/spatial_kernel.dart';
import 'package:iwb_canvas_engine/src/interaction/interaction_read_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_interaction_read_adapter.dart';

// This bounded-read fixture keeps the fake frame and assertions together so the
// selected-handle lookup invariant is proved without weakening the main
// read-port behavior matrix.
// ignore: halstead-volume, source-lines-of-code
void testSelectedMoveStartUsesSelectedHandleLookups() {
  test(
    'selected move start derives group facts from selected handle lookups',
    () {
      final frame = _CountingFrameFactsPort([
        _frameRectFacts('unselected-before', const Offset(-100, 0), 0),
        _frameRectFacts('selected-left', const Offset(0, 0), 1),
        _frameRectFacts('unselected-between', const Offset(100, 0), 2),
        _frameRectFacts('selected-right', const Offset(30, 0), 3),
        _frameRectFacts('unselected-after', const Offset(200, 0), 4),
        for (var index = 0; index < 40; index += 1)
          _frameRectFacts(
            'far-unselected-$index',
            Offset(10000 + index * 300, 0),
            5 + index,
          ),
      ]);
      final spatial = SpatialKernel()..rebuild(frame);
      frame.resetAccessCounts();
      final adapter = RuntimeInteractionReadAdapter(
        frame: frame,
        documentSummary: () => const CanvasDocumentSummary(
          elementCount: 45,
          layerCount: 1,
          resourceCount: 0,
        ),
        selection: _SelectionFactsFixture([
          CanvasElementId('selected-right'),
          CanvasElementId('selected-left'),
        ]),
        spatial: spatial,
        controllerEpoch: () => 0,
      );

      final facts = adapter.selectedMoveStartFacts(
        const SelectedMoveStartReadRequest(worldPosition: Offset(15, 0)),
      );

      expect(facts.selectedIds, [
        CanvasElementId('selected-left'),
        CanvasElementId('selected-right'),
      ]);
      expect(
        facts.selectedGroupBoundsWorld,
        const Rect.fromLTRB(-5, -5, 35, 5),
      );
      expect(facts.insideSelectedGroupUnion, isTrue);
      expect(frame.elementHandlesCalls, 0);
      expect(frame.elementHandleForIdCalls, lessThan(frame.factCount));
    },
  );
}

FrameElementFacts _frameRectFacts(String id, Offset offset, int orderToken) {
  return FrameElementFacts(
    id: CanvasElementId(id),
    kind: CanvasElementKind.rect,
    revision: 0,
    generation: 0,
    orderToken: orderToken,
    locationKind: FrameElementLocationKind.content,
    transform: CanvasTransform.translation(offset),
    opacity: 1,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: false,
    isDeletable: true,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    size: const Size(10, 10),
  );
}

final class _SelectionFactsFixture implements SelectionFactsPort {
  _SelectionFactsFixture(Iterable<CanvasElementId> ids)
    : _selectionFacts = SelectionFacts(
        selectedElementIds: ids,
        selectionRevision: 0,
      );

  final SelectionFacts _selectionFacts;

  @override
  SelectionFacts get selectionFacts => _selectionFacts;
}

// The fake implements the full frame fact seam so the bounded-read test can
// count broad handle scans separately from selected-id lookups.
// ignore: number-of-methods
final class _CountingFrameFactsPort implements FrameFactsPort {
  _CountingFrameFactsPort(List<FrameElementFacts> facts) : _facts = facts;

  final List<FrameElementFacts> _facts;
  int elementCountCalls = 0;
  int elementHandlesCalls = 0;
  int elementHandleForIdCalls = 0;
  int get factCount => _facts.length;

  @override
  CanvasBackground get background => const CanvasBackground();

  @override
  FrameRevisionFacts get frameRevisions {
    return const FrameRevisionFacts(
      documentRevision: 0,
      structuralRevision: 0,
      boundsRevision: 0,
      elementVisualRevision: 0,
      backgroundRevision: 0,
      gridRevision: 0,
      resourceRevision: 0,
    );
  }

  void resetAccessCounts() {
    elementCountCalls = 0;
    elementHandlesCalls = 0;
    elementHandleForIdCalls = 0;
  }

  @override
  int elementCount(int structuralRevision) {
    elementCountCalls += 1;

    return _facts.length;
  }

  @override
  List<FrameElementHandle> elementHandles(int structuralRevision) {
    elementHandlesCalls += 1;

    return [for (final facts in _facts) _handleFor(facts)];
  }

  @override
  FrameElementHandle? elementHandleForId(
    int structuralRevision,
    CanvasElementId id,
  ) {
    elementHandleForIdCalls += 1;
    for (final facts in _facts) {
      if (facts.id == id) {
        return _handleFor(facts);
      }
    }

    return null;
  }

  @override
  FrameElementFacts? resolveElement(FrameElementHandle handle) {
    for (final facts in _facts) {
      if (facts.id == handle.id && facts.orderToken == handle.orderToken) {
        return facts;
      }
    }

    return null;
  }

  @override
  FrameResourceDescriptorFacts? resourceDescriptor(CanvasResourceId id) {
    return null;
  }

  FrameElementHandle _handleFor(FrameElementFacts facts) {
    return FrameElementHandle(
      id: facts.id,
      structuralRevision: 0,
      generation: facts.generation,
      orderToken: facts.orderToken,
    );
  }
}
