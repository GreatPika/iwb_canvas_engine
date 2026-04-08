# Change Contract

## 1. Change Mandate

This change makes active draw flows consume gesture-start style snapshots and
owner-scoped pending-line state instead of live config reads or ownerless
latent state.

## 2. Change Boundary

### Included in the Change

- captured draw-style ownership for active draw preview and commit flows
- owner-scoped pending-line storage inside `InteractiveDrawLineEngine`
- preview read-side updates so active previews use captured runtime style
- manual/session cross-owner regression coverage for pending-line semantics

### Not Included in the Change

- public/session routed-input transport split from step `92`
- lifecycle-reason split from step `93`
- `SceneViewPointerSession.detach()` contract and host ordering
- docs, invariant-registry, or roadmap closure work

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator.dart`
- `lib/src/interactive/internal/interactive_draw_gesture_session.dart`
- `lib/src/interactive/internal/interactive_draw_line_engine.dart`
- `lib/src/interactive/internal/interactive_draw_stroke_engine.dart`
- `lib/src/interactive/internal/interactive_draw_terminal_router.dart`
- `lib/src/interactive/internal/interactive_gesture_router.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/pointer_session_token.dart`

### Test Files

- `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/view/scene_view_interactive_test.dart`

### Fixture and Supporting Data Files

- `test/interactive/test_support/interactive_controller_fixtures.dart`
- `plan/step_94_draw_style_snapshot_and_pending_line_ownership.md`

### Analysis Area

- `lib/src/interactive/**`
- `lib/src/view/**`
- `test/interactive/**`
- `test/view/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which the listed
  verification cannot be closed.

### File Change Rule

- Every modified production file must implement draw-style snapshot ownership
  or owner-scoped pending-line semantics.
- Every modified test must pin one captured-style or cross-owner pending-line
  behavior.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.

## 4. Locked Decisions

1. Steps `92-93` define the routed-input path and lifecycle-reason taxonomy;
   this step consumes them instead of reopening those seams.
2. Active draw snapshot remains owned by `InteractiveDrawGestureSession`.
3. Pending line remains draw-local latent state owned by
   `InteractiveDrawLineEngine`.
4. Mid-flow config changes affect only the next draw flow; active preview and
   commit continue to use gesture-start style.
5. A pending line started by one ownership source cannot be completed by a
   different ownership source.

## 5. Result Requirements

1. Active stroke and line preview/commit flows use captured gesture-start style
   for their full lifetime.
2. Pending line stores captured style and ownership provenance in one
   owner-local carrier inside `InteractiveDrawLineEngine`.
3. A different owner can replace an existing pending line but cannot complete
   it across owners.
4. Active preview getters on the controller/runtime read captured draw values
   while the preview is active; mutable config getters remain future-gesture
   state only.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `InteractiveDrawGestureSession` currently stores only `downScene` and
  `moved`, so it cannot own captured style or session provenance.
- `InteractiveDrawLineEngine` pending-line state currently stores only
  start/timestamp/timer and cannot represent style or owner provenance.
- Preview getters currently read live mutable config even while an active draw
  preview exists.

### 6.2 Target Verification Units

- MCP run of `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- MCP run of `test/view/scene_view_interactive_test.dart`

### 6.3 Protected States, Data, or Structures

- draw preview points and line preview non-committing behavior
- pending line start/timestamp/timer lifecycle
- public draw-setting getters for future gestures

### 6.4 Allowed Semantic Change Zones

- owner metadata stored on active draw snapshot and pending-line latent state
- read-side preview style source for active draw flows
- draw commit and interruption paths that consume captured draw state

### 6.5 Requirements for Resolution of Links and Structural Analysis

- `InteractiveDrawGestureSession` must capture exactly:
  `downScene`, `moved`, `InteractiveDrawStyle capturedStyle`, and
  `PointerSessionToken? sessionToken`.
- `InteractiveDrawLineEngine` must represent pending line with one owner-local
  carrier that stores `Offset start`, `int timestampMs`,
  `InteractiveDrawStyle capturedStyle`, `PointerSessionToken? sessionToken`,
  and timeout-timer state.
- `InteractiveDrawGestureSession` and `InteractiveDrawLineEngine` are the only
  production owners allowed in this step to persist session-token state for
  draw ownership. No other runtime, router, draw engine, facade, or view owner
  may retain that provenance.
- `InteractiveGestureRouter` may read `callbacks.readDrawStyle()` only on
  pointer `down`. After `down`, active draw preview and terminal behavior must
  read from captured session state.

### 6.6 Prohibited

- reading live mutable draw config for active preview or commit behavior after
  gesture start
- moving pending-line ownership out of `InteractiveDrawLineEngine`
- storing draw-owner session provenance outside
  `InteractiveDrawGestureSession` or `InteractiveDrawLineEngine`
- allowing a pending line started by one owner source to commit from a
  different owner source

## 7. Execution Rules

1. Steps `92-93` remain the owners of routed-input and lifecycle-reason
   semantics.
2. This step closes draw-owner semantics before any view-session detach
   contract work starts.
3. Manual/session cross-owner regression coverage must land in the same change
   as the owner-scoped pending-line behavior.
4. Preparatory refactors without green preview/commit regressions do not close
   the step.

## 8. Vertical Slices

### Slice 1. [ ] Draw Snapshot And Owner-Scoped Pending Line

#### Slice Contract

Active draw preview and pending line use captured gesture-start style and
owner-scoped pending-line provenance instead of live config reads or ownerless
latent state.

#### Change

Refactor `InteractiveDrawGestureSession` into the single owner of active draw
snapshot state. It must capture exactly:

- `downScene`
- `moved`
- `InteractiveDrawStyle capturedStyle`
- `PointerSessionToken? sessionToken`

Refactor `InteractiveDrawLineEngine` so pending line is represented by one
owner-local carrier inside that file. The carrier must store exactly:

- `Offset start`
- `int timestampMs`
- `InteractiveDrawStyle capturedStyle`
- `PointerSessionToken? sessionToken`
- timeout timer state

Implement exact owner-scoped pending-line semantics:

- drag gesture clears any existing pending line before active preview
- first tap with no pending line stores a pending line for the current owner
- second tap from the same owner commits using the pending line’s captured
  style
- tap from a different owner replaces the old pending line and does not
  cross-owner commit
- detaching a session token clears only the matching pending line

Refactor the listed draw engines and preview getters so stroke commit, line
commit, line preview, stroke preview, and interruption all consume captured
draw state instead of live mutable config.

Add session/manual cross-owner regression coverage in
`test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
by driving one flow through a real `SceneViewPointerSession` and the other
through public manual `interaction.handlePointer(...)`.

#### Verification

- MCP run of `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- MCP run of `test/view/scene_view_interactive_test.dart`

#### Fixtures Used

- `test/interactive/test_support/interactive_controller_fixtures.dart`

#### Positive Scenarios

- highlighter preview and commit keep original thickness and opacity after
  mid-drag config changes
- stroke preview and commit keep original color after mid-drag
  `setDrawColor(...)`
- dragged line preview and commit keep original thickness and color after
  mid-drag config changes
- same-owner two-tap line commit uses the first tap’s captured style

#### Negative Scenarios

- different-owner tap cannot complete an existing pending line
- different-owner drag cannot reuse an existing pending line
- post-terminal config changes affect the next gesture immediately

#### Closure Evidence

- green run of the listed verifications
- direct regression assertions proving owner-scoped pending-line replacement and
  captured-style commit behavior

## 9. Final Verification

- MCP run of `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- MCP run of `test/view/scene_view_interactive_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- The slice is closed.
- Final verification has passed.
