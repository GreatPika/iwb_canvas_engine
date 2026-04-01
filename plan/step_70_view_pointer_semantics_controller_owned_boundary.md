language: russian

# Шаг 70. Вынести view-side pointer semantics в controller-owned boundary вне `interactive/internal`

## 1. Change Mandate

This change replaces the step-68 internal-access transport with a dedicated
controller-owned pointer-semantics boundary outside
`interactive/internal/**` so `view/**` reaches `interactive` only through
`SceneViewRenderState` and a separate narrow pointer/input seam.

## 2. Change Boundary

### Included in the Change

- `lib/src/interactive/scene_view_pointer_semantics.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `lib/src/interactive/internal/scene_controller_pointer_semantics.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `tool/src/import_boundaries/import_boundary_policy.dart`
- `tool/src/import_boundaries/directive_boundary_checker.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `tool/invariant_registry.dart`
- `plan/step_70_view_pointer_semantics_controller_owned_boundary.md`

### Not Included in the Change

- Extending `SceneViewRenderState` with pointer-semantics factory, lifecycle,
  or input responsibilities
- Any public package export change or public API widening for
  `SceneController`,
  `SceneView`,
  or package entrypoints
- Moving raw pointer admission, raw pointer id routing, slot reuse, or raw
  release ownership out of `view/**`
- Reopening the step-69 render read-side closure or reintroducing
  `view/** -> interactive/internal/**` imports for render-state access
- Replacing test/debug/inspection uses of
  `scene_controller_internal_access.dart` that are unrelated to the production
  pointer bridge path
- Any write-side mutation-pipeline refactor outside the pointer-semantics seam
- Any file outside the listed zones unless a targeted verification cannot close
  without it

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/scene_view_pointer_semantics.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `lib/src/interactive/internal/scene_controller_pointer_semantics.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `tool/src/import_boundaries/import_boundary_policy.dart`
- `tool/src/import_boundaries/directive_boundary_checker.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`

### Test Files

- `test/contract/runtime_contract_interfaces_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixture and Supporting Data Files

- `test/tool/support/guardrails_tool_test_support.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `tool/invariant_registry.dart`
- `plan/step_70_view_pointer_semantics_controller_owned_boundary.md`

### Analysis Area

- `lib/src/view/**`
- `lib/src/interactive/**`
- `tool/src/import_boundaries/**`
- `tool/src/guardrails/**`
- `test/view/**`
- `test/interactive/core/**`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/tool/import_boundaries/**`
- `test/tool/guardrails/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified production file must either introduce the new pointer seam,
  adopt it from controller/view code, remove the production bridge path from
  internal access, or enforce the hard `view/** -> interactive/internal/**`
  ban without pointer-specific exceptions.
- Every modified test file must pin one confirmed regression surface:
  controller-owned seam availability,
  view-shell import drift,
  behavior drift in double tap / pending flush / deferred settings adoption,
  or tooling regressions in the import-boundary and guardrail rules.
- Every modified documentation or invariant file must describe exactly the same
  two-contact view contract: render read-side through `SceneViewRenderState`
  and pointer/input semantics through the dedicated seam.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneViewRenderState` remains a read-side render contract only and must not
   absorb pointer-semantics factory, lifecycle, or input behavior.
2. The new pointer seam lives in
   `lib/src/interactive/scene_view_pointer_semantics.dart`, outside
   `interactive/internal/**`.
3. The seam consists of `SceneViewPointerSemanticsBridge` and
   `SceneViewPointerSemanticsSource`.
4. `SceneController` directly implements
   `SceneViewPointerSemanticsSource` and remains the owner of bridge creation
   for `SceneView`.
5. `SceneControllerPointerSemantics` remains the concrete pointer-semantics
   owner, but only interactive-local code may name or instantiate it.
6. `SceneViewInteractive` and
   `SceneViewInteractivePointerHost`
   must not import `interactive/internal/**`; they may depend only on the new
   seam plus the existing public/internal-safe interactive contracts.
7. `scene_controller_internal_access.dart` must not transport the production
   pointer bridge after this step; it remains only for test/debug/inspection
   hooks that still need explicit internal access.
8. Import-boundary tooling must not keep a pointer-specific exception for
   `view/**`; after this step any production
   `view/** -> interactive/internal/**` dependency is a violation.
9. Raw pointer admission, raw pointer slot routing, invalid finite filtering,
   raw release lifecycle, and mounted/controller listener ownership stay in
   `view/**`.
10. Existing behavior for text double tap, pending tap flush, invalid terminal
    forwarding, controller replacement without remount, and deferred
    `PointerInputSettings` adoption stays unchanged.

## 5. Result Requirements

1. `lib/src/view/scene_view_interactive.dart` and
   `lib/src/view/scene_view_interactive_pointer_host.dart`
   no longer import `interactive/internal/**`.
2. `lib/src/interactive/scene_view_pointer_semantics.dart` exists and exposes
   the view-facing bridge and source contracts outside `internal/**`.
3. `SceneController` implements
   `SceneViewPointerSemanticsSource` and view code acquires pointer semantics
   directly from the controller-owned seam instead of internal-access helpers.
4. The production pointer path no longer calls
   `sceneControllerInternalCreatePointerSemanticsBridge(...)` and no longer
   uses internal-access registration to move the bridge from controller to
   view.
5. `SceneControllerInternalAccessRegistration` no longer carries a
   pointer-bridge factory.
6. Import-boundary policy and checker contain no pointer-specific exception and
   reject any `view/** -> interactive/internal/**` import.
7. Guardrails, structural architecture tests, invariant registration, and
   `ARCHITECTURE.md` describe the same final shape: `SceneView` has only two
   allowed contacts with `interactive`, `SceneViewRenderState` and the new
   pointer seam.
8. Double tap routing, pending tap flush timing, invalid terminal forwarding,
   raw slot reuse, and deferred pointer-settings apply remain behaviorally
   equivalent to the current mainline.
9. The public package export surface remains unchanged.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/view/scene_view_interactive.dart` currently imports
  `scene_controller_internal_access.dart` and calls
  `sceneControllerInternalCreatePointerSemanticsBridge(...)` during `initState`.
- `lib/src/view/scene_view_interactive_pointer_host.dart` currently imports
  `scene_controller_internal_access.dart`, types its dependency as
  `SceneControllerPointerSemanticsBridge`, and recreates the bridge through
  `sceneControllerInternalCreatePointerSemanticsBridge(...)` on controller
  replacement.
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
  currently owns the bridge type, carries `createPointerSemanticsBridge` in
  the registration, and exposes the production helper
  `sceneControllerInternalCreatePointerSemanticsBridge(...)`.
- `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
  currently exposes `createPointerSemanticsBridge` as part of the assembled
  facade.
- `lib/src/interactive/internal/scene_controller_pointer_semantics.dart`
  remains the concrete owner of `PointerInputTracker`, pending tap scheduling,
  live/pending pointer-settings adoption, and double-tap dispatch.
- `tool/src/import_boundaries/import_boundary_policy.dart` currently whitelists
  `scene_view_interactive.dart` and
  `scene_view_interactive_pointer_host.dart`
  as pointer-boundary files and allows only
  `scene_controller_internal_access.dart` as their internal target.
- `tool/src/import_boundaries/directive_boundary_checker.dart` currently
  contains a dedicated pointer-semantics exception path in addition to the
  broader view/internal violation path.
- `tool/src/guardrails/interactive_api_guardrails.dart`,
  `test/interactive/core/scene_controller_architecture_boundary_test.dart`,
  and
  `test/tool/support/guardrails_tool_test_support.dart`
  currently pin the internal-access helper as part of the step-68 closure.
- Step 69 already closed the render read-side seam, so removing the
  pointer-specific exception here must leave one simple steady-state rule:
  `view/**` does not import `interactive/internal/**`.

### 6.2 Target Verification Units

- `rg -n "scene_controller_internal_access\\.dart" lib/src/view`
- `rg -n "sceneControllerInternalCreatePointerSemanticsBridge|createPointerSemanticsBridge" lib/src/interactive lib/src/view test tool`
- `rg -n "SceneViewPointerSemanticsBridge|SceneViewPointerSemanticsSource" lib/src/interactive lib/src/view test`
- `rg -n "isViewPointerSemanticsBoundaryFile|isAllowedViewPointerSemanticsInternalTarget|pointer-semantics boundary violation" tool/src/import_boundaries`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner: `test/contract/runtime_contract_interfaces_test.dart`
- MCP test runner: `test/view/scene_view_interactive_test.dart`
- MCP test runner: `test/view/scene_view_pointer_router_test.dart`
- MCP test runner: `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- MCP test runner: `test/interactive/core/scene_controller_interaction_contract_test.dart`

### 6.3 Protected States, Data, or Structures

- `SceneViewPointerRouter` raw-pointer ownership, minimum-free-slot reuse, and
  single active signal-tracking gate
- Existing invalid terminal forwarding into
  `controller.interaction.handlePointer(...)`
- Pending tap flush scheduling and deferred `PointerInputSettings` adoption
  until router idle
- Text double-tap edit request behavior and controller-change-without-remount
  behavior
- The committed step-69 render-state boundary owned by
  `SceneViewRenderState`

### 6.4 Allowed Semantic Change Zones

- The new view-facing pointer-semantics contract file under
  `lib/src/interactive/`
- Controller-owned bridge creation and view/host adoption of that contract
- Removal of production pointer-bridge transport from
  `scene_controller_internal_access.dart`
- Import-boundary, guardrail, invariant, and architecture enforcement for the
  hard `view/** -> interactive/internal/**` ban

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct `view/** -> interactive/internal/**` import
- helper-based bridge resolution through
  `sceneControllerInternalCreatePointerSemanticsBridge(...)`
- registration-based bridge transport through
  `SceneControllerInternalAccessRegistration`
- direct concrete-owner import from view to
  `scene_controller_pointer_semantics.dart`
- host-local reownership of `PointerInputTracker`,
  `_PendingTapFlushScheduler`,
  or pending pointer-settings state

### 6.6 Allowed Forms That Do Not Count as Violations

- `lib/src/interactive/internal/scene_controller_pointer_semantics.dart`
  continuing to own concrete pointer-semantics implementation details
- interactive-local files depending on the new seam file while keeping
  concrete pointer semantics in `interactive/internal/**`
- test/debug/inspection code continuing to use
  `scene_controller_internal_access.dart` for non-production hooks such as
  epoch, preview, or explicit white-box test access

### 6.8 Prohibited

- Extending `SceneViewRenderState` with pointer-semantics creation or lifecycle
  responsibilities
- Any new Expando, registration, or helper path whose only purpose is to move
  the production pointer seam from controller to view
- Leaving `createPointerSemanticsBridge` inside
  `SceneControllerInternalAccessRegistration`
- Keeping a pointer-specific import-boundary exception for view files
- Moving raw pointer routing ownership into `interactive/internal/**`
- Changing package exports to expose the new seam as a supported public API

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must
   be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Introduce the standalone pointer seam outside `internal/**`

#### Slice Contract

`SceneView`-facing pointer semantics are expressed through a dedicated
controller-owned seam in `lib/src/interactive/scene_view_pointer_semantics.dart`
instead of bridge types living in `scene_controller_internal_access.dart`.

#### Change

Create the new seam file, move the bridge interface out of
`scene_controller_internal_access.dart`, add
`SceneViewPointerSemanticsSource`, and make `SceneController` implement that
source while the concrete pointer owner stays in
`scene_controller_pointer_semantics.dart`.

#### Verification

- `rg -n "abstract interface class SceneViewPointerSemanticsBridge|abstract interface class SceneViewPointerSemanticsSource" lib/src/interactive/scene_view_pointer_semantics.dart`
- `rg -n "implements SceneViewRenderState, SceneViewPointerSemanticsSource|createPointerSemanticsBridge" lib/src/interactive/scene_controller.dart`
- MCP test runner: `test/contract/runtime_contract_interfaces_test.dart`

#### Positive Scenarios

- `SceneController` exposes the new seam directly without widening the package
  export surface.
- `SceneViewRenderState` remains a render read-side contract only.

#### Negative Scenarios

- The bridge type no longer lives in
  `scene_controller_internal_access.dart`.
- No view-facing contract type for pointer semantics is introduced under
  `interactive/internal/**`.

#### Closure Evidence

- green run of the listed verifications
- source proof that the bridge/source contracts live in
  `scene_view_pointer_semantics.dart`
- source proof that `SceneController` implements the new source contract

### Slice 2. [x] Adopt the new seam at the view boundary

#### Slice Contract

`SceneViewInteractive` and `SceneViewInteractivePointerHost` consume pointer
semantics only through the controller-owned seam and retain only raw routing
plus lifecycle responsibilities.

#### Change

Switch `scene_view_interactive.dart` and
`scene_view_interactive_pointer_host.dart` to the new seam, remove their
imports of `scene_controller_internal_access.dart`, and make controller
replacement recreate pointer semantics through the controller-owned source
contract instead of the internal-access helper.

#### Verification

- `rg -n "scene_controller_internal_access\\.dart" lib/src/view`
- `rg -n "SceneViewPointerSemanticsBridge|createPointerSemanticsBridge\\(" lib/src/view/scene_view_interactive.dart lib/src/view/scene_view_interactive_pointer_host.dart`
- MCP test runner: `test/view/scene_view_interactive_test.dart`
- MCP test runner: `test/view/scene_view_pointer_router_test.dart`

#### Positive Scenarios

- Controller replacement without remount preserves the existing pointer
  lifecycle contract.
- View-local raw routing, slot reuse, and invalid finite filtering remain
  owned by `SceneViewInteractivePointerHost`.
- Double tap routing and deferred pointer-settings adoption remain green in the
  existing widget tests.

#### Negative Scenarios

- `SceneViewInteractivePointerHost` must not reintroduce
  `PointerInputTracker`,
  `_PendingTapFlushScheduler`,
  or pending pointer-settings ownership.
- No view file in the closed seam may import `interactive/internal/**`.

#### Closure Evidence

- green run of the listed verifications
- `rg` output shows no `scene_controller_internal_access.dart` import under
  `lib/src/view/**`
- widget and router tests stay green while the host remains a raw shell

### Slice 3. [x] Remove the production pointer bridge path from internal access

#### Slice Contract

`scene_controller_internal_access.dart` no longer transports pointer bridge
creation for production code; the remaining internal-access surface is limited
to explicit test/debug/inspection hooks.

#### Change

Delete the pointer-bridge factory field and helper from
`SceneControllerInternalAccessRegistration` and the Expando-backed access
surface, and align the remaining controller/facade code so the production
pointer path no longer depends on internal access.

#### Verification

- `rg -n "sceneControllerInternalCreatePointerSemanticsBridge|createPointerSemanticsBridge" lib/src/interactive lib/src/view`
- MCP test runner: `test/interactive/core/scene_controller_interaction_contract_test.dart`
- MCP test runner: `test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- Internal access still exposes the committed epoch/preview/test hooks that are
  outside this step.
- `SceneController` remains the single owner of the production pointer seam.

#### Negative Scenarios

- The production tree no longer reaches pointer semantics through Expando
  registration.
- Internal access does not keep a dead bridge-factory field or helper as a
  residual seam.

#### Closure Evidence

- green run of the listed verifications
- source proof that pointer bridge creation is absent from
  `scene_controller_internal_access.dart`
- structural tests prove that the production pointer path no longer routes
  through internal access

### Slice 4. [x] Remove the view/internal exception and pin the final boundary

#### Slice Contract

Tooling, structural tests, invariants, and architecture docs enforce a simple
steady-state rule: `view/**` does not import `interactive/internal/**`, and
pointer semantics reach view only through the new seam.

#### Change

Delete the pointer-specific exception from the import-boundary policy and
checker, update the guardrails and their test support to pin the new seam,
refresh invariant wording, and update `ARCHITECTURE.md`, `PLAN.md`, and this
step contract to describe the final two-contact view boundary.

#### Verification

- `rg -n "isViewPointerSemanticsBoundaryFile|isAllowedViewPointerSemanticsInternalTarget|pointer-semantics boundary violation" tool/src/import_boundaries`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner: `test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- Import-boundary tooling rejects every `view/** -> interactive/internal/**`
  dependency without carve-outs for pointer files.
- Guardrails and architecture tests describe the same controller-owned
  render-state seam plus controller-owned pointer seam.

#### Negative Scenarios

- Tooling must fail if the old pointer-specific exception returns.
- Guardrails must fail if view reintroduces internal-access bridge creation or
  concrete pointer-semantics ownership.

#### Closure Evidence

- green run of the listed verifications
- source proof that import-boundary policy has no pointer-specific carve-out
- docs, invariants, and structural checks describe the same final boundary

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/view lib/src/interactive tool/src/import_boundaries tool/src/guardrails --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `core`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `controller_internal`
- MCP test runner shard preset: `controller`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`
- MCP test runner shard preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
- `SceneView` reaches `interactive` only through
  `SceneViewRenderState` and the dedicated controller-owned pointer seam.
