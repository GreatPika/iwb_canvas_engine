# Change Contract

## 1. Change Mandate

This change removes session-routed pointer and double-tap transport from the
public interactive facade and moves routed input onto an explicit internal
session boundary.

## 2. Change Boundary

### Included in the Change

- explicit internal token ownership for session-routed pointer provenance
- separate public/manual and session-routed runtime entrypoints for pointer and
  double-tap delivery
- `SceneControllerPointerSession` rewiring away from
  `SceneControllerInteraction`
- view-host regression coverage that proves routed input without the public
  facade transport
- guardrails and structural tests for the new public/session split

### Not Included in the Change

- any public API widening of `SceneController`, `SceneControllerInteraction`,
  `SceneControllerSelection`, `SceneControllerScene`, or `CanvasPointerInput`
- lifecycle-reason split for interaction-config changes, external mutations,
  detachment, or dispose
- draw-style snapshot capture and pending-line owner semantics
- `SceneViewPointerSession.detach()` or host replacement/dispose ordering
- docs, invariant-registry, or roadmap closure work

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller_interaction.dart`
- `lib/src/interactive/internal/pointer_session_token.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`
- `lib/src/interactive/internal/scene_controller_pointer_session.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`

### Test Files

- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

### Fixture and Supporting Data Files

- `test/interactive/test_support/interactive_controller_fixtures.dart`
- `plan/step_92_session_routed_input_boundary.md`

### Analysis Area

- `lib/src/interactive/**`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `lib/src/view/**`
- `test/interactive/**`
- `test/view/**`
- `tool/src/guardrails/**`
- `test/tool/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which the listed
  verification cannot be closed.

### File Change Rule

- Every modified production file must implement the public/session split or the
  new internal token boundary.
- Every modified test must pin one aspect of the routed-input transport change.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneController` remains the only public interactive root, and
   `SceneViewRuntime` / `SceneViewPointerSession` remain the only internal-safe
   view/runtime contracts.
2. `CanvasPointerInput` remains a provenance-free public DTO. Session
   ownership must not re-enter it through extra fields, hidden subclasses,
   runtime-type checks, or supported public API semantics.
3. Session-routed input and double-tap traffic must stop using the public
   `SceneControllerInteraction.handlePointer(...)` and
   `SceneControllerInteraction.handleDoubleTap(...)` entrypoints as transport
   for session-only semantics.
4. Public/manual entrypoints and session-routed entrypoints are boundary shims
   only. After provenance is resolved, they must converge into the same
   internal pointer-dispatch path and the same internal double-tap-dispatch
   path instead of duplicating downstream logic per entrypoint.
5. Session ownership is represented by the explicit internal
   `PointerSessionToken` type and not by `Object? owner`, `Object? context`,
   or any other untyped ownership carrier.
6. `SceneViewInteractivePointerHost` remains a raw routing/lifecycle shell over
   an opaque `SceneViewPointerSession` and must not become a gesture owner,
   pointer-tracker owner, or pending-setting owner.

## 5. Result Requirements

1. View-routed pointer and double-tap traffic reach the controller through an
   explicit internal session path with `PointerSessionToken`.
2. Public `SceneControllerInteraction.handlePointer(...)` and
   `handleDoubleTap(...)` remain manual/public entrypoints only and no longer
   carry session-specific semantics.
3. `SceneControllerPointerSession` no longer depends on
   `SceneControllerInteraction` to forward routed pointer or double-tap
   traffic.
4. `PointerSessionToken` remains an internal opaque nominal type with object-
   identity comparison only, and manual/public input does not fabricate a
   synthetic token.
5. Repository-local structural tests and guardrails fail if routed input is
   sent back through the public facade, if hidden subtype or runtime-type
   ownership transport returns, or if untyped ownership transport returns.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `SceneControllerPointerSession` currently depends on
  `SceneControllerInteraction Function()` and forwards both pointer samples and
  double taps through the public interaction facade.
- `test/view/scene_view_interactive_test.dart` currently observes routed host
  input by overriding the public `SceneControllerInteraction.handlePointer(...)`
  path on a recording controller, which is the transport this step removes.
- Tool guardrails and sandbox fixtures currently mirror the old
  `handlePointer(...)` / `handleDoubleTap(...)` runtime boundary names.
- `scene_controller_internal_access.dart` remains test-only and must not
  become a production bridge for pointer/session transport.

### 6.2 Target Verification Units

- MCP run of `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- MCP run of `test/interactive/core/scene_controller_interaction_contract_test.dart`
- MCP run of `test/view/scene_view_interactive_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### 6.3 Protected States, Data, or Structures

- public `SceneControllerInteraction` manual pointer and double-tap semantics
- raw host routing and routed pointer-id allocation semantics
- invalid down/move rejection and terminal forwarding behavior

### 6.4 Allowed Semantic Change Zones

- session-routed pointer provenance and transport semantics inside the
  interactive runtime graph
- view/runtime wiring between `SceneControllerSceneViewRuntime` and
  `SceneControllerPointerSession`
- repo-local structural and guardrail proofs for the public/session split

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
- Every `createPointerSessionToken()` call must return a fresh token for the
  lifetime of the owning controller runtime. Tokens must not be recycled or
  reassigned after pointer-session replacement or disposal.
- The new boundary symbols introduced by this step use the exact names fixed
  in this contract: `PointerSessionToken`, `handlePublicPointer(...)`,
  `handlePublicDoubleTap(...)`, `handlePointerFromSession(...)`, and
  `handleDoubleTapFromSession(...)`.
- `SceneControllerInteraction` must not gain any session-specific or
  token-bearing methods. Manual/public pointer APIs stay exactly
  `handlePointer(...)` and `handleDoubleTap(...)`.
- Manual/public input uses the dedicated public-input namespace inside the
  owning internal state and must not allocate or fabricate a synthetic token.
- Raw host-routing proofs in `test/view/scene_view_interactive_test.dart` must
  move to a local fake `SceneViewRuntime` / `SceneViewPointerSession` test
  double. Production code must not grow new debug hooks solely to replace the
  removed public-facade transport path.
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
  synthetic `PointerSessionToken` and forwarding through the session-only path

## 7. Execution Rules

1. This step is the architecture spine for steps `93-95`.
2. The public/session transport split must close in this step; later steps may
   consume it but may not reopen it.
3. Guardrail expectation changes for renamed or replaced boundary methods must
   land in the same change as the production rename.
4. Preparatory rewiring without green structural verification does not count as
   a closed step.

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
from that boundary surface in this step. Private shared helpers may remain
only below the provenance boundary.

Update `SceneControllerSceneViewRuntime.createPointerSession(...)` so it
creates a token through
`SceneControllerInteractionRuntime.createPointerSessionToken()` and constructs
`SceneControllerPointerSession` with exact constructor dependencies:

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
and one shared internal double-tap-dispatch path.

Update `test/view/scene_view_interactive_test.dart` so raw host-routing proofs
use a fake `SceneViewRuntime` / `SceneViewPointerSession` recorder mounted
through `SceneViewRuntimeHost`. Remove the controller-based public-facade
transport proof.

Update the listed architecture and guardrail tests in the same change so they
pin the new public/session split and reject reintroduction of public-facade
session transport.

#### Verification

- MCP run of `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- MCP run of `test/interactive/core/scene_controller_interaction_contract_test.dart`
- MCP run of `test/view/scene_view_interactive_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Positive Scenarios

- raw host routing still allocates stable routed pointer ids and forwards
  `down` / `move` / `up` / `cancel` phases correctly through the session path
- session-side double-tap recognition forwards through the internal session
  callback path without using the public interaction facade
- invalid down and move are still dropped before session-side effects
- invalid terminal input is still forwarded with the original terminal phase

#### Negative Scenarios

- public `SceneControllerInteraction.handlePointer(...)` contains no session
  token, session-detach, runtime-type, or hidden-subclass logic
- public manual entrypoints are not implemented by allocating a synthetic
  `PointerSessionToken` and forwarding through the session path
- `SceneControllerPointerSession` no longer depends on the public interaction
  facade to forward routed input or double taps

#### Closure Evidence

- green run of the listed verifications
- structural assertions proving that routed input no longer travels through the
  public interaction facade

## 9. Final Verification

- MCP run of `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- MCP run of `test/interactive/core/scene_controller_interaction_contract_test.dart`
- MCP run of `test/view/scene_view_interactive_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- The slice is closed.
- Final verification has passed.
