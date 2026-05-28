# Change Contract

## Goal

Complete the remaining P7 resource session behavior so image resolution is
owned by a surface-scoped `SurfaceResourceSession`, dirty resource calls
invalidate the active session before public dirty observation, resolver
callbacks are guarded and bounded, and app-owned images remain outside engine
lifetime ownership. Keep frame paint binding and Flutter surface lifecycle
wiring deferred to their later phase owners.

## Evidence

- `.design/2026-05-28-p7-resource-session-resolver-lifecycle.md` / disposition and selected form: the design is `READY_FOR_CONTRACT` and selects Candidate A, a surface-owned session policy with runtime handoff -> this step must implement `SurfaceResourceSession` as the live resolver/cache owner and must not move cache ownership into runtime, frame, or widget code.
- `.design/2026-05-28-p7-resource-session-resolver-lifecycle.md` / target classification: the required profile is `BEHAVIOR_CHANGE` with `SEAM_MIGRATION` obligation -> this step must prove both observable resource behavior and the internal seam/import shape.
- `.design/2026-05-28-p7-resource-session-resolver-lifecycle.md` / locked seam: `ResourceSessionInvalidationSink` belongs in `lib/src/contracts/internal/resource_session_invalidation_sink.dart`, exposes `invalidateResourceImage(CanvasResourceId id)` and `invalidateAllResourceImages()`, is implemented by `SurfaceResourceSession`, is held by `RuntimeRoot` only as the nullable active-session invalidation slot, and is never passed to `ResourceKernel` -> execution must preserve that exact owner split.
- `.design/2026-05-28-p7-resource-session-resolver-lifecycle.md` / temporal ordering: active-session dirty invalidation must occur before `_publishRuntimeState()` and the commit-effect observer can synchronously expose dirty-resource publication -> runtime delivery tests must prove listener and observer callbacks see cache state already invalidated.
- `.design/2026-05-28-p7-resource-session-resolver-lifecycle.md` / session frame-pass boundary: `beginFrameResourcePass()` starts the main-paint resource pass, resets the 128-call budget, clears current-frame null-result suppression, and clears the pending budget follow-up flag -> session tests must prove the reset boundary explicitly without depending on P9 paint code.
- `.design/2026-05-28-p7-resource-session-resolver-lifecycle.md` / resolve boundary: `resolveImage(ResourceImageResolveRequest request)` receives resource id, app-key descriptor data, resource revision, and placeholder bounds; missing descriptors return bounded placeholders without resolver calls or cache writes -> implementation must use typed resource-owned request/result values instead of frame or runtime imports, and app-key descriptor data must preserve the full public `CanvasImageResource` payload that the public resolver receives.
- `.design/2026-05-28-p7-resource-session-resolver-lifecycle.md` / resolver guard: resolver callbacks must execute through `ResolverMutationGuard.runResolverCallback`, while runtime remains the owner of public mutation rejection -> session code owns when to call the resolver but does not own public mutation policy.
- `docs/implementation/p7_resources_and_images.md` / build scope: P7 includes `SurfaceResourceSession`, synchronous app-owned image resolver bridge, surface-scoped image resolve cache, same-frame null-result suppression, bounded placeholders for missing descriptors and absent resolvers, resolver frame budget, resolver reentrancy guard, and no engine IO, asset-bundle, file, remote, or network loading -> this step must finish that remaining P7 session scope without adding loading mechanisms.
- `docs/implementation/p7_resources_and_images.md` / exit gate: target dirty must evict the target active-session image cache entry, mark-all dirty must clear the active-session cache, resolver image results are app-owned and not disposed by the engine, resolver swap/detach/dispose/runtime swap cannot reuse stale cache entries, null results do not retry in the same frame, missing descriptors and absent resolvers return bounded placeholders without resolver calls, and budget placeholders must not create invalid cache writes -> execution units must name tests for each behavior.
- `docs/contracts/resources.md` / ownership contract: committed descriptors belong to `DocumentStoreKernel`; `ResourceKernel` owns the implemented non-surface public resource API and dirty orchestration; each active future `CanvasSurface` owns one `SurfaceResourceSession` under `lib/src/resources/**` for resolver lifecycle and resolved-image cache state -> this step must not duplicate committed descriptor or resolved image ownership.
- `docs/contracts/resources.md` / frame descriptor seam: paint/resource resolution receives immutable descriptor snapshots and `resourceRevision` through `FrameFactsPort`; `PaintAssetBindingService` is the later frame collaborator that receives `SurfaceResourceSession` -> P7 tests may construct request values directly, but P7 must not wire frame rendering or ordinary planners to resolver access.
- `docs/contracts/resources.md` / cache policy: `ImageResolveCache` is session policy keyed by resolver generation, resource id, and resource revision, with 1024 entries per active session, target/all invalidation, generation reset, LRU eviction, and 128 sync resolver calls per frame -> cache and budget constants must be resource-owned and mechanically tested.
- `docs/contracts/resources.md` / dirty behavior: dirty-resource revision is a repaint observation signal only; dirty calls explicitly invalidate target/all active-session entries; no attached surface means no session cache work and the next attach starts empty -> runtime handoff must preserve existing no-session dirty publication behavior.
- `docs/contracts/resources.md` / v1 resolver boundary: resolver calls are synchronous and app-owned, bounded by `kMaxSyncResourceResolverCallsPerFrame = 128`, reentrant public runtime mutation throws `StateError`, and no engine IO/file/network loading is allowed -> session implementation must not introduce async, filesystem, asset bundle, or network behavior.
- `docs/contracts/resources.md` / placeholder and suppression contract: missing or unresolved resource images paint bounded placeholders, normal placeholders do not write `DiagnosticsHub`, budget-exceeded results may schedule at most one pending throttled follow-up repaint, null resolver results are suppressed only within the same frame and resolver generation/resource id/resource revision identity, and missing descriptors or absent resolvers do not call the resolver -> result values and tests must distinguish resolved, missing, null, no-resolver, and budget placeholder paths.
- `docs/architecture/02_package_boundaries.md` / package layout: resource session policy belongs in `lib/src/resources/resource_cache.dart`, `lib/src/resources/resource_resolver_adapter.dart`, and `lib/src/resources/surface_resource_session.dart`; `lib/src/resources/**` may not import runtime, store, frame, surface, interaction, Flutter, or cache/session owners outside resource-owned seams -> guardrails must protect the new files.
- `docs/architecture/architecture_graph.yaml` / P7 graph: `resource.surface_session` is a required P7 owner and the future `resource.kernel.invalidates_surface_session` edge records ResourceKernel dirty invalidation to the session without ResourceKernel owning image references or cache entries -> graph data must move only the implemented P7 session and invalidation edges out of future status when proof exists.
- `docs/contracts/public_api_v1.md` and `lib/src/contracts/public/canvas_resource.dart` / public resolver payload: `CanvasResourceResolver.resolveImage` receives a `CanvasImageResource`, whose public descriptor fields include `mimeType`, `contentHash`, `byteLength`, metadata, id, and source -> the session request path must reconstruct and pass the full public image descriptor, not an app-key-only subset.
- `lib/src/store/resource_table.dart` / committed descriptor storage: store resource copies preserve `mimeType`, `contentHash`, `byteLength`, and metadata, but current `StoreResourceDescriptorFacts` only exposes id, app key, resource revision, and metadata -> this step must extend internal descriptor facts rather than drop public descriptor fields before resolver execution.
- `lib/src/resources/resource_kernel.dart` / current implementation: `ResourceKernel` already emits `ResourceDirtyOutcome` after guarded target/all dirty acceptance and has no session/cache dependency -> this step must keep `ResourceKernel` free of image cache and app image state.
- `lib/src/runtime/runtime_root.dart` / current dirty delivery: runtime receives `ResourceDirtyOutcome`, turns it into resource/repaint/public-state effects, and publishes state and commit-effect observer callbacks inside the synchronous dirty delivery window -> active-session invalidation must be inserted before that publication window, not after it.
- `lib/src/runtime/runtime_root.dart` / current guard owner: runtime implements `runResolverCallback`, rejects nested resolver callbacks, and rejects public mutations while a resolver callback is active -> session implementation must call this seam instead of duplicating mutation-state flags.
- `lib/src/contracts/internal/frame_facts_port.dart` / current descriptor facts: `FrameResourceDescriptorFacts` carries resource id, app key, resource revision, and metadata, but not the optional public image descriptor fields -> P7 must extend the internal descriptor fact path so request values can reconstruct the full `CanvasImageResource` resolver payload from immutable facts and placeholder bounds without importing frame owners.
- `test/resources/**` and `docs/verification/tests.md` / current proof gap: Step 39 tests cover public resource reads and dirty revision publication, while the listed future tests for sync resolver, app-owned image lifetime, active-session dirty eviction, mark-all cache clear, cache lifecycle, resolver swap, frame budget, and reentrancy are still absent -> this step must add those focused resource/session tests.

## Boundaries

Owner:

`SurfaceResourceSession` under `lib/src/resources/**` owns sync resolver
lifecycle, resolver generation, image resolve cache, per-frame resolver-call
budget, same-frame null-result suppression, bounded placeholder results,
budget follow-up throttle state, target/all cache invalidation, resolver swap
cache reset, and app-owned image no-dispose behavior. `ResourceKernel` remains
the public resource read/dirty owner and emits only `ResourceDirtyOutcome`.
`RuntimeRoot` owns the nullable active `ResourceSessionInvalidationSink` slot,
runtime mutation guard implementation, dirty publication ordering, public state
publication, and repaint/effect delivery containment. `DocumentStoreKernel`
remains the committed descriptor owner. P9 owns later frame paint binding; P13
owns later Flutter surface attach/detach/resolver-swap timing.

In Scope:

- Add `ResourceSessionInvalidationSink` in `contracts/internal/**` with exactly
  `invalidateResourceImage(CanvasResourceId id)` and
  `invalidateAllResourceImages()`.
- Add resource-owned request/result/cache/session implementation under
  `lib/src/resources/resource_cache.dart`,
  `lib/src/resources/resource_resolver_adapter.dart`, and
  `lib/src/resources/surface_resource_session.dart`.
- Extend the internal committed image descriptor fact path used by
  `StoreResourceDescriptorFacts` and `FrameResourceDescriptorFacts` so the
  request can preserve `mimeType`, `contentHash`, and `byteLength` alongside id,
  app key, metadata, and `resourceRevision`; the resolver must receive the full
  reconstructed public `CanvasImageResource`.
- Implement `SurfaceResourceSession.beginFrameResourcePass()`,
  `resolveImage(ResourceImageResolveRequest request)`,
  `replaceResolver(CanvasResourceResolver?)`, target/all invalidation, and
  session drop/dispose cache clearing behavior without disposing app-owned
  `ui.Image` instances.
- Use cache identity `resolverGeneration + resourceId + resourceRevision`, a
  1024-entry session cache, and LRU eviction that refreshes recency on cache
  hits.
- Represent missing descriptors, absent resolver, null resolver results,
  budget-exceeded results, and resolved images with explicit resource-owned
  result states; every placeholder result must carry the request's bounded
  placeholder rectangle.
- Call the app resolver only through `ResolverMutationGuard.runResolverCallback`
  and never from ordinary planners, painters, runtime dirty delivery, or
  `ResourceKernel`.
- Enforce per-main-frame budget reset and 128 sync resolver calls per
  `beginFrameResourcePass()`; cache hits and missing descriptors do not consume
  the budget, and budget-exceeded results are placeholders with no null/missing
  or image cache write.
- Suppress null resolver results only within the current frame pass for resolver
  generation, resource id, and resource revision; missing descriptors and absent
  resolvers return bounded placeholders without resolver calls; clear null-result
  suppression on `beginFrameResourcePass()` and resolver replacement.
- Add internal `RuntimeRoot` attach/clear operations for the active
  `ResourceSessionInvalidationSink` so later P13 code can wire them after
  successful single-active-surface attachment; direct P7 tests may use those
  internal operations, but no public API is added.
- Forward accepted dirty target/all outcomes from runtime to the active session
  invalidation sink before runtime-state listeners or commit-effect observers
  can synchronously observe dirty publication.
- Add focused tests for sync resolution, app image ownership, cache lifecycle,
  resolver swap, null-result same-frame suppression, resolver budget, resolver
  reentrancy rejection, target dirty cache eviction, mark-all cache clear,
  runtime dirty handoff ordering, no-session dirty publication, public
  incremental smoke coverage, and import/seam guardrails.
- Update durable resource, architecture, verification, guardrail, diagram, and
  architecture graph sources only where the implemented P7 session behavior
  changes source-of-truth or graph closure state; regenerate generated graph
  views and generated docs when their inputs change.
- After implementation and verification pass, mark Step 41 complete in
  `PLAN.md` and mark this step document's execution-unit checkboxes complete in
  the same change.

Out of Scope:

- Do not implement P9 frame paint binding, `PaintAssetBindingService`, painter
  inputs, render records, or ordinary paint planner resolver access.
- Do not implement P13 Flutter widget lifecycle, public `CanvasSurface` attach
  ownership, multi-surface collaboration, runtime-swap widget behavior, or
  public resolver registration changes.
- Do not add public API methods, public DTO variants, schema v1 formats, public
  diagnostics streams, public cache/probe APIs, or public error-code changes.
- Do not implement or change future interaction-owned public placeholders such
  as `CanvasRuntime.tools`, `commands`, `preview`,
  `contextActionRequests`, or their future mutation/admission behavior; their
  resolver reentrancy coverage belongs to their owning phases.
- Do not implement async resource loading, remote/network/file/asset-bundle IO,
  image decoding, image disposal, or engine ownership of returned app images.
- Do not make `ResourceKernel`, runtime state, frame caches, or widget state own
  resolved images, resolver generation, cache entries, budget counters, or
  same-frame suppression state.
- Do not route frame code, painters, or ordinary planners through
  `CanvasResourceResolver` or `ResourceCatalogPort` for asset binding.
- Do not change committed resource descriptor storage, edit/load descriptor
  mutation behavior, document/resource revisions, schema validation, or public
  resource read/dirty behavior except for active-session invalidation handoff.
- Do not satisfy architecture or DCM checks through metric-only wrappers, broad
  suppressions, generated-output hand edits, or production fixture-only seams.

Source of Truth:

The design input for this step is
`.design/2026-05-28-p7-resource-session-resolver-lifecycle.md`. Durable
resource lifecycle behavior remains defined by `docs/contracts/resources.md`,
`docs/contracts/cache_policy.md`, and
`docs/implementation/p7_resources_and_images.md`. Runtime/store/resource/frame
ownership remains defined by `docs/architecture/01_runtime_ownership.md`,
`docs/architecture/02_package_boundaries.md`,
`docs/architecture/03_data_model.md`, and
`docs/architecture/architecture_graph.yaml`. Future frame and Flutter lifecycle
ownership remains defined by `docs/implementation/p9_frame_rendering_and_caches.md`
and `docs/implementation/p13_flutter_surface.md`. Executable enforcement lives
in `test/**`, `tool/guardrails/**`, `tool/architecture_graph/**`, and generated
documentation checks. Roadmap closure state remains owned by `PLAN.md` and this
linked step file.

Compatibility:

Supported public consumers must see unchanged public resource APIs:
`CanvasResourceResolver.resolveImage(CanvasImageResource)`,
`CanvasResourcePort`, `CanvasResource`, `CanvasImageResource`,
`CanvasResourceSource.appKey`, runtime state APIs, schema v1 resource formats,
and existing public dirty-resource behavior. `CanvasRuntime.resources` remains
the public resource port. The resolver must receive a reconstructed
`CanvasImageResource` preserving the committed id, app key, `mimeType`,
`contentHash`, `byteLength`, and metadata; narrowing that payload would be a
compatibility change and is out of scope for this step. Dirty calls with no attached session continue to
publish the accepted `resourceVisual` state and repaint/effect intent exactly
as Step 39 established. Dirty calls with an attached session add only
pre-publication cache invalidation. Resolver callback mutation rejection must
continue to throw `StateError` before document, selection, preview,
resourceVisual, cache, repaint, action, or public-state side effects.
Returned `ui.Image` references remain app-owned; the engine must never dispose
them during cache eviction, resolver replacement, session drop, runtime swap, or
dispose.

Order Constraints:

Create the internal invalidation seam and extend the internal descriptor fact
payload before creating the resource-owned request/result/cache surface or
wiring runtime dirty handoff. Implement session-local resolver
generation, cache, frame-pass reset, and explicit result states before adding
runtime invalidation tests. For each `resolveImage` call, preserve this order:
missing descriptor/null-result suppression check; cache lookup; resolver budget
gate; `ResolverMutationGuard.runResolverCallback`; cache write only after a
non-null image result; placeholder return without durable null/missing/budget
cache writes. For resolver replacement, increment resolver generation and clear
cache and suppression before the next resolve. For accepted dirty calls,
`ResourceKernel` guard/catalog acceptance and `resourceVisualRevision`
increment remain the irreversible point from Step 39; after that point,
runtime must invalidate the active session sink if present before
`_publishRuntimeState()` or the commit-effect observer can run. The active sink
contract is internal and infallible for the real `SurfaceResourceSession`; no
attached sink is a no-op for cache work, not a dirty publication blocker. Update
guardrails, docs, graph data, generated graph views, and roadmap closure only
after focused behavior tests prove the new owner and ordering.

## Execution Units

### [x] Unit 1: Full image descriptor fact path

Owner:

The narrow committed-to-frame resource descriptor fact path:
`ResourceTable`/`StoreResourceDescriptorFacts`,
`FrameResourceDescriptorFacts`, and the `RuntimeRoot.resourceDescriptor()`
adapter.

Boundary:

Only the internal descriptor payload needed to preserve the public
`CanvasImageResource` resolver contract: store descriptor facts, frame
descriptor facts, runtime pass-through mapping, and focused descriptor fact
tests. This unit must not add `SurfaceResourceSession`, resource cache entries,
resolver calls, runtime dirty handoff, public API changes, frame paint binding,
or Flutter lifecycle wiring.

Change:

Extend `StoreResourceDescriptorFacts` and `FrameResourceDescriptorFacts` to
carry `mimeType`, `contentHash`, and `byteLength` alongside resource id, app
key, metadata, and resource revision. Update `RuntimeRoot.resourceDescriptor()`
to pass those fields through from committed store facts to frame facts without
exposing store internals, changing public resource DTOs, or changing schema v1
formats. Keep committed descriptor ownership in the store and keep resource
session code dependent only on immutable facts/request values, not on store or
runtime imports.

Completion Check:

`dart test test/runtime/runtime_read_ports_test.dart
test/contracts/internal_seam_shape_test.dart
test/api_contract/public_api_v1_compiles_as_written_test.dart
test/guardrails/public_api_declaration_checks_test.dart
test/codec/schema_v1/resources_appkey_only_test.dart` passes and proves
`FrameResourceDescriptorFacts` carries id, app key, `mimeType`, `contentHash`,
`byteLength`, metadata, and `resourceRevision` from committed
`CanvasImageResource` rows; missing descriptors still return `null`;
`FrameFactsPort.resourceDescriptor` remains the frame descriptor lookup seam;
store facts are not exposed publicly; public resource declarations and
`CanvasResourceResolver.resolveImage(CanvasImageResource)` still compile as
written from the public contract; the public API registry/declaration checks
still accept the resource surface; and schema v1 app-key resource encoding and
decoding still preserves the existing resource fields without format drift.
`dart analyze` reports no
unresolved field or duplicate declaration errors for the extended descriptor
fact path.

Depends On:

None.

### [x] Unit 2: Internal session seam and value model

Owner:

`lib/src/contracts/internal/**` and `lib/src/resources/**`.

Boundary:

Only the internal session invalidation seam and resource-owned request/result
value model: `ResourceSessionInvalidationSink`,
`ResourceImageResolveRequest`, `ResourceImageResolveResult` or equivalent
explicit result states, full public image descriptor fields, placeholder
bounds, resolver budget constant, and seam shape tests. This unit must not wire
runtime dirty handoff, implement cache mutation, or call app resolvers.

Change:

Add `ResourceSessionInvalidationSink` under `contracts/internal/**` with the
design-locked target/all invalidation methods and only public id imports.
Add resource-owned adapter/value declarations that can be built from the
immutable descriptor facts extended in Unit 1 plus a bounded placeholder
rectangle, including an explicit
missing-descriptor path and a reconstructed `CanvasImageResource` payload for
the app resolver. Define the internal
`kMaxSyncResourceResolverCallsPerFrame = 128` constant in a resource-owned
surface. Keep the resource declarations free of runtime, store, frame, surface,
Flutter widget, IO, asset-bundle, file, network, diagnostics, and cache-owner
imports.

Completion Check:

`dart test test/contracts/internal_seam_shape_test.dart
test/resources/resource_resolver_adapter_shape_test.dart` passes and proves
`ResourceSessionInvalidationSink` lives under `contracts/internal/**`, imports
only `CanvasResourceId`, exposes exactly target and all invalidation methods,
and does not name `RuntimeRoot`, `ResourceKernel`, `SurfaceResourceSession`,
cache entries, images, resolver callbacks, frame owners, or store owners. The
resource adapter shape test proves request values carry resource id, app key,
`mimeType`, `contentHash`, `byteLength`, metadata, resource revision,
placeholder bounds, a reconstructed full public `CanvasImageResource`, and an
explicit missing-descriptor state; result states distinguish resolved image,
missing-descriptor placeholder, no-resolver placeholder, null-result
placeholder, and budget placeholder; the budget constant is exactly 128; and
no resource value declaration imports
runtime, store, frame, surface, Flutter widgets, asset bundle, file, network,
or diagnostics owners.

Depends On:

Unit 1.

### [x] Unit 3: Surface session cache and resolver lifecycle

Owner:

`SurfaceResourceSession`, `ImageResolveCache`, and resolver adapter code under
`lib/src/resources/**`.

Boundary:

Only direct session behavior: `beginFrameResourcePass()`, `resolveImage(...)`,
`replaceResolver(CanvasResourceResolver?)`, target/all cache invalidation,
session drop/dispose cache clearing, resolver generation, cache identity,
same-frame null-result suppression, resolved-image cache writes, and
app-owned image no-dispose behavior. This unit must not wire runtime dirty
handoff or frame/widget lifecycle.

Change:

Implement `SurfaceResourceSession` with an injected
`CanvasResourceResolver?` and `ResolverMutationGuard`, resolver generation,
1024-entry `ImageResolveCache`, current-frame null-result suppression set keyed
by resolver generation/resource id/resource revision, and
resource-owned placeholder result creation. `beginFrameResourcePass()` resets
the per-frame budget and current-frame suppression. `replaceResolver` must
increment generation and clear cache/suppression before the next resolve.
Missing descriptors return bounded placeholders without resolver calls, budget
use, or cache writes. If the session has no resolver, `resolveImage` returns a
bounded no-resolver placeholder result with no guard callback, no budget use,
and no cache write. Cache hits return the cached app-owned image without
resolver calls or budget use and refresh LRU recency. Non-null resolver results
write exactly one cache entry for the current generation/resource id/resource
revision. Null resolver results return placeholders, are suppressed for the
rest of the same frame identity, and are not durable cache writes. Target
invalidation removes only matching resource-id cache entries across
generations/revisions; all invalidation clears the cache. Cache eviction,
invalidation, resolver
replacement, session drop, and dispose must never dispose app-owned images.

Completion Check:

`dart test test/resources/sync_image_resolver_test.dart
test/resources/app_owned_image_not_disposed_test.dart
test/resources/missing_result_suppressed_per_frame_test.dart
test/resources/surface_session_cache_lifecycle_test.dart
test/resources/resolver_swap_starts_fresh_cache_test.dart` passes and proves:
resolved images are returned synchronously and cached by resolver
generation/resource id/resource revision; same-key cache hits do not call the
resolver; different resource revisions miss cache; missing descriptors and null
resolver results return bounded placeholders with the request bounds and no
cache write; the resolver receives a `CanvasImageResource` whose id, app key,
`mimeType`, `contentHash`, `byteLength`, and metadata match the committed
descriptor facts used to build the request; null results are not retried in the
same frame; missing descriptors and absent resolvers return bounded placeholders
with no resolver callback, no guard callback, no budget use, and no cache write;
null-result identities are eligible again after `beginFrameResourcePass()`;
resolver swap increments
generation, clears cache and suppression, and does not reuse stale entries;
target invalidation evicts only that resource id; all invalidation clears the
session cache; 1024-entry capacity evicts the least-recently-used entry,
including proof that a cache hit refreshes recency before later capacity
eviction; and no fake app-owned image records a dispose call during
eviction, invalidation, resolver swap, session drop, or dispose.

Depends On:

Unit 2.

### [x] Unit 4: Resolver guard and frame budget

Owner:

`SurfaceResourceSession` and the existing runtime-owned
`ResolverMutationGuard` seam.

Boundary:

Only guarded resolver execution, resolver-call budget accounting,
budget-exceeded placeholder behavior, pending budget follow-up throttle state,
and reentrant public runtime mutation rejection. This unit must not implement
frame repaint scheduling, public diagnostics, async loading, or runtime dirty
handoff.

Change:

Call the app resolver only inside `ResolverMutationGuard.runResolverCallback`.
Consume one budget unit only for actual resolver callback attempts; cache hits,
missing descriptors, same-frame suppressed null-result identities, and
budget-exceeded placeholders must not consume additional calls. After 128
resolver callback attempts in a frame pass, return bounded budget placeholders
with no resolver call and no cache write. Record only resource-owned
budget-exceeded probe/throttle state through the read-only internal
`SurfaceResourceSession.hasPendingBudgetFollowUpRepaint` getter; set that flag
at most once per exhausted frame pass and clear it on the next
`beginFrameResourcePass()`.
Reentrant public runtime mutation attempted by a resolver callback must throw
`StateError` through the guard before document, selection, preview,
resourceVisual, cache, repaint/effect, public-state, action, or resolver-result
side effects occur.

Completion Check:

`dart test test/resources/resolver_frame_budget_test.dart
test/resources/resolver_reentrancy_rejected_test.dart` passes and proves the
first 128 uncached resolve requests in one frame pass may call the resolver,
the 129th and later uncached requests return bounded budget placeholders
without resolver calls or cache writes, cache hits do not consume budget,
missing descriptors do not consume budget, budget placeholders are retried in a
later frame pass, `hasPendingBudgetFollowUpRepaint` is set at most once per
exhausted frame pass and cleared by the next pass, resolver callbacks are
wrapped by `runResolverCallback`, nested resolver callbacks throw `StateError`,
and an uncaught rejected resolver callback attempt to call `markResourceDirty`,
`markAllResourcesDirty`, edit, load, selection, camera, or id generation
mutation leaves document, selection, preview, resourceVisual, cache,
repaint/effect, public-state, and action state unchanged.

Depends On:

Unit 3.

### [x] Unit 5: Runtime dirty handoff to active session

Owner:

`RuntimeRoot`, `ResourceSessionInvalidationSink`, and
`SurfaceResourceSession` sink implementation.

Boundary:

Only runtime active-session invalidation registration, accepted dirty target/all
handoff ordering, session cache eviction through the internal sink, no-session
behavior, and focused runtime/session integration tests. This unit must not add
public API, Flutter lifecycle, multi-surface arbitration, or frame paint
binding.

Change:

Make `SurfaceResourceSession` implement `ResourceSessionInvalidationSink`.
Add internal `RuntimeRoot` operations to attach and clear one nullable active
session invalidation sink for later P13 use, with clear/drop behavior that does
not dispose app-owned images. In `deliverResourceDirtyOutcome`, route accepted
target dirty outcomes to `invalidateResourceImage(id)` and accepted all-dirty
outcomes to `invalidateAllResourceImages()` before `_deliverResourceDirtyResult`
publishes runtime state or invokes the commit-effect observer. Keep no-session
dirty publication as a no-op for cache work and preserve Step 39 public dirty
revision/repaint behavior. Do not pass the sink to `ResourceKernel`; it
continues to emit only `ResourceDirtyOutcome`.

Completion Check:

`dart test test/resources/resource_dirty_test.dart
test/resources/mark_all_resources_dirty_test.dart
test/runtime/resource_dirty_runtime_delivery_test.dart` passes and proves an
attached session with a cached resolved image evicts only the target entry on
`markResourceDirty(id)`, resolves that target again on the next direct session
resolve, preserves other cached resource entries, and publishes the same
resourceVisual/repaint/effect behavior as Step 39. The mark-all test proves an
attached session cache is cleared for all resources, the next resolves call the
resolver again, and document/resource/selection/preview/view-camera/interaction/
epoch revisions and action streams remain unchanged except for
`resourceVisual`. Runtime delivery tests prove no attached session is a cache
no-op while dirty publication still occurs, `ResourceKernel` does not receive
or import the session sink, state listeners and commit-effect observers run
only after the active session has been invalidated, and clearing the active sink
prevents later dirty calls from mutating the dropped session.

Depends On:

Unit 4.

### [x] Unit 6: Resource session enforcement and source-of-truth closure

Owner:

Guardrail tooling, architecture graph data, generated graph views, durable
resource/architecture/verification docs, diagram sources, test registries,
`PLAN.md`, and this step file.

Boundary:

Only durable source-of-truth and enforcement surfaces that describe or
mechanically prove the implemented P7 resource session lifecycle:
`tool/guardrails/**`, guardrail tests, `docs/contracts/resources.md`,
`docs/contracts/cache_policy.md`, `docs/contracts/frame_rendering.md`,
`docs/implementation/p7_resources_and_images.md`,
`docs/implementation/p9_frame_rendering_and_caches.md`,
`docs/implementation/p13_flutter_surface.md`,
`docs/architecture/01_runtime_ownership.md`,
`docs/architecture/02_package_boundaries.md`,
`docs/architecture/03_data_model.md`,
`docs/architecture/architecture_graph.yaml`,
`docs/diagrams/*.mmd`, generated graph views, verification docs and registries,
`PLAN.md`, and this step file. This unit must not claim P9 frame paint binding
or P13 Flutter lifecycle closure.

Change:

Tighten or add structural proof that `lib/src/resources/**` may import only
public/internal contracts and resource-owned helpers, not runtime, store, frame,
surface, interaction, Flutter widgets, asset-bundle, file, network, or
diagnostics owners. Preserve or add negative proof that frame/painter code does
not call `CanvasResourceResolver` directly and does not use `ResourceCatalogPort`
for asset binding. The guardrail/source-of-truth update must carry the named
resource guardrails `resources.resolver_boundary_owned_by_surface_session`,
`resources.resolver_frame_budget`, `resources.no_same_frame_missing_retry`, and
`resources.resolver_reentrancy_rejected`; if they are kept as guardrails rather
than reclassified as behavior-test obligations, each id must be present in the
executable guardrail inventory, routed through `tool/guardrails/run.dart`, and
selectable with `--guardrail=<id>`. Update architecture graph nodes and edges so implemented P7
session owner, resolver/cache behavior, and runtime-to-active-session
invalidation handoff are no longer marked future. The
`resource.kernel.invalidates_surface_session` graph edge must be renamed,
re-evidenced, or otherwise repaired so it projects the implemented
`ResourceKernel -> ResourceDirtyOutcome -> RuntimeRoot ->
ResourceSessionInvalidationSink -> SurfaceResourceSession` handoff instead of
implying direct cache ownership or direct `ResourceKernel` session access, while
P9 frame renderer use and P13 Flutter lifecycle remain future. Update resource,
cache policy, frame rendering, P7, P9, P13, architecture, verification,
guardrail, and diagram docs to reflect the implemented session behavior and the
still-deferred integration owners. Regenerate generated docs and architecture
graph views through repository tooling. Mark Step 41 complete in `PLAN.md` and
mark this file's unit checkboxes complete only after all implementation,
guardrail, architecture, documentation, DCM, analyzer, and focused test checks
pass.

Completion Check:

`dart test test/guardrails/owner_dag_import_boundaries_test.dart
test/guardrails/import_boundaries_test.dart
test/contracts/internal_seam_shape_test.dart
test/smoke/public_incremental_smoke_test.dart` passes with negative fixtures for
resources importing runtime/store/frame/surface/interaction/Flutter/widget/IO
owners, frame or painters calling `CanvasResourceResolver`, frame using
`ResourceCatalogPort` for asset binding, and public/internal contracts
depending on `SurfaceResourceSession`. The smoke test must be extended to cover
the public resource surface after the session implementation: root-barrel public
consumers can still create/read resources, call dirty resource APIs with no
attached session, observe the accepted `resourceVisual` publication, and retain
unchanged public API access without importing private session types. `dart run
tool/guardrails/run.dart` passes, and
`dart run tool/guardrails/run.dart --guardrail=resources.resolver_boundary_owned_by_surface_session`,
`dart run tool/guardrails/run.dart --guardrail=resources.resolver_frame_budget`,
`dart run tool/guardrails/run.dart --guardrail=resources.no_same_frame_missing_retry`,
and
`dart run tool/guardrails/run.dart --guardrail=resources.resolver_reentrancy_rejected`
each execute a real routed check instead of failing as unknown ids or passing
only because the id is absent; if any of these ids are intentionally not
executable guardrails after implementation, the source-of-truth docs must
reclassify that id away from "guardrail" and point to the concrete behavior
test that owns the proof. `dart run
tool/architecture_graph/check.dart --phase P7` and `dart run
tool/architecture_graph/generate_views.dart --phase P7 --check` pass with graph
data that distinguishes implemented P7 session and invalidation behavior from
future P9/P13 integration. `dart run docs/tool/sync_generated_docs.dart
--check` and `dart run docs/tool/check_docs.dart` pass after docs, registries,
diagrams, generated docs, and graph views are updated. Final implementation
verification must explicitly review `docs/diagrams/seq_resource_resolution.mmd`,
`docs/diagrams/state_resource_resolution.mmd`,
`docs/diagrams/dfd_resource_resolution.mmd`, and
`docs/diagrams/dfd_cache_invalidation.mmd`; each must either have a reviewed
diff that projects the implemented P7 session behavior or a checked
repository-local assertion in docs tooling, architecture graph tests, diagram
registry metadata, or a durable source-of-truth document that records why the
existing diagram already projects the implemented P7 state. A chat-only or
handoff-only no-op note is not sufficient for step closure. Final verification
from the repository root also includes `dart analyze`, `dcm analyze .`,
`dcm calculate-metrics .`, and the focused tests named by Units 1-5.

Depends On:

Unit 5.
