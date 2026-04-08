# Change Contract

## 1. Change Mandate

This change splits interruption, detachment, and dispose semantics into
distinct interactive-runtime lifecycle owners instead of a shared reset path.

## 2. Change Boundary

### Included in the Change

- explicit runtime entrypoints for interaction-config interruption, external
  mutation interruption, pointer-session detachment, and destructive dispose
- owner-scoped active-gesture detachment in the gesture machine and pointer
  normalizer
- move-session restoration rules that align interruption and owning-session
  detachment with pointer-cancel semantics
- mutation guardrail and structural-test updates for the renamed lifecycle
  contract

### Not Included in the Change

- public/session routed-input transport split from step `92`
- draw-style snapshot capture and pending-line owner semantics
- `SceneViewPointerSession.detach()` contract and host ordering
- docs, invariant-registry, or roadmap closure work

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`
- `lib/src/interactive/internal/interactive_pointer_normalizer.dart`
- `lib/src/interactive/internal/interactive_gesture_machine.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/pointer_session_token.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/src/guardrails/interactive_mutation_guard_contract.dart`

### Test Files

- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
- `test/interactive/core/scene_controller_interactive_dispose_matrix_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

### Fixture and Supporting Data Files

- `test/interactive/test_support/interactive_controller_fixtures.dart`
- `plan/step_93_interactive_runtime_lifecycle_reason_split.md`

### Analysis Area

- `lib/src/interactive/**`
- `test/interactive/**`
- `tool/src/guardrails/**`
- `test/tool/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which the listed
  verification cannot be closed.

### File Change Rule

- Every modified production file must implement one of the split lifecycle
  reasons or consume the new lifecycle owner APIs.
- Every modified test must pin one lifecycle-reason behavior or one renamed
  guardrail expectation.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.

## 4. Locked Decisions

1. Step `92` provides the session-token input path; this step consumes that
   path and must not reopen public-facade transport.
2. Interaction-config interruption, external-mutation interruption,
   pointer-session detachment, and `SceneController.dispose()` are distinct
   lifecycle reasons in the target architecture and must not be collapsed into
   one boundary-level reset API.
3. Active move interruption restores gesture-baseline selection exactly when
   pointer `cancel` would restore it.
4. Session detachment of a non-owning session leaves the active move gesture
   untouched.
5. Controller dispose must remain destructive runtime teardown and must not be
   represented as an interruption or detachment alias.

## 5. Result Requirements

1. `InteractiveRuntime` exposes distinct owner-appropriate entrypoints for
   interaction-config interruption, external-mutation interruption,
   pointer-session detachment, and dispose.
2. `InteractiveGestureMachine` and `InteractivePointerNormalizer` can detach
   only state owned by a specific `PointerSessionToken`.
3. `InteractiveMoveSession` uses one non-committing restore-and-clear path for
   pointer `cancel`, interaction interruption, external-mutation interruption,
   and owning-session detachment.
4. Repository-local guardrails fail if the old reset terminology or one-reset
   lifecycle API returns.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `InteractiveRuntime` currently exposes `resetInteractiveState()`, and
  boundary owners still use raw reset terminology.
- `InteractiveGestureMachine` currently stores only pointer-local gesture
  identity and cannot detach an active gesture by session owner.
- `InteractivePointerNormalizer` currently keys last-finite pointer state only
  by `pointerId`, so it cannot selectively forget session-owned state.
- `SceneControllerInteraction` and `SceneControllerSceneMutations` still use
  boundary names that imply reset-style semantics instead of explicit
  interruption reasons.
- `SceneController.dispose()` still relies on the graph-level
  `resetSceneControllerGraphInteractiveState(...)` helper instead of
  destructive runtime disposal.

### 6.2 Target Verification Units

- MCP run of `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_dispose_matrix_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### 6.3 Protected States, Data, or Structures

- active gesture exclusivity and active-pointer ownership
- move baseline selection restore semantics on cancel/interruption
- pointer-normalizer terminal semantics for non-finite up/cancel input
- `actions` / `editTextRequests` delivery semantics and dispose fail-fast

### 6.4 Allowed Semantic Change Zones

- boundary naming and call-site intent for interruption reasons
- owner metadata stored on active gesture and pointer-normalizer state
- move-session interruption and detachment behavior
- repo-local structural and mutation-guardrail proof surface

### 6.5 Requirements for Resolution of Links and Structural Analysis

- `InteractiveRuntime` must replace `resetInteractiveState()` with the exact
  boundary methods fixed by this contract:
  `interruptForInteractionConfigChange()`,
  `interruptForExternalMutation()`,
  `detachPointerSession(PointerSessionToken token)`, and `dispose()`.
- `interruptForInteractionConfigChange()` is used only by
  `SceneControllerInteraction.setMode(...)` and
  `SceneControllerInteraction.setDrawTool(...)`.
- `interruptForExternalMutation()` is used only by
  `SceneControllerSceneMutations.setCameraOffset(...)` and
  `SceneControllerSceneMutations.replaceScene(...)`.
- `SceneControllerInteraction` and `SceneControllerSceneMutations` must remove
  the old `resetActiveGestureBeforeExternalMutation` terminology.
- `SceneController.dispose()` must stop calling the graph-level
  `resetSceneControllerGraphInteractiveState(...)` helper and must rely on
  destructive runtime disposal only.
- `InteractivePointerNormalizer` and `InteractiveGestureMachine` are the only
  production owners allowed in this step to persist session-token state for
  owner-scoped detachment. `InteractiveMoveSession` must consume detachment
  through the runtime flow and must not retain the token itself.

### 6.6 Prohibited

- keeping `resetInteractiveState()` as a boundary-level lifecycle API
- calling a generic reset from `setMode(...)`, `setDrawTool(...)`,
  `setCameraOffset(...)`, `replaceScene(...)`, or `SceneController.dispose()`
- representing controller dispose as
  `interruptForExternalMutation()` or `detachPointerSession(...)`
- retaining `PointerSessionToken` inside `InteractiveMoveSession`

## 7. Execution Rules

1. Step `92` must remain the only owner of the public/session transport split.
2. This step closes the lifecycle-reason taxonomy before draw-owner changes or
   view-session detach contract work proceed.
3. Renamed guardrail expectations must land in the same change as the boundary
   rename.
4. Preparatory refactors without green move/dispose regression coverage do not
   close the step.

## 8. Vertical Slices

### Slice 1. [x] Lifecycle Reasons Are Split And Owned

#### Slice Contract

Interaction-config interruption, external-mutation interruption,
pointer-session detachment, and controller dispose use distinct runtime
entrypoints with owner-appropriate behavior instead of one reset API.

#### Change

Refactor `InteractiveRuntime` so it no longer exposes
`resetInteractiveState()`. Replace it with exactly these boundary methods:

- `interruptForInteractionConfigChange()`
- `interruptForExternalMutation()`
- `detachPointerSession(PointerSessionToken token)`
- `dispose()`

`interruptForInteractionConfigChange()` is used only by
`SceneControllerInteraction.setMode(...)` and
`SceneControllerInteraction.setDrawTool(...)`.
`interruptForExternalMutation()` is used only by
`SceneControllerSceneMutations.setCameraOffset(...)` and
`SceneControllerSceneMutations.replaceScene(...)`.
`SceneController.dispose()` must stop calling the graph-level
`resetSceneControllerGraphInteractiveState(...)` helper and must rely on
destructive runtime disposal only.

Refactor `InteractiveGestureMachine` so active gesture admission and terminal
matching key on `(pointerId, session token namespace)` and so the machine can
interrupt the current active gesture without exposing a generic reset API and
detach only the active gesture owned by a specific `PointerSessionToken`.

Refactor `InteractivePointerNormalizer` so public/manual input and session
input use separate internal key namespaces and add `detachSession(token)` that
forgets only last-finite positions owned by that session.

Refactor `InteractiveMoveSession` so pointer `cancel`,
`interruptForInteractionConfigChange()`,
`interruptForExternalMutation()`, and owning-session detachment all use the
same non-committing restore-and-clear path.

Update `SceneControllerInteractionRuntime`,
`SceneControllerSceneMutations`, and the listed guardrail files in the same
change so the repo-local mutation contract enforces the renamed lifecycle
policy without a red intermediate state.

#### Verification

- MCP run of `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_dispose_matrix_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Fixtures Used

- `test/interactive/test_support/interactive_controller_fixtures.dart`

#### Positive Scenarios

- active move interrupted by `setMode(...)`, `setDrawTool(...)`,
  `setCameraOffset(...)`, or `replaceScene(...)` restores baseline selection
  exactly like pointer `cancel`
- detaching the owning session of an active move gesture restores baseline
  selection exactly like pointer `cancel`
- no-op camera updates and rejected scene replacement preserve the active
  gesture

#### Negative Scenarios

- non-owning session detachment does not clear another owner’s active gesture
- interruption or detachment emits no draw/move/erase commit and no action
  event
- controller dispose does not route through
  `interruptForExternalMutation()` or `detachPointerSession(...)`

#### Closure Evidence

- green run of the listed verifications
- guardrail diagnostics proving the new mutation-owner policy name is enforced

## 9. Final Verification

- MCP run of `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_dispose_matrix_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- The slice is closed.
- Final verification has passed.
