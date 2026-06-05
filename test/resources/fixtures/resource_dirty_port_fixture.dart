import 'package:flutter_test/flutter_test.dart';
import 'package:iwb_canvas_engine/iwb_canvas_engine.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resource_catalog_port.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resource_dirty_outcome.dart';
import 'package:iwb_canvas_engine/src/contracts/internal/resolver_mutation_guard.dart';
import 'package:iwb_canvas_engine/src/resources/resource_kernel.dart';

void main() {
  test('single-target dirty accepts existing resources only', () {
    expect(_expectSingleTargetDirtyRules, returnsNormally);
  });

  test('mark-all dirty accepts non-empty catalogs only', () {
    expect(_expectMarkAllDirtyRules, returnsNormally);
  });

  test('mutation guard runs before catalog reads', () {
    expect(_expectGuardBeforeCatalogRead, returnsNormally);
  });
}

void _expectSingleTargetDirtyRules() {
  final sink = _RecordingDirtySink();
  final kernel = ResourceKernel(
    catalog: _FakeResourceCatalog([_resource('resource-a')]),
    mutationGuard: const _AllowingMutationGuard(),
    dirtyOutcomeSink: sink,
  );

  kernel.markResourceDirty(CanvasResourceId('missing'));

  expect(kernel.resourceVisualRevision, 0);
  expect(sink.outcomes, isEmpty);

  kernel.markResourceDirty(CanvasResourceId('resource-a'));

  expect(kernel.resourceVisualRevision, 1);
  expect(sink.outcomes, hasLength(1));
  expect(sink.outcomes.single.dirtyResourceIds, {
    CanvasResourceId('resource-a'),
  });
  expect(sink.outcomes.single.allResourcesDirty, isFalse);
}

void _expectMarkAllDirtyRules() {
  final emptySink = _RecordingDirtySink();
  final emptyCatalog = _FakeResourceCatalog(const []);
  final emptyKernel = ResourceKernel(
    catalog: emptyCatalog,
    mutationGuard: const _AllowingMutationGuard(),
    dirtyOutcomeSink: emptySink,
  );

  emptyKernel.markAllResourcesDirty();

  expect(emptyKernel.resourceVisualRevision, 0);
  expect(emptySink.outcomes, isEmpty);
  expect(emptyCatalog.resourceCountReadCount, 1);
  expect(emptyCatalog.resourcesReadCount, 0);

  final sink = _RecordingDirtySink();
  final catalog = _FakeResourceCatalog([_resource('resource-a')]);
  final kernel = ResourceKernel(
    catalog: catalog,
    mutationGuard: const _AllowingMutationGuard(),
    dirtyOutcomeSink: sink,
  );

  kernel.markAllResourcesDirty();

  expect(kernel.resourceVisualRevision, 1);
  expect(sink.outcomes, hasLength(1));
  expect(sink.outcomes.single.dirtyResourceIds, isEmpty);
  expect(sink.outcomes.single.allResourcesDirty, isTrue);
  expect(catalog.resourceCountReadCount, 1);
  expect(catalog.resourcesReadCount, 0);
}

void _expectGuardBeforeCatalogRead() {
  final singleTarget = ResourceKernel(
    catalog: const _ThrowingResourceCatalog(),
    mutationGuard: const _RejectingMutationGuard(),
    dirtyOutcomeSink: _RecordingDirtySink(),
  );
  final markAll = ResourceKernel(
    catalog: const _ThrowingResourceCatalog(),
    mutationGuard: const _RejectingMutationGuard(),
    dirtyOutcomeSink: _RecordingDirtySink(),
  );

  expect(
    () => singleTarget.markResourceDirty(CanvasResourceId('resource-a')),
    throwsStateError,
  );
  expect(singleTarget.resourceVisualRevision, 0);
  expect(markAll.markAllResourcesDirty, throwsStateError);
  expect(markAll.resourceVisualRevision, 0);
}

final class _FakeResourceCatalog implements ResourceCatalogPort {
  _FakeResourceCatalog(Iterable<CanvasResource> resources)
    : _resources = List.unmodifiable(resources);

  final List<CanvasResource> _resources;
  int resourceCountReadCount = 0;
  int resourcesReadCount = 0;

  @override
  int get resourceCount {
    resourceCountReadCount += 1;

    return _resources.length;
  }

  @override
  List<CanvasResource> get resources {
    resourcesReadCount += 1;

    return _resources;
  }

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    for (final resource in _resources) {
      if (resource.id == id) {
        return resource;
      }
    }

    return null;
  }
}

final class _ThrowingResourceCatalog implements ResourceCatalogPort {
  const _ThrowingResourceCatalog();

  @override
  int get resourceCount {
    throw StateError('catalog count should not run');
  }

  @override
  List<CanvasResource> get resources {
    throw StateError('catalog read should not run');
  }

  @override
  CanvasResource? resourceById(CanvasResourceId id) {
    throw StateError('catalog lookup should not run');
  }
}

final class _RecordingDirtySink implements ResourceDirtyOutcomeSink {
  final List<ResourceDirtyOutcome> outcomes = [];

  @override
  void deliverResourceDirtyOutcome(ResourceDirtyOutcome outcome) {
    outcomes.add(outcome);
  }
}

final class _AllowingMutationGuard implements ResolverMutationGuard {
  const _AllowingMutationGuard();

  @override
  void ensureRuntimeMutationAllowed() => _allowRuntimeMutation();

  @override
  T runResolverCallback<T>(T Function() callback) => callback();
}

int _allowRuntimeMutation() => 0;

final class _RejectingMutationGuard implements ResolverMutationGuard {
  const _RejectingMutationGuard();

  @override
  void ensureRuntimeMutationAllowed() {
    throw StateError('mutation rejected');
  }

  @override
  T runResolverCallback<T>(T Function() callback) => callback();
}

CanvasImageResource _resource(String id) {
  return CanvasImageResource(
    id: CanvasResourceId(id),
    source: CanvasResourceSource.appKey(id),
  );
}
