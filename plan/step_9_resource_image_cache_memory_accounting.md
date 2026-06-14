# Change Contract

## Goal

Make resolved resource image retention byte-aware without changing public resource APIs, resolver lifecycle, cache identity, or app-owned image ownership. The active `SurfaceResourceSession` image cache must keep the existing 1024-entry LRU limit, add a 64 MiB decoded-byte limit per active session, skip retaining a single oversized resolved image while still returning it for the current resolve, and update resource/cache source-of-truth docs and diagrams in the same implementation change.

## Source Inputs

- Design: `.design/2026-06-14-resource-image-cache-memory-accounting.md`
- Research: `.research/2026-06-14-resource-image-cache-memory-accounting.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `docs/contracts/resources.md`; `docs/contracts/cache_policy.md`; `docs/contracts/public_api_v1.md`; `docs/verification/tests.md`; `docs/diagrams/dfd_resource_resolution.mmd`; `docs/diagrams/seq_resource_resolution.mmd`; `docs/diagrams/state_resource_resolution.mmd`; `lib/src/resources/resource_cache.dart`; `lib/src/resources/surface_resource_session.dart`; `test/resources/fixtures/surface_session_cache_lifecycle_fixture.dart`; `test/resources/fixtures/app_owned_image_not_disposed_fixture.dart`

## Classification

Profile: BEHAVIOR_CHANGE

Obligations: BUG_FIX.

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` `ImageResolveCache` remains the owner of resolved-image retention and byte accounting. | `Boundaries.Owner`; `Unit 1` | `lib/src/resources/resource_cache.dart` implementation and focused resource-cache tests. |
| `D2` Cache identity stays `resolverGeneration + resourceId + resourceRevision`; size is admission metadata, not part of the key. | `Boundaries.Source of Truth`; `Unit 1` | Cache hit/miss regression tests that keep the same key inputs and do not include size in lookup identity. |
| `D3` Use decoded `ui.Image` dimension estimate, `width * height * 4`, rather than descriptor `byteLength`. | `Boundaries.Source of Truth`; `Unit 1` | Tests with misleading descriptor byte lengths or direct cache images proving decoded dimensions drive eviction. |
| `D4` Enforce dual limits: existing 1024 entry cap plus `kMaxResolvedResourceImageBytesPerSession = 64 * 1024 * 1024`. | `Boundaries.In Scope`; `Unit 1`; `Unit 3` | Byte-cap, entry-cap, and docs ledger checks. |
| `D5` Oversized single images are not retained, but still return for the current resolve result. | `Boundaries.Compatibility`; `Unit 1`; `Unit 2` | Oversized no-retention test and session result proof that the first resolve remains `ResolvedResourceImage`. |
| `D6` Byte eviction never disposes app-owned images and only removes cache references. | `Boundaries.Compatibility`; `Unit 2` | No-dispose fixture covering byte eviction, invalidation, clear/drop, and disposal paths. |
| `D7` Source-of-truth docs, resource-resolution diagrams, and verification notes must change with implementation. | `Boundaries.Source of Truth`; `Unit 3` | Resource/cache docs, `docs/verification/tests.md`, resource-resolution diagrams, generated-docs check, docs check, and architecture graph checks. |
| Design verification strategy requires session resolver-call behavior where integration is involved. | `Boundaries.In Scope`; `Unit 2` | Contract-level proof seam: non-public `SurfaceResourceSession` optional `ImageResolveCache` constructor parameter used only by resource tests to inject a small-byte-budget cache, not a new runtime policy. |
| Research finding: `ImageResolveCache` currently evicts only by entry count. | `Boundaries.Owner`; `Unit 1` | Tests fail against entry-only eviction and pass only with byte accounting. |
| Research finding: current frame hot-cache guardrail does not scan `lib/src/resources/**`. | `Boundaries.Out of Scope`; `Unit 3` | Contract does not claim existing frame guardrail enforces this policy; proof stays in focused tests and source-of-truth docs. |

## Evidence

- `.design/2026-06-14-resource-image-cache-memory-accounting.md:13` / disposition: design is `READY_FOR_CONTRACT` -> contract may proceed from the design artifact.
- `.design/2026-06-14-resource-image-cache-memory-accounting.md:21` / classification: design selects BEHAVIOR_CHANGE with BUG_FIX -> contract must preserve the selected profile and obligation.
- `.design/2026-06-14-resource-image-cache-memory-accounting.md:153` / source-of-truth handoff: docs and resource-resolution diagrams must change with implementation -> implementation scope includes documentation and diagram updates.
- `.design/2026-06-14-resource-image-cache-memory-accounting.md:254` / source-of-truth handoff: future contract must update resource/cache docs, diagrams, verification notes, and generated docs if stale -> Unit 3 includes `docs/verification/tests.md` and docs tooling checks.
- `.design/2026-06-14-resource-image-cache-memory-accounting.md:281` / verification strategy: direct cache tests use small byte limits and session integration asserts resolver-call behavior -> Unit 2 fixes a concrete non-public session cache injection seam.
- `.research/2026-06-14-resource-image-cache-memory-accounting.md:13` / current behavior: research confirms the cache stores `ui.Image` values and evicts only by `_entries.length > _capacity` -> root fix belongs in the cache owner, not in one resolver call site.
- `lib/src/resources/resource_cache.dart:5` / existing capacity: default resolved-resource image capacity is 1024 entries -> keep entry count as one of the two limits.
- `lib/src/resources/resource_cache.dart:7` / cache key: key is resolver generation, resource id, and resource revision -> byte size is admission metadata, not identity.
- `lib/src/resources/resource_cache.dart:18` / retained object: cache stores `ui.Image` references directly -> retained-size estimate belongs beside cache entries.
- `lib/src/resources/resource_cache.dart:22` / read boundary: cache read takes only key inputs -> preserve key-only read and LRU promotion without byte metadata.
- `lib/src/resources/resource_cache.dart:42` / write boundary: cache write receives the resolved `ui.Image` -> estimate decoded bytes at the admission boundary.
- `lib/src/resources/resource_cache.dart:53` / replacement order: existing write removes the same key before inserting -> future byte accounting must subtract replaced entry size before oversize rejection or insertion.
- `lib/src/resources/resource_cache.dart:56` / defect: eviction compares only entry count with capacity -> add byte-limit eviction at the same owner-level loop.
- `lib/src/resources/resource_cache.dart:61` / target invalidation: target removal is owned by the cache -> byte accounting must subtract removed target entries here.
- `lib/src/resources/resource_cache.dart:65` / clear boundary: all invalidation clears the map -> `currentSizeBytes` must reset here.
- `lib/src/resources/surface_resource_session.dart:25` / session ownership: each session owns one `ImageResolveCache` -> byte budget is per active session.
- `lib/src/resources/surface_resource_session.dart:85` / lookup semantics: session reads by resolver generation, resource id, and revision -> cache lookup compatibility is unchanged.
- `lib/src/resources/surface_resource_session.dart:144` / temporal boundary: resolver callback runs before cache write -> byte estimation must occur after callback return and must not add a new callback/public publication window.
- `lib/src/resources/surface_resource_session.dart:155` / admission seam: resolver result enters the cache after a non-null resolver result -> oversized no-retention must not prevent returning the current resolved image.
- `docs/contracts/resources.md:67` / session lifecycle: each active `CanvasSurface` creates one `SurfaceResourceSession` under resources -> per-session byte cap matches current owner boundary.
- `docs/contracts/resources.md:92` / descriptor source: paint/resource resolution receives immutable descriptor snapshots and `resourceRevision` through `FrameFactsPort` -> descriptor bytes stay upstream metadata, not cache pressure truth.
- `docs/contracts/resources.md:95` / dependency boundary: resource module must not read or mutate runtime/store -> byte accounting stays in `lib/src/resources/**`.
- `docs/contracts/resources.md:117` / attach lifecycle: session is created only after successful attach -> byte counter starts with an empty active session.
- `docs/contracts/resources.md:120` / no-dispose lifecycle: detach, dispose, runtime swap, and runtime disposal clear cache without disposing app-owned images -> byte eviction may drop references only.
- `docs/contracts/resources.md:128` / cache owner: `ImageResolveCache` is `SurfaceResourceSession` policy owned by resources -> source-of-truth docs must keep this owner.
- `docs/contracts/resources.md:136` / stale policy row: resource contract currently states 1024 entries per active session -> update it to entry plus decoded-byte capacity and probe.
- `docs/contracts/cache_policy.md:45` / stale cache ledger: cache policy ledger repeats entry-only capacity and existing probe -> update ledger row with byte capacity and `currentSizeBytes`.
- `docs/contracts/cache_policy.md:53` / hot-path bound: hot cache misses must be bounded by candidate count, not total scene size -> eviction work must stay local to cache write and LRU removals, with no full-scene scan.
- `docs/contracts/cache_policy.md:54` / cache declaration: hot caches must declare capacity, eviction, key components, invalidation owner, and metric/probe -> docs must declare both entry and byte capacity/probe.
- `docs/contracts/public_api_v1.md:567` / public resolver contract: `resourceResolver` is app-owned and synchronous -> no async image inspection or engine loading is in scope.
- `docs/contracts/public_api_v1.md:578` / surface ownership: `CanvasSurface` does not own or dispose app images -> byte eviction cannot dispose returned `ui.Image`s.
- `docs/contracts/public_api_v1.md:1984` / resolver timing: resource resolver is synchronous in v1 -> byte estimation must be synchronous after resolver return.
- `docs/contracts/public_api_v1.md:1985` / app ownership: returned `ui.Image` objects are app-owned -> cache only retains or releases references.
- `docs/contracts/public_api_v1.md:1986` / no disposal: engine never disposes app-provided images -> tests must cover byte eviction without disposal.
- `docs/contracts/public_api_v1.md:1988` / retention boundary: resolved image references live only inside active `SurfaceResourceSession` -> per-session cache accounting is the complete engine-retention boundary.
- `docs/verification/tests.md:937` / verification registry: resource dirty tests already document active-session `ImageResolveCache` eviction proof -> update verification notes with byte-cap, oversize, counter-consistency, and no-dispose proof surfaces.
- `docs/diagrams/dfd_resource_resolution.mmd:95` / data-flow diagram: current flow says cache lookup and bounded update -> diagram must show byte-aware bounded update.
- `docs/diagrams/dfd_resource_resolution.mmd:103` / data-flow diagram: current flow stores resolved image by key -> diagram must add decoded-byte admission without changing key identity.
- `docs/diagrams/dfd_resource_resolution.mmd:118` / invalidation flow: target/all invalidation targets `ImageResolveCache` -> diagram/docs must preserve invalidation as byte-counter removal/reset path.
- `docs/diagrams/seq_resource_resolution.mmd:88` / sequence diagram: current sequence stores every returned image -> add oversize branch that returns without retaining.
- `docs/diagrams/state_resource_resolution.mmd:70` / state diagram: current note says admission is keyed strictly by generation/id/revision -> update note to distinguish identity from byte admission.
- `test/resources/fixtures/surface_session_cache_lifecycle_fixture.dart:111` / existing proof: LRU entry-count behavior is already tested -> preserve or extend this proof under dual limits.
- `test/resources/fixtures/app_owned_image_not_disposed_fixture.dart:24` / existing proof: no-dispose fixture covers entry eviction over capacity -> extend no-dispose proof to byte eviction or add a focused byte-eviction no-dispose fixture.
- `tool/guardrails/src/frame_cache_guardrail_checks.dart:229` / guardrail scope: hot-cache guardrail scans only `lib/src/frame` -> do not claim this resource cache policy is mechanically enforced by the existing frame guardrail.
- `tool/guardrails/src/guardrail_executor.dart:408` / guardrail proof map: cache capacity guardrail maps to frame cache tests -> focused resource tests and docs checks are required for this step.

## Boundaries

Owner: `ImageResolveCache` under `lib/src/resources/resource_cache.dart` owns decoded-byte estimation, byte counter state, byte-cap admission, entry-cap admission, LRU eviction, replacement accounting, target invalidation accounting, and clear/reset accounting. `SurfaceResourceSession` remains the owner of resolver lifecycle and per-session cache instance ownership. Resource/cache contract docs and resource-resolution diagrams own the durable source-of-truth wording.

In Scope:

- Add `kMaxResolvedResourceImageBytesPerSession = 64 * 1024 * 1024` next to the existing resolved-resource image entry cap.
- Add `maximumSizeBytes` constructor configurability for `ImageResolveCache` for focused tests while preserving the default per-session 64 MiB budget.
- Add a non-public optional `ImageResolveCache` constructor parameter to `SurfaceResourceSession` as the contract-level proof seam for session-level oversized/no-retention behavior; resource tests use it to inject a small-byte-budget cache, production construction keeps the default cache, and exported public API remains unchanged.
- Store each cache entry as app-owned `ui.Image` plus cache-local `estimatedBytes`.
- Compute `estimatedBytes` synchronously at cache admission as `image.width * image.height * 4`.
- Remove an existing same-key entry and subtract its bytes before deciding whether the replacement image is oversized.
- Skip retaining any single image whose estimate exceeds `maximumSizeBytes`, while allowing the current session resolve to return `ResolvedResourceImage`.
- Evict least-recently-used entries until both `length <= capacity` and `currentSizeBytes <= maximumSizeBytes`.
- Keep reads as key-only LRU promotion and preserve existing cache key semantics.
- Update `currentSizeBytes` on replacement, byte eviction, entry eviction, target invalidation, all invalidation, resolver replacement, document replacement reset, drop, and dispose.
- Add or update focused tests under `test/resources/**` for byte cap, oversized no-retention, decoded-dimension accounting instead of descriptor `byteLength`, entry-cap preservation, replacement/invalidation/clear counter consistency, read promotion, and no-dispose behavior.
- Update `docs/contracts/resources.md`, `docs/contracts/cache_policy.md`, `docs/verification/tests.md`, and resource-resolution diagrams so the authoritative policy and verification notes match implemented behavior.

Out of Scope:

- No public API change and no public app-provided cache weight contract.
- No change to resource descriptor shape, schema v1, `CanvasResource.byteLength`, resolver request shape, or descriptor `byteLength` validation.
- No engine image loading, decoding, asset-bundle IO, file IO, network IO, or async image inspection.
- No transfer of `ui.Image` ownership to the engine and no engine disposal of app-owned images.
- No runtime-wide or process-global resource image cache.
- No replacement with Flutter `ImageCache`.
- No new guardrail/analyzer pipeline for resource cache byte accounting in this step; use focused resource tests and source-of-truth docs as proof.
- No change to frame, painter, runtime, store, or surface public behavior except adopting the updated internal per-session cache policy.

Source of Truth: Cache identity remains `resolverGeneration + resourceId + resourceRevision` in `ImageResolveCache`. Decoded byte estimate is cache-local derived state from `ui.Image.width * ui.Image.height * 4`, not descriptor truth and not public API. Durable policy wording lives in `docs/contracts/resources.md` and `docs/contracts/cache_policy.md`; resource-resolution diagrams are dependent generated/source-of-truth visual references that must match those contracts.

Compatibility: Existing public resolver and resource descriptor APIs remain source-compatible. `CanvasResource.byteLength` continues to describe optional descriptor/source metadata and must not become the cache memory source of truth. Resolver callbacks remain synchronous, app-owned images are never disposed by the engine, and oversized images still resolve for the current paint request even when not cached.

Order Constraints:

1. Establish focused failing resource-cache tests for byte accounting and preserve existing entry LRU/no-dispose proof surfaces before or with the production cache change.
2. Implement cache-local entry records, byte estimation, byte counter updates, oversize rejection, and dual-limit LRU in `ImageResolveCache`.
3. Keep `SurfaceResourceSession` cache admission after synchronous resolver return and do not add a new callback, listener, public publication, or async boundary.
4. Update source-of-truth docs, verification notes, and diagrams after behavior is implemented so the docs describe the final policy, not an aspirational intermediate state.
5. Run code checks, focused resource tests, DCM metrics for changed production/test scopes, docs checks, and architecture graph checks because resource-resolution diagrams change.

Temporal Surface Closure: The only synchronous app callback in this path remains `CanvasResourceResolver.resolveImage`, invoked through `ResolverMutationGuard` in `SurfaceResourceSession._resolveThroughResolver`. Byte estimation and cache mutation occur only after the callback returns a non-null image. No public state is published by cache write, and reentrant/interleaved runtime mutation attempts from the resolver must keep the existing guard-owned rejection/no-runtime-effects behavior.

All-Or-Nothing Failure Boundary: The first irreversible in-memory mutation inside `ImageResolveCache.write` is same-key old-entry removal with byte subtraction. There is no new external or fallible work before that point beyond key construction and decoded-byte estimate calculation from the supplied `ui.Image`. Oversize rejection after same-key removal, insertion, LRU removals, and counter updates are cache-owned synchronous/failure-contained work with no external failure projection. Tests must prove stale byte totals cannot survive write replacement, oversize rejection, eviction, target invalidation, or clear.

## Execution Units

### [x] Unit 1: Byte-aware cache admission

Owner: `ImageResolveCache` in `lib/src/resources/resource_cache.dart`.

Boundary: The cache-local admission, lookup, eviction, replacement, target invalidation, and clear paths. This unit may add resource-cache-focused tests under `test/resources/**`; it must not change public resource APIs or descriptor schema.

Change: Add the 64 MiB per-session decoded-byte default, `maximumSizeBytes` constructor configurability, cache entry records containing `ui.Image` plus `estimatedBytes`, `currentSizeBytes`, decoded byte estimation from `ui.Image.width * ui.Image.height * 4`, oversize no-retention, and dual-limit LRU eviction. Reads must keep key-only LRU promotion. Replacement, target invalidation, and clear must update byte totals exactly.

Completion Check: Focused resource tests fail against the current entry-only cache and pass only when `ImageResolveCache` proves these direct outcomes: total retained `currentSizeBytes` never exceeds `maximumSizeBytes` for retained entries; a single oversized image is not retained and an immediate read for that key misses; entry-count LRU still evicts the least-recently-used entry after capacity is exceeded; read promotion changes LRU order without changing `currentSizeBytes`; replacing the same key subtracts the old size before admission; `invalidateResource` subtracts matching entries; `clear` resets `currentSizeBytes` to zero; and descriptor `byteLength` does not influence cache pressure. Run `dart test` for the changed `test/resources/**` tests, `dart analyze`, `dcm analyze .`, `dcm calculate-metrics lib/src/resources`, and `dcm calculate-metrics test/resources`.

Negative Proof And Fixture Quarantine: Byte-accounting tests must use test-only controlled-dimension `ui.Image` fixtures under `test/resources/fixtures/**`; fixture-only dimensions, ids, and byte-limit values must not be added to production code, public APIs, schemas, durable docs, or generated source-of-truth files.

Depends On: none.

### [x] Unit 2: Session lifecycle and app-owned image compatibility

Owner: `SurfaceResourceSession` in `lib/src/resources/surface_resource_session.dart` and resource lifecycle fixtures under `test/resources/**`.

Boundary: Resolver result admission into the session-owned cache and lifecycle paths that clear or invalidate cache entries. This unit must preserve the resolver callback order, resolver generation keying, null/budget placeholder behavior, and app-owned image lifecycle.

Change: Adopt the updated `ImageResolveCache` without moving resolver ownership or changing `SurfaceResourceSession.resolveImage` public/internal semantics. Add a non-public optional `ImageResolveCache? cache` constructor parameter to `SurfaceResourceSession`; production and existing call sites omit it and keep the default 64 MiB cache, while resource tests inject an `ImageResolveCache` with a small `maximumSizeBytes`. Extend or add resource tests proving byte eviction drops references without disposing app-owned images and that an oversized resolver result still returns `ResolvedResourceImage` for the current resolve while not becoming a later cache hit.

Completion Check: Resource session tests use the non-public injected small-byte-budget `ImageResolveCache` seam and prove direct behavior rather than resolver-call proxies alone: the first oversized resolve returns `ResolvedResourceImage`; the next resolve for the same key calls the resolver again because the oversized image was not retained; byte eviction, target invalidation, all invalidation, resolver replacement, reset, drop, and dispose leave `ui.Image.debugDisposed` false until the fixture explicitly disposes the image; resolver reentrancy rejection behavior and resolver-call budget placeholder behavior remain unchanged. Run the focused `test/resources/**` tests covering session cache lifecycle, no-dispose, resolver reentrancy, and resolver budget; when cache invalidation or session invalidation paths change, also run `dart test test/resources/resource_dirty_test.dart` and `dart test test/resources/mark_all_resources_dirty_test.dart`. Run `dart analyze`, `dcm analyze .`, `dcm calculate-metrics lib/src/resources`, and `dcm calculate-metrics test/resources`.

Negative Proof And Fixture Quarantine: Session integration tests that need oversized or byte-eviction behavior must reuse the test-only controlled-dimension image fixtures and the non-public injected cache seam; they must not add fixture-only cache settings to public `CanvasSurface`, public resource descriptors, schema contracts, or source-of-truth docs.

Depends On: Unit 1.

### [x] Unit 3: Resource cache source of truth

Owner: Resource/cache contracts, verification notes, and resource-resolution diagrams under `docs/contracts/**`, `docs/verification/tests.md`, and `docs/diagrams/**`.

Boundary: Durable documentation, verification notes, and diagrams that describe resolved resource image cache policy and proof surfaces. This unit must update source-of-truth surfaces only after the implementation behavior exists; it must not introduce docs-only claims unsupported by tests or code.

Change: Update `docs/contracts/resources.md` and `docs/contracts/cache_policy.md` so `ImageResolveCache` is documented as a per-active-session dual-limit LRU with 1024 entries, 64 MiB decoded-byte budget, `currentSizeBytes`/byte-capacity probe, decoded-dimension accounting, target/all invalidation byte updates, and oversized-image no-retention. Update `docs/verification/tests.md` to list byte-cap, oversized-image, counter-consistency, and no-dispose proof for the resource cache/session tests. Update `docs/diagrams/dfd_resource_resolution.mmd`, `docs/diagrams/seq_resource_resolution.mmd`, and `docs/diagrams/state_resource_resolution.mmd` to show byte-aware cache admission inside `SurfaceResourceSession`, the oversize branch that returns the current resolved image without retention, and the distinction between key identity and byte admission.

Completion Check: Documentation checks prove the durable source of truth matches behavior: `docs/verification/tests.md` names the new byte-cap, oversized-image, counter-consistency, and no-dispose proof surfaces; `dart run docs/tool/sync_generated_docs.dart --check` reports no stale generated docs after diagram/doc updates, `dart run docs/tool/check_docs.dart` passes, `dart run tool/architecture_graph/check.dart` passes, and `dart run tool/architecture_graph/generate_views.dart --check` passes. The docs must explicitly state that descriptor `byteLength` remains descriptor metadata and not decoded cache weight, and must not claim the existing frame cache guardrail enforces resource cache byte accounting.

Depends On: Unit 1 and Unit 2.
