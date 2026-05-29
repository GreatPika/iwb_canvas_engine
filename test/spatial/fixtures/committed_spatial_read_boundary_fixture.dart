import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/frame_facts_port.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  _testCommittedScopeFacts();
  _testHandleValidation();
  _testFactsOnlyBoundaryShape();
}

void _testCommittedScopeFacts() {
  test('committed frame facts expose spatial scope facts', () {
    final root = RuntimeRoot(
      initialDocument: _document(),
      config: const CanvasRuntimeConfig(),
    );

    final frame = root.frameFactsPort;
    final handles = frame.elementHandles(
      frame.frameRevisions.structuralRevision,
    );
    expect(handles.map((handle) => handle.id), [
      CanvasElementId('background-a'),
      CanvasElementId('rect-a'),
    ]);

    _expectBackgroundScopeFacts(frame, handles);
    _expectContentScopeFacts(frame, handles);

    root.dispose();
  });
}

void _testHandleValidation() {
  test('scope facts do not weaken handle validation', () {
    final root = RuntimeRoot(
      initialDocument: _document(),
      config: const CanvasRuntimeConfig(),
    );

    final frame = root.frameFactsPort;
    final handle = frame
        .elementHandles(frame.frameRevisions.structuralRevision)
        .singleWhere((candidate) => candidate.id == CanvasElementId('rect-a'));
    expect(handle.orderToken, 1);

    _expectHandleValidation(frame, handle);

    root.dispose();
  });
}

void _testFactsOnlyBoundaryShape() {
  test('spatial scope facts are facts-only and do not expose store tables', () {
    final frameFactsPort = _frameFactsPortSource();
    expect(frameFactsPort, contains('abstract interface class FrameFactsPort'));

    _expectFrameFactsPortScopeFields(frameFactsPort);
    _expectNoStoreTablesInFrameFactsPort(frameFactsPort);
    _expectScopeFieldsStayOutOfHandleIdentity(frameFactsPort);
  });
}

void _expectBackgroundScopeFacts(
  FrameFactsPort frame,
  List<FrameElementHandle> handles,
) {
  final background = _resolved(frame, handles, 'background-a');
  expect(background.locationKind, FrameElementLocationKind.background);
  expect(background.layerId, isNull);
}

void _expectContentScopeFacts(
  FrameFactsPort frame,
  List<FrameElementHandle> handles,
) {
  final content = _resolved(frame, handles, 'rect-a');
  expect(content.locationKind, FrameElementLocationKind.content);
  expect(content.layerId, CanvasLayerId('layer-a'));
}

void _expectHandleValidation(FrameFactsPort frame, FrameElementHandle handle) {
  expect(frame.resolveElement(handle), isNotNull);
  expect(frame.resolveElement(_withStructuralRevision(handle, 1)), isNull);
  expect(frame.resolveElement(_withGeneration(handle, 1)), isNull);
  expect(frame.resolveElement(_withOrderToken(handle, 0)), isNull);
}

void _expectFrameFactsPortScopeFields(String frameFactsPort) {
  expect(frameFactsPort, contains('final CanvasLayerId? layerId'));
  expect(frameFactsPort, contains('FrameElementLocationKind'));
}

void _expectNoStoreTablesInFrameFactsPort(String frameFactsPort) {
  expect(frameFactsPort, isNot(contains('StoreElement')));
  expect(frameFactsPort, isNot(contains('DocumentStoreKernel')));
  expect(frameFactsPort, isNot(contains('LayerTable')));
}

void _expectScopeFieldsStayOutOfHandleIdentity(String frameFactsPort) {
  final handleConstructor = RegExp(
    r'FrameElementHandle\s*\(\{(?<body>[\s\S]*?)\n\s*\}\);',
  ).firstMatch(frameFactsPort)?.namedGroup('body');
  expect(handleConstructor, isNotNull);
  expect(handleConstructor, isNot(contains('locationKind')));
  expect(handleConstructor, isNot(contains('layerId')));
}

String _frameFactsPortSource() {
  return File(
    'lib/src/contracts/internal/frame_facts_port.dart',
  ).readAsStringSync();
}

FrameElementFacts _resolved(
  FrameFactsPort frame,
  List<FrameElementHandle> handles,
  String id,
) {
  final handle = handles.singleWhere(
    (candidate) => candidate.id == CanvasElementId(id),
  );
  final facts = frame.resolveElement(handle);
  expect(facts, isNotNull);

  return facts as FrameElementFacts;
}

FrameElementHandle _withStructuralRevision(
  FrameElementHandle handle,
  int delta,
) {
  return FrameElementHandle(
    id: handle.id,
    structuralRevision: handle.structuralRevision + delta,
    generation: handle.generation,
    orderToken: handle.orderToken,
  );
}

FrameElementHandle _withGeneration(FrameElementHandle handle, int delta) {
  return FrameElementHandle(
    id: handle.id,
    structuralRevision: handle.structuralRevision,
    generation: handle.generation + delta,
    orderToken: handle.orderToken,
  );
}

FrameElementHandle _withOrderToken(FrameElementHandle handle, int orderToken) {
  return FrameElementHandle(
    id: handle.id,
    structuralRevision: handle.structuralRevision,
    generation: handle.generation,
    orderToken: orderToken,
  );
}

CanvasDocument _document() {
  return CanvasDocument(
    backgroundElements: [
      CanvasRectElement(
        id: CanvasElementId('background-a'),
        size: const Size(10, 10),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasRectElement(
            id: CanvasElementId('rect-a'),
            size: const Size(20, 20),
          ),
        ],
      ),
    ],
  );
}
