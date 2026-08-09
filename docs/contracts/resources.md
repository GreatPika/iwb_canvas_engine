<!-- CONTEXT:BEGIN -->
Registry id: `section_07_resource_lifecycle`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/resources.md`
Owns:
- 7. Resource lifecycle contract
Must read before editing:
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
Current owners:
- `contract`
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
- `test.resources.missing_result_suppressed_per_frame`
- `test.resources.surface_session_cache_lifecycle`
- `test.resources.resolver_swap_starts_fresh_cache`
- `test.resources.resolver_frame_budget`
- `test.resources.resolver_exception_placeholder`
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
Resource declarations such as `CanvasResource`, `CanvasResourcePort`, and
`CanvasResourceResolver` live in `lib/src/contracts/public/**`;
`ResourceCatalogPort`, dirty-resource outcomes, and resolver mutation guard
seams live in `lib/src/contracts/internal/**`. `ResourceCatalogPort` is the
runtime-backed count/list/lookup seam for committed public resource
descriptors; frame code continues to use `FrameFactsPort` for descriptor facts
and must not use the catalog seam for asset binding. `ResourceKernel` owns the
implemented non-surface resource API, catalog read delegation,
`resourceVisualRevision`, and dirty-resource no-op/acceptance orchestration.
`RuntimeRoot` holds the nullable active `SurfaceResourceSessionLifecycle` port,
which extends `ResourceSessionReleaseSink` with `drop()`. Runtime invokes its
generic target/all release side before dirty public-state/effect publication and
the drop side when the active surface detaches, swaps runtimes, the runtime is
disposed, or a post-acceptance resource-session release/reset target fails and
must not be reused.
Each active `CanvasSurface` creates one concrete `SurfaceResourceSession`
instance under `lib/src/resources/**` for synchronous resolver lifecycle and
resolved-image cache/suppression state. CanvasSurface wires the session to the
runtime lifecycle port after successful attach and supplies the narrow callback
that releases matching retained main-output bindings.

```text
Committed document:
  resource descriptors only.

Runtime resource orchestration:
  dirty resource ids;
  resource visual public-state publication;
  target/all resource release before publication;
  active session drop on detach/runtime swap/dispose;
  resolver reentrancy rejection.

SurfaceResourceSession:
  CanvasResourceResolver?;
  resolverGeneration;
  ImageResolveCache;
  per-frame resolver-call budget;
  same-frame null-result suppression;
  budget-exceeded follow-up throttle.

CanvasSurface retained output:
  identity-aware target/all main-output binding release;
  unrelated bindings and overlay preserved for target release.
```

Paint/resource resolution receives immutable descriptor snapshots and
`resourceRevision` through the `contracts/internal/**` `FrameFactsPort`, which
is backed by the committed document owner for frame paint. The resource module
must not import, read, or mutate `DocumentStoreKernel` or `RuntimeRoot`; it owns
session policy, resolver-safe placeholder results, and generic release
boundaries through narrow contract inputs only.
Schema v1 runtime load imports resource declarations as store-owned descriptor
rows during `DocumentStoreKernel` preparation. Load must not construct public
`CanvasImageResource` instances or call app resolvers. Public
`CanvasImageResource` appears only when an explicit read/resource/resolver-facing
projection asks for a public resource view.
Ordinary frame planning receives immutable row facts and resource ids needed to
build records, but it does not receive descriptor snapshots or resolver/session
APIs. In the target frame split, `PaintAssetBindingService` is the only frame
collaborator that receives `SurfaceResourceSession`; after ordinary and
supplement records are known, it reads descriptor facts through
`FrameFactsPort`, performs descriptor-to-asset binding, and produces resolved
paint assets or placeholders for painter inputs. This keeps descriptor binding
and resolver access out of capture, ordinary planning, painters, and app
resolver ownership.
The binding service calls `beginFrameResourcePass()` before resolving any image
for a main paint frame. That call resets the session-owned per-frame resolver
budget, clears same-frame null-result suppression for the new frame, and clears
the pending budget follow-up repaint flag before resolver work begins.

`CanvasSurface` creates an empty `SurfaceResourceSession` only after successful
single-active-surface attachment. Rejected attachment creates no session and
performs no resolver side effects. The runtime-surface bridge installs the
session through `SurfaceResourceSessionLifecycle`; detach, dispose, runtime
swap, and runtime disposal remove matching session and retained-output borrows
before return, without disposing app-owned `ui.Image` instances. If an active
surface receives a different `resourceResolver`, the session increments
`resolverGeneration` and releases stale session/output borrows before the next
resolve.

### 7.1.1 Image resolve cache policy

`ImageResolveCache` is `SurfaceResourceSession` policy owned by the resources
module, not a frame/spatial cache prerequisite and not runtime-wide resource
state. Frame rendering consumes the session boundary; resource owns the session
primitive and cache policy, while surface wires the instance lifecycle to
`CanvasSurface`.

| Cache | Owner | Key | Invalidated by | Capacity | Eviction | Metric/probe | Hot path allowed? |
|---|---|---|---|---:|---|---|---|
| ImageResolveCache | SurfaceResourceSession | resolverGeneration + resourceId + resourceRevision | resolver replacement, descriptor change, resource dirty target/all release, detach/dispose/runtime swap | 1024 entries and 64 MiB decoded bytes per active session | target/all release, generation reset, oversized no-retention, then entry/byte LRU | `length`, `currentSizeBytes`, resolver-call budget, and pending budget follow-up flag | yes, sync app resolver only with `kMaxSyncResourceResolverCallsPerFrame = 128` |

The public dirty-resource revision is a repaint observation signal only. Cache
identity is the table key above; dirty-resource calls release matching target
entries or all entries in the active session explicitly. If no surface is
attached, there is no session cache or retained output to release and the next
attach starts empty.
Resolved-image cache byte pressure is cache-local derived state from decoded
`ui.Image` dimensions, `image.width * image.height * 4`; descriptor
`CanvasResource.byteLength` remains descriptor/source metadata and is not cache
memory truth. A single resolved image whose decoded estimate exceeds the active
session byte budget is returned for the current resolve result but is not
retained for a later cache hit. Entry eviction and byte eviction remove cache
references only. Target/all release, resolver replacement, document replacement,
drop, and dispose synchronously remove matching cache/suppression borrows and
the matching retained main-output borrow; they never call the resolver or
dispose app-owned `ui.Image` instances. Target release preserves unrelated
bindings and overlay output. A stale session callback proves no matching active
output and never mutates the current surface output.

Generic release and document-replacement reset are post-acceptance delivery
work: reference removal completes before a fallible notification boundary.
Later notification failures must not roll back, rethrow from, or block
publication of an accepted edit, accepted load, or accepted dirty-resource
result; accepted state, revisions, repaint intent, operation return, and the
no-borrow postcondition remain observable. Rejected and no-op operations mutate
neither retention owner. Runtime clears a failed sink; when the failed target is
the active surface session, runtime drops and detaches that session before
continuing publication so stale resolved images cannot be reused.

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
- removes resource and releases matching resource borrows if unused;
- emits no action event;
- increments document/resource revision if removed.
```

### 7.4 External visual resource repaint

Applications notify the runtime about external resource visual changes through
the current resource repaint API:

```dart
runtime.resources.markResourceDirty(resourceId);
runtime.resources.markAllResourcesDirty();
```

Semantics:

```text
- does not change document revision;
- increments `state.revisions.resourceVisual`;
- sends target/all dirty outcome through `RuntimeRoot` to the active
  `ResourceSessionReleaseSink`, if attached, which synchronously releases
  matching session and retained-output borrows before dirty state listeners or
  commit-effect observers run;
- publishes main repaint intent;
- publishes one `CanvasRuntimeState` when the dirty request changes resource
  visual state;
- does not emit action event;
- does not clear selection;
- does not clear preview;
- missing target resource ids and empty mark-all catalogs are complete no-ops;
- after dispose throws StateError.
```

`resourceVisualRevision` is runtime resource revision state and maps to the
public `state.revisions.resourceVisual` domain. The public resource port
delegates the revision increment to ResourceKernel/RuntimeRoot orchestration.
`ResourceKernel` emits only `ResourceDirtyOutcome`; `RuntimeRoot` owns the
active-session release slot and forwards target/all release to the attached
resource session, if any. The active session clears matching cache/suppression
borrows before its identity-aware CanvasSurface callback releases matching
retained main-output bindings. If that release target fails, `RuntimeRoot`
contains the failure by clearing the failed sink or dropping the failed surface
session, then still publishes the accepted dirty state and repaint effect. The
repaint intent is runtime-owned and does not require an attached CanvasSurface;
an attached surface observes it if present.

`markAllResourcesDirty` applies the same rule to every registered resource and
releases all active session and retained-output borrows when a
`ResourceSessionReleaseSink` is attached. With no attached session, the dirty
publication still completes and there is no release work to perform.

### 7.5 v1 resource boundary

```text
- mandatory v1 supports appKey resource descriptors and dirty-resource release;
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
normal placeholder painting does not write `DiagnosticsHub`;
schema missing-reference validation at load time uses the staged-load codec-bridge row in `section_20_diagnostics_hub`;
any future verbose missing-placeholder diagnostic must be added to the routing table before implementation.
```

Resolver exception placeholders:

```text
SurfaceResourceSession catches ordinary synchronous app resolver failures,
including ordinary StateError failures, and returns a bounded
resolver-exception placeholder for only the affected image resource;
runtime resolver guard rejections remain fail-fast StateError failures and are
not converted to placeholders;
resolver-exception placeholders are not written to ImageResolveCache;
resolver-exception placeholders are not added to same-frame null-result
suppression;
resolver-exception attempts consume the per-frame resolver-call budget;
later frames may retry the throwing resource through the app resolver;
other image resources in the same frame continue resolving and binding;
resolver-exception placeholders do not write DiagnosticsHub.
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
SurfaceResourceSession owns the budget-exceeded follow-up throttle;
budget-exceeded results may schedule at most one pending throttled follow-up repaint;
the pending follow-up repaint flag is cleared by the next main frame resource pass;
painters and app resolvers must not schedule budget-exceeded follow-up repaints;
budget-exceeded results are not cached as null, missing, or resolved images.
null resolver results are suppressed only within the same frame and
resolverGeneration + resourceId + resourceRevision identity. Missing
descriptors and absent resolvers return bounded placeholders without resolver
calls, budget use, or cache writes. Resolver exception placeholders consume
budget for the attempted callback but are not cached or null-suppressed.
Placeholder outcomes are not durable cross-frame cache entries, and resolver
replacement clears null-result suppression state before the next resolve.
```

---
