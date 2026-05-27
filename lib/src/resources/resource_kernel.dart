import '../contracts/internal/resource_catalog_port.dart';
import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';

final class ResourceKernel implements CanvasResourcePort {
  const ResourceKernel({
    required ResourceCatalogPort catalog,
    required ResolverMutationGuard mutationGuard,
  }) : _catalog = catalog,
       _mutationGuard = mutationGuard;

  final ResourceCatalogPort _catalog;
  final ResolverMutationGuard _mutationGuard;

  @override
  List<CanvasResource> get resources => _catalog.resources;

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    return _catalog.resourceById(id);
  }

  @override
  void markResourceDirty(CanvasResourceId id) {
    _mutationGuard.ensureRuntimeMutationAllowed();
    throw UnsupportedError(
      'Resource dirty orchestration is owned by a later P7 unit.',
    );
  }

  @override
  void markAllResourcesDirty() {
    _mutationGuard.ensureRuntimeMutationAllowed();
    throw UnsupportedError(
      'Resource dirty orchestration is owned by a later P7 unit.',
    );
  }
}
