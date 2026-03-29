language: russian

# Шаг 32. Сузить `InteractiveRuntime` до boundary pointer/gesture owner

## 1. Change Mandate

Этот шаг сужает `InteractiveRuntime` до boundary owner-а pointer normalization,
active gesture dispatch, reset, and dispose without changing public interactive
behavior.

## 2. Change Boundary

### Included in the Change

- Boundary-runtime ownership beneath `SceneControllerInteractive`.
- Event and monotonic-timestamp ownership currently mixed into
  `InteractiveRuntime`.
- Facade/runtime wiring required to keep `SceneControllerInteractive` thin over
  the narrowed runtime owner.

### Not Included in the Change

- Draw-path owner decomposition under `interactive_draw_coordinator.dart`.
- Eraser-path geometry, candidate-query, and delete-flow decomposition.
- Final interactive architecture closure in docs, structural tests, and
  accepted residual baseline.
- View-side raw pointer routing ownership.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`
- `lib/src/interactive/internal/interactive_event_dispatcher.dart`

### Test Files

- `test/interactive/**`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `PLAN.md`
- `plan/step_32_interactive_runtime_boundary_owner_split.md`

### Analysis Area

- `lib/src/interactive/**`
- `test/interactive/**`
- `test/view/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which the slice
  verification cannot be closed.

### File Change Rule

- Every modified implementation file must remove mixed boundary-runtime
  ownership from `InteractiveRuntime` or become one explicit focused owner under
  the narrowed runtime graph.
- Every modified test must validate boundary-runtime behavior or the updated
  facade/runtime seam.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneControllerInteractive` remains the only public interactive facade.
2. Boundary pointer normalization, active gesture ownership, and family dispatch
   remain in the `interactive` layer and do not move into `view`.
3. `SceneView` continues to own raw Flutter pointer routing and routed
   `pointerId` allocation only.
4. `SceneControllerCore` remains the owner of committed writes; interactive
   runtime may delegate committed mutations but must not re-own controller
   commit lifecycle.
5. `interactive_event_dispatcher.dart` remains the interactive event-delivery
   boundary; timestamp sequencing removed from `InteractiveRuntime` may extend
   that boundary or one focused helper directly behind it, but must not become
   a new generic event bus/platform.

## 5. Result Requirements

1. `InteractiveRuntime` no longer owns public action/edit-text stream lifecycle
   and monotonic timestamp sequencing; those responsibilities live behind the
   existing interactive event-dispatch boundary and not in the public facade.
2. One narrowed boundary-runtime owner remains beneath
   `SceneControllerInteractive` for pointer admission, normalized terminal
   semantics, active gesture ownership, family dispatch, reset, and dispose.
3. Public interactive behavior remains equivalent for:
   pointer normalization,
   monotonic timestamps,
   `actions`,
   `editTextRequests`,
   double-tap text routing,
   active-gesture exclusivity,
   and dispose fail-fast.
4. The measured hotspot baseline improves against the current confirmed runtime
   scope as evidence of removed mixed ownership, and metric improvement alone
   does not close the step:
   `interactive_runtime.dart` imports `15`, class `CBO 20`, `RFC 55`,
   `WMC 68`.
5. `SceneControllerInteractive` does not reabsorb the removed boundary-runtime
   responsibilities.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed boundary-runtime hotspot is
  `lib/src/interactive/internal/interactive_runtime.dart` with:
  imports `15`,
  class `CBO 20`,
  `RFC 55`,
  `WMC 68`.
- `InteractiveRuntime` currently mixes:
  pointer normalization,
  active gesture owner lifecycle,
  family dispatch,
  monotonic timestamp sequencing,
  public action and edit-text stream exposure,
  double-tap text routing,
  reset,
  and dispose.
- `scene_controller_interactive.dart` currently remains wide partly because it
  still wires runtime, selection actions, and preview/event glue in one public
  facade file.
- `interactive_event_dispatcher.dart` already owns interactive event dispatch
  and notify scheduling, but `InteractiveRuntime` still re-owns timestamp state
  and public event exposure around it.
- Preferred closure path for this step is to extend the existing
  `interactive_event_dispatcher.dart` boundary instead of inventing a new
  action-bus or timeline platform.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_runtime.dart lib/src/interactive/internal/interactive_event_dispatcher.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/interactive`
- MCP test runner:
  `test/view/scene_view_interactive_test.dart test/view/scene_view_pointer_router_test.dart`

### 6.3 Protected States, Data, or Structures

- Pointer terminal normalization semantics.
- Active gesture identity and gesture-family dispatch.
- Monotonic timestamp behavior for interactive events.
- `actions` and `editTextRequests` behavior.
- Public facade fail-fast behavior after `dispose()`.

### 6.4 Allowed Semantic Change Zones

- Boundary-runtime ownership beneath the interactive facade.
- Event and timestamp ownership beneath the interactive runtime boundary.
- Existing interactive event-dispatch boundary and focused timestamp sequencing
  beneath it.
- Facade/runtime wiring required to keep the public interactive surface
  behaviorally equivalent.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The narrowed runtime graph must keep one boundary-runtime entrypoint beneath
  `SceneControllerInteractive`; the step must not introduce a second public
  controller or a parallel runtime facade.
- Any extracted focused owner created by this step must remain internal to
  `lib/src/interactive/internal/`.
- Removed event/timestamp responsibilities must be externalized into
  `interactive_event_dispatcher.dart` or one focused helper directly behind it;
  a new generic event/action platform does not satisfy the step.
- The step is not closed if `SceneControllerInteractive` keeps the removed
  boundary-runtime logic inline as private helper bodies.

### 6.8 Prohibited

- Introducing a generic tool/plugin runtime model.
- Moving raw pointer routing or routed `pointerId` allocation into
  `interactive`.
- Moving controller commit/write ownership into `InteractiveRuntime`.
- Parking removed event/timestamp responsibilities as new private helpers inside
  `InteractiveRuntime` or `SceneControllerInteractive` without changing the
  owner graph.
- Introducing wrapper layers whose primary purpose is metric reduction without
  removing mixed ownership.

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

### Slice 1. [x] Boundary runtime no longer owns event timeline

#### Slice Contract

`InteractiveRuntime` no longer mixes event/timestamp ownership with boundary
pointer and gesture runtime ownership.

#### Change

Extract the event/timestamp responsibilities currently mixed into
`InteractiveRuntime` beneath the existing interactive facade and rewire
`SceneControllerInteractive` to the narrowed runtime graph without widening the
public facade.

#### Verification

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_runtime.dart lib/src/interactive/internal/interactive_event_dispatcher.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/interactive`
- MCP test runner:
  `test/view/scene_view_interactive_test.dart test/view/scene_view_pointer_router_test.dart`

#### Positive Scenarios

- Valid pointer sequences still preserve monotonic interactive timestamps.
- `actions` and `editTextRequests` retain the current observable behavior on the
  public facade.
- Active gesture ownership and family dispatch remain controller-local beneath
  the narrowed runtime boundary.

#### Negative Scenarios

- Non-finite `down` and `move` remain no-op admissions.
- Non-finite terminal `up` and `cancel` remain normalized only when the same
  `pointerId` already has a cached finite position.
- The refactor does not move raw host pointer routing or routed `pointerId`
  allocation into `interactive`.
- `dispose()` still closes further mutating or effectful public entrypoints with
  `StateError`.

#### Closure Evidence

- Green run of the listed verifications.
- `InteractiveRuntime` no longer contains the removed mixed event/timestamp
  ownership in the same owner body as pointer normalization and gesture
  dispatch.
- The targeted metric baseline improves against the confirmed starting values
  for `interactive_runtime.dart`.
- `SceneControllerInteractive` does not gain the removed runtime ownership as a
  replacement hotspot.

## 9. Final Verification

- `dcm calculate-metrics lib/src/interactive/scene_controller_interactive.dart lib/src/interactive/internal/interactive_runtime.dart lib/src/interactive/internal/interactive_event_dispatcher.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/controller/internal`
- MCP test runner:
  `test/controller/core test/controller/commands`
  plus
  controller-root
  `scene_snapshot_invariant_assertions_test.dart`,
  `scene_invariants_test.dart`,
  and
  `scene_controller_randomized_txn_test.dart`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test` with root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
