import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/runtime/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('document and frame ports return committed facts only', () {
    final root = RuntimeRoot(
      initialDocument: _document(),
      config: const CanvasRuntimeConfig(),
    );

    expect(() {
      _verifyDocumentFacts(root);
      _verifyFrameElementFacts(root);
      _verifyResourceDescriptorFacts(root);
      _verifyConstructedFrameFactsAreImmutable();
    }, returnsNormally);

    root.dispose();
  });
}

void _verifyDocumentFacts(RuntimeRoot root) {
  final documentFacts = root.documentFactsPort.documentFacts;
  expect(documentFacts.elementCount, 3);
  expect(documentFacts.layerCount, 1);
  expect(documentFacts.resourceCount, 1);
  expect(documentFacts.contentElementIds, {
    CanvasElementId('image-a'),
    CanvasElementId('rect-a'),
  });
  expect(documentFacts.selectableElementIds, {CanvasElementId('image-a')});
  expect(
    () => documentFacts.contentElementIds.add(CanvasElementId('x')),
    throwsUnsupportedError,
  );
}

void _verifyFrameElementFacts(RuntimeRoot root) {
  final frame = root.frameFactsPort;
  final revisions = frame.frameRevisions;
  expect(revisions.documentRevision, 0);
  expect(revisions.structuralRevision, 0);
  expect(revisions.resourceRevision, 0);

  final handles = frame.elementHandles(revisions.structuralRevision);
  _verifyFrameHandles(handles);
  expect(frame.elementHandles(revisions.structuralRevision + 1), isEmpty);
  _verifyResolvedFrameElement(frame, handles[1]);
  _verifyStaleFrameHandle(frame, handles[1]);
}

void _verifyFrameHandles(List<FrameElementHandle> handles) {
  expect(handles.map((handle) => handle.id), [
    CanvasElementId('background-a'),
    CanvasElementId('image-a'),
    CanvasElementId('rect-a'),
  ]);
  expect(() => handles.add(handles.first), throwsUnsupportedError);
}

void _verifyResolvedFrameElement(
  FrameFactsPort frame,
  FrameElementHandle handle,
) {
  final maybeImageFacts = frame.resolveElement(handle);
  expect(maybeImageFacts, isNotNull);
  final imageFacts = maybeImageFacts as FrameElementFacts;
  expect(imageFacts.id, CanvasElementId('image-a'));
  expect(imageFacts.kind, CanvasElementKind.image);
  expect(imageFacts.orderToken, 1);
  expect(imageFacts.resourceId, CanvasResourceId('resource-a'));
  expect(imageFacts.transform, CanvasTransform.translation(const Offset(4, 5)));
  expect(imageFacts.opacity, 0.5);
  expect(imageFacts.hitPadding, 2);
  expect(imageFacts.size, const Size(2, 2));

  final maybeRectFacts = frame.resolveElement(handleForRect(frame));
  expect(maybeRectFacts, isNotNull);
  final rectFacts = maybeRectFacts as FrameElementFacts;
  expect(rectFacts.fillColor, const Color(0xff112233));
  expect(rectFacts.strokeColor, const Color(0xff445566));
  expect(rectFacts.strokeWidth, 7);
}

void _verifyStaleFrameHandle(FrameFactsPort frame, FrameElementHandle handle) {
  final stale = frame.resolveElement(
    FrameElementHandle(
      id: handle.id,
      structuralRevision: handle.structuralRevision + 1,
      generation: handle.generation,
      orderToken: handle.orderToken,
    ),
  );
  expect(stale, isNull);
  final staleGeneration = frame.resolveElement(
    FrameElementHandle(
      id: handle.id,
      structuralRevision: handle.structuralRevision,
      generation: handle.generation + 1,
      orderToken: handle.orderToken,
    ),
  );
  expect(staleGeneration, isNull);
  final staleOrderToken = frame.resolveElement(
    FrameElementHandle(
      id: handle.id,
      structuralRevision: handle.structuralRevision,
      generation: handle.generation,
      orderToken: handle.orderToken + 1,
    ),
  );
  expect(staleOrderToken, isNull);
}

void _verifyResourceDescriptorFacts(RuntimeRoot root) {
  final frame = root.frameFactsPort;
  final maybeDescriptor = frame.resourceDescriptor(
    CanvasResourceId('resource-a'),
  );
  expect(maybeDescriptor, isNotNull);
  final descriptor = maybeDescriptor as FrameResourceDescriptorFacts;
  expect(descriptor.id, CanvasResourceId('resource-a'));
  expect(descriptor.appKey, 'asset-a');
  expect(descriptor.resourceRevision, 0);

  expect(frame.resourceDescriptor(CanvasResourceId('missing')), isNull);
}

FrameElementHandle handleForRect(FrameFactsPort frame) {
  return frame
      .elementHandles(frame.frameRevisions.structuralRevision)
      .singleWhere((handle) => handle.id == CanvasElementId('rect-a'));
}

void _verifyConstructedFrameFactsAreImmutable() {
  final points = [const Offset(1, 1)];
  final facts = FrameElementFacts(
    id: CanvasElementId('stroke-a'),
    kind: CanvasElementKind.stroke,
    revision: 0,
    generation: 0,
    orderToken: 0,
    transform: CanvasTransform.identity,
    opacity: 1,
    hitPadding: 0,
    isVisible: true,
    isSelectable: true,
    isLocked: false,
    isDeletable: true,
    isTransformable: true,
    metadata: const CanvasMetadata.empty(),
    points: points,
  );
  points.add(const Offset(2, 2));

  expect(facts.points, [const Offset(1, 1)]);
  expect(() => facts.points.add(const Offset(3, 3)), throwsUnsupportedError);
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-a'),
        source: CanvasResourceSource.appKey('asset-a'),
      ),
    ],
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('background-a'),
        size: const Size(1, 1),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-a'),
            resourceId: CanvasResourceId('resource-a'),
            size: const Size(2, 2),
            transform: CanvasTransform.translation(const Offset(4, 5)),
            opacity: 0.5,
            hitPadding: 2,
          ),
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(3, 3),
            isSelectable: false,
            fillColor: const Color(0xff112233),
            strokeColor: const Color(0xff445566),
            strokeWidth: 7,
          ),
        ],
      ),
    ],
  );
}
