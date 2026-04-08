# Change Contract

## 1. Change Mandate

This change introduces explicit pointer-session detachment and requires view
host replacement/dispose to detach old sessions before disposal or router
reset.

## 2. Change Boundary

### Included in the Change

- `SceneViewPointerSession.detach()` as the explicit lifecycle contract for
  pointer-session detachment
- controller/runtime wiring for token-aware session detachment callbacks
- `SceneControllerPointerSession.detach()` idempotence and post-detach local
  no-op guarantees
- exact host ordering for session replacement and host disposal
- contract, guardrail, and runtime regression coverage for detach-before-dispose

### Not Included in the Change

- public/session routed-input transport split from step `92`
- lifecycle-reason split from step `93`
- draw-style snapshot and pending-line owner semantics from step `94`
- docs, invariant-registry, or roadmap closure work

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/scene_view_runtime.dart`
- `lib/src/interactive/internal/scene_controller_pointer_session.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/pointer_session_token.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/view/scene_view_runtime_host.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`

### Test Files

- `test/view/scene_view_interactive_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/coverage_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

### Fixture and Supporting Data Files

- `plan/step_95_pointer_session_detach_contract_and_host_ordering.md`

### Analysis Area

- `lib/src/contract/**`
- `lib/src/interactive/**`
- `lib/src/view/**`
- `test/contract/**`
- `test/interactive/**`
- `test/view/**`
- `tool/src/guardrails/**`
- `test/tool/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which the listed
  verification cannot be closed.

### File Change Rule

- Every modified production file must implement the new detach contract or the
  host ordering that consumes it.
- Every modified test must pin one detach-ordering, post-detach no-op, or
  contract-shape guarantee.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.

## 4. Locked Decisions

1. Steps `92-94` define the routed-input boundary, lifecycle taxonomy, and
   draw-owner semantics; this step consumes them instead of reopening those
   owners.
2. `SceneViewRuntime` and `SceneViewPointerSession` remain the only view/runtime
   bridge contracts.
3. `SceneViewPointerSession` may grow exactly one new lifecycle method in this
   sequence: `void detach();`.
4. Pointer-session detachment clears only session-owned state and emits no
   draw commit, move commit, erase commit, action event, edit request, or
   committed scene mutation.
5. `SceneViewInteractivePointerHost` remains a raw routing/lifecycle shell and
   must not become a pointer-tracker owner or gesture owner.

## 5. Result Requirements

1. Replacing or disposing an opaque `SceneViewPointerSession` detaches the old
   session before disposal and before any host-side router reset.
2. `SceneControllerPointerSession.detach()` is idempotent,
   allow-after-dispose-safe, and makes later session-owned callbacks local
   no-ops.
3. Swapping or disposing the host leaves the old controller with no active
   gesture or session-owned pending-line ownership.
4. Contract tests and guardrails fail if the detach method or detach-before-
   dispose ordering is removed.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `SceneViewPointerSession` currently has no explicit detachment contract.
- `SceneControllerPointerSession` currently cannot tell the controller to
  detach token-owned state before disposal.
- Host replacement/dispose order currently does not express detach-before-
  dispose as an enforced contract.

### 6.2 Target Verification Units

- MCP run of `test/view/scene_view_interactive_test.dart`
- MCP run of `test/contract/runtime_contract_interfaces_test.dart`
- MCP run of `test/interactive/core/scene_controller_interaction_contract_test.dart`
- MCP run of `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/coverage_tool_test.dart`

### 6.3 Protected States, Data, or Structures

- pointer-settings apply-on-idle and pending tap flush scheduling in
  `SceneControllerPointerSession`
- active gesture and pending-line state owned by a routed session
- `SceneViewRuntime` / `SceneViewPointerSession` as the only view/runtime
  bridge contracts

### 6.4 Allowed Semantic Change Zones

- `SceneViewPointerSession` contract shape
- `SceneControllerPointerSession` local detach lifecycle
- host replacement/dispose order around opaque pointer sessions
- structural and runtime proofs for detach-before-dispose behavior

### 6.5 Requirements for Resolution of Links and Structural Analysis

- `SceneViewPointerSession` must define exactly one new lifecycle method:
  `void detach();`.
- `SceneViewPointerSession` must not grow controller mutation APIs,
  token-bearing APIs, or any callback-style controller-update API.
- `SceneControllerSceneViewRuntime` must extend the
  `SceneControllerPointerSession` constructor seam with exactly one new
  controller callback:
  `void Function(PointerSessionToken token) detachPointerSession`.
- `SceneControllerPointerSession` may store its token only as an opaque
  constructor dependency and must not interpret token ownership locally beyond
  forwarding session-scoped runtime calls and invoking `detach()`.
- `SceneControllerPointerSession.detach()` must:
  mark the session detached, cancel pending timers/settings state, reset local
  pointer-tracker generation, and invoke controller-side
  `detachPointerSession(token)`.
- After `detach()` returns, later routed samples, invalid terminal forwarding,
  raw pointer release callbacks, and session-owned timer flushes must be local
  no-ops and must not call the controller again.

### 6.6 Prohibited

- adding any new `SceneViewPointerSession` method other than `detach()`
- exposing token-bearing APIs on `SceneViewPointerSession`
- adding callback-style controller-update APIs on `SceneViewPointerSession`
- letting host replacement or dispose call `dispose()` before `detach()`
- storing pointer tracker, pending settings, or gesture-owner state in
  `SceneViewInteractivePointerHost`

## 7. Execution Rules

1. Steps `92-94` remain the owners of routed-input, lifecycle-reason, and
   draw-owner semantics.
2. This step closes the explicit session detach contract before documentation
   and invariant closure work starts.
3. Low-level tests that create sessions directly must exercise the explicit
   `detach(); dispose();` sequence in the same change that introduces the
   contract.
4. Preparatory interface changes without green host-ordering regressions do not
   close the step.

## 8. Vertical Slices

### Slice 1. [ ] Pointer Session Detaches Before Replace And Dispose

#### Slice Contract

Replacing or disposing an opaque `SceneViewPointerSession` detaches the old
session before disposal and before host-side router reset, so the old
controller is not left with active gesture or pending-line ownership.

#### Change

Extend `lib/src/contract/scene_view_runtime.dart` so
`SceneViewPointerSession` defines exactly one new lifecycle method:

- `void detach();`

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

Refactor `SceneViewInteractivePointerHost` so replacement order is exact:

1. old session `detach()`
2. old session `dispose()`
3. router `reset()`
4. install the new session

Host disposal order is exact:

1. current session `detach()`
2. current session `dispose()`

Update the listed contract, architecture, coverage, and guardrail tests in the
same change so contract shape, host ordering, and sandbox mirrors all agree.

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

## 9. Final Verification

- MCP run of `test/view/scene_view_interactive_test.dart`
- MCP run of `test/contract/runtime_contract_interfaces_test.dart`
- MCP run of `test/interactive/core/scene_controller_interaction_contract_test.dart`
- MCP run of `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/coverage_tool_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- The slice is closed.
- Final verification has passed.
