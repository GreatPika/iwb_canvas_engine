language: english

# Change Contract

Status: completed.

## 1. Change Mandate

Close `KI-5` by making direct model-level scene insertion validate topology
admission from the actual runtime scene and leave derived topology maps fresh
after successful semantic topology mutation.

## 2. Change Boundary

### Included in the Change

- Reproduce stale or incomplete derived locator/index admission failures for
  node id uniqueness, node budget, content-layer id uniqueness, and layer
  ensure behavior.
- Move `txnInsertNodeInScene(...)` duplicate-id and node-budget admission to
  actual `Scene` topology.
- Move `txnInsertContentLayerInScene(...)` and
  `txnEnsureContentLayerInScene(...)` content-layer uniqueness admission to
  actual `Scene.layers` topology.
- Refresh caller-provided derived maps from the actual scene after successful
  semantic topology mutation, and refresh `layerIndexById` when layer ensure
  returns `false` because the scene already contains the layer.
- Add repository-local structural proof that future insert admission cannot use
  caller-provided derived maps as the sole uniqueness or budget source.
- Remove `KI-5` from `KNOWN_ISSUES.md` and update the model topology family
  status in the same implementation change that adds regression proof.
- Add an `Unreleased` changelog entry for the fixed runtime topology admission
  defect.

### Not Included in the Change

- No public API, JSON schema, snapshot shape, or controller capability rename.
- No replacement of `NodeLocatorEntry`, `nodeLocator`, or `layerIndexById`
  carrier shapes.
- No new layer ordering data structure or sub-`O(L)` ordering scheme.
- No migration of topology ownership into controller, interactive, render,
  view, serialization, or contract layers.
- No broad transaction derived-state redesign beyond adopting the corrected
  model helper behavior.
- No direct implementation of active known issues other than `KI-5`.

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` - records `KI-5` as an active `P2` defect: direct
  model-level scene insertion uses stale or incomplete derived locator/index
  state as the sole uniqueness and budget source.
- `ARCHITECTURE.md` - declares that node ids are unique across the full scene,
  content layer ids are unique across content layers, and model helpers own
  semantic content-layer topology mutation while controller code may carry
  `nodeLocator` / `layerIndexById` but must not repair topology manually.
- `docs/ARCHITECTURE_ATLAS.md` - routes architecture questions to the model
  topology family, proof architecture, active known issues, and `PLAN.md`.
- `docs/architecture/families/model_document_mutation_and_topology.md` -
  states that topology invariants are validated by the owner with complete
  scene topology and that derived indexes are not independent truth unless
  freshness is explicit and enforced; it tracks `KI-5` as the remaining
  drift.
- `docs/architecture/families/store_and_commit_path.md` - keeps `TxnContext`
  as the copy-on-write workspace and committed store metadata owner, so the
  fix must not make controller the semantic topology validator.
- `docs/architecture/families/mutation_gateway.md` - keeps public/runtime
  mutation callers routed through `SceneControllerMutationBoundary`, so the
  fix must not move topology admission into the interaction gateway.
- `lib/src/model/document_scene_insert.dart` - current defect owner:
  `txnEnsureContentLayerInScene(...)` returns from
  `layerIndexById.containsKey(layerId)`,
  `txnInsertContentLayerInScene(...)` checks duplicates through the supplied
  layer index, and `txnInsertNodeInScene(...)` checks duplicate node ids and
  node budget through `nodeLocator`.
- `lib/src/model/document_locator.dart` - owns derived locator builders and
  locator entry resolution; it is the correct adjacent abstraction for
  rebuilding derived indexes from scene topology, not for deciding semantic
  admission.
- `lib/src/model/document_clone.dart` - provides `txnCollectNodeIds(...)` and
  `txnCollectLayerIds(...)`; these set helpers prove existing scene-derived
  lookup precedent but are not enough for node-budget counting because sets
  collapse duplicate ids.
- `lib/src/contract/scene_structure_validation.dart` - closest valid
  precedent for topology truth: `sceneValidateSceneStructure(...)` walks
  background nodes and every content layer to enforce node budget and duplicate
  id structure from the actual document shape.
- `lib/src/controller/txn_workspace.dart` - controller layer delegates
  content-layer ensure and slot replacement to model helpers; it should
  continue carrying derived state rather than owning semantic topology checks.
- `lib/src/controller/node_mutation_applier.dart` - node insert route already
  resolves the target layer through `TxnContext`, materializes a mutable scene
  and layer, then calls `txnInsertNodeInScene(...)`; the correct downstream
  owner is already in the model layer.
- `lib/src/controller/txn_derived_state.dart` - derives and materializes
  `nodeLocator` and `layerIndexById` for transactions; it depends on model
  helper correctness and should not gain duplicate topology policy.
- `lib/src/controller/scene_invariants.dart` - committed invariant checks
  rebuild expected node and layer indexes from the scene and compare them to
  carried committed metadata; this is a committed-store backstop, not the
  model insertion admission owner.
- `test/model/document_model_test.dart` - already covers simple duplicate
  node rejection, duplicate layer rejection, insertion reindexing, and node
  overflow before mutation, but all current KI-5-adjacent tests pass fresh
  derived maps.
- `test/controller/internal/layer_topology_locator_contract_test.dart` -
  existing structural proof rejects controller-side topology repair and keeps
  semantic layer topology in the model seam; new proof should preserve this
  direction without moving model behavior into controller tests.
- `tool/src/guardrails/rules/model/model_architecture_rules.dart` and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` -
  current guardrails prevent non-model imports of split model owners and
  controller direct topology mutation, but do not catch the KI-5 admission
  source drift inside `document_scene_insert.dart`.
- `tool/invariant_registry.dart` - links the relevant proof families:
  `INV-G-NODEID-UNIQUE`, `INV-G-LAYERID-UNIQUE`,
  `INV-ENG-ID-INDEX-FROM-SCENE`, and
  `INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER`.
- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/scene_controller_scene.dart SceneControllerSceneOwner.addNode --direction=outgoing --depth=5 --json`
  - confirms public add-node flow reaches
  `SceneControllerMutationBoundary` and then the controller committed-mutation
  access seam; there is no reason to solve KI-5 at the public facade.
- `dart run tool/lsp_find_boundary_bypasses.dart lib/src/interactive/scene_controller_scene.dart SceneControllerSceneOwner --must-pass=SceneControllerMutationBoundary --depth=5`
  - found no public scene-owner bypasses around the mutation boundary.
- `dart run tool/lsp_find_boundary_bypasses.dart lib/src/interactive/scene_controller_selection.dart SceneControllerSelectionOwner --must-pass=SceneControllerMutationBoundary --depth=5`
  - found no selection-owner bypasses around the mutation boundary.
- `dart run tool/lsp_trace_symbol.dart lib/src/model/document_scene_insert.dart txnInsertNodeInScene --direction=both --depth=3 --json`
  - confirms the narrow insert helper owner and outgoing dependence on
  `sceneConsumeNodeBudget(...)` and `txnWriteLayerNodeLocations(...)`.
- `dart run tool/lsp_trace_symbol.dart lib/src/model/document_scene_insert.dart txnInsertContentLayerInScene --direction=both --depth=3 --json`
  - confirms content-layer insert is only exposed through the model facade and
  internal model helper paths.
- `dart run tool/lsp_trace_symbol.dart lib/src/controller/node_mutation_applier.dart _insert --direction=outgoing --depth=4 --json`
  - confirms controller node insertion delegates final scene mutation to
  `txnInsertNodeInScene(...)`.
- `dart run tool/analysis/find_similar_clones.dart --json --top 20 lib/src/model 40 20 5 3 0.55 12`
  - found local duplication signals in validation and decode code, but no
  competing topology admission owner that should replace
  `document_scene_insert.dart`.
- `dcm calculate-metrics lib/src/model/document_scene_insert.dart` - reports
  the existing five-parameter `txnInsertNodeInScene(...)` threshold warning;
  this is an existing signal to keep the fix cohesive and not a reason for a
  metric-only signature split.
- `dart run tool/run_repository_audits.dart`,
  `dart run tool/check_guardrails.dart`,
  `dart run tool/check_invariant_coverage.dart`,
  `dart run tool/check_import_boundaries.dart`, and
  `flutter test --no-pub test/model` - current checks are green and do not
  catch KI-5; the missing proof is model-topology-specific.

### Current Entry Path

- Public add-node route:
  `SceneControllerSceneOwner.addNode(...) -> SceneControllerMutationBoundary.addNode(...) -> SceneControllerCommittedMutationAccess.addNode(...) -> controller write path -> node mutation applier -> txnInsertNodeInScene(...)`.
- Internal transaction node insert route:
  `_insert(...)` in `node_mutation_applier.dart` resolves the target layer,
  materializes a mutable scene/layer, passes a mutable `nodeLocator`, then
  calls `txnInsertNodeInScene(...)`.
- Content-layer ensure route:
  `TxnContext.txnEnsureContentLayer(...) -> _TxnWorkspace.ensureContentLayer(...) -> txnEnsureContentLayerInScene(...) -> txnInsertContentLayerInScene(...)`.
- Direct model helper route:
  tests and internal model users can call `txnInsertNodeInScene(...)`,
  `txnEnsureContentLayerInScene(...)`, and
  `txnInsertContentLayerInScene(...)` through `lib/src/model/document.dart`.

### Current Owner

- `lib/src/model/document_scene_insert.dart` owns semantic runtime scene
  insertion and content-layer topology mutation.
- `lib/src/model/document_locator.dart` owns building and resolving derived
  locator/index state.
- `lib/src/controller/txn_derived_state.dart` owns transaction-local derived
  state materialization and commit projection.
- `lib/src/controller/scene_invariants.dart` owns committed-store invariant
  backstops after a commit candidate exists.

### Adjacent Abstractions

- `sceneValidateSceneStructure(...)` in
  `lib/src/contract/scene_structure_validation.dart` - actual-topology
  validation precedent for node budget and duplicate ids.
- `txnBuildNodeLocator(...)` and `txnBuildLayerIndexById(...)` in
  `lib/src/model/document_locator.dart` - accepted derived-index builders from
  runtime scene topology.
- `txnFindNodeById(...)` and `txnFindContentLayerIndexById(...)` - accepted
  actual-scene lookup helpers in the model layer.
- `txnReplaceContentLayerSlotInScene(...)` - topology-preserving copy-on-write
  slot replacement, intentionally not semantic topology admission.

### Existing Tests

- `test/model/document_model_test.dart` - model behavior proof for document
  clone, patch, selection, insert, erase, layer insertion, duplicate rejection,
  and overflow behavior.
- `test/controller/internal/layer_topology_locator_contract_test.dart` -
  structural proof that controller does not repair topology locators manually
  and that semantic layer topology remains model-owned.
- `test/controller/scene_invariants_test.dart` - committed-store invariant
  proof that `allNodeIds`, `nodeLocator`, and `layerIndexById` match the
  committed scene.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` -
  guardrail proof for model owner imports and controller topology mutation
  restrictions.

### Analogous Implementation Path

- `sceneValidateSceneStructure(...)` is the closest valid precedent: it walks
  the actual scene-shaped topology to enforce content-layer count, node
  budget, duplicate layer ids, and duplicate node ids rather than trusting a
  derived index.
- `debugAssertTxnStoreInvariants(...)` through
  `scene_invariants.dart` is the closest committed-store metadata precedent:
  derived indexes are checked by rebuilding from scene topology.

### Governing Repository Rules

- `AGENTS.md` - fix root causes at the shared owning layer instead of patching
  one call site.
- `AGENTS.md` - prefer a single source of truth; if the same state exists in
  multiple places, consolidate or make the invariant mechanically enforced.
- `AGENTS.md` - use repository-local mechanical enforcement for stable
  constraints rather than repeated prose reminders.
- `AGENTS.md` - metrics thresholds are signals, not goals; do not split
  functions or parameters solely to satisfy a threshold.
- `ARCHITECTURE.md` - node ids are unique across the full scene and content
  layer ids are unique across content layers.
- `ARCHITECTURE.md` - model helpers own semantic content-layer topology
  mutation; controller code may carry `nodeLocator` / `layerIndexById`, but it
  must not repair topology manually.
- `docs/architecture/families/model_document_mutation_and_topology.md` -
  topology invariants are validated by the owner that has complete scene
  topology, and derived indexes are not independent truth unless freshness is
  explicit and enforced.
- `KNOWN_ISSUES.md` - active known issues are removed only in the same change
  that fixes them and adds regression proof.

### Rejected Misleading Local Patterns

- Checking `ctx.txnHasNodeId(...)` in `node_mutation_applier.dart` - useful
  fast public insert admission, but it is controller-local and cannot protect
  direct model helper calls with stale maps.
- Relying on `scene_invariants.dart` to catch stale committed metadata later -
  too late for KI-5 because the model helper can already admit invalid
  topology before commit planning.
- Requiring every caller to prove map freshness before calling model insert
  helpers - wrong level because the model helper is the owner with complete
  scene topology and direct callers can still pass stale maps.
- Keeping incremental locator repair after successful insert without a
  freshness gate - incomplete because an incomplete input map remains
  incomplete after mutation.
- Adding a new wrapper around `nodeLocator` / `layerIndexById` solely for this
  fix - too broad for KI-5 and unnecessary while the scene can be used as the
  single admission source.
- Moving duplicate/budget checks into controller or interactive entrypoints -
  wrong owner and leaves direct model-level insertion vulnerable.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Model-layer runtime document topology mutation.

#### Selected Architectural Form

- Direct model insert helpers must use actual `Scene` topology as the
  admission source for uniqueness and budget decisions.
- Caller-provided derived maps remain companion indexes for lookup and commit
  metadata, but successful semantic topology mutation must refresh those maps
  from the actual scene rather than incrementally updating a potentially stale
  input.

#### Owning Layer or Module

- Primary owner: `lib/src/model/document_scene_insert.dart`.
- Adjacent derived-index builder owner:
  `lib/src/model/document_locator.dart`.
- Proof owner: `test/model/**`, with existing controller/guardrail checks
  reused only for boundary confirmation.

#### Dependency Direction

- `model` may depend on `contract` and `core`.
- `controller` continues to depend on `model` for semantic topology mutation.
- No dependency may be introduced from `model` upward into `controller`,
  `interactive`, `render`, `view`, or `serialization`.

#### State and Data Ownership

- `Scene.layers`, `Scene.backgroundLayer`, and layer node lists are the source
  of truth for insertion admission.
- `nodeLocator` and `layerIndexById` are derived companion state.
- On successful `txnInsertNodeInScene(...)`, the supplied `nodeLocator` must be
  refreshed to `txnBuildNodeLocator(scene)` after the scene mutation.
- On successful `txnInsertContentLayerInScene(...)`, the supplied
  `layerIndexById`, when present, must be refreshed to
  `txnBuildLayerIndexById(scene)` after the scene mutation.
- On `txnEnsureContentLayerInScene(...)` returning `false` because the scene
  already contains the layer id, the supplied `layerIndexById` must be
  refreshed to `txnBuildLayerIndexById(scene)`.
- Failed admission must not mutate scene topology. It does not need to repair
  caller-provided derived maps.

#### Entry and Exit Boundaries

- Entry boundaries are the model facade functions in
  `lib/src/model/document.dart` and their owning implementations in
  `document_scene_insert.dart`.
- Exit boundary after successful mutation is a scene whose topology is valid
  for the inserted item and a caller-provided derived map refreshed from that
  scene.
- Error boundary preserves existing error families where possible:
  duplicate node insert remains a `StateError`, duplicate layer insert remains
  `SceneDataException.duplicateLayerId(...)`, range failures remain
  `RangeError`, and budget overflow remains `SceneDataException.maxNodes(...)`
  through `sceneConsumeNodeBudget(...)`.

#### Permitted Extension Seam

- Private helpers may be added in `document_scene_insert.dart` to count nodes,
  detect actual duplicate node/layer ids, and refresh provided maps.
- Existing builders in `document_locator.dart` may be reused directly.
- A model-owned structural test may inspect `document_scene_insert.dart` source
  for forbidden admission forms if behavioral tests alone would not make the
  architecture drift mechanically visible.

#### Rejected Alternatives

- Enforce freshness preconditions on every caller before using derived maps -
  rejected because proving freshness costs the same topology walk while keeping
  the wrong admission source.
- Patch only controller `TxnContext` or `node_mutation_applier.dart` -
  rejected because direct model helper calls remain vulnerable.
- Keep incremental map update after successful insert - rejected because stale
  or incomplete input maps can remain stale after the helper returns.
- Introduce new typed fresh-index wrappers for all locators - rejected as a
  broader transaction API redesign not needed to close KI-5.
- Run full runtime scene validation after every insert - rejected as too broad
  for the defect; the required checks are topology uniqueness, budget, range,
  and derived-map freshness.

#### Why This Level Is Correct

- `document_scene_insert.dart` is the lowest shared owner that sees both the
  actual mutable scene and the derived maps passed by callers.
- Fixing there closes direct model helper calls and all controller routes that
  delegate to those helpers without duplicating topology policy upstream.
- The selected form matches the architecture rule that scene topology is the
  source of truth and derived indexes are companion metadata, not independent
  truth.

### 4B. Architecture Decision Gate

Not used. The architectural form is locked in 4A.

## 5. Locked Decisions

1. `txnInsertNodeInScene(...)` must scan actual scene topology before mutating
   to determine duplicate id presence and current total node count.
2. Node count for budget admission must count nodes, not unique ids, so set
   helpers such as `txnCollectNodeIds(...)` are not sufficient for budget
   enforcement.
3. `txnInsertContentLayerInScene(...)` and
   `txnEnsureContentLayerInScene(...)` must determine existing layer ids from
   `scene.layers`.
4. Successful semantic insertion refreshes the provided derived map from the
   whole scene, trading a bounded `O(N)` or `O(L)` rebuild on insert success
   for correctness against stale or incomplete maps.
5. Existing public signatures remain unchanged; no public migration is part of
   this step.
6. Existing DCM parameter-count warning on `txnInsertNodeInScene(...)` must not
   drive a signature split unless implementation discovers a genuine cohesion
   improvement.

## 6. Result Requirements

1. A stale or incomplete `nodeLocator` cannot allow insertion of a node whose
   id already exists anywhere in background or content layers.
2. A stale or incomplete `nodeLocator` cannot undercount scene node budget.
3. A stale or incomplete `layerIndexById` cannot allow insertion of a content
   layer whose id already exists in `scene.layers`.
4. `txnEnsureContentLayerInScene(...)` returns `false` without inserting when
   `scene.layers` already contains the requested layer id, even if
   `layerIndexById` is missing that id.
5. After successful node insertion, the caller-provided `nodeLocator` matches
   `txnBuildNodeLocator(scene)`.
6. After successful content-layer insertion or ensure no-op on an existing
   layer, the caller-provided `layerIndexById` matches
   `txnBuildLayerIndexById(scene)`.
7. Existing range, duplicate, budget, copy-on-write, committed invariant, and
   mutation-boundary behavior remains compatible with current tests.

## 7. Execution Order and Gates

### Required Order

- First add failing model-level reproducer and neighboring guard tests for
  KI-5 in `test/model/document_model_test.dart`.
- Add structural proof that future model insert admission cannot use derived
  maps as the sole uniqueness or budget source.
- Run the targeted model tests and confirm the KI-5 reproducer fails before
  implementation changes.
- Apply the minimal owner-side fix in `document_scene_insert.dart`.
- Re-run targeted model tests and structural proof until green.
- Remove `KI-5` from `KNOWN_ISSUES.md`, update the model topology family
  status, and add the required `CHANGELOG.md` `Unreleased` entry for the
  fixed runtime topology admission defect.
- Run final required-code-change verification after all files are updated.

### Successor Seam and Retirement Gates

- Successor seam: actual scene topology inside `document_scene_insert.dart` is
  the insertion admission source; derived maps are refreshed companion indexes.
- Retirement gate: `KNOWN_ISSUES.md` may remove `KI-5` only after behavioral
  reproducer, guard tests, structural proof, and targeted model tests pass.
- No shared support file or public API seam is retired in this step.

### Deferred Broad Verification

- Full required-code-change preset is reserved for final verification after
  code, tests, known-issue cleanup, and architecture-family status are updated.
- Direct `dart test` remains forbidden; use repository verification wrappers
  and `flutter test --no-pub test/model` for targeted model proof.

## 8. File Map

### Implementation Files

- `lib/src/model/document_scene_insert.dart`

### Test Files

- `test/model/document_model_test.dart`
- `test/model/document_scene_insert_contract_test.dart`

### Fixtures and Supporting Data

- None.

### Registry, Inventory, and Workflow Files

- `KNOWN_ISSUES.md`
- `docs/architecture/families/model_document_mutation_and_topology.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_34_scene_topology_admission_source.md`

### Analysis Area

- Model topology insertion admission and derived-index freshness.

## 9. Implementation Rules

### Protected Invariants

- `INV-G-NODEID-UNIQUE`
- `INV-G-LAYERID-UNIQUE`
- `INV-ENG-ID-INDEX-FROM-SCENE`
- `INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER`
- `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY`

### Required Proof

- behavioral proof: model tests must reproduce stale/incomplete derived-map
  failures and verify corrected duplicate, budget, layer ensure, and
  successful-refresh behavior.
- structural proof: a model-owned contract test must make it mechanically
  visible if the admission paths in `document_scene_insert.dart` reintroduce
  `nodeLocator.containsKey(...)`, `nodeLocator.length`, or
  `layerIndexById.containsKey(...)` as uniqueness or budget sources; the check
  must be scoped so legal refresh/output use of `nodeLocator` and
  `layerIndexById` remains allowed outside admission.
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract.
- for refactors: not applicable; this step is a bug fix for `KI-5`.

### Allowed Change Surface

- Add private helper functions in `document_scene_insert.dart` for actual
  topology scans and derived-map refresh.
- Reuse `locator.txnBuildNodeLocator(scene)`,
  `locator.txnBuildLayerIndexById(scene)`, and existing scene structure
  validation exceptions.
- Add model tests and source-level structural contract tests.
- Update known-issue and architecture-family source-of-truth documents after
  proof passes.

### Forbidden Moves

- Do not move semantic topology admission into controller, interactive, view,
  render, serialization, or contract owners.
- Do not change public API signatures or JSON/snapshot schemas.
- Do not rely on `txnCollectNodeIds(scene).length` for budget admission.
- Do not add background synchronizers or a second source of truth for topology.
- Do not split `txnInsertNodeInScene(...)` only to satisfy the existing
  parameter-count metric warning.
- Do not remove `KI-5` before the regression proof is green.

### Optional: Recognition Forms That Must Be Supported

- A stale or incomplete map may omit existing scene ids.
- A stale or incomplete map may contain some valid entries while missing other
  background or content-layer entries.
- A successful helper call may receive a map that was stale before the call;
  after the call it must match the scene-derived builder output for the map
  type it owns.

### Optional: Allowed Forms That Are Not Violations

- `nodeLocator` remains allowed for locator refresh output and downstream
  lookup helpers outside admission.
- `layerIndexById` remains allowed for derived-map refresh output and
  downstream lookup helpers outside admission.
- `locator.txnBuildNodeLocator(scene)` and
  `locator.txnBuildLayerIndexById(scene)` remain allowed because they derive
  maps from the actual scene.

### Optional: Resolution Rules

- When scene topology and derived map disagree during insertion admission,
  scene topology wins.
- When a semantic insert succeeds, refresh the affected derived map from the
  entire scene instead of incrementally repairing from the stale input.
- When admission fails, preserve the no-topology-mutation behavior; derived-map
  repair on failure is not required.

## 10. Vertical Slices

### Slice 1. [x] Close KI-5 With Scene-Owned Admission

#### Slice Contract

Close the KI-5 defect class at the model topology owner: stale or incomplete
derived maps cannot admit duplicate ids or undercount budget, and successful
semantic topology mutation returns fresh derived companion maps.

#### Change

- Add failing reproducer and guard tests in `test/model/document_model_test.dart`:
  stale/incomplete `nodeLocator` cannot admit duplicate node id, stale/
  incomplete `nodeLocator` cannot undercount node budget, stale/incomplete
  `layerIndexById` cannot admit duplicate layer id, and
  `txnEnsureContentLayerInScene(...)` no-ops from actual scene topology when
  the map is missing an existing layer.
- Add success-path map freshness assertions for node insertion, content-layer
  insertion, and content-layer ensure no-op.
- Add `test/model/document_scene_insert_contract_test.dart` with invariant
  markers and source-level structural checks for forbidden derived-map
  admission forms.
- Update `lib/src/model/document_scene_insert.dart` only enough to make those
  tests pass.
- Remove `KI-5` from `KNOWN_ISSUES.md` and update
  `docs/architecture/families/model_document_mutation_and_topology.md` from
  `known issue` to the appropriate locked status after proof is green.
- Add a `CHANGELOG.md` `Unreleased` entry for the fixed runtime topology
  admission defect.
- Mark this slice and the Step 34 `PLAN.md` entry complete only after
  implementation and proof are complete.

#### Behavioral Verification

- First, before implementation changes:
  `flutter test --no-pub test/model/document_model_test.dart`
  must fail on the KI-5 stale/incomplete derived-map reproducer.
- After implementation:
  `flutter test --no-pub test/model/document_model_test.dart`
  must pass.
- After implementation:
  `flutter test --no-pub test/model` must pass.

#### Structural Verification

- `flutter test --no-pub test/model/document_scene_insert_contract_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_import_boundaries.dart`

#### Fixtures Used

- None.

#### Positive Scenarios

- Fresh-map insertion behavior remains compatible with existing tests.
- Successful node insertion refreshes `nodeLocator` to the scene-derived
  locator.
- Successful content-layer insertion refreshes `layerIndexById` to the
  scene-derived layer index.
- Existing-layer ensure returns `false` and refreshes `layerIndexById` when
  the scene already contains the requested layer.

#### Negative Scenarios

- Incomplete `nodeLocator` missing an existing node id does not allow duplicate
  node insertion.
- Incomplete `nodeLocator` missing existing nodes does not bypass
  `kMaxNodesPerScene`.
- Incomplete `layerIndexById` missing an existing layer id does not allow
  duplicate layer insertion.
- Source-level structural proof fails if the model insert helper returns to
  derived-map-only admission.

#### Closure Evidence

- `KI-5` is absent from `KNOWN_ISSUES.md`.
- Model topology family status no longer tracks `KI-5` as active drift.
- Required model behavioral and structural tests pass.

## 11. Final Verification

- `dart format --set-exit-if-changed lib/src/model/document_scene_insert.dart test/model/document_model_test.dart test/model/document_scene_insert_contract_test.dart`
- `dcm calculate-metrics lib/src/model/document_scene_insert.dart`
- `flutter test --no-pub test/model`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

## 12. Acceptance Criteria

- `KI-5` can no longer be reproduced through direct model-level insertion with
  stale or incomplete derived maps.
- Actual scene topology is the insertion admission source for node uniqueness,
  node budget, and content-layer uniqueness.
- Caller-provided derived maps are fresh after successful semantic topology
  mutation or ensure no-op on an existing layer.
- Structural proof makes future derived-map-only insertion admission drift
  mechanically visible.
- `KNOWN_ISSUES.md`, the model topology family document, and `CHANGELOG.md`
  state match the implemented and verified behavior.
- `PLAN.md` and this step document mark Step 34 complete only after the
  implementation proof has passed.
- Final verification commands required by this contract pass, or any
  environment-specific inability to run them is reported with exact command
  output and impacted risk.
