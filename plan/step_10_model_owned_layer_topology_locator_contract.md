# Change Contract

## 1. Change Mandate

Make content-layer topology mutation self-contained by moving layer-topology
semantics into the model facade, replacing positional node locators with
stable layer-identity locators plus an `O(L)` layer index companion, and
removing controller-side locator repair.

## 2. Change Boundary

### Included in the Change

- Add one shared stable runtime node-location carrier and use it for
  mutation-time and committed node locators.
- Promote `layerId -> layerIndex` from a lazy transaction-only helper to
  first-class derived state in transaction and committed store paths.
- Split topology-changing layer mutation from topology-preserving layer slot
  replacement used by copy-on-write cloning.
- Migrate model, controller, and core locator consumers to the stable
  layer-identity seam while preserving existing outward `layerIndex` /
  `nodeIndex` outputs.
- Reject duplicate content-layer ids during semantic layer insert and semantic
  layer replacement.
- Align empty-scene layer bootstrap with the same semantic layer-topology
  owner path.
- Extend structural guardrails and repository docs for the new ownership
  contract.

### Not Included in the Change

- Any new public layer reorder, move, or delete API.
- Any order-maintenance key scheme or sub-`O(L)` layer ordering data
  structure.
- Any full spatial-index redesign, render-pipeline redesign, or paint-order
  cache redesign.
- Any public API rename for `SceneWriteTxn`, `SceneStoreController`, or
  committed snapshot resolution contracts.
- Any mutation-gateway, composition-root, or broader store-family refactor
  outside this topology/locator contract.

## 3. Surrounding Code Review

### Inspected Artifacts

- `docs/adr/0001_target_engine_architecture.md` — the accepted target keeps
  `TxnContext` as the copy-on-write workspace and keeps the mutation gateway
  narrow, so layer-topology repair must not move upward into interaction or
  facade owners.
- `docs/target_architecture/overview.md` — the relevant owner family is the
  store/commit path, not the mutation gateway or composition root.
- `docs/target_architecture/execution_flows.md` — write flow stays
  `API -> gateway/write entry -> store -> kernel -> TxnContext`, which fixes
  the repair level below the gateway.
- `docs/target_architecture/families/store_and_commit_path.md` — `TxnContext`
  remains the copy-on-write workspace and its local internal shape is still a
  valid cleanup target.
- `docs/target_architecture/families/mutation_gateway.md` — the gateway
  remains the only interaction-owned committed-write bridge and must not grow
  into a runtime document-topology owner.
- `ARCHITECTURE.md` — model owns document mutation helpers and controller owns
  copy-on-write scene/layer/node carriers plus derived indexes.
- `lib/src/contract/scene_write_txn.dart` — `writeLayerEnsure(...)` is a
  supported public write contract, so semantic tightening is a user-visible
  runtime behavior change.
- `API_GUIDE.md` — the public guide already documents `ensureLayer(...)`,
  which means the implemented semantics must be reflected there.
- `lib/src/model/document_scene_insert.dart` — content-layer insert and
  replace currently mutate `scene.layers` without duplicate-layer guard or
  locator ownership, while `txnInsertNodeInScene(...)` already owns duplicate
  rejection and locator maintenance in the same helper.
- `lib/src/model/document_locator.dart` — node locator entries currently store
  `layerIndex` and expose `txnShiftNodeLocatorLayersFrom(...)` as an external
  repair helper.
- `lib/src/model/document_selection.dart` — selection normalization and
  candidate checks optionally trust the node locator and therefore depend on
  the locator seam staying valid after topology changes.
- `lib/src/controller/txn_derived_state.dart` — transaction derived state
  already has a lazy `Map<LayerId, int>` cache, which is the correct local
  primitive to promote instead of inventing a new ordering subsystem.
- `lib/src/controller/txn_workspace.dart` — `ensureContentLayer(...)`
  currently performs duplicate-layer checking and manual
  `txnShiftNodeLocatorLayersFrom(...)` repair in controller code.
- `lib/src/controller/scene_mutation_applier.dart` — `EnsureLayerOp` enters
  the current layer insert path through `TxnContext.txnEnsureContentLayer(...)`.
- `lib/src/controller/node_mutation_applier.dart` — later same-transaction
  node operations depend on `ctx.txnFindNodeById(...)` staying correct after
  layer topology changes.
- `lib/src/controller/store.dart`,
  `lib/src/controller/committed_store_state.dart`,
  `lib/src/controller/mutation_execution_types.dart`, and
  `lib/src/controller/mutation_commit_preparer.dart` — committed and prepared
  write state currently carry only the positional node locator, not an
  explicit companion layer index.
- `lib/src/controller/scene_store_controller.dart` — committed snapshot
  resolution trusts stored locator entries and must keep returning positional
  outputs after the internal locator seam changes.
- `lib/src/controller/scene_invariants.dart` — committed invariant checks
  currently validate `allNodeIds` and positional `nodeLocator`, but do not
  validate a first-class `layerIndexById` companion map because it does not
  exist yet.
- `lib/src/controller/internal/spatial_index_cache.dart` and
  `lib/src/core/scene_spatial_index.dart` — spatial indexing stores locator
  state for candidate ordering and node re-resolution, so locator shape
  changes reach both controller and core consumers.
- `tool/src/guardrails/rules/model/model_architecture_rules.dart` and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` —
  controller direct `scene.layers` mutation is guarded, but controller use of
  raw topology-repair helpers is not.
- `test/model/document_model_test.dart` — node-level helper behavior is
  strongly locked, but layer-level helpers are covered only for overflow,
  range, and simple replacement behavior.
- `test/controller/internal/change_set_txn_context_test.dart`,
  `test/controller/internal/mutation_executor_test.dart`, and
  `test/controller/internal/scene_writer_test.dart` — transaction and writer
  tests already prove same-txn shifted lookup behavior through controller-side
  repair.
- `test/controller/internal/spatial_index_cache_test.dart` — controller cache
  tests lock incremental/rebuild behavior around carried locator input, which
  must remain correct after the locator seam changes.
- `test/controller/core/scene_controller_commit_atomicity_test.dart` — the
  committed write path already expects layer insertion before delete to work
  without leaving stale nodes behind.
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  — committed snapshot resolution already expects valid post-replace lookup and
  stale-candidate rejection without snapshot-scan fallback.
- `test/controller/scene_invariants_test.dart` — duplicate layer ids are
  currently caught only at committed invariant time.
- `test/core/scene_spatial_index_test.dart` — committed spatial ordering and
  resolution already have targeted coverage that must stay green through the
  locator seam change.

### Current Entry Path

- `SceneWriteTxn.writeLayerEnsure(...)`
- `SceneWriter.writeLayerEnsure(...)`
- `SceneWriterRuntime.execute(const EnsureLayerOp(...))`
- `MutationExecutor.execute(...)`
- `executeStructuralDocumentMutationOp(...)`
- `TxnContext.txnEnsureContentLayer(...)`
- `_TxnWorkspace.ensureContentLayer(...)`
- `txnInsertContentLayerInScene(...)`
- later `ctx.txnFindNodeById(...)`, committed
  `SceneStoreController.resolveSnapshotNodeById(...)`, and
  `SceneSpatialIndex` consume the stored locator

### Current Owner

- The defect is a split owner at the model/controller seam: model helpers own
  `scene.layers` mutation, but controller transaction code owns the repair of
  derived locator and uniqueness state.

### Adjacent Abstractions

- `lib/src/model/document_scene_edit.dart` — node erase helpers already update
  locator state inside the model layer.
- `lib/src/model/document_selection.dart` — selection helper seam that must
  stay aligned with node lookup semantics.
- `lib/src/controller/txn_derived_state.dart` — current transaction-derived
  index carrier.
- `lib/src/controller/store.dart` and
  `lib/src/controller/scene_store_controller.dart` — committed derived-state
  carriers and committed read adapters.
- `lib/src/core/scene_spatial_index.dart` — core consumer that orders and
  re-resolves nodes from the carried locator state.

### Existing Tests

- `test/model/document_model_test.dart` — current direct model helper lock
  surface.
- `test/controller/internal/change_set_txn_context_test.dart` — transaction
  derived-state and copy-on-write behavior.
- `test/controller/internal/mutation_executor_test.dart` — structural mutation
  execution inside one transaction.
- `test/controller/internal/scene_writer_test.dart` — public writer behavior
  around `writeLayerEnsure(...)`.
- `test/controller/internal/scene_write_txn_public_adapter_test.dart` — public
  adapter coverage for `writeLayerEnsure(...)`.
- `test/controller/internal/spatial_index_cache_test.dart` — controller cache
  coverage around carried locator-driven candidate resolution.
- `test/controller/core/scene_controller_commit_atomicity_test.dart` —
  committed write/commit behavior after layer insertion.
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
  — committed locator and stale-candidate resolution behavior.
- `test/controller/scene_invariants_test.dart` — committed scene/index
  invariant enforcement.
- `test/core/scene_spatial_index_test.dart` — spatial candidate ordering and
  resolution.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` —
  controller/model structural guardrail scenarios.

### Analogous Implementation Path

- `lib/src/model/document_scene_insert.dart` —
  `txnInsertNodeInScene(...)` is the closest valid precedent because it
  rejects duplicate ids at mutation time and updates locator state in the same
  model-owned helper instead of delegating repair to controller code.

### Governing Repository Rules

- `AGENTS.md` — fix bugs at the owning layer, avoid sync glue, prefer the
  smallest change that removes the shared weakness, and add mechanical
  enforcement for stable constraints.
- `ARCHITECTURE.md` — model owns document mutation helpers; controller owns
  copy-on-write carriers and committed store state.
- `docs/adr/0001_target_engine_architecture.md` — `TxnContext` remains the
  copy-on-write workspace and the mutation gateway remains a narrow bridge.
- `docs/target_architecture/families/store_and_commit_path.md` — transaction
  workspace cleanup belongs in the store/commit family rather than a new
  architectural family.
- `docs/target_architecture/families/mutation_gateway.md` — no interactive
  owner may absorb committed document-topology repair.
- `tool/invariant_registry.dart` / `INV-G-LAYERID-UNIQUE` — content-layer ids
  must remain unique across content layers.
- `tool/invariant_registry.dart` / `INV-G-LAYER-Z-ORDER-BY-LIST` — content
  layer order remains defined by `scene.layers`.
- `tool/invariant_registry.dart` / `INV-ENG-ID-INDEX-FROM-SCENE` —
  scene-derived ids and locators must match the committed scene.
- `tool/invariant_registry.dart` / `INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER` —
  runtime scene structure mutation remains model-owned and controller must not
  become the structural owner.

### Rejected Misleading Local Patterns

- `lib/src/controller/txn_workspace.dart` manual
  `txnShiftNodeLocatorLayersFrom(...)` repair — wrong owner because it keeps
  topology mutation semantics split between model and controller.
- full node-locator rebuild after every layer topology change — wrong steady
  state because it turns rare but valid layer inserts into `O(totalNodes)`
  repair work.
- mutation-gateway or store-facade repair — wrong level because target
  architecture keeps those owners narrow and above the runtime topology seam.
- keeping `txnReplaceContentLayerInScene(...)` as both a semantic layer
  replacement helper and a topology-preserving copy-on-write slot helper —
  wrong contract because callers cannot tell when derived-state repair is
  required.
- order-maintenance keys or a second ordering subsystem — wrong scope because
  the repository already treats `scene.layers` as the single source of z-order.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The problem belongs to the runtime document-topology mutation contract at the
  model/controller seam, with one shared runtime locator carrier also consumed
  by core spatial indexing.

#### Selected Architectural Form

- Add one shared stable node-location carrier in
  `lib/src/core/scene_node_locator.dart`.
- Stable node-locator entries store `contentLayerId` plus `nodeIndex` for
  content nodes, and use `contentLayerId == null` as the background sentinel.
- `Map<LayerId, int> layerIndexById` becomes the single companion index for
  current content-layer positions in both transaction and committed state.
- Model semantic layer-mutation helpers in `document.dart` /
  `document_scene_insert.dart` accept and update both `nodeLocator` and
  `layerIndexById` atomically.
- Controller `TxnContext`, prepared commit state, and committed store state
  carry these derived structures but do not repair them manually.
- Topology-preserving layer slot replacement for copy-on-write cloning is split
  into a separate low-level model helper and remains the only controller-side
  layer slot mutation seam.
- Committed store and core consumers resolve outward `layerIndex` values only
  at read/output boundaries through `layerIndexById`, so existing public
  positional outputs stay unchanged.

#### Owning Layer or Module

- Shared runtime locator carrier: `lib/src/core/scene_node_locator.dart`
- Semantic topology owner: `lib/src/model/document.dart`,
  `lib/src/model/document_locator.dart`,
  `lib/src/model/document_scene_insert.dart`, and
  `lib/src/model/document_selection.dart`
- Carrier/adaptation owners: `lib/src/controller/txn_context.dart`,
  `lib/src/controller/txn_derived_state.dart`,
  `lib/src/controller/txn_workspace.dart`,
  `lib/src/controller/store.dart`,
  `lib/src/controller/committed_store_state.dart`,
  `lib/src/controller/mutation_execution_types.dart`,
  `lib/src/controller/mutation_commit_preparer.dart`,
  `lib/src/controller/scene_store_controller.dart`,
  `lib/src/controller/scene_invariants.dart`, and
  `lib/src/controller/scene_controller_commit_execution.dart`
- Core read consumer adaptation: `lib/src/core/scene_spatial_index.dart` and
  `lib/src/controller/internal/spatial_index_cache.dart`

#### Dependency Direction

- `core` defines the shared stable node-location carrier.
- `model` depends on the `core` carrier to build, update, and resolve
  document-topology locators.
- `controller` depends on the model facade and carries `nodeLocator` plus
  `layerIndexById` through transaction and committed-state paths.
- `core` spatial indexing and controller committed-read adapters consume the
  carried state and resolve positional outputs through `layerIndexById`; they
  do not call back into controller repair helpers.

#### State and Data Ownership

- `scene.layers` remains the only source of truth for content-layer order.
- `layerIndexById` is a derived accelerator over `scene.layers`, not a second
  ordering source.
- `nodeLocator` becomes stable-layer-identity based and no longer stores the
  current numeric content-layer index.
- `allNodeIds` remains a separate controller-owned derived set and is not
  merged into the locator carrier.
- No second positional node-locator cache is introduced for steady-state
  reads.

#### Entry and Exit Boundaries

- Entry: semantic content-layer insert/bootstrap/replace helpers and any
  model-owned lookup helper that consumes `nodeLocator`.
- Exit: mutation-time node and selection lookup, committed snapshot
  resolution, spatial candidate ordering/resolution, and other existing
  consumers continue to return resolved `layerIndex` / `nodeIndex` outputs
  without rescanning whole scenes or rewriting all node-locator entries after
  layer insertion.

#### Permitted Extension Seam

- Any future topology-changing layer operation must go through a model facade
  helper that accepts current `nodeLocator` plus `layerIndexById`.
- Any future consumer that needs current numeric layer order must resolve it
  from `layerIndexById` rather than storing positional layer indices in the
  node locator.
- A low-level layer slot helper may remain separate only when it preserves
  topology, preserves layer identity, and cannot invalidate derived topology
  state.

#### Rejected Alternatives

- Keep positional node locators and continue controller-side repair — wrong
  owner and same hidden-protocol class.
- Rebuild the full node locator after every layer insert/replace — correct but
  wrong steady-state cost.
- Move topology repair into the mutation gateway or committed store facade —
  wrong layer and contrary to ADR 0001.
- Keep one mixed `txnReplaceContentLayerInScene(...)` contract — ambiguous seam
  that hides whether topology semantics are involved.
- Introduce a new ordering subsystem instead of reusing `scene.layers` plus a
  derived companion map — unnecessary redesign beyond this fix.

#### Why This Level Is Correct

- Repository docs and guardrails already say `scene.layers` mutation is
  model-owned, while target architecture keeps `TxnContext` as a carrier
  workspace rather than a second structural owner.
- Promoting the existing `layerId -> index` primitive into first-class carried
  state gives `O(L)` topology maintenance without turning hot-path lookups into
  scans.
- Stable layer-identity locators fix the shared cause once across model,
  controller, and core consumers instead of patching only one caller path.

## 5. Locked Decisions

1. Stable node-locator entries use `contentLayerId == null` as the background
   sentinel and `contentLayerId != null` for content nodes.
2. `txnFindNodeByLocator(...)` and equivalent committed/core consumers must use
   current `layerIndexById`; hot-path lookup must not fall back to scene or
   snapshot scans when the companion map is available.
3. Promote the current transaction-only layer-id index into first-class carried
   state in `TxnContext`, `SceneStore`, prepared commit state, and committed
   store state.
4. Semantic content-layer insert and semantic layer replacement reject
   duplicate `layerId` at mutation time and update carried topology state in
   one model-owned operation.
5. Split topology-preserving layer slot replacement from semantic layer
   replacement; controller may depend only on the topology-preserving slot
   seam.
6. Retire `txnShiftNodeLocatorLayersFrom(...)` from controller-visible flows
   and tests.
7. Keep outward `layerIndex` / `nodeIndex` outputs unchanged for committed and
   interactive consumers.

## 6. Result Requirements

1. Inserting a content layer before indexed nodes no longer invalidates
   same-transaction node lookup, delete, patch, transform, or selection
   finalization.
2. Duplicate content-layer ids are rejected during semantic layer insert and
   semantic layer replacement instead of relying only on committed invariant
   failure.
3. Empty-scene layer bootstrap and ordinary `writeLayerEnsure(...)` use the
   same model-owned semantic topology path.
4. Committed `resolveSnapshotNodeById(...)`, spatial candidate
   ordering/resolution, and committed invariant checks remain correct while
   consuming stable locator data plus `layerIndexById`.
5. Layer-topology maintenance performs no full-scene node-locator rebuild as
   the steady-state repair path; cost is bounded by `O(L)` layer-index
   maintenance plus local node-index updates only where node membership
   actually changes.
6. Controller code carries topology-derived state but does not repair it.

## 7. Execution Order and Gates

### Required Order

- first add one failing stale-topology reproducer and 1 to 3 neighboring guard
  tests covering duplicate layer ids, one same-txn patch /
  selection-finalization branch, and empty-scene bootstrap while reusing the
  existing delete/transform locking tests as unchanged neighbors
- then introduce the shared stable locator carrier plus first-class
  `layerIndexById`, migrate model lookup/mutation helpers, and remove
  controller-side topology repair from the write path
- then migrate committed store, invariant, and spatial-index consumers to the
  successor seam while preserving outward positional outputs
- then retire raw controller topology-repair access and tighten guardrails
- then align docs and release notes with the implemented public/runtime
  behavior

### Successor Seam and Retirement Gates

- successor seam: stable `contentLayerId`-based node locator plus explicit
  `layerIndexById`
- consumer migration order: model lookup and mutation helpers ->
  transaction-derived carriers -> prepared/committed store carriers ->
  committed snapshot and spatial consumers -> guardrails and docs
- retirement gate: no controller file contains
  `txnShiftNodeLocatorLayersFrom(` or direct calls to topology-changing raw
  layer helpers, and no carried node-locator entry stores numeric content-layer
  index
- proof-retirement gate: tests and guardrails that currently allow controller
  use of `txnReplaceContentLayerInScene(...)` or manual topology repair are
  updated before the old surface is removed

### Deferred Broad Verification

- run the required code-change verification preset only after all slices land
- run tool-guardrail verification only after the guardrail slice lands
- if a new `lib/**` production file such as
  `lib/src/core/scene_node_locator.dart` is added, run `dcm calculate-metrics`
  for that file at the final gate

## 8. File Map

### Implementation Files

- `lib/src/core/scene_node_locator.dart`
- `lib/src/model/document.dart`
- `lib/src/model/document_locator.dart`
- `lib/src/model/document_scene_insert.dart`
- `lib/src/model/document_selection.dart`
- `lib/src/controller/txn_context.dart`
- `lib/src/controller/txn_derived_state.dart`
- `lib/src/controller/txn_workspace.dart`
- `lib/src/controller/scene_writer_nodes.dart`
- `lib/src/controller/selection_state_mutation_applier.dart`
- `lib/src/controller/selection_post_apply_finalizer.dart`
- `lib/src/controller/store.dart`
- `lib/src/controller/committed_store_state.dart`
- `lib/src/controller/mutation_execution_types.dart`
- `lib/src/controller/mutation_commit_preparer.dart`
- `lib/src/controller/scene_controller_commit_execution.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/controller/scene_invariants.dart`
- `lib/src/controller/internal/spatial_index_cache.dart`
- `lib/src/core/scene_spatial_index.dart`
- `tool/src/guardrails/rules/model/model_architecture_rules.dart`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `README.md`
- `CHANGELOG.md`

### Test Files

- `test/model/document_model_test.dart`
- `test/controller/internal/change_set_txn_context_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/internal/scene_write_txn_public_adapter_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/controller/internal/layer_topology_locator_contract_test.dart`
- `test/controller/core/scene_controller_commit_atomicity_test.dart`
- `test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `test/controller/scene_invariants_test.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixtures and Supporting Data

- none

### Registry, Inventory, and Workflow Files

- `PLAN.md`

### Analysis Area

- model/controller/core layer-topology locator boundary and committed resolver
  chain

## 9. Implementation Rules

### Protected Invariants

- `INV-G-LAYERID-UNIQUE`
- `INV-G-LAYER-Z-ORDER-BY-LIST`
- `INV-ENG-ID-INDEX-FROM-SCENE`
- `INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER`

### Required Proof

- behavioral proof:
  - direct semantic layer insert before an indexed node preserves locator-based
    lookup for the moved node
  - same-txn `writeLayerEnsure(...)` before delete or transform continues to
    resolve the shifted node
  - same-txn `writeLayerEnsure(...)` before a visibility or selectability patch
    still resolves the shifted node and preserves selection-finalization
    behavior
  - duplicate layer-id insert or semantic replacement fails at mutation time
  - empty-scene bootstrap creates the first layer without desynchronizing
    carried locator/index state
  - committed `resolveSnapshotNodeById(...)` resolves through stable locator
    data and current `layerIndexById`
  - spatial candidate ordering and node re-resolution remain correct after
    committed layer-topology changes
  - committed invariant checks detect mismatch between scene, stable node
    locator, and `layerIndexById`
- structural proof:
  - source-inspection proof that controller no longer calls
    `txnShiftNodeLocatorLayersFrom(...)`
  - source-inspection proof that stable node-locator entries store layer
    identity rather than numeric content-layer index
  - guardrail proof that controller may use only the topology-preserving slot
    helper, not semantic layer-topology helpers
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- model locator and layer-mutation helpers
- transaction and committed derived-state carriers
- committed snapshot/spatial resolution adapters
- owner-side tests, guardrails, and required docs

### Forbidden Moves

- do not add full-scene node-locator rebuild as the steady-state repair path
  for layer insert or semantic layer replacement
- do not scan `scene.layers` or `snapshot.layers` on hot lookup/resolution
  paths when `layerIndexById` is already available
- do not move layer-topology repair into the mutation gateway, committed store
  facade, or view/render consumers
- do not keep topology-changing and topology-preserving layer replacement
  semantics behind one helper contract
- do not introduce a second source of z-order truth beyond `scene.layers` and
  derived `layerIndexById`

### Optional: Resolution Rules

- background uses `contentLayerId == null` internally and still resolves
  outward as `layerIndex == -1`
- when topology changes but a node stays in the same content layer, update only
  `layerIndexById`; do not rewrite unaffected node-locator entries
- when a content layer changes identity semantically, rewrite only node-locator
  entries that belong to the replaced layer

## 10. Vertical Slices

### Slice 1. [ ] Stable Layer-Identity Locator In The Write Path

#### Slice Contract

Transaction write helpers and model topology helpers use stable layer-identity
locators plus `layerIndexById`, so same-txn layer insertion no longer depends
on controller-side locator repair.

#### Change

- add one failing reproducer for stale locator after layer insertion and up to
  three neighboring guard tests covering duplicate layer ids, one same-txn
  patch / selection-finalization branch, and empty-scene bootstrap while
  keeping the existing delete/transform locking tests in place
- add `lib/src/core/scene_node_locator.dart`
- convert model locator build/resolve helpers and selection helpers to stable
  `contentLayerId`-based entries plus explicit `layerIndexById`
- promote `layerIndexById` into `TxnContext` / `_TxnDerivedState`
- rewrite `txnEnsureContentLayer(...)` / `writeLayerEnsure(...)` to use one
  model-owned semantic layer helper and remove controller-side
  `txnShiftNodeLocatorLayersFrom(...)`
- split topology-preserving layer slot replacement from semantic layer
  replacement and keep copy-on-write layer cloning on the slot seam only

#### Behavioral Verification

- `flutter test test/model/document_model_test.dart`
- `flutter test test/controller/internal/change_set_txn_context_test.dart`
- `flutter test test/controller/internal/mutation_executor_test.dart`
- `flutter test test/controller/internal/scene_writer_test.dart`
- `flutter test test/controller/internal/scene_write_txn_public_adapter_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`

#### Structural Verification

- `flutter test test/controller/internal/layer_topology_locator_contract_test.dart`

#### Fixtures Used

- existing in-memory scene fixtures already used by model, transaction, and
  writer tests

#### Positive Scenarios

- same-txn ensure-layer before delete resolves the moved node correctly
- same-txn ensure-layer before transform resolves the moved node correctly
- same-txn ensure-layer before a visibility/selectability patch finalizes
  shifted selection correctly
- duplicate layer id insert or semantic replacement is rejected before the
  scene is committed
- empty-scene layer bootstrap creates the first layer without stale locator
  state

#### Negative Scenarios

- background lookup still resolves through the background sentinel only
- copy-on-write layer cloning still preserves topology and does not trigger
  semantic duplicate-layer validation

#### Closure Evidence

- failing stale-topology reproducers pass through the model-owned semantic
  helper path
- source inspection proves the controller write path no longer repairs locator
  layer indices manually

### Slice 2. [ ] Committed Resolver And Spatial Consumer Migration

#### Slice Contract

Committed store, spatial index, and invariant consumers use stable locator
entries plus `layerIndexById` while preserving current positional outputs.

#### Change

- extend `SceneStore`, `CommittedStoreState`, `MutationCommitCandidate`, and
  commit execution to carry `layerIndexById`
- adapt committed snapshot resolution and invariant checks to stable locator
  entries plus `layerIndexById`
- adapt `SceneSpatialIndex` and `SpatialIndexCache` to resolve and order nodes
  from the stable locator seam without storing numeric content-layer indices in
  node-locator entries
- add committed-path regressions for snapshot resolution, stale-candidate
  rejection, and spatial ordering after layer-topology changes

#### Behavioral Verification

- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/controller/scene_invariants_test.dart`
- `flutter test test/core/scene_spatial_index_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`

#### Structural Verification

- `flutter test test/controller/internal/layer_topology_locator_contract_test.dart`

#### Fixtures Used

- existing committed snapshot fixtures and spatial query rectangles already used
  by controller/core tests

#### Positive Scenarios

- committed `writeLayerEnsure(...)` before delete leaves no stale node behind
- committed `resolveSnapshotNodeById(...)` returns the correct
  `layerIndex` / `nodeIndex`
- spatial hit-test and paint candidate ordering remain correct after topology
  changes
- committed invariant checks validate `layerIndexById` alongside `nodeLocator`

#### Negative Scenarios

- stale committed candidate resolution still returns `null` rather than falling
  back to a scene or snapshot scan
- background committed resolution still reports `layerIndex == -1`
- no committed consumer depends on a positional node-locator entry shape

#### Closure Evidence

- committed readers remain correct while consuming the stable locator seam
- no per-insert node-locator layer-index rewrite remains in committed or core
  consumers

### Slice 3. [ ] Guardrail And Documentation Alignment

#### Slice Contract

Repository guardrails and docs describe the new topology owner contract and the
public `writeLayerEnsure(...)` semantics consistently.

#### Change

- extend model architecture guardrails and sandbox tests to reject controller
  use of retired topology-repair helpers and semantic layer-topology helpers
  while allowing only the topology-preserving slot helper
- update `API_GUIDE.md` for `writeLayerEnsure(...)` uniqueness and topology
  semantics
- update `ARCHITECTURE.md` for model-owned topology mutation and controller
  carrier-only responsibility
- update `README.md` and `CHANGELOG.md` with concise release-ready notes

#### Behavioral Verification

- `flutter test test/controller/internal/scene_writer_test.dart`
- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`

#### Structural Verification

- `flutter test test/controller/internal/layer_topology_locator_contract_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- docs describe `writeLayerEnsure(...)` and internal topology ownership
  consistently
- guardrails fail when controller code tries to reintroduce retired topology
  repair or semantic layer helper usage

#### Negative Scenarios

- no sandbox case still treats `txnReplaceContentLayerInScene(...)` as the
  allowed controller seam for topology-changing layer behavior
- no doc reintroduces controller-side topology repair or post-commit-only
  layer-id enforcement wording

#### Closure Evidence

- architecture docs, API docs, and release notes match the implemented seam
- guardrail suite fails on the old hidden-protocol patterns

## 11. Final Verification

- create a changed-paths file covering every modified repository-relative path
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<that-file>`
- `flutter test test/model/document_model_test.dart`
- `flutter test test/controller/internal/change_set_txn_context_test.dart`
- `flutter test test/controller/internal/mutation_executor_test.dart`
- `flutter test test/controller/internal/scene_writer_test.dart`
- `flutter test test/controller/internal/scene_write_txn_public_adapter_test.dart`
- `flutter test test/controller/internal/layer_topology_locator_contract_test.dart`
- `flutter test test/controller/internal/spatial_index_cache_test.dart`
- `flutter test test/controller/core/scene_controller_commit_atomicity_test.dart`
- `flutter test test/controller/core/scene_controller_spatial_candidate_resolution_test.dart`
- `flutter test test/controller/scene_invariants_test.dart`
- `flutter test test/core/scene_spatial_index_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- if `lib/src/core/scene_node_locator.dart` is added, run
  `dcm calculate-metrics lib/src/core/scene_node_locator.dart`

## 12. Acceptance Criteria

- content-layer topology mutation is model-owned and self-contained
- controller write and committed-state code no longer performs manual locator
  shift repair
- stable node locators and `layerIndexById` stay aligned in transaction and
  committed state
- same-txn and committed layer-insert scenarios keep node resolution and
  spatial ordering correct
- duplicate layer ids are rejected at mutation time
- guardrails and docs match the implemented topology owner contract
