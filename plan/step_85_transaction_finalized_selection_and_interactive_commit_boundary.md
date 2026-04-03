language: russian

# Change Contract

## 1. Change Mandate

This change fixes the write-side owner graph so that transaction state is fully finalized before commit planning and every interactive committed write routes through one canonical controller-private mutation boundary.

## 2. Change Boundary

### Included in the Change

- Удаление deferred selection repair из commit-plan и перенос finalization в canonical controller mutation flow.
- Расширение `SceneControllerMutationBoundary` на draw/line/erase committed writes и удаление прямого interactive bypass в `storeController.draw.*`.
- Обновление structural tests, guardrails, invariant registry и release-ready docs для новой формы.
- Добавление нового шага в roadmap и отдельного step-документа для этого change contract.

### Not Included in the Change

- Изменение публичных entrypoint-ов `SceneController`, `SceneWriteTxn`, `SceneView` или package exports.
- Изменение selection rule, по которой visible non-selectable ids могут оставаться explicitly selected.
- Изменение signal types, draw payload semantics, action ordering или active-gesture exclusivity policy.
- Переписывание underlying `DrawCommands` / `SceneCommands` вне required boundary adoption.

## 3. File Map and Analysis Areas

### Implementation Files

- [lib/src/controller/mutation_executor.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/mutation_executor.dart)
- [lib/src/controller/selection_state_mutation_applier.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/selection_state_mutation_applier.dart)
- [lib/src/controller/selection_post_apply_finalizer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/selection_post_apply_finalizer.dart)
- [lib/src/controller/node_mutation_applier.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/node_mutation_applier.dart)
- [lib/src/controller/scene_controller_commit_plan.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_controller_commit_plan.dart)
- [lib/src/controller/internal/selection_normalizer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/internal/selection_normalizer.dart)
- [lib/src/interactive/internal/scene_controller_mutation_boundary.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart)
- [lib/src/interactive/internal/scene_controller_interaction_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_runtime.dart)
- [lib/src/interactive/internal/interactive_runtime_callbacks.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_runtime_callbacks.dart)
- [lib/src/interactive/internal/interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart)
- [lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart)
- [lib/src/interactive/internal/interactive_draw_stroke_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_stroke_engine.dart)
- [lib/src/interactive/internal/interactive_draw_line_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_line_engine.dart)
- [lib/src/interactive/internal/interactive_draw_eraser_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_eraser_engine.dart)
- [tool/src/guardrails/interactive_api_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/src/guardrails/interactive_api_guardrails.dart)

### Test Files

- [test/controller/internal/scene_writer_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/internal/scene_writer_test.dart)
- [test/controller/internal/mutation_executor_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/internal/mutation_executor_test.dart)
- [test/controller/core/scene_controller_writer_lifecycle_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_writer_lifecycle_test.dart)
- [test/controller/core/scene_controller_commit_effects_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_commit_effects_test.dart)
- [test/controller/core/scene_controller_commit_atomicity_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_commit_atomicity_test.dart)
- [test/controller/core/scene_controller_commit_runtime_contract_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_commit_runtime_contract_test.dart)
- [test/interactive/core/scene_controller_mutation_boundary_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_mutation_boundary_test.dart)
- [test/interactive/core/scene_controller_architecture_boundary_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_architecture_boundary_test.dart)
- [test/tool/guardrails/guardrails_interactive_api_tool_test.dart](/Users/blackpika/iwb_canvas_engine/test/tool/guardrails/guardrails_interactive_api_tool_test.dart)

### Fixture and Supporting Data Files

- [test/tool/support/guardrails_tool_test_support.dart](/Users/blackpika/iwb_canvas_engine/test/tool/support/guardrails_tool_test_support.dart)
- [tool/invariant_registry.dart](/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart)
- [README.md](/Users/blackpika/iwb_canvas_engine/README.md)
- [API_GUIDE.md](/Users/blackpika/iwb_canvas_engine/API_GUIDE.md)
- [ARCHITECTURE.md](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md)
- [CHANGELOG.md](/Users/blackpika/iwb_canvas_engine/CHANGELOG.md)
- [PLAN.md](/Users/blackpika/iwb_canvas_engine/PLAN.md)
- [plan/step_85_transaction_finalized_selection_and_interactive_commit_boundary.md](/Users/blackpika/iwb_canvas_engine/plan/step_85_transaction_finalized_selection_and_interactive_commit_boundary.md)

### Analysis Area

- `lib/src/controller/**`
- `lib/src/interactive/**`
- `tool/src/guardrails/**`
- `test/controller/**`
- `test/interactive/**`
- `test/tool/guardrails/**`
- `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`, `plan/step_85_transaction_finalized_selection_and_interactive_commit_boundary.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one of the slices below.
- Every modified test must prove one of the locked results below.
- Every modified supporting file must pin the resulting owner model, invariant contour, or roadmap state.
- Every newly proposed file or directory name must comply with the global `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Selection normalization continues to drop only missing, background, or invisible ids; explicit non-selectable ids remain stable.
2. `SceneControllerMutationBoundary` remains the only interactive owner allowed to perform committed scene writes; draw, line, and erase commits are included in that rule and must not remain a parallel bypass.
3. `SceneControllerCommitRuntime` remains the controller-private orchestration owner; this change must not move transaction assembly or commit orchestration back into the public controller facade.
4. All committed writes continue to route through the existing transactional core; no second mutable selection source, no sync bridge, and no raw selection-intent cache may be introduced.
5. Public behavior for active-gesture exclusivity, action emission, signal types, and timestamp ordering remains behaviorally equivalent.
6. The change must be mechanically enforced through tests and guardrails; prose-only closure is not acceptable.

## 5. Result Requirements

1. After any successful node, structural, or document mutation inside `write(...)`, `SceneWriteTxn.selectedNodeIds` and `SceneWriteTxn.snapshot` reflect the finalized transaction state that would commit if the callback returned at that point.
2. `buildControllerCommitPlan(...)` and `normalizeControllerCommitInputs(...)` no longer mutate `TxnContext`, `workingSelection`, or `changeSet`.
3. `selectionChanged` is true only when the effective selection set changes; a selected node patched to `isSelectable: false` stays selected and does not create a false selection delta.
4. `SceneControllerInteractionRuntime` and draw-family callback surfaces no longer call `request.storeController.draw.write*` directly; all committed gesture writes route through `SceneControllerMutationBoundary`.
5. Structural enforcement fails when interactive callback wiring bypasses the boundary or when commit planning reintroduces post-callback transaction-state repair.
6. `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`, and the new step document describe the finalized owner model and callback-consistency contract without documenting temporary migration state.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `normalizeControllerCommitInputs(...)` currently mutates `ctx.workingSelection` and `ctx.changeSet` during commit planning.
- Explicit selection writes already have a canonical owner in `selection_state_mutation_applier.dart`.
- Post-apply selection repair is a separate transactional responsibility from explicit selection commands and must not be folded into a mixed-responsibility selection-state file.
- `node_mutation_applier.dart` currently marks `selectionChanged` for `isVisible` and `isSelectable` patches without finalizing `ctx.workingSelection`.
- `scene_controller_interaction_runtime.dart` currently routes selection and move through `mutationBoundary`, but routes stroke, line, and erase directly through `request.storeController.draw.*`.
- `tool/src/guardrails/interactive_api_guardrails.dart` currently protects selection callback wiring, but not draw-family callback wiring.
- `ARCHITECTURE.md` already fixes two critical contracts: non-selectable explicit ids remain stable, and `SceneControllerMutationBoundary` is the canonical interactive committed-write owner.

### 6.2 Target Verification Units

- MCP test runner: [test/controller/internal/scene_writer_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/internal/scene_writer_test.dart)
- MCP test runner: [test/controller/internal/mutation_executor_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/internal/mutation_executor_test.dart)
- MCP test runner: [test/controller/core/scene_controller_writer_lifecycle_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_writer_lifecycle_test.dart)
- MCP test runner: [test/controller/core/scene_controller_commit_effects_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_commit_effects_test.dart)
- MCP test runner: [test/controller/core/scene_controller_commit_atomicity_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_commit_atomicity_test.dart)
- MCP test runner: [test/controller/core/scene_controller_commit_runtime_contract_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_commit_runtime_contract_test.dart)
- MCP test runner: [test/interactive/core/scene_controller_mutation_boundary_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_mutation_boundary_test.dart)
- MCP test runner: [test/interactive/core/scene_controller_architecture_boundary_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_architecture_boundary_test.dart)
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

### 6.3 Protected States, Data, or Structures

- `TxnContext.workingSelection` must stay a single mutable in-place owner; replacement with a competing cached set is forbidden.
- `SceneStoreController.selectedNodeIds` view identity must continue to survive commits without effective selection changes.
- Visible non-selectable explicit ids must remain selectable-by-persistence, even though new selection normalization still excludes invisible or missing ids.
- Existing draw, line, erase, move, clear, and transform action payloads and signal types must remain unchanged.
- Active-gesture exclusivity and external-mutation deny/reset semantics must remain unchanged.

### 6.4 Allowed Semantic Change Zones

- Controller-private post-apply selection finalization after successful node, structural, and document mutation execution.
- Commit-plan phase derivation from already-finalized transaction state.
- Interactive callback naming and wiring for committed draw-family writes.
- Structural guardrails and invariant proofs for mutation-boundary completeness and commit-plan purity.
- Documentation and roadmap updates required to pin the new shape.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct bypass via `request.storeController.draw.writeDrawStroke`, `writeDrawLineFromWorldSegment`, or `writeEraseNodes`;
- alias-based bypass where the same draw-family members are first captured into locals or helpers and then wired into interactive callbacks;
- direct commit-plan mutation of `ctx.workingSelection`, `ctx.changeSet`, or any helper that performs the same repair from `scene_controller_commit_plan.dart`;
- helper-based deferred repair invoked from commit runtime after the write callback has already completed.

### 6.6 Allowed Forms That Do Not Count as Violations

- Boundary methods in `scene_controller_mutation_boundary.dart` delegating into canonical controller-private command families such as `storeController.draw.*` or `storeController.commands.*`.
- Direct `TxnContext` mutation inside canonical controller mutation owners only, when it happens before control returns from the mutation execution path.
- Read-only phase derivation inside `scene_controller_commit_plan.dart`.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `MutationExecutor.execute(...)` must become the single place that invokes post-apply selection finalization after successful `NodeMutationOp` and `StructuralDocumentMutationOp`; this step must run before the write callback regains control.
- Post-apply selection finalization must live in a dedicated controller-private owner file at [lib/src/controller/selection_post_apply_finalizer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/selection_post_apply_finalizer.dart), not inside [lib/src/controller/selection_state_mutation_applier.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/selection_state_mutation_applier.dart) and not in commit planning.
- `scene_controller_commit_plan.dart` must remain present as the commit-plan owner, but it may only read finalized transaction state and derive plan data; if [lib/src/controller/internal/selection_normalizer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/internal/selection_normalizer.dart) becomes unused, it must be deleted in this change.
- Draw-family callback surfaces under `interactive/internal/**` must be renamed from `write*` to `commit*` when they start routing through the mutation boundary, so the callback API itself no longer suggests a direct store write owner.
- Structural guardrails must reject both direct and renamed draw-family bypasses in `scene_controller_interaction_runtime.dart`; string checks limited to selection-only wiring do not satisfy closure.

### 6.8 Prohibited

- Keeping any selection normalization or `changeSet` repair in `scene_controller_commit_plan.dart`.
- Replacing deferred repair with a second mutable “pending selection intent” source or any synchronizer between two selection states.
- Preserving `isSelectable` as a flag that marks `selectionChanged` without an actual selection-set delta.
- Leaving draw-family committed callback names on `write*` while the implementation routes them through the boundary.
- Adding or widening public API solely to implement this change.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the trigger point must be attached.
7. If a slice changes a guardrail, both bypass and non-bypass scenarios must be covered.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global `AGENTS.md` section `### File naming`.
11. If implementation reveals an unproven behavioral dependency on hide-then-show selection resurrection inside a single write callback, execution must stop and that behavior must be explicitly confirmed before continuing.

## 8. Vertical Slices

### Slice 1. [ ] Finalized Transaction Selection Before Commit Plan

#### Slice Contract

Selection finalization happens inside the canonical mutation execution path before control returns to the write callback, and commit planning becomes read-only.

#### Change

Introduce a dedicated controller-private finalization owner in [lib/src/controller/selection_post_apply_finalizer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/selection_post_apply_finalizer.dart) that normalizes `ctx.workingSelection` against the current scene and marks `selectionChanged` only on an actual set delta. Invoke that owner from [lib/src/controller/mutation_executor.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/mutation_executor.dart) after successful `NodeMutationOp` and `StructuralDocumentMutationOp` execution. Keep [lib/src/controller/selection_state_mutation_applier.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/selection_state_mutation_applier.dart) limited to explicit selection commands. Remove the flag-only `isVisible/isSelectable` selection marker from [lib/src/controller/node_mutation_applier.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/node_mutation_applier.dart). Convert [lib/src/controller/scene_controller_commit_plan.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/scene_controller_commit_plan.dart) into a read-only plan owner and delete [lib/src/controller/internal/selection_normalizer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/controller/internal/selection_normalizer.dart) if no code path uses it afterward.

#### Verification

- MCP test runner: [test/controller/internal/scene_writer_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/internal/scene_writer_test.dart)
- MCP test runner: [test/controller/internal/mutation_executor_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/internal/mutation_executor_test.dart)
- MCP test runner: [test/controller/core/scene_controller_writer_lifecycle_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_writer_lifecycle_test.dart)
- MCP test runner: [test/controller/core/scene_controller_commit_effects_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_commit_effects_test.dart)
- MCP test runner: [test/controller/core/scene_controller_commit_atomicity_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_commit_atomicity_test.dart)
- MCP test runner: [test/controller/core/scene_controller_commit_runtime_contract_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_commit_runtime_contract_test.dart)

#### Positive Scenarios

- `writeNodePatch(isVisible:false)` immediately removes the selected id from `selectedNodeIds` inside the same callback.
- `writeDocumentReplace(...)` and structural delete flows expose the finalized empty or reduced selection before callback return.
- `writeNodePatch(isSelectable:false)` preserves the selected visible id both inside the callback and after commit.

#### Negative Scenarios

- `scene_controller_commit_plan.dart` contains no mutation of `ctx.workingSelection` and no repair-only `txnMarkSelectionChanged()` call.
- No false `selectionChanged` delta is produced when only `isSelectable` changes on an already-selected visible node.

#### Closure Evidence

- Green run of the listed verifications.
- Source proof in [test/controller/core/scene_controller_commit_runtime_contract_test.dart](/Users/blackpika/iwb_canvas_engine/test/controller/core/scene_controller_commit_runtime_contract_test.dart) that commit planning no longer mutates transaction state.

### Slice 2. [ ] Full Interactive Commit Boundary For Draw Family

#### Slice Contract

Stroke, line, and erase gesture commits route through `SceneControllerMutationBoundary`, and the interactive callback surface expresses that boundary-owned commit path.

#### Change

Add `commitDrawStroke(...)`, `commitDrawLineFromWorldSegment(...)`, and `commitEraseNodes(...)` to [lib/src/interactive/internal/scene_controller_mutation_boundary.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart). Rewire [lib/src/interactive/internal/scene_controller_interaction_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_runtime.dart) to pass only mutation-boundary callbacks. Rename the draw-family callback fields from `write*` to `commit*` across [lib/src/interactive/internal/interactive_runtime_callbacks.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_runtime_callbacks.dart), [lib/src/interactive/internal/interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart), [lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart), [lib/src/interactive/internal/interactive_draw_stroke_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_stroke_engine.dart), [lib/src/interactive/internal/interactive_draw_line_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_line_engine.dart), and [lib/src/interactive/internal/interactive_draw_eraser_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_eraser_engine.dart).

#### Verification

- MCP test runner: [test/interactive/core/scene_controller_mutation_boundary_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_mutation_boundary_test.dart)
- MCP test runner: [test/interactive/core/scene_controller_architecture_boundary_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_architecture_boundary_test.dart)
- MCP test runner shard preset: `interactive`

#### Positive Scenarios

- Stroke commit, line commit, and erase commit still produce the same committed scene results and action emission behavior.
- `SceneControllerInteractionRuntime` assembles selection, move, stroke, line, and erase commits through one boundary object.

#### Negative Scenarios

- `scene_controller_interaction_runtime.dart` contains no direct `request.storeController.draw.writeDrawStroke`, `writeDrawLineFromWorldSegment`, or `writeEraseNodes` wiring.
- `InteractiveRuntimeCallbacks` and draw coordinator callbacks no longer describe draw-family commits as direct store writes.

#### Closure Evidence

- Green run of the listed verifications.
- Source proof in [test/interactive/core/scene_controller_architecture_boundary_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_architecture_boundary_test.dart) that all committed gesture callback wiring uses `mutationBoundary`.

### Slice 3. [ ] Enforcement And Documentation Closure

#### Slice Contract

Guardrails, invariant registry, release-ready docs, and roadmap mechanically pin the finalized write-side architecture and callback-consistency contract.

#### Change

Extend [tool/src/guardrails/interactive_api_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/src/guardrails/interactive_api_guardrails.dart) and [test/tool/guardrails/guardrails_interactive_api_tool_test.dart](/Users/blackpika/iwb_canvas_engine/test/tool/guardrails/guardrails_interactive_api_tool_test.dart) to reject draw-family callback bypasses and accept the new boundary-owned `commit*` wiring; update [test/tool/support/guardrails_tool_test_support.dart](/Users/blackpika/iwb_canvas_engine/test/tool/support/guardrails_tool_test_support.dart) accordingly. Extend `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY` to cover draw-family callback routing and add one new invariant entry in [tool/invariant_registry.dart](/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart) for “transaction state is finalized before commit planning”, with `// INV:` markers placed in the updated controller proof tests. Update [README.md](/Users/blackpika/iwb_canvas_engine/README.md), [API_GUIDE.md](/Users/blackpika/iwb_canvas_engine/API_GUIDE.md), [ARCHITECTURE.md](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md), [CHANGELOG.md](/Users/blackpika/iwb_canvas_engine/CHANGELOG.md), [PLAN.md](/Users/blackpika/iwb_canvas_engine/PLAN.md), and create [plan/step_85_transaction_finalized_selection_and_interactive_commit_boundary.md](/Users/blackpika/iwb_canvas_engine/plan/step_85_transaction_finalized_selection_and_interactive_commit_boundary.md) with this contract.

#### Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Positive Scenarios

- Guardrails accept selection and draw-family callback wiring through `SceneControllerMutationBoundary`.
- Invariant coverage succeeds with the expanded mutation-boundary proof and the new finalized-before-commit-plan proof.

#### Negative Scenarios

- Sandbox cases with direct draw-family callback bypasses fail with an `interactive API violation`.
- Reintroducing commit-plan transaction-state mutation fails the structural controller proof.

#### Closure Evidence

- Green run of the listed verifications.
- New and updated invariant entries in [tool/invariant_registry.dart](/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart).
- Updated step index entry in [PLAN.md](/Users/blackpika/iwb_canvas_engine/PLAN.md) and a new step document at [plan/step_85_transaction_finalized_selection_and_interactive_commit_boundary.md](/Users/blackpika/iwb_canvas_engine/plan/step_85_transaction_finalized_selection_and_interactive_commit_boundary.md).

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/controller/mutation_executor.dart lib/src/controller/selection_state_mutation_applier.dart lib/src/controller/selection_post_apply_finalizer.dart lib/src/controller/node_mutation_applier.dart lib/src/controller/scene_controller_commit_plan.dart lib/src/interactive/internal/scene_controller_mutation_boundary.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/interactive_runtime_callbacks.dart lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart lib/src/interactive/internal/interactive_draw_stroke_engine.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard preset: `core`
- MCP test shard preset: `model_contract`
- MCP test shard preset: `controller_internal`
- MCP test shard preset: `controller`
- MCP test shard preset: `render_view`
- MCP test shard preset: `interactive`
- MCP test shard preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
