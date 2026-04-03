language: russian

# Change Contract

## 1. Change Mandate

This change migrates routed pointer boundary ownership from `core` into `contract` so the `contract` layer no longer depends on `core/pointer_input.dart` and the import-boundary DAG becomes mechanically exact again.

## 2. Change Boundary

### Included in the Change

- Перенос owner-ов `PointerPhase`, `PointerSample`, `PointerInputSettings` и boundary validation настроек из `core` в `contract/pointer_input.dart`.
- Переименование current core pointer owner-а в `core/pointer_input_tracker.dart` и пересборка его как core-local tracker/signal owner-а, который потребляет contract-owned pointer boundary types вместо объявления их у себя.
- Перепривязка `contract/**`, `interactive/**`, `view/**` и package entrypoint к новым contract-owned pointer boundary файлам без public API drift.
- Удаление special-case bridge для `/lib/src/core/pointer_input.dart` из import-boundary policy и обновление tool-tests, guardrails, архитектурного source of truth и roadmap.

### Not Included in the Change

- Изменение tap/double-tap semantics, signal ordering, raw-to-routed pointer routing или apply-on-idle policy для `PointerInputSettings`.
- Изменение публичных `CanvasPointerInput` / `CanvasPointerPhase` semantics или добавление `PointerSample` / `PointerPhase` в package-root exports.
- Переписывание `PointerInputTracker` алгоритма, gesture orchestration или view host lifecycle сверх required import/owner rewiring.
- Любые новые sync-механизмы между `contract` и `core`.

## 3. File Map and Analysis Areas

### Implementation Files

- [lib/src/core/pointer_input_tracker.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input_tracker.dart)
- [lib/src/contract/scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_view_runtime.dart)
- [lib/src/contract/pointer_phase_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_phase_codec.dart)
- [lib/src/interactive/scene_controller.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller.dart)
- [lib/src/interactive/scene_controller_interaction.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interaction.dart)
- [lib/src/interactive/internal/scene_controller_graph.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_graph.dart)
- [lib/src/interactive/internal/scene_controller_interaction_config.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_config.dart)
- [lib/src/interactive/internal/scene_controller_pointer_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_pointer_session.dart)
- [lib/src/interactive/internal/interactive_pointer_normalizer.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_pointer_normalizer.dart)
- [lib/src/interactive/internal/interactive_gesture_router.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_gesture_router.dart)
- [lib/src/interactive/internal/interactive_draw_terminal_router.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_terminal_router.dart)
- [lib/src/interactive/internal/interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart)
- [lib/src/interactive/internal/interactive_move_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart)
- [lib/src/interactive/internal/interactive_move_commit_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_commit_coordinator.dart)
- [lib/src/view/scene_view_pointer_router.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_pointer_router.dart)
- [lib/src/view/scene_view_runtime_host.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_runtime_host.dart)
- [lib/src/view/scene_view_interactive_pointer_host.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart)
- [lib/iwb_canvas_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/iwb_canvas_engine.dart)
- [tool/src/import_boundaries/import_boundary_policy.dart](/Users/blackpika/iwb_canvas_engine/tool/src/import_boundaries/import_boundary_policy.dart)
- [tool/src/guardrails/public_surface_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/src/guardrails/public_surface_guardrails.dart)
- [lib/src/contract/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_input.dart)

### Test Files

- [test/contract/runtime_contract_interfaces_test.dart](/Users/blackpika/iwb_canvas_engine/test/contract/runtime_contract_interfaces_test.dart)
- [test/core/pointer_input_test.dart](/Users/blackpika/iwb_canvas_engine/test/core/pointer_input_test.dart)
- [test/view/scene_view_pointer_router_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_pointer_router_test.dart)
- [test/view/scene_view_interactive_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_interactive_test.dart)
- [test/interactive/core/scene_controller_interactive_basics_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart)
- [test/entrypoints/basic_smoke_test.dart](/Users/blackpika/iwb_canvas_engine/test/entrypoints/basic_smoke_test.dart)
- [test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart](/Users/blackpika/iwb_canvas_engine/test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart)
- [test/tool/guardrails/guardrails_public_surface_tool_test.dart](/Users/blackpika/iwb_canvas_engine/test/tool/guardrails/guardrails_public_surface_tool_test.dart)
- [test/tool/public_api_surface_tool_test.dart](/Users/blackpika/iwb_canvas_engine/test/tool/public_api_surface_tool_test.dart)

### Fixture and Supporting Data Files

- [test/tool/support/public_entrypoint_contract.dart](/Users/blackpika/iwb_canvas_engine/test/tool/support/public_entrypoint_contract.dart)
- [ARCHITECTURE.md](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md)
- [plan/contract_target_architecture.md](/Users/blackpika/iwb_canvas_engine/plan/contract_target_architecture.md)
- [PLAN.md](/Users/blackpika/iwb_canvas_engine/PLAN.md)
- [plan/step_86_pointer_boundary_contract_core_detachment.md](/Users/blackpika/iwb_canvas_engine/plan/step_86_pointer_boundary_contract_core_detachment.md)

### Analysis Area

- `lib/src/contract/**`
- `lib/src/core/**`
- `lib/src/interactive/**`
- `lib/src/view/**`
- `tool/src/import_boundaries/**`
- `tool/src/guardrails/**`
- `test/contract/**`
- `test/core/**`
- `test/view/**`
- `test/interactive/**`
- `test/tool/import_boundaries/**`
- `test/tool/guardrails/**`
- `test/tool/support/public_entrypoint_contract.dart`
- `ARCHITECTURE.md`, `plan/contract_target_architecture.md`, `PLAN.md`, `plan/step_86_pointer_boundary_contract_core_detachment.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one of the slices below.
- Every modified test must prove one of the locked results below.
- Every modified supporting file must pin the resulting owner graph, public-entrypoint owner manifest, or roadmap state.
- Every newly proposed file or directory name must comply with the global `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. The fix is architectural, not documentary: `contract` must stop depending on `core/pointer_input_tracker.dart`; the bridge is not kept and merely re-described.
2. `PointerPhase`, `PointerSample`, `PointerInputSettings`, and settings validation become contract-owned boundary artifacts in this change.
3. `PointerInputTracker`, `PointerSignalType`, and `PointerSignal` remain core-owned runtime helpers in [lib/src/core/pointer_input_tracker.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input_tracker.dart).
4. The public package symbol set remains stable; `PointerInputSettings` stays available from [lib/iwb_canvas_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/iwb_canvas_engine.dart), and `PointerSample` / `PointerPhase` do not become new package-root exports.
5. `CanvasPointerInput` / `CanvasPointerPhase` remain the public host-facing input contract; this step changes internal owner placement only.
6. The new owner graph must be enforced mechanically through tool policy, tool tests, and runtime tests; prose-only closure is not acceptable.

## 5. Result Requirements

1. [lib/src/contract/scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_view_runtime.dart) and [lib/src/contract/pointer_phase_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_phase_codec.dart) no longer import the core tracker owner.
2. `PointerPhase`, `PointerSample`, `PointerInputSettings`, and `validatePointerInputSettings` are declared in [lib/src/contract/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_input.dart), while [lib/src/core/pointer_input_tracker.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input_tracker.dart) keeps only core-owned pointer tracker and signal logic.
3. `tool/check_import_boundaries.dart` rejects `contract -> core/pointer_input_tracker.dart` imports because `contract` no longer depends on a core pointer owner.
4. The package root still exports `PointerInputSettings`, and the public API symbol set remains unchanged.
5. Pointer router behavior, pointer-session behavior, tracker validation, and apply-on-idle settings semantics remain behaviorally equivalent to the pre-change runtime.
6. [ARCHITECTURE.md](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md), [plan/contract_target_architecture.md](/Users/blackpika/iwb_canvas_engine/plan/contract_target_architecture.md), [PLAN.md](/Users/blackpika/iwb_canvas_engine/PLAN.md), and this step document describe the new pointer owner graph and no longer imply a sanctioned `contract -> core/pointer_input.dart` dependency.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `PointerPhase`, `PointerSample`, and `PointerInputSettings` are currently declared in [lib/src/core/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input.dart) even though `contract` code consumes them directly.
- [lib/src/contract/scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_view_runtime.dart) and [lib/src/contract/pointer_phase_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_phase_codec.dart) currently import `../core/pointer_input.dart`.
- [tool/src/import_boundaries/import_boundary_policy.dart](/Users/blackpika/iwb_canvas_engine/tool/src/import_boundaries/import_boundary_policy.dart) currently declares `contract -> none` in the layer DAG and separately whitelists `/lib/src/core/pointer_input.dart` as a bridge friend for `contract`.
- [lib/iwb_canvas_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/iwb_canvas_engine.dart) currently exports `PointerInputSettings` from `src/core/pointer_input.dart`.
- `PointerInputSettings` validation is currently invoked from public runtime boundaries such as [lib/src/interactive/scene_controller_interaction.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interaction.dart) and controller graph assembly in [lib/src/interactive/internal/scene_controller_graph.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_graph.dart).

### 6.2 Target Verification Units

- MCP test runner: [test/contract/runtime_contract_interfaces_test.dart](/Users/blackpika/iwb_canvas_engine/test/contract/runtime_contract_interfaces_test.dart)
- MCP test runner: [test/core/pointer_input_test.dart](/Users/blackpika/iwb_canvas_engine/test/core/pointer_input_test.dart)
- MCP test runner: [test/view/scene_view_pointer_router_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_pointer_router_test.dart)
- MCP test runner: [test/view/scene_view_interactive_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_interactive_test.dart)
- MCP test runner: [test/interactive/core/scene_controller_interactive_basics_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart)
- MCP test runner: [test/entrypoints/basic_smoke_test.dart](/Users/blackpika/iwb_canvas_engine/test/entrypoints/basic_smoke_test.dart)
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/public_api_surface_tool_test.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dcm calculate-metrics`

### 6.3 Protected States, Data, or Structures

- `PointerInputTracker` tap/double-tap state machine and emitted `PointerSignalType` sequence.
- `SceneView` raw-pointer admission, routed pointer id allocation, terminal cleanup, and pending-tap flush lifecycle.
- `SceneControllerInteraction` apply-on-idle handling for `PointerInputSettings`.
- The public package export symbol set recorded by [tool/goldens/public_api_symbols.txt](/Users/blackpika/iwb_canvas_engine/tool/goldens/public_api_symbols.txt).

### 6.4 Allowed Semantic Change Zones

- Ownership and file placement of routed pointer boundary value types and settings validation.
- Import rewiring inside `contract/**`, `interactive/**`, `view/**`, and `core/**` to consume the new owner files.
- Package-root export owner path for `PointerInputSettings`.
- Import-boundary tool policy and its regression tests for the removed `contract -> core` bridge.
- Architecture and roadmap documents that describe the contract/core pointer owner graph.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- [lib/src/contract/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_input.dart) must declare `PointerPhase`, `PointerSample`, `PointerInputSettings`, and `validatePointerInputSettings`.
- [lib/src/core/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input.dart) must be renamed to [lib/src/core/pointer_input_tracker.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input_tracker.dart).
- [lib/src/core/pointer_input_tracker.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input_tracker.dart) must retain `PointerSignalType`, `PointerSignal`, `PointerInputTracker`, and private pointer-local helper owners; it must import contract-owned pointer boundary types/settings instead of declaring them.
- [lib/src/contract/scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_view_runtime.dart) and [lib/src/contract/pointer_phase_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_phase_codec.dart) must import [lib/src/contract/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_input.dart), not the core tracker owner.
- Files under `interactive/**` and `view/**` may continue to import [lib/src/core/pointer_input_tracker.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input_tracker.dart) only where they need tracker/signal owners; every use of `PointerPhase`, `PointerSample`, `PointerInputSettings`, or `validatePointerInputSettings` must import [lib/src/contract/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_input.dart) directly.
- [lib/iwb_canvas_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/iwb_canvas_engine.dart) and [test/tool/support/public_entrypoint_contract.dart](/Users/blackpika/iwb_canvas_engine/test/tool/support/public_entrypoint_contract.dart) must switch the `PointerInputSettings` export owner from `src/core/pointer_input.dart` to `src/contract/pointer_input.dart` without changing the exported symbol list.
- [tool/src/import_boundaries/import_boundary_policy.dart](/Users/blackpika/iwb_canvas_engine/tool/src/import_boundaries/import_boundary_policy.dart) must remove the `/lib/src/core/pointer_input.dart` bridge descriptor entry instead of broadening `_allowedLayerDependencies` for `contract`.
- [test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart](/Users/blackpika/iwb_canvas_engine/test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart) must replace the existing positive proof for `contract -> core pointer_input bridge import` with a negative proof that the same dependency path now fails after the core owner is renamed to `pointer_input_tracker.dart`.
- [tool/src/guardrails/public_surface_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/src/guardrails/public_surface_guardrails.dart) must stop treating `/lib/src/core/pointer_input.dart` as a directly exported non-contract public owner once [lib/iwb_canvas_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/iwb_canvas_engine.dart) no longer exports it.
- [plan/contract_target_architecture.md](/Users/blackpika/iwb_canvas_engine/plan/contract_target_architecture.md) and [ARCHITECTURE.md](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md) must describe the new pointer boundary ownership explicitly so the contract target state and layer DAG match the tool-enforced graph.

### 6.8 Prohibited

- Keeping `PointerPhase`, `PointerSample`, or `PointerInputSettings` declared in the core tracker owner after the change.
- Solving the mismatch by allowing `contract -> core` in `_allowedLayerDependencies`.
- Replacing the removed bridge with a new bridge path or a generic “pointer support” helper bucket.
- Changing public pointer semantics, signal sequencing, or adding new package-root pointer exports as part of this step.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes an import-boundary rule, both the removed exception and the preserved allowed imports must be covered by tool verification.
7. Scope expansion is forbidden until the mandatory slices are closed.
8. The plan must be detailed enough that the implementing agent has no material branch in how to execute a slice.
9. Every newly proposed file or directory name must comply with the global `AGENTS.md` section `### File naming`.
10. If implementation reveals that `PointerSignal` or tracker validation must also move into `contract` to keep the build green, execution must stop and that architectural expansion must be explicitly confirmed before continuing.

## 8. Vertical Slices

### Slice 1. [ ] Contract-Owned Routed Pointer Boundary

#### Slice Contract

`contract/**` consumes routed pointer sample/phase/settings types from [lib/src/contract/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_input.dart), while [lib/src/core/pointer_input_tracker.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input_tracker.dart) contains only tracker/signal logic over those types.

#### Change

Create [lib/src/contract/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_input.dart) for `PointerPhase`, `PointerSample`, `PointerInputSettings`, and `validatePointerInputSettings`. Rename [lib/src/core/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input.dart) to [lib/src/core/pointer_input_tracker.dart](/Users/blackpika/iwb_canvas_engine/lib/src/core/pointer_input_tracker.dart), then rewrite it so it imports the contract-owned pointer boundary and keeps only `PointerSignalType`, `PointerSignal`, `PointerInputTracker`, and private tracker helpers. Rewire [lib/src/contract/scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_view_runtime.dart), [lib/src/contract/pointer_phase_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_phase_codec.dart), the listed `interactive/**` files, and the listed `view/**` files so every reference to pointer boundary types/settings imports [lib/src/contract/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_input.dart) directly.

#### Verification

- MCP test runner: [test/contract/runtime_contract_interfaces_test.dart](/Users/blackpika/iwb_canvas_engine/test/contract/runtime_contract_interfaces_test.dart)
- MCP test runner: [test/core/pointer_input_test.dart](/Users/blackpika/iwb_canvas_engine/test/core/pointer_input_test.dart)
- MCP test runner: [test/view/scene_view_pointer_router_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_pointer_router_test.dart)
- MCP test runner: [test/view/scene_view_interactive_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_interactive_test.dart)
- MCP test runner: [test/interactive/core/scene_controller_interactive_basics_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart)
- `dcm calculate-metrics`

#### Positive Scenarios

- `SceneViewRuntime` and pointer phase codec compile against contract-owned `PointerSample` / `PointerPhase`.
- `PointerInputTracker` continues to validate `PointerInputSettings` and emit the same lifecycle and tap/double-tap signals.
- `SceneControllerInteraction` and controller construction continue to reject invalid pointer settings and preserve apply-on-idle behavior.

#### Negative Scenarios

- No `contract/**` production file imports the core tracker owner.
- No second copy of `PointerInputSettings` validation remains under `core/**`.

#### Closure Evidence

- Green run of the listed verifications.
- Source proof that [lib/src/contract/scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_view_runtime.dart) and [lib/src/contract/pointer_phase_codec.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_phase_codec.dart) import [lib/src/contract/pointer_input.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/pointer_input.dart) instead of the core tracker owner.

### Slice 2. [ ] Import-Boundary, Public Surface, and Roadmap Closure

#### Slice Contract

The removed `contract -> core` pointer exception is mechanically rejected by tooling, the package root still exports `PointerInputSettings`, and the roadmap/source-of-truth documents describe the new owner graph.

#### Change

Switch [lib/iwb_canvas_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/iwb_canvas_engine.dart) and [test/tool/support/public_entrypoint_contract.dart](/Users/blackpika/iwb_canvas_engine/test/tool/support/public_entrypoint_contract.dart) to the new `src/contract/pointer_input.dart` export owner. Remove the `/lib/src/core/pointer_input.dart` bridge descriptor from [tool/src/import_boundaries/import_boundary_policy.dart](/Users/blackpika/iwb_canvas_engine/tool/src/import_boundaries/import_boundary_policy.dart). Update [test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart](/Users/blackpika/iwb_canvas_engine/test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart) so the former `contract -> core/pointer_input.dart` dependency path is a failure case and the remaining allowed imports are described by their non-bridge semantics. Remove the no-longer-needed direct-export scan policy for `/lib/src/core/pointer_input.dart` from [tool/src/guardrails/public_surface_guardrails.dart](/Users/blackpika/iwb_canvas_engine/tool/src/guardrails/public_surface_guardrails.dart). Update [ARCHITECTURE.md](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md), [plan/contract_target_architecture.md](/Users/blackpika/iwb_canvas_engine/plan/contract_target_architecture.md), [PLAN.md](/Users/blackpika/iwb_canvas_engine/PLAN.md), and this step document to pin the new pointer owner graph.

#### Verification

- MCP test runner: [test/entrypoints/basic_smoke_test.dart](/Users/blackpika/iwb_canvas_engine/test/entrypoints/basic_smoke_test.dart)
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/public_api_surface_tool_test.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Positive Scenarios

- `PointerInputSettings` remains available from `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- Tooling still allows legal `interactive -> core` imports where `core` ownership actually remains, without preserving a contract-only exception.

#### Negative Scenarios

- `contract -> core` pointer dependency fails as a layer DAG violation after the core owner rename.
- No public-surface scaffold or guardrail manifest still claims `src/core/pointer_input.dart` as the package-root export owner for `PointerInputSettings`.

#### Closure Evidence

- Green run of the listed verifications.
- Tool diagnostic proof that the removed `contract -> core/pointer_input.dart` import is now rejected.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics`
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
