<!-- CONTEXT:BEGIN -->
Registry id: `section_07_resource_lifecycle`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/resources.md`
Owns:
- 7. Resource lifecycle contract
Must read before editing:
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
Feeds phases:
- `P7`
- `P9`
- `P13`
Related donors:
- `none`
Related diagrams:
- `dfd_resource_resolution`
- `seq_resource_resolution`
- `state_resource_resolution`
Required tests:
- `test.api_contract.public_readable_union_variants`
- `test.codec.schema_v1.resources_appkey_only`
- `test.codec.schema_v1.reject_unknown_resource_source_kind`
- `test.resources.sync_image_resolver`
- `test.resources.app_owned_image_not_disposed`
- `test.resources.resource_dirty`
- `test.resources.mark_all_resources_dirty`
- `test.resources.painter_never_calls_resolver_directly`
- `test.resources.missing_result_cached_per_revision`
- `test.resources.resolver_frame_budget`
- `test.resources.resolver_reentrancy_rejected`
Guardrails:
- `api.resource_source_app_key_publicly_readable`
- `resources.mutation_inside_edit_only`
- `resources.dirty_no_document_revision`
- `resources.app_key_only`
- `resources.resolver_boundary_owned_by_resource_kernel`
- `resources.resolver_frame_budget`
- `resources.no_same_frame_missing_retry`
- `resources.resolver_reentrancy_rejected`
Do not assume:
- no engine IO
- no asset-bundle loading
- no file loading
- no remote/network loading
<!-- CONTEXT:END -->

## 7. Resource lifecycle contract

### 7.1 Resource state

`DocumentStoreKernel` owns resource descriptors as part of committed document. `ResourceKernel` owns runtime caches.

```text
Committed document:
  resource descriptors only.

Runtime cache:
  resolved app-provided image references;
  dirty resource ids.
```

Paint/resource resolution receives immutable descriptor snapshots and
`resourceRevision` from an allowed committed-state reader such as `FrameEngine`
or `RuntimeRoot`. `ResourceKernel` must not import, read, or mutate
`DocumentStoreKernel`; it owns resolver calls, resolved-image cache entries,
dirty ids, and resolver-safe placeholder results.
Painters and frame paint code never call `CanvasResourceResolver` directly; they
receive immutable descriptor facts and resolve paint assets only through
`ResourceKernel`.

### 7.1.1 Image resolve cache policy

`ImageResolveCache` is ResourceKernel-owned core resource policy, not a
frame/spatial cache prerequisite. Frame rendering may consume the boundary, but
P7 owns the cache admission, invalidation, and budget semantics.

| Cache | Owner | Key | Invalidated by | Capacity | Eviction | Metric/probe | Hot path allowed? |
|---|---|---|---|---:|---|---|---|
| ImageResolveCache | Resource | resourceId/resourceRevision | resource dirty/descriptor change | 1024 entries | target/all invalidation, then LRU | resolver calls, budget-exceeded count, hit/miss, null-cache count | yes, sync app resolver only with `kMaxSyncResourceResolverCallsPerFrame = 128` |

### 7.2 Atomic operations

Resource mutation is inside `CanvasEdit`:

```dart
runtime.edits.edit((edit) {
  edit.upsertResource(CanvasImageResource(...));
  edit.addElement(CanvasImageElement(resourceId: ...));
});
```

If any operation throws, both resource and element changes roll back.

### 7.3 Removal

`removeUnusedResource(id)`:

```text
- returns false if resource does not exist;
- returns false if any element references it;
- references include background elements, hidden elements, locked elements and non-deletable elements;
- removes resource and invalidates resource cache if unused;
- emits no action event;
- increments document/resource revision if removed.
```

### 7.4 External visual resource repaint

Legacy `notifySceneChanged()` is replaced by:

```dart
runtime.resources.markResourceDirty(resourceId);
runtime.resources.markAllResourcesDirty();
```

Semantics:

```text
- does not change document revision;
- increments resourceVisualRevision;
- invalidates resolved cache entries for target resource;
- publishes main repaint intent;
- does not emit action event;
- does not clear selection;
- does not clear preview;
- after dispose throws StateError.
```

`resourceVisualRevision` is committed runtime revision state. The public
resource port delegates the revision increment to the runtime/store boundary
and delegates cache invalidation to `ResourceKernel`.
The repaint intent is runtime-owned and does not require an attached
`CanvasSurface`; an attached surface observes it if present.

`markAllResourcesDirty` applies the same rule to every registered resource.

### 7.5 v1 resource boundary

```text
- mandatory v1 supports appKey resource descriptors and dirty invalidation;
- `CanvasResourceSource.appKey` constructs the public readable
  `CanvasAppKeyResourceSource`; application resolvers read the app-owned
  identity from `CanvasAppKeyResourceSource.key` through the public barrel only;
- resource mutation remains inside CanvasEdit;
- resolver calls are synchronous and app-owned;
- resolver calls are bounded by internal `kMaxSyncResourceResolverCallsPerFrame = 128`;
- reentrant public runtime mutation from inside the resolver throws `StateError`;
- no engine IO;
- no asset-bundle loading;
- no file loading;
- no remote/network loading.
```

### 7.6 Missing resource placeholder

If an image element references a missing or unresolved resource, FrameEngine
paints a bounded placeholder rectangle.

```text
image size determines placeholder bounds;
no full-document repaint loop;
no repeated resolver retry in same frame;
diagnostic emitted only if verbose diagnostics enabled or schema missing reference occurs at load time.
```

Resolver reentrancy:

```text
ResourceKernel marks the resolver call boundary as active before invoking the app
callback. Any public runtime mutation attempted by that callback is rejected with
StateError. The failed reentrant mutation does not change document, selection,
preview, cache, repaint, or action state.
```

Resolver frame budget:

```text
kMaxSyncResourceResolverCallsPerFrame = 128;
the counter resets for each main paint frame;
cache hits and missing descriptors do not consume the resolver-call budget;
after the budget is exhausted, ResourceKernel returns a bounded placeholder;
budget-exceeded results increment a diagnostic/probe counter;
ResourceKernel owns the budget-exceeded retry scheduler;
budget-exceeded results may schedule at most one pending throttled follow-up repaint;
the pending follow-up repaint flag is cleared by the next main frame resource pass;
painters and app resolvers must not schedule budget-exceeded follow-up repaints;
budget-exceeded results are not cached as null, missing, or resolved images.
```

---
