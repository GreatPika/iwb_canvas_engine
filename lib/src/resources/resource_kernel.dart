import '../contracts/internal/resource_catalog_port.dart';
import '../contracts/internal/resource_dirty_outcome.dart';
import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';

final class ResourceKernel implements CanvasResourcePort {
  ResourceKernel({
    required ResourceCatalogPort catalog,
    required ResolverMutationGuard mutationGuard,
    required ResourceDirtyOutcomeSink dirtyOutcomeSink,
  }) : _catalog = catalog,
       _mutationGuard = mutationGuard,
       _dirtyOutcomeSink = dirtyOutcomeSink;

  final ResourceCatalogPort _catalog;
  final ResolverMutationGuard _mutationGuard;
  final ResourceDirtyOutcomeSink _dirtyOutcomeSink;
  int _resourceVisualRevision = 0;

  int get resourceVisualRevision => _resourceVisualRevision;

  @override
  List<CanvasResource> get resources => _catalog.resources;

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    return _catalog.resourceById(id);
  }

  @override
  void markResourceDirty(CanvasResourceId id) {
    _mutationGuard.ensureRuntimeMutationAllowed();
    final resource = _catalog.resourceById(id);
    if (resource == null) {
      return;
    }

    _resourceVisualRevision += 1;
    _dirtyOutcomeSink.deliverResourceDirtyOutcome(
      ResourceDirtyOutcome(dirtyResourceIds: [id]),
    );
  }

  @override
  void markAllResourcesDirty() {
    _mutationGuard.ensureRuntimeMutationAllowed();
    if (_catalog.resourceCount == 0) {
      return;
    }

    _resourceVisualRevision += 1;
    _dirtyOutcomeSink.deliverResourceDirtyOutcome(
      ResourceDirtyOutcome(allResourcesDirty: true),
    );
  }
}
