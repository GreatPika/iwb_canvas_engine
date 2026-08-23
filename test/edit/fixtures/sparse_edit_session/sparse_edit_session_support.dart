import 'dart:ui';

import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/edit/draft_document.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';
import 'package:iwb_canvas_engine/src/store/element_registry.dart';

CanvasDocument baseSparseDocument() {
  return CanvasDocument(
    resources: [sparseImageResource('resource-a')],
    backgroundElements: [sparseRect('background-a')],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [sparseRect('content-a')],
      ),
    ],
  );
}

DraftDocument baseSparseDraft() => DraftDocument(baseSparseDocument());

CanvasRectElement sparseRect(String id) =>
    CanvasRectElement(id: CanvasElementId(id), size: const Size(1, 1));

CanvasImageResource sparseImageResource(String id) => CanvasImageResource(
  id: CanvasResourceId(id),
  source: CanvasResourceSource.appKey(id),
);

CanvasDocument supportedSizeDraftDocument({
  required int elementCount,
  required int layerCount,
}) {
  return CanvasDocument(
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-0'),
        elements: [
          for (var index = 0; index < elementCount; index += 1)
            sparseRect('element-$index'),
        ],
      ),
      for (var index = 1; index < layerCount; index += 1)
        CanvasLayer(id: CanvasLayerId('layer-$index')),
    ],
  );
}

// This fixture mirrors the complete production facts boundary. Splitting it
// would require coordinating two test ports for the same sparse-session input.
// ignore: coupling-between-object-classes, number-of-methods
final class SupportedSizeSparseFacts implements SparseEditSessionFacts {
  SupportedSizeSparseFacts({
    required this.elementCount,
    required this.layerCount,
    this.committedResourceCount = 0,
  });

  final int elementCount;
  final int layerCount;
  final int committedResourceCount;
  int locationReadCount = 0;
  int elementIdsReadCount = 0;
  int resourceIdsReadCount = 0;
  int imageResourceReferenceCountReadCount = 0;
  int vectorResourceReferenceCountReadCount = 0;

  @override
  CanvasDocumentSummary get summary => CanvasDocumentSummary(
    elementCount: elementCount,
    layerCount: layerCount,
    resourceCount: committedResourceCount,
  );

  @override
  CanvasBackground get background => const CanvasBackground();

  @override
  CanvasCamera get camera => CanvasCamera();

  @override
  CanvasPalette get palette => const CanvasPalette.defaults();

  @override
  Iterable<CanvasElementId> get backgroundElementIds => const [];

  @override
  Iterable<CanvasElementId> get elementIds {
    elementIdsReadCount += 1;
    return Iterable.generate(
      elementCount,
      (index) => CanvasElementId('element-$index'),
    );
  }

  @override
  Iterable<CanvasLayerId> get layerIds =>
      Iterable.generate(layerCount, (index) => CanvasLayerId('layer-$index'));

  @override
  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id) {
    if (id != CanvasLayerId('layer-0')) {
      return const [];
    }
    return Iterable.generate(
      elementCount,
      (index) => CanvasElementId('element-$index'),
    );
  }

  @override
  Iterable<CanvasResourceId> get resourceIds {
    resourceIdsReadCount += 1;
    return Iterable.generate(
      committedResourceCount,
      (index) => CanvasResourceId('resource-$index'),
    );
  }

  @override
  bool hasLayer(CanvasLayerId id) {
    final value = id.value;
    if (!value.startsWith('layer-')) {
      return false;
    }
    final index = int.tryParse(value.replaceFirst('layer-', ''));
    return index != null && index >= 0 && index < layerCount;
  }

  @override
  CanvasElement? elementById(CanvasElementId id) {
    final value = id.value;
    if (!value.startsWith('element-')) {
      return null;
    }
    final index = int.tryParse(value.replaceFirst('element-', ''));
    if (index == null || index < 0 || index >= elementCount) {
      return null;
    }
    if (index == 0 && committedResourceCount > 0) {
      return CanvasImageElement(
        id: id,
        resourceId: CanvasResourceId('resource-0'),
        size: const Size(1, 1),
      );
    }
    if (index == 1 && committedResourceCount > 3) {
      return CanvasVectorElement(
        id: id,
        resourceId: CanvasResourceId('resource-2'),
        size: const Size(1, 1),
      );
    }
    return CanvasRectElement(id: id, size: const Size(1, 1));
  }

  @override
  ElementLocationFacts? elementLocationFor(CanvasElementId id) {
    locationReadCount += 1;
    return elementById(id) == null
        ? null
        : ElementLocationFacts.content(CanvasLayerId('layer-0'));
  }

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    final value = id.value;
    if (!value.startsWith('resource-')) {
      return null;
    }
    final index = int.tryParse(value.replaceFirst('resource-', ''));
    if (index == null || index < 0 || index >= committedResourceCount) {
      return null;
    }
    return CanvasImageResource(
      id: id,
      source: CanvasResourceSource.appKey(value),
    );
  }

  @override
  int imageResourceReferenceCount(CanvasResourceId id) {
    imageResourceReferenceCountReadCount += 1;
    return id == CanvasResourceId('resource-0') ? 1 : 0;
  }

  @override
  int vectorResourceReferenceCount(CanvasResourceId id) {
    vectorResourceReferenceCountReadCount += 1;
    return id == CanvasResourceId('resource-2') ? 1 : 0;
  }
}

// This fixture mirrors the complete production facts boundary. Splitting it
// would require coordinating two test ports for the same sparse-session input.
// ignore: coupling-between-object-classes, number-of-methods, weighted-methods-per-class
final class SparseFixtureFacts implements SparseEditSessionFacts {
  SparseFixtureFacts(this.document);

  final CanvasDocument document;
  int elementIdsReadCount = 0;
  int resourceIdsReadCount = 0;
  int backgroundElementIdsReadCount = 0;
  int imageResourceReferenceCountReadCount = 0;
  int vectorResourceReferenceCountReadCount = 0;
  final Map<CanvasElementId, int> _elementByIdReadCounts = {};

  void resetReadCounters() {
    elementIdsReadCount = 0;
    resourceIdsReadCount = 0;
    backgroundElementIdsReadCount = 0;
    imageResourceReferenceCountReadCount = 0;
    vectorResourceReferenceCountReadCount = 0;
    _elementByIdReadCounts.clear();
  }

  int elementByIdReadCount(CanvasElementId id) {
    return _elementByIdReadCounts[id] ?? 0;
  }

  @override
  CanvasBackground get background => document.background;

  @override
  CanvasCamera get camera => document.camera;

  @override
  CanvasPalette get palette => document.palette;

  @override
  CanvasDocumentSummary get summary {
    return CanvasDocumentSummary(
      elementCount: document.backgroundElements.length + _contentElementCount,
      layerCount: document.layers.length,
      resourceCount: document.resources.length,
    );
  }

  int get _contentElementCount {
    return document.layers.fold(
      0,
      (count, layer) => count + layer.elements.length,
    );
  }

  @override
  Iterable<CanvasElementId> get backgroundElementIds {
    backgroundElementIdsReadCount += 1;

    return [for (final element in document.backgroundElements) element.id];
  }

  @override
  Iterable<CanvasElementId> get elementIds {
    elementIdsReadCount += 1;

    return [
      for (final element in document.backgroundElements) element.id,
      for (final layer in document.layers)
        for (final element in layer.elements) element.id,
    ];
  }

  @override
  Iterable<CanvasLayerId> get layerIds {
    return [for (final layer in document.layers) layer.id];
  }

  @override
  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id) {
    for (final layer in document.layers) {
      if (layer.id == id) {
        return [for (final element in layer.elements) element.id];
      }
    }

    return const <CanvasElementId>[];
  }

  @override
  bool hasLayer(CanvasLayerId id) {
    return document.layers.any((layer) => layer.id == id);
  }

  @override
  Iterable<CanvasResourceId> get resourceIds {
    resourceIdsReadCount += 1;

    return [for (final resource in document.resources) resource.id];
  }

  @override
  CanvasElement? elementById(CanvasElementId id) {
    _elementByIdReadCounts.update(id, (count) => count + 1, ifAbsent: () => 1);
    for (final element in document.backgroundElements) {
      if (element.id == id) {
        return element;
      }
    }
    for (final layer in document.layers) {
      for (final element in layer.elements) {
        if (element.id == id) {
          return element;
        }
      }
    }

    return null;
  }

  @override
  ElementLocationFacts? elementLocationFor(CanvasElementId id) {
    if (document.backgroundElements.any((element) => element.id == id)) {
      return const ElementLocationFacts.background();
    }
    for (final layer in document.layers) {
      if (layer.elements.any((element) => element.id == id)) {
        return ElementLocationFacts.content(layer.id);
      }
    }

    return null;
  }

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    for (final resource in document.resources) {
      if (resource.id == id) {
        return resource;
      }
    }

    return null;
  }

  @override
  int imageResourceReferenceCount(CanvasResourceId id) {
    imageResourceReferenceCountReadCount += 1;
    return _referenceCount(id, image: true);
  }

  @override
  int vectorResourceReferenceCount(CanvasResourceId id) {
    vectorResourceReferenceCountReadCount += 1;
    return _referenceCount(id, image: false);
  }

  int _referenceCount(CanvasResourceId id, {required bool image}) {
    var count = 0;
    for (final element in document.backgroundElements) {
      count += _matchesResourceReference(element, id, image: image) ? 1 : 0;
    }
    for (final layer in document.layers) {
      for (final element in layer.elements) {
        count += _matchesResourceReference(element, id, image: image) ? 1 : 0;
      }
    }
    return count;
  }

  bool _matchesResourceReference(
    CanvasElement element,
    CanvasResourceId id, {
    required bool image,
  }) {
    return switch (element) {
      CanvasImageElement(:final resourceId) => image && resourceId == id,
      CanvasVectorElement(:final resourceId) => !image && resourceId == id,
      _ => false,
    };
  }
}

EditSession sparseSession(DraftDocument Function() promoteDraft) {
  return sparseSessionForDocument(
    baseSparseDocument(),
    promoteDraft: promoteDraft,
  );
}

EditSession sparseSessionForDocument(
  CanvasDocument document, {
  DraftDocument Function()? promoteDraft,
  Iterable<CanvasElementId> selectedElementIds = const [],
}) {
  return EditSession.sparse(
    facts: SparseFixtureFacts(document),
    promoteDraft:
        promoteDraft ??
        () => DraftDocument(document, selectedElementIds: selectedElementIds),
    selectedElementIds: selectedElementIds,
  );
}

// One canonical typed literal seed keeps descriptor and element relationships visible.
// ignore: halstead-volume, source-lines-of-code, maintainability-index
CanvasDocument clearBackgroundResourcesDocument({
  bool includeUnusedResource = true,
}) {
  return CanvasDocument(
    resources: [
      CanvasImageResource(
        id: CanvasResourceId('background-image-resource'),
        source: CanvasResourceSource.appKey('background-image-source'),
        mimeType: 'image/png',
        contentHash: 'sha256:background-image',
        byteLength: 101,
        metadata: CanvasMetadata.fromMap({'asset': 'image', 'scale': 2}),
      ),
      CanvasVectorResource(
        id: CanvasResourceId('background-vector-resource'),
        source: CanvasResourceSource.appKey('background-vector-source'),
        contentHash: 'sha256:background-vector',
        byteLength: 202,
        metadata: CanvasMetadata.fromMap({'asset': 'vector', 'scale': 3}),
      ),
      CanvasImageResource(
        id: CanvasResourceId('content-image-resource'),
        source: CanvasResourceSource.appKey('content-image-source'),
      ),
      if (includeUnusedResource)
        CanvasVectorResource(
          id: CanvasResourceId('unused-resource'),
          source: CanvasResourceSource.appKey('unused-source'),
        ),
      if (includeUnusedResource)
        CanvasImageResource(
          id: CanvasResourceId('unused-resource-a'),
          source: CanvasResourceSource.appKey('unused-source-a'),
        ),
      if (includeUnusedResource)
        CanvasVectorResource(
          id: CanvasResourceId('unused-resource-b'),
          source: CanvasResourceSource.appKey('unused-source-b'),
        ),
      if (includeUnusedResource)
        CanvasImageResource(
          id: CanvasResourceId('unused-resource-c'),
          source: CanvasResourceSource.appKey('unused-source-c'),
        ),
      if (includeUnusedResource)
        CanvasVectorResource(
          id: CanvasResourceId('unused-resource-d'),
          source: CanvasResourceSource.appKey('unused-source-d'),
        ),
    ],
    backgroundElements: [
      CanvasImageElement(
        id: CanvasElementId('background-image'),
        resourceId: CanvasResourceId('background-image-resource'),
        size: const Size(2, 3),
        naturalSize: const Size(20, 30),
        revision: 7,
        transform: CanvasTransform.translation(const Offset(8, 9)),
        opacity: 0.75,
        hitPadding: 3,
        isVisible: false,
        isSelectable: false,
        isLocked: true,
        isDeletable: false,
        isTransformable: false,
        metadata: CanvasMetadata.fromMap({
          'role': 'background-image',
          'rank': 1,
        }),
      ),
      CanvasVectorElement(
        id: CanvasElementId('background-vector'),
        resourceId: CanvasResourceId('background-vector-resource'),
        size: const Size(4, 5),
        naturalSize: const Size(40, 50),
        revision: 8,
        transform: CanvasTransform.translation(const Offset(10, 11)),
        opacity: 0.5,
        hitPadding: 4,
        isVisible: false,
        isSelectable: false,
        isLocked: true,
        isDeletable: false,
        isTransformable: false,
        metadata: CanvasMetadata.fromMap({
          'role': 'background-vector',
          'rank': 2,
        }),
      ),
    ],
    layers: [
      CanvasLayer(
        id: CanvasLayerId('layer-a'),
        elements: [
          CanvasImageElement(
            id: CanvasElementId('content-image'),
            resourceId: CanvasResourceId('content-image-resource'),
            size: const Size(6, 7),
            isVisible: false,
            isLocked: true,
            isDeletable: false,
          ),
        ],
      ),
    ],
  );
}
