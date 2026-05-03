# Change Contract

## 1. Change Mandate

Retire the unused semantic content-layer replacement seam introduced during
Step 10, keep only the topology-preserving slot replacement seam required by
copy-on-write, and make future semantic layer replacement re-enter only from a
real product-owned mutation contract.

## 2. Change Boundary

### Included in the Change

- Remove `txnReplaceContentLayerInScene(...)` from
  `lib/src/model/document_scene_insert.dart` and retire its internal model
  facade wrapper from `lib/src/model/document.dart`.
- Retire direct owner-side tests that currently lock the removed semantic seam
  and replace them with proof that only the topology-preserving slot seam
  remains in active use.
- Tighten the contract of `txnReplaceContentLayerSlotInScene(...)` so it stays
  a copy-on-write seam only and cannot silently become a semantic
  layer-topology helper.
- Keep controller, transaction, and replace-scene flows green while the seam is
  removed.
- Update plan and guardrail source-of-truth artifacts that currently imply the
  retired semantic seam still exists.

### Not Included in the Change

- No new public or internal product-facing API for semantic content-layer
  replacement.
- No redesign of `TxnContext`, the mutation gateway, the store/write-kernel
  split, or the stable locator architecture from Step 10.
- No change to `replaceScene(...)`, snapshot materialization, or scene import
  ownership.
- No controller-side topology repair, node-locator rebuild-on-every-change
  fallback, or second source of z-order truth.
- No behavioral change to `writeLayerEnsure(...)`, node insert/delete, or
  committed replace-scene flows beyond removal of the dead internal seam.

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` — new execution work must be recorded as a dedicated step document
  linked from the active plan index.
- `plan/step_10_model_owned_layer_topology_locator_contract.md` — Step 10
  intentionally split topology-preserving slot replacement from semantic layer
  replacement, but also retained a semantic seam that is now proving to be a
  dead and unsafe abstraction.
- `docs/target_architecture/README.md` — target architecture maps owner
  families and execution flows, but does not require dead internal helpers to
  remain in code when no product use-case depends on them.
- `docs/target_architecture/execution_flows.md` — committed writes flow through
  gateway/store/kernel/`TxnContext`; no target flow mentions a semantic
  content-layer replace operation.
- `docs/target_architecture/families/store_and_commit_path.md` — `TxnContext`
  remains the copy-on-write workspace and may carry derived state, but there is
  no target requirement to preserve an unused semantic layer-replace seam.
- `ARCHITECTURE.md` — model owns semantic content-layer topology mutation and
  controller must not repair topology manually; this is compatible with
  removing a dead helper while keeping the active owner path.
- `lib/src/model/document_scene_insert.dart` — the file contains both
  `txnReplaceContentLayerInScene(...)` and
  `txnReplaceContentLayerSlotInScene(...)`; the semantic seam mutates
  `scene.layers`, `nodeLocator`, and `layerIndexById`, while the slot seam only
  swaps the layer object.
- `lib/src/model/document.dart` — the removed seam is re-exported only as an
  internal model facade wrapper.
- `lib/src/controller/txn_workspace.dart` — the active controller write path
  uses only `txnReplaceContentLayerSlotInScene(...)` for shallow copy-on-write
  layer cloning.
- `lib/src/model/document_clone.dart` and `lib/src/core/scene.dart` — shallow
  content-layer cloning preserves `layer.id`, node order, and node object
  identity while allocating a fresh owning layer object and node list.
- `lib/src/controller/scene_snapshot_materializer.dart` — the real semantic
  replacement path today is whole-scene replacement via
  `materializeSceneReplacement(...)` and `adoptPreparedSceneReplacement(...)`,
  not content-layer replacement.
- `test/model/document_model_test.dart` — current owner-side coverage still
  locks direct `txnReplaceContentLayerInScene(...)` behavior even though the
  seam has no production caller.
- `test/controller/internal/change_set_txn_context_test.dart` — copy-on-write
  layer cloning behavior is already locked independently of the removed seam.
- `test/controller/internal/layer_topology_locator_contract_test.dart` —
  structural proof already asserts that controller code uses the slot seam and
  does not call `txnReplaceContentLayerInScene(...)`.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` —
  guardrails currently treat `txnReplaceContentLayerInScene(...)` as a semantic
  model-owned helper and `txnReplaceContentLayerSlotInScene(...)` as the only
  controller-allowed slot seam.

### Current Entry Path

- Direct internal dead seam:
  `test/model/document_model_test.dart` ->
  `lib/src/model/document.dart` ->
  `txnReplaceContentLayerInScene(...)`.
- Active copy-on-write path:
  `TxnContext.txnEnsureMutableLayer(...)` ->
  `_TxnWorkspace.ensureMutableLayer(...)` ->
  `txnCloneContentLayerShallow(...)` ->
  `txnReplaceContentLayerSlotInScene(...)`.
- Active semantic replacement path today:
  `replaceScene(...)` ->
  `materializeSceneReplacement(...)` ->
  `adoptPreparedSceneReplacement(...)` ->
  `TxnContext.txnAdoptScene(...)`.

### Current Owner

- The dead seam lives in the internal model topology helper inventory under
  `lib/src/model/document_scene_insert.dart` and `lib/src/model/document.dart`.
- The active copy-on-write seam lives in the same model file, but is consumed
  only by the transaction workspace in `lib/src/controller/txn_workspace.dart`.

### Adjacent Abstractions

- `txnInsertContentLayerInScene(...)` — active semantic layer insert seam that
  still has a real production use-case through `writeLayerEnsure(...)`.
- `txnReplaceContentLayerSlotInScene(...)` — active low-level slot seam for
  shallow layer replacement without topology semantics.
- `TxnContext.txnAdoptScene(...)` — atomic whole-scene adoption seam used by
  prepared scene replacement.
- `txnBuildNodeLocator(...)` and `txnBuildLayerIndexById(...)` — canonical
  derived-state rebuild helpers.

### Existing Tests

- `test/model/document_model_test.dart` — direct model-helper coverage for
  insert, replace, erase, clear, and locator behavior.
- `test/controller/internal/change_set_txn_context_test.dart` — transaction
  copy-on-write and derived-state behavior.
- `test/controller/internal/mutation_executor_test.dart` — structural mutation
  execution, including prepared scene replacement flows.
- `test/controller/internal/layer_topology_locator_contract_test.dart` —
  source-level structural contract around controller seam usage.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` —
  guardrail proof around allowed and forbidden controller/model topology seams.

### Analogous Implementation Path

- `lib/src/model/document_clone.dart` plus
  `lib/src/controller/txn_workspace.dart` —
  `txnCloneContentLayerShallow(...)` and `_TxnWorkspace.ensureMutableLayer(...)`
  are the closest local precedent for the surviving slot seam because they
  already encode the intended topology-preserving copy-on-write behavior:
  preserve `layer.id`, preserve node ordering, and swap only the owning layer
  object.
- `lib/src/controller/scene_snapshot_materializer.dart` —
  `materializeSceneReplacement(...)` plus `adoptPreparedSceneReplacement(...)`
  is the closest valid precedent for semantic replacement because it exists for
  a real product path, validates before adoption, and swaps scene ownership in
  one coherent operation instead of keeping a speculative helper alive.

### Governing Repository Rules

- `AGENTS.md` — prefer deleting liability over preserving unused layers of
  abstraction; fix bugs at the right owner; do not keep sync glue when one
  source of truth is enough.
- `ARCHITECTURE.md` — model owns topology mutation and controller may carry but
  must not repair topology-derived state.
- `docs/target_architecture/execution_flows.md` — write and commit ownership
  remains on gateway/store/kernel/`TxnContext`, not on speculative helper
  inventories.
- `docs/target_architecture/families/store_and_commit_path.md` — the stable
  part is one copy-on-write workspace and no second committed-scene owner, not
  preservation of every internal helper introduced during intermediate slices.
- `tool/invariant_registry.dart` / `INV-ENG-ID-INDEX-FROM-SCENE` — carried ids
  and locators must match the scene rather than a stale helper-local protocol.
- `tool/invariant_registry.dart` / `INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER` —
  runtime scene structure mutation remains model-owned.

### Rejected Misleading Local Patterns

- Patch `txnReplaceContentLayerInScene(...)` and keep it “for future use” —
  wrong level because the seam has no production owner today and would keep a
  dangerous dead abstraction alive.
- Reuse `txnReplaceContentLayerSlotInScene(...)` as a semantic layer-topology
  helper — wrong seam because the slot helper is only safe when layer identity
  and node ordering stay stable.
- Move semantic layer replacement into controller code — wrong owner because
  Step 10 and the architecture docs intentionally retired controller-side
  topology repair.
- Keep tests and guardrails that positively describe the dead seam — wrong
  source of truth because they would continue advertising a removed contract.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- The problem belongs to the internal model topology seam inventory inside the
  store/commit family: one speculative semantic helper survived Step 10 even
  though no active product path depends on it.

#### Selected Architectural Form

- Retire `txnReplaceContentLayerInScene(...)` completely from the internal
  model facade and keep only `txnReplaceContentLayerSlotInScene(...)` as the
  low-level topology-preserving slot seam used by copy-on-write layer cloning.
- Treat whole-scene replacement through prepared scene replacement as the only
  currently admitted semantic replacement path.
- Require any future semantic content-layer replacement to re-enter the code
  base only from a real mutation use-case with an explicit owner, admission
  contract, and proof bundle; do not preserve a speculative seam in advance.

#### Owning Layer or Module

- Seam retirement owner: `lib/src/model/document_scene_insert.dart` and
  `lib/src/model/document.dart`.
- Active successor seam owner: `lib/src/model/document_scene_insert.dart`
  through `txnReplaceContentLayerSlotInScene(...)`.
- Consumer and proof owners: `lib/src/controller/txn_workspace.dart`,
  `test/controller/internal/change_set_txn_context_test.dart`,
  `test/controller/internal/layer_topology_locator_contract_test.dart`, and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`.

#### Dependency Direction

- `controller` continues to depend on the model slot seam for copy-on-write
  layer cloning only.
- `controller` semantic replacement continues to depend on prepared scene
  replacement, not on a content-layer semantic helper.
- `model` no longer exposes a dead semantic content-layer replace seam upward.

#### State and Data Ownership

- `scene.layers` remains the single source of truth for content-layer order.
- `nodeLocator` and `layerIndexById` remain derived state from the scene.
- The slot seam may replace only the owning `ContentLayer` object while
  preserving `layer.id`, node count, node order, and per-index node identity,
  so derived topology state stays valid without semantic repair.
- No internal seam may mutate `scene`, `nodeLocator`, and `layerIndexById`
  together unless a real semantic mutation path owns the full admission
  contract.

#### Entry and Exit Boundaries

- Entry: active copy-on-write layer cloning in `_TxnWorkspace.ensureMutableLayer(...)`.
- Exit: no model facade or test inventory positively depends on
  `txnReplaceContentLayerInScene(...)`; replace-scene remains the semantic
  replacement boundary available today.

#### Permitted Extension Seam

- Future semantic content-layer replacement may be added only when a real write
  contract or mutation op needs it and only with explicit structural admission,
  owner-side proof, and guardrails.
- Until then, extending layer topology means:
  - semantic insert via `txnEnsureContentLayerInScene(...)` /
    `txnInsertContentLayerInScene(...)`;
  - topology-preserving slot replacement via
    `txnReplaceContentLayerSlotInScene(...)`;
  - semantic whole-scene replacement via prepared scene replacement.

#### Rejected Alternatives

- Keep and harden the dead semantic seam — wrong because it preserves liability
  without an active owner or product contract.
- Collapse slot replacement and semantic replacement back into one helper —
  wrong because Step 10 already proved that mixed seam ownership hides whether
  derived-state repair is required.
- Add a new public or controller-private replace-layer API now — wrong scope
  because this step is corrective retirement, not a new product capability.

#### Why This Level Is Correct

- It preserves the target architecture rule that real semantic mutation must
  stay model-owned while removing a seam that currently has no product owner.
- It reduces risk instead of adding another patch to a dead abstraction.
- It keeps the active copy-on-write path intact and leaves a clean re-entry
  point if a real semantic layer-replace use-case appears later.

## 5. Locked Decisions

1. `txnReplaceContentLayerInScene(...)` is retired instead of patched.
2. `txnReplaceContentLayerSlotInScene(...)` remains, but its contract is
   narrowed to topology-preserving replacement only.
3. Step 10 source-of-truth artifacts must be updated or superseded where they
   still imply that the retired semantic seam is part of the living design.
4. No new semantic layer-replace helper will be introduced in this corrective
   step.
5. Slot-seam enforcement uses one explicit mechanism: fail-fast runtime guards
   in the model helper plus owner-side structural tests and guardrails; this
   step does not leave enforcement form open for selection during
   implementation.

## 6. Result Requirements

1. No active internal model facade exposes a semantic content-layer replace
   helper.
2. Copy-on-write layer cloning still works through one explicit slot seam.
3. Replace-scene remains the only semantic replacement path available today.
4. Guardrails and source-level tests make it mechanically visible if controller
   or model code reintroduces the retired seam.
5. Plan and architecture-adjacent artifacts no longer describe the dead seam as
   part of the current runtime design.

## 7. Execution Order and Gates

### Required Order

- first add or revise structural and characterization proof around the active
  slot seam and the retired semantic seam inventory
- then remove `txnReplaceContentLayerInScene(...)` from the model files and
  retire direct owner-side tests that lock it
- then tighten the slot seam contract and its proof surfaces
- then align plan and guardrail source-of-truth artifacts that still mention
  the retired seam

### Successor Seam and Retirement Gates

- successor seam: `txnReplaceContentLayerSlotInScene(...)` for copy-on-write
  only, plus prepared scene replacement for semantic whole-scene replacement
- consumer migration order: owner-side model tests -> structural seam tests ->
  guardrail fixtures -> plan/source-of-truth docs
- retirement gate: no production file, model facade wrapper, guardrail fixture,
  or architecture-facing test positively references
  `txnReplaceContentLayerInScene(...)`
- documentation gate: no active plan or architecture-facing artifact describes
  semantic content-layer replacement as a living seam unless it explicitly says
  the seam was retired

### Deferred Broad Verification

- run the required code-change verification preset only after all retirement
  and guardrail edits land
- run tool-guardrail verification only after structural tests and guardrail
  fixtures are updated

## 8. File Map

### Implementation Files

- `lib/src/model/document_scene_insert.dart`
- `lib/src/model/document.dart`
- `lib/src/controller/txn_workspace.dart`
- `tool/src/guardrails/rules/model/model_architecture_rules.dart`

### Test Files

- `test/model/document_model_test.dart`
- `test/controller/internal/change_set_txn_context_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/internal/layer_topology_locator_contract_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixtures and Supporting Data

- none

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_10_model_owned_layer_topology_locator_contract.md`
- `plan/step_14_retire_unused_semantic_layer_replace_seam.md`
- `tool/check_guardrails.dart`

### Analysis Area

- model topology seam inventory around content-layer replacement and the active
  copy-on-write slot seam

## 9. Implementation Rules

### Protected Invariants

- `INV-G-LAYERID-UNIQUE`
- `INV-G-LAYER-Z-ORDER-BY-LIST`
- `INV-ENG-ID-INDEX-FROM-SCENE`
- `INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER`

### Required Proof

- behavioral proof:
  - copy-on-write layer cloning still resolves mutable nodes correctly after
    slot replacement
  - replace-scene adoption still bypasses layer/node copy-on-write cloning as
    before
  - removing the dead semantic seam does not change `writeLayerEnsure(...)` or
    node delete/patch flows
- structural proof:
  - no active model facade exposes `txnReplaceContentLayerInScene(...)`
  - controller source-inspection proof still allows only the slot seam
  - slot seam proof makes it visible when callers try to use it as semantic
    topology mutation
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- internal model topology helpers
- transaction workspace seam tests
- guardrail fixtures and architecture-facing structural tests
- plan/source-of-truth artifacts that describe the retired seam

### Forbidden Moves

- do not patch and keep `txnReplaceContentLayerInScene(...)` as a dormant seam
- do not broaden `txnReplaceContentLayerSlotInScene(...)` into a semantic
  topology helper
- do not move topology mutation or topology repair into controller code
- do not add a new public or controller-private replace-layer API in this step
- do not leave source-of-truth artifacts claiming the dead seam still exists

### Optional: Resolution Rules

- slot replacement must preserve `layer.id`
- slot replacement must preserve node count and per-index node identity
- slot replacement may allocate a fresh owning `ContentLayer` object and fresh
  node list for copy-on-write purposes only
- slot replacement enforcement uses fail-fast runtime guards in
  `txnReplaceContentLayerSlotInScene(...)`; tests and guardrails make drift
  visible and keep the seam inventory explicit

## 10. Vertical Slices

### Slice 1. [x] Retire Semantic Replace Seam From The Model Facade

#### Slice Contract

The dead semantic content-layer replacement seam disappears from the internal
model facade without changing active production flows.

#### Change

- add one failing structural reproducer proving that the model seam inventory
  must no longer expose `txnReplaceContentLayerInScene(...)`
- add 1 to 3 neighboring guard tests covering the active copy-on-write seam and
  the separate replace-scene semantic path
- remove `txnReplaceContentLayerInScene(...)` from
  `document_scene_insert.dart` and retire its wrapper from `document.dart`
- retire direct owner-side tests that positively lock the removed seam

#### Behavioral Verification

- `flutter test test/model/document_model_test.dart`
- `flutter test test/controller/internal/change_set_txn_context_test.dart`
- `flutter test test/controller/internal/mutation_executor_test.dart`

#### Structural Verification

- `flutter test test/controller/internal/layer_topology_locator_contract_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

#### Fixtures Used

- existing in-memory runtime scenes already used by model and transaction tests

#### Positive Scenarios

- copy-on-write layer cloning still returns a mutable layer and preserves lookup
- prepared replace-scene adoption still owns semantic scene replacement

#### Negative Scenarios

- no model facade wrapper exposes `txnReplaceContentLayerInScene(...)`
- no structural test treats the removed seam as part of the active design

#### Closure Evidence

- dead semantic seam is gone from the model files
- active production tests stay green without introducing a replacement seam

### Slice 2. [x] Narrow Slot Replacement To Copy-On-Write Only

#### Slice Contract

The remaining slot seam is mechanically constrained to topology-preserving
replacement so the retired semantic behavior cannot re-enter through a nearby
helper, and source-of-truth artifacts describe only that surviving seam.

#### Change

- add slot-seam guard tests for preserved `layer.id`, node count, and per-index
  node identity
- tighten `txnReplaceContentLayerSlotInScene(...)` with fail-fast runtime
  guards so semantic topology mutation through the slot seam becomes visible
  immediately in every build
- align controller seam tests and guardrail fixtures with the narrowed slot
  contract
- update Step 10 and Step 14 plan/source-of-truth artifacts as closure evidence
  so they describe the living seam inventory accurately

#### Behavioral Verification

- `flutter test test/model/document_model_test.dart`
- `flutter test test/controller/internal/change_set_txn_context_test.dart`

#### Structural Verification

- `flutter test test/controller/internal/layer_topology_locator_contract_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

#### Fixtures Used

- existing shallow-clone runtime layers from transaction tests

#### Positive Scenarios

- shallow cloned layers still preserve `layer.id` and node ordering
- controller code still uses only the slot seam for copy-on-write cloning

#### Negative Scenarios

- slot seam cannot silently become a semantic replace helper
- no plan or guardrail artifact still advertises the retired seam as active

#### Closure Evidence

- slot seam has one narrow, mechanically visible contract
- plan and structural proof surfaces describe the same seam inventory as code

## 11. Final Verification

- create a changed-paths file covering every modified repository-relative path
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<that-file>`
- `flutter test test/model/document_model_test.dart`
- `flutter test test/controller/internal/change_set_txn_context_test.dart`
- `flutter test test/controller/internal/mutation_executor_test.dart`
- `flutter test test/controller/internal/layer_topology_locator_contract_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`

## 12. Acceptance Criteria

- `txnReplaceContentLayerInScene(...)` no longer exists in the active internal
  model facade
- `txnReplaceContentLayerSlotInScene(...)` remains the only layer-replace seam
  and is constrained to topology-preserving copy-on-write use
- active controller and replace-scene flows behave as before
- guardrails and plan/source-of-truth artifacts no longer describe the retired
  seam as living architecture
