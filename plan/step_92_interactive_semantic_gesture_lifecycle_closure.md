# Change Contract

## 1. Change Mandate

This change migrates forced interactive interruption, active draw-style ownership, and view-side pointer-session detachment onto one controller-owned semantic gesture-lifecycle contract so these behaviors stop depending on raw reset paths, live config reads, or host lifetime artifacts.

## 2. Change Boundary

### Included in the Change

- semantic active-gesture interruption inside the existing interactive owner graph
- forced-interrupt semantics for active move during `setMode(...)`, `setDrawTool(...)`, `setCameraOffset(...)`, `replaceScene(...)`, and `SceneController.dispose()`
- draw-style snapshot semantics for stroke preview/commit, dragged line preview/commit, and two-tap pending line state
- explicit pointer-session detachment before session replacement and host disposal
- invariant, documentation, changelog, and regression-test closure for the new lifecycle contract

### Not Included in the Change

- any public API widening of `SceneController`, `SceneView`, `SceneControllerInteraction`, `SceneControllerSelection`, or `SceneControllerScene`
- any change to raw pointer admission, slot reuse, or routing ownership in `SceneViewPointerRouter`
- any change to deny-listed public mutation exclusivity outside the interruption paths already allowed by the current contract
- any model, serialization, render, undo/redo, or backend behavior unrelated to the interactive lifecycle scenarios above

## 3. File Map and Analysis Areas

### Implementation Files

- [lib/src/interactive/internal/interactive_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_runtime.dart)
- [lib/src/interactive/internal/interactive_gesture_machine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_gesture_machine.dart)
- [lib/src/interactive/internal/interactive_move_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart)
- [lib/src/interactive/internal/interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart)
- [lib/src/interactive/internal/interactive_draw_gesture_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_gesture_session.dart)
- [lib/src/interactive/internal/interactive_draw_line_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_line_engine.dart)
- [lib/src/interactive/internal/interactive_draw_stroke_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_stroke_engine.dart)
- [lib/src/interactive/internal/interactive_draw_terminal_router.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_terminal_router.dart)
- [lib/src/interactive/internal/interactive_gesture_router.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_gesture_router.dart)
- [lib/src/interactive/internal/interactive_runtime_callbacks.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_runtime_callbacks.dart)
- [lib/src/interactive/internal/scene_controller_interaction_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_runtime.dart)
- [lib/src/interactive/internal/scene_controller_scene_mutations.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_scene_mutations.dart)
- [lib/src/interactive/scene_controller_interaction.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interaction.dart)
- [lib/src/contract/scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_view_runtime.dart)
- [lib/src/interactive/internal/scene_controller_pointer_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_pointer_session.dart)
- [lib/src/interactive/internal/scene_controller_scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_scene_view_runtime.dart)
- [lib/src/view/scene_view_interactive_pointer_host.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart)
- [lib/src/view/scene_view_runtime_host.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_runtime_host.dart)

### Test Files

- [test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart)
- [test/interactive/core/scene_controller_interactive_basics_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart)
- [test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart)
- [test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart)
- [test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart)
- [test/view/scene_view_interactive_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_interactive_test.dart)
- [test/contract/runtime_contract_interfaces_test.dart](/Users/blackpika/iwb_canvas_engine/test/contract/runtime_contract_interfaces_test.dart)
- [test/interactive/core/scene_controller_architecture_boundary_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_architecture_boundary_test.dart)

### Fixture and Supporting Data Files

- [test/interactive/test_support/interactive_controller_fixtures.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/test_support/interactive_controller_fixtures.dart)
- [README.md](/Users/blackpika/iwb_canvas_engine/README.md)
- [API_GUIDE.md](/Users/blackpika/iwb_canvas_engine/API_GUIDE.md)
- [ARCHITECTURE.md](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md)
- [CHANGELOG.md](/Users/blackpika/iwb_canvas_engine/CHANGELOG.md)
- [tool/invariant_registry.dart](/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart)

### Analysis Area

- [lib/src/interactive](/Users/blackpika/iwb_canvas_engine/lib/src/interactive)
- [lib/src/view](/Users/blackpika/iwb_canvas_engine/lib/src/view)
- [lib/src/contract/scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_view_runtime.dart)
- [test/interactive/core](/Users/blackpika/iwb_canvas_engine/test/interactive/core)
- [test/view](/Users/blackpika/iwb_canvas_engine/test/view)
- [test/contract/runtime_contract_interfaces_test.dart](/Users/blackpika/iwb_canvas_engine/test/contract/runtime_contract_interfaces_test.dart)
- [tool/invariant_registry.dart](/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart)

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one slice below.
- Every modified test must prove one stated regression or invariant.
- Every modified documentation or invariant file must describe the same lifecycle contract implemented in code.
- Untied changes are out of scope.

## 4. Locked Decisions

1. The change must solve forced interruption, active draw-style drift, and pointer-session detachment through one architectural gesture-lifecycle contract, not through isolated call-site patches.
2. The controller-owned active-gesture owner remains the only owner of gesture identity and baseline `dragStartSlop`; move and draw owners must not reintroduce competing pointer ownership.
3. Preview state remains ephemeral and must not commit scene mutations before terminal `up`; cancel and forced-interrupt paths must remain non-committing.
4. `setCameraOffset(...)` and `replaceScene(...)` remain the only public scene mutations allowed to interrupt an active gesture after their existing preflight proves the mutation will proceed; other deny-listed public scene and selection mutations remain blocked during an active gesture.
5. `SceneViewInteractivePointerHost` remains a raw routing shell over an opaque `SceneViewPointerSession` and must not become a controller-side gesture owner.
6. Public API shape stays unchanged; the fix is internal to the existing interactive, view, and internal-safe contract layers.
7. No-op and rejected boundary operations must keep the current contract: they must not silently abort the active gesture.
8. User-visible behavior changes in this area must update [README.md](/Users/blackpika/iwb_canvas_engine/README.md), [API_GUIDE.md](/Users/blackpika/iwb_canvas_engine/API_GUIDE.md), [ARCHITECTURE.md](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md), [CHANGELOG.md](/Users/blackpika/iwb_canvas_engine/CHANGELOG.md), and [tool/invariant_registry.dart](/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart) in the same change.

## 5. Result Requirements

1. All non-pointer interruption paths use one semantic interruption path instead of raw state clearing; for move, forced interruption restores baseline selection exactly when pointer `cancel` would restore it.
2. An active draw stroke, dragged line, and two-tap pending line use style captured from the gesture start state; mid-flow changes to color, thickness, opacity, or draw tool affect only subsequent gestures.
3. Read-side preview values exposed through `SceneControllerInteraction` reflect the captured active draw state, not the live mutable config, for the full lifetime of the active draw or pending line flow.
4. Replacing or disposing a `SceneViewPointerSession` while the old controller still exists leaves that old controller without an active gesture or host-lifetime lock.
5. Existing public mutation exclusivity, no-op preflight behavior, and rejected-operation behavior remain unchanged outside the scenarios addressed by this change.
6. The lifecycle scenarios addressed by this change are covered by direct regression tests and repo-local invariant coverage.

## 6. Implementation Specification

### 6.1 Analysis Scope

- controller-owned interruption flow across runtime, interaction facade, and scene-mutation entrypoints
- move-session terminalization and baseline-selection restore semantics
- draw-session captured state for preview, commit, and two-tap pending line flow
- view/runtime detachment path for opaque pointer sessions
- invariant and documentation statements for the same final contract

### 6.2 Target Verification Units

- [test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart)
- [test/interactive/core/scene_controller_interactive_basics_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart)
- [test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart)
- [test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart)
- [test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart)
- [test/view/scene_view_interactive_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_interactive_test.dart)
- [test/contract/runtime_contract_interfaces_test.dart](/Users/blackpika/iwb_canvas_engine/test/contract/runtime_contract_interfaces_test.dart)
- [test/interactive/core/scene_controller_architecture_boundary_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_architecture_boundary_test.dart)

### 6.3 Protected States, Data, or Structures

- controller-owned active gesture identity in [interactive_gesture_machine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_gesture_machine.dart)
- move baseline selection, marquee state, and preview state
- draw captured style, stroke preview points, active line preview, pending line start, and pending line style
- pointer-session detach lifecycle, pending tap timer state, and pointer-tracker state
- current exclusivity rules for public scene and selection mutations

### 6.4 Allowed Semantic Change Zones

- [interactive_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_runtime.dart) must distinguish semantic interruption from destructive cleanup; public boundary callers may use only the semantic interruption entrypoint.
- [scene_controller_interaction_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_runtime.dart), [scene_controller_interaction.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interaction.dart), and [scene_controller_scene_mutations.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_scene_mutations.dart) must route `setMode(...)`, `setDrawTool(...)`, `setCameraOffset(...)`, `replaceScene(...)`, and `SceneController.dispose()` through that semantic interruption entrypoint.
- [interactive_move_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart) must expose one terminalization path for pointer `cancel` and forced interruption so baseline-selection restore happens before state clear whenever move changed selection locally.
- [interactive_draw_gesture_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_gesture_session.dart) must become the owner of captured draw-style state for the active draw gesture.
- [interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart), [interactive_draw_line_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_line_engine.dart), [interactive_draw_stroke_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_stroke_engine.dart), and [interactive_draw_terminal_router.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_terminal_router.dart) must consume captured style for pointer-move updates, preview read-side, pending-line carry, and terminal commit; live config reads after `down` are forbidden for the active flow.
- [scene_controller_interaction.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interaction.dart) must expose active preview thickness, color, and opacity from runtime-owned captured state rather than `_access.config`.
- [scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_view_runtime.dart) must gain one explicit detachment entrypoint on `SceneViewPointerSession`; it must be internal-safe and idempotent.
- [scene_controller_pointer_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_pointer_session.dart) must implement detachment by invoking controller-side semantic interruption and clearing pointer-tracker and pending-timer state without emitting commit, double-tap, or scene mutation.
- [scene_view_interactive_pointer_host.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart) and [scene_view_runtime_host.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_runtime_host.dart) must call session detachment before replacing or disposing an opaque session; host-side router reset remains host-owned and happens only after detachment of the old session.

### 6.8 Prohibited

- calling raw `resetInteractiveState()` or equivalent destructive cleanup directly from `setMode(...)`, `setDrawTool(...)`, `setCameraOffset(...)`, `replaceScene(...)`, runtime swap, or host disposal
- reading live draw config as the source of truth for an already active draw preview or pending-line flow
- committing move, stroke, line, erase, or action events during forced interruption or session detachment
- moving controller-side gesture semantics into [scene_view_interactive_pointer_host.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart) or [scene_view_runtime_host.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_runtime_host.dart)
- introducing a second active-gesture owner in `view/**` or public capability facades
- widening public API or bypassing the existing mutation boundary

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, the reproducer test must assert the former trigger point directly.
7. New invariant ids and new `// INV:` markers must land in the same slice as their proof tests.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. Slice 1 is the mandatory architecture spine; slices 2 and 3 must consume its semantic interruption contract and may not create parallel reset paths.
10. Every newly proposed file or directory name must comply with the global `AGENTS.md` file-naming rules before the slice is considered valid.
11. The plan must remain inside the current controller-owned owner graph; reopening public API or view-routing architecture is forbidden.

## 8. Vertical Slices

### Slice 1. [ ] Semantic Active-Gesture Interruption

#### Slice Contract

All non-pointer interruption paths terminate the active gesture through one semantic interruption path, and forced interruption of move restores baseline selection with the same semantics as pointer `cancel`.

#### Change

Refactor [interactive_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_runtime.dart), [scene_controller_interaction_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_runtime.dart), [scene_controller_interaction.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interaction.dart), and [scene_controller_scene_mutations.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_scene_mutations.dart) so only controller-owned interruption call sites no longer invoke raw reset. In this slice, those call sites are `setMode(...)`, `setDrawTool(...)`, `setCameraOffset(...)`, `replaceScene(...)`, and `SceneController.dispose()`. Refactor [interactive_move_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart) so pointer `cancel` and forced interruption share one restore-and-clear path. Keep draw interruption behavior non-committing and behavior-preserving through [interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart). Preserve current no-op and rejected-operation behavior. Do not add or change `SceneViewPointerSession` detachment in this slice.

#### Verification

- MCP run of [test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart)
- MCP run of [test/interactive/core/scene_controller_interactive_basics_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_basics_test.dart)
- MCP run of [test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart)
- MCP run of [test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart)

#### Fixtures Used

- [test/interactive/test_support/interactive_controller_fixtures.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/test_support/interactive_controller_fixtures.dart)

#### Positive Scenarios

- active marquee or move interrupted by `setMode(...)`, `setDrawTool(...)`, `setCameraOffset(...)`, and `replaceScene(...)` restores the original selection baseline when the gesture changed selection locally
- active draw interrupted by mode/tool/camera/scene replacement clears preview and pending-line latent state without commit
- no-op `setCameraOffset(...)` and rejected `replaceScene(...)` preserve the active gesture

#### Negative Scenarios

- forced interruption does not emit transform or draw actions
- forced interruption does not commit previewed geometry
- deny-listed public scene and selection mutations remain rejected during an active gesture

#### Closure Evidence

- green run of the listed verifications
- direct regression assertions for forced move interruption that follows the same baseline-selection restore semantics as pointer `cancel`

### Slice 2. [ ] Draw Style Snapshot Ownership

#### Slice Contract

Active draw preview and commit use style captured from gesture start state, including two-tap pending-line state, and ignore mid-flow config mutations until the flow ends.

#### Change

Refactor [interactive_draw_gesture_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_gesture_session.dart) into the owner of captured draw style. Update [interactive_gesture_router.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_gesture_router.dart), [interactive_runtime_callbacks.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_runtime_callbacks.dart), [interactive_draw_coordinator.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_coordinator.dart), [interactive_draw_stroke_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_stroke_engine.dart), [interactive_draw_line_engine.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_line_engine.dart), [interactive_draw_terminal_router.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_terminal_router.dart), and [scene_controller_interaction.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/scene_controller_interaction.dart) so preview getters and commit paths read captured style, not live config. Pending two-tap line state must carry its own captured style until commit, timeout, cancel, or forced interruption.

#### Verification

- MCP run of [test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart)
- MCP run of [test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart)
- MCP run of [test/view/scene_view_interactive_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_interactive_test.dart)

#### Fixtures Used

- [test/interactive/test_support/interactive_controller_fixtures.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/test_support/interactive_controller_fixtures.dart)

#### Positive Scenarios

- highlighter preview keeps original thickness and opacity after mid-drag changes to `highlighterThickness` and `highlighterOpacity`
- stroke preview and final stroke keep original color after mid-drag `setDrawColor(...)`
- dragged line preview and final line keep original thickness and color after mid-drag config changes
- two-tap line commit keeps the style captured by the first tap even if draw config changes before the second tap

#### Negative Scenarios

- post-terminal config changes affect the next gesture immediately
- tool change during an active draw interrupts the active flow instead of committing with cross-tool mixed state

#### Closure Evidence

- green run of the listed verifications
- direct regression assertions for active draw preview and commit keeping gesture-start style across mid-flow config changes

### Slice 3. [ ] Pointer-Session Detachment Before Dispose

#### Slice Contract

Replacing or disposing a `SceneViewPointerSession` detaches the old session semantically before disposal and router reset, so the old controller cannot remain stuck with an active gesture.

#### Change

Extend [scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/contract/scene_view_runtime.dart) with one explicit detachment entrypoint on `SceneViewPointerSession`. Implement it in [scene_controller_pointer_session.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_pointer_session.dart). Update [scene_view_interactive_pointer_host.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_interactive_pointer_host.dart), [scene_view_runtime_host.dart](/Users/blackpika/iwb_canvas_engine/lib/src/view/scene_view_runtime_host.dart), and [scene_controller_scene_view_runtime.dart](/Users/blackpika/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_scene_view_runtime.dart) so replacement of a pointer session and disposal of the runtime host always detach before disposing the old session. This slice owns only view/runtime-side session detachment and must not reopen controller-owned interruption call sites already closed in Slice 1. Detach must be idempotent and non-committing.

#### Verification

- MCP run of [test/view/scene_view_interactive_test.dart](/Users/blackpika/iwb_canvas_engine/test/view/scene_view_interactive_test.dart)
- MCP run of [test/contract/runtime_contract_interfaces_test.dart](/Users/blackpika/iwb_canvas_engine/test/contract/runtime_contract_interfaces_test.dart)
- MCP run of [test/interactive/core/scene_controller_architecture_boundary_test.dart](/Users/blackpika/iwb_canvas_engine/test/interactive/core/scene_controller_architecture_boundary_test.dart)

#### Positive Scenarios

- swapping runtime while move is active leaves the old controller able to perform previously blocked public mutations
- swapping runtime while draw is active clears old preview state and releases the old controller
- disposing the host while the controller survives leaves no active gesture in the controller

#### Negative Scenarios

- detaching an idle session is a no-op
- detaching a session emits no action commits, edit requests, or scene mutations
- pending tap timer cancellation on controller swap remains green

#### Closure Evidence

- green run of the listed verifications
- direct regression assertions for runtime swap and host disposal detaching the old pointer session before disposal

### Slice 4. [ ] Invariant and Documentation Closure

#### Slice Contract

Repository-local documentation and invariants describe and enforce the new semantic interruption, draw-style snapshot, and pointer-session detachment contracts.

#### Change

Update [README.md](/Users/blackpika/iwb_canvas_engine/README.md), [API_GUIDE.md](/Users/blackpika/iwb_canvas_engine/API_GUIDE.md), [ARCHITECTURE.md](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md), [CHANGELOG.md](/Users/blackpika/iwb_canvas_engine/CHANGELOG.md), and [tool/invariant_registry.dart](/Users/blackpika/iwb_canvas_engine/tool/invariant_registry.dart). Keep `INV-ENG-INTERACTIVE-CANCEL-STATE-RESET` pointer-cancel-specific. Add new invariant ids for semantic interruption, draw-style snapshot, and pointer-session detachment, and place matching `// INV:` markers into the proof tests introduced or updated by slices 1-3.

#### Verification

- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP re-run of the proof tests updated in slices 1-3

#### Closure Evidence

- green run of the listed verifications
- updated invariant registry entries and matching proof markers
- updated release-ready documentation and `## Unreleased` changelog entry

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/interactive/internal/interactive_runtime.dart lib/src/interactive/internal/interactive_gesture_machine.dart lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/scene_controller_pointer_session.dart lib/src/view/scene_view_interactive_pointer_host.dart`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP shard preset `core`
- MCP shard preset `model_contract`
- MCP shard preset `controller_internal`
- MCP shard preset `controller`
- MCP shard preset `render_view`
- MCP shard preset `interactive`
- MCP shard preset `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
- The lifecycle scenarios addressed by this step have direct regression tests and invariant-backed proof surfaces.
