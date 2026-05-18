# Change Contract

## 1. Change Mandate

Move resolved image cache and synchronous resolver-call lifecycle from runtime-wide resource ownership to one resource session owned by each active canvas surface.

## 2. Change Boundary

### Change Surface Summary

Mode: documentation and architecture contract update. Primary surfaces: resource lifecycle, surface lifecycle, frame rendering, cache policy, resource-resolution diagrams, verification guardrails, planned tests, phase guidance, package layout, redesign backlog cleanup, audit cleanup, and generated documentation indexes. Production/test status: no production Dart or Dart test implementation exists in the root package yet; this step updates the target architecture before resource and Flutter-surface implementation lands.

### Included in the Change

- Introduce `SurfaceResourceSession` as the target owner for the per-active-surface resolver reference, `resolverGeneration`, `ImageResolveCache`, per-frame resolver budget, same-frame missing/null suppression, and budget-exceeded follow-up throttle.
- Keep committed resource descriptors and `resourceRevision` owned by committed document state.
- Keep public `resourceVisualRevision` / `state.revisions.resourceVisual` as the dirty-resource repaint signal owned by runtime resource dirty orchestration.
- Keep `ResourceKernel` as the non-surface resource API and dirty-resource orchestration owner, but remove runtime-wide ownership of resolved image references and resolver-call cache state.
- Define `ImageResolveCache` lookup identity as `resolverGeneration`, `resourceId`, and `resourceRevision`.
- State that the global `resourceVisualRevision` is not an `ImageResolveCache` key component; dirty-resource operations invalidate target or all active session cache entries explicitly.
- Define active surface lifecycle rules: successful attach creates an empty `SurfaceResourceSession`; resource resolver replacement increments `resolverGeneration` and clears stale cache entries; detach, dispose, or runtime swap drops the session without disposing app-owned `ui.Image` instances.
- Align frame rendering so `FrameEngine` asks `SurfaceResourceSession` for resolved paint assets; painters and frame code never call `CanvasResourceResolver` directly.
- Align resource-resolution diagrams, dispose diagrams, verification guardrails, planned tests, phase guidance, indexes, and registry references with the selected owner.
- Delete the promoted resource resolver cache section from `redesign.md` after active contracts own the decision.
- Remove `HOLE-003` resource cache / resolver-surface lifecycle entries from `audit.md` after active contracts and proof mappings close the issue.
- Retire wording and ids that say `ResourceKernel` owns the resolver boundary when they are accepted target architecture rather than historical evidence.

### Not Included in the Change

- No production Dart implementation under `lib/**`.
- No Dart test implementation under `test/**`.
- No public API field or constructor shape change for `CanvasSurface`, `CanvasResourceResolver`, `CanvasResourcePort`, or `CanvasRuntimeState`.
- No async resolver support.
- No engine IO, asset-bundle loading, file loading, remote/network loading, or application-domain resource storage.
- No engine disposal of app-owned `ui.Image` instances.
- No multi-surface shared-runtime collaboration contract beyond the existing v1 single-active-surface rule.
- No per-resource visual stamp unless a future contract introduces a distinct owner for that stamp.
- No generic global cache invalidation replacing target/all dirty-resource invalidation.

## 3. Surrounding Code Review

### Inspected Artifacts

- `.research/2026-05-18-resource-resolver-cache-surface-session.md:13` records that current documentation stores descriptors in committed document state while placing resolved image caching under runtime resource ownership.
- `.research/2026-05-18-resource-resolver-cache-surface-session.md:17` records that `SurfaceResourceSession` and `resolverGeneration` are not current root documentation terms.
- `docs/architecture/01_runtime_ownership.md:54` lists `DocumentStoreKernel` as owner of committed document state, document revisions, resource descriptors, and public document projection cache.
- `docs/architecture/01_runtime_ownership.md:59` currently lists `ResourceKernel` as owner of resolver boundary, image resolve cache, and dirty resource ids.
- `docs/architecture/02_package_boundaries.md:104` through `docs/architecture/02_package_boundaries.md:108` currently plan `resources/resource_kernel.dart`, `resources/resource_cache.dart`, and `resources/resource_resolver_adapter.dart`, with no `SurfaceResourceSession` file.
- `docs/architecture/03_data_model.md:122` defines `resourceRevision` as resource descriptor changes.
- `docs/architecture/03_data_model.md:123` defines `resourceVisualRevision` as `markResourceDirty` / resolver visual invalidation.
- `docs/contracts/resources.md:52` states that `DocumentStoreKernel` owns resource descriptors and `ResourceKernel` owns runtime caches.
- `docs/contracts/resources.md:63` through `docs/contracts/resources.md:69` state that resource resolution receives descriptor snapshots and `resourceRevision`, that `ResourceKernel` must not read or mutate `DocumentStoreKernel`, and that painters and frame paint code resolve only through `ResourceKernel`.
- `docs/contracts/resources.md:74` through `docs/contracts/resources.md:80` define `ImageResolveCache` as `ResourceKernel`-owned, keyed by `resourceId/resourceRevision`, and invalidated by resource dirty or descriptor change.
- `docs/contracts/resources.md:119` through `docs/contracts/resources.md:123` state that dirty-resource calls do not change document revision, increment `state.revisions.resourceVisual`, invalidate resolved cache entries, and publish main repaint intent.
- `docs/contracts/resources.md:132` through `docs/contracts/resources.md:137` state that `resourceVisualRevision` maps to public runtime state and that an attached `CanvasSurface` observes repaint intent.
- `docs/contracts/resources.md:179` through `docs/contracts/resources.md:191` define the resolver frame budget, budget-exceeded placeholder behavior, and current `ResourceKernel` ownership of the follow-up retry scheduler.
- `docs/contracts/public_api_v1.md:442` through `docs/contracts/public_api_v1.md:453` define `CanvasSurface` with optional `CanvasResourceResolver? resourceResolver`.
- `docs/contracts/public_api_v1.md:463` through `docs/contracts/public_api_v1.md:472` define the v1 single-active-surface lifecycle.
- `docs/contracts/public_api_v1.md:487` and `docs/contracts/public_api_v1.md:488` state that `CanvasSurface.resourceResolver` is the app-owned synchronous image resolver for that surface and that the surface does not dispose app-provided images.
- `docs/contracts/public_api_v1.md:1453` through `docs/contracts/public_api_v1.md:1468` define the synchronous resolver and app-owned `ui.Image` disposal rule.
- `docs/contracts/frame_rendering.md:68` includes `resourceVisualRevision` in captured main frame facts.
- `docs/contracts/frame_rendering.md:96` and `docs/contracts/frame_rendering.md:97` state that the image resolver is the only external read boundary in paint and that v1 resolver calls are synchronous and bounded.
- `docs/contracts/cache_policy.md:42` through `docs/contracts/cache_policy.md:55` define the active hot-cache ledger; `ImageResolveCache` is currently documented separately in the resource lifecycle contract rather than this cache ledger.
- `docs/diagrams/seq_main_paint.mmd:68` through `docs/diagrams/seq_main_paint.mmd:81` show `FrameEngine` passing descriptor snapshot, `resourceRevision`, and resolver to `ResourceKernel`.
- `docs/diagrams/seq_main_paint.mmd:95` states that `ResourceKernel` owns the app resolver boundary.
- `docs/diagrams/seq_resource_resolution.mmd:33` through `docs/diagrams/seq_resource_resolution.mmd:55` show `ImageResolveCache` lookup and storage by `resourceId + resourceRevision`.
- `docs/diagrams/seq_resource_resolution.mmd:66` states that `ResourceKernel` owns the resolver boundary and budget-exceeded retry scheduler.
- `docs/diagrams/c4_component_runtime.mmd:13` states that `ResourceKernel` owns resolver boundary, image resolve cache, and dirty resource ids in an active runtime component diagram.
- `docs/diagrams/dfd_resource_resolution.mmd:48` through `docs/diagrams/dfd_resource_resolution.mmd:92` show runtime resource resolution through `ResourceKernel` and cache identity by `resourceId + resourceRevision`.
- `docs/diagrams/state_resource_resolution.mmd:9` through `docs/diagrams/state_resource_resolution.mmd:13` state that `ResourceKernel` owns dirty ids, resolved-image cache entries, and resolver calls.
- `docs/diagrams/seq_dispose_during_gesture.mmd:68` through `docs/diagrams/seq_dispose_during_gesture.mmd:70` say dispose drops resolved-image cache entries without disposing app-owned images.
- `docs/verification/guardrails.md:185` defines `resources.resolver_boundary_owned_by_resource_kernel`.
- `docs/verification/guardrails.md:186` defines `resources.resolver_frame_budget` with `ResourceKernel` as owner.
- `docs/verification/guardrails.md:187` defines same-frame missing retry suppression by `resourceId` and `resourceRevision`.
- `docs/implementation/p7_resources_and_images.md:20` through `docs/implementation/p7_resources_and_images.md:25` put resolver bridge, missing/null cache, frame budget, and reentrancy guard in P7.
- `docs/implementation/p9_frame_rendering_and_caches.md:32` states that resource resolver access is only through `ResourceKernel`.
- `docs/implementation/p13_flutter_surface.md:11` through `docs/implementation/p13_flutter_surface.md:16` put `CanvasSurface`, single-active-surface gate, painters, and synchronous resolver bridge in P13.
- `redesign.md:1` starts `## 6. Resource resolver cache переносим в surface resource session`, which is backlog/design-note wording to delete after this decision is promoted into active contracts.
- `audit.md:13` lists `HOLE-003` under P3 resources/surface lifecycle blockers.
- `audit.md:26` lists `HOLE-003` as "resolved image cache не переживает смену resolver/surface некорректно".
- `audit.md:80` through `audit.md:102` define the `HOLE-003` audit checklist that this step must close and remove after active docs and proof mapping exist.
- `test ! -d lib && test ! -d test` confirms the root package currently has no production `lib/` or test `test/` directory, so this step is documentation/architecture only.

### Current Entry Path

The current documented resource-resolution entry path starts when `CanvasSurface` paints with a `resourceResolver`, `FrameEngine` reads committed descriptor snapshots and `resourceRevision`, then `FrameEngine` passes the resolver and descriptor facts to `ResourceKernel` for cache lookup, budget enforcement, resolver invocation, and placeholder selection. Dirty-resource entry paths start at `runtime.resources.markResourceDirty(resourceId)` or `runtime.resources.markAllResourcesDirty()`, update public resource visual state, invalidate resolved cache entries, and publish main repaint intent.

### Current Owner

The current accepted documentation owner for resolved image cache state is `ResourceKernel`. `CanvasSurface` already owns the resolver input and surface lifecycle, while `DocumentStoreKernel` owns descriptors and resource descriptor revisions. This creates a lifecycle mismatch: the resolver is surface-scoped, but the resolved-image cache is described as runtime-scoped.

### Adjacent Abstractions

- `CanvasSurface` is the Flutter paint host and single-active-surface lifecycle owner.
- `FrameEngine` captures immutable main frame facts and builds paint assets without live painter reads.
- `ResourceKernel` owns resource API behavior, dirty-resource signals, and resolver safety policy in the current docs.
- `ImageResolveCache` is the existing named cache for app-owned image references.
- `resourceRevision` and `resourceVisualRevision` are existing revision families with distinct meanings.
- `CanvasRuntimeState.revisions.resourceVisual` is the public dirty-resource observation domain.
- Existing frame caches already separate cache identity from public runtime revision domains.

### Existing Tests

No root-package `test/**` Dart files exist yet. Planned resource tests in `docs/verification/tests.md` include `test.resources.sync_image_resolver`, `test.resources.app_owned_image_not_disposed`, `test.resources.resource_dirty`, `test.resources.mark_all_resources_dirty`, `test.resources.painter_never_calls_resolver_directly`, `test.resources.missing_result_cached_per_revision`, `test.resources.resolver_frame_budget`, and `test.resources.resolver_reentrancy_rejected`. Planned Flutter bridge tests include `test.flutter_bridge.single_active_surface` and `test.flutter_bridge.widget_paint`.

### Analogous Implementation Path

The closest accepted target-architecture precedent is the documented `CanvasSurface` lifecycle: surface attach succeeds before side effects, a second active surface is rejected before resolver attachment side effects, and detach/dispose remove only listeners registered by that surface. The frame-cache architecture also treats paint-time values as captured inputs instead of runtime-owned persistent state when their lifecycle belongs to the paint boundary.

### Governing Repository Rules

- `PLAN.md` is the active roadmap and each step uses a dedicated contract file.
- Repository documentation under `docs/` is the durable source of truth for the new-engine transition and target architecture.
- Documentation changes do not require `dart analyze`, `dcm analyze .`, or `dcm calculate-metrics .`.
- Documentation navigation and registry consistency are checked with `dart run docs/tool/generate_context_capsules.dart --check` and `dart run docs/tool/check_docs.dart`.
- Public communication and to-do lists are Russian; repository documentation is English.

### Rejected Misleading Local Patterns

- Current `ResourceKernel` ownership wording is the defect source, not the target design.
- A runtime-wide cache with only a `resolverGeneration` key still leaves surface-scoped app image references in the wrong lifecycle owner.
- A global `resourceVisualRevision` cache key would turn one dirty resource into cold-cache misses for unrelated resources.
- Putting ad hoc cache maps directly in `CanvasSurface` would make the widget own resource policy instead of merely owning the session lifecycle.
- `redesign.md` section 6 and `audit.md` `HOLE-003` are tracking artifacts for this gap, not the final source of truth after the active contracts are updated.
- Legacy package controller, scene, and image-loading structures are donor material only and must not become the new resource resolver architecture.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

The problem belongs at the boundary between surface lifecycle and resource resolution policy. App resolver callbacks and resolved app-owned images are scoped to an active surface, while resource descriptors and dirty-resource public state are scoped to the runtime/document resource domain.

#### Selected Architectural Form

Introduce `SurfaceResourceSession` as a resource-module type whose instance is owned by one active `CanvasSurface`.

```text
Document/resource runtime state:
  resource descriptors
  resourceRevision
  resourceVisualRevision
  dirty-resource repaint orchestration
  resolver reentrancy rejection boundary

SurfaceResourceSession:
  CanvasResourceResolver?
  resolverGeneration
  ImageResolveCache
  per-frame resolver budget
  same-frame missing/null suppression
  budget-exceeded follow-up throttle
```

The cache key is:

```text
resolverGeneration + resourceId + resourceRevision
```

`resourceVisualRevision` remains a public dirty-resource repaint signal and is not a global `ImageResolveCache` key component. `markResourceDirty(id)` invalidates target cache entries in the active session if a session exists. `markAllResourcesDirty()` clears the active session cache if a session exists. If no surface is attached, there is no surface cache to invalidate and the next attach starts with an empty session.

#### Owning Layer or Module

- `DocumentStoreKernel` owns committed resource descriptors and `resourceRevision`.
- Runtime resource dirty orchestration, implemented through `ResourceKernel` / `RuntimeRoot`, owns `CanvasResourcePort`, dirty-resource validation, `resourceVisualRevision` publication, dirty target/all invalidation events, and resolver reentrancy rejection.
- The resources module owns the `SurfaceResourceSession` type, `ImageResolveCache` policy, resolver budget, same-frame missing/null suppression, and bounded placeholder result policy.
- `CanvasSurface` owns the lifecycle of one `SurfaceResourceSession` instance from successful attach until detach, dispose, or runtime swap.
- `FrameEngine` consumes descriptor snapshots and a `SurfaceResourceSession` handle to produce paint assets; it does not call `CanvasResourceResolver` directly.
- Painters consume resolved image paint assets or bounded placeholders only.

#### Architectural Dependency / Import Direction

The resources module may define `SurfaceResourceSession` and narrow resolver/cache interfaces without importing Flutter widget implementation, `DocumentStoreKernel`, or concrete `FrameEngine`. The Flutter bridge may construct and dispose a `SurfaceResourceSession`. Frame rendering may depend on the resource-session interface as an input, but not on the concrete Flutter widget. Runtime resource dirty orchestration may notify an attached session through a narrow invalidation boundary; it must not store app resolver callbacks or app-owned image references.

#### State and Data Ownership

- Resource descriptors are committed document state.
- `resourceRevision` changes when descriptors change.
- `resourceVisualRevision` changes when external resource visuals are marked dirty.
- `resolverGeneration` is session-local and changes on session creation or resolver replacement.
- `ImageResolveCache` stores app-owned `ui.Image` references only inside a live surface session.
- Same-frame missing/null suppression is frame-local session state and clears at frame boundaries.
- Budget-exceeded placeholders are not stored as resolved, missing, or null cache entries.
- App-owned `ui.Image` instances are never disposed by the engine, surface, session, runtime, or cache.

#### Entry and Exit Boundaries

- Attach entry: after successful single-active-surface attachment, `CanvasSurface` creates a new empty `SurfaceResourceSession`.
- Resolver update entry: when an active surface receives a different `resourceResolver`, the session increments `resolverGeneration` and prevents old-generation cache hits; stale entries are cleared or made unreachable before the next resolve.
- Frame entry: `FrameEngine` reads descriptor snapshots and `resourceRevision`, then asks `SurfaceResourceSession` for resolved paint assets.
- Dirty entry: `markResourceDirty` / `markAllResourcesDirty` update runtime public state and send target/all invalidation to the active session when one exists.
- Detach exit: detach, dispose, or runtime swap drops the session and its cache without disposing app-owned images.
- Paint exit: painters receive only immutable records plus resolved assets/placeholders.

#### Permitted Extension Seam

Future multi-surface support may create one `SurfaceResourceSession` per active surface only after a separate multi-surface contract changes the v1 single-active-surface rule. Future async resolver support requires a separate public API and lifecycle contract. Future per-resource visual stamps may be introduced only with an explicit owner and verification; the global `resourceVisualRevision` must not be repurposed as a cache key.

#### Rejected Alternatives

- Keep `ImageResolveCache` in `ResourceKernel` and add `resolverGeneration` to the runtime cache key: rejected because the runtime would still retain surface-scoped app image references.
- Add global `resourceVisualRevision` to the cache key: rejected because one dirty resource would invalidate cache usefulness for unrelated resources.
- Move resolver calls into `FrameEngine` or painters: rejected because it weakens the external read boundary and makes resolver budget/reentrancy harder to enforce once.
- Let `CanvasSurface` own a raw image map directly: rejected because widget code would own resource policy instead of a resource-module session instance.
- Dispose app-owned images on session drop: rejected because current public API explicitly keeps image disposal application-owned.
- Add async resolver support while moving the cache: rejected because v1 resolver calls are synchronous and async would change public behavior.

#### Why This Level Is Correct

The selected owner matches lifecycle: descriptors and dirty-resource public state live with runtime/document resources, while resolved images and resolver callbacks live with the active surface that produced them. Placing the type in the resources module keeps cache policy cohesive; placing the instance lifecycle in `CanvasSurface` prevents stale images from surviving detach, runtime swap, or resolver swap.

#### Verification Strategy

Semantic proof uses targeted searches to show active contracts describe `SurfaceResourceSession`, `resolverGeneration`, surface-owned cache lifecycle, and target/all dirty invalidation, while no accepted target wording leaves resolved image cache or resolver boundary ownership in `ResourceKernel`. Structural proof uses documentation tooling and generated index checks to keep registry, guardrail, test, and diagram navigation coherent.

## 5. Locked Decisions

- `SurfaceResourceSession` is the selected successor owner for resolver callback state, resolved image cache entries, resolver budget, missing/null same-frame suppression, and budget-exceeded follow-up throttle.
- The resources module owns `SurfaceResourceSession` policy; `CanvasSurface` owns its instance lifecycle.
- `ResourceKernel` remains a runtime resource owner for descriptor-facing resource APIs, dirty-resource orchestration, and reentrancy rejection, but not for app resolver callback retention or resolved `ui.Image` cache entries.
- `ImageResolveCache` identity is `resolverGeneration + resourceId + resourceRevision`.
- `resourceVisualRevision` is not an `ImageResolveCache` key component in v1.
- Dirty-resource calls invalidate active session entries by target id or all resources; they do not rely on global cache-key churn.
- Missing/null resolver results are suppressed only within the current frame/session generation, not stored as durable resolved image cache results.
- Resolver replacement on an active surface increments `resolverGeneration` and prevents old resolver results from being reused.
- Session disposal drops cache entries without disposing app-owned images.
- The guardrail id `resources.resolver_boundary_owned_by_resource_kernel` is retired in favor of `resources.resolver_boundary_owned_by_surface_session`.
- The planned test id `test.resources.missing_result_cached_per_revision` is retired in favor of `test.resources.missing_result_suppressed_per_frame`.

## 6. Result Requirements

- Active resource lifecycle docs define `SurfaceResourceSession` and make resolved image cache lifecycle surface-scoped.
- Active public surface docs state when a session is created, refreshed, and dropped.
- Active frame rendering docs route image resolution through a resource session instead of passing the raw resolver to `ResourceKernel`.
- Active cache policy docs or resource cache policy docs declare the owner, key, invalidation, capacity, eviction, and probes for `ImageResolveCache`.
- Active resource dirty docs preserve `state.revisions.resourceVisual`, no document revision increment, and target/all cache invalidation semantics.
- Active diagrams show `CanvasSurface` owning the session lifecycle, `FrameEngine` using the session as the resolver boundary, and session disposal dropping cache entries without image disposal.
- Active verification docs include guardrails/tests for surface-session resolver ownership, session cache lifecycle, resolver swap isolation, frame budget behavior, no same-frame missing retry, and app-owned image non-disposal.
- No active target architecture doc says `ResourceKernel` owns resolved-image cache entries or the app resolver boundary.
- `redesign.md` no longer contains the "Resource resolver cache переносим в surface resource session" backlog section.
- `audit.md` no longer lists `HOLE-003` once active contracts and proof mappings close that gap.

## 7. Execution Order and Gates

### Preconditions

- Work starts from the repository root.
- Confirm the worktree before editing and preserve unrelated changes, including untracked `.research/**` files.
- Treat this as documentation/architecture work only unless a later user request explicitly asks for implementation.

### Required Order

1. Lock owner and lifecycle semantics in architecture, package layout, public API, resource lifecycle, data model, and cache policy docs.
2. Align frame rendering, resource-resolution diagrams, surface lifecycle diagrams, dispose diagrams, and cache-invalidation diagrams.
3. Align phase guidance, verification guardrails, planned tests, benchmarks, release gates, registry, and generated indexes.
4. Delete the promoted redesign section and remove the closed `HOLE-003` audit entries.
5. Run documentation structural checks and targeted semantic retirement checks.

### Successor Seam and Retirement Gates

- Retired guardrail id: `resources.resolver_boundary_owned_by_resource_kernel`.
- Successor guardrail id: `resources.resolver_boundary_owned_by_surface_session`.
- Retirement gate: no active docs, registry, index, phase, release-gate, or diagram text may contain `resources.resolver_boundary_owned_by_resource_kernel` after Slice 3.
- Retired planned test id: `test.resources.missing_result_cached_per_revision`.
- Successor planned test id: `test.resources.missing_result_suppressed_per_frame`.
- Retirement gate: no active verification, index, registry, or phase guidance may contain `test.resources.missing_result_cached_per_revision` or `missing_result_cached_per_revision_test.dart` after Slice 3.

### Seam Migration Matrix

| Changed seam | Successor seam | Affected consumers or documents | Migration slice | Retirement proof |
|---|---|---|---|---|
| Runtime-owned resolver boundary wording through `ResourceKernel` | `SurfaceResourceSession` resource-session boundary | `docs/contracts/resources.md`, `docs/contracts/frame_rendering.md`, resource-resolution diagrams, P7/P9/P13 phase guidance | Slices 1 and 2 | targeted `rg` proof rejects accepted `ResourceKernel` resolver-boundary/cache-owner wording |
| `resources.resolver_boundary_owned_by_resource_kernel` | `resources.resolver_boundary_owned_by_surface_session` | `docs/contracts/resources.md`, `docs/verification/guardrails.md`, `docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`, `docs/verification/release_gates.md`, `docs/_registry/sections.yaml`, phase docs | Slice 3 | targeted `rg` proof finds the successor id and rejects the retired id |
| `test.resources.missing_result_cached_per_revision` | `test.resources.missing_result_suppressed_per_frame` | `docs/contracts/resources.md`, `docs/verification/tests.md`, `docs/indexes/by_test_area.md`, `docs/_registry/sections.yaml`, P7 phase guidance | Slice 3 | targeted `rg` proof finds the successor id/path and rejects the retired id/path |
| `redesign.md` section `## 6. Resource resolver cache переносим в surface resource session` | Active resource/surface/frame contracts and Step 8 proof mapping | `redesign.md`, `docs/contracts/resources.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/frame_rendering.md`, verification docs | Slice 3 | targeted `rg` proof rejects the promoted redesign section title |
| `audit.md` `HOLE-003` | Active contracts plus guardrails/tests for surface-session cache lifecycle | `audit.md`, `docs/verification/guardrails.md`, `docs/verification/tests.md`, indexes, registry, release gates | Slice 3 | targeted `rg` proof rejects `HOLE-003` and its title in `audit.md` |

### Cross-Slice Finalization

- Complete guardrail and planned-test id migration in one finalization pass; do not leave mixed old/new ids across docs, indexes, registry, or release gates.
- Delete the exact promoted section from `redesign.md`; do not preserve the same decision in backlog prose after active contracts own it.
- Remove `HOLE-003` from `audit.md` ordering, blocker lists, and detailed checklist; the audit file keeps only remaining holes.
- Refresh generated context/navigation artifacts only through repository docs tooling; do not hand-edit generated output unless the tool identifies it as a source file.
- Keep `.research/**` as evidence only; do not convert it into normative architecture.

### Deferred Broad Verification

Slice-local proof may run targeted semantic checks and documentation structural checks as soon as a slice changes the relevant source files. The final gate must repeat the broad documentation structural checks after all slices and cleanup are complete. `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` are intentionally outside this documentation-only step.

## 8. Implementation Rules

### Protected Invariants

- Resource descriptors remain committed document facts.
- Resource descriptor mutation remains inside `CanvasEdit`.
- Dirty-resource calls do not increment document revision.
- Public resource visual state remains `state.revisions.resourceVisual`.
- Runtime owners must not retain app resolver callbacks or app-owned `ui.Image` cache entries after surface detach.
- `SurfaceResourceSession` must not import Flutter widget code or concrete document store internals.
- `FrameEngine` and painters must not call `CanvasResourceResolver` directly.
- Budget-exceeded placeholders are not cached as null, missing, or resolved images.
- Same-frame missing/null suppression must not become a durable cross-frame cache.
- Global `resourceVisualRevision` must not be used as an `ImageResolveCache` key component.
- Engine code must never dispose app-owned `ui.Image` instances.
- v1 remains synchronous and app-key-only for resource resolution.

### Required Proof

- Use targeted semantic proof to show active target docs define `SurfaceResourceSession`, `resolverGeneration`, and surface-owned cache lifecycle.
- Use targeted negative proof to show active target docs no longer place resolved image cache entries or the app resolver boundary in `ResourceKernel`.
- Use targeted cache-key proof to show `ImageResolveCache` identity is `resolverGeneration + resourceId + resourceRevision` and not global `resourceVisualRevision`, including multiline negative proof for rejected key blocks.
- Use targeted migration proof to show successor guardrail and planned-test ids replaced retired ids everywhere in active references.
- Use documentation structural proof to keep registries, indexes, diagrams catalog, and context capsules coherent.

### Allowed Change Surface

- `docs/architecture/01_runtime_ownership.md`
- `docs/architecture/02_package_boundaries.md`
- `docs/architecture/03_data_model.md`
- `docs/contracts/public_api_v1.md`
- `docs/contracts/resources.md`
- `docs/contracts/frame_rendering.md`
- `docs/contracts/cache_policy.md`
- `docs/contracts/operation_matrix.md` only if dirty-resource invalidation wording needs alignment
- `docs/diagrams/seq_main_paint.mmd`
- `docs/diagrams/c4_component_runtime.mmd`
- `docs/diagrams/seq_resource_resolution.mmd`
- `docs/diagrams/dfd_resource_resolution.mmd`
- `docs/diagrams/state_resource_resolution.mmd`
- `docs/diagrams/dfd_main_paint_frame.mmd`
- `docs/diagrams/dfd_cache_invalidation.mmd`
- `docs/diagrams/seq_dispose_during_gesture.mmd`
- `docs/diagrams/seq_single_active_surface.mmd`
- `docs/implementation/p7_resources_and_images.md`
- `docs/implementation/p9_frame_rendering_and_caches.md`
- `docs/implementation/p13_flutter_surface.md`
- `docs/verification/guardrails.md`
- `docs/verification/tests.md`
- `docs/verification/benchmarks.md`
- `docs/verification/release_gates.md`
- `docs/indexes/by_guardrail.md`
- `docs/indexes/by_test_area.md`
- `docs/indexes/by_subsystem.md`
- `docs/_registry/sections.yaml`
- `redesign.md`
- `audit.md`

### Forbidden Moves

- Do not add production code or tests in this step.
- Do not add public API fields, public revision domains, or new resolver API methods.
- Do not introduce async resolver behavior.
- Do not keep a runtime-wide resolved image cache and call it surface-safe only because generation is part of the key.
- Do not use global `resourceVisualRevision` as a cache key.
- Do not move resolver calls into painters or direct frame code.
- Do not add sync glue to keep two resolved image caches consistent.
- Do not use legacy implementation files as edit targets.

## 9. Vertical Slices

### Slice 1. [x] Lock Surface Resource Session Ownership

#### Slice Contract

Architecture, package layout, public API, resource lifecycle, data model, and cache policy docs define `SurfaceResourceSession` as the surface-lifetime owner of resolver cache state while preserving runtime/document ownership of descriptors and dirty-resource public state.

#### Files

- Primary edit: `docs/contracts/resources.md` - replace runtime-owned resolved cache contract with surface-session ownership, key, lifecycle, dirty invalidation, missing suppression, budget, and app-owned image rules.
- Primary edit: `docs/contracts/public_api_v1.md` - add surface session lifecycle semantics to `CanvasSurface` and resolver rules without changing public constructor/API shape.
- Primary edit: `docs/architecture/01_runtime_ownership.md` - update owner table so `ResourceKernel` no longer owns resolved image cache entries or app resolver boundary.
- Primary edit: `docs/architecture/02_package_boundaries.md` - add planned resources-module placement for `surface_resource_session.dart` and align resource cache/resolver adapter names if needed.
- Primary edit: `docs/architecture/03_data_model.md` - clarify `resourceVisualRevision` as dirty-resource public state, not the global image cache key.
- Alignment edit: `docs/contracts/cache_policy.md` - add or align `ImageResolveCache` policy row or cross-reference so owner/key/invalidation/capacity are declared once coherently.
- Verify-only check: `docs/tool/check_docs.dart` - repository documentation structure checker.

#### Change

Write the selected owner split into the active contracts. The resource module owns the session type and cache policy; `CanvasSurface` owns the instance lifecycle; runtime resource dirty orchestration owns public dirty state and invalidation events.

#### Slice Verification

##### Semantic Proof

Proves the selected owner and key exist in the active resource and surface contracts:

```bash
bash -lc 'set -e
for file in docs/contracts/resources.md docs/contracts/public_api_v1.md docs/architecture/01_runtime_ownership.md; do
  rg -q "SurfaceResourceSession" "$file"
done
rg -q "resolverGeneration" docs/contracts/resources.md
rg -q "resolverGeneration.*resourceId.*resourceRevision|resourceId.*resourceRevision.*resolverGeneration" docs/contracts/resources.md
rg -q "markResourceDirty.*target" docs/contracts/resources.md
rg -q "markAllResourcesDirty.*clear" docs/contracts/resources.md
rg -q "app-owned.*ui.Image" docs/contracts/resources.md
rg -q "surface_resource_session.dart" docs/architecture/02_package_boundaries.md'
```

Proves the accepted owner docs no longer assign resolved-image cache entries or resolver boundary ownership to `ResourceKernel`:

```bash
bash -lc 'set -e
! rg -n "ResourceKernel.*resolver boundary|ResourceKernel.*image resolve cache|ResourceKernel.*resolved-image cache|ResourceKernel-owned.*ImageResolveCache|ImageResolveCache.*ResourceKernel-owned|it owns resolver calls, resolved-image cache entries|ResourceKernel owns the budget-exceeded retry scheduler" docs/contracts/resources.md docs/architecture/01_runtime_ownership.md docs/contracts/public_api_v1.md docs/contracts/cache_policy.md'
```

Proves the global resource visual revision is not the cache key:

```bash
bash -lc 'set -e
! rg -n "ImageResolveCache.*resourceVisualRevision|resourceVisualRevision.*ImageResolveCache.*key|resourceVisualRevision.*cache key" docs/contracts/resources.md docs/contracts/cache_policy.md docs/architecture/03_data_model.md'
bash -lc 'set -e
! rg -U -n "ImageResolveCache(Key)?[\\s\\S]{0,400}resourceVisualRevision|resourceVisualRevision[\\s\\S]{0,400}ImageResolveCache(Key)?" docs/contracts/resources.md docs/contracts/cache_policy.md docs/architecture/03_data_model.md'
```

##### Structural Proof

Proves docs structure remains valid after owner changes:

```bash
dart run docs/tool/check_docs.dart
```

#### Closure Gate

Slice closes when active architecture and resource contracts have one unambiguous owner split and the selected cache key does not include global `resourceVisualRevision`.

### Slice 2. [x] Align Frame, Surface, And Resource-Resolution Flows

#### Slice Contract

Frame rendering and diagrams route image resolution through `SurfaceResourceSession`; attach/detach/resolver swap lifecycle creates, refreshes, and drops session cache without app image disposal.

#### Files

- Primary edit: `docs/contracts/frame_rendering.md` - route frame image resolution through `SurfaceResourceSession` and keep painters/direct frame code away from `CanvasResourceResolver`.
- Primary edit: `docs/diagrams/c4_component_runtime.mmd` - update the runtime component owner label so `ResourceKernel` no longer owns resolver boundary or image resolve cache.
- Primary edit: `docs/diagrams/seq_main_paint.mmd` - update main paint sequence to pass/use a surface resource session instead of raw resolver-to-`ResourceKernel` resolution.
- Primary edit: `docs/diagrams/seq_resource_resolution.mmd` - update sequence for session cache lookup, resolver generation, budget, missing suppression, and dirty invalidation.
- Primary edit: `docs/diagrams/dfd_resource_resolution.mmd` - update data flow so session owns resolver/cache state and runtime owns dirty-resource events.
- Primary edit: `docs/diagrams/state_resource_resolution.mmd` - update state lifecycle for surface session attach, resolver swap, frame resolve, dirty invalidation, and session disposal.
- Alignment edit: `docs/diagrams/dfd_main_paint_frame.mmd` - update main frame resource asset nodes and cache labels.
- Alignment edit: `docs/diagrams/dfd_cache_invalidation.mmd` - route descriptor/dirty invalidation to active session cache.
- Alignment edit: `docs/diagrams/seq_dispose_during_gesture.mmd` - make dispose drop the surface session cache without disposing app-owned images.
- Alignment edit: `docs/diagrams/seq_single_active_surface.mmd` - clarify session creation after successful attach and no session side effects before rejected attach.
- Verify-only check: `docs/tool/check_docs.dart` - repository documentation structure checker.

#### Change

Make the frame and diagram surfaces tell the same lifecycle story as the resource contract: `FrameEngine` asks a session for paint assets, the session owns bounded synchronous resolver work, and disposal drops the cache at the same boundary that owns the resolver.

#### Slice Verification

##### Semantic Proof

Proves active frame and resource-resolution flows name the selected session owner:

```bash
bash -lc 'set -e
for file in docs/contracts/frame_rendering.md docs/diagrams/c4_component_runtime.mmd docs/diagrams/seq_main_paint.mmd docs/diagrams/seq_resource_resolution.mmd docs/diagrams/dfd_resource_resolution.mmd docs/diagrams/state_resource_resolution.mmd docs/diagrams/dfd_main_paint_frame.mmd docs/diagrams/dfd_cache_invalidation.mmd docs/diagrams/seq_dispose_during_gesture.mmd docs/diagrams/seq_single_active_surface.mmd; do
  rg -q "SurfaceResourceSession" "$file"
done
rg -q "resolverGeneration" docs/diagrams/seq_resource_resolution.mmd
rg -q "resolverGeneration" docs/diagrams/dfd_resource_resolution.mmd
rg -q "drop.*session" docs/diagrams/seq_dispose_during_gesture.mmd
rg -q "app-owned.*ui.Image" docs/diagrams/seq_dispose_during_gesture.mmd
rg -q "successful attach.*SurfaceResourceSession|SurfaceResourceSession.*successful attach|creates.*SurfaceResourceSession" docs/diagrams/seq_single_active_surface.mmd
rg -q "rejected.*SurfaceResourceSession|SurfaceResourceSession.*rejected|no session.*side effects|before.*SurfaceResourceSession" docs/diagrams/seq_single_active_surface.mmd'
```

Proves direct raw resolver routing through `FrameEngine` / `ResourceKernel` is no longer active target flow:

```bash
bash -lc 'set -e
! rg -n "Frame->>Resources: resolve paint asset\\(descriptor snapshot, resourceRevision, resolver\\)|Frame->>Resources: resolve paint image\\(descriptor snapshot, resourceRevision, resolver\\)|ResourceKernel.*resolver boundary|ResourceKernel.*resolver calls|ResourceKernel.*image resolve cache|ResourceKernel.*resolved-image cache|ResourceKernel-owned.*ImageResolveCache|ImageResolveCache.*ResourceKernel-owned|it owns resolver calls, resolved-image cache entries" docs/contracts/frame_rendering.md docs/diagrams/c4_component_runtime.mmd docs/diagrams/seq_main_paint.mmd docs/diagrams/seq_resource_resolution.mmd docs/diagrams/dfd_resource_resolution.mmd docs/diagrams/state_resource_resolution.mmd docs/diagrams/dfd_main_paint_frame.mmd docs/diagrams/dfd_cache_invalidation.mmd'
bash -lc 'set -e
! rg -U -n "subgraph Resources[\\s\\S]{0,80}ResourceKernel[\\s\\S]{0,600}ImageResolveCache eviction|ResourceKernel[\\s\\S]{0,240}ImageResolveCache eviction" docs/diagrams/dfd_cache_invalidation.mmd'
```

##### Structural Proof

Proves docs structure remains valid after diagram and frame-flow updates:

```bash
dart run docs/tool/check_docs.dart
```

#### Closure Gate

Slice closes when resource resolution flows use the surface session consistently and no active frame/diagram path passes the raw resolver to `ResourceKernel`.

### Slice 3. [x] Align Verification, Phase Guidance, And Indexes

#### Slice Contract

Verification docs, phase guidance, benchmarks, release gates, registry, generated indexes, redesign backlog, and audit checklist prove the surface-session design and retire stale `ResourceKernel` resolver-boundary, missing-result cache, and `HOLE-003` tracking terminology.

#### Files

- Primary edit: `docs/verification/guardrails.md` - replace `resources.resolver_boundary_owned_by_resource_kernel` with `resources.resolver_boundary_owned_by_surface_session` and align resolver budget / no-same-frame-missing wording.
- Primary edit: `docs/verification/tests.md` - add or rename planned tests for surface session lifecycle, resolver swap isolation, and missing-result same-frame suppression.
- Primary edit: `docs/implementation/p7_resources_and_images.md` - make P7 own the resource-module session primitive, cache policy, budget, missing suppression, and reentrancy guard.
- Primary edit: `docs/implementation/p9_frame_rendering_and_caches.md` - make P9 consume the session boundary without owning resolver calls.
- Primary edit: `docs/implementation/p13_flutter_surface.md` - make P13 own CanvasSurface attach/detach/resolver-swap session lifecycle wiring.
- Alignment edit: `docs/verification/benchmarks.md` - align resource resolve benchmarks with per-surface session cache/budget probes.
- Alignment edit: `docs/verification/release_gates.md` - update guardrail and test ids.
- Alignment edit: `docs/indexes/by_guardrail.md` - update guardrail mapping.
- Alignment edit: `docs/indexes/by_test_area.md` - update test-to-guardrail mapping.
- Alignment edit: `docs/indexes/by_subsystem.md` - update subsystem navigation if resource ownership wording appears there.
- Alignment edit: `docs/_registry/sections.yaml` - update section guardrail/test references.
- Primary edit: `redesign.md` - delete the promoted `## 6. Resource resolver cache переносим в surface resource session` section after active contracts own the decision.
- Primary edit: `audit.md` - remove `HOLE-003` from the execution order, blocker list, and detailed checklist after proof mappings close the issue.
- Verify-only check: `docs/tool/generate_context_capsules.dart` - context capsule synchronization checker.
- Verify-only check: `docs/tool/check_docs.dart` - repository documentation structure checker.

#### Change

Update the proof system so future implementation has mechanical targets for the new owner: session cache lifecycle, resolver swap isolation, no direct resolver calls outside the session, same-frame missing suppression, and budget behavior.

#### Slice Verification

##### Semantic Proof

Proves the successor guardrail and planned tests are present:

```bash
bash -lc 'set -e
for file in docs/verification/guardrails.md docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/verification/release_gates.md docs/_registry/sections.yaml docs/implementation/p7_resources_and_images.md docs/implementation/p9_frame_rendering_and_caches.md; do
  rg -q "resources.resolver_boundary_owned_by_surface_session" "$file"
done
for file in docs/verification/tests.md docs/indexes/by_test_area.md docs/_registry/sections.yaml docs/implementation/p7_resources_and_images.md; do
  rg -q "test.resources.missing_result_suppressed_per_frame" "$file"
done
rg -q "test.resources.surface_session_cache_lifecycle" docs/verification/tests.md
rg -q "test.resources.resolver_swap_starts_fresh_cache" docs/verification/tests.md
rg -q "test.flutter_bridge.surface_resource_session_lifecycle" docs/verification/tests.md docs/implementation/p13_flutter_surface.md'
```

Proves resource benchmark rows are aligned with the surface-session cache and budget owner:

```bash
bash -lc 'set -e
rg -q "SurfaceResourceSession|surface session|per-surface session" docs/verification/benchmarks.md
rg -q "resources.resolve_sync.*(SurfaceResourceSession|surface session|session cache|session budget)" docs/verification/benchmarks.md
rg -q "resources.resolve_sync_cold_budget.*(SurfaceResourceSession|surface session|session cache|session budget)" docs/verification/benchmarks.md'
```

Proves retired guardrail and missing-result test ids are gone from active references:

```bash
bash -lc 'set -e
! rg -n "resources.resolver_boundary_owned_by_resource_kernel|test.resources.missing_result_cached_per_revision|missing_result_cached_per_revision_test\\.dart" docs/contracts/resources.md docs/contracts/frame_rendering.md docs/verification/guardrails.md docs/verification/tests.md docs/verification/release_gates.md docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/indexes/by_subsystem.md docs/_registry/sections.yaml docs/implementation/p7_resources_and_images.md docs/implementation/p9_frame_rendering_and_caches.md docs/implementation/p13_flutter_surface.md'
```

Proves stale phase guidance no longer routes resource resolving through `ResourceKernel` or runtime cache ownership:

```bash
bash -lc 'set -e
! rg -n "resolver access.*ResourceKernel|resolve images only through ResourceKernel|ResourceKernel-facing tests" docs/implementation/p7_resources_and_images.md docs/implementation/p9_frame_rendering_and_caches.md docs/implementation/p13_flutter_surface.md'
bash -lc 'set -e
! rg -U -n "resolved images belong[\\s\\S]{0,120}runtime cache" docs/implementation/p7_resources_and_images.md docs/implementation/p9_frame_rendering_and_caches.md docs/implementation/p13_flutter_surface.md'
```

Proves the promoted redesign section and closed audit hole are gone:

```bash
bash -lc 'set -e
! rg -n "Resource resolver cache переносим в surface resource session|HOLE-003|Resource cache не учитывает смену resolver/surface|resolved image cache не переживает смену resolver/surface" redesign.md audit.md'
```

##### Structural Proof

Proves context capsules and docs navigation remain synchronized:

```bash
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```

#### Closure Gate

Slice closes when verification docs and indexes use the new owner/test ids consistently, stale `ResourceKernel` resolver-boundary terminology remains only in historical plan or research artifacts outside active docs, and `redesign.md` / `audit.md` no longer track the closed cache lifecycle gap.

## 10. Final Verification

Final verification for this documentation-only step:

```bash
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```

Targeted semantic verification:

```bash
bash -lc 'set -e
for file in docs/contracts/resources.md docs/contracts/public_api_v1.md docs/contracts/frame_rendering.md docs/diagrams/c4_component_runtime.mmd docs/diagrams/seq_main_paint.mmd docs/diagrams/seq_resource_resolution.mmd docs/diagrams/dfd_resource_resolution.mmd docs/diagrams/state_resource_resolution.mmd docs/diagrams/dfd_cache_invalidation.mmd docs/diagrams/seq_single_active_surface.mmd docs/verification/benchmarks.md docs/implementation/p7_resources_and_images.md docs/implementation/p13_flutter_surface.md; do
  rg -q "SurfaceResourceSession" "$file"
done'
bash -lc 'set -e
rg -q "resolverGeneration" docs/contracts/resources.md
rg -q "resolverGeneration" docs/diagrams/seq_resource_resolution.mmd
rg -q "resolverGeneration" docs/diagrams/dfd_resource_resolution.mmd
! rg -n "ImageResolveCache.*resourceVisualRevision|resourceVisualRevision.*ImageResolveCache.*key|resourceVisualRevision.*cache key" docs/contracts/resources.md docs/contracts/cache_policy.md docs/architecture/03_data_model.md'
bash -lc 'set -e
! rg -U -n "ImageResolveCache(Key)?[\\s\\S]{0,400}resourceVisualRevision|resourceVisualRevision[\\s\\S]{0,400}ImageResolveCache(Key)?" docs/contracts/resources.md docs/contracts/cache_policy.md docs/architecture/03_data_model.md docs/diagrams/seq_resource_resolution.mmd docs/diagrams/dfd_resource_resolution.mmd docs/diagrams/state_resource_resolution.mmd'
bash -lc 'set -e
! rg -n "ResourceKernel.*resolver boundary|ResourceKernel.*resolver calls|ResourceKernel.*image resolve cache|ResourceKernel.*resolved-image cache|ResourceKernel-owned.*ImageResolveCache|ImageResolveCache.*ResourceKernel-owned|it owns resolver calls, resolved-image cache entries|ResourceKernel owns the budget-exceeded retry scheduler|resolver access.*ResourceKernel|resolve images only through ResourceKernel|ResourceKernel-facing tests" docs/architecture/01_runtime_ownership.md docs/contracts/resources.md docs/contracts/frame_rendering.md docs/diagrams/c4_component_runtime.mmd docs/diagrams/seq_main_paint.mmd docs/diagrams/seq_resource_resolution.mmd docs/diagrams/dfd_resource_resolution.mmd docs/diagrams/state_resource_resolution.mmd docs/diagrams/dfd_cache_invalidation.mmd docs/implementation/p7_resources_and_images.md docs/implementation/p9_frame_rendering_and_caches.md docs/implementation/p13_flutter_surface.md'
bash -lc 'set -e
! rg -U -n "subgraph Resources[\\s\\S]{0,80}ResourceKernel[\\s\\S]{0,600}ImageResolveCache eviction|ResourceKernel[\\s\\S]{0,240}ImageResolveCache eviction" docs/diagrams/dfd_cache_invalidation.mmd'
bash -lc 'set -e
! rg -U -n "resolved images belong[\\s\\S]{0,120}runtime cache" docs/implementation/p7_resources_and_images.md docs/implementation/p9_frame_rendering_and_caches.md docs/implementation/p13_flutter_surface.md'
bash -lc 'set -e
rg -q "successful attach.*SurfaceResourceSession|SurfaceResourceSession.*successful attach|creates.*SurfaceResourceSession" docs/diagrams/seq_single_active_surface.mmd
rg -q "rejected.*SurfaceResourceSession|SurfaceResourceSession.*rejected|no session.*side effects|before.*SurfaceResourceSession" docs/diagrams/seq_single_active_surface.mmd
rg -q "resources.resolve_sync.*(SurfaceResourceSession|surface session|session cache|session budget)" docs/verification/benchmarks.md
rg -q "resources.resolve_sync_cold_budget.*(SurfaceResourceSession|surface session|session cache|session budget)" docs/verification/benchmarks.md'
bash -lc 'set -e
for file in docs/verification/guardrails.md docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/verification/release_gates.md docs/_registry/sections.yaml docs/implementation/p7_resources_and_images.md docs/implementation/p9_frame_rendering_and_caches.md; do
  rg -q "resources.resolver_boundary_owned_by_surface_session" "$file"
done
! rg -n "resources.resolver_boundary_owned_by_resource_kernel|test.resources.missing_result_cached_per_revision|missing_result_cached_per_revision_test\\.dart" docs/contracts/resources.md docs/contracts/frame_rendering.md docs/verification/guardrails.md docs/verification/tests.md docs/verification/release_gates.md docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/indexes/by_subsystem.md docs/_registry/sections.yaml docs/implementation/p7_resources_and_images.md docs/implementation/p9_frame_rendering_and_caches.md docs/implementation/p13_flutter_surface.md'
bash -lc 'set -e
! rg -n "Resource resolver cache переносим в surface resource session|HOLE-003|Resource cache не учитывает смену resolver/surface|resolved image cache не переживает смену resolver/surface" redesign.md audit.md'
```

Do not run `dart analyze`, `dcm analyze .`, or `dcm calculate-metrics .` for this step unless production Dart files are added contrary to this contract.

## 11. Acceptance Criteria

- `PLAN.md` links this step and the step remains unchecked until executed.
- Active resource/surface/frame docs make `SurfaceResourceSession` the resolved image cache and resolver-call lifecycle owner.
- Active docs preserve committed descriptor, `resourceRevision`, and `resourceVisualRevision` ownership.
- Active docs define `ImageResolveCache` identity as `resolverGeneration + resourceId + resourceRevision`.
- Active docs reject global `resourceVisualRevision` as an image cache key.
- Active diagrams show session creation, session use, dirty invalidation, and session disposal.
- Active verification references use `resources.resolver_boundary_owned_by_surface_session`.
- Active verification references use `test.resources.missing_result_suppressed_per_frame`.
- `redesign.md` no longer contains the promoted resource resolver cache section.
- `audit.md` no longer contains `HOLE-003`.
- Documentation structural checks and targeted semantic checks pass.
