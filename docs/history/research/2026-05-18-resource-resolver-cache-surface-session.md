---
date: 2026-05-18
researcher: Codex
commit: 2e43f59
branch: new-architecture
research_question: "Current codebase facts for moving the resolved image cache from runtime ResourceKernel ownership to a surface resource session with resolver generation."
---

# Research: Resource Resolver Cache Surface Session

## Summary

The current root new-engine documentation places resource descriptors in committed document state and resolved image caching in runtime resource ownership. `DocumentStoreKernel` owns resource descriptors, while `ResourceKernel` owns the resolver boundary, image resolve cache, dirty resource ids, and resolver-safe placeholder behavior.

`CanvasSurface` is already documented as the Flutter paint host that accepts an optional app-owned synchronous `CanvasResourceResolver` for that surface. During main paint, the surface passes the resolver into the frame request, `FrameEngine` reads committed descriptor snapshots and `resourceRevision`, and `ResourceKernel` performs cache lookup, resolver budget enforcement, resolver invocation, and placeholder selection. Painters receive immutable records and resolved assets/placeholders; they do not call the application resolver directly.

The proposed concepts `SurfaceResourceSession` and `resolverGeneration` are not present in the current root `docs/` terminology found during scoped search. The current cache key documented for `ImageResolveCache` is `resourceId/resourceRevision`; several diagrams also show the same `resourceId + resourceRevision` key. `resourceVisualRevision` is captured in frame facts and advanced by dirty resource operations, but it is not currently listed as an `ImageResolveCache` key component.

## Detailed Findings

### 1. Current Resource Ownership

- **Location**: primary `docs/contracts/resources.md:52`; additional `docs/architecture/01_runtime_ownership.md:54`, `docs/architecture/01_runtime_ownership.md:59`
- **Description**: The resource lifecycle contract states that `DocumentStoreKernel` owns resource descriptors as committed document state and `ResourceKernel` owns runtime caches (`docs/contracts/resources.md:52`). The runtime ownership table also places committed document state and resource descriptors under `DocumentStoreKernel`, while placing resolver boundary, image resolve cache, and dirty resource ids under `ResourceKernel` (`docs/architecture/01_runtime_ownership.md:54`, `docs/architecture/01_runtime_ownership.md:59`).
- **Dependencies**: Paint/resource resolution receives immutable descriptor snapshots and `resourceRevision` from allowed committed-state readers such as `FrameEngine` or `RuntimeRoot` (`docs/contracts/resources.md:63`, `docs/contracts/resources.md:64`). `ResourceKernel` must not import, read, or mutate `DocumentStoreKernel` (`docs/contracts/resources.md:65`, `docs/contracts/resources.md:66`).
- **Data flow**: Committed document state stores resource descriptors only, while runtime cache stores resolved app-provided image references and dirty resource ids (`docs/contracts/resources.md:54`, `docs/contracts/resources.md:56`, `docs/contracts/resources.md:58`, `docs/contracts/resources.md:60`).

### 2. Current Image Resolve Cache Policy

- **Location**: primary `docs/contracts/resources.md:72`; additional `docs/contracts/resources.md:78`, `docs/contracts/resources.md:80`
- **Description**: `ImageResolveCache` is described as `ResourceKernel`-owned core resource policy, not a frame/spatial cache prerequisite (`docs/contracts/resources.md:72`, `docs/contracts/resources.md:74`, `docs/contracts/resources.md:75`). The cache policy table lists owner `Resource`, key `resourceId/resourceRevision`, invalidation by resource dirty or descriptor change, capacity 1024 entries, and target/all invalidation followed by LRU eviction (`docs/contracts/resources.md:78`, `docs/contracts/resources.md:80`).
- **Dependencies**: The cache admits synchronous app resolver usage only under `kMaxSyncResourceResolverCallsPerFrame = 128` (`docs/contracts/resources.md:80`). The data-flow diagram shows descriptor changes evict descriptor-dependent `ImageResolveCache` entries (`docs/diagrams/dfd_resource_resolution.mmd:68`, `docs/diagrams/dfd_resource_resolution.mmd:72`).
- **Data flow**: During resource resolution, the cache is looked up by `resourceId` and `resourceRevision`; cache hits return app-owned images or cached missing/null results, while cache misses proceed to the resolver budget gate (`docs/diagrams/seq_resource_resolution.mmd:33`, `docs/diagrams/seq_resource_resolution.mmd:35`, `docs/diagrams/seq_resource_resolution.mmd:36`, `docs/diagrams/dfd_resource_resolution.mmd:83`, `docs/diagrams/dfd_resource_resolution.mmd:85`).

### 3. Resource Revisions And Dirty Invalidation

- **Location**: primary `docs/architecture/03_data_model.md:116`; additional `docs/architecture/03_data_model.md:122`, `docs/architecture/03_data_model.md:123`
- **Description**: The runtime data model defines `resourceRevision` as resource descriptor changes and `resourceVisualRevision` as `markResourceDirty` / resolver visual invalidation (`docs/architecture/03_data_model.md:116`, `docs/architecture/03_data_model.md:122`, `docs/architecture/03_data_model.md:123`). Public runtime state exposes `resourceVisual`, while internal cache/projection revisions remain private (`docs/architecture/03_data_model.md:132`, `docs/architecture/03_data_model.md:135`, `docs/architecture/03_data_model.md:136`).
- **Dependencies**: External visual resource repaint is exposed through `runtime.resources.markResourceDirty(resourceId)` and `runtime.resources.markAllResourcesDirty()` (`docs/contracts/resources.md:108`, `docs/contracts/resources.md:112`, `docs/contracts/resources.md:114`). `resourceVisualRevision` maps to public `state.revisions.resourceVisual` and the public resource port delegates cache invalidation to `ResourceKernel` (`docs/contracts/resources.md:132`, `docs/contracts/resources.md:133`, `docs/contracts/resources.md:134`, `docs/contracts/resources.md:135`).
- **Data flow**: Dirty operations do not change document revision, increment `state.revisions.resourceVisual`, invalidate resolved cache entries for the target resource, and publish main repaint intent (`docs/contracts/resources.md:119`, `docs/contracts/resources.md:120`, `docs/contracts/resources.md:121`, `docs/contracts/resources.md:122`, `docs/contracts/resources.md:123`). The repaint intent is runtime-owned and does not require an attached `CanvasSurface`; an attached surface observes it if present (`docs/contracts/resources.md:136`, `docs/contracts/resources.md:137`).

### 4. Frame-Time Resource Resolution Flow

- **Location**: primary `docs/diagrams/seq_main_paint.mmd:17`; additional `docs/diagrams/seq_main_paint.mmd:68`, `docs/diagrams/seq_main_paint.mmd:72`
- **Description**: The main paint sequence begins with `CanvasSurface` sending a paint request to `FrameEngine` with `viewportRect`, `devicePixelRatio`, `gridStyle`, and `resolver` (`docs/diagrams/seq_main_paint.mmd:17`). When records include image resource ids, `FrameEngine` reads committed descriptor snapshots and passes descriptor snapshot, `resourceRevision`, and resolver to `ResourceKernel` (`docs/diagrams/seq_main_paint.mmd:68`, `docs/diagrams/seq_main_paint.mmd:70`, `docs/diagrams/seq_main_paint.mmd:71`, `docs/diagrams/seq_main_paint.mmd:72`).
- **Dependencies**: The frame rendering contract states that main paint captures main frame facts once and painters do not live-read runtime or materialize `CanvasDocument` (`docs/contracts/frame_rendering.md:88`, `docs/contracts/frame_rendering.md:91`, `docs/contracts/frame_rendering.md:93`, `docs/contracts/frame_rendering.md:94`). It also states that the image resolver is the only external read boundary in paint, cannot mutate runtime, and v1 resolver calls are synchronous and bounded by the per-frame resolver budget (`docs/contracts/frame_rendering.md:96`, `docs/contracts/frame_rendering.md:97`).
- **Data flow**: `ResourceKernel` returns app-owned image paint assets, bounded missing image placeholders, or budget-exceeded placeholders; actual resolver calls occur only in the cache-miss-and-budget-available branch (`docs/diagrams/seq_main_paint.mmd:74`, `docs/diagrams/seq_main_paint.mmd:75`, `docs/diagrams/seq_main_paint.mmd:76`, `docs/diagrams/seq_main_paint.mmd:78`, `docs/diagrams/seq_main_paint.mmd:80`, `docs/diagrams/seq_main_paint.mmd:81`). The painter consumes immutable records, resolved assets, and bounded render caches, and a diagram note says `ResourceKernel` owns the app resolver boundary while the painter never calls the application resolver directly (`docs/diagrams/seq_main_paint.mmd:88`, `docs/diagrams/seq_main_paint.mmd:93`, `docs/diagrams/seq_main_paint.mmd:95`).

### 5. Resolver Budget And Missing Result Suppression

- **Location**: primary `docs/contracts/resources.md:179`; additional `docs/contracts/resources.md:182`, `docs/contracts/resources.md:184`
- **Description**: The resolver frame budget is `kMaxSyncResourceResolverCallsPerFrame = 128`, the counter resets for each main paint frame, and cache hits plus missing descriptors do not consume the resolver-call budget (`docs/contracts/resources.md:179`, `docs/contracts/resources.md:182`, `docs/contracts/resources.md:183`, `docs/contracts/resources.md:184`).
- **Dependencies**: After budget exhaustion, `ResourceKernel` returns a bounded placeholder and increments a diagnostic/probe counter (`docs/contracts/resources.md:185`, `docs/contracts/resources.md:186`). `ResourceKernel` owns the budget-exceeded retry scheduler, may schedule at most one pending throttled follow-up repaint, and clears the pending flag on the next main frame resource pass (`docs/contracts/resources.md:187`, `docs/contracts/resources.md:188`, `docs/contracts/resources.md:189`).
- **Data flow**: Budget-exceeded results are not cached as null, missing, or resolved images (`docs/contracts/resources.md:191`). If the resolver returns null, `ResourceKernel` remembers missing/null by `resourceId + resourceRevision` and does not retry in the same frame (`docs/diagrams/seq_resource_resolution.mmd:54`, `docs/diagrams/seq_resource_resolution.mmd:55`, `docs/diagrams/seq_resource_resolution.mmd:56`).

### 6. CanvasSurface Lifecycle And Resolver Injection

- **Location**: primary `docs/contracts/public_api_v1.md:439`; additional `docs/contracts/public_api_v1.md:442`, `docs/contracts/public_api_v1.md:453`
- **Description**: `CanvasSurface` is declared as a `StatefulWidget` with required `CanvasRuntime runtime` and optional `CanvasResourceResolver? resourceResolver` (`docs/contracts/public_api_v1.md:439`, `docs/contracts/public_api_v1.md:442`, `docs/contracts/public_api_v1.md:443`, `docs/contracts/public_api_v1.md:445`, `docs/contracts/public_api_v1.md:452`, `docs/contracts/public_api_v1.md:453`). The surface contract states that `CanvasSurface resourceResolver` is the app-owned synchronous image resolver for that surface (`docs/contracts/public_api_v1.md:487`).
- **Dependencies**: v1 supports one active `CanvasSurface` per `CanvasRuntime`; a surface is active from successful runtime attachment until detach or dispose completes; attaching a second active surface throws `StateError('CanvasRuntime already has an active CanvasSurface.')` before pointer routing, paint, repaint-listener, or `resourceResolver` attachment side effects (`docs/contracts/public_api_v1.md:463`, `docs/contracts/public_api_v1.md:466`, `docs/contracts/public_api_v1.md:468`, `docs/contracts/public_api_v1.md:469`, `docs/contracts/public_api_v1.md:470`, `docs/contracts/public_api_v1.md:471`).
- **Data flow**: The single-active-surface sequence shows `CanvasSurface A` attaching to `CanvasRuntime A`, `CanvasSurface B` being rejected on the same runtime, and another surface attaching successfully to a different runtime (`docs/diagrams/seq_single_active_surface.mmd:10`, `docs/diagrams/seq_single_active_surface.mmd:11`, `docs/diagrams/seq_single_active_surface.mmd:16`, `docs/diagrams/seq_single_active_surface.mmd:20`, `docs/diagrams/seq_single_active_surface.mmd:21`, `docs/diagrams/seq_single_active_surface.mmd:22`). After `SurfaceA` unmounts and detaches, `SurfaceC` can attach to the same runtime (`docs/diagrams/seq_single_active_surface.mmd:25`, `docs/diagrams/seq_single_active_surface.mmd:26`, `docs/diagrams/seq_single_active_surface.mmd:28`, `docs/diagrams/seq_single_active_surface.mmd:29`, `docs/diagrams/seq_single_active_surface.mmd:30`).

### 7. Disposal And App-Owned Image Handling

- **Location**: primary `docs/contracts/public_api_v1.md:339`; additional `docs/contracts/public_api_v1.md:355`, `docs/contracts/public_api_v1.md:358`
- **Description**: The runtime dispose contract says `CanvasRuntime` does not own application listeners; `CanvasSurface` removes only listeners it registered during detach, dispose, or runtime swap, and applications remove listeners they registered directly (`docs/contracts/public_api_v1.md:339`, `docs/contracts/public_api_v1.md:355`, `docs/contracts/public_api_v1.md:356`, `docs/contracts/public_api_v1.md:357`). Mandatory v1 resource caches are cleared without disposing app-provided `ui.Image` objects (`docs/contracts/public_api_v1.md:358`).
- **Dependencies**: `CanvasResourceResolver.resolveImage` returns `ui.Image?`, resolver calls are synchronous in v1, all returned `ui.Image` objects are app-owned, and the engine never disposes app-provided images (`docs/contracts/public_api_v1.md:1453`, `docs/contracts/public_api_v1.md:1454`, `docs/contracts/public_api_v1.md:1466`, `docs/contracts/public_api_v1.md:1467`, `docs/contracts/public_api_v1.md:1468`). The surface contract separately states that `CanvasSurface` does not own or dispose app-provided `ui.Image` instances (`docs/contracts/public_api_v1.md:488`).
- **Data flow**: During dispose, the sequence diagram clears mandatory v1 runtime resource caches and drops resolved-image cache entries; its note says app-owned `ui.Image` instances and the app resolver are not disposed by the engine (`docs/diagrams/seq_dispose_during_gesture.mmd:68`, `docs/diagrams/seq_dispose_during_gesture.mmd:69`, `docs/diagrams/seq_dispose_during_gesture.mmd:70`).

### 8. Verification And Current Root Package Structure

- **Location**: primary `docs/verification/tests.md:95`; additional `docs/verification/tests.md:111`, `docs/verification/tests.md:118`
- **Description**: Required resource tests include sync image resolver, app-owned image not disposed, resource dirty, mark all resources dirty, painter never calls resolver directly, missing result cached per revision, resolver frame budget, and resolver reentrancy rejected (`docs/verification/tests.md:95`, `docs/verification/tests.md:111`, `docs/verification/tests.md:112`, `docs/verification/tests.md:113`, `docs/verification/tests.md:114`, `docs/verification/tests.md:115`, `docs/verification/tests.md:116`, `docs/verification/tests.md:117`, `docs/verification/tests.md:118`).
- **Dependencies**: Mandatory guardrails include `resources.resolver_boundary_owned_by_resource_kernel`, `resources.resolver_frame_budget`, and `resources.no_same_frame_missing_retry` (`docs/verification/guardrails.md:185`, `docs/verification/guardrails.md:186`, `docs/verification/guardrails.md:187`). P7 lists resource resolver bridge, missing/null per-frame cache, frame budget, and reentrancy guard in its build scope (`docs/implementation/p7_resources_and_images.md:20`, `docs/implementation/p7_resources_and_images.md:21`, `docs/implementation/p7_resources_and_images.md:23`, `docs/implementation/p7_resources_and_images.md:24`).
- **Data flow**: P13 lists `CanvasSurface`, the single active surface gate, main/overlay painters, synchronous app-owned resource resolver bridge, and widget paint in its build scope (`docs/implementation/p13_flutter_surface.md:11`, `docs/implementation/p13_flutter_surface.md:12`, `docs/implementation/p13_flutter_surface.md:14`, `docs/implementation/p13_flutter_surface.md:15`, `docs/implementation/p13_flutter_surface.md:16`, `docs/implementation/p13_flutter_surface.md:22`). The documented target package layout includes root `lib/` and `test/` directories (`docs/architecture/02_package_boundaries.md:33`, `docs/architecture/02_package_boundaries.md:36`, `docs/architecture/02_package_boundaries.md:37`, `docs/architecture/02_package_boundaries.md:123`), while command-observed current root structure during this research did not include root `lib/` or `test/` directories.

## Code References

- `docs/contracts/resources.md:52` - current split: committed descriptors in `DocumentStoreKernel`, runtime caches in `ResourceKernel`.
- `docs/contracts/resources.md:63` - resource resolution receives immutable descriptor snapshots.
- `docs/contracts/resources.md:74` - `ImageResolveCache` is currently `ResourceKernel`-owned policy.
- `docs/contracts/resources.md:80` - current `ImageResolveCache` key is `resourceId/resourceRevision`.
- `docs/contracts/resources.md:120` - resource dirty does not change document revision.
- `docs/contracts/resources.md:121` - resource dirty increments public resource visual revision.
- `docs/contracts/resources.md:135` - public resource port delegates cache invalidation to `ResourceKernel`.
- `docs/contracts/resources.md:137` - an attached `CanvasSurface` observes runtime-owned repaint intent if present.
- `docs/contracts/resources.md:182` - resolver budget constant is 128 per frame.
- `docs/contracts/resources.md:187` - `ResourceKernel` owns the budget-exceeded retry scheduler.
- `docs/architecture/03_data_model.md:122` - `resourceRevision` means descriptor changes.
- `docs/architecture/03_data_model.md:123` - `resourceVisualRevision` means dirty/visual invalidation.
- `docs/contracts/frame_rendering.md:96` - image resolver is the only external read boundary in paint and cannot mutate runtime.
- `docs/diagrams/seq_main_paint.mmd:72` - `FrameEngine` asks `ResourceKernel` to resolve paint asset.
- `docs/diagrams/seq_main_paint.mmd:95` - painter never calls the application resolver directly.
- `docs/contracts/public_api_v1.md:453` - `CanvasSurface` stores optional `CanvasResourceResolver`.
- `docs/contracts/public_api_v1.md:487` - `CanvasSurface.resourceResolver` is the app-owned synchronous image resolver for that surface.
- `docs/contracts/public_api_v1.md:488` - `CanvasSurface` does not own or dispose app-provided images.
- `docs/diagrams/seq_single_active_surface.mmd:16` - second active surface on same runtime is rejected.
- `docs/diagrams/seq_dispose_during_gesture.mmd:69` - dispose drops resolved-image cache entries.
- `docs/verification/guardrails.md:185` - guardrail keeps resolver access owned by `ResourceKernel`.
- `docs/verification/guardrails.md:186` - guardrail requires per-frame resolver budget and no cache write for budget placeholders.
- `docs/verification/guardrails.md:187` - guardrail requires missing/null suppression by resource id and revision.

## Observed Architecture Facts

- Pattern observed: resource descriptors and resolved image references are separate state classes in the current docs; descriptors are committed document facts, while resolved app-provided image references are runtime cache facts (`docs/contracts/resources.md:52`, `docs/contracts/resources.md:54`, `docs/contracts/resources.md:58`).
- Pattern observed: current image resolution routes `CanvasSurface` resolver input through `FrameEngine` into `ResourceKernel`; `ResourceKernel`, not painters, owns the resolver call boundary (`docs/diagrams/seq_main_paint.mmd:17`, `docs/diagrams/seq_main_paint.mmd:72`, `docs/diagrams/seq_main_paint.mmd:95`).
- Pattern observed: `resourceVisualRevision` is a frame-captured/runtime-visible visual invalidation fact, while the current `ImageResolveCache` key documented in resource contracts and diagrams is `resourceId/resourceRevision` (`docs/contracts/frame_rendering.md:68`, `docs/contracts/resources.md:80`, `docs/diagrams/dfd_resource_resolution.mmd:48`).
- Data flow observed: dirty resource operations invalidate target/all cache entries and schedule main repaint without descriptor mutation or document revision change (`docs/contracts/resources.md:119`, `docs/contracts/resources.md:121`, `docs/diagrams/dfd_resource_resolution.mmd:104`, `docs/diagrams/dfd_resource_resolution.mmd:105`, `docs/diagrams/seq_resource_resolution.mmd:75`, `docs/diagrams/seq_resource_resolution.mmd:78`).
- Lifecycle observed: `CanvasSurface` is active from successful runtime attachment until detach/dispose, and second active surface attachment is rejected before resolver attachment side effects (`docs/contracts/public_api_v1.md:466`, `docs/contracts/public_api_v1.md:468`, `docs/contracts/public_api_v1.md:470`, `docs/contracts/public_api_v1.md:471`).

## Open Questions

- `SurfaceResourceSession` is not defined in the current root documentation found during scoped search; current positive owner references point to `ResourceKernel`, `lib/src/resources/resource_kernel.dart`, and `lib/src/resources/resource_cache.dart` as the planned resource owner/files (`docs/architecture/01_runtime_ownership.md:59`, `docs/architecture/02_package_boundaries.md:105`, `docs/architecture/02_package_boundaries.md:106`, `docs/architecture/02_package_boundaries.md:107`).
- `resolverGeneration` is not defined in the current root documentation found during scoped search; current positive cache-key references use `resourceId/resourceRevision` or `resourceId + resourceRevision` (`docs/contracts/resources.md:80`, `docs/diagrams/dfd_resource_resolution.mmd:48`, `docs/diagrams/state_resource_resolution.mmd:46`, `docs/diagrams/state_resource_resolution.mmd:47`).
- `resourceVisualRevision` is captured by main frame and advanced by dirty invalidation, but current `ImageResolveCache` key documentation does not list it as a key component (`docs/contracts/frame_rendering.md:68`, `docs/architecture/03_data_model.md:123`, `docs/contracts/resources.md:80`).
