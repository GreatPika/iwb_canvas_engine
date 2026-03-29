language: russian

# Шаг 19.5. Сделать SceneControllerInteractive тонким facade над pointer/gesture runtime

## 1. Change Mandate

Этот шаг делает `SceneControllerInteractive` тонким facade over pointer and
gesture runtime so interactive public owner no longer mixes settings, pointer
dispatch, and gesture orchestration in one class body.

## 2. Change Boundary

### Included in the Change

- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator.dart`
- `lib/src/interactive/internal/interactive_event_dispatcher.dart`
- `lib/src/interactive/internal/interactive_gesture_machine.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`

### Not Included in the Change

- `SceneViewInteractive`
- Render/view cache lifecycle
- Controller write pipeline and invariant sweep

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator.dart`
- `lib/src/interactive/internal/interactive_event_dispatcher.dart`
- `lib/src/interactive/internal/interactive_gesture_machine.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`

### Test Files

- `test/interactive/**`
- `test/view/scene_view_interactive_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `plan/step_19_5_scene_controller_interactive_facade_thinning.md`

### Analysis Area

- `lib/src/interactive/**`
- `test/interactive/**`
- `test/view/scene_view_interactive_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one interactive slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneControllerInteractive` remains the public interactive facade.
2. Pointer semantics, active-gesture ownership, selection exclusivity, and
   dispose fail-fast behavior remain protected.
3. This step must thin the facade and not replace it with a second public
   controller.

## 5. Result Requirements

1. `SceneControllerInteractive` no longer mixes public facade duties,
   pointer-dispatch runtime, and gesture orchestration in the same owner body.
2. Interactive behavior remains equivalent on the public surface.
3. Current hotspots improve against the confirmed baseline:
   `scene_controller_interactive.dart = 4 HIGH+`,
   `interactive_move_session.dart = 2 HIGH+`,
   and the class metrics
   `CBO 36`, `RFC 154`, `WMC 184`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed exact duplication includes `_scheduleNotify()` and
  repeated pointer / gesture dispatch glue.
- The step owns interactive runtime beneath the facade and must not reopen
  render/view event admission work from `SceneViewInteractive`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_move_session.dart lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/interactive_event_dispatcher.dart lib/src/interactive/internal/interactive_gesture_machine.dart lib/src/interactive/internal/interactive_runtime.dart --report-all`
- MCP test runner: `test/interactive`
- MCP test runner: `test/view/scene_view_interactive_test.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`

### 6.3 Protected States, Data, or Structures

- Pointer normalization semantics.
- Active-gesture and selection exclusivity behavior.
- Action and editTextRequests behavior.
- Dispose fail-fast semantics.

### 6.4 Allowed Semantic Change Zones

- Pointer and gesture runtime ownership beneath the interactive facade.
- Internal event dispatch and move/draw coordination ownership.
- Interactive-side notify glue ownership.

### 6.8 Prohibited

- Reopening `SceneViewInteractive` host admission work in this step.
- Changing public interactive behavior to improve metrics.
- Keeping the same mixed facade/runtime body behind cosmetic helper extraction.

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

### Slice 1. [x] Pointer and gesture runtime is separated from the facade

#### Slice Contract

Public interactive facade is separated from pointer and gesture runtime
ownership.

#### Change

Вынести pointer and gesture runtime responsibilities below
`SceneControllerInteractive` and remove the replaced mixed owner body.

#### Verification

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_move_session.dart lib/src/interactive/internal/interactive_gesture_machine.dart lib/src/interactive/internal/interactive_runtime.dart --report-all`
- MCP test runner: `test/interactive`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `SceneControllerInteractive` no longer keeps the replaced mixed facade /
  runtime body.

### Slice 2. [x] Interactive semantics remain exact after facade thinning

#### Slice Contract

Interactive semantics remain exact after the facade thinning.

#### Change

Перевести remaining internal dispatch and notify glue on the new ownership
shape and close residual duplicate bodies.

#### Verification

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/interactive_event_dispatcher.dart lib/src/interactive/internal/interactive_runtime.dart --report-all`
- MCP test runner: `test/interactive`
- MCP test runner: `test/view/scene_view_interactive_test.dart`
- `dart run tool/check_guardrails.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Interactive semantics remain green without the replaced mixed owner body.

## 9. Final Verification

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_move_session.dart lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/interactive_event_dispatcher.dart lib/src/interactive/internal/interactive_gesture_machine.dart lib/src/interactive/internal/interactive_runtime.dart --report-all`
- MCP test runner: `test/interactive`
- MCP test runner: `test/view/scene_view_interactive_test.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
