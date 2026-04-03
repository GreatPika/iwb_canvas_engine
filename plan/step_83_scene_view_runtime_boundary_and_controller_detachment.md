language: russian

# Шаг 83. Ввести assembled `SceneView` runtime boundary и отвязать view core от concrete controller

## 1. Change Mandate

This change introduces one assembled internal `SceneViewRuntime` boundary so
the view core consumes only runtime/read-side contracts, `SceneController`
stops directly owning view render/pointer/internal-access roles, and the
pointer host becomes a raw routing shell over an opaque session owner.

## 2. Change Boundary

### Included in the Change

- `lib/src/contract/scene_view_runtime.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_runtime_owner.dart`
- `lib/src/view/scene_view_render_surface.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/view/scene_view_interactive_overlay_painter.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_owners.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/scene_controller_pointer_session.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- removal of `lib/src/interactive/internal/scene_controller_facade_assembly.dart`
- removal of `lib/src/interactive/internal/scene_controller_pointer_semantics.dart`
- removal of `lib/src/interactive/scene_view_pointer_semantics.dart`
- `tool/src/import_boundaries/import_boundary_policy.dart`
- `tool/src/import_boundaries/directive_boundary_checker.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/invariant_registry.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/view/scene_view_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_pointer_router_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_83_scene_view_runtime_boundary_and_controller_detachment.md`

### Not Included in the Change

- Any public `SceneView` / `SceneViewInteractive` constructor change; the
  public widget surface remains `SceneController`-based
- Any public `SceneControllerInteraction`, `SceneControllerSelection`, or
  `SceneControllerScene` API widening
- Moving raw pointer routing, admission, or slot reuse ownership out of
  `view/**`
- Any write-side mutation-pipeline, gesture-routing, or commit-pipeline refactor
- Any `SceneStoreController` write/read contract change unrelated to adopting a
  controller-agnostic render-surface entrypoint
- Any file outside the listed zones unless a targeted verification cannot close
  without it

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/scene_view_runtime.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_runtime_owner.dart`
- `lib/src/view/scene_view_render_surface.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/view/scene_view_interactive_overlay_painter.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_owners.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/scene_controller_pointer_session.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `tool/src/import_boundaries/import_boundary_policy.dart`
- `tool/src/import_boundaries/directive_boundary_checker.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`

### Test Files

- `test/contract/runtime_contract_interfaces_test.dart`
- `test/view/scene_view_test.dart`
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
- `plan/step_83_scene_view_runtime_boundary_and_controller_detachment.md`

### Analysis Area

- `lib/src/view/**`
- `lib/src/interactive/**`
- `lib/src/contract/**`
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

- Every modified production file must either introduce the runtime boundary,
  adopt it, remove a concrete-controller/separate-pointer-seam bypass, or
  enforce the no-return structural boundary.
- Every modified test file must pin one confirmed regression surface:
  public-shell drift,
  concrete-controller drift in view core,
  pointer-host lifecycle drift,
  or owner-graph drift in `SceneController`.
- Every modified tooling, invariant, or architecture file must describe and
  enforce the same public-shell exception and runtime-core boundary.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. The public `SceneViewInteractive` / `SceneView` constructor surface remains
   `SceneController`-based; the concrete controller contact is confined to the
   public entry shell only.
2. The view implementation beneath the public shell consumes one internal-safe
   contract defined in `lib/src/contract/scene_view_runtime.dart`.
3. `SceneController` must not implement `SceneViewRenderState` or any
   view-facing pointer source contract after this step closes.
4. `SceneController` must not directly import
   `scene_controller_internal_access.dart`,
   `scene_controller_pointer_session.dart`,
   or any replacement concrete view-runtime/session owner; assembly of these
   roles lives in one internal owner-graph file.
5. `SceneViewInteractivePointerHost` remains the owner of raw pointer
   admission, invalid finite filtering, raw-to-slot routing, raw release
   bookkeeping, and router debug counters.
6. `SceneViewInteractivePointerHost` must not own controller listener wiring,
   pointer-settings adoption policy, pending-flush scheduling policy, or
   concrete pointer-session construction after this step closes.
7. Overlay ownership stays outside the shared render-surface boundary and uses
   the same runtime/render-state repaint source as the main painter.
8. `scene_controller_internal_access.dart` remains test/debug-only and must not
   transport production `SceneViewRuntime` or pointer-session ownership.
9. Existing behavior for controller swap without remount, pending tap flush
   timing, invalid terminal forwarding, pointer-settings apply-on-idle,
   `setCameraOffset(...)` overlay reset, and `replaceScene(...)` overlay reset
   remains unchanged.
10. The new runtime/session owners must read through `SceneController` owner
    access in a way that preserves observable overrides of `snapshot` and
    `interaction` used by existing white-box tests; capturing only base-facade
    fields in a way that bypasses those overrides is forbidden.
11. `SceneViewRuntime` has exactly two responsibilities:
    expose `renderState` and create a pointer session. It must not expose
    scene/selection/interaction capability APIs, mutation entrypoints, or
    controller-debug hooks.
12. `SceneViewPointerSession` owns controller-side reaction to owner changes
    itself; the host must not forward a separate controller-change callback
    after this step closes.
13. `SceneViewRenderSurface` is reduced to one constructor that accepts
    `SceneViewRenderState`; interactive/store mode bifurcation is removed.
14. `SceneViewRuntimeOwner` is the only stateful runtime owner beneath
    the public shell; it owns the render-surface key and pointer-host lifetime.
15. `sceneControllerViewRuntimeOf(SceneController controller)` is the only
    package-level adapter exposed from `interactive/scene_controller.dart` for
    view integration.

## 5. Result Requirements

1. `lib/src/view/scene_view_interactive.dart` is a thin public shell that
   converts `SceneController` into an internal-safe runtime dependency and does
   not own pointer host, render-surface key, or other runtime state.
2. `lib/src/view/scene_view_runtime_owner.dart`,
   `lib/src/view/scene_view_render_surface.dart`,
   `lib/src/view/scene_view_interactive_pointer_host.dart`, and
   `lib/src/view/scene_view_interactive_overlay_painter.dart`
   no longer import `interactive/scene_controller.dart` or
   `interactive/internal/**`.
3. `SceneViewRenderSurface` consumes only `SceneViewRenderState` and no longer
   exposes controller-specific constructor entrypoints.
4. The production tree contains one internal-safe `SceneViewRuntime` contract
   and one opaque `SceneViewPointerSession` contract; the old separate
   `SceneViewPointerSemanticsBridge` / `SceneViewPointerSemanticsSource` seam
   no longer exists.
5. `SceneController` no longer implements the view render-state contract, no
   longer constructs pointer-session owners directly, and no longer registers
   internal access directly in its constructor.
6. One internal owner graph assembles public capability facades, the private
   `SceneViewRuntime`, and test/debug internal access for a `SceneController`
   instance.
7. `SceneViewInteractivePointerHost` contains no controller field, no
   controller listener generation logic, and no pointer-settings/timer owner
   state; it only routes raw input and replaces an opaque pointer session.
8. The current widget and contract tests proving controller swap, pending tap
   timer cancellation, apply-on-idle pointer settings, overlay reset on
   controller-side mutations, and overlay-outside-render-surface ownership
   remain green.
9. Guardrails, structural tests, invariant registration, and `ARCHITECTURE.md`
   describe the same final shape: one public shell may adapt `SceneController`
   to the runtime boundary, and the rest of the view core consumes only that
   runtime boundary.
10. The new runtime/session contracts have one canonical API shape and no
    alternative constructor or callback form is left in production code.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/view/scene_view_interactive.dart` currently owns pointer host state,
  render-surface key lookup, and direct `SceneController` pointer-semantics
  bridge creation.
- `lib/src/view/scene_view_render_surface.dart` currently imports concrete
  controller types for `store(...)` / `interactive(...)` entrypoints even
  though its runtime field is already `SceneViewRenderState`.
- `lib/src/view/scene_view_interactive_pointer_host.dart` currently owns the
  controller field, controller listener lifecycle, pointer-semantics bridge
  replacement, and controller-change forwarding.
- `lib/src/interactive/scene_controller.dart` currently implements
  `SceneViewRenderState` and the view-facing pointer seam, constructs the
  concrete pointer-semantics owner, and registers internal access directly.
- `lib/src/interactive/internal/scene_controller_pointer_semantics.dart`
  currently owns pending-flush scheduling, pointer-settings adoption, and
  double-tap tracking, but depends on the host to notify controller changes.
- `test/view/scene_view_interactive_test.dart` uses `_OverlayTestController`
  and `_RecordingPointerController` subclasses that override `snapshot` and
  `interaction`; the new runtime/session path must not bypass those overrides.

### 6.1.1 Canonical Runtime Contract Shape

- `lib/src/contract/scene_view_runtime.dart` must define exactly:
  - `abstract interface class SceneViewRuntime`
  - `SceneViewRenderState get renderState;`
  - `SceneViewPointerSession createPointerSession({required bool Function() isMounted, required bool Function() hasLiveRawPointers});`
  - `abstract interface class SceneViewPointerSession`
  - `int? get pendingTapFlushTimestampMs;`
  - `void handleRoutedSample(PointerSample sample, {required bool shouldTrackSignals});`
  - `void handleInvalidTerminalSample({required CanvasPointerInput input, required int pointerId, required int referenceTimestampMs});`
  - `void handleRawPointerRelease({required bool isIdleAfterRelease});`
  - `void dispose();`
- `SceneViewPointerSession` must not define `handleControllerChanged(...)`,
  `updateController(...)`, or any mutation-facing API.
- `SceneViewRuntime` must not implement `Listenable`.

### 6.1.2 Canonical Widget Composition

- `scene_view_interactive.dart` must define only the public shell widget and
  delegate to `SceneViewRuntimeOwner`.
- `scene_view_runtime_owner.dart` must define the stateful runtime owner
  beneath the public shell.
- `_SceneViewRuntimeOwnerState.initState()` must create one pointer host
  from `widget.runtime.createPointerSession(...)`.
- `_SceneViewRuntimeOwnerState.didUpdateWidget(...)` must replace the
  pointer session only when `oldWidget.runtime != widget.runtime`.
- `_SceneViewRuntimeOwnerState.build(...)` must compose:
  `Listener -> CustomPaint(foregroundPainter: SceneViewInteractiveOverlayPainter(renderState: widget.runtime.renderState)) -> SceneViewRenderSurface(renderState: widget.runtime.renderState, ...)`.
- `scene_view_render_surface.dart` must expose one constructor:
  `SceneViewRenderSurface({required SceneViewRenderState renderState, ...})`.

### 6.1.3 Canonical Interactive Assembly Shape

- `scene_controller_owners.dart` must assemble and return all controller
  owners in one value object that includes:
  `interactionRuntime`,
  `interactionAccess`,
  `interaction`,
  `selection`,
  `scene`,
  `viewRuntime`,
  and `internalAccessRegistration`.
- `scene_controller_scene_view_runtime.dart` must contain the concrete
  `SceneControllerSceneViewRuntime` and
  `SceneControllerSceneViewRenderState` owners.
- `SceneControllerSceneViewRenderState` must read every field through closures
  on
  the owning controller instance so subclass overrides of `snapshot` and
  `interaction` remain visible.
- `scene_controller_pointer_session.dart` must own its own subscription to the
  assembled owner `Listenable` and must unregister on `dispose()`.
- `interactive/scene_controller.dart` must import only the owner-graph file for
  view/runtime assembly and must expose exactly one package-level adapter:
  `SceneViewRuntime sceneControllerViewRuntimeOf(SceneController controller)`.

### 6.2 Target Verification Units

- `rg -n "import '../interactive/scene_controller.dart';" lib/src/view`
- `rg -n "SceneViewRuntime|SceneViewPointerSession|sceneControllerViewRuntimeOf" lib test tool`
- `rg -n "implements SceneViewRenderState|SceneViewPointerSemanticsSource|createPointerSemanticsBridge|registerSceneControllerInternalAccess" lib/src/interactive/scene_controller.dart`
- `rg -n "SceneViewPointerSemanticsBridge|SceneViewPointerSemanticsSource|SceneControllerPointerSemantics" lib test tool`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/contract/scene_view_runtime.dart lib/src/view lib/src/interactive --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/contract/runtime_contract_interfaces_test.dart`
- MCP test runner: `test/view/scene_view_test.dart`
- MCP test runner: `test/view/scene_view_interactive_test.dart`
- MCP test runner: `test/view/scene_view_pointer_router_test.dart`
- MCP test runner: `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- MCP test runner: `test/interactive/core/scene_controller_interaction_contract_test.dart`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- `SceneViewPointerRouter` raw slot allocation, min-free-slot reuse, and
  single active signal-tracking gate
- Pending tap flush timing and deferred pointer-settings adoption until router
  idle
- Invalid terminal forwarding into the existing interaction pointer path
- Overlay-outside-render-surface ownership
- Render-cache invalidation tied to controller epoch changes
- Existing `SceneController` capability surfaces and their public behavior
- White-box test controllers that override `snapshot` and `interaction`

### 6.4 Allowed Semantic Change Zones

- The internal-safe runtime/session contract used between the public shell and
  the view core
- The split between a public `SceneController` shell adapter and the
  controller-agnostic runtime widget
- The controller-local owners assembly that assembles view runtime and internal
  access without leaking those owners into the public facade
- The raw-host vs. opaque-session boundary for pointer handling
- Structural enforcement and architecture documentation for the public-shell
  exception and view-core boundary

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct concrete-controller import in a view-core file
- alias-based or helper-based bypass that reads `SceneController` or
  `SceneControllerInteraction` directly from view core instead of through the
  runtime boundary
- direct `registerSceneControllerInternalAccess(...)` in
  `scene_controller.dart`
- direct construction of `SceneControllerPointerSession`,
  `PointerInputTracker`, or `_PendingTapFlushScheduler` in the pointer host
- stale capture form where the runtime/session owner stores base-facade fields
  in a way that bypasses virtual `snapshot` / `interaction` overrides

### 6.6 Allowed Forms That Do Not Count as Violations

- `lib/src/view/scene_view_interactive.dart` may import
  `interactive/scene_controller.dart` and call
  `sceneControllerViewRuntimeOf(controller)`; no other production view file may
- `test/**` may continue to import
  `interactive/internal/scene_controller_internal_access.dart`
- Interactive-local runtime/session owners may depend on `SceneController` as
  an owner input, but only inside `interactive/internal/**`

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Structural checks must treat `scene_view_interactive.dart` as the only
  allowed concrete-controller adapter in `view/**`; all other production
  `view/**` files are checked against the runtime boundary.
- The change is not closed while any production source, guardrail, invariant,
  or test still references
  `scene_view_pointer_semantics.dart`,
  `SceneViewPointerSemanticsBridge`,
  `SceneViewPointerSemanticsSource`, or
  `SceneControllerPointerSemantics`.
- If `scene_controller_facade_assembly.dart` is replaced by
  `scene_controller_owners.dart`, all references in tests, guardrails,
  docs, and tooling must move in the same change; dangling path references keep
  the slice open.

### 6.8 Prohibited

- Exporting `SceneViewRuntime` or any replacement internal runtime owner from
  `lib/iwb_canvas_engine.dart`
- Keeping the old pointer-semantics seam alive in parallel with the new
  runtime/session boundary
- Adding a second registry or sync layer to mirror view runtime state beside
  the controller-owned assembly
- Keeping controller listener wiring or pending-flush/pointer-settings owner
  state inside `SceneViewInteractivePointerHost`
- Reintroducing controller-specific constructors on `SceneViewRenderSurface`
- Fixing stale overlay/runtime behavior with widget rebuild glue instead of the
  new runtime/session ownership

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

### Slice 1. [x] Introduce the internal view runtime boundary

#### Slice Contract

The public `SceneViewInteractive` shell is separated from a controller-agnostic
runtime widget, and the view core beneath that shell depends only on
`SceneViewRuntime` / `SceneViewRenderState`.

#### Change

Add `scene_view_runtime.dart`, add `scene_view_runtime_owner.dart`,
reduce `scene_view_interactive.dart` to a shell that delegates through
`sceneControllerViewRuntimeOf(...)`, and replace controller-specific
render-surface constructors with a single render-state entrypoint.

#### Verification

- `rg -n "import '../interactive/scene_controller.dart';" lib/src/view`
- MCP test runner: `test/view/scene_view_test.dart`
- MCP test runner: `test/view/scene_view_interactive_test.dart`

#### Positive Scenarios

- Public `SceneViewInteractive(controller: ...)` still mounts and behaves
  normally.
- Render-cache debug access and controller-swap / replace-scene smoke coverage
  remain green through the public shell.

#### Negative Scenarios

- No production view-core file except `scene_view_interactive.dart` imports
  `interactive/scene_controller.dart`.
- `SceneViewRenderSurface` no longer exposes `store(...)` / `interactive(...)`
  constructor bifurcation.

#### Closure Evidence

- green run of the listed verifications
- `rg` output showing the single allowed controller import in `view/**`

### Slice 2. [x] Move view-runtime and internal-access assembly out of `SceneController`

#### Slice Contract

`SceneController` stops directly implementing view contracts and delegates
private runtime/internal-access assembly to one internal owner graph.

#### Change

Introduce `scene_controller_owners.dart` and
`scene_controller_scene_view_runtime.dart`, give `scene_controller.dart` one private
runtime field plus package-internal `sceneControllerViewRuntimeOf(...)`, remove
direct `SceneViewRenderState` / pointer-source implementation, and move
internal-access registration out of the public constructor body.

#### Verification

- `rg -n "implements SceneViewRenderState|SceneViewPointerSemanticsSource|createPointerSemanticsBridge|registerSceneControllerInternalAccess" lib/src/interactive/scene_controller.dart`
- MCP test runner: `test/contract/runtime_contract_interfaces_test.dart`
- MCP test runner: `test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- The runtime contract remains reachable for the public shell through
  `sceneControllerViewRuntimeOf(...)`.
- Structural tests prove that `SceneController` remains a thin public facade
  over assembled owners.

#### Negative Scenarios

- `scene_controller.dart` no longer imports the concrete pointer-session owner
  or internal-access file directly.
- `scene_controller.dart` no longer implements view render/pointer contracts.

#### Closure Evidence

- green run of the listed verifications
- `rg` output showing the removed direct ownership markers in
  `scene_controller.dart`

### Slice 3. [x] Replace pointer semantics with an opaque pointer session

#### Slice Contract

The pointer host owns only raw routing and opaque session replacement, while
controller-change reaction, pending flush scheduling, pointer-settings
adoption, and double-tap tracking move into `SceneControllerPointerSession`.

#### Change

Replace the old pointer-semantics seam with `SceneViewPointerSession` in
`scene_view_runtime.dart`, introduce `scene_controller_pointer_session.dart`,
make the session subscribe to controller-owner notifications using a
router-state callback, and reduce the host to router + raw event forwarding.

#### Verification

- `rg -n "SceneViewPointerSemanticsBridge|SceneViewPointerSemanticsSource|SceneControllerPointerSemantics" lib test tool`
- MCP test runner: `test/view/scene_view_interactive_test.dart`
- MCP test runner: `test/view/scene_view_pointer_router_test.dart`
- MCP test runner: `test/interactive/core/scene_controller_interaction_contract_test.dart`

#### Positive Scenarios

- Controller swap without remount still succeeds.
- Stale pending tap timers still cancel on controller swap and ignore dispose.
- Pointer-settings live apply and apply-on-idle behavior remain unchanged.
- Invalid terminal forwarding and raw slot reuse remain unchanged.

#### Negative Scenarios

- `SceneViewInteractivePointerHost` contains no controller listener lifecycle.
- `SceneViewInteractivePointerHost` does not name `PointerInputTracker`,
  `_PendingTapFlushScheduler`, or the concrete session owner.

#### Closure Evidence

- green run of the listed verifications
- `rg` output showing removal of the old pointer-semantics seam names

### Slice 4. [x] Close the no-return structural boundary

#### Slice Contract

Tools, structural tests, invariants, and architecture documentation all enforce
the same public-shell exception and runtime-core boundary, with no remaining
claims or references to the old seam model.

#### Change

Update import-boundary tooling where needed, tighten interactive guardrails,
update invariant titles/proofs, update `ARCHITECTURE.md`, and register the new
step in `PLAN.md`.

#### Verification

- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Structural checks allow the public `scene_view_interactive.dart` shell to
  adapt `SceneController`.
- Structural checks reject any remaining view-core dependency on
  `SceneController` or `interactive/internal/**`.

#### Negative Scenarios

- Old seam vocabulary and old owner claims are absent from production docs,
  invariants, and guardrails.
- Direct internal-access registration in `SceneController` fails structural
  guardrails.

#### Closure Evidence

- green run of the listed verifications
- diagnostic output from guardrail/import-boundary checks if any negative case
  needed adjustment during closure

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/contract/scene_view_runtime.dart lib/src/view lib/src/interactive --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
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
