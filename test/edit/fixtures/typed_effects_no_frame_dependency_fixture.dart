import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/commit_plan.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';

void main() {
  test('commit plan emits typed descriptions for future owners', () {
    expect(_expectTypedEffects, returnsNormally);
  });

  test('unused resource descriptor edits do not request repaint', () {
    expect(_expectUnusedResourceEditDoesNotRepaint, returnsNormally);
  });

  test('referenced resource descriptor edits request repaint', () {
    expect(_expectReferencedResourceEditRepaints, returnsNormally);
  });

  test('edit compiler and plan do not import concrete downstream owners', () {
    expect(_expectNoConcreteDownstreamImports, returnsNormally);
  });
}

void _expectTypedEffects() {
  final draft = DraftDocument(_document());

  draft.addElement(_rect('rect-2'), layerId: CanvasLayerId('layer-1'));
  final plan = draft.commitPlan;

  expect(plan.hasChanges, isTrue);
  expect(plan.documentReplaced, isFalse);
  expect(plan.effects.whereType<ProjectionEffect>(), hasLength(1));
  expect(plan.effects.whereType<SpatialEffect>(), hasLength(1));
  expect(plan.effects.whereType<RepaintEffect>(), hasLength(1));
  expect(plan.effects.whereType<PublicStateEffect>(), hasLength(1));
}

void _expectUnusedResourceEditDoesNotRepaint() {
  final draft = DraftDocument(_documentWithUnusedResource());

  draft.removeUnusedResource(CanvasResourceId('resource-1'));
  final plan = draft.commitPlan;

  expect(plan.effects.whereType<ResourceEffect>(), hasLength(1));
  expect(plan.effects.whereType<RepaintEffect>(), isEmpty);
}

void _expectReferencedResourceEditRepaints() {
  final draft = DraftDocument(_documentWithReferencedResource());

  draft.upsertResource(
    CanvasImageResource(
      id: CanvasResourceId('resource-1'),
      source: CanvasResourceSource.appKey('resource-1-updated'),
    ),
  );
  final plan = draft.commitPlan;

  expect(plan.effects.whereType<ResourceEffect>(), hasLength(1));
  expect(plan.effects.whereType<RepaintEffect>(), hasLength(1));
}

void _expectNoConcreteDownstreamImports() {
  for (final path in [
    'lib/src/edit/commit_compiler.dart',
    'lib/src/edit/commit_plan.dart',
    'lib/src/edit/touched_set.dart',
  ]) {
    final source = File(path).readAsStringSync();
    expect(source, isNot(contains("lib/src/frame/")));
    expect(source, isNot(contains("lib/src/spatial/")));
    expect(source, isNot(contains("lib/src/resources/")));
    expect(source, isNot(contains("lib/src/interaction/")));
    expect(source, isNot(contains("lib/src/surface/")));
    expect(source, isNot(contains("package:flutter/")));
    expect(source, isNot(contains("FrameEngine")));
    expect(source, isNot(contains("SpatialKernel")));
    expect(source, isNot(contains("ResourceKernel")));
    expect(source, isNot(contains("SurfaceResourceSession")));
  }
}

CanvasDocument _document() {
  return CanvasDocument(
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-1'), elements: [_rect('rect-1')]),
    ],
  );
}

CanvasDocument _documentWithUnusedResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
    ],
    layers: [
      CanvasLayer(id: CanvasLayerId('layer-1'), elements: [_rect('rect-1')]),
    ],
  );
}

CanvasDocument _documentWithReferencedResource() {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('resource-1'),
        source: CanvasResourceSource.appKey('resource-1'),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-1'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('image-1'),
            resourceId: CanvasResourceId('resource-1'),
            size: const Size(1, 1),
          ),
        ],
      ),
    ],
  );
}

CanvasRectElement _rect(String id) {
  return CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));
}
