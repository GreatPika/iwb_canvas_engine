language: russian

# Шаг 69. Замкнуть интерактивный read-side рендера на одном internal render-state

## 1. Change Mandate

This change closes the remaining interactive render read-side seam by making
`SceneViewRenderSurface`,
`ScenePainter`,
`ScenePainterFrameOwner`,
and
`SceneViewInteractiveOverlayPainter`
consume one internal read-only render-state with one repaint source instead of
mixing controller snapshots, interaction state, snapshot-captured widget
fields, and `interactive/internal` helper readers at the view boundary.

## 2. Change Boundary

### Included in the Change

- `lib/src/view/scene_view_render_surface.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_overlay_painter.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `tool/check_import_boundaries.dart`
- `tool/src/import_boundaries/import_boundary_policy.dart`
- `tool/invariant_registry.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_69_interactive_render_read_side_single_render_state.md`

### Not Included in the Change

- Any public API widening on `SceneController`, `SceneControllerInteraction`,
  `SceneViewInteractive`, or the public `SceneRenderState` contract
- Reopening the step 68 pointer-semantics bridge, raw pointer routing, pending
  tap scheduling, or `PointerInputSettings` live-apply ownership
- Moving pointer host ownership into `SceneViewRenderSurface`
- Moving overlay ownership into `SceneViewRenderSurface`; overlay may remain a
  separate owner, but it must consume the same read-side render-state and
  repaint source as the main painter
- Any write-side mutation-pipeline, gesture-routing, or commit-pipeline
  refactor outside the render read-side seam
- Any file outside the listed zones unless a targeted verification cannot close
  without it

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/view/scene_view_render_surface.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_interactive_overlay_painter.dart`
- `lib/src/view/scene_view_interactive_pointer_host.dart`
- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_internal_access.dart`
- `tool/src/import_boundaries/import_boundary_policy.dart`

### Test Files

- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`

### Fixture and Supporting Data Files

- `tool/check_import_boundaries.dart`
- `tool/invariant_registry.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_69_interactive_render_read_side_single_render_state.md`

### Analysis Area

- `lib/src/view/**`
- `lib/src/render/**`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/**`
- `tool/src/import_boundaries/**`
- `test/view/**`
- `test/render/**`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/import_boundaries/**`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified production file must either introduce the single read-side
  render-state, adopt it, remove a snapshot/helper-based bypass, or preserve
  the locked overlay-outside-surface ownership while switching it to the same
  read-side state and repaint source.
- Every modified test file must pin one confirmed seam regression:
  view-side internal helper access,
  snapshot-captured marquee state,
  split repaint ownership,
  or stale overlay state after controller-side reset mutations.
- Every modified tooling, invariant, or documentation file must mechanically
  enforce or publish the exact render read-side boundary closed by this step.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. The public `SceneRenderState` contract remains narrow and must not be
   widened into an ad hoc interactive render bag.
2. This step introduces one internal read-only render-state for interactive
   render reads; the view boundary must consume that state instead of reading
   epoch, preview delta, selection rectangle, and camera data through separate
   helpers or snapshot-captured widget fields.
3. `SceneViewRenderSurface`, `ScenePainter`, `ScenePainterFrameOwner`, and
   `SceneViewInteractiveOverlayPainter` must read interactive render data from
   the same render-state contract.
4. The main painter and the overlay painter must use the same repaint source.
5. `selectionRect` and per-node preview delta are live render-time reads and
   must not be captured as widget fields or constructor snapshots on the
   interactive path.
6. `lib/src/view/scene_view_render_surface.dart` must not import
   `interactive/internal/**` for read-side epoch or preview access after this
   step closes.
7. A `setState(...)`-driven or widget-rebuild-only fix does not satisfy this
   step; closure requires the correct read-side state contract and repaint
   ownership.
8. Step 22 remains valid: overlay ownership stays outside the shared
   render-surface boundary even after both painters switch to the same
   read-side render-state.
9. Step 68 remains valid: pointer-semantics bridge closure stays separate from
   this read-side render-state closure and must not be reopened.

## 5. Result Requirements

1. The production tree has one internal render-state contract that provides the
   interactive render reads required by the main painter and overlay:
   committed snapshot,
   selected node ids,
   controller epoch,
   live selection rectangle,
   live preview delta lookup,
   committed camera offset,
   and one repaint `Listenable`.
2. `lib/src/view/scene_view_render_surface.dart` no longer imports
   `lib/src/interactive/internal/scene_controller_internal_access.dart`,
   no longer defines interactive helper readers for epoch or preview delta,
   and no longer stores interactive `selectionRect` as a widget field.
3. `ScenePainter` repaints from the unified render-state and does not receive
   interactive `selectionRect` or interactive preview resolution as separate
   snapshot-style constructor inputs.
4. `ScenePainterFrameOwner` resolves live `selectionRect` and live preview
   delta from the unified render-state when building a frame.
5. `SceneViewInteractiveOverlayPainter` no longer combines
   `SceneController` and `SceneControllerInteraction` as split read-side
   sources; it reads preview and camera data from the same render-state used by
   the main painter.
6. Interactive marquee and overlay repaint immediately on drag-state and
   controller-reset changes without a widget rebuild workaround.
7. `view/**` no longer imports `interactive/internal/**` for the closed
   interactive render read-side seam.
8. Widget coverage proves marquee rectangle updates during drag without a
   rebuild shim and proves `setCameraOffset(...)` plus `replaceScene(...)`
   clear stale overlay state on screen immediately.
9. `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
   `tool/invariant_registry.dart`, and the relevant structural tests describe
   and enforce the same closed render read-side boundary.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/contract/scene_render_state.dart` currently exposes only
  `snapshot` and `selectedNodeIds`.
- `lib/src/view/scene_view_render_surface.dart` currently imports
  `scene_controller_internal_access.dart`, defines
  `_interactiveControllerEpochReader(...)`,
  `_interactivePreviewOffsetResolver(...)`,
  and stores interactive `selectionRect` in the widget field `_selectionRect`.
- `SceneViewRenderSurface.interactive(...)` currently receives
  `SceneController`, passes `controller` into `ScenePainter`, and wires
  interactive preview/selection through separate constructor arguments.
- `lib/src/render/scene_painter.dart` currently repaints from
  `super(repaint: controller)`, accepts `selectionRect` and
  `nodePreviewOffsetResolver` as separate inputs, and passes them into
  `ScenePainterFrameOwner`.
- `lib/src/render/scene_painter_frame.dart` currently stores `selectionRect`
  and preview resolution outside the render-state and reads only snapshot plus
  selected ids from `SceneRenderState`.
- `lib/src/view/scene_view_interactive_overlay_painter.dart` currently uses
  `super(repaint: interaction)` while reading camera offset from
  `controller.snapshot.camera.offset`.
- `lib/src/view/scene_view_interactive.dart` currently builds the main render
  surface from `controller`, builds the overlay from `controller` plus
  `controller.interaction`, and still passes `onControllerChanged: () {}` to
  `SceneViewInteractivePointerHost`.
- `plan/step_68_pointer_semantics_view_boundary_closure.md` explicitly left
  the `scene_view_render_surface.dart -> scene_controller_internal_access.dart`
  dependency open as a separate read-side/render-state seam.

### 6.2 Target Verification Units

- `rg -n "scene_controller_internal_access\\.dart" lib/src/view`
- `rg -n "_interactiveControllerEpochReader|_interactivePreviewOffsetResolver|_selectionRect" lib/src/view/scene_view_render_surface.dart`
- `rg -n "super\\(repaint: interaction\\)|controller\\.snapshot\\.camera\\.offset" lib/src/view/scene_view_interactive_overlay_painter.dart`
- `rg -n "selectionRect|nodePreviewOffsetResolver|super\\(repaint: controller\\)" lib/src/render/scene_painter.dart lib/src/render/scene_painter_frame.dart`
- `rg -n "onControllerChanged: \\(\\) \\{\\}" lib/src/view/scene_view_interactive.dart`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/interactive --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Root-owned committed snapshot and selected-node state on `SceneController`
- Interactive preview ephemerality for move and draw gestures
- Render-cache lifecycle invalidation tied to controller epoch changes
- Existing pointer host ownership of raw Flutter pointer routing and controller
  listener wiring
- Overlay-outside-render-surface ownership fixed by step 22
- Pointer-semantics bridge closure fixed by step 68
- Public capability surface of `SceneController`,
  `SceneControllerInteraction`,
  `SceneControllerSelection`,
  `SceneControllerScene`,
  and `SceneView`

### 6.4 Allowed Semantic Change Zones

- One internal read-only render-state contract and its controller-private
  assembly/registration path
- Interactive and core render-surface adoption of the unified render-state
- Painter/frame read-side ownership for live preview delta and live marquee
  state
- Overlay read-side ownership and repaint wiring
- Import-boundary, invariant, structural-test, and documentation updates that
  pin the unified render-state boundary

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct helper bypass where `view/**` reads epoch or preview state through
  `scene_controller_internal_access.dart`
- widget-snapshot bypass where interactive marquee state is captured in a
  widget field such as `_selectionRect`
- split-source bypass where overlay reads camera from controller and preview
  state from `interaction`
- split-listenable bypass where main painter and overlay painter repaint from
  different `Listenable` owners
- constructor-resolver bypass where interactive preview or selection state is
  threaded into `ScenePainter` through separate helper callbacks instead of the
  unified render-state

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The step is not closed unless the closed seam is removed from production
  `view/**`; a remaining `scene_view_render_surface.dart ->
  scene_controller_internal_access.dart` import keeps the step open.
- Introducing a new internal render-state helper or owner is allowed only if
  it becomes the single render read-side contract for the affected painters and
  does not widen the public API.
- Keeping overlay outside `SceneViewRenderSurface` is allowed only if overlay
  consumes the same render-state and repaint source as the main painter.
- Core-mode rendering may adapt committed-only values into the same internal
  render-state contract, but it must not reintroduce interactive helper seams
  or a second read-side contract shape.

### 6.8 Prohibited

- Fixing the stale marquee or overlay behavior by adding widget `setState(...)`
  rebuild glue while keeping the current split read-side design
- Keeping `_interactiveControllerEpochReader(...)`,
  `_interactivePreviewOffsetResolver(...)`,
  or widget-owned interactive `_selectionRect` in
  `scene_view_render_surface.dart`
- Keeping `ScenePainter` on one repaint source and overlay on another
- Reintroducing a controller/interaction split read-side in overlay after the
  unified render-state is available
- Widening public `SceneRenderState` or public controller/view capability
  surfaces to carry the new internal render-state contract
- Adding synchronizers or duplicated mutable mirrors to keep two render-state
  owners in sync

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

### Slice 1. [ ] Adopt one render-state at the render-surface boundary

#### Slice Contract

`SceneViewRenderSurface` consumes one internal render-state instead of
interactive helper readers and widget-captured marquee state.

#### Change

Introduce the internal read-only render-state contract and switch
`SceneViewRenderSurface` to accept that state for the interactive path,
removing the local epoch reader, preview resolver helper, and widget-owned
`selectionRect` snapshot.

#### Verification

- `rg -n "scene_controller_internal_access\\.dart" lib/src/view`
- `rg -n "_interactiveControllerEpochReader|_interactivePreviewOffsetResolver|_selectionRect" lib/src/view/scene_view_render_surface.dart`
- MCP test runner: `test/view/scene_view_test.dart`
- MCP test runner: `test/view/scene_view_interactive_test.dart`

#### Positive Scenarios

- Interactive render-surface cache lifecycle still clears on controller epoch
  changes and controller replacement.
- Interactive render-surface construction no longer requires local helper
  readers for epoch, preview delta, or marquee state.

#### Closure Evidence

- green run of the listed verifications
- `rg` output shows the interactive helper readers and widget-owned marquee
  snapshot are removed from `scene_view_render_surface.dart`

### Slice 2. [ ] Move painter frame reads to the live render-state

#### Slice Contract

`ScenePainter` and `ScenePainterFrameOwner` resolve live preview and marquee
state from the unified render-state and repaint from that state.

#### Change

Replace the interactive snapshot-style painter inputs with the unified
render-state contract, move live `selectionRect` and preview-delta reads into
frame creation, and align painter repaint ownership with the unified state.

#### Verification

- `rg -n "selectionRect|nodePreviewOffsetResolver|super\\(repaint: controller\\)" lib/src/render/scene_painter.dart lib/src/render/scene_painter_frame.dart`
- MCP test runner: `test/render/scene_painter_test.dart`
- MCP test runner: `test/render/scene_painter_frame_contract_test.dart`

#### Positive Scenarios

- Preview delta is resolved once per node per frame through the unified
  render-state.
- Marquee rendering still appears when live selection-rectangle state is
  present.

#### Closure Evidence

- green run of the listed verifications
- render tests prove frame-time preview resolution and marquee rendering
  without snapshot-style widget inputs

### Slice 3. [ ] Switch overlay to the same render-state and repaint source

#### Slice Contract

Interactive overlay reads camera and preview state from the same render-state
and repaint source as the main painter.

#### Change

Replace the split `controller + interaction` overlay inputs with the unified
render-state, wire the same repaint source into overlay, and remove the
remaining interactive read-side helper seam from `view/**`.

#### Verification

- `rg -n "super\\(repaint: interaction\\)|controller\\.snapshot\\.camera\\.offset" lib/src/view/scene_view_interactive_overlay_painter.dart`
- `rg -n "scene_controller_internal_access\\.dart" lib/src/view`
- `rg -n "onControllerChanged: \\(\\) \\{\\}" lib/src/view/scene_view_interactive.dart`
- MCP test runner: `test/view/scene_view_interactive_test.dart`

#### Positive Scenarios

- Marquee rectangle changes while drag is in progress without a widget rebuild
  shim.
- `setCameraOffset(...)` and `replaceScene(...)` clear stale overlay state on
  screen immediately.

#### Negative Scenarios

- Overlay must not keep stale preview or camera state after controller-side
  reset mutations.
- View must not reintroduce `interactive/internal/**` imports for render
  read-side access after the unified render-state exists.

#### Closure Evidence

- green run of the listed verifications
- widget tests prove live marquee updates and immediate overlay clearing after
  reset mutations
- `rg` output shows no closed render read-side import remains under `view/**`

### Slice 4. [ ] Pin the closed read-side boundary in docs and structural checks

#### Slice Contract

Repo-local docs, invariant registration, and structural enforcement describe
and reject the old split render read-side.

#### Change

Update the import-boundary policy, invariant registry, architecture/public
docs, changelog, and structural tests so the closed render read-side seam is
documented and mechanically enforced.

#### Verification

- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner: `test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Positive Scenarios

- Import-boundary tooling rejects a reintroduced `view/** ->
  interactive/internal/**` render read-side bypass.
- Repo-local docs and invariants describe the same unified render-state
  boundary.

#### Negative Scenarios

- Structural tests fail if view reintroduces the closed helper seam or if the
  unified render-state boundary drifts from docs and invariants.

#### Closure Evidence

- green run of the listed verifications
- tooling and structural checks fail against the old bypass forms and pass for
  the closed unified render-state design

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/interactive --report-all`
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
