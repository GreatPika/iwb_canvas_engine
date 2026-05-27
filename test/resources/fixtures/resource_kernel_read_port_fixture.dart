import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resource_catalog_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resolver_mutation_guard.dart';
import 'package:iwb_canvas_engine/src/resources/resource_kernel.dart';
import 'package:iwb_canvas_engine/src/runtime/runtime_root.dart';

void main() {
  test('kernel read port delegates to catalog without owning descriptors', () {
    expect(_expectKernelCatalogDelegation, returnsNormally);
  });

  test('runtime exposes the resource-owned public read port', () {
    expect(_expectRuntimeResourcePort, returnsNormally);
  });
}

void _expectKernelCatalogDelegation() {
  final catalog = _FakeResourceCatalog([
    _imageResource(id: 'resource-a', appKey: 'asset-a'),
  ]);
  final kernel = ResourceKernel(
    catalog: catalog,
    mutationGuard: const _AllowingMutationGuard(),
  );

  expect(kernel.resources.single.id, CanvasResourceId('resource-a'));
  expect(
    kernel.resourceById(CanvasResourceId('resource-a'))?.id,
    CanvasResourceId('resource-a'),
  );
  expect(kernel.resourceById(CanvasResourceId('missing')), isNull);
  expect(catalog.resourcesReadCount, 1);
  expect(catalog.lookupIds, [
    CanvasResourceId('resource-a'),
    CanvasResourceId('missing'),
  ]);
}

void _expectRuntimeResourcePort() {
  final root = RuntimeRoot(
    initialDocument: _document(),
    config: const CanvasRuntimeConfig(),
  );

  expect(() {
    final resources = root.resources;
    expect(resources, isA<CanvasResourcePort>());
    expect(resources.resources.single.id, CanvasResourceId('resource-a'));
    expect(
      resources.resourceById(CanvasResourceId('resource-a'))?.id,
      CanvasResourceId('resource-a'),
    );
    expect(resources.resourceById(CanvasResourceId('missing')), isNull);
  }, returnsNormally);

  root.dispose();
}

final class _FakeResourceCatalog implements ResourceCatalogPort {
  _FakeResourceCatalog(Iterable<CanvasResource> resources)
    : _resources = List.unmodifiable(resources);

  final List<CanvasResource> _resources;
  final List<CanvasResourceId> lookupIds = [];
  int resourcesReadCount = 0;

  @override
  List<CanvasResource> get resources {
    resourcesReadCount += 1;

    return List.unmodifiable(_resources);
  }

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    lookupIds.add(id);

    for (final resource in _resources) {
      if (resource.id == id) {
        return resource;
      }
    }

    return null;
  }
}

final class _AllowingMutationGuard implements ResolverMutationGuard {
  const _AllowingMutationGuard();

  @override
  void ensureRuntimeMutationAllowed() {}

  @override
  T runResolverCallback<T>(T Function() callback) => callback();
}

CanvasDocument _document() {
  return CanvasDocument(
    resources: [_imageResource(id: 'resource-a', appKey: 'asset-a')],
  );
}

CanvasImageResource _imageResource({
  required String id,
  required String appKey,
}) {
  return CanvasImageResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey(appKey),
  );
}
