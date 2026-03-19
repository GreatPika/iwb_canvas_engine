language: russian

# Шаг 14.3. Закрыть regression-матрицу interactive и view

## 1. Change Mandate

This change closes the unresolved input-lifecycle regression matrix across the
current `interactive/view` seam without moving ownership back into controller or
render layers.

## 2. Change Boundary

### Included in the Change
- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/interaction_eligibility_policy.dart`
- `lib/src/interactive/internal/interactive_gesture_machine.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_pointer_router.dart`
- `test/interactive/core/interaction_eligibility_policy_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/view/scene_view_test.dart`

### Not Included in the Change
- Serialization/model/core regression proofs
- Controller command and commit regression proofs
- Render/cache parity and invalidation regressions

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/interactive/scene_controller_interactive.dart`
- `lib/src/interactive/interaction_eligibility_policy.dart`
- `lib/src/interactive/internal/interactive_gesture_machine.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_pointer_router.dart`

### Test Files
- `test/interactive/core/interaction_eligibility_policy_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/view/scene_view_test.dart`

### Analysis Area
- `lib/src/interactive/**`
- `lib/src/view/**`
- `test/interactive/**`
- `test/view/**`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Controller-owned gesture semantics stay in `interactive`; host routing and
   pointer tracking stay in `view`.
2. Invalid terminal pointer normalization remains a controller-boundary concern,
   while raw-pointer admission and slot routing remain a view concern.
3. Forced resets on `replaceScene(...)` and `setCameraOffset(...)` remain part
   of the current interactive lifecycle contract.
4. This step closes regression proofs for the existing input-lifecycle seam; it
   does not reopen the step `10.x-11.x` architecture.

## 5. Result Requirements

1. Interactive regressions are covered for `dragStartSlop`, frozen gesture
   baseline, invalid terminal normalization, cancel rollback, scene/camera
   forced reset, monotonic timestamps, preview/commit parity, the unified
   `dragStartSlop` / `tapSlop = 0` rule, and pending-line abort semantics.
2. View regressions are covered for invalid pointer filtering, slot release
   order, raw-id/slot-id separation, no reset while raw pointers are alive,
   mounted guards, and flush-path allocation discipline.
3. The regression proofs stay aligned with the current split between
   `interactive` and `view`.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Reuse the existing `test/interactive/core/**` and `test/view/**` owners.
- Keep controller-lifecycle assertions in `interactive` tests and host/routing
  assertions in `view` tests.
- Do not use render tests as the primary oracle for pointer or gesture
  behavior.

### 6.2 Target Verification Units
- `test/interactive/core/interaction_eligibility_policy_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/view/scene_view_test.dart`

### 6.3 Protected States, Data, or Structures
- Active gesture identity and baseline state
- Pointer timestamp monotonicity
- Pending-line latent state
- Raw-pointer to slot routing state
- Pending tap flush state and mounted lifecycle

### 6.4 Allowed Semantic Change Zones
- Interactive pointer admission and gesture lifecycle regression proofs
- View-side raw host routing and flush lifecycle regression proofs

### 6.8 Prohibited
- Moving view routing checks into controller or render tests
- Treating controller core tests as sufficient proof for interactive lifecycle
- Reopening the owner split between `scene_controller_interactive.dart` and
  `scene_view_interactive.dart`

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

### Slice 1. [ ] Interactive Gesture Boundary Matrix

#### Slice Contract
The unresolved interactive gesture and pointer-entry regressions are closed by
owner-level tests under `test/interactive/**`.

#### Change
Extend the current interactive regression tests around gesture start, terminal
normalization, move parity, and pending-line cleanup.

#### Verification
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/interaction_eligibility_policy_test.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`

#### Positive Scenarios
- valid pointer sequences preserve monotonic timestamps
- preview and commit stay aligned for transformable selections
- `dragStartSlop` baseline stays fixed for the active gesture
- `tapSlop = 0` follows the same current threshold contract as explicit
  `dragStartSlop`

#### Negative Scenarios
- invalid `up/cancel` paths are normalized only under the current controller
  boundary rule
- cancel restores the current baseline state
- `replaceScene(...)` and `setCameraOffset(...)` abort the current gesture
- stray terminal input aborts pending-line state according to the current rule

#### Closure Evidence
- Green run of the listed interactive tests.
- Every original `interactive` item from step `14` is tied to one owner-level
  test.

### Slice 2. [ ] View Host Routing Matrix

#### Slice Contract
The unresolved view-side raw host and pointer-router regressions are closed by
owner-level tests under `test/view/**`.

#### Change
Extend the current view tests around invalid host input filtering, slot
lifecycle, mounted guards, and flush-path behavior.

#### Verification
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/view/scene_view_test.dart`

#### Positive Scenarios
- live raw pointers keep the current slot mapping contract
- pending tap flush uses the current mounted and owner-generation guards

#### Negative Scenarios
- invalid host pointer data is filtered before side effects
- slot release order remains stable
- the router does not reset while raw pointers are still alive
- flush-path logic avoids useless collection work according to the current
  owner behavior

#### Closure Evidence
- Green run of the listed view tests.
- No original `view` item from step `14` remains without an explicit owner
  proof.

## 9. Final Verification

- `dart run tool/check_invariant_coverage.dart`
- Green run of the interactive verification units listed in section `6.2`
- Green run of the view verification units listed in section `6.2`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
