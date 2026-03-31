language: russian

# Шаг 68. Замкнуть view-boundary pointer semantics через assembled internal bridge

## 1. Change Mandate

This change closes the remaining local view-to-interactive/internal
pointer-semantics seam around
`scene_view_interactive.dart`
and
`scene_view_interactive_pointer_host.dart`
by moving concrete pointer-semantics assembly behind a narrow
controller-private bridge while keeping `SceneView` as a raw-routing and
lifecycle shell.

## 2. Change Boundary

### Included in the Change

- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `lib/src/interactive/internal/scene_controller_pointer_semantics.dart`
- `tool/check_import_boundaries.dart`
- `tool/src/import_boundaries/import_boundary_policy.dart`
- `tool/invariant_registry.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_68_pointer_semantics_view_boundary_closure.md`

### Not Included in the Change

- Any public API change to `SceneController`, `SceneControllerInteraction`,
  `SceneViewInteractive`, or package entrypoints
- Moving raw pointer routing, raw pointer id assignment, or slot reuse out of
  `view/**`
- Changing double-tap recognition semantics, pending-flush timing semantics, or
  live `PointerInputSettings` behavior beyond preserving the existing contract
- A repo-wide ban on every `view/** -> interactive/internal/**` import; the
  enforced closure target in this step is the local pointer-semantics seam
  around
  `scene_view_interactive.dart`
  and
  `scene_view_interactive_pointer_host.dart`
- `lib/src/view/scene_view_render_surface.dart`
- The remaining read-side/render-state seam where
  `scene_view_render_surface.dart`
  depends on `interactive/internal/**`; that broader architectural debt stays
  open after this step and must not be treated as resolved by the local
  pointer-semantics guardrail
- Any scene/model/controller mutation-pipeline refactor outside the listed seam
- Any file outside the listed zones unless a targeted verification cannot close
  without it

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `lib/src/interactive/internal/scene_controller_pointer_semantics.dart`
- `tool/src/import_boundaries/import_boundary_policy.dart`

### Test Files

- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`

### Fixture and Supporting Data Files

- `tool/check_import_boundaries.dart`
- `tool/invariant_registry.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_68_pointer_semantics_view_boundary_closure.md`

### Analysis Area

- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/**`
- `tool/src/import_boundaries/**`
- `test/view/**`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/import_boundaries/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either remove direct view knowledge
  of a concrete pointer-semantics owner, provide controller-private bridge
  assembly, or preserve raw routing and lifecycle ownership in `view/**`.
- Every modified test file must pin one of the confirmed seam regressions:
  direct import leakage,
  concrete-owner construction in view,
  host-local tracker/timer/settings ownership,
  or behavior drift in pointer routing and controller replacement.
- Every modified tooling, invariant, or architecture file must mechanically
  enforce or publish the exact local view-seam pointer-semantics boundary
  closed by this step.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneViewInteractivePointerHost` must not import or instantiate
   `SceneControllerPointerSemantics` or any replacement concrete
   pointer-semantics owner from `interactive/internal/**`.
2. `view/**` keeps ownership only of raw pointer admission, raw pointer id
   routing, raw pointer release, mounted/controller lifecycle, and controller
   listener wiring for this seam.
3. Tap/double-tap recognition, pending tap flush scheduling, deferred
   `PointerInputSettings` adoption, and idle-transition rules remain owned by
   one dedicated pointer-semantics implementation hidden behind a narrow
   internal bridge abstraction.
4. The concrete pointer-semantics bridge is created by controller- or
   interactive-private assembly; view receives an already assembled dependency
   and must not decide which implementation class to construct.
5. This step must not widen the public API of `SceneController`,
   `SceneControllerInteraction`,
   `SceneViewInteractive`,
   or package entrypoints.
6. Automated regression protection is mandatory and must cover the full local
   structural seam around
   `scene_view_interactive.dart`
   and
   `scene_view_interactive_pointer_host.dart`,
   plus the import boundary that blocks the old direct dependency from
   returning.
7. A repo-wide ban on all `view/** -> interactive/internal/**` imports is not
   part of this step; closure is defined by eliminating the concrete
   pointer-semantics seam from the local view boundary around
   `scene_view_interactive.dart`
   and
   `scene_view_interactive_pointer_host.dart`.
8. The existing
   `scene_view_render_surface.dart -> scene_controller_internal_access.dart`
   dependency remains a separate read-side/render-state seam and is not
   legitimized, normalized, or closed by this step.
9. Neither
   `scene_view_interactive.dart`
   nor
   `scene_view_interactive_pointer_host.dart`
   may import or instantiate a concrete pointer-semantics owner or a concrete
   bridge implementation from `interactive/internal/**`; the closed seam in
   `view/**` receives only an already assembled narrow dependency.

## 5. Result Requirements

1. `lib/src/view/scene_view_interactive_pointer_host.dart` no longer imports a
   pointer-semantics implementation from `lib/src/interactive/internal/**` and
   does not name a concrete pointer-semantics owner type.
2. `SceneViewInteractivePointerHost` and `SceneViewInteractive` own only raw
   routing and lifecycle responsibilities for pointer handling and delegate
   pointer semantics through an abstract internal dependency.
3. One controller- or interactive-private assembly path creates and wires the
   pointer-semantics bridge for a `SceneController` instance before view-local
   pointer handling uses it.
4. Existing observable behavior remains equivalent for text double-tap edit
   routing, deferred `PointerInputSettings` apply after idle, invalid terminal
   forwarding, raw slot reuse/min-free-slot routing, and controller change
   without remount.
5. Import-boundary and structural tests fail if view reintroduces direct
   pointer-semantics imports, concrete owner construction, `PointerInputTracker`,
   or pending-flush scheduler ownership.
6. `ARCHITECTURE.md`, `PLAN.md`, and `tool/invariant_registry.dart` describe
   and prove the same view/private pointer-semantics boundary.
7. No touched `lib/src/view/**` file in the closed seam chooses the
   implementation class, factory path, or assembly path for the
   pointer-semantics bridge.
8. Closure proof for this step covers the full local view seam around
   `scene_view_interactive.dart`
   and
   `scene_view_interactive_pointer_host.dart`,
   not only the host file in isolation.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `scene_view_interactive_pointer_host.dart` currently imports
  `scene_controller_pointer_semantics.dart`, creates a
  `_SceneViewInteractivePointerRuntime`, and that runtime creates the concrete
  `SceneControllerPointerSemantics` owner.
- `scene_view_interactive.dart` currently creates
  `SceneViewInteractivePointerHost` directly from the widget state and passes
  only `controller`, `isMounted`, and `onControllerChanged`.
- `scene_controller_pointer_semantics.dart` currently owns
  `PointerInputTracker`, pending tap timer scheduling, applied/pending pointer
  settings state, invalid terminal forwarding cleanup, and double-tap signal
  dispatch.
- `scene_controller_facade_assembly.dart` currently assembles interaction,
  selection, and scene facades, but it does not yet assemble a view-facing
  pointer-semantics bridge.
- `scene_controller.dart` already registers controller-private internal access,
  and `scene_controller_internal_access.dart` already exposes controller-owned
  internal hooks that can carry private dependencies without widening the
  public API.
- `scene_view_render_surface.dart` already imports
  `scene_controller_internal_access.dart`, so a repo-wide `view/** ->
  interactive/internal/**` prohibition is broader than this step and is not the
  closure target here; that remaining seam stays open architectural debt rather
  than an accepted steady-state rule.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/view/scene_view_interactive.dart lib/src/view/scene_view_interactive_pointer_host.dart lib/src/interactive/scene_controller.dart lib/src/interactive/internal/scene_controller_facade_assembly.dart lib/src/interactive/internal/scene_controller_internal_access.dart lib/src/interactive/internal/scene_controller_pointer_semantics.dart tool/src/import_boundaries/import_boundary_policy.dart --report-all`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner shard preset: `interactive`
- MCP test runner shard preset: `render_view`

### 6.3 Protected States, Data, or Structures

- `SceneViewPointerRouter` raw slot allocation, min-free-slot reuse, and active
  pointer signal-tracking gate
- Existing invalid terminal forwarding into `controller.interaction.handlePointer(...)`
- Pending tap flush timing and deferred `PointerInputSettings` adoption until
  router idle
- Text double-tap edit request behavior and controller-change-without-remount
  behavior
- The existing public capability surface for `SceneController` and
  `SceneViewInteractive`

### 6.4 Allowed Semantic Change Zones

- A narrow internal bridge abstraction between view raw routing and
  pointer-semantics ownership
- Controller-private assembly or registration that creates and wires the bridge
- View-host constructor/runtime simplification to raw routing and lifecycle
  responsibilities only
- Import-boundary, structural tests, invariant registration, and architecture
  documentation for this seam

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct import from `scene_view_interactive_pointer_host.dart` to
  `scene_controller_pointer_semantics.dart` or another concrete
  pointer-semantics owner under `interactive/internal/**`;
- direct or alias-based construction of a concrete pointer-semantics owner in
  `view/**`;
- host-local ownership in `view/**` of `PointerInputTracker`,
  `_PendingTapFlushScheduler`,
  applied/pending `PointerInputSettings`,
  or pending tap timestamp state;
- helper-based or local-runtime bypass that recreates pointer semantics
  lifecycle in view instead of delegating through the bridge.

### 6.6 Allowed Forms That Do Not Count as Violations

- `view/**` imports of public `interactive/scene_controller.dart`
- controller-private bridge wiring under `interactive/internal/**` that does
  not widen the public API
- existing raw router ownership in `SceneViewPointerRouter`, including
  stray-event dropping, terminal release, and min-free-slot reuse
- a concrete pointer-semantics implementation remaining in
  `lib/src/interactive/internal/**` as long as view sees only the bridge
  abstraction

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Structural enforcement must reject both direct and aliased view-side imports
  or constructions of a concrete pointer-semantics owner; a rename-only wrapper
  does not satisfy this step if view still knows the concrete owner.
- Import-boundary enforcement for closure must at minimum reject the
  pointer-semantics seam where
  `scene_view_interactive.dart`
  or
  `scene_view_interactive_pointer_host.dart`
  links to `interactive/internal/**` for pointer-semantics ownership.
- The step-local import guardrail is not a general allowlist for
  `view/** -> interactive/internal/**`; it protects only the
  pointer-semantics seam and does not change the target architecture for the
  remaining read-side/render-state seam.
- If the bridge is exposed through controller-private access rather than a new
  public constructor contract, the access path must remain assembled from
  controller-owned registration code and must not be chosen by view-local
  factory logic.

### 6.8 Prohibited

- Closing the step by keeping pointer semantics in a separate class while
  `view/**` still imports and instantiates that class directly
- Reintroducing `PointerInputTracker`, pending tap scheduler state, or
  applied/pending pointer settings ownership into `view/**`
- Moving raw slot routing or raw pointer id assignment out of `view/**` as part
  of this step
- Widening public API or adding sync glue between two mutable pointer-semantics
  owners
- Broad layer-DAG rewrites unrelated to the confirmed pointer-semantics seam

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

### Slice 1. [x] Assembled Pointer-Semantics Bridge

#### Slice Contract

The local view seam around
`scene_view_interactive.dart`
and
`scene_view_interactive_pointer_host.dart`
no longer owns concrete pointer-semantics assembly; it delegates pointer
semantics through one assembled internal bridge while retaining only raw
routing and lifecycle responsibilities.

#### Change

Introduce a narrow internal bridge abstraction for pointer semantics, assemble
and wire its concrete owner from controller-private code, and rework
`SceneViewInteractive` plus `SceneViewInteractivePointerHost` to consume that
assembled dependency instead of constructing
`SceneControllerPointerSemantics` directly.

#### Verification

- `dcm calculate-metrics lib/src/view/scene_view_interactive.dart lib/src/view/scene_view_interactive_pointer_host.dart lib/src/interactive/scene_controller.dart lib/src/interactive/internal/scene_controller_facade_assembly.dart lib/src/interactive/internal/scene_controller_internal_access.dart lib/src/interactive/internal/scene_controller_pointer_semantics.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- MCP test runner shard preset: `interactive`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios

- Text double tap routed through view still emits the existing edit-text
  request behavior.
- Pointer settings updates on the same controller still apply only after idle
  and keep last-write-wins behavior.
- Controller replacement without remount still preserves the existing pointer
  lifecycle contract.

#### Negative Scenarios

- Invalid terminal forwarding still reaches controller pointer handling exactly
  once.
- Raw slot reuse and the single active signal-tracking gate remain unchanged.
- `scene_view_interactive_pointer_host.dart` no longer names
  `SceneControllerPointerSemantics`,
  `PointerInputTracker`,
  or `_PendingTapFlushScheduler`.
- Guardrails fail if a concrete pointer-semantics owner or bridge
  implementation returns either to
  `scene_view_interactive_pointer_host.dart`
  or to
  `scene_view_interactive.dart`.

#### Closure Evidence

- green run of the listed verifications;
- source proof that concrete pointer-semantics assembly happens outside
  `view/**`;
- source proof that `SceneViewInteractivePointerHost` is reduced to raw routing
  and lifecycle responsibilities.
- source proof that no `view/**` file in the closed seam decides bridge
  construction or imports a concrete pointer-semantics implementation.

### Slice 2. [x] Pointer-Seam Guardrails And Boundary Proof

#### Slice Contract

Automated checks fail when the old direct view-to-internal pointer-semantics
seam or host-local pointer-semantics state returns.

#### Change

Extend import-boundary tooling, structural architecture tests, invariant
registry, and architecture documentation so the pointer-semantics seam cannot
silently regress back to a direct view-owned concrete dependency.

#### Verification

- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner shard preset: `interactive`

#### Positive Scenarios

- The allowed view dependency on public `interactive/scene_controller.dart`
  remains valid.
- Structural architecture tests prove that pointer semantics stay outside
  `SceneViewInteractivePointerHost`.
- The step-local guardrail remains scoped to the pointer-semantics seam and
  does not claim that the broader `view/** -> interactive/internal/**`
  architectural debt is closed.

#### Negative Scenarios

- The import-boundary tool rejects a direct
  `scene_view_interactive.dart -> interactive/internal/**`
  or
  `scene_view_interactive_pointer_host.dart -> interactive/internal/**`
  pointer-semantics dependency.
- The structural test rejects reintroduction of
  `PointerInputTracker`,
  `_PendingTapFlushScheduler`,
  or a concrete pointer-semantics owner in
  `scene_view_interactive_pointer_host.dart`
  or
  `scene_view_interactive.dart`.

#### Closure Evidence

- green run of the listed verifications;
- invariant registry and architecture documentation describe the same boundary
  as the structural and tooling checks.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
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
- The pointer-semantics seam is closed without widening public API or moving raw
  routing out of `view/**`.
