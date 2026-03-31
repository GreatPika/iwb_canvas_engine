language: russian

# Шаг 66. Замкнуть active-gesture exclusivity для всех public scene/selection mutations

## 1. Change Mandate

This change fixes the remaining public active-gesture ownership bypasses so
every external mutating `controller.selection.*` and `controller.scene.*`
entrypoint is governed by one runtime-owned policy instead of a partial
selection-only guard set.

## 2. Change Boundary

### Included in the Change

- `lib/src/interactive/scene_controller_selection.dart`
- `lib/src/interactive/scene_controller_scene.dart`
- `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_selection_mutations.dart`
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/invariant_registry.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_66_active_gesture_public_mutation_exclusivity.md`

### Not Included in the Change

- `lib/src/contract/scene_write_txn.dart`
- `lib/src/controller/**`
- Any transaction-level allowlist or capability split inside `SceneWriteTxn`
- Any change to move/draw gesture-machine ownership beneath the existing
  runtime graph
- Any new public API surface or capability root
- Any file outside the listed zones unless a targeted verification cannot close
  without it

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_controller_selection.dart`
- `lib/src/interactive/scene_controller_scene.dart`
- `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_selection_mutations.dart`
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `PLAN.md`

### Test Files

- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixture and Supporting Data Files

- `test/tool/support/guardrails_tool_test_support.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `plan/step_66_active_gesture_public_mutation_exclusivity.md`

### Analysis Area

- `lib/src/interactive/scene_controller_selection.dart`
- `lib/src/interactive/scene_controller_scene.dart`
- `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_selection_mutations.dart`
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/invariant_registry.dart`
- `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- `test/interactive/core/scene_controller_interactive_basics_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either introduce the single
  runtime-owned external mutation policy, wire a listed public mutation
  entrypoint into that policy, or preserve the already documented
  reset-before-mutate semantics for `setCameraOffset(...)` and
  `replaceScene(...)`.
- Every modified test file must pin one of the confirmed bypass classes:
  direct deny-path regression,
  reset-before-mutate preservation,
  widget-level `scene.write(...)` conflict,
  or structural guardrail enforcement.
- Every modified documentation or invariant file must publish the exact public
  contract introduced by this step and must not add speculative future policy.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. One canonical active-gesture external mutation policy owner is introduced in
   `SceneControllerInteractionRuntime`.
2. Public capability files remain thin public facades; the active-gesture
   mutation policy is enforced in
   `scene_controller_selection_mutations.dart`
   and
   `scene_controller_scene_mutations.dart`,
   not through ad hoc guards scattered across facade and runtime call sites.
3. The runtime-owned policy exposes exactly two mutation behaviors for this
   step:
   `ensureExternalMutationAllowed(...)` for deny semantics and
   `resetActiveGestureForExternalMutation(...)` for reset-before-mutate
   semantics.
4. `setCameraOffset(...)` and `replaceScene(...)` remain the only public
   scene mutations that may force-release an active gesture in this step.
5. Validation and no-op preflight for `setCameraOffset(...)` and
   `replaceScene(...)` remain before any active-gesture reset, so invalid input
   or no-op boundary writes preserve the active gesture exactly as they do now.
6. `SceneControllerScene.write(...)` is treated as an opaque broad mutation
   entrypoint and is denied during an active gesture; this step must not add a
   transaction-level allowlist or partial `SceneWriteTxn` capability filter.
7. `notifySceneChanged()` remains outside active-gesture mutation exclusivity
   because it does not mutate committed controller state.
8. `setBackgroundColor(...)`,
   `setGridEnabled(...)`,
   `setGridCellSize(...)`,
   `addNode(...)`,
   `ensureLayer(...)`,
   `patchNode(...)`,
   `removeNode(...)`,
   `clearScene(...)`,
   `setSelection(...)`,
   `toggleSelection(...)`,
   `clearSelection(...)`,
   `selectAll(...)`,
   `rotateSelection(...)`,
   `flipSelectionVertical(...)`,
   `flipSelectionHorizontal(...)`,
   and
   `deleteSelection(...)`
   use deny semantics during an active gesture.
9. A new invariant id
   `INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY`
   is added and used as the canonical proof hook for this contract.
10. A widget-level regression proving that `scene.write(...)` cannot bypass an
    active gesture is mandatory in this step.

## 5. Result Requirements

1. One runtime-owned active-gesture mutation policy governs all mutating public
   `controller.selection.*` and `controller.scene.*` entrypoints listed in
   Locked Decision 8, plus `setCameraOffset(...)` and `replaceScene(...)`.
2. During an active move or draw gesture, every deny-listed public mutation
   throws `StateError` before it mutates committed scene, selection, camera,
   layer structure, or document state.
3. `setCameraOffset(...)` and `replaceScene(...)` continue to reset the active
   gesture only when their boundary mutation will proceed after existing
   validation/no-op preflight.
4. After terminal `up` or `cancel`, the deny-listed public mutations become
   available again.
5. `scene.write(...)` can no longer bypass active-gesture exclusivity through
   direct controller calls or through a widget-routed integration scenario.
6. Tool guardrails fail when a listed public mutation path omits the required
   runtime policy call, uses the wrong policy family, or hides the policy
   behind a local helper or intermediate call.
7. `README.md`,
   `API_GUIDE.md`,
   `ARCHITECTURE.md`,
   `CHANGELOG.md`,
   and
   `tool/invariant_registry.dart`
   publish the exact contract of this step.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `SceneControllerSelection` currently applies active-gesture exclusivity only
  to `setSelection(...)`,
  `toggleSelection(...)`,
  `clearSelection()`,
  and
  `selectAll(...)`
  through `ensureExternalSelectionMutationAllowed(...)`.
- `rotateSelection(...)`,
  `flipSelectionVertical(...)`,
  `flipSelectionHorizontal(...)`,
  and
  `deleteSelection(...)`
  currently bypass that exclusivity path.
- `SceneControllerScene` currently exposes `write(...)`,
  `setBackgroundColor(...)`,
  `setGridEnabled(...)`,
  `setGridCellSize(...)`,
  `setCameraOffset(...)`,
  `addNode(...)`,
  `ensureLayer(...)`,
  `patchNode(...)`,
  `removeNode(...)`,
  `clearScene(...)`,
  `replaceScene(...)`,
  and
  `notifySceneChanged()`
  under resolver-purity guarding only.
- `SceneControllerSceneMutations.setCameraOffset(...)` and
  `SceneControllerSceneMutations.replaceScene(...)` already preserve the
  documented contract that active gesture reset happens only after mutation
  preflight proves the boundary transition will proceed.
- `SceneWriteTxn` currently exposes selection, transform, camera, and document
  replacement operations, so transaction-level partial allowlisting is outside
  the safe scope of this step.
- Current public docs already publish two behaviors that must remain aligned:
  selection-only gesture exclusivity for four methods, and reset-before-mutate
  semantics for `setCameraOffset(...)` and `replaceScene(...)`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/interactive/scene_controller_selection.dart lib/src/interactive/scene_controller_scene.dart lib/src/interactive/internal/scene_controller_facade_assembly.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/scene_controller_selection_mutations.dart lib/src/interactive/internal/scene_controller_scene_mutations.dart tool/src/guardrails/interactive_api_guardrails.dart --report-all`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_interactive_basics_test.dart`
- MCP test runner: root `.` paths `test/view/scene_view_interactive_test.dart`

### 6.3 Protected States, Data, or Structures

- Active move marquee state, move preview state, and draw preview buffers owned
  under `InteractiveRuntime`.
- Existing terminal recovery semantics after `up` and `cancel`.
- Existing no-op and validation preservation for `setCameraOffset(...)` and
  `replaceScene(...)`.
- Existing asynchronous `actions` / `editTextRequests` delivery contract.
- The public capability split
  `controller.interaction`,
  `controller.selection`,
  and
  `controller.scene`
  introduced earlier in the plan.

### 6.4 Allowed Semantic Change Zones

- Runtime-owned active-gesture external mutation policy entrypoints.
- Scene and selection mutation-owner methods that decide whether a public
  mutation is denied or may reset the active gesture.
- Thin public facade delegation required to keep capability files aligned with
  the mutation-owner graph.
- Structural guardrail rules and their negative/positive regression fixtures.
- Interactive core and view regressions that prove the deny/reset matrix.
- Public documentation and invariant publication for the new contract.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct bypass of active-gesture exclusivity from a public scene mutation
  entrypoint;
- direct bypass of active-gesture exclusivity from a public selection
  transform/delete entrypoint;
- local-helper bypass where a mutation-owner method delegates before the
  required runtime policy call;
- intermediate-call bypass where `scene.write(...)` reaches the broad
  transactional surface during an active gesture;
- wrong-policy bypass where a deny-listed method uses reset-before-mutate
  semantics or a reset-listed method uses deny semantics.

### 6.6 Allowed Forms That Do Not Count as Violations

- `setCameraOffset(...)` and `replaceScene(...)` performing validation/no-op
  preflight before calling `resetActiveGestureForExternalMutation(...)`.
- `notifySceneChanged()` remaining guarded only by public-side-effect rules.
- Internal gesture-owned writes that do not enter through
  `controller.selection.*` or `controller.scene.*`.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `SceneControllerSelection` and `SceneControllerScene` remain the public
  capability owners and keep `ensurePublicSideEffectAllowed(...)` as the first
  executable statement of each mutating public method.
- `SceneControllerSelectionMutations` and `SceneControllerSceneMutations`
  become the structural owners of active-gesture mutation policy for the public
  capability methods in this step.
- Guardrail resolution stays file-local and method-name-based; aliasing a
  mutation owner, moving the required runtime policy call into a helper, or
  satisfying the contract through an intermediate wrapper does not count as a
  valid guarded form.
- The required policy mapping is exact:
  `setSelection`,
  `toggleSelection`,
  `clearSelection`,
  `selectAll`,
  `rotateSelection`,
  `flipSelectionVertical`,
  `flipSelectionHorizontal`,
  `deleteSelection`,
  `write`,
  `setBackgroundColor`,
  `setGridEnabled`,
  `setGridCellSize`,
  `addNode`,
  `ensureLayer`,
  `patchNode`,
  `removeNode`,
  and
  `clearScene`
  must call `ensureExternalMutationAllowed(...)` before the first stateful
  write or emitted side effect.
- `setCameraOffset(...)` and `replaceScene(...)` must call
  `resetActiveGestureForExternalMutation(...)` only after their existing
  mutation preflight determines that the boundary transition will proceed.
- `notifySceneChanged()` must not be added to the active-gesture exclusivity
  guard set in this step.

### 6.8 Prohibited

- Keeping or reintroducing selection-only exclusivity as a partial special
  case.
- Duplicating active-gesture mutation policy through inline
  `runtime.hasActiveGesture` checks outside the runtime-owned policy methods.
- Adding a transaction-level allowlist, filter, or partial capability split to
  `SceneWriteTxn` in this step.
- Broadening reset-before-mutate semantics beyond `setCameraOffset(...)` and
  `replaceScene(...)`.
- Silently dropping, queuing, deferring, or replaying denied public mutations.
- Weakening existing no-op/validation preservation tests for
  `setCameraOffset(...)` or `replaceScene(...)` to accommodate an earlier
  forced reset.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes capability or mutation-owner guard structure, the same
   slice must update `interactive_api_guardrails.dart` proofs or explicitly
   defer that work to the next still-open slice.
7. If a slice changes the public active-gesture mutation contract, the same
   slice must add or update runtime proofs marked with
   `// INV:INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY`.
8. Scope expansion into `controller/`,
   `contract/scene_write_txn.dart`,
   or new public API is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] Introduce one runtime-owned public mutation policy

#### Slice Contract

All mutating `controller.selection.*` and `controller.scene.*` entrypoints use
one runtime-owned deny/reset policy with the exact method mapping fixed in this
step, while `setCameraOffset(...)` and `replaceScene(...)` preserve their
existing preflight-before-reset behavior.

#### Change

Add `ensureExternalMutationAllowed(...)` and
`resetActiveGestureForExternalMutation(...)` to
`SceneControllerInteractionRuntime`, wire
`SceneControllerSelectionMutations` and `SceneControllerSceneMutations` to use
that policy, adjust facade assembly and thin capability owners accordingly, and
extend interactive-core tests to cover the full deny matrix plus the preserved
reset/no-op paths.

#### Verification

- `dcm calculate-metrics lib/src/interactive/scene_controller_selection.dart lib/src/interactive/scene_controller_scene.dart lib/src/interactive/internal/scene_controller_facade_assembly.dart lib/src/interactive/internal/scene_controller_interaction_runtime.dart lib/src/interactive/internal/scene_controller_selection_mutations.dart lib/src/interactive/internal/scene_controller_scene_mutations.dart --report-all`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_interactive_single_pointer_policy_test.dart`
- MCP test runner: root `.` paths `test/interactive/core/scene_controller_interactive_basics_test.dart`

#### Positive Scenarios

- During an active move gesture and during an active draw gesture,
  every deny-listed public mutation throws `StateError`.
- After terminal `up` or `cancel`, the same deny-listed public mutations are
  available again.
- `setCameraOffset(...)` and `replaceScene(...)` still force-release the active
  gesture only when the boundary mutation will actually proceed.

#### Negative Scenarios

- `setCameraOffset(...)` no-op keeps the active move/draw gesture intact.
- `replaceScene(...)` validation failure keeps the active move/draw gesture
  intact.
- `scene.write(...)` does not remain as a bypass for selection, transform,
  camera, or document writes during an active gesture.

#### Closure Evidence

- Green run of the listed interactive-core verifications.
- Updated interactive proofs marked with
  `// INV:INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY`.

### Slice 2. [ ] Pin structural enforcement, widget proof, and published contract

#### Slice Contract

The new active-gesture mutation policy is structurally enforced by guardrails,
proved at widget level for `scene.write(...)`, and published as a stable
repository contract through invariants and release-ready docs.

#### Change

Extend `interactive_api_guardrails.dart` and its fixtures/tests so mutation
owners must use the exact runtime policy mapping from this step, add a
widget-level `scene.write(...)` conflict regression in
`scene_view_interactive_test.dart`, register
`INV-ENG-INTERACTIVE-PUBLIC-MUTATION-EXCLUSIVITY`, and update
`README.md`,
`API_GUIDE.md`,
`ARCHITECTURE.md`,
`CHANGELOG.md`,
`PLAN.md`,
and
this step file to publish the closed contract.

#### Verification

- `dcm calculate-metrics tool/src/guardrails/interactive_api_guardrails.dart --report-all`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: root `.` paths `test/view/scene_view_interactive_test.dart`

#### Positive Scenarios

- Guardrail fixtures that use the exact required runtime policy calls pass.
- A widget-routed active gesture blocks `scene.write(...)` the same way as a
  direct controller call.
- Invariant coverage remains green with the new invariant id and proof path.

#### Negative Scenarios

- A deny-listed mutation owner method without `ensureExternalMutationAllowed(...)`
  fails the guardrail tool.
- `setCameraOffset(...)` or `replaceScene(...)` using the wrong policy family
  fails the guardrail tool.
- A local-helper or intermediate-call bypass that hides the required runtime
  policy call from the owning method fails the guardrail tool.

#### Closure Evidence

- Green run of the listed tool, invariant, and view verifications.
- Updated public docs and changelog describe the exact deny/reset contract of
  this step and do not leave the old partial-selection wording behind.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner preset: `core`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `controller_internal`
- MCP test runner preset: `controller`
- MCP test runner preset: `render_view`
- MCP test runner preset: `interactive`
- MCP test runner preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
