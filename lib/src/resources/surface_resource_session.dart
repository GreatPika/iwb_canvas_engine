import 'dart:ui' as ui;

import '../contracts/internal/resolver_mutation_guard.dart';
import '../contracts/internal/surface_resource_session_lifecycle.dart';
import '../contracts/public/canvas_ids.dart';
import '../contracts/public/canvas_resource.dart';
import 'resource_cache.dart';
import 'resource_resolver_adapter.dart';

typedef _SuppressedResolveKey = ({
  int resolverGeneration,
  CanvasResourceId resourceId,
  int resourceRevision,
});

// The session intentionally coordinates every explicit resolver outcome in one
// owner so cache, suppression, budget, and resolver generation cannot drift.
// ignore: coupling-between-object-classes, number-of-methods
final class SurfaceResourceSession implements SurfaceResourceSessionLifecycle {
  SurfaceResourceSession({
    required CanvasResourceResolver? resolver,
    required ResolverMutationGuard mutationGuard,
    ImageResolveCache? cache,
  }) : _resolver = resolver,
       _mutationGuard = mutationGuard,
       _cache = cache ?? ImageResolveCache();

  final ResolverMutationGuard _mutationGuard;
  final ImageResolveCache _cache;
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

  ResourceImageResolveResult resolveImage(ResourceImageResolveRequest request) {
    if (_isDropped) {
      return _noResolverPlaceholder(request);
    }
    final missingDescriptor = _missingDescriptorPlaceholder(request);
    if (missingDescriptor != null) {
      return missingDescriptor;
    }
    final cachedImage = _cachedImageResult(request);
    if (cachedImage != null) {
      return cachedImage;
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

  ResourceImageResolveResult? _missingDescriptorPlaceholder(
    ResourceImageResolveRequest request,
  ) {
    if (request.hasDescriptor) {
      return null;
    }

    return MissingDescriptorResourceImagePlaceholder(
      placeholderBounds: request.placeholderBounds,
    );
  }

  ResourceImageResolveResult? _cachedImageResult(
    ResourceImageResolveRequest request,
  ) {
    final cachedImage = _cache.read(
      resolverGeneration: _resolverGeneration,
      resourceId: request.id,
      resourceRevision: request.resourceRevision,
    );
    if (cachedImage == null) {
      return null;
    }

    return ResolvedResourceImage(
      image: cachedImage,
      placeholderBounds: request.placeholderBounds,
    );
  }

  ResourceImageResolveResult _noResolverPlaceholder(
    ResourceImageResolveRequest request,
  ) {
    return NoResolverResourceImagePlaceholder(
      placeholderBounds: request.placeholderBounds,
    );
  }

  ResourceImageResolveResult? _suppressedNullPlaceholder(
    ResourceImageResolveRequest request,
  ) {
    final nullKey = _suppressionKey(request);
    if (!_currentFrameNullResults.contains(nullKey)) {
      return null;
    }

    return NullResourceImagePlaceholder(
      placeholderBounds: request.placeholderBounds,
    );
  }

  ResourceImageResolveResult? _budgetPlaceholder(
    ResourceImageResolveRequest request,
  ) {
    if (_resolverCallsThisFrame < kMaxSyncResourceResolverCallsPerFrame) {
      return null;
    }

    _hasPendingBudgetFollowUpRepaint = true;

    return BudgetExceededResourceImagePlaceholder(
      placeholderBounds: request.placeholderBounds,
    );
  }

  ResourceImageResolveResult _resolveThroughResolver(
    ResourceImageResolveRequest request,
    CanvasResourceResolver resolver,
  ) {
    _resolverCallsThisFrame += 1;
    final imageResource = request.imageResource;
    if (imageResource == null) {
      throw StateError('Descriptor-backed resource request has no image.');
    }
    final ui.Image? image;
    try {
      image = _mutationGuard.runResolverCallback(
        () => resolver.resolveImage(imageResource),
      );
    } on Object catch (error) {
      if (error is ResolverCallbackRejection) {
        rethrow;
      }

      return ResolverExceptionResourceImagePlaceholder(
        placeholderBounds: request.placeholderBounds,
      );
    }
    if (image == null) {
      _currentFrameNullResults.add(_suppressionKey(request));

      return NullResourceImagePlaceholder(
        placeholderBounds: request.placeholderBounds,
      );
    }

    _cache.write(
      resolverGeneration: _resolverGeneration,
      resourceId: request.id,
      resourceRevision: request.resourceRevision,
      image: image,
    );

    return ResolvedResourceImage(
      image: image,
      placeholderBounds: request.placeholderBounds,
    );
  }

  void replaceResolver(CanvasResourceResolver? resolver) {
    if (_isDropped) {
      return;
    }
    _resolver = resolver;
    _resolverGeneration += 1;
    _cache.clear();
    _currentFrameNullResults.clear();
    _hasPendingBudgetFollowUpRepaint = false;
  }

  @override
  void invalidateResourceImage(CanvasResourceId id) {
    _cache.invalidateResource(id);
  }

  @override
  void invalidateAllResourceImages() {
    _cache.clear();
  }

  @override
  void resetForDocumentReplacement() {
    if (_isDropped) {
      return;
    }
    _resolverCallsThisFrame = 0;
    _hasPendingBudgetFollowUpRepaint = false;
    _cache.clear();
    _currentFrameNullResults.clear();
  }

  @override
  void drop() {
    _isDropped = true;
    _resolver = null;
    _resolverGeneration += 1;
    _resolverCallsThisFrame = 0;
    _hasPendingBudgetFollowUpRepaint = false;
    _cache.clear();
    _currentFrameNullResults.clear();
  }

  void dispose() {
    drop();
  }

  _SuppressedResolveKey _suppressionKey(ResourceImageResolveRequest request) {
    return (
      resolverGeneration: _resolverGeneration,
      resourceId: request.id,
      resourceRevision: request.resourceRevision,
    );
  }
}
