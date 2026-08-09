import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/internal/surface_resource_session_lifecycle.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_prepared_vector.dart';
import '../contracts/public/canvas_resource.dart';
import 'resource_cache.dart';
import 'resource_resolver_adapter.dart';

typedef _SuppressedResolveKey = ({
  int resolverGeneration,
  CanvasResourceId resourceId,
  int resourceRevision,
});

typedef RetainedResourceBatchRelease = void Function(Set<CanvasResourceId> ids);
typedef RetainedResourcesRelease = void Function();

void _ignoreRetainedResourceBatchRelease(Set<CanvasResourceId> _) {
  return;
}

void _ignoreRetainedResourcesRelease() {
  return;
}

// The session intentionally coordinates every explicit resolver outcome in one
// owner so cache, suppression, budget, and resolver generation cannot drift.
// Its release branches stay here as well so both borrows retire in one
// synchronous order rather than being split across lifecycle helpers.
// ignore: coupling-between-object-classes, number-of-methods, weighted-methods-per-class
final class SurfaceResourceSession implements SurfaceResourceSessionLifecycle {
  SurfaceResourceSession({
    required CanvasResourceResolver? resolver,
    required ResolverMutationGuard mutationGuard,
    RetainedResourceBatchRelease releaseRetainedResources =
        _ignoreRetainedResourceBatchRelease,
    RetainedResourcesRelease releaseAllRetainedResources =
        _ignoreRetainedResourcesRelease,
    ResourceAssetCache? cache,
  }) : _resolver = resolver,
       _mutationGuard = mutationGuard,
       _releaseRetainedResources = releaseRetainedResources,
       _releaseAllRetainedResources = releaseAllRetainedResources,
       _cache = cache ?? ResourceAssetCache();

  final ResolverMutationGuard _mutationGuard;
  final RetainedResourceBatchRelease _releaseRetainedResources;
  final RetainedResourcesRelease _releaseAllRetainedResources;
  final ResourceAssetCache _cache;
  final Set<_SuppressedResolveKey> _currentFrameNullResults = {};
  CanvasResourceResolver? _resolver;
  int _resolverGeneration = 0;
  int _resolverCallsThisFrame = 0;
  bool _hasPendingBudgetFollowUpRepaint = false;
  bool _isDropped = false;

  bool get hasPendingBudgetFollowUpRepaint => _hasPendingBudgetFollowUpRepaint;
  int get resolverGeneration => _resolverGeneration;

  void beginFrameResourcePass() {
    _resolverCallsThisFrame = 0;
    _hasPendingBudgetFollowUpRepaint = false;
    _currentFrameNullResults.clear();
  }

  ResourceAssetResolveResult resolveResource(
    ResourceAssetResolveRequest request,
  ) {
    if (_isDropped) {
      return _noResolverPlaceholder(request);
    }
    final missingDescriptor = _missingDescriptorPlaceholder(request);
    if (missingDescriptor != null) {
      return missingDescriptor;
    }
    final cachedAsset = _cachedAssetResult(request);
    if (cachedAsset != null) {
      return cachedAsset;
    }
    final resolver = _resolver;
    if (resolver == null) {
      return _noResolverPlaceholder(request);
    }
    final suppressedNull = _suppressedNullPlaceholder(request);
    if (suppressedNull != null) {
      return suppressedNull;
    }
    final budgetPlaceholder = _budgetPlaceholder(request);
    if (budgetPlaceholder != null) {
      return budgetPlaceholder;
    }

    return _resolveThroughResolver(request, resolver);
  }

  ResourceAssetResolveResult? _missingDescriptorPlaceholder(
    ResourceAssetResolveRequest request,
  ) {
    if (request.hasDescriptor) {
      return null;
    }

    return MissingDescriptorResourceAssetPlaceholder(
      placeholderBounds: request.placeholderBounds,
    );
  }

  ResourceAssetResolveResult? _cachedAssetResult(
    ResourceAssetResolveRequest request,
  ) {
    final cachedAsset = _cache.read(
      resolverGeneration: _resolverGeneration,
      resourceId: request.id,
      resourceRevision: request.resourceRevision,
    );
    if (cachedAsset == null) {
      return null;
    }
    if (cachedAsset case VectorResourceAsset(
      :final prepared,
    ) when !_isLivePreparedVector(prepared)) {
      _cache.invalidateResource(request.id);

      return null;
    }

    return ResolvedResourceAsset(
      asset: cachedAsset,
      placeholderBounds: request.placeholderBounds,
    );
  }

  ResourceAssetResolveResult _noResolverPlaceholder(
    ResourceAssetResolveRequest request,
  ) {
    return NoResolverResourceAssetPlaceholder(
      placeholderBounds: request.placeholderBounds,
    );
  }

  ResourceAssetResolveResult? _suppressedNullPlaceholder(
    ResourceAssetResolveRequest request,
  ) {
    final nullKey = _suppressionKey(request);
    if (!_currentFrameNullResults.contains(nullKey)) {
      return null;
    }

    return NullResourceAssetPlaceholder(
      placeholderBounds: request.placeholderBounds,
    );
  }

  ResourceAssetResolveResult? _budgetPlaceholder(
    ResourceAssetResolveRequest request,
  ) {
    if (_resolverCallsThisFrame < kMaxSyncResourceResolverCallsPerFrame) {
      return null;
    }

    _hasPendingBudgetFollowUpRepaint = true;

    return BudgetExceededResourceAssetPlaceholder(
      placeholderBounds: request.placeholderBounds,
    );
  }

  ResourceAssetResolveResult _resolveThroughResolver(
    ResourceAssetResolveRequest request,
    CanvasResourceResolver resolver,
  ) {
    _resolverCallsThisFrame += 1;
    final resource = request.resource;
    if (resource == null) {
      throw StateError('Descriptor-backed resource request has no resource.');
    }
    final ResourceAsset? asset;
    try {
      asset = _mutationGuard.runResolverCallback(
        () => _resolveAsset(resource, resolver),
      );
    } on Object catch (error) {
      if (error is ResolverCallbackRejection) {
        rethrow;
      }

      return ResolverExceptionResourceAssetPlaceholder(
        placeholderBounds: request.placeholderBounds,
      );
    }
    if (asset == null) {
      _currentFrameNullResults.add(_suppressionKey(request));

      return NullResourceAssetPlaceholder(
        placeholderBounds: request.placeholderBounds,
      );
    }

    _cache.write(
      resolverGeneration: _resolverGeneration,
      resourceId: request.id,
      resourceRevision: request.resourceRevision,
      asset: asset,
    );

    return ResolvedResourceAsset(
      asset: asset,
      placeholderBounds: request.placeholderBounds,
    );
  }

  void replaceResolver(CanvasResourceResolver? resolver) {
    if (_isDropped) {
      return;
    }
    _resolver = resolver;
    _resolverGeneration += 1;
    _releaseAllSessionBorrows();
    _releaseAllRetainedResources();
  }

  @override
  void releaseResource(CanvasResourceId id) {
    releaseResources({id});
  }

  @override
  void releaseResources(Set<CanvasResourceId> ids) {
    if (ids.isEmpty) {
      return;
    }
    _cache.invalidateResources(ids);
    _currentFrameNullResults.removeWhere((key) => ids.contains(key.resourceId));
    _releaseRetainedResources(ids);
  }

  @override
  void releaseAllResources() {
    _releaseAllSessionBorrows();
    _releaseAllRetainedResources();
  }

  @override
  void resetForDocumentReplacement() {
    if (_isDropped) {
      return;
    }
    _resolverCallsThisFrame = 0;
    _releaseAllSessionBorrows();
    _releaseAllRetainedResources();
  }

  @override
  void drop() {
    if (_isDropped) {
      return;
    }
    _isDropped = true;
    _resolver = null;
    _resolverGeneration += 1;
    _resolverCallsThisFrame = 0;
    _releaseAllSessionBorrows();
    _releaseAllRetainedResources();
  }

  void _releaseAllSessionBorrows() {
    _hasPendingBudgetFollowUpRepaint = false;
    _cache.clear();
    _currentFrameNullResults.clear();
  }

  void dispose() {
    drop();
  }

  ResourceAsset? _resolveAsset(
    CanvasResource resource,
    CanvasResourceResolver resolver,
  ) {
    return switch (resource) {
      final CanvasImageResource image => _resolveImageAsset(image, resolver),
      final CanvasVectorResource vector => _resolveVectorAsset(
        vector,
        resolver,
      ),
    };
  }

  ResourceAsset? _resolveImageAsset(
    CanvasImageResource resource,
    CanvasResourceResolver resolver,
  ) {
    final image = resolver.resolveImage(resource);

    return image == null ? null : ImageResourceAsset(image);
  }

  ResourceAsset? _resolveVectorAsset(
    CanvasVectorResource resource,
    CanvasResourceResolver resolver,
  ) {
    final prepared = resolver.resolveVector(resource);

    if (prepared == null || !_isLivePreparedVector(prepared)) {
      return null;
    }

    return VectorResourceAsset(prepared);
  }

  bool _isLivePreparedVector(CanvasPreparedVector prepared) {
    try {
      liveCanvasPreparedVectorPicture(prepared);
      // The wrapper's internal liveness boundary intentionally signals stale
      // application-owned Pictures with StateError.
      // ignore: avoid_catching_errors
    } on StateError {
      return false;
    }

    return true;
  }

  _SuppressedResolveKey _suppressionKey(ResourceAssetResolveRequest request) {
    return (
      resolverGeneration: _resolverGeneration,
      resourceId: request.id,
      resourceRevision: request.resourceRevision,
    );
  }
}
