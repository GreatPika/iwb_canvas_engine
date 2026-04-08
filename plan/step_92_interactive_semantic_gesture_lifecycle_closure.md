# Change Contract

## 1. Change Mandate

This change closes the interactive lifecycle by separating manual pointer input,
session-routed input, interruption reasons, draw-style snapshot ownership, and
pointer-session detachment onto explicit internal owners instead of raw reset
paths or public-facade transport.

## 2. Change Boundary

### Included in the Change

- explicit internal ownership for session-routed pointer provenance
- explicit runtime entrypoints for interaction-config interruption, external
  mutation interruption, pointer-session detachment, and destructive dispose
- draw-style snapshot ownership for active stroke/line flows and owner-scoped
  pending-line state
- `SceneViewPointerSession.detach()` and host ordering for replace/dispose
- structural tests, tool guardrails, invariants, and release-ready docs for the
  new lifecycle shape

### Not Included in the Change

- any public API widening of `SceneController`, `SceneControllerInteraction`,
  `SceneControllerSelection`, `SceneControllerScene`, or `CanvasPointerInput`
- any change to raw pointer slot allocation or routing policy in
  `scene_view_pointer_router.dart`
- any change to committed write semantics outside the already allowed
  interruption preflight for `setCameraOffset(...)` and `replaceScene(...)`
- any new draw tools, gesture families, render features, undo/redo behavior,
  model/serialization work, or app-level UI behavior

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/internal/pointer_session_token.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`
- `lib/src/interactive/internal/interactive_pointer_normalizer.dart`
- `lib/src/interactive/internal/interactive_gesture_machine.dart`
- `lib/src/interactive/internal/interactive_gesture_router.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator.dart`
- `lib/src/interactive/internal/interactive_draw_gesture_session.dart`
- `lib/src/interactive/internal/interactive_draw_line_engine.dart`
- `lib/src/interactive/internal/interactive_draw_stroke_engine.dart`
- `lib/src/interactive/internal/interactive_draw_terminal_router.dart`
- `lib/src/interactive/internal/scene_controller_pointer_session.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- `lib/src/contract/scene_view_runtime.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/view/scene_view_runtime_host.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/src/guardrails/interactive_mutation_guard_contract.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `tool/invariant_registry.dart`

### Test Files

- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
- `test/interactive/core/scene_controller_interactive_dispose_matrix_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/tool/coverage_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

### Fixture and Supporting Data Files

- `test/interactive/test_support/interactive_controller_fixtures.dart`
- `VERIFICATION.md`
- `plan/step_92_interactive_semantic_gesture_lifecycle_closure.md`

### Analysis Area

- `lib/src/interactive/**`
- `lib/src/view/**`
- `lib/src/contract/scene_view_runtime.dart`
- `test/interactive/**`
- `test/view/**`
- `test/contract/runtime_contract_interfaces_test.dart`
- `tool/src/guardrails/**`
- `test/tool/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneController` remains the only public interactive root, and
   `SceneViewRuntime` / `SceneViewPointerSession` remain the only internal-safe
   view/runtime contracts.
2. `CanvasPointerInput` remains a provenance-free public DTO. Session ownership
   must not re-enter it through extra fields, hidden subclasses, runtime-type
   checks, or supported public API semantics.
3. Session-routed input and double-tap traffic must stop using the public
   `SceneControllerInteraction.handlePointer(...)` and
   `SceneControllerInteraction.handleDoubleTap(...)` entrypoints as transport
   for session-only semantics.
4. Public/manual entrypoints and session-routed entrypoints are boundary shims
   only. After provenance is resolved, they must converge into the same
   internal pointer-dispatch path and the same internal double-tap-dispatch
   path instead of duplicating downstream gesture, draw, or mutation logic per
   entrypoint.
5. Session ownership is represented by the explicit internal
   `PointerSessionToken` type and not by `Object? owner`, `Object? context`,
   or any other untyped ownership carrier.
6. Pending line remains draw-local latent state owned by
   `InteractiveDrawLineEngine`, and active draw snapshot remains owned by
   `InteractiveDrawGestureSession`.
7. Interaction-config interruption, external-mutation interruption,
   pointer-session detachment, and `SceneController.dispose()` are distinct
   lifecycle reasons in the target architecture and must not be collapsed into
   one boundary-level reset API.
8. `SceneViewInteractivePointerHost` remains a raw routing/lifecycle shell over
   an opaque `SceneViewPointerSession` and must not become a gesture owner,
   pointer-tracker owner, or pending-setting owner.

## 5. Result Requirements

1. View-routed pointer and double-tap traffic reach the controller through an
   explicit internal session path with `PointerSessionToken`; the public
   `SceneControllerInteraction` manual entrypoints no longer carry
   session-specific semantics.
2. External mutation interruption, interaction-config interruption,
   pointer-session detachment, and controller dispose use distinct runtime
   entrypoints whose names and behaviors match those reasons.
3. Active move interruption restores gesture-baseline selection exactly when
   pointer `cancel` would restore it; session detachment of a non-owning
   session leaves the active move gesture untouched.
4. Active draw preview and two-tap pending line use gesture-start style for the
   full lifetime of that flow, and mid-flow config changes affect only the next
   flow.
5. Pending line is owner-scoped: it stores both captured style and ownership
   provenance, and it cannot be completed by a different owner source.
6. Pointer-session detachment clears only session-owned state: active gesture
   owned by that session, pending-line latent state owned by that session, and
   that session’s pointer-normalizer / tracker / timer state. It emits no draw
   commit, move commit, erase commit, action event, edit request, or committed
   scene mutation.
7. Session replacement and host disposal call `detach()` before disposing the
   old session and before any host-side router reset, and the old controller is
   not left with an active gesture or stale pending-line ownership.
8. Repository-local docs, invariants, and structural/tool proofs describe the
   same boundary shape and fail if the hidden-subtype path, untyped ownership
   path, or one-reset-for-all path returns.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `SceneControllerPointerSession` currently depends on
  `SceneControllerInteraction Function()` and forwards both pointer samples and
  double taps through the public interaction facade.
- `InteractivePointerNormalizer` currently keys last-finite pointer state only
  by `pointerId`, so it cannot selectively forget session-owned state when the
  view host replaces a session and raw slot ids are reused.
- `InteractiveGestureMachine` currently stores only `pointerId`, gesture family,
  and `dragStartSlop`, so it cannot detach an active gesture by session owner.
- `InteractiveRuntime` currently exposes `resetInteractiveState()`, and
  `SceneControllerInteraction`, `SceneControllerSceneMutations`, and
  `SceneController.dispose()` still use raw reset terminology at the boundary.
- `InteractiveDrawGestureSession` currently stores only `downScene` and
  `moved`, while `InteractiveDrawLineEngine` pending-line state currently stores
  only start/timestamp/timer. Neither owner can represent captured style or
  session provenance.
- `SceneControllerInteraction` preview getters currently read live mutable
  config for stroke/line style even while an active preview exists.
- `test/view/scene_view_interactive_test.dart` currently observes routed host
  input by overriding the public `SceneControllerInteraction.handlePointer(...)`
  method on `_RecordingPointerController`, which is the exact public-facade
  transport this step removes.
- Tool guardrails, sandbox fixtures, and synthetic runtime-contract coverage
  fixtures currently mirror the old public/manual runtime boundary names
  `handlePointer(...)` / `handleDoubleTap(...)`, the old mutation method name
  `resetActiveGestureBeforeExternalMutation`, and the old
  `SceneViewPointerSession` contract shape without `detach()`.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/interactive/internal/pointer_session_token.dart lib/src/interactive/scene_controller_interaction.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/interactive_runtime.dart lib/src/interactive/internal/interactive_pointer_normalizer.dart lib/src/interactive/internal/interactive_gesture_machine.dart lib/src/interactive/internal/interactive_draw_gesture_session.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/scene_controller_pointer_session.dart lib/src/interactive/internal/scene_controller_scene_view_runtime.dart lib/src/view/scene_view_interactive_pointer_host.dart --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP run of `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- MCP run of `test/interactive/core/scene_controller_interaction_contract_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_dispose_fail_fast_test.dart`
- MCP run of `test/interactive/core/scene_controller_interactive_dispose_matrix_test.dart`
- MCP run of `test/view/scene_view_interactive_test.dart`
- MCP run of `test/contract/runtime_contract_interfaces_test.dart`
- MCP shard preset `core`
- MCP shard preset `model_contract`
- MCP shard preset `controller_internal`
- MCP shard preset `controller`
- MCP shard preset `render_view`
- MCP shard preset `interactive`
- MCP shard preset `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- public `SceneControllerInteraction` manual pointer and double-tap semantics
- active gesture exclusivity and active-pointer ownership
- move baseline selection restore semantics on cancel/interruption
- draw preview points, active line preview, pending line start/timestamp, and
  their non-committing behavior
- pointer-normalizer terminal semantics for non-finite up/cancel input
- pointer-settings apply-on-idle and pending tap flush scheduling in
  `SceneControllerPointerSession`
- `actions` / `editTextRequests` delivery semantics and dispose fail-fast
- `SceneViewRuntime` and `SceneViewPointerSession` as the only view/runtime
  bridge contracts

### 6.4 Allowed Semantic Change Zones

- session-routed pointer provenance and detachment semantics inside the
  interactive runtime graph
- boundary naming and call-site intent for interruption reasons
- owner metadata stored on active gesture and pending-line latent state
- read-side preview style source for active draw flows
- view host replacement/dispose order around opaque pointer sessions
- repo-local structural/tool proof surface for the above boundaries

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct bypass
- subtype-based bypass
- runtime-type bypass
- local-function bypass
- intermediate-call bypass
- nullable-owner-parameter bypass

### 6.6 Allowed Forms That Do Not Count as Violations

- public manual pointer input continuing to use
  `SceneControllerInteraction.handlePointer(...)` and
  `SceneControllerInteraction.handleDoubleTap(...)`
- `SceneControllerSceneViewRuntime` continuing to read
  `controller.interaction` and `controller.snapshot` through owner closures for
  render-state overrides
- private helpers inside `SceneControllerPointerSession` implementing the exact
  ordered detach steps defined in Slice 4
- private helpers inside an existing owner file, as long as they do not create
  a second boundary owner or reopen the public/session transport seam

### 6.7 Requirements for Resolution of Links and Structural Analysis

- This step may introduce exactly one new production file:
  `lib/src/interactive/internal/pointer_session_token.dart`. No other new
  production files or directories are allowed in this step.
- `PointerSessionToken` must stay internal to `lib/src/interactive/internal/**`
  and must not be exposed from `lib/iwb_canvas_engine.dart`,
  `SceneController`, `SceneControllerInteraction`, `SceneViewRuntime`, or
  `SceneViewPointerSession`.
- `PointerSessionToken` must remain an opaque nominal type with no public raw
  id field, no serialization role, and no custom equality semantics. Token
  comparison is by object identity inside one controller runtime only.
- `PointerSessionToken` is allocated only for `SceneViewPointerSession`
  instances created through `SceneViewRuntime.createPointerSession(...)`.
  Manual/public input uses the dedicated public-input namespace inside the
  owning internal state and must not allocate or fabricate a synthetic token.
- Every `createPointerSessionToken()` call must return a fresh token for the
  lifetime of the owning controller runtime. Tokens must not be recycled or
  reassigned after pointer-session replacement or disposal.
- The new boundary symbols introduced by this step use the exact names fixed
  in this contract: `PointerSessionToken`, `handlePublicPointer(...)`,
  `handlePublicDoubleTap(...)`, `handlePointerFromSession(...)`,
  `handleDoubleTapFromSession(...)`,
  `interruptForInteractionConfigChange()`,
  `interruptForExternalMutation()`, and `detachPointerSession(...)`. Do not
  substitute synonyms, abbreviations, or umbrella names for these concepts.
- `SceneViewPointerSession` may grow exactly one new method: `void detach();`.
  It must not grow controller mutation APIs, token-bearing APIs, or any
  callback-style controller-update API.
- `SceneControllerInteraction` must not gain any session-specific or
  token-bearing methods. Manual/public pointer APIs stay exactly
  `handlePointer(...)` and `handleDoubleTap(...)`.
- `InteractivePointerNormalizer`, `InteractiveGestureMachine`,
  `InteractiveDrawGestureSession`, and `InteractiveDrawLineEngine` are the only
  production owners allowed to persist session-token state. No other runtime,
  router, draw-engine, facade, or view owner may retain that provenance.
- `SceneControllerPointerSession` may store its own token as an opaque
  constructor dependency, but it must not interpret token ownership locally
  beyond forwarding session-scoped runtime calls and invoking `detach()`.
- Raw host-routing proofs in `test/view/scene_view_interactive_test.dart` must
  move to a local fake `SceneViewRuntime` / `SceneViewPointerSession` test
  double. Production code must not grow new debug hooks solely to replace the
  removed `_RecordingPointerController` transport path.
- `scene_controller_internal_access.dart` remains test-only and must not become
  a production bridge for pointer/session transport.

### 6.8 Prohibited

- reintroducing hidden ownership through a subclass of `CanvasPointerInput`
- using `Object? owner`, `Object? session`, `Object? context`, or similar
  untyped ownership transport in production code
- routing session-owned pointer or double-tap semantics through the public
  `SceneControllerInteraction.handlePointer(...)` or
  `SceneControllerInteraction.handleDoubleTap(...)` entrypoints
- keeping `handlePointer(...)` or `handleDoubleTap(...)` as parallel boundary
  aliases on `SceneControllerInteractionRuntime` or `InteractiveRuntime` after
  the public/session split lands
- implementing public/manual pointer or double-tap handling by fabricating a
  synthetic `PointerSessionToken` and forwarding through the session-routed
  path
- keeping `resetInteractiveState()` as a boundary-level lifecycle API or
  calling it directly from `setMode(...)`, `setDrawTool(...)`,
  `setCameraOffset(...)`, `replaceScene(...)`, view host replacement/dispose,
  or `SceneController.dispose()`
- representing controller dispose as `interruptForExternalMutation()` or
  `detachPointerSession(...)`
- moving pending-line ownership out of `InteractiveDrawLineEngine`
- allowing a pending line started by one ownership source to commit from a
  different ownership source
- widening public supported API to expose session detachment or token concepts

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
9. Slice 1 is the mandatory architecture spine. Slices 2-4 must consume its
   internal session path and may not re-open public-facade transport.
10. If a slice renames a guarded method or changes a contract token used by
    structural/tool proofs, the matching guardrail expectations and sandbox
    fixtures must be updated in the same slice.
11. The plan must remain inside the current interactive/view owner graph. It
    may not reopen a second public controller, a second runtime boundary, or a
    production test-probe bridge.

## 8. Vertical Slices

### Slice 1. [ ] Session-Routed Input Leaves The Public Facade

#### Slice Contract

View-routed pointer and double-tap traffic enter the controller through an
explicit internal session path with `PointerSessionToken`, and the public
interaction facade no longer transports session-only semantics.

#### Change

Introduce `lib/src/interactive/internal/pointer_session_token.dart` with the
single internal `PointerSessionToken` declaration. Extend
`SceneControllerInteractionRuntime` and `InteractiveRuntime` with exact
session-path entrypoints:

- `createPointerSessionToken()`
- `handlePublicPointer(CanvasPointerInput input)`
- `handlePublicDoubleTap({required Offset position, int? timestampMs})`
- `handlePointerFromSession(CanvasPointerInput input, {required PointerSessionToken token})`
- `handleDoubleTapFromSession({required Offset position, int? timestampMs, required PointerSessionToken token})`

Update `SceneControllerInteraction.handlePointer(...)` and
`SceneControllerInteraction.handleDoubleTap(...)` so they delegate only to the
public/manual runtime entrypoints.

The old boundary method names `handlePointer(...)` and `handleDoubleTap(...)`
on `SceneControllerInteractionRuntime` / `InteractiveRuntime` must be retired
from that boundary surface in this slice. Private shared helpers may remain
only below the boundary seam.

Update `SceneControllerSceneViewRuntime.createPointerSession(...)` so it creates
a token through `SceneControllerInteractionRuntime.createPointerSessionToken()`
and constructs `SceneControllerPointerSession` with exact constructor
dependencies:

- `Listenable ownerListenable`
- the token
- `PointerInputSettings Function() readPointerSettings`
- `void Function(CanvasPointerInput input, {required PointerSessionToken token}) handlePointerFromSession`
- `void Function({required Offset position, int? timestampMs, required PointerSessionToken token}) handleDoubleTapFromSession`
- `bool Function() isMounted`
- `bool Function() hasLiveRawPointers`

Remove the `SceneControllerInteraction Function() readInteraction` dependency
from `SceneControllerPointerSession`. The session may still receive
`readPointerSettings`, but it must no longer call the public interaction facade
to forward routed pointer or double-tap traffic.

Both public/manual entrypoints and session-routed entrypoints must converge
below the provenance boundary into one shared internal pointer-dispatch path
and one shared internal double-tap-dispatch path. Slice 1 must not duplicate
gesture-router, draw-coordinator, or mutation-boundary logic per entrypoint.

Update `test/view/scene_view_interactive_test.dart` so raw host-routing proofs
use a fake `SceneViewRuntime` / `SceneViewPointerSession` recorder mounted
through `SceneViewRuntimeHost`. Remove `_RecordingPointerController` and
`_RecordingPointerInteraction`; controller-backed view tests remain only where
the proof actually depends on a real controller.

Update `test/interactive/core/scene_controller_architecture_boundary_test.dart`
and `test/interactive/core/scene_controller_interaction_contract_test.dart` so
they pin the new public/session split:

- `SceneControllerInteraction.handlePointer(...)` delegates to
  `handlePublicPointer(...)`
- `SceneControllerInteraction.handleDoubleTap(...)` delegates to
  `handlePublicDoubleTap(...)`
- `SceneControllerPointerSession` no longer depends on
  `SceneControllerInteraction`
- `SceneControllerSceneViewRuntime` injects the explicit session callbacks and
  token creation path

Update `tool/src/guardrails/interactive_api_guardrails.dart`,
`test/tool/guardrails/guardrails_interactive_api_tool_test.dart`, and
`test/tool/support/guardrails_tool_test_support.dart` in the same slice so the
repo-local guardrails pin the new public/manual runtime boundary names and
reject reintroduction of public-facade session transport.

#### Verification

- MCP run of `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- MCP run of `test/interactive/core/scene_controller_interaction_contract_test.dart`
- MCP run of `test/view/scene_view_interactive_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Positive Scenarios

- raw host routing still allocates stable routed pointer ids and forwards
  `down` / `move` / `up` / `cancel` phases correctly through the session path
- session-side double-tap recognition still forwards through the internal
  session callback path without using the public interaction facade
- invalid down and move are still dropped before session-side effects
- invalid terminal input is still forwarded with the original terminal phase

#### Negative Scenarios

- public `SceneControllerInteraction.handlePointer(...)` contains no session
  token, session-detach, runtime-type, or hidden-subclass logic
- public `handlePointer(...)` / `handleDoubleTap(...)` are not implemented by
  allocating a synthetic `PointerSessionToken` and forwarding through the
  session-only path
- `SceneControllerPointerSession` no longer depends on the public interaction
  facade to forward routed input or double taps

#### Closure Evidence

- green run of the listed verifications
- structural assertions proving that routed input no longer travels through the
  public interaction facade

### Slice 2. [ ] Lifecycle Reasons Are Split And Owned

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
matching key on `(pointerId, session token namespace)` and so the machine can:

- interrupt the current active gesture without exposing a generic reset API
- detach only the active gesture owned by a specific `PointerSessionToken`

Refactor `InteractivePointerNormalizer` so public/manual input and session
input use separate internal key namespaces. Add `detachSession(token)` that
forgets only last-finite positions owned by that session.

Refactor `InteractiveMoveSession` so pointer `cancel`,
`interruptForInteractionConfigChange()`,
`interruptForExternalMutation()`, and owning-session detachment all use the
same non-committing restore-and-clear path. Non-owning session detachment must
be a no-op for move state.

Refactor `SceneControllerInteractionRuntime` and
`SceneControllerSceneMutations` to remove the old
`resetActiveGestureBeforeExternalMutation` terminology. The exact replacement
name for mutation-owner policy is `interruptForExternalMutation`.
Update `tool/src/guardrails/interactive_mutation_guard_contract.dart`,
`tool/src/guardrails/interactive_api_guardrails.dart`,
`test/tool/guardrails/guardrails_interactive_api_tool_test.dart`, and
`test/tool/support/guardrails_tool_test_support.dart` in the same slice so the
repo-local guardrails enforce the renamed policy without a red intermediate
state.

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
- no-op camera updates and rejected scene replacement still preserve the active
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

### Slice 3. [ ] Draw Snapshot And Owner-Scoped Pending Line

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

`InteractiveGestureRouter` may read `callbacks.readDrawStyle()` only on pointer
`down`. After `down`, all active draw preview and terminal behavior must read
from `InteractiveDrawGestureSession.capturedStyle`.

Refactor `InteractiveDrawLineEngine` so pending line is represented by one
owner-local carrier inside that file. The carrier must store exactly:

- `Offset start`
- `int timestampMs`
- `InteractiveDrawStyle capturedStyle`
- `PointerSessionToken? sessionToken`
- timeout timer state

`InteractiveDrawLineEngine` must implement exact owner-scoped pending-line
semantics:

- drag gesture clears any existing pending line before active preview
- first tap with no pending line stores a pending line for the current owner
- second tap from the same owner commits using the pending line’s captured
  style, not the second tap’s current config
- tap from a different owner replaces the old pending line with a new pending
  line for the new owner and does not cross-owner commit
- `detachPointerSession(token)` clears only the matching pending line

Refactor `InteractiveDrawStrokeEngine`, `InteractiveDrawTerminalRouter`, and
`InteractiveDrawCoordinator` so stroke commit, line commit, line preview,
stroke preview, and interruption all consume captured draw state instead of
live mutable config.

Update `SceneControllerInteraction` and
`SceneControllerSceneViewRenderState` preview getters so active preview
thickness/color/opacity read runtime-captured values whenever the corresponding
preview is active. Public draw-setting getters still read the mutable config for
future gestures.

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
  mid-drag `highlighterThickness` / `highlighterOpacity` changes
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

### Slice 4. [ ] Pointer Session Detaches Before Replace And Dispose

#### Slice Contract

Replacing or disposing an opaque `SceneViewPointerSession` detaches the old
session before disposal and before host-side router reset, so the old
controller is not left with active gesture or pending-line ownership.

#### Change

Extend `lib/src/contract/scene_view_runtime.dart` so
`SceneViewPointerSession` defines exactly one new lifecycle method:

- `void detach();`

No other new methods are allowed on the contract in this step.

Extend the `SceneControllerSceneViewRuntime -> SceneControllerPointerSession`
constructor seam with exactly one new controller callback:

- `void Function(PointerSessionToken token) detachPointerSession`

Implement `SceneControllerPointerSession.detach()` as an idempotent,
allow-after-dispose-safe, non-committing method that:

1. marks the session detached
2. cancels pending tap timer and clears pending pointer-settings state
3. resets local pointer-tracker generation so late timer callbacks become
   no-ops
4. invokes controller-side `detachPointerSession(token)`

After `detach()` returns, all later `handleRoutedSample(...)`,
`handleInvalidTerminalSample(...)`, `handleRawPointerRelease(...)`, and
session-owned double-tap/timer flush callbacks must be local no-ops and must
not call the controller again, even if raw host events or timers arrive late.

`SceneControllerPointerSession.dispose()` remains local resource cleanup and
must be safe after `detach()`. Low-level tests that create sessions directly
must change their teardown to `detach(); dispose();` so the explicit contract is
exercised. This includes
`test/interactive/core/scene_controller_interaction_contract_test.dart` and
`test/contract/runtime_contract_interfaces_test.dart`.

Refactor `SceneViewInteractivePointerHost` so replacement order is exact:

1. old session `detach()`
2. old session `dispose()`
3. router `reset()`
4. install the new session

Host disposal order is exact:

1. current session `detach()`
2. current session `dispose()`

Update `SceneViewRuntimeHost`, `SceneControllerSceneViewRuntime`,
`test/interactive/core/scene_controller_architecture_boundary_test.dart`,
`test/interactive/core/scene_controller_interaction_contract_test.dart`,
`test/contract/runtime_contract_interfaces_test.dart`,
`test/tool/coverage_tool_test.dart`,
`tool/src/guardrails/interactive_api_guardrails.dart`,
`test/tool/guardrails/guardrails_interactive_api_tool_test.dart`, and
`test/tool/support/guardrails_tool_test_support.dart` in the same slice so the
contract shape, host ordering, and sandbox mirrors all agree.

#### Verification

- MCP run of `test/view/scene_view_interactive_test.dart`
- MCP run of `test/contract/runtime_contract_interfaces_test.dart`
- MCP run of `test/interactive/core/scene_controller_interaction_contract_test.dart`
- MCP run of `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/coverage_tool_test.dart`

#### Positive Scenarios

- swapping the runtime while move is active leaves the old controller able to
  perform previously blocked scene/selection mutations
- swapping the runtime while draw or pending line is active clears old preview
  and old pending-line ownership before the old session is disposed
- disposing the host while the controller survives leaves no active gesture or
  session-owned pending line in the controller

#### Negative Scenarios

- detaching an idle session is a no-op
- detaching a session emits no action commit, edit request, or committed scene
  mutation
- late routed samples, invalid terminal forwarding, or pending tap flushes
  arriving after `detach()` do not re-enter the controller
- `SceneViewInteractivePointerHost` still contains no pointer tracker, pending
  settings, or gesture-owner state

#### Closure Evidence

- green run of the listed verifications
- direct regression assertions proving detach-before-dispose ordering and old
  controller release on runtime swap / host disposal

### Slice 5. [ ] Documentation, Invariants, And Roadmap Closure

#### Slice Contract

Repository-local docs, invariants, and roadmap state describe and enforce the
new lifecycle taxonomy, draw-style snapshot contract, and pointer-session
detachment contract.

#### Change

Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md` so
they describe the final shape:

- manual public pointer input remains on `SceneControllerInteraction`
- session-routed input uses an internal tokenized path
- interaction-config interruption, external mutation interruption,
  session detachment, and dispose are distinct lifecycle reasons
- active draw style is captured on gesture start
- pending line is draw-local latent state with owner provenance
- view hosts detach sessions before replacement/disposal

Update `tool/invariant_registry.dart` with exactly these new invariants:

- `INV-ENG-INTERACTIVE-INTERRUPTION-SEMANTICS`
  - primary proof:
    `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `INV-ENG-INTERACTIVE-DRAW-STYLE-SNAPSHOT`
  - primary proof:
    `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- `INV-ENG-VIEW-POINTER-SESSION-DETACH`
  - primary proof:
    `test/view/scene_view_interactive_test.dart`

Keep `INV-ENG-INTERACTIVE-CANCEL-STATE-RESET` pointer-cancel-specific and do
not widen its title or proof to cover all interruption reasons.

Add matching `// INV:` markers in the proof files above and in any updated
structural test that directly proves the new boundary shape.

When this slice closes the step, mark Step 92 complete in `PLAN.md` and mark
all closed slice checkboxes in this step document.

#### Verification

- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP re-run of
  `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- MCP re-run of
  `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- MCP re-run of `test/view/scene_view_interactive_test.dart`

#### Closure Evidence

- green run of the listed verifications
- updated invariant registry entries and matching proof markers
- updated release-ready docs and `## Unreleased` changelog entry
- `PLAN.md` and this step document both marked complete

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/interactive/internal/pointer_session_token.dart lib/src/interactive/scene_controller_interaction.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/interactive_runtime.dart lib/src/interactive/internal/interactive_pointer_normalizer.dart lib/src/interactive/internal/interactive_gesture_machine.dart lib/src/interactive/internal/interactive_draw_gesture_session.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/scene_controller_pointer_session.dart lib/src/interactive/internal/scene_controller_scene_view_runtime.dart lib/src/view/scene_view_interactive_pointer_host.dart --report-all`
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
