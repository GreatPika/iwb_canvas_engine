import 'dart:ui';
import "../../support/runtime_root_with_committed_document_seed.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/geometry/geometry_policy.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('document and frame ports return committed facts only', () {
    final root = runtimeRootWithCommittedDocumentSeed(
      _document(),
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

  test('test root starts view camera from committed document camera', () {
    final root = runtimeRootWithCommittedDocumentSeed(
      _documentWithCamera(CanvasCamera(offset: const Offset(11, 13))),
      config: const CanvasRuntimeConfig(),
    );

    expect(root.readDocument().camera.offset, const Offset(11, 13));
    expect(root.cameraPort().offset, const Offset(11, 13));
    expect(root.state.value.revisions.viewCamera, 0);

    root.dispose();
  });

  _testVectorFrameDescriptor();
}

void _testVectorFrameDescriptor() {
  test('frame facts expose vector descriptors without MIME inference', () {
    final root = runtimeRootWithCommittedDocumentSeed(
      CanvasDocument(
        resources: [
          CanvasVectorResource(
            id: CanvasResourceId('vector-a'),
            source: CanvasResourceSource.appKey('vector-a'),
            contentHash: 'sha256:vector-a',
            byteLength: 42,
            metadata: CanvasMetadata.fromMap({'role': 'vector'}),
          ),
        ],
      ),
      config: const CanvasRuntimeConfig(),
    );
    final descriptor = root.frameFactsPort.resourceDescriptor(
      CanvasResourceId('vector-a'),
    );

    switch (descriptor) {
      case final FrameVectorResourceDescriptorFacts vector:
        expect(vector.appKey, 'vector-a');
        expect(vector.contentHash, 'sha256:vector-a');
        expect(vector.byteLength, 42);
        expect(vector.metadata, CanvasMetadata.fromMap({'role': 'vector'}));
      case _:
        fail('Expected a vector descriptor, got $descriptor.');
    }
    root.dispose();
  });
}

void _verifyDocumentFacts(RuntimeRoot root) {
  final documentFacts = root.documentFactsPort.documentFacts;
  expect(documentFacts.elementCount, 4);
  expect(documentFacts.layerCount, 1);
  expect(documentFacts.resourceCount, 1);
  expect(documentFacts.contentElementIds, {
    CanvasElementId('image-a'),
    CanvasElementId('rect-a'),
    CanvasElementId('text-a'),
  });
  expect(documentFacts.selectableElementIds, {
    CanvasElementId('image-a'),
    CanvasElementId('text-a'),
  });
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
    CanvasElementId('text-a'),
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

  _verifyResolvedRectFrameElement(frame);
  _verifyMeasuredTextFrameFacts(frame);
}

void _verifyResolvedRectFrameElement(FrameFactsPort frame) {
  final maybeRectFacts = frame.resolveElement(handleForRect(frame));
  expect(maybeRectFacts, isNotNull);
  final rectFacts = maybeRectFacts as FrameElementFacts;
  expect(rectFacts.fillColor, const Color(0xff112233));
  expect(rectFacts.strokeColor, const Color(0xff445566));
  expect(rectFacts.strokeWidth, 7);
}

void _verifyMeasuredTextFrameFacts(FrameFactsPort frame) {
  final maybeTextFacts = frame.resolveElement(handleForText(frame));
  expect(maybeTextFacts, isNotNull);
  final textFacts = maybeTextFacts as FrameElementFacts;
  final textLayout = textFacts.measuredTextLayout;
  expect(textLayout, isNotNull);
  if (textLayout == null) {
    fail('Expected runtime text frame facts to include measured layout.');
  }
  expect(textLayout.paintBoundsLocal.width, greaterThan(0));
  expect(
    const GeometryPolicy().boundsFor(textFacts).localBounds,
    textLayout.paintBoundsLocal,
  );
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
  final descriptor = maybeDescriptor as FrameImageResourceDescriptorFacts;
  expect(descriptor.id, CanvasResourceId('resource-a'));
  expect(descriptor.appKey, 'asset-a');
  expect(descriptor.mimeType, 'image/png');
  expect(descriptor.contentHash, 'sha256:resource-a');
  expect(descriptor.byteLength, 2048);
  expect(descriptor.resourceRevision, 0);
  expect(descriptor.metadata, CanvasMetadata.fromMap({'role': 'fixture'}));

  expect(frame.resourceDescriptor(CanvasResourceId('missing')), isNull);
}

FrameElementHandle handleForRect(FrameFactsPort frame) {
  return frame
      .elementHandles(frame.frameRevisions.structuralRevision)
      .singleWhere((handle) => handle.id == CanvasElementId('rect-a'));
}

FrameElementHandle handleForText(FrameFactsPort frame) {
  return frame
      .elementHandles(frame.frameRevisions.structuralRevision)
      .singleWhere((handle) => handle.id == CanvasElementId('text-a'));
}

void _verifyConstructedFrameFactsAreImmutable() {
  final points = [const Offset(1, 1)];
  final facts = FrameElementFacts(
    id: CanvasElementId('stroke-a'),
    kind: CanvasElementKind.stroke,
    revision: 0,
    generation: 0,
    orderToken: 0,
    locationKind: FrameElementLocationKind.content,
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
    resources: _resources(),
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
          CanvasTextElement(
            id: CanvasElementId('text-a'),
            text: 'Measured runtime text',
            fontSize: 16,
            color: const Color(0xff223344),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    ],
  );
}

CanvasDocument _documentWithCamera(CanvasCamera camera) {
  return CanvasDocument(camera: camera);
}

List<CanvasResource> _resources() {
  return [
    CanvasImageResource(
      id: CanvasResourceId('resource-a'),
      source: CanvasResourceSource.appKey('asset-a'),
      mimeType: 'image/png',
      contentHash: 'sha256:resource-a',
      byteLength: 2048,
      metadata: CanvasMetadata.fromMap({'role': 'fixture'}),
    ),
  ];
}
