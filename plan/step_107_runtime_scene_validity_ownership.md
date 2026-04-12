language: english

# Change Contract

## 1. Change Mandate
This change seals runtime scene validity so structural scene limits and
constrained runtime node fields are enforced by canonical owners before commit,
and any remaining bypass on the pending runtime scene surface is rejected by
one canonical pre-commit validation backstop before the committed store is
updated.

## 2. Change Boundary

### Included in the Change
- Runtime enforcement of `kMaxContentLayersPerScene` and
  `kMaxNodesPerScene` on content-layer creation and node insertion paths.
- Pre-commit rejection of invalid runtime scenes in the committed-store
  invariant gate.
- Eager runtime validation for constrained mutable fields on runtime node
  owners and text layout state.
- Repository-local invariant, guardrail, and documentation updates that pin
  the new runtime validity contract.

### Not Included in the Change
- JSON schema version changes, payload-shape changes, or public field renames.
- New node types, rendering features, or interaction workflow changes.
- Removal of defensive render, hit-test, text-layout, or path-build crash
  safety fallbacks when those fallbacks are acting on foreign or test-bypassed
  invalid state.
- Broad refactors outside the listed runtime validity owners and proof
  surfaces.

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/contract/scene_structure_validation.dart`
- `lib/src/contract/runtime_node_value_validation.dart`
- `lib/src/controller/txn_workspace.dart`
- `lib/src/controller/scene_invariants.dart`
- `lib/src/core/scene_node.dart`
- `lib/src/core/box_nodes.dart`
- `lib/src/core/vector_nodes.dart`
- `lib/src/core/path_node.dart`
- `lib/src/core/text_node_layout_state.dart`
- `lib/src/model/document_scene_insert.dart`
- `tool/invariant_registry.dart`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`
- `tool/src/guardrails/guardrails_runner.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/internal/change_set_txn_context_test.dart`
- `test/controller/scene_invariants_test.dart`
- `test/core/nodes_test.dart`
- `test/model/document_model_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Analysis Area
- `lib/src/contract/scene_structure_validation.dart`
- `lib/src/controller/scene_invariants.dart`
- `lib/src/controller/txn_workspace.dart`
- `lib/src/core/{scene_node,box_nodes,vector_nodes,path_node,text_node_layout_state}.dart`
- `lib/src/model/document_scene_insert.dart`
- `lib/src/model/scene_value_validation*.dart`
- `lib/src/contract/runtime_node_value_validation.dart`
- `lib/src/contract/internal/node_boundary_schema.dart`
- `tool/src/guardrails/*.dart`
- `test/controller/**/*.dart`
- `test/core/nodes_test.dart`
- `test/model/document_model_test.dart`
- `tool/{check_guardrails.dart,invariant_registry.dart}`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified invariant entry must be tied to a concrete proof
  surface.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step must not introduce a third validation contract. Field-local
   eager runtime validation reuses the canonical helpers exported through
   `lib/src/contract/runtime_node_value_validation.dart`, while the
   pre-commit backstop reuses the canonical runtime graph validators under
   `lib/src/model/scene_value_validation*.dart` together with
   `lib/src/contract/scene_structure_validation.dart`.
2. Structural scene-limit ownership belongs to model mutation owners.
   Controller transaction workspace code must not continue to own independent
   content-layer or node-budget logic.
3. The pre-commit backstop validates the runtime scene directly. It must not
   route runtime commit validation through snapshot export, import-draft
   reconstruction, or `ScenePolicy.validateRuntimeScene(...)`.
4. The existing committed-store invariant gate in
   `lib/src/controller/scene_invariants.dart` remains the owner that blocks
   invalid runtime scenes before `_applyCommittedStore(...)` runs.
5. Critical pre-commit validation in release builds must remain change-scoped
   for ordinary tracked commits. Full-scene runtime validation is allowed only
   when the document is replaced or in the existing debug/profile full
   invariant sweep.
6. Constrained mutable runtime node fields must not remain as bare public
   mutable storage after this step. They must mutate through validated
   setters or dedicated owner methods.
7. `StrokeNode.replacePoints(...)` remains the sole owner of stroke point-list
   mutation; this step must not add a raw mutable points setter.
8. Defensive sanitization in rendering, hit-testing, text layout, and
   `PathNode.buildLocalPath()` remains fallback behavior for foreign or
   deliberately bypassed invalid state; it does not define the validity of
   ordinary committed runtime scenes.
9. Public documentation and changelog updates ship in the same change as the
   runtime validity enforcement changes.

## 5. Result Requirements

1. No ordinary runtime mutation path can create a scene whose content-layer
   count exceeds `kMaxContentLayersPerScene` or whose total node count exceeds
   `kMaxNodesPerScene` and still reach the committed store.
2. The committed-store precheck reuses the canonical runtime validators on the
   changed runtime scene surface and rejects any commit candidate whose
   changed metadata, structure, or constrained node fields violate the runtime
   scene validation contract before store apply; `debug` and `profile` still
   run the full committed-store sweep.
3. Ordinary runtime writes to the constrained fields listed in this contract
   fail fast at the owner boundary instead of relying on later render/layout
   sanitization or snapshot/export rejection.
4. Repository-local invariants and guardrails mechanically prevent
   reintroduction of controller-owned structural budget logic and bare public
   constrained mutable fields on runtime node owners.
5. `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md`
   describe one consistent runtime validity contract: eager owner validation
   for constrained writes, one pre-commit backstop for bypasses, and boundary
   validation as a separate outer layer.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Reuse the existing structural limit owner in
  `lib/src/contract/scene_structure_validation.dart` instead of duplicating
  layer/node budget comparisons in controller and model code.
- Reuse the existing runtime graph validators in
  `lib/src/model/scene_value_validation*.dart` instead of creating a second
  runtime-scene traversal contract.
- Reuse the existing field-level validators exported through
  `lib/src/contract/runtime_node_value_validation.dart` instead of
  reimplementing numeric/string/transform validation directly inside core
  node owners.
- Keep the controller commit hook in the existing invariant gate path; do not
  add a second commit-time validation hook elsewhere in the controller stack.

### 6.2 Target Verification Units
- Runtime scene mutation regressions in `test/model/document_model_test.dart`
  and `test/controller/internal/change_set_txn_context_test.dart`.
- Pre-commit rejection regressions in
  `test/controller/scene_invariants_test.dart` and
  `test/controller/core/scene_controller_commit_failures_test.dart`.
- Runtime node owner fail-fast semantics in `test/core/nodes_test.dart` and
  `test/model/document_model_test.dart`.
- Guardrail enforcement in
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`.
- Final repository verification through the canonical command required by
  `AGENTS.md` for code changes.

### 6.3 Protected States, Data, or Structures
- Public snapshot/JSON field names and public `SceneDataException` contract.
- Existing scene contract limits and their diagnostic templates.
- Existing controller write protocol, copy-on-write behavior, and atomic
  commit flow.
- Existing render/hit-test/text-layout/path-build fallback behavior for raw
  invalid states that are constructed only through deliberate test bypasses or
  foreign input.

### 6.4 Allowed Semantic Change Zones
- Structural preconditions for content-layer creation and node insertion.
- Runtime committed-scene invariant collection and rejection behavior.
- Runtime node-owner mutation semantics for constrained fields.
- Repository-local invariants, guardrails, and published runtime-contract
  documentation.

### 6.5 Recognition Forms That Must Be Supported Within This Change
- Empty-scene insertion that materializes the first content layer.
- Explicit `EnsureLayerOp` insertion into the middle of the content-layer list.
- `InsertNodeOp` insertion when the scene is already at the node budget limit.
- Direct runtime assignment to constrained node fields on ordinary runtime
  owners.
- Patch-based mutation that reaches the same constrained node fields through
  `txnApplyNodePatch(...)`.
- Deliberately bypassed invalid runtime state used only to prove the
  pre-commit backstop and defensive fallback paths.

### 6.6 Allowed Forms That Do Not Count as Violations
- Private backing fields plus validated getters/setters on runtime node owners.
- Dedicated owner methods such as `StrokeNode.replacePoints(...)`.
- Direct mutable storage for runtime fields that are not covered by an
  existing repository-local validity contract, including visibility,
  selectability, lock-state, deletability, transformability, colors, and
  `PathFillRule`.
- Tests that construct intentionally corrupted runtime owners or subclasses
  solely to verify the pre-commit backstop or crash-safety fallback behavior.

### 6.8 Prohibited
- Do not duplicate content-layer or node-budget logic in both
  `txn_workspace.dart` and `document_scene_insert.dart`.
- Do not validate runtime commit candidates by exporting snapshots or
  round-tripping through import policy.
- Do not add a second field-validation ruleset in `core/**`; owner writes must
  reuse the canonical contract validators.
- Do not leave any of the following fields as bare public mutable storage
  after touching their owners in this step:
  `transform`, `hitPadding`, `imageId`, `size`, `naturalSize`, `text`,
  `fontSize`, `fontFamily`, `maxWidth`, `lineHeight`, `start`, `end`,
  `thickness`, `strokeWidth`, `svgPathData`.
- Do not weaken or remove existing defensive fallback behavior only to make
  runtime invariant tests pass.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. The step must not be marked complete until both eager owner validation and
   the pre-commit backstop are closed; either one alone is insufficient.
7. Any slice that changes core node-owner mutation semantics must keep patch
   application paths on the same owner surface instead of adding patch-local
   validation branches.
8. Any slice that changes proof tooling must update
   `tool/invariant_registry.dart` in the same change where the proof surface
   is introduced.
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered
    valid.

## 8. Vertical Slices

### Slice 1. [x] Centralize runtime structural scene budgets

#### Slice Contract
All content-layer creation and node insertion paths enforce scene layer/node
budgets through one model-owned structural contract before mutation is applied.

#### Change
- Extend `lib/src/contract/scene_structure_validation.dart` with runtime-usable
  precondition helpers for adding one content layer and one scene node while
  preserving the existing limit constants and `SceneDataException` templates.
- Route `txnResolveInsertLayerIndex(...)` and `txnInsertNodeInScene(...)` in
  `lib/src/model/document_scene_insert.dart` through those helpers, using
  `scene.layers.length` and `nodeLocator.length` as the authoritative O(1)
  runtime counts.
- Remove direct controller-owned content-layer creation from
  `lib/src/controller/txn_workspace.dart` by delegating content-layer
  materialization to model-owned insert helpers instead of calling
  `scene.layers.add(...)` or `scene.layers.insert(...)` directly in the
  workspace layer.
- Update `test/model/document_model_test.dart` and
  `test/controller/internal/change_set_txn_context_test.dart` so they prove
  early failure for layer-budget and node-budget overflow in the runtime
  mutation path, not only on export/snapshot boundaries.

#### Verification
- `flutter test test/model/document_model_test.dart`
- `flutter test test/controller/internal/change_set_txn_context_test.dart`

#### Positive Scenarios
- Inserting the first node into an empty scene creates the first content layer
  only when the layer budget permits it.
- Inserting a node into a non-full scene succeeds without changing existing
  locator semantics.
- Ensuring a content layer below the layer budget succeeds at the requested
  position and preserves layer-index reindexing behavior.

#### Negative Scenarios
- Creating a content layer when the scene is already at
  `kMaxContentLayersPerScene` fails before the layer list is mutated.
- Inserting a node when the scene is already at `kMaxNodesPerScene` fails
  before the target layer is mutated.
- Controller transaction workspace code must not keep a second independent
  budget check or unchecked direct layer insertion path.

#### Closure Evidence
- Green run of the listed verifications.
- Regression tests proving that runtime overflow now fails on mutation rather
  than only on export.

### Slice 2. [x] Add a canonical pre-commit runtime validation backstop

#### Slice Contract
The committed-store invariant gate rejects invalid runtime commit candidates
before the store is updated, reusing canonical runtime graph validation on the
changed scene surface for ordinary tracked commits and whole-scene validation
for document replacement instead of snapshot roundtrips.

#### Change
- Extend `lib/src/controller/scene_invariants.dart` so committed-scene
  validation reuses the canonical runtime graph validators from
  `lib/src/model/scene_value_validation*.dart` for scene metadata and node
  fields, and reuses `sceneValidateSceneStructure(...)` for duplicate ids and
  scene-wide layer/node budgets.
- If the existing duplicate-id invariant helpers are kept alongside
  `sceneValidateSceneStructure(...)`, the committed-scene collector must not
  emit duplicate duplicate-id violation entries for one underlying defect.
- Keep the owner site in the existing pre-commit invariant gate path used by
  `lib/src/controller/scene_controller_commit_execution.dart`; do not add a
  second commit-time rejection seam.
- Keep the critical release-path check change-scoped for ordinary tracked
  commits. Whole-scene runtime validation is allowed only when the document is
  replaced, while the existing full committed-store sweep remains in
  `debug`/`profile`.
- Preserve the existing index, selection, revision, and controller metadata
  invariant checks in `scene_invariants.dart`; this slice adds the canonical
  runtime-scene backstop instead of replacing unrelated invariant families.
- Update `test/controller/scene_invariants_test.dart` and
  `test/controller/core/scene_controller_commit_failures_test.dart` to prove
  that deliberately corrupted runtime scenes fail before the committed store is
  applied, including one structural overflow case and one node-field violation
  case created through deliberate bypass.

#### Verification
- `flutter test test/controller/scene_invariants_test.dart`
- `flutter test test/controller/core/scene_controller_commit_failures_test.dart`

#### Positive Scenarios
- A valid runtime scene still passes the pre-commit invariant gate.
- A deliberately corrupted runtime scene with invalid node state is rejected
  before `_applyCommittedStore(...)` runs.
- A deliberately oversized runtime scene is rejected by the same pre-commit
  gate without needing export/snapshot conversion.

#### Negative Scenarios
- The pre-commit backstop must not classify runtime validity by calling
  `txnSceneToSnapshot(...)` or `ScenePolicy.validateRuntimeScene(...)`.
- The committed store must not accept a scene that violates canonical runtime
  node validation even when a direct bypass avoided ordinary owner writes.

#### Closure Evidence
- Green run of the listed verifications.
- Failing commit regression tests proving rejection occurs before the store
  apply path.

### Slice 3. [x] Convert constrained runtime node writes to validated owners

#### Slice Contract
Ordinary runtime writes to constrained mutable node fields fail fast through
validated owners, and patch-based mutations inherit the same fail-fast
semantics because they already write through those owners.

#### Change
- Replace bare public mutable storage with private backing plus validated
  setters or dedicated owner methods in
  `lib/src/core/scene_node.dart`,
  `lib/src/core/box_nodes.dart`,
  `lib/src/core/vector_nodes.dart`,
  `lib/src/core/path_node.dart`, and
  `lib/src/core/text_node_layout_state.dart`.
- Reuse the canonical field validators exported through
  `lib/src/contract/runtime_node_value_validation.dart`; do not duplicate
  numeric, transform, string, or size rules in `core/**`.
- Cover the following constrained runtime fields exactly in this slice:
  `transform`, `hitPadding`, `imageId`, `size`, `naturalSize`, `text`,
  `fontSize`, `fontFamily`, `maxWidth`, `lineHeight`, `start`, `end`,
  `thickness`, `strokeWidth`, `svgPathData`.
- Keep `StrokeNode.replacePoints(...)` as the point-list owner and preserve
  existing point-count and finite-coordinate validation there.
- Update `test/core/nodes_test.dart` and `test/model/document_model_test.dart`
  so they assert fail-fast owner writes for the touched constrained fields and
  patch-path parity for the same fields.
- Rewrite any touched fallback tests that currently depend on ordinary runtime
  setters accepting invalid constrained values so those tests instead use
  deliberate bypass construction to exercise crash-safety fallback behavior.

#### Verification
- `flutter test test/core/nodes_test.dart`
- `flutter test test/model/document_model_test.dart`

#### Positive Scenarios
- Direct runtime assignment to each touched constrained field succeeds for
  valid values and preserves existing derived-state/cache invalidation
  semantics.
- Patch-based mutation of each touched constrained field still succeeds for
  valid values without adding patch-local validation branches.

#### Negative Scenarios
- Direct runtime assignment to an invalid touched constrained field throws at
  the owner boundary.
- Patch-based mutation of an invalid touched constrained field throws through
  the same owner boundary.
- Ordinary runtime setters must not remain able to construct invalid path,
  transform, text-layout, image-size, or vector-geometry state after this
  slice.

#### Closure Evidence
- Green run of the listed verifications.
- Regression tests demonstrating fail-fast owner writes for the touched
  constrained fields.

### Slice 4. [x] Lock the runtime validity contract in invariants, guardrails, and docs

#### Slice Contract
Repository-local invariants, guardrails, and published docs describe one
runtime validity contract and mechanically block its reintroduction failures.

#### Change
- Add invariant entries to `tool/invariant_registry.dart` that cover
  model-owned runtime structural budgets and validated constrained runtime node
  owners, and attach them to the proof surfaces closed in Slices 1 through 3.
- Extend `tool/check_guardrails.dart` and
  `tool/src/guardrails/model_architecture_guardrails.dart` together with
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` so the
  repository rejects both of the following exact reintroduction forms:
  direct content-layer list mutation from controller code under
  `lib/src/controller/**` via `scene.layers.add(...)` or
  `scene.layers.insert(...)`, and public non-final constrained
  mutable fields or unvalidated direct storage declarations for the field list
  locked in Slice 3 inside the touched runtime node owner files under
  `lib/src/core/**`.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md`
  so they publish the same contract: eager owner validation for constrained
  runtime writes, one pre-commit backstop for bypasses, and boundary
  validation as a distinct outer layer.

#### Verification
- `flutter test test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`

#### Positive Scenarios
- Guardrail tooling accepts the canonical model-owned mutation and core-owner
  validation layout introduced by the earlier slices.
- Published docs describe the same ownership and enforcement split as the
  implementation.

#### Negative Scenarios
- Guardrail tooling rejects a controller path that reintroduces direct
  structural budget ownership.
- Guardrail tooling rejects a runtime node owner that reintroduces a bare
  public constrained mutable field.
- Documentation must not describe runtime validity as boundary-only after this
  slice closes.

#### Closure Evidence
- Green run of the listed verifications.
- Guardrail regression cases proving both forbidden reintroduction forms are
  blocked.

## 9. Final Verification

- `flutter test test/model/document_model_test.dart`
- `flutter test test/controller/internal/change_set_txn_context_test.dart`
- `flutter test test/controller/scene_invariants_test.dart`
- `flutter test test/controller/core/scene_controller_commit_failures_test.dart`
- `flutter test test/core/nodes_test.dart`
- `flutter test test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<prepared-path-list>`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
