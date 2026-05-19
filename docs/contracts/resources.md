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
- `test.resources.missing_result_suppressed_per_frame`
- `test.resources.surface_session_cache_lifecycle`
- `test.resources.resolver_swap_starts_fresh_cache`
- `test.resources.resolver_frame_budget`
- `test.resources.resolver_reentrancy_rejected`
Guardrails:
- `api.resource_source_app_key_publicly_readable`
- `resources.mutation_inside_edit_only`
- `resources.dirty_no_document_revision`
- `resources.app_key_only`
- `resources.resolver_boundary_owned_by_surface_session`
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

`DocumentStoreKernel` owns resource descriptors as part of committed document.
`ResourceKernel` owns the non-surface resource API and dirty-resource
orchestration. Each active `CanvasSurface` owns one `SurfaceResourceSession`
instance for synchronous resolver lifecycle and resolved-image cache state.

```text
Committed document:
  resource descriptors only.

Runtime resource orchestration:
  dirty resource ids;
  resource visual public-state publication;
  target/all session invalidation events;
  resolver reentrancy rejection.

SurfaceResourceSession:
  CanvasResourceResolver?;
  resolverGeneration;
  ImageResolveCache;
  per-frame resolver-call budget;
  same-frame missing/null suppression;
  budget-exceeded follow-up throttle.
```

Paint/resource resolution receives immutable descriptor snapshots and
`resourceRevision` from an allowed committed-state reader such as `FrameEngine`
or `RuntimeRoot`. The resource module must not import, read, or mutate
`DocumentStoreKernel`; it owns session policy, resolver-safe placeholder
results, and dirty invalidation boundaries through narrow inputs only.
Painters and frame paint code never call `CanvasResourceResolver` directly; they
receive immutable descriptor facts and resolved paint assets or placeholders
through `SurfaceResourceSession`.

`CanvasSurface` creates an empty `SurfaceResourceSession` only after successful
single-active-surface attachment. Rejected attachment creates no session and
performs no resolver side effects. Detach, dispose, and runtime swap drop the
session and its cache without disposing app-owned `ui.Image` instances. If an
active surface receives a different `resourceResolver`, the session increments
`resolverGeneration` and clears stale entries before the next resolve.

### 7.1.1 Image resolve cache policy

`ImageResolveCache` is `SurfaceResourceSession` policy owned by the resources
module, not a frame/spatial cache prerequisite and not runtime-wide resource
state. Frame rendering consumes the session boundary; P7 owns the session
primitive and cache policy, while P13 wires the instance lifecycle to
`CanvasSurface`.

| Cache | Owner | Key | Invalidated by | Capacity | Eviction | Metric/probe | Hot path allowed? |
|---|---|---|---|---:|---|---|---|
| ImageResolveCache | SurfaceResourceSession | resolverGeneration + resourceId + resourceRevision | resolver replacement, descriptor change, resource dirty target/all, detach/dispose/runtime swap | 1024 entries per active session | target/all invalidation, generation reset, then LRU | resolver calls, budget-exceeded count, hit/miss, same-frame null/missing suppression count | yes, sync app resolver only with `kMaxSyncResourceResolverCallsPerFrame = 128` |

The public dirty-resource revision is a repaint observation signal only. Cache
identity is the table key above; dirty-resource calls invalidate target entries
or all entries in the active session explicitly. If no surface is attached,
there is no session cache to invalidate and the next attach starts empty.

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
- increments `state.revisions.resourceVisual`;
- sends target invalidation to the active `SurfaceResourceSession` if attached;
- publishes main repaint intent;
- publishes one `CanvasRuntimeState` when the dirty request changes resource
  visual state;
- does not emit action event;
- does not clear selection;
- does not clear preview;
- after dispose throws StateError.
```

`resourceVisualRevision` is runtime resource revision state and maps to the
public `state.revisions.resourceVisual` domain. The public resource port
delegates the revision increment to ResourceKernel/RuntimeRoot orchestration and
delegates target invalidation to the attached resource session, if any. The
repaint intent is runtime-owned and does not require an attached `CanvasSurface`;
an attached surface observes it if present.

`markAllResourcesDirty` applies the same rule to every registered resource and
clears the active session cache if a session exists.

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
Runtime resource orchestration marks the resolver call boundary as active before
the session invokes the app callback. Any public runtime mutation attempted by
that callback is rejected with StateError. The failed reentrant mutation does
not change document, selection, preview, cache, repaint, or action state.
```

Resolver frame budget:

```text
kMaxSyncResourceResolverCallsPerFrame = 128;
the counter resets for each main paint frame;
cache hits and missing descriptors do not consume the resolver-call budget;
after the budget is exhausted, SurfaceResourceSession returns a bounded placeholder;
budget-exceeded results increment a diagnostic/probe counter;
SurfaceResourceSession owns the budget-exceeded follow-up throttle;
budget-exceeded results may schedule at most one pending throttled follow-up repaint;
the pending follow-up repaint flag is cleared by the next main frame resource pass;
painters and app resolvers must not schedule budget-exceeded follow-up repaints;
budget-exceeded results are not cached as null, missing, or resolved images.
null or missing resolver results are suppressed only within the same frame and
resolverGeneration + resourceId + resourceRevision identity; they are not
durable cross-frame cache entries, and resolver replacement clears suppression
state before the next resolve.
```

---
