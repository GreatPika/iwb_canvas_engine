# Change Contract

## Goal

Move ordinary large-canvas edit commits from full public-document projection, full `DraftDocument` materialization, and full committed-store reconstruction to a sparse edit/store seam that preserves the current public edit API and semantic behavior while proving at least 2x lower action latency and allocation on the three locked Pixel 6 100k edit hotspots.

## Source Inputs

- Design: `.design/2026-06-06-incremental-edit-store.md`
- Research: `.research/2026-06-06-pixel6-manual-baseline-hotspots.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: `docs/architecture/03_data_model.md`, `docs/contracts/edit_kernel.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/cache_policy.md`, `docs/_registry/benchmarks.yaml`, `docs/diagrams/c4_code_edit_kernel.mmd`, `docs/diagrams/dfd_public_edit.mmd`, `docs/diagrams/seq_edit_success.mmd`, `docs/diagrams/state_edit_session.mmd`, `lib/src/edit/edit_kernel.dart`, `lib/src/edit/edit_session.dart`, `lib/src/edit/draft_document.dart`, `lib/src/edit/commit_compiler.dart`, `lib/src/edit/commit_applier.dart`, `lib/src/store/document_store_kernel.dart`, `lib/src/store/committed_document.dart`, `lib/src/store/element_registry.dart`, `lib/src/store/family_tables.dart`, `lib/src/store/document_projection_cache.dart`, `lib/src/selection/selection_kernel.dart`, `lib/src/runtime/runtime_root.dart`, `test/edit/edit_matrix_effects_test.dart`, `test/edit/fixtures/rollback_fixture.dart`, `test/store/fixtures/no_projection_hot_path_fixture.dart`, `test/spatial/fixtures/runtime_delivery_order_fixture.dart`, `test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart`, `test/benchmarks/benchmark_probe_flutter.dart`

## Classification

Profile: REFACTOR

Obligations: SEAM_MIGRATION

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Optimize the edit/store transaction owner first, not load/projection first. | `Goal`, `Boundaries.In Scope`, `Boundaries.Out of Scope` | Unit 7 public-route benchmark proof for `edit.add_element`, `edit.update_visual`, and `edit.update_transform`; load and first-read projection remain out of scope. |
| `D2` Keep `EditKernel` as public lifecycle, guard, rollback, stale-handle, and command-inheritance owner. | `Boundaries.Owner`, `Temporal Surface Closure`, Unit 2, Unit 4 | Sparse/session tests prove nested edit, Future rejection, stale-handle, callback rollback, command, and interaction routes still enter through `EditKernel`. |
| `D3` Move ordinary edit mutation storage/preparation to a store-owned sparse seam rather than edit-owned full draft state. | `Boundaries.Source of Truth`, Unit 1 | Store sparse-prepare tests and guardrails prove committed tables remain store-owned and ordinary sparse edits do not retain public `CanvasDocument` live state. |
| `D4` Preserve public `CanvasEdit` API, keep `draftSummary` sparse/non-materializing, and route `readDraftDocument`/`replaceDraftDocument` to materialized fallback. | `Boundaries.Compatibility`, Unit 2 | Public API compile fixtures, sparse `draftSummary` projection-count tests, and materialized fallback tests prove no public shape change and explicit materialization compatibility. |
| `D5` Keep `CommitCompiler` as typed invalidation/effect taxonomy owner for both sparse and materialized paths. | `Boundaries.Owner`, Unit 3, Unit 5 | Operation-matrix and taxonomy tests prove sparse commits produce exact typed effects instead of global invalidation or edit-owned duplicate taxonomy. |
| `D6` Preserve all-or-nothing behavior by preparing sparse committed snapshots and `PreparedSelectionEffect` outcomes before the irreversible store swap. | `All-Or-Nothing Failure Boundary`, Unit 1, Unit 3 | Rollback fixture and prepared-selection seam tests prove fallible validation, next snapshot preparation, and selection outcome preparation complete before store swap. |
| `D7` Preserve runtime delivery order: spatial effects before public state, then actions/observer under guard. | `Temporal Surface Closure`, Unit 4, Unit 5 | Delivery-order fixture proves spatial freshness before state listeners/actions/observer and reentrant public mutations fail with `StateError` without mutation. |
| `D8` Prove optimization through existing action-only public-route benchmarks using the locked 2x caps, plus no-projection semantic tests. | `Order Constraints`, Unit 5, Unit 7 | No-projection tests prove the hot path avoids public projection; focused benchmark run proves all locked latency/allocation caps on public `runtime.edits.edit` routes. |
| `D9` Update normative docs and the four durable edit diagrams when ordinary edits become sparse. | `Boundaries.Source of Truth`, Unit 6 | Documentation checks, diagram generation checks, and source-of-truth doc diffs prove contracts and diagrams describe sparse ordinary edit plus materialized fallback. |

## Evidence

- `.design/2026-06-06-incremental-edit-store.md:13` / disposition: design is `READY_FOR_CONTRACT` -> write a full step contract rather than a blocker.
- `.design/2026-06-06-incremental-edit-store.md:17` / product outcome: large-canvas one-element edits should stop behaving like full-document rewrites while preserving public edit semantics -> contract must target internal edit/store performance without public API change.
- `.design/2026-06-06-incremental-edit-store.md:21` / non-goal: `CanvasEditPort`, `CanvasEdit`, `CanvasDocument`, schema v1, and update DTO shapes must not change -> compatibility boundary excludes public API/schema changes.
- `.design/2026-06-06-incremental-edit-store.md:22` / non-goal: `loadDocument` and first `readDocument` are separate tracks -> contract excludes load/projection-first optimization.
- `.design/2026-06-06-incremental-edit-store.md:28` / classification: required profile is `REFACTOR` -> work is a seam migration, not a feature API.
- `.design/2026-06-06-incremental-edit-store.md:29` / classification: required obligation is `SEAM_MIGRATION` -> execution order must add and prove successor seams before retiring eager draft use.
- `.design/2026-06-06-incremental-edit-store.md:33` / performance gate: first optimization track success is locked, not left for implementer choice -> Unit 7 must compare exact 2x caps.
- `.design/2026-06-06-incremental-edit-store.md:37` / benchmark cap: `edit.add_element/100k avg_us` must be `<= 106530` -> benchmark completion check must include the exact add latency cap.
- `.design/2026-06-06-incremental-edit-store.md:41` / benchmark cap: `edit.update_visual/100k avg_us` must be `<= 104059` -> benchmark completion check must include the exact visual latency cap.
- `.design/2026-06-06-incremental-edit-store.md:45` / benchmark cap: `edit.update_transform/100k avg_us` must be `<= 105744` -> benchmark completion check must include the exact transform latency cap.
- `.research/2026-06-06-pixel6-manual-baseline-hotspots.md:32` / hotspot evidence: the three edit rows take about 208-213 ms and allocate about 48-60 MB -> one shared edit/store root cause should be optimized instead of per-case patches.
- `.research/2026-06-06-pixel6-manual-baseline-hotspots.md:47` / current path: `EditKernel.edit` creates `DraftDocument` from `_readDocument()`, materializes a draft, installs document changes, and delivers result -> successor seam must avoid eager projection/materialization on ordinary edits.
- `.research/2026-06-06-pixel6-manual-baseline-hotspots.md:48` / current data flow: store reads use `DocumentProjectionCache.projectionFor` and `DraftDocument` copies resources/background/layers -> projection/materialization must become explicit fallback, not ordinary mutation storage.
- `.research/2026-06-06-pixel6-manual-baseline-hotspots.md:61` / secondary path: `spatial.touched_update` calls update-transform before spatial metrics -> sparse edit must preserve typed touched delivery rather than bypass spatial correctness.
- `docs/architecture/03_data_model.md:49` / store model: `DocumentStoreKernel` stores compact committed tables and no live public `CanvasDocument` -> sparse committed preparation belongs in store tables.
- `docs/architecture/03_data_model.md:140` / public state: runtime observation is one immutable snapshot after an accepted owner change -> sparse state must not be publicly observable before accepted install.
- `docs/contracts/edit_kernel.md:100` / edit lifecycle: `EditKernel` stales the handle before runtime consumes accepted apply result -> sparse path must preserve stale-handle and delivery window.
- `docs/contracts/edit_kernel.md:138` / rollback: rollback leaves document, revisions, projection cache, spatial, resources, selection, actions, public state, and repaint unchanged -> fallible sparse work must complete before irreversible store swap.
- `docs/contracts/edit_kernel.md:177` / touched sets: generic global invalidation is forbidden except replacement -> sparse path must preserve exact `CommitCompiler` taxonomy.
- `docs/contracts/edit_kernel.md:227` / taxonomy owner: `CommitCompiler` remains field-effect source of truth and resource validation is preflighted -> sparse storage cannot duplicate or bypass typed invalidation policy.
- `docs/contracts/operation_matrix.md:55` / semantic matrix: operation rows define state, revisions, spatial, projection, repaint, and events -> sparse path requires operation-matrix parity proof.
- `docs/contracts/public_api_v1.md:1351` / public surface: `CanvasEdit` includes draft reads, summary, mutations, resources, metadata, clear, and replacement -> contract must preserve every public method.
- `docs/contracts/public_api_v1.md:1377` / public edit behavior: callbacks are synchronous and require nested-edit rejection, atomic mutations, rollback, notifications, stale handles, and materialization limits -> sparse mode must keep these temporal and compatibility guarantees.
- `docs/_registry/benchmarks.yaml:115` / benchmark registry: `edit.add_element` is action-only incremental edit with allocation budget -> benchmark proof must run the registered public route.
- `docs/_registry/benchmarks.yaml:136` / benchmark registry: `edit.update_visual` has the same action-only incremental boundary -> visual update proof must use the public route and allocation budget.
- `docs/_registry/benchmarks.yaml:157` / benchmark registry: `edit.update_transform` reports spatial touched pages plus allocation bytes -> transform proof must preserve touched semantics and memory improvement.
- `lib/src/runtime/runtime_root.dart:209` / composition seam: `RuntimeRoot` wires `EditKernel` to `_store.readDocument`, selected ids, commit install, and delivery -> migration point is runtime-composed edit/store seam.
- `lib/src/edit/edit_kernel.dart:43` / guard owner: public edit enforces mutation admission and non-nested sessions -> `EditKernel` remains lifecycle owner.
- `lib/src/edit/edit_kernel.dart:50` / eager draft: ordinary edit currently creates `DraftDocument(_readDocument())` -> Unit 4 retirement gate must remove eager draft from ordinary edit open.
- `lib/src/edit/edit_kernel.dart:64` / commit order: commit plan is read after callback and before install -> sparse mode must keep effect compilation after synchronous mutation collection.
- `lib/src/edit/edit_kernel.dart:66` / full install: accepted edit currently installs `session.readDraftDocument()` -> sparse path needs prepared sparse install when no explicit materialization occurred.
- `lib/src/edit/draft_document.dart:31` / materialization cost: `DraftDocument` copies public document state into mutable transaction state -> keep it only for explicit materialized fallback.
- `lib/src/edit/draft_document.dart:95` / add semantics: add element owns admission, insertion, touched set, and revision marking -> sparse journal must preserve add semantics.
- `lib/src/edit/draft_document.dart:124` / update semantics: update validates kind, resource references, typed touched facts, and revision deltas -> sparse journal must preserve update semantics.
- `lib/src/edit/draft_document.dart:275` / replacement path: `replaceDocument` prepares full replacement -> replacement remains materialized/full path.
- `lib/src/edit/draft_document.dart:304` / projection construction: `_materialize` builds full `CanvasDocument` -> ordinary sparse commits must avoid this unless explicit materialization occurs.
- `lib/src/edit/draft_document.dart:447` / lookup cost: `_findElement` scans background and layers -> store-owned indexed lookup is the owner-level fix for sparse update.
- `lib/src/edit/commit_compiler.dart:28` / taxonomy helper: `compileElementUpdate` computes revision/touched taxonomy from before and after elements -> sparse mode should reuse this pure taxonomy.
- `lib/src/store/document_store_kernel.dart:21` / store owner: store owns committed document facts, read projection, id admission, and selection normalization inputs -> sparse prepare/install belongs under store.
- `lib/src/store/document_store_kernel.dart:48` / projection cache: `readDocument` delegates to `DocumentProjectionCache.projectionFor` -> no-projection proof can observe projection build count.
- `lib/src/store/document_store_kernel.dart:157` / selection normalization: current selection normalization reads committed document membership -> prepared selection must compute next-facts outcome before swap.
- `lib/src/store/document_store_kernel.dart:178` / installer: current `installDocument` rebuilds `CommittedDocument` from public `CanvasDocument` -> sparse installer must avoid full committed reconstruction for single-row updates.
- `lib/src/selection/selection_kernel.dart:67` / selection owner: pruning normalizes ids through membership owner -> selection pruning remains a selection-owner effect.
- `lib/src/selection/selection_kernel.dart:71` / selection revision: replacement increments revision after membership is chosen -> prepared selection install can consume precomputed ids without post-swap membership reads.
- `lib/src/runtime/runtime_root.dart:1566` / delivery guard: runtime enters guarded commit-effect delivery -> runtime remains guard owner for observer/reentrant mutation windows.
- `lib/src/runtime/runtime_root.dart:1569` / delivery order: spatial effects are delivered before public state publication -> sparse delivery must preserve spatial freshness before observers.
- `test/store/fixtures/no_projection_hot_path_fixture.dart:6` / proof seam: existing fixture expects projection cache to be touched only by explicit `readDocument` -> sparse edit no-projection proof belongs in this family.
- `test/edit/edit_matrix_effects_test.dart:19` / semantic proof: matrix guard verifies fixture coverage against operation matrix rows -> sparse path must keep this coverage active.
- `test/edit/fixtures/rollback_fixture.dart:9` / rollback proof: rollback tests cover callback throw, validation failure, replacement rollback, and live mutation rejection -> sparse rollback cases extend this fixture.
- `test/spatial/fixtures/runtime_delivery_order_fixture.dart:28` / temporal proof: delivery-order tests assert spatial delivery before state/observer callbacks and guarded mutation attempts -> sparse path must pass the same temporal proof.
- `test/api_contract/fixtures/app_next_engine_adapter_compile_fixture.dart:73` / public compatibility: fixture exercises `readDraftDocument`, `draftSummary`, and every edit method in one callback -> public compatibility proof must still compile and run.
- `test/benchmarks/benchmark_probe_flutter.dart:1330` / benchmark route: primary edit benchmarks call ordinary `runtime.edits.edit` mutations -> performance proof must measure public route, not private helpers.
- `.design/2026-06-06-incremental-edit-store.md:330` / source-of-truth impact: future contract must update existing contracts, data model, cache policy, benchmark registry only if needed, and four diagrams -> Unit 6 owns docs/diagram updates.
- `.design/2026-06-06-incremental-edit-store.md:369` / handoff: profile, obligations, D1-D9, sequencing, source-of-truth updates, and proof surfaces are mandatory -> contract preserves all design handoff constraints.
- `.design/2026-06-06-incremental-edit-store.md:399` / open decisions: none -> implementation should not reopen owner, boundary, source-of-truth, proof, or performance target decisions.

## Boundaries

Owner:

`EditKernel` owns public edit session lifecycle, callback admission, nested-edit rejection, stale handles, rollback window, and command/interaction inheritance. `DocumentStoreKernel` owns committed sparse fact lookup, id/resource/layer validation, prepared committed snapshots, projection cache invalidation, and atomic committed-store install. `CommitCompiler` owns typed invalidation and field-effect taxonomy. `SelectionKernel` owns selected ids, but the edit/store commit boundary must hand it precomputed accepted ids through an internal `PreparedSelectionEffect` so post-swap selection install performs no document-membership read. `RuntimeRoot` owns composition and post-install delivery order.

In Scope:

Add a store-owned sparse prepare/install seam for ordinary edit mutations. Add sparse `EditSession` backing state and journal behavior for ordinary public `CanvasEdit` methods. Keep `draftSummary` sparse and non-materializing before promotion. Promote to `DraftDocument` only on explicit `readDraftDocument`, `replaceDraftDocument`, and compatibility paths that require full materialization. Preserve current public edit method signatures, synchronous callback rules, stale handles, no-op semantics, rollback, revision deltas, touched sets, selection pruning, resource validation, command/interaction routes, action emission, observer delivery, and public state publication. Add prepared-selection handoff before committed-store swap. Update tests, guardrails, normative docs, durable diagrams, and public-route benchmarks required by the design.

Out of Scope:

Do not change `CanvasEditPort`, `CanvasEdit`, `CanvasDocument`, schema v1, public update DTOs, benchmark caps, or public benchmark-only APIs. Do not optimize `loadDocument`, first `readDocument`, codec, frame, or spatial query owners except for secondary effects naturally caused by preserving edit touched delivery. Do not move committed-store policy into edit, runtime, frame, benchmarks, tests, or docs-only abstractions. Do not use benchmark-only shortcuts or fixture-only production paths. Do not relax exact invalidation, rollback, stale-handle, nested-edit, delivery-order, selection-owner, or explicit draft-read guarantees.

Source of Truth:

The design `.design/2026-06-06-incremental-edit-store.md` is the decision handoff. Durable runtime/data/edit meaning remains in `docs/architecture/03_data_model.md`, `docs/contracts/edit_kernel.md`, `docs/contracts/operation_matrix.md`, `docs/contracts/public_api_v1.md`, `docs/contracts/cache_policy.md`, and the four named durable edit diagrams. Runtime committed document facts remain in `DocumentStoreKernel`; public `CanvasDocument` remains a projection/read artifact; sparse journal state is transient callback-local edit state; materialized draft state is transient fallback state; selected ids remain in `SelectionKernel`; delivery state remains in `RuntimeRoot`. Benchmark target semantics remain in `docs/_registry/benchmarks.yaml` and the existing benchmark runner/probe surfaces.

Compatibility:

Public Dart API signatures, schema v1 data format, public update DTO shapes, public callback synchrony, exception/no-op behavior, action stream behavior, state publication semantics, and explicit `readDraftDocument` materialization behavior must remain compatible. Internal seams may change. `DraftDocument` may stop being the ordinary backing store, but it must remain available as the explicit materialized fallback until all compatibility tests prove the fallback behavior.

Order Constraints:

First add store sparse fact/prepare/install seams and no-projection guardrails without routing ordinary edits through them. Then add sparse-capable `EditSession` backing, sparse `draftSummary`, and materialized fallback behind an internal successor seam while ordinary public edit and interaction routes still use the existing eager draft path. Then add prepared-selection and sparse commit/apply payloads so all fallible validation and next-state preparation complete before store swap. Then migrate ordinary `edit`, command, and interaction commit routes to sparse mode and retire eager `DraftDocument(_readDocument())` from ordinary edit open only after replacement seams and tests exist. Then expand semantic, rollback, temporal, and guardrail proof across sparse and materialized modes. Then update normative docs and durable diagrams in the same implementation change that changes the seam. Run focused public-route benchmarks only after semantic proof passes; benchmark success is either the pinned 2x cap table or a design-allowed fresh pre-change report where every listed post-change metric is `<= 50%` of the same pre-change metric, not private helper speed.

Temporal Surface Closure:

The temporal invariant is that no public observer sees sparse uncommitted state. Synchronous callback surfaces are the public edit callback, explicit `readDraftDocument`, `replaceDraftDocument`, commit apply, state listeners, action stream listeners, and commit-effect observer. `EditKernel` owns callback, nested-edit, Future-result, stale-handle, and rollback guards. `RuntimeRoot` owns post-install delivery and reentrant mutation guard. Allowed public observation order is sparse/materialized callback mutation collection -> exact plan compilation -> all fallible sparse/materialized and prepared-selection validation -> committed-store install -> precomputed selection install -> stale handle close -> spatial effects -> public state/action publication when required -> observer effects under guard. Reentrant public mutations during edit callback, state listener, action listener, or observer delivery must throw `StateError` and leave committed document, selection, revisions, projection cache, spatial state, public state, actions, and observers unchanged beyond the accepted commit already being delivered.

All-Or-Nothing Failure Boundary:

The irreversible point is swapping the committed store snapshot. Fallible work before that point includes sparse journal validation/replay, duplicate id checks, resource reference checks, update-kind checks, no-op detection, replacement validation, revision/touched planning, next committed snapshot construction, and `PreparedSelectionEffect` computation from accepted next document facts. Later work is allowed only because it is infallible, failure-contained, or part of the accepted result: selection install consumes precomputed ids without membership validation, spatial/resource/frame observer failures remain contained delivery failures, and public-state/action/observer delivery follows the existing accepted-result contract. Failure projection before the irreversible point is the existing public exception or no-op signal with unchanged committed document, selected ids, revisions, projection cache, spatial index, public state, actions, and observer effects. The proof surface is rollback fixture expansion, no-projection proof, prepared-selection seam tests, and delivery-order/reentrant mutation tests.

## Execution Units

### [x] Unit 1: Store sparse committed preparation seam

Owner:

`DocumentStoreKernel` and store-owned committed-table collaborators under `lib/src/store/**`.

Boundary:

Add the store-owned sparse fact lookup, validation, next-snapshot preparation, and atomic install surface without making public `CanvasDocument` live state or edit-owned indexes a second source of truth.

Change:

Introduce internal store APIs that let edit sessions read committed facts for touched ids, layers, resources, and ordering without calling `readDocument`. Add prepared sparse install payloads that validate duplicate ids, resource references, layer membership, row placement, revision deltas, projection invalidation, and aligned `ElementRegistry`/family-table snapshots before the committed-store swap. Preserve full `installDocument`/`replaceDocument` paths for materialized fallback and load/replacement behavior. Do not retain public `CanvasDocument` in production fields outside the existing projection cache read path.

Completion Check:

Store-focused tests prove add, visual update, transform update, no-op update, resource reference validation, missing-id update, layer insertion, clear, and replacement fallback prepare the expected committed facts or fail before store swap. No-projection fixture proves ordinary sparse add/update/no-op preparation and install do not increase `projectionBuildCount`; explicit `readDocument` still does. Structural guardrails or focused tests fail if sparse store paths call `DocumentStoreKernel.readDocument`, retain public `CanvasDocument` live state, or place committed id/resource/layer policy outside `lib/src/store/**`. `dart analyze`, `dcm analyze .`, `dcm calculate-metrics lib/src/store test/store`, and focused store tests pass.

Depends On:

None.

### [x] Unit 2: Sparse edit session and materialized fallback

Owner:

`EditKernel`, `EditSession`, and edit-owned transient session state under `lib/src/edit/**`.

Boundary:

Introduce sparse-capable callback-local journal state and materialized compatibility behavior without changing the ordinary public route yet.

Change:

Add the internal sparse-capable edit session/backing that Unit 4 will later wire into ordinary public routes. Record ordinary mutation semantics into sparse session state backed by store fact reads and reusable edit logic, but keep the existing eager `DraftDocument(_readDocument())` route as the public default until Unit 4. Preserve callback synchrony, nested-edit rejection, stale handles, no-op handling, resource mutation semantics, metadata changes, clear, delete, and replacement behavior in the sparse-capable seam. Make sparse `draftSummary` compute from committed summary plus sparse deltas without building a public projection before promotion. Promote to `DraftDocument` on `readDraftDocument` and `replaceDraftDocument`; mutations before promotion must appear in the materialized draft, and later mutations must commit through the materialized fallback path.

Completion Check:

Sparse-capable edit seam tests prove every `CanvasEdit` method keeps its public signature and behavior through sparse mode and materialized promotion without switching ordinary public routes before Unit 4. Sparse `draftSummary` tests prove add, remove, resource edit, clear, no-op, and metadata operations update summary counts without increasing `projectionBuildCount` until explicit `readDraftDocument` or replacement. Materialized fallback tests prove `readDraftDocument` includes prior sparse mutations, subsequent mutations commit, replacement remains full/materialized, and rollback after promotion restores all owners. Sparse and materialized session lifecycle tests explicitly prove stale-handle operations after close throw `StateError` and leave no document, selection, revision, projection, spatial, public-state, action, or observer mutation. API contract compile fixtures still exercise `readDraftDocument`, `draftSummary`, and every edit method in one callback. `dart analyze`, `dcm analyze .`, `dcm calculate-metrics lib/src/edit test/edit test/api_contract`, and focused edit/API tests pass.

Depends On:

Unit 1.

### [x] Unit 3: Typed commit and prepared selection boundary

Owner:

`CommitCompiler`, `CommitApplier`, internal commit-delivery contracts, and `SelectionKernel` selection replacement seam.

Boundary:

Preserve exact typed invalidation and all-or-nothing selection pruning when accepted sparse commits install.

Change:

Extend commit planning/apply payloads so sparse and materialized paths both use `CommitCompiler` as the taxonomy source of truth. Add an internal `PreparedSelectionEffect` seam computed from accepted next document facts before the store swap. Install selection after store swap by consuming precomputed accepted ids without document-membership validation or current-store normalization. Preserve document and selection publication as one accepted result.

Completion Check:

Operation-matrix and taxonomy tests prove sparse add, remove, visual update, transform update, resource reference update, visibility/selectability prune, clear, replacement fallback, no-op, background, grid, palette, and metadata rows produce the same document, revision, touched, spatial, projection, resource, repaint, selection, event, and public-state effects as materialized/current semantics. Prepared-selection seam tests prove next-facts computation happens before the committed-store swap and post-swap selection install performs no membership read. Rollback tests inject sparse validation failure, resource validation failure, update-kind failure, mixed sparse/materialized failure, and prepared-selection failure before swap; expected result is unchanged committed document, selected ids, revisions, projection cache, spatial index, public state, actions, and observers. `dart analyze`, `dcm analyze .`, `dcm calculate-metrics lib/src/edit lib/src/selection test/edit test/selection`, and focused commit/selection tests pass.

Depends On:

Unit 1 and Unit 2.

### [x] Unit 4: Runtime route migration and eager-draft retirement

Owner:

`RuntimeRoot` edit/store composition seam and `EditKernel` route wiring.

Boundary:

Move ordinary public edit, command, and interaction commit routes onto the sparse successor seam only after store, session, and prepared-selection seams exist.

Change:

Route ordinary `CanvasEditPort.edit`, command mutations, and interaction prepared commits that currently inherit edit commit planning through the sparse path when no explicit materialization is requested. Preserve full document install for `readDraftDocument`-promoted sessions, replacement fallback, and load document. Retire eager `DraftDocument(_readDocument())` from ordinary edit open and interaction prepared commit open, while keeping `_store.readDocument` available only for explicit read/projection/materialization paths.

Completion Check:

Route tests prove ordinary edit, command remove/clear/update paths, draw-tool commits, eraser/context-action commits, no-op edits, and explicit materialized edits all publish the same accepted results as before. Public route temporal tests explicitly attempt nested edit inside an edit callback, return a `Future` from an edit callback, and use stale handles after callback close in both sparse and materialized routes; each forbidden action throws `StateError` and leaves no extra document, selection, revision, projection, spatial, public-state, action, or observer mutation. A structural search or guardrail fails if ordinary edit open or interaction commit open still constructs `DraftDocument(_readDocument())` or calls `session.readDraftDocument()` for sparse commits. Runtime tests prove accepted sparse commits publish exactly one coherent public `CanvasRuntimeState` when required and no publication on no-op. `dart analyze`, `dcm analyze .`, `dcm calculate-metrics lib/src/runtime lib/src/edit test/runtime test/interaction`, focused runtime/interaction tests, and architecture graph checks for the affected P14 graph surfaces pass.

Depends On:

Unit 1, Unit 2, and Unit 3.

### [x] Unit 5: Semantic, temporal, and negative-proof hardening

Owner:

Test and guardrail proof surfaces under `test/edit/**`, `test/store/**`, `test/spatial/**`, `test/guardrails/**`, and any existing guardrail/tool owner extended for projection/live-state checks.

Boundary:

Make sparse correctness mechanically provable before benchmark proof is accepted.

Change:

Expand existing semantic parity, rollback, no-projection, delivery-order, reentrant mutation, public compatibility, and guardrail coverage so sparse and materialized modes are both exercised through real public `runtime.edits.edit` routes. Keep fixture-only names, ids, or sentinels out of production APIs, durable docs, generated docs, benchmark registry, and public schema. Strengthen projection/live-state guardrails so ordinary sparse hot paths cannot silently reintroduce public projection or live public-document storage.

Completion Check:

`test/edit/edit_matrix_effects_test.dart` and its coverage guard fail if any operation-matrix row lacks sparse/materialized parity proof. `test/edit/fixtures/rollback_fixture.dart` fails if callback throw, validation failure, materialization after sparse ops, selection-prune rollback, or replacement fallback changes committed owners, selected ids, revisions, projection cache, spatial index, public state, actions, or observers. `test/store/fixtures/no_projection_hot_path_fixture.dart` fails if sparse add/update/no-op or `draftSummary` builds projection. Temporal tests cover every synchronous callback surface named in this contract: nested edit during public edit callback throws `StateError` with no mutation; Future-returning edit callback throws `StateError` with rollback; stale-handle operations after callback close throw `StateError` with no mutation; reentrant mutation attempts in state listener, action listener, and commit-effect observer surfaces throw `StateError` with no extra mutation. `test/spatial/fixtures/runtime_delivery_order_fixture.dart` also fails unless spatial effects are delivered before public state/action/observer. Guardrail tests fail on sparse hot-path projection calls or retained public `CanvasDocument` live state. `dart analyze`, `dcm analyze .`, owner-scoped DCM metrics for changed production/test/tool owners, and all focused semantic/guardrail tests pass.

Depends On:

Unit 1, Unit 2, Unit 3, and Unit 4.

### [ ] Unit 6: Source-of-truth docs and durable diagrams

Owner:

Existing normative docs and durable diagrams under `docs/**`.

Boundary:

Update only the existing owning source-of-truth artifacts that describe edit/store data flow, cache policy, operation effects, and edit diagrams.

Change:

Update `docs/contracts/edit_kernel.md` to describe sparse ordinary edit, materialized fallback, `draftSummary`, prepared sparse commit, prepared selection, rollback, touched-set, and delivery order. Update `docs/architecture/03_data_model.md` to describe store-owned sparse committed-table prepare/install while keeping public `CanvasDocument` projection-only. Update `docs/contracts/operation_matrix.md` only where notes must clarify sparse/materialized implementation paths without changing row outcomes. Update `docs/contracts/cache_policy.md` so ordinary sparse edits invalidate projection revision without building a public projection. Update `docs/_registry/benchmarks.yaml` only if implementation changes required metrics, exact invariants, or cap metadata; do not relax caps. Update `docs/diagrams/c4_code_edit_kernel.mmd`, `docs/diagrams/dfd_public_edit.mmd`, `docs/diagrams/seq_edit_success.mmd`, and `docs/diagrams/state_edit_session.mmd` to show sparse journal, materialized fallback, prepared selection, store install ordering, and sparse/materialized session states.

Completion Check:

Documentation checks prove docs and generated projections are synchronized: `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after any required generated-doc refresh. Architecture graph checks prove the affected P14 graph surfaces remain current: `dart run tool/architecture_graph/check.dart --phase P14` and `dart run tool/architecture_graph/generate_views.dart --phase P14 --check` pass. Contract text review verifies no new durable doc exists solely to record task progress and no docs prose contradicts `DocumentStoreKernel` as committed source of truth, public `CanvasDocument` as projection, `CommitCompiler` as taxonomy owner, or `SelectionKernel` as selected-id owner.

Depends On:

Unit 1, Unit 2, Unit 3, Unit 4, and Unit 5.

### [ ] Unit 7: Public-route performance proof and final migration gate

Owner:

Benchmark probe/report surfaces under `test/benchmarks/**`, existing benchmark runner/tooling, and the implementation owners whose metrics are being proven.

Boundary:

Accept the sparse-store migration only after semantic proof passes and the existing public benchmark route proves the locked 2x latency/allocation caps.

Change:

Run focused public-route benchmarks for `edit.add_element`, `edit.update_visual`, and `edit.update_transform` at 100k after semantic, rollback, guardrail, docs, and analyzer checks pass. Include secondary `spatial.touched_update` observation where available, but do not treat secondary benefit as a replacement for primary edit caps. Use exactly one benchmark proof mode and record which one was used in implementation close-out. Pinned-cap mode compares the post-change report against the exact manual-baseline 2x caps from the design. Fresh-current mode requires a same-harness, same-manifest pre-change current report captured before sparse route migration and a post-change report captured after migration; every listed post-change metric must be `<= 50%` of the corresponding pre-change current metric. Do not update caps, baselines, or benchmark fixtures to hide failure.

Completion Check:

Benchmark proof uses one of two accepted modes. In pinned-cap mode, the post-change public-route report is at or below all locked caps: `edit.add_element/100k avg_us <= 106530`, `p95_us <= 112228`, `max_us <= 112228`, `allocation_bytes <= 26157056`; `edit.update_visual/100k avg_us <= 104059`, `p95_us <= 107497`, `max_us <= 107497`, `allocation_bytes <= 29835264`; `edit.update_transform/100k avg_us <= 105744`, `p95_us <= 116825`, `max_us <= 116825`, `allocation_bytes <= 24387584`. In fresh-current mode, the close-out includes the pre-change current report path, post-change report path, same-harness/same-manifest evidence, and computed caps for every listed avg_us, p95_us, max_us, and allocation_bytes metric; the post-change metric must be `<= 50%` of the same pre-change metric for all listed rows. The benchmark invocation must use ordinary `runtime.edits.edit` routes from `test/benchmarks/benchmark_probe_flutter.dart`, not private helper microbenchmarks. Final close-out also reruns `dart analyze`, `dcm analyze .`, DCM metrics for all changed production/test/tool owners, focused semantic tests, focused benchmark/tool tests, documentation checks, and applicable architecture graph checks.

Depends On:

Unit 1, Unit 2, Unit 3, Unit 4, Unit 5, and Unit 6.
