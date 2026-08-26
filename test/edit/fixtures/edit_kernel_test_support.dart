import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resolver_mutation_guard.dart';
import 'package:iwb_canvas_engine/src/edit/edit_session.dart';
import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart';
import 'package:iwb_canvas_engine/src/store/element_registry.dart';

final class AllowMutationGuard implements ResolverMutationGuard {
  AllowMutationGuard();

  bool isAllowed = true;

  @override
  void ensureRuntimeMutationAllowed() {
    if (!isAllowed) {
      throw StateError('Test mutation guard denied mutation.');
    }
  }

  @override
  T runResolverCallback<T>(T Function() callback) => callback();
}

// This test adapter mirrors the Store sparse-fact boundary so direct
// EditKernel fixtures do not create a public document projection.
// ignore: number-of-methods
final class StoreSparseFactsForTest implements SparseEditSessionFacts {
  const StoreSparseFactsForTest(this.store);

  final DocumentStoreKernel store;

  @override
  CanvasDocumentSummary get summary => store.documentSummary;

  @override
  CanvasBackground get background => store.background;

  @override
  CanvasCamera get camera => store.camera;

  @override
  CanvasPalette get palette => store.palette;

  @override
  bool hasLayer(CanvasLayerId id) => store.hasLayer(id);

  @override
  Iterable<CanvasElementId> get backgroundElementIds {
    return store.backgroundElementIds;
  }

  @override
  Iterable<CanvasElementId> get elementIds => store.elementIds;

  @override
  Iterable<CanvasLayerId> get layerIds => store.layerIds;

  @override
  Iterable<CanvasElementId> elementIdsInLayer(CanvasLayerId id) {
    return store.elementIdsInLayer(id);
  }

  @override
  Iterable<CanvasResourceId> get resourceIds => store.resourceIds;

  @override
  CanvasElement? elementById(CanvasElementId id) => store.elementById(id);

  @override
  ElementLocationFacts? elementLocationFor(CanvasElementId id) {
    return store.elementLocationFor(id);
  }

  @override
  CanvasResource? resourceById(CanvasResourceId id) => store.resourceById(id);

  @override
  int imageResourceReferenceCount(CanvasResourceId id) {
    return store.imageResourceReferenceCount(id);
  }

  @override
  int vectorResourceReferenceCount(CanvasResourceId id) {
    return store.vectorResourceReferenceCount(id);
  }
}
