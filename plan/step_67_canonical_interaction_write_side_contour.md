language: russian

# Change Contract

## 1. Change Mandate
This change introduces a canonical controller-owned interaction write-side contour that owns scene and selection mutations, prepared scene replacement, and pointer semantics without model-import drift in `interactive` or direct `TxnContext` edits outside canonical mutation appliers.

## 2. Change Boundary

### Included in the Change
- Консолидация scene/selection mutation ownership под одним controller-private write-side boundary.
- Введение канонического mutation-family owner-а для selection-state transitions.
- Перевод `replaceScene(...)` на prepared replacement payload без повторного `txnSceneFromSnapshot(...)`.
- Вынос tap/double-tap recognition, deferred flush и live `PointerInputSettings` adoption из view-host shell в одного dedicated pointer-semantics owner-а.
- Удаление `model/document.dart` import-ов из `lib/src/interactive/**`.
- Обновление guardrails, invariant proof surface, docs и roadmap для нового owner graph.

### Not Included in the Change
- Изменение публичного API `SceneController`, `SceneView`, `SceneWriteTxn` или package entrypoints.
- Перенос raw pointer slot routing из `view` в `interactive` или `controller`.
- Изменение scene serialization contract, snapshot/schema boundary или `ScenePolicy`.
- Переписывание render/cache pipeline вне targeted replace-scene and pointer-host regressions.
- App-level UI, example workflows или backend/persistence concerns.

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/interaction_eligibility_policy.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- `lib/src/interactive/internal/scene_controller_selection_mutations.dart`
- `lib/src/interactive/internal/interactive_selection_actions.dart`
- `lib/src/interactive/internal/interactive_move_selection_coordinator.dart`
- `lib/src/controller/scene_writer.dart`
- `lib/src/controller/scene_writer_selection.dart`
- `lib/src/controller/mutation_op.dart`
- `lib/src/controller/mutation_executor.dart`
- `lib/src/controller/scene_mutation_applier.dart`
- `lib/src/controller/commands/scene_commands.dart`
- `lib/src/controller/commands/move_commands.dart`

### Test Files
- `test/core/pointer_input_test.dart`
- `test/controller/internal/scene_writer_test.dart`
- `test/controller/internal/mutation_executor_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/commands/move_commands_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`
- `test/interactive/core/interaction_eligibility_policy_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`

### Fixture and Supporting Data Files
- `tool/check_guardrails.dart`
- `tool/invariant_registry.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_67_canonical_interaction_write_side_contour.md`

### Analysis Area
- `lib/src/controller/**`
- `lib/src/interactive/**`
- `lib/src/view/**`
- `test/controller/**`
- `test/interactive/**`
- `test/view/**`
- `test/tool/guardrails/**`
- `tool/**`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule
- Каждый изменённый implementation file обязан либо замкнуть один canonical interaction write-side owner, либо удалить один подтверждённый bypass/dual-owner path.
- Каждый новый implementation file обязан иметь одну явную owner-responsibility: selection-state mutation family, prepared scene replacement, pointer semantics, или controller-private mutation channel.
- Каждый изменённый test file обязан доказывать один из контрактов шага: canonical mutation routing, single-import replace-scene, model-free interactive preflight, или single-owner pointer semantics.
- Каждый изменённый doc/tool file обязан механически закреплять новый owner graph, а не описывать временный migration state.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Один controller-private interaction mutation boundary становится единственным write-side owner-ом для всех public `controller.scene.*`, public `controller.selection.*` и gesture-local scene/selection mutations.
2. `SceneControllerSceneMutations`, `SceneControllerSelectionMutations` и `InteractiveSelectionActions` могут остаться только как thin routing shells; они не могут сохранять собственную overlapping mutation semantics.
3. `mutation_op.dart` остаётся typed mutation catalog boundary, а selection-state transitions `replace`, `toggle`, `clear`, `selectAll` получают canonical mutation-family ownership под `MutationExecutor` и не остаются прямыми writer-local set edits.
4. `TxnContext` остаётся transaction root, но прямые правки `workingSelection`, `workingScene` и `changeSet` допустимы только внутри canonical mutation appliers/execution owners, dispatch-имых executor-ом.
5. `replaceScene(...)` обязан материализовать replacement payload ровно один раз в controller-private code до gesture reset; apply path усваивает уже подготовленный runtime scene и не импортирует snapshot повторно.
6. `interactive` layer не импортирует `model/document.dart`; любой snapshot-to-runtime materialization, нужный для selection/action preflight, переносится под controller-private owners ниже `interactive`.
7. Pointer semantics имеют одного dedicated owner-а: tap/double-tap recognition, deferred tap flush и live `PointerInputSettings` adoption не остаются в `scene_view_interactive_pointer_host.dart`.
8. `SceneViewPointerRouter` и raw host admission остаются view-owned leaf responsibility и не переезжают в `interactive` или `controller`.
9. Existing public behavior for active-gesture exclusivity, invalid terminal forwarding, double-tap text edit routing, live pointer-settings apply, selection normalization, epoch invalidation, and revision safety must remain behaviorally equivalent after the owner rewrite.
10. Wrapper layers, whose only effect is to rename the current split owners without deleting the duplicated logic, do not satisfy this change.

## 5. Result Requirements

1. Все scene/selection mutations из public capability surface и interactive gesture flow проходят через один canonical controller-private mutation boundary до любого committed write.
2. `scene_writer_selection.dart` больше не изменяет `TxnContext` напрямую для `writeSelectionReplace(...)`, `writeSelectionToggle(...)`, `writeSelectionClear(...)` и `writeSelectionSelectAll(...)`.
3. Успешный `replaceScene(...)` выполняет snapshot validation/materialization ровно один раз; apply path не содержит второй вызов `txnSceneFromSnapshot(...)`.
4. Ни один файл под `lib/src/interactive/**` не импортирует `model/document.dart`.
5. Один dedicated pointer-semantics owner владеет tap/double-tap recognition, deferred flush scheduling и live `PointerInputSettings` adoption; `scene_view_interactive_pointer_host.dart` остаётся host shell над raw routing и mounted/controller lifecycle.
6. Observable behavior остаётся эквивалентным для invalid terminal handling, text double-tap edit requests, active-gesture mutation exclusivity, live pointer-settings apply, selection replace/toggle/clear/select-all semantics, move commit semantics, replace-scene epoch invalidation и revision allocation.
7. `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `tool/invariant_registry.dart` и guardrails публикуют и механически защищают новый owner graph.

## 6. Implementation Specification

### 6.1 Analysis Scope
- `scene_view_interactive_pointer_host.dart` сейчас владеет `PointerInputTracker`, pending tap timer, applied/pending pointer settings state и вызывает `controller.interaction.handleDoubleTap(...)` после host-local signal tracking.
- `scene_controller_interaction.dart` сейчас владеет public `setPointerSettings(...)` и `handleDoubleTap(...)`, поэтому pointer semantics split between view-local detection and interactive-local public runtime.
- `scene_controller_scene_mutations.dart` сейчас вызывает `txnSceneFromSnapshot(snapshot)` перед `core.writeReplaceScene(snapshot)`.
- `scene_mutation_applier.dart` сейчас повторно импортирует тот же snapshot через `txnSceneFromSnapshot(snapshot, nextInstanceRevision: ctx.txnNextInstanceRevision)`.
- `scene_writer_selection.dart` сейчас напрямую меняет `ctx.workingSelection` и `ctx.changeSet` для `replace`, `toggle`, `clear` и `selectAll`, while `delete`, `translate` и `transform` already route through executor-owned ops.
- `interaction_eligibility_policy.dart` сейчас импортирует `model/document.dart` и использует `txnNodeFromSnapshot(...)` для world-bounds materialization inside `centerWorldForNodeSnapshots(...)`.
- Public and gesture-local scene/selection mutations сейчас размазаны между `SceneControllerSelectionMutations`, `SceneControllerSceneMutations`, `InteractiveSelectionActions`, `SceneCommands` и writer-local exact-result helpers.

### 6.2 Target Verification Units
- `dcm calculate-metrics lib/src/view/scene_view_interactive_pointer_host.dart lib/src/interactive/scene_controller_interaction.dart lib/src/interactive/interaction_eligibility_policy.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/scene_controller_facade_assembly.dart lib/src/interactive/internal/scene_controller_scene_mutations.dart lib/src/interactive/internal/scene_controller_selection_mutations.dart lib/src/interactive/internal/interactive_selection_actions.dart lib/src/controller/scene_writer_selection.dart lib/src/controller/mutation_op.dart lib/src/controller/mutation_executor.dart lib/src/controller/scene_mutation_applier.dart --report-all`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner shard preset: `core`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `controller_internal`
- MCP test runner shard preset: `controller`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`

### 6.3 Protected States, Data, or Structures
- `SceneViewPointerRouter` raw slot allocation, min-free-slot reuse и active-pointer gate.
- Public `SceneWriteTxn` contract and writer lifetime guarantees.
- Selection normalization contract: missing, background, and invisible ids drop; explicit non-selectable ids stay stable.
- Active move/draw gesture ownership and public mutation exclusivity.
- `replaceScene(...)` epoch invalidation, revision allocator correctness и selection reset semantics.
- Text double-tap edit request behavior and monotonic interactive timestamps.

### 6.4 Allowed Semantic Change Zones
- Controller-private mutation ownership for scene and selection entrypoints.
- Selection-state mutation family under `MutationExecutor`.
- Controller-private prepared scene replacement ownership and apply wiring.
- Interactive preflight ownership after removing model materialization from `interactive`.
- Dedicated pointer-semantics ownership beneath the existing public controller/view surface.
- Guardrails, invariant proofs, and public docs required to freeze the new owner graph.

### 6.5 Recognition Forms That Must Be Supported Within This Change
- direct bypass of the canonical mutation boundary by calling `core.commands.writeSelection*`, `core.commands.writeDeleteSelection`, `core.write(...)`, or `core.writeReplaceScene(...)` from interactive mutation callers;
- alias-based bypass where the same calls are hidden behind a local helper, callback, or renamed local variable in capability or gesture code;
- direct `TxnContext` mutation outside canonical mutation appliers via `ctx.workingSelection`, `ctx.workingScene`, or `ctx.changeSet`;
- direct or aliased import/use of `txnSceneFromSnapshot(...)` or `txnNodeFromSnapshot(...)` inside `lib/src/interactive/**`;
- host-local pointer-semantics ownership in `scene_view_interactive_pointer_host.dart` via `PointerInputTracker`, pending tap scheduler, or applied/pending pointer settings state.

### 6.6 Allowed Forms That Do Not Count as Violations
- Прямые `TxnContext` updates внутри canonical mutation appliers/execution owners dispatch-имых `MutationExecutor`.
- `model/document.dart` imports внутри `lib/src/controller/**` или `lib/src/model/**`, если они являются единственным owner-ом materialization/prepared replacement для этого шага.
- Raw pointer routing, slot release и mounted/controller subscription lifecycle внутри view-host shell.
- Thin public and internal routing shells, которые только делегируют в canonical owner without re-owning mutation semantics.

### 6.7 Requirements for Resolution of Links and Structural Analysis
- New canonical mutation ownership may be split into focused controller-private files, but every public or gesture-local scene/selection mutation caller must resolve directly to that boundary rather than to `SceneControllerCore.commands` or ad hoc `core.write(...)` bodies.
- If a prepared replacement payload is introduced, it must carry all data required to avoid a second model import, including the resolved runtime scene and allocator state needed by the apply path.
- Interactive preflight helpers may depend on controller-private facades, but no file under `lib/src/interactive/**` may resolve model materialization by importing `document.dart` directly.
- Structural guardrails added or updated in this step must detect the bypass forms from section `6.5` through AST-based analysis or an equivalent structural mechanism; string-grep-only enforcement is not sufficient for closure.

### 6.8 Prohibited
- Сохранять `SceneControllerSceneMutations`, `SceneControllerSelectionMutations` и `InteractiveSelectionActions` как parallel mutation owners с overlapping preflight/apply semantics.
- Валидировать или материализовать `replaceScene(...)` в `interactive` или `view`, а потом повторять import в controller apply path.
- Оставлять `PointerInputTracker`, pending tap timer и live pointer-settings state в `scene_view_interactive_pointer_host.dart` после ввода dedicated pointer-semantics owner-а.
- Добавлять sync glue, который зеркалит selection state, prepared scene state или pointer settings между двумя mutable owner-ами.
- Расширять public API ради этого шага или делать prepared replacement payload / canonical mutation boundary частью public contract.
- Закрывать шаг metric-only wrappers, не удаляющими фактический split owner logic.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the trigger point must be attached.
7. If a slice changes a structural guardrail, both bypass and non-bypass cases must be covered where applicable to this subject.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Canonical Selection-State Mutation Family

#### Slice Contract

Selection replace, toggle, clear, and select-all transitions execute only through a canonical executor-owned mutation family instead of direct writer-local `TxnContext` edits.

#### Change

Introduce a dedicated canonical mutation-family owner for selection-state transitions, route writer selection methods and exact-result helpers through that family, and delete the replaced direct `TxnContext` mutation bodies from `scene_writer_selection.dart`.

#### Verification
- `dcm calculate-metrics lib/src/controller/scene_writer_selection.dart lib/src/controller/mutation_op.dart lib/src/controller/mutation_executor.dart --report-all`
- `dart run tool/check_guardrails.dart`
- MCP test runner shard preset: `controller_internal`
- MCP test runner shard preset: `controller`

#### Positive Scenarios
- `writeSelectionReplace(...)`, `writeSelectionToggle(...)`, `writeSelectionClear(...)`, and `writeSelectionSelectAll(...)` preserve current exact-result and normalization behavior.
- Selection exact-result helpers keep stable sorted payload semantics for command emitters.

#### Negative Scenarios
- Missing, background, and invisible ids remain ignored by selection replace/toggle.
- Direct writer-local `ctx.workingSelection` and `ctx.changeSet` edits no longer exist outside canonical mutation appliers.

#### Closure Evidence
- green run of the listed verifications;
- `scene_writer_selection.dart` no longer contains direct writes to `ctx.workingSelection` or `ctx.changeSet`.

### Slice 2. [x] Canonical Interaction Mutation Boundary

#### Slice Contract

Public scene/selection mutations and gesture-local scene/selection writes route through one controller-private mutation boundary instead of competing interactive owners.

#### Change

Introduce one controller-private mutation boundary consumed by public capability shells and gesture-local write paths, then delete or thin the replaced overlapping mutation ownership from `SceneControllerSceneMutations`, `SceneControllerSelectionMutations`, and `InteractiveSelectionActions`.

#### Verification
- `dcm calculate-metrics lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/scene_controller_facade_assembly.dart lib/src/interactive/internal/scene_controller_scene_mutations.dart lib/src/interactive/internal/scene_controller_selection_mutations.dart lib/src/interactive/internal/interactive_selection_actions.dart --report-all`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `controller`
- MCP test runner shard preset: `interactive`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios
- Public `controller.scene.*` and `controller.selection.*` entrypoints use the same mutation owner graph as move/delete/transform/clear gesture flows.
- Action emission, timestamp resolution, and gesture-local write semantics stay behaviorally equivalent.

#### Negative Scenarios
- Active-gesture deny/reset semantics remain intact for public external mutations.
- `notifySceneChanged()` remains outside committed mutation ownership and does not become part of the write boundary.

#### Closure Evidence
- green run of the listed verifications;
- listed interactive mutation callers no longer invoke `core.commands.writeSelection*`, `core.write(...)`, or `core.writeReplaceScene(...)` directly for scene/selection mutation behavior.

### Slice 3. [ ] Single-Import ReplaceScene And Model-Free Interactive Preflight

#### Slice Contract

`replaceScene(...)` validates and materializes input exactly once in controller-private code, and `interactive` no longer imports model materialization helpers.

#### Change

Introduce a prepared scene-replacement owner that materializes runtime scene plus allocator state once, adapt the apply path to adopt the prepared payload without reimport, and move any selection/action preflight materialization needed by `interactive` behind controller-private owners so `lib/src/interactive/**` becomes model-free.

#### Verification
- `dcm calculate-metrics lib/src/interactive/interaction_eligibility_policy.dart lib/src/interactive/internal/scene_controller_scene_mutations.dart lib/src/controller/scene_mutation_applier.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `controller`
- MCP test runner shard preset: `interactive`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios
- Valid `replaceScene(...)` preserves committed snapshot replacement, epoch invalidation, selection reset, and revision allocation behavior.
- Rotate, flip, delete, and move-commit preflight keep their current selection ordering and center/bounds semantics.

#### Negative Scenarios
- Invalid `replaceScene(...)` preserves active gesture state and does not partially mutate controller state.
- No file under `lib/src/interactive/**` imports `model/document.dart`.
- Successful `replaceScene(...)` does not call `txnSceneFromSnapshot(...)` twice.

#### Closure Evidence
- green run of the listed verifications;
- structural proof that `lib/src/interactive/**` has no direct `document.dart` import;
- source proof that the replace-scene apply path consumes a prepared payload instead of reimporting the snapshot.

### Slice 4. [ ] Dedicated Pointer-Semantics Owner

#### Slice Contract

Tap/double-tap recognition, deferred tap flushing, and live pointer-settings adoption live under one dedicated pointer-semantics owner, while `SceneView` keeps only raw host routing and lifecycle.

#### Change

Extract pointer semantics into one dedicated owner beneath the existing public controller/view surface, rewire `scene_view_interactive_pointer_host.dart` into a raw host shell over router and lifecycle only, and delete the replaced host-local tracker, timer, and applied/pending settings ownership.

#### Verification
- `dcm calculate-metrics lib/src/view/scene_view_interactive_pointer_host.dart lib/src/interactive/scene_controller_interaction.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart --report-all`
- `dart run tool/check_guardrails.dart`
- MCP test runner shard preset: `core`
- MCP test runner shard preset: `interactive`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios
- View-routed text double tap still emits the existing edit-text request behavior.
- Pointer settings update live on the same controller without remount, keep last-write-wins semantics, and still wait for router idle before taking effect.
- Direct public pointer entrypoints remain supported.

#### Negative Scenarios
- Stray non-down host events are still dropped before controller routing.
- Raw slot reuse and single active signal-tracking gate stay unchanged.
- `scene_view_interactive_pointer_host.dart` no longer instantiates `PointerInputTracker` or owns pending tap scheduler/settings transition state.

#### Closure Evidence
- green run of the listed verifications;
- source proof that `scene_view_interactive_pointer_host.dart` is reduced to raw routing and lifecycle shell responsibilities only.

## 9. Final Verification

- `dcm calculate-metrics lib/src/view/scene_view_interactive_pointer_host.dart lib/src/interactive/scene_controller_interaction.dart lib/src/interactive/interaction_eligibility_policy.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/scene_controller_facade_assembly.dart lib/src/interactive/internal/scene_controller_scene_mutations.dart lib/src/interactive/internal/scene_controller_selection_mutations.dart lib/src/interactive/internal/interactive_selection_actions.dart lib/src/controller/scene_writer_selection.dart lib/src/controller/mutation_op.dart lib/src/controller/mutation_executor.dart lib/src/controller/scene_mutation_applier.dart --report-all`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `core`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `controller_internal`
- MCP test runner shard preset: `controller`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`
- MCP test runner shard preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
- Repo docs, invariants, and structural guardrails describe and enforce the same owner graph without split-source fallback wording.
