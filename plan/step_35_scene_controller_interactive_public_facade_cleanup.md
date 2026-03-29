language: russian

# Шаг 35. Дожать `SceneControllerInteractive` до чистого public facade без line-write и test-access ownership

## 1. Change Mandate

Этот шаг убирает из `SceneControllerInteractive` остаточное line-write и
test-access ownership, сохраняя его единственным public interactive facade без
изменения public interactive behavior.

## 2. Change Boundary

### Included in the Change

- Public-facade ownership in `scene_controller_interactive.dart`.
- Controller-owned draw write surface required to remove facade-local
  world-segment line commit logic.
- Shared draw-style contract currently tied to
  `interactive_draw_line_engine.dart`.
- Test/debug access surface currently mixed into the public facade file.
- Structural non-regression coverage required to pin the tightened facade
  boundary.

### Not Included in the Change

- Reopening runtime boundary ownership from steps `32-34`.
- Eraser exact-hit geometry decomposition beneath
  `interactive_draw_eraser_engine.dart`.
- Draw-family orchestration changes in `interactive_draw_coordinator.dart`.
- Public API changes for `SceneControllerInteractive`, `CanvasPointerInput`,
  `actions`, `editTextRequests`, or line-tool behavior.
- View-side raw pointer routing ownership.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/internal/interactive_draw_line_engine.dart`
- `lib/src/interactive/internal/interactive_draw_action_emitter.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart`
- `lib/src/interactive/internal/interactive_runtime_callbacks.dart`
- `lib/src/controller/commands/draw_commands.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/controller/commands/draw_commands_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_line_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_eraser_lifecycle_test.dart`
- `test/interactive/test_support/interactive_controller_fixtures.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/step_35_scene_controller_interactive_public_facade_cleanup.md`

### Analysis Area

- `lib/src/interactive/**`
- `lib/src/controller/commands/draw_commands.dart`
- `test/interactive/**`
- `test/controller/commands/draw_commands_test.dart`
- `tool/src/guardrails/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must remove one remaining non-facade owner
  from `SceneControllerInteractive` or become one focused owner that replaces
  that residual responsibility.
- Every modified structural test or guardrail must pin the tightened
  facade/controller boundary introduced by this step.
- Every modified test-support file must be tied directly to the moved
  test/debug access surface.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneControllerInteractive` remains the only public interactive facade.
2. `SceneControllerCore` remains the owner of committed writes.
3. Draw-family orchestration remains beneath the interactive runtime boundary
   and does not move back into the public facade.
4. Interactive line commits must preserve the current world-segment semantics
   currently produced by `_writeDrawLineFromWorldSegment(...)` in the facade.
5. This step must not introduce a wrapper assembly layer whose primary purpose
   is to reduce facade metrics without transferring real ownership.

## 5. Result Requirements

1. `SceneControllerInteractive` no longer owns facade-local line write commit
   logic for draw-line insertion.
2. One controller-owned draw write entrypoint exists for the current
   world-segment line commit semantics used by interactive draw-line flow.
3. The shared draw-style contract used across runtime and draw owners lives in
   one focused owner outside both `scene_controller_interactive.dart` and
   `interactive_draw_line_engine.dart`.
4. Test/debug access used by interactive tests no longer lives in the public
   facade file.
5. Public interactive behavior remains equivalent for:
   line drag commit,
   line tap-to-start and tap-to-finish flow,
   pending-line timeout and cancel cleanup,
   move-commit delta resolver fail-fast,
   eraser debug counters exposed to interactive tests,
   and dispose fail-fast behavior.
6. Structural tests and guardrails fail if `scene_controller_interactive.dart`
   reabsorbs committed line write logic, shared draw-style ownership, or
   test/debug access surface removed by this step.
7. The measured facade hotspot improves against the current confirmed residual
   scope as evidence of owner transfer, and metric improvement alone does not
   close the step:
   file imports `23`,
   class `CBO 29`,
   `RFC 115`,
   `WMC 113`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `scene_controller_interactive.dart` currently mixes public facade ownership
  with:
  top-level test/debug access functions,
  facade-local line world-segment commit logic,
  and a shared draw-style contract imported from
  `interactive_draw_line_engine.dart`.
- `draw_commands.dart` already owns `writeDrawStroke(...)`,
  `writeDrawLine(...)`, and `writeEraseNodes(...)`, but it does not yet own the
  centered world-segment line commit shape used by interactive draw-line flow.
- `interactive_draw_line_engine.dart`,
  `interactive_draw_action_emitter.dart`, and
  `interactive_runtime_callbacks.dart` currently depend on
  `InteractiveDrawStyle` through the line-engine file rather than through one
  shared contract owner.
- Interactive tests currently import facade-level test access functions through
  `scene_controller_interactive.dart`, which keeps test/debug access mixed into
  the public facade file.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/controller/commands/draw_commands.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/controller/commands/draw_commands_test.dart`
- MCP test runner: `test/interactive`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Public interactive API shape and public host-facing behavior.
- Current centered world-segment semantics for interactive line commits.
- Pending-line timeout lifecycle and cancel cleanup.
- Reentrant `moveCommitDeltaResolver(...)` fail-fast behavior.
- Interactive test-visible debug counters and hook access.

### 6.4 Allowed Semantic Change Zones

- Controller-owned committed draw-line write surface.
- Shared draw-style contract ownership beneath the interactive layer.
- Test/debug access ownership beneath the interactive layer.
- Facade/runtime wiring required to keep `SceneControllerInteractive` thin over
  runtime, selection, and controller write owners.
- Structural source-level contract tests and guardrails tied directly to the
  tightened facade boundary.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct reabsorption of line-write helper logic into `SceneControllerInteractive`
- private-helper bypass where moved line-write logic stays inside the facade
  under another private helper name
- alias-based reuse where `InteractiveDrawStyle` remains owned by
  `interactive_draw_line_engine.dart` under a renamed export
- local-function bypass where test/debug access remains in the facade file but
  is hidden behind local or private wrappers

### 6.6 Allowed Forms That Do Not Count as Violations

- Public facade methods delegating into runtime, selection owners, or
  controller commands.
- Controller-owned draw commands owning committed line write semantics on behalf
  of interactive draw flow.
- A focused shared draw-style contract file used by multiple draw/runtime
  owners.
- A focused debug/test access file used only by `test/**` support.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- This step must preserve the step-`34` interactive boundary shape and tighten
  it further; it must not reopen runtime/event/draw-family mixed ownership as
  the subject of change.
- Any new focused owner created by this step for shared draw-style or
  test/debug access must remain under `lib/src/interactive/`.
- Any new controller write entrypoint created by this step must stay under
  `lib/src/controller/commands/` and must preserve the current interactive
  world-segment line commit semantics instead of substituting the existing
  `writeDrawLine(...)` shape.
- Structural assertions introduced or updated by this step must read the final
  facade file graph directly enough to fail when line-write or test/debug
  ownership returns to `scene_controller_interactive.dart`.
- The step is not closed if the facade keeps line-write ownership through a
  local closure, partial application, or private helper that still performs
  world-segment conversion or committed draw-line parameter binding on behalf
  of controller draw commands.

### 6.8 Prohibited

- Changing interactive line commit semantics for the primary purpose of
  simplifying controller draw commands.
- Introducing a second public controller or a facade-assembly wrapper.
- Leaving the shared draw-style contract owned by
  `interactive_draw_line_engine.dart`.
- Reparking the removed line-write helper in another interactive-layer helper
  or inside `InteractiveRuntime` instead of transferring committed ownership to
  controller draw commands.
- Leaving test/debug access mixed into `scene_controller_interactive.dart`
  behind renamed helpers.
- Treating metric improvement as sufficient evidence without owner transfer and
  structural pinning.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be
   covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Controller draw owner replaces facade-local line write bridge

#### Slice Contract

Committed interactive draw-line writes no longer originate from facade-local
write logic in `SceneControllerInteractive`.

#### Change

Introduce one controller-owned write entrypoint for the current interactive
world-segment line commit semantics, move shared draw-style ownership out of
`interactive_draw_line_engine.dart`, and rewire interactive line commit flow to
the new owner without widening the public facade.

#### Verification

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/controller/commands/draw_commands.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/controller/commands/draw_commands_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

#### Positive Scenarios

- Interactive line drag still commits one line with the current world-segment
  semantics.
- Interactive two-tap line flow still creates the same committed line shape and
  action payload.
- `DrawCommands` owns the interactive line commit write path instead of the
  facade.

#### Negative Scenarios

- Pending line still clears on timeout and on pointer `cancel`.
- Reentrant `moveCommitDeltaResolver(...)` still fails fast during interactive
  entrypoints.
- The step does not replace current interactive world-segment line commit with
  the existing local-segment `writeDrawLine(...)` shape.
- The step does not keep committed draw-line parameter binding in a facade-local
  closure or private adapter around controller draw commands.

#### Closure Evidence

- Green run of the listed verifications.
- Source proof that `scene_controller_interactive.dart` no longer contains the
  moved line-write helper body.

### Slice 2. [x] Public facade file no longer owns test/debug access surface

#### Slice Contract

Interactive tests continue to access the required debug/test hooks without
keeping that surface inside the public facade file.

#### Change

Move facade-level test/debug access into one focused non-public owner and
extend structural tests / guardrails so the tightened facade boundary fails if
test/debug or line-write ownership returns to `scene_controller_interactive.dart`.

#### Verification

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart --report-all`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/interactive`
- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Interactive tests still access before-pointer-dispatch hook, move-commit
  delta resolver test path, gesture-buffer helper, and eraser debug counters.
- Structural tests and guardrails accept the tightened final facade shape.

#### Negative Scenarios

- Structural proof fails if test/debug access helpers return to
  `scene_controller_interactive.dart`.
- Structural proof fails if committed line-write logic returns to the facade
  file under a renamed private helper.

#### Closure Evidence

- Green run of the listed verifications.
- Diagnostic output from the new or updated structural proof when the banned
  facade-local forms are reintroduced.

## 9. Final Verification

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/controller/commands/draw_commands.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/controller/commands/draw_commands_test.dart`
- MCP test runner: `test/interactive`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
