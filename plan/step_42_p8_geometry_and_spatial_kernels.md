# Change Contract

## Goal

Implement P8 as the engine's internal bounded geometry and spatial query layer: geometry policies compute hit/paint/eraser primitives, `SpatialKernel` owns derived tile/outlier membership and typed candidate results, and `RuntimeRoot` keeps spatial state updated before public runtime state or observer callbacks can see accepted commits or loads.

## Evidence

- `.design/2026-05-29-p8-geometry-spatial.md` / selected form: P8 is `READY_FOR_CONTRACT` and selects a derived `SpatialKernel` under `lib/src/geometry/**`, composed by `RuntimeRoot`, fed by existing spatial delivery effects, and reading committed rows through the existing immutable committed read boundary -> implement Candidate A and do not redesign the owner, source of truth, delivery order, or proof strategy.
- `docs/implementation/p8_geometry_and_spatial.md` / build scope: P8 owns `GeometryPolicy`, `HitTestPolicy`, bounds policy, exact family hit tests, paint admission, eraser primitive budget foundations, `SpatialKernel`, `TileIndex`, `OutlierIndex`, `SpatialMembership`, touched update, stale rejection, typed budget results, and no global scene traversal -> the step must cover both geometry primitives and spatial indexing, not only one side.
- `docs/implementation/p8_geometry_and_spatial.md` / donor list: required P8 donors include numeric policy, local bounds, paint admission, transform/core geometry, hit tests, eraser exact-hit inputs, spatial index/cache behavior, and committed read paths -> implementation must map and port every required donor as algorithm/proof input while rejecting forbidden legacy architecture shells.
- `.design/2026-05-29-p8-geometry-spatial.md` / required donor mapping: `direct_numeric_policy`, `direct_local_bounds_policy`, and `direct_paint_admission` are direct-copy inputs; `foundation_transform2d`, `foundation_core_geometry`, and `geometry_interactive_geometry` are copy/adapt inputs; `geometry_node_geometry`, `geometry_hit_test`, `render_geometry_builder`, `geometry_eraser_exact_hit`, `spatial_scene_spatial_index`, `spatial_index_cache`, and `store_scene_controller_read_paths` are adapt inputs -> donor mapping proof must account for all thirteen required donors by name.
- `.design/2026-05-29-p8-geometry-spatial.md` / forbidden donor structures: `avoid_scene_controller_facades`, `avoid_interactive_runtime_whole`, `avoid_scene_builder_public_architecture`, `avoid_scene_codec_whole`, and `avoid_scene_store_controller_whole` are explicit avoid decisions -> the implementation must not import those legacy architecture shells through donor work.
- `docs/contracts/geometry.md` / geometry policy: geometry constants, finite/invertible rules, hit eligibility, paint bounds, marquee, and eraser primitive/budget rules are already the durable policy source -> production geometry and tests must conform to this contract and keep P12 terminal eraser commit proof out of P8.
- `docs/contracts/spatial_kernel.md` / spatial policy: `SpatialKernel` owns hit/paint tile indexes, outlier indexes, `entriesById`, structural revision, touched-only ordinary updates, invalid-index fallback, non-hub budget counters, and typed budget-exceeded results with no partial candidates -> spatial query/update behavior must be implemented in that owner and tested at those seams.
- `docs/architecture/01_runtime_ownership.md` / ownership table: `SpatialKernel` owns coarse candidate lookup and outlier policy but must not be source of truth for the scene -> committed rows remain store-owned and spatial state remains derived/rebuildable.
- `docs/architecture/02_package_boundaries.md` / import boundary: `lib/src/geometry/**` may use only typed geometry/spatial delta/read ports and must not import concrete store tables or interaction/frame state -> geometry must consume committed facts through internal contracts, not direct store/runtime/frame dependencies.
- `lib/src/contracts/internal/frame_facts_port.dart` / committed read boundary: `FrameFactsPort` already exposes revisions, element handles, element facts, and resource descriptors, but handles currently carry only id, structural revision, generation, and order token -> extend this boundary only for missing durable scope facts such as location kind or layer id when P8 requires them.
- `lib/src/contracts/internal/touched_set.dart` / delta input: `TouchedSet` distinguishes added, removed, updated, transformed, geometry, visual, resource, layer, background, and replacement changes -> spatial ordinary updates must be driven by this existing typed delta instead of inventing a parallel delta model.
- `lib/src/contracts/internal/commit_delivery.dart` / delivery effect: `SpatialDeliveryEffect` already carries a `TouchedSet` in post-commit delivery -> preserve the observer-visible effect surface while making runtime consume spatial effects before forwarding them.
- `lib/src/edit/commit_applier.dart` / irreversible point: accepted commits install or replace the document before delivery effects are materialized -> spatial update failure after this point must be failure-contained as invalid spatial state, not a rollback of the accepted document.
- `lib/src/runtime/runtime_root.dart` / publication order: edit and load delivery currently publish runtime state before forwarding effects to the observer, and public mutations are rejected during delivery -> P8 must insert spatial update/rebuild before `_publishRuntimeState` and before `CommitEffectObserver`, preserving the mutation guard for callbacks.
- `docs/verification/tests.md` / P8 tests: the verification inventory already names geometry and spatial tests under `test/geometry/**` and `test/spatial/**` -> focused tests, not smoke tests, own internal spatial behavior proof.
- `docs/verification/tests.md` / smoke policy: the public incremental smoke test imports only the root public barrel and must stay coarse by appending the next real public user step -> P8 smoke coverage must be public compatibility only, not internal spatial assertions.
- `docs/verification/guardrails.md` / P8 guardrails: geometry/spatial guardrails forbid legacy scene order, partial eraser budget behavior, full ordinary spatial clones, stale candidates, and unenforced fallback budgets -> add runner-backed guardrail proof after concrete production seams exist.
- `tool/guardrails/src/owner_dag_import_checks.dart` / selected owner DAG: runtime currently may import contracts, edit, resources through `RuntimeRoot`, selection, and store, while `runtime -> spatial` is not yet an allowed edge -> P8 must add a narrow `RuntimeRoot -> SpatialKernel` composition edge and prove no reverse or broad spatial coupling is introduced.

## Boundaries

Owner:

`SpatialKernel` under `lib/src/geometry/**` owns derived spatial state, tile/outlier membership, invalid-index state, typed spatial query results, and non-hub budget counters. `GeometryPolicy` and `HitTestPolicy` under `lib/src/geometry/**` own geometry constants, bounds, paint admission, exact hit orchestration, marquee, and eraser primitive budget foundations. `RuntimeRoot` owns composition and delivery ordering. `FrameFactsPort` remains the committed immutable read boundary; `DocumentStoreKernel` remains committed scene truth.

In Scope:

Create the P8 geometry/spatial production owner under `lib/src/geometry/**`; extend committed row handles/facts only for missing durable scope facts; port required P8 donor algorithms and proof cases into new owners; implement touched-only spatial updates, rebuild/reset paths, stale rejection, invalid-index fallback, and typed no-partial budget results; wire runtime commit/load delivery so spatial update or invalidation happens before public state publication and observer callbacks; add focused tests, guardrails, architecture graph closure, durable docs/diagram updates, and a coarse public-barrel smoke extension.

Out of Scope:

Do not add public hit-test, paint-query, marquee, eraser, or context-action APIs. Do not implement frame rendering, pointer interaction, selected move, text hit testing, terminal eraser commits, or P12 no-partial erase commits. The existing `geometry.eraser_exact_budget_no_partial` inventory entry may be clarified for P8 only to cover primitive/exact-check budget inputs; runner enforcement of terminal erase cleanup/no-op behavior remains P12. Do not store spatial truth in `DocumentStoreKernel`, read concrete store tables from geometry, introduce a duplicate `SpatialFactsPort` unless implementation evidence proves the existing committed read boundary cannot remain cohesive, scan the full scene silently on fallback, or copy legacy `SceneNode`, `NodeSnapshot`, controller, scene, codec, or cache-shell architecture.

Source of Truth:

P8 scope and donor obligations come from `docs/implementation/p8_geometry_and_spatial.md` and `.design/2026-05-29-p8-geometry-spatial.md`. Geometry behavior comes from `docs/contracts/geometry.md`. Spatial behavior comes from `docs/contracts/spatial_kernel.md`. Committed document truth remains `DocumentStoreKernel`; committed row reads flow through `FrameFactsPort`. Verification inventory and guardrail ids remain in `docs/verification/tests.md`, `docs/verification/guardrails.md`, and the guardrail runner registry.

Compatibility:

The public package API and root public barrel remain compatible. Existing `CommitEffectObserver` delivery remains observable, but spatial effects are consumed by runtime before effects are forwarded. Accepted commits and loads are not rolled back because spatial indexing fails after the committed-state irreversible point; instead the spatial index is marked invalid and queries return bounded fallback or typed budget-exceeded results until rebuild/retry outside hot pointer/paint paths. Pure spatial budget paths increment non-hub counters and do not write DiagnosticsHub records.

Order Constraints:

First settle the committed row facts and donor mapping needed by geometry scope. Then implement geometry policies before spatial entries depend on derived hit/paint bounds. Then implement spatial result/index/update behavior before wiring runtime delivery. Wire runtime delivery before expanding smoke coverage. Add guardrails and architecture/docs closure after concrete production seams and file names exist. Run architecture and documentation checks after graph/docs/diagram changes.

## Execution Units

### [x] Unit 1: Committed Row Boundary And Donor Map

Owner:

`FrameFactsPort`, `DocumentStoreKernel`, `ElementRegistry`, and P8 implementation evidence under the existing docs/test surfaces.

Boundary:

Only committed immutable read facts and donor proof mapping needed by P8 geometry/spatial scope. No geometry direct store reads, no duplicate spatial read port, and no public API exposure.

Change:

Extend the existing committed handle/facts boundary with the exact P8-required durable scope facts `locationKind` and nullable `layerId`, and update store handle materialization/resolution so generation, structural revision, order token, and handle identity scope facts remain validated together. Do not add new committed `boundsRevision` or `elementRevision` surfaces for P8 unless implementation evidence proves the existing `FrameRevisionFacts.boundsRevision` and `FrameElementFacts.revision` cannot support spatial stale proof; if they are promoted into handle identity, validate them in the same committed-read tests. Record or encode the required P8 donor mapping so `direct_numeric_policy`, `direct_local_bounds_policy`, `direct_paint_admission`, `foundation_transform2d`, `foundation_core_geometry`, `geometry_node_geometry`, `geometry_hit_test`, `render_geometry_builder`, `geometry_interactive_geometry`, `geometry_eraser_exact_hit`, `spatial_scene_spatial_index`, `spatial_index_cache`, and `store_scene_controller_read_paths` are copied, adapted, rejected, or explicitly deferred into the correct P8 owner before their algorithms are used. The same mapping must record the avoid decision for `avoid_scene_controller_facades`, `avoid_interactive_runtime_whole`, `avoid_scene_builder_public_architecture`, `avoid_scene_codec_whole`, and `avoid_scene_store_controller_whole`.

Completion Check:

`dart test test/spatial/committed_spatial_read_boundary_test.dart` proves `FrameFactsPort.elementHandles` and `resolveElement` expose `locationKind` and nullable `layerId` for background and content rows, reject stale structural revision/generation/order-token handles, reject mismatched or stale scope facts if those facts become part of `FrameElementHandle`, and do not expose store tables. If implementation keeps `locationKind` or `layerId` as facts-only fields instead of handle identity fields, the same test file must prove they are resolved from the current committed row and cannot be supplied by callers to bypass generation/structural/order validation. `dart test test/geometry/geometry_spatial_donor_mapping_test.dart` names all thirteen required P8 donors and all five forbidden donor structures listed in this unit, and links each one to a copied/adapted proof case, an owning P8 implementation unit, or a documented out-of-scope reason.

Depends On:

None.

### [x] Unit 2: Geometry And Hit Policy

Owner:

`lib/src/geometry/geometry_policy.dart`, `lib/src/geometry/hit_test_policy.dart`, and focused geometry tests.

Boundary:

Pure geometry policy over committed row facts and public DTO value types. No spatial index mutation, no runtime delivery, no frame/interaction ownership, no legacy scene traversal, and no P12 terminal erase commit behavior.

Change:

Implement numeric constants, transform/math helpers, local bounds, hit bounds, paint bounds, family exact-hit checks, hit eligibility, topmost hit resolution over ordered candidate handles, paint admission, marquee inclusion primitives, and eraser primitive/exact-budget input helpers according to `docs/contracts/geometry.md`, using the mapped donor algorithms over new P8 shapes.

Completion Check:

`dart test test/geometry/hit_policy_test.dart` proves constants, finite/invertible handling, family hit behavior, topmost candidate resolution from order tokens, paint admission, marquee primitives, and corrupted non-invertible row miss-without-mutation behavior. `dart test test/geometry/no_legacy_scene_order_test.dart` proves geometry code uses committed handles/order tokens and not legacy scene traversal or scene order logic. `dart test test/geometry/eraser_exact_budget_inputs_test.dart` proves P8 exposes corridor envelope, family exact-check input limits, preview candidate/exact-check budget inputs, and terminal candidate/exact-check budget input shapes without asserting terminal cleanup/no-op commit behavior.

Depends On:

Unit 1.

### [x] Unit 3: Spatial Query Result And Index Structures

Owner:

`lib/src/geometry/spatial_query_port.dart`, `lib/src/geometry/spatial_query_result.dart`, `lib/src/geometry/spatial_membership.dart`, `lib/src/geometry/tile_index.dart`, `lib/src/geometry/outlier_index.dart`, `lib/src/geometry/spatial_budget_counters.dart`, and focused spatial tests.

Boundary:

Derived spatial DTOs, membership records, tile/outlier indexes, query-result taxonomy, and non-hub counters. No runtime composition, no committed store ownership, no public API, and no query hot-path index or membership mutation; budget and invalid probes may update non-hub counters only.

Change:

Implement typed candidate, invalid/rebuild-needed, stale, and budget-exceeded result shapes; hit/paint membership records; tile page updates; outlier-only membership for oversized elements; query tile budget handling; max fallback candidate enforcement; and non-hub budget/invalid probes. Ensure budget-exceeded results contain no partial candidate list.

Completion Check:

`dart test test/spatial/fallback_budget_enforced_test.dart` proves query tile and fallback candidate budgets increment only non-hub counters, return typed budget-exceeded results with no partial candidates, and never scan the full scene silently. `dart test test/spatial/tile_outlier_membership_test.dart` proves elements above `kCanvasMaxCellsPerElement` are outlier-only and ordinary elements are not duplicated into outlier and tile membership.

Depends On:

Unit 2.

### [x] Unit 4: SpatialKernel Update, Rebuild, And Stale Rejection

Owner:

`lib/src/geometry/spatial_kernel.dart` and focused spatial tests.

Boundary:

`SpatialKernel` staged update/rebuild/query behavior using `TouchedSet`, `FrameFactsPort`, geometry policies, and the index structures from Unit 3. No runtime publication order, no public API, and no direct concrete store reads.

Change:

Implement initial rebuild, load/replacement rebuild, clear-content empty reset, ordinary touched-only update, staged delta preparation, previous-membership removals, new-bound additions, stale id/generation/structural-revision validation, invalid-index marking on failed preparation, bounded fallback query behavior, rebuild/retry scheduling signal outside hot paths, and read-only hit/paint/marquee/eraser candidate query entrypoints.

Completion Check:

`dart test test/spatial/touched_update_test.dart` proves ordinary edits update only touched ids/pages and replacement/load rebuilds the full index. `dart test test/spatial/no_full_clone_for_touched_update_test.dart` proves ordinary spatial updates do not clone the full index and only copy touched pages. The same no-full-clone test includes a clear-content assertion proving the operation-matrix `clearContent` path resets to an empty spatial index, produces no remaining hit/paint candidates, and does not use the generic full-scene clone path. `dart test test/spatial/stale_generation_rejected_test.dart` proves stale generation, structural revision, and order-token candidates are rejected before hit/frame use. `dart test test/spatial/invalid_index_fallback_test.dart` proves failed staged delta application discards prepared membership changes, marks the index invalid, and returns bounded invalid/rebuild-needed or budget-exceeded results without mutating query hot-path indexes or memberships; budget and invalid probes may update non-hub counters only.

Depends On:

Units 1, 2, and 3.

### [x] Unit 5: Runtime Spatial Delivery Ordering

Owner:

`lib/src/runtime/runtime_root.dart`, existing commit/load delivery surfaces, and runtime delivery-order tests.

Boundary:

Runtime composition and synchronous commit/load delivery ordering only. Do not change commit acceptance semantics, public API shape, or observer effect payload shape unless existing `SpatialDeliveryEffect` is proven insufficient.

Change:

Compose `SpatialKernel` in `RuntimeRoot`, run initial/load rebuilds and accepted-edit touched updates from `SpatialDeliveryEffect`, and ensure spatial update, rebuild, or invalid-index marking occurs after accepted store install/replace and before `_publishRuntimeState` and `CommitEffectObserver`. Preserve the existing public mutation guard during state listener and observer callbacks.

Completion Check:

`dart test test/spatial/runtime_delivery_order_test.dart` proves runtime construction performs an initial spatial rebuild or marks spatial state invalid before any internal spatial query/use path can observe the initial document. The same test proves accepted edit and load paths update or invalidate spatial state before `CanvasRuntime.state` listeners and `CommitEffectObserver` run. It attempts a public runtime mutation from those callback surfaces and observes the existing `StateError` rejection with no additional document mutation. Failure-containment tests prove a spatial update failure after the commit irreversible point does not roll back the accepted document and exposes invalid spatial query state instead of partial candidates.

Depends On:

Unit 4.

### [x] Unit 6: Guardrails And Architecture Closure

Owner:

`tool/guardrails/src/**`, guardrail tests, `docs/verification/guardrails.md`, `docs/architecture/architecture_graph.yaml`, generated architecture graph views, and architecture docs/diagrams that name P8 ownership.

Boundary:

Repository-local enforcement and architecture source-of-truth updates for P8 seams. No metric-only reshaping, no broad DCM suppression, and no fixture-only data in production registries beyond real guardrail ids.

Change:

Register and implement P8 guardrails for no legacy scene order, no full ordinary spatial clone, stale candidate rejection, fallback budget enforcement, and P8-owned eraser primitive budget-input scope. Keep `core.owner_dag_import_boundaries` as the mandatory import-boundary proof seam for `lib/src/geometry/**`: maintain the `spatial` owner fixture, add a narrow allowed owner edge from `lib/src/runtime/runtime_root.dart` to `lib/src/geometry/spatial_kernel.dart` for runtime composition, reject broad runtime-to-geometry imports outside that edge, extend required forbidden edges if the new geometry owner paths need more coverage, and prove `spatial` imports to `api`, `store`, `runtime`, `frame`, `interaction`, and `surface` all fail with `core.owner_dag_import_boundaries`. Before implementing any eraser guardrail runner behavior, update the guardrail inventory wording so P8-owned enforcement covers only primitive/exact-check budget-input no-partial behavior and explicitly leaves terminal erase cleanup/no-op enforcement to P12. Update architecture graph/docs/diagrams so `geometry.spatial_index` resolves to the implemented `SpatialKernel` owner, runtime composition is represented as a one-way `RuntimeRoot -> SpatialKernel` relationship, and diagrams reflect committed read boundary, typed budget results, and runtime-before-publication delivery order.

Completion Check:

`dart test test/guardrails/geometry_no_legacy_scene_order_guardrail_test.dart`, `dart test test/guardrails/spatial_no_full_clone_ordinary_edit_guardrail_test.dart`, `dart test test/guardrails/spatial_stale_candidate_rejected_guardrail_test.dart`, `dart test test/guardrails/spatial_fallback_budget_enforced_guardrail_test.dart`, and `dart test test/guardrails/geometry_eraser_exact_budget_inputs_guardrail_test.dart` prove each P8-owned guardrail id in `docs/verification/guardrails.md` is registered in `tool/guardrails/src/guardrail_registry.dart`, is runner-backed where structural proof is required, and fails on a fixture containing the forbidden pattern. `dart test test/guardrails/owner_dag_import_boundaries_test.dart` must prove the `spatial` owner maps to `lib/src/geometry/**`, allows only `contracts/public` and `contracts/internal` as dependencies, allows exactly `lib/src/runtime/runtime_root.dart` to import `lib/src/geometry/spatial_kernel.dart` for composition, rejects other runtime-to-geometry fixture imports, and rejects fixture imports/exports from `lib/src/geometry/bad.dart` to `api`, `store`, `runtime`, `frame`, `interaction`, and `surface` with `core.owner_dag_import_boundaries`. The `geometry.eraser_exact_budget_no_partial` proof is acceptable in P8 only if the fixture/check targets primitive or exact-check budget-input no-partial behavior and cannot be mistaken for the P12 terminal erase commit proof. `dart run tool/architecture_graph/check.dart --phase P8` and `dart run tool/architecture_graph/generate_views.dart --phase P8 --check` pass after `SpatialKernel`, runtime composition, and related P8 graph metadata close.

Depends On:

Units 2, 4, and 5.

### [x] Unit 7: Verification Docs And Public Smoke Coverage

Owner:

`PLAN.md`, `plan/step_42_p8_geometry_and_spatial_kernels.md`, `docs/implementation/p8_geometry_and_spatial.md`, `docs/architecture/03_data_model.md`, `docs/contracts/geometry.md`, `docs/contracts/spatial_kernel.md`, `docs/contracts/diagnostics.md` if a concrete corrupted-row diagnostics bridge or counter seam is introduced, `docs/verification/tests.md`, `docs/verification/guardrails.md`, generated docs indexes, durable P8 diagrams, and `test/smoke/public_incremental_smoke_test.dart`.

Boundary:

Durable source-of-truth alignment and coarse public compatibility coverage. Do not create a separate P8 smoke test and do not assert internal spatial candidates, counters, stale handles, or budget result shapes through the public smoke path.

Change:

Update durable docs and diagrams to match implemented P8 owner names, read boundary naming, delivery ordering, invalid/budget result names, guardrail runner coverage, eraser primitive-vs-terminal scope split, and test file mapping. Update `docs/architecture/03_data_model.md` to state the implemented P8 committed handle/facts semantics for `locationKind` and nullable `layerId`, including whether they are handle identity fields validated by `resolveElement` or facts-only fields resolved from the current committed row. Replace the current P8 verification inventory mapping from `test/geometry/eraser_exact_budget_no_partial_commit_test.dart` with `test/geometry/eraser_exact_budget_inputs_test.dart`, or keep the existing file name only if its inventory wording and assertions are narrowed to P8 primitive/exact-check budget inputs and explicitly reserve terminal cleanup/no-op commit proof for P12. Extend the existing public incremental smoke test by appending a geometry-rich public-barrel scenario that decodes/reads background and overlapping transformed content, performs one public geometry-changing edit, and loads a replacement geometry-rich document while asserting only public runtime/document outcomes. After every implementation unit and verification gate is complete, mark Step 42 complete in `PLAN.md` and mark completed unit checkboxes in this step document in the same change.

Completion Check:

`dart test test/smoke/public_incremental_smoke_test.dart` passes while importing only `package:iwb_canvas_engine/iwb_canvas_engine.dart` and asserting only public outcomes. `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` pass from the repository root after all P8 production, test, and tool changes. Focused tests from Units 1 through 6 pass, including `test/spatial/committed_spatial_read_boundary_test.dart`, `test/geometry/geometry_spatial_donor_mapping_test.dart`, `test/geometry/hit_policy_test.dart`, `test/geometry/no_legacy_scene_order_test.dart`, `test/geometry/eraser_exact_budget_inputs_test.dart`, `test/spatial/tile_outlier_membership_test.dart`, `test/spatial/touched_update_test.dart`, `test/spatial/no_full_clone_for_touched_update_test.dart`, `test/spatial/stale_generation_rejected_test.dart`, `test/spatial/fallback_budget_enforced_test.dart`, `test/spatial/invalid_index_fallback_test.dart`, `test/spatial/runtime_delivery_order_test.dart`, and the named P8 guardrail tests from Unit 6. `dart run tool/guardrails/run.dart --suite=blocking` passes and includes the registered P8 guardrail ids in its output. `dart run tool/architecture_graph/check.dart --phase P8` and `dart run tool/architecture_graph/generate_views.dart --phase P8 --check` pass. `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after all P8 source docs, diagrams, verification inventories, and generated indexes are aligned. The final implementation diff marks `PLAN.md` Step 42 checked and marks every completed `### [x] Unit N` checkbox in `plan/step_42_p8_geometry_and_spatial_kernels.md`.

Depends On:

Units 5 and 6.
