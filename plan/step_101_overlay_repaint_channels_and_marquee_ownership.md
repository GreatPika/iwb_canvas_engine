language: russian

# Шаг 101. Разделить scene/overlay repaint channels и перенести marquee в overlay

## 1. Change Mandate

Этот шаг разделяет controller-owned scene и overlay repaint channels внутри
одного render-state family и переносит marquee selection rectangle из
`ScenePainter` в overlay painter, чтобы overlay-only interactive state больше
не тянул repaint базовой сцены.

## 2. Change Boundary

### Included in the Change

- Internal render-state family split into scene and overlay repaint channels.
- Overlay ownership migration for `selectionRect`/marquee painting.
- View/runtime wiring changes required so the main painter listens only to the
  scene repaint channel and the overlay painter listens to the overlay repaint
  channel.
- Controller-private commit and mutation routing changes required to invalidate
  the correct repaint channel for committed scene, selection, camera, and
  opaque write paths while keeping one controller-owned render-state family.
- Render/view/interactive/invariant/documentation surfaces required to prove
  and publish the split repaint-channel architecture.

### Not Included in the Change

- Viewport candidate enumeration ownership or frame candidate selection.
- Text-layout payload ownership and frame-local text layout handoff.
- Dynamic selection-halo cull-budget computation.
- Node selection halo rendering ownership; node halos remain in the main
  `ScenePainter` selection pass.
- Public scene/model/write contracts, public listener-delivery semantics, and
  hit-test eligibility semantics.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/interactive/internal/interactive_event_dispatcher.dart`
- `lib/src/interactive/internal/interactive_runtime_callbacks.dart`
- `lib/src/interactive/internal/interactive_move_callbacks.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator_callbacks.dart`
- `lib/src/interactive/internal/interactive_draw_coordinator.dart`
- `lib/src/interactive/internal/interactive_runtime.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/controller/commands/scene_commands.dart`
- `lib/src/controller/scene_controller_commit_runtime.dart`
- `lib/src/controller/scene_controller_committed_mutation_access.dart`
- `lib/src/controller/scene_store_controller.dart`
- `lib/src/view/scene_view_interactive_overlay_painter.dart`
- `lib/src/view/scene_view_runtime_host.dart`
- `lib/src/view/scene_view_render_surface.dart`
- `lib/src/render/scene_painter_contract.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_selection.dart`

### Test Files

- `test/controller/core/scene_controller_committed_mutation_access_test.dart`
- `test/controller/core/scene_controller_writer_lifecycle_test.dart`
- `test/interactive/core/interactive_move_session_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_test.dart`

### Fixture and Supporting Data Files

- `test/support/committed_scene_view_render_state.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `tool/invariant_registry.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_101_overlay_repaint_channels_and_marquee_ownership.md`

### Analysis Area

- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/controller/**`
- `lib/src/interactive/internal/**`
- `lib/src/view/**`
- `lib/src/render/scene_painter_*`
- `test/controller/core/**`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/interactive/core/**`
- `test/view/**`
- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/support/committed_scene_view_render_state.dart`
- `test/tool/**`
- `tool/invariant_registry.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either introduce the split repaint
  channel contract, adopt it on the controller-owned runtime/view wiring, or
  remove marquee painting from the base scene painter.
- Every modified test file must pin one closed seam of this step:
  split repaint channel wiring,
  overlay-owned marquee painting,
  main-painter non-ownership of `selectionRect`,
  or controller-owned render-state family retention.
- Every modified supporting or documentation file must publish or enforce the
  exact split repaint-channel contract closed by this step.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step changes repaint topology and marquee ownership only. It must not
   absorb viewport candidate enumeration changes, text-layout owner changes, or
   selection-halo cull-budget changes.
2. Controller-owned render reads remain one assembled render-state family.
   This step does not reintroduce widget-local snapshot glue, a second scene
   source of truth, or a view-owned interactive state mirror.
3. `SceneViewRenderState` remains the main painter's `Listenable` scene repaint
   channel and gains one additional overlay repaint channel surface named
   `overlayRepaintListenable`.
4. `ScenePainter` keeps listening only to the scene repaint channel. The
   interactive overlay painter listens only to `overlayRepaintListenable`.
5. `selectionRect` marquee painting moves fully into
   `SceneViewInteractiveOverlayPainter`; `ScenePainterSelectionRenderer`
   continues owning node selection halos only.
6. Overlay repaint routing remains controller-owned: committed scene changes
   that affect overlay reads, such as camera changes and scene replacement,
   must still reach the overlay repaint channel in addition to the scene
   repaint channel.
7. Committed selection changes that affect `selectedNodeIds` remain
   main-painter-visible state and must notify the scene repaint channel.
   Transient marquee `selectionRect` changes remain overlay-only state and must
   notify the overlay repaint channel. A gesture that changes both must notify
   both channels through those distinct causes rather than a shared fallback
   notify path.
8. Public `SceneController` listener-delivery semantics are not a target of
   this step. The repaint split may refactor controller-private scheduling, but
   it must not redefine the public async/coalescing contract for raw input and
   configuration entrypoints.

## 5. Result Requirements

1. The production tree has one controller-owned render-state family with two
   repaint channels: scene repaint through `SceneViewRenderState` itself and
   overlay repaint through `overlayRepaintListenable`.
2. Overlay-only interactive state changes, including marquee `selectionRect`
   updates and stroke/line preview updates, no longer use the main painter's
   repaint channel.
3. Committed `selectedNodeIds` changes continue to repaint the main painter so
   node selection halos remain correct after the repaint split.
4. `ScenePainterSelectionRenderer` no longer paints marquee selection
   rectangles and no longer depends on `selectionRect` in the base frame
   contract.
5. `SceneViewInteractiveOverlayPainter` paints marquee selection rectangles
   from controller-owned render state and keeps stroke/line preview ownership.
6. The invariant registry, proof surface, and release-ready docs describe one
   controller-owned render-state family with split scene/overlay repaint
   channels instead of one shared repaint source.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/contract/scene_view_render_state.dart` currently exposes one
  internal read-side contract shared by the main painter and overlay painter
  and has no split repaint channel surface.
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
  currently forwards `addListener`/`removeListener` directly to one
  `ownerListenable` for both scene and overlay repaint behavior.
- `lib/src/interactive/internal/interactive_event_dispatcher.dart` and
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
  currently own one interactive notify scheduler that drives all overlay and
  scene-local interactive state through one notify path.
- `lib/src/interactive/internal/interactive_runtime.dart`,
  `interactive_move_session.dart`, and `interactive_draw_coordinator.dart`
  currently route marquee, move preview, and line/stroke preview state changes
  through one `onStateChanged` callback path.
- `lib/src/render/scene_painter_selection.dart` currently paints both node
  selection halos and marquee `selectionRect`.
- `lib/src/view/scene_view_interactive_overlay_painter.dart` currently paints
  only stroke and line previews.
- `lib/src/view/scene_view_runtime_host.dart` currently routes both painters
  through one `renderState` object and one repaint source.
- `README.md`, `API_GUIDE.md`, and `ARCHITECTURE.md` currently describe one
  shared repaint source for main painter and overlay.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/interactive lib/src/view lib/src/render --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Existing controller-owned render-state family ownership.
- Existing controller-owned render candidate enumeration and frame resolution in
  `ScenePainter`.
- Existing text-layout payload ownership and frame-local text handoff.
- Existing node selection halo rendering in the main `ScenePainter`.
- Existing overlay ownership for stroke and line previews.
- Existing public `SceneViewRuntime` boundary; this step must not widen it.

### 6.4 Allowed Semantic Change Zones

- Internal repaint channel routing for scene and overlay consumers.
- Controller-owned runtime/read-side wiring for overlay and scene repaint
  notifications.
- Marquee selection rectangle rendering ownership.
- Base painter frame contract cleanup after marquee removal.
- Invariant and documentation wording for the split repaint-channel contract.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `SceneViewRenderState` must keep `Listenable` semantics as the scene repaint
  channel and must add one exact internal getter:
  `Listenable get overlayRepaintListenable;`.
- `SceneViewRuntime` must keep the existing single `renderState` getter.
  This step must not widen the public runtime boundary with a second render
  state object or a second runtime getter.
- `SceneControllerSceneViewRenderState` must stop proxying
  `addListener`/`removeListener` directly to the controller owner. It must own
  one scene repaint notifier and one overlay repaint notifier while continuing
  to expose one assembled render-state read surface.
- Store-controller changes that affect committed scene reads used by both
  painters, including scene replacement and committed camera changes, must
  notify both repaint channels.
- Opaque `scene.write(...)` commits must invalidate both repaint channels,
  because the public write adapter does not preserve enough domain detail after
  commit to route scene-only versus overlay-only repaint causes exactly.
- Committed selection changes that affect `selectedNodeIds` must notify the
  scene repaint channel and must not rely on the overlay repaint channel for
  halo correctness.
- Interactive move-preview changes that affect only `ScenePainter`, including
  `previewDeltaResolver(nodeId)` changes, must notify only the scene repaint
  channel.
- Interactive marquee `selectionRect` changes must notify only the overlay
  repaint channel.
- Interactive draw preview changes, including stroke and line preview state,
  must notify only the overlay repaint channel.
- `InteractiveNotifyScheduler` and the callback graph under
  `interactive_runtime.dart` must stop exposing one generic notify callback.
  The callback graph must be split so move-preview and marquee changes are
  routed through distinct repaint callbacks and draw-preview changes route
  through the overlay repaint callback.
- `SceneViewInteractiveOverlayPainter` must use
  `renderState.overlayRepaintListenable` as its repaint owner and must draw the
  marquee rectangle from `renderState.selectionRect`.
- `ScenePainterSelectionRenderer` must remove `_drawMarqueeSelection(...)`.
  Base frame contracts must stop carrying `selectionRect` once no main-painter
  consumer remains.
- `SceneViewRenderSurface` must keep listening only to the scene repaint
  channel for cache lifecycle and base painter updates.
- Public `SceneController` listener delivery must remain on the pre-step
  async/coalesced contract; split repaint channels are an internal routing
  change, not a public notification-behavior rewrite.

### 6.8 Prohibited

- Moving marquee drawing into the overlay painter without splitting repaint
  channels.
- Replacing one controller-owned render-state family with widget-local state,
  duplicate scene snapshots, or helper-side mirrors.
- Widening `SceneViewRuntime` with a second public render-state getter.
- Keeping `selectionRect` in the base painter frame contract after marquee
  ownership has moved to the overlay path.
- Moving node selection halos into the overlay path in this step.
- Leaving docs or invariants claiming that main painter and overlay share one
  repaint source after the step is complete.

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
9. The plan must be detailed enough that the implementing agent has no material
   branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered valid.
11. If a slice depends on an unconfirmed architectural decision, planning must
    stop and that decision must be explicitly confirmed by the user before the
    slice can be written or expanded.

## 8. Vertical Slices

### Slice 1. [x] Controller-owned render-state family exposes split repaint channels

#### Slice Contract

The controller-owned render-state family exposes one scene repaint channel and
one overlay repaint channel, while keeping one assembled render-state read
surface for both painters.

#### Change

- Extend `SceneViewRenderState` with the exact internal getter
  `overlayRepaintListenable`.
- Replace direct `ownerListenable` proxying in
  `SceneControllerSceneViewRenderState` with two owned notifiers:
  one for scene repaint and one for overlay repaint.
- Split `InteractiveNotifyScheduler`, `InteractiveRuntimeCallbacks`,
  `InteractiveMoveSessionCallbacks`, and
  `InteractiveDrawCoordinatorCallbacks` so the runtime can route:
  committed scene changes to both channels,
  move preview changes to the scene channel,
  marquee changes to the overlay channel,
  and draw preview changes to the overlay channel.
- Update `test/support/committed_scene_view_render_state.dart` and the
  test-local static render states so they satisfy the expanded internal
  contract without introducing a second production owner model.

#### Verification

- `dart run tool/check_import_boundaries.dart`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `interactive`

#### Fixtures Used

- `test/support/committed_scene_view_render_state.dart`

#### Positive Scenarios

- A committed scene or camera change notifies both repaint channels.
- A committed selection change notifies the scene repaint channel without
  notifying the overlay repaint channel unless the same gesture also changes
  overlay-only state separately.
- A move-preview delta change notifies the scene repaint channel without
  notifying the overlay repaint channel.
- A marquee or draw-preview change notifies the overlay repaint channel without
  notifying the scene repaint channel.

#### Negative Scenarios

- `SceneControllerSceneViewRenderState` must not proxy scene repaint listeners
  back to one shared owner `Listenable`.
- No runtime callback type may keep one generic repaint callback after this
  slice.
- Committed selection changes must not be routed only through the overlay
  repaint channel.

#### Closure Evidence

- Green run of the listed verifications.
- Runtime and architecture-boundary tests prove the split channel wiring and
  the absence of one generic notify path.

### Slice 2. [x] Overlay owns marquee painting and base frame drops selectionRect

#### Slice Contract

Marquee `selectionRect` painting is owned entirely by the overlay painter, and
the base scene painter no longer carries or paints marquee state.

#### Change

- Move marquee rectangle painting from `scene_painter_selection.dart` into
  `SceneViewInteractiveOverlayPainter`.
- Remove `selectionRect` from `ScenePainterPaintFrame` and any base
  main-painter frame assembly once no base-painter consumer remains.
- Keep node selection halos in `ScenePainterSelectionRenderer`.
- Update `SceneViewRuntimeHost` wiring so the overlay painter reads marquee,
  line preview, and stroke preview from the same controller-owned render-state
  object while repainting only from `overlayRepaintListenable`.

#### Verification

- `dcm calculate-metrics lib/src/interactive lib/src/view lib/src/render --report-all`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios

- A live marquee gesture increases `drawRect` activity in the overlay painter.
- A live marquee gesture does not add marquee painting work to the main
  `ScenePainter`.
- Stroke and line preview painting remain in the overlay painter after marquee
  migration.

#### Negative Scenarios

- `ScenePainterSelectionRenderer` must not keep `_drawMarqueeSelection(...)` or
  any other `selectionRect` paint path.
- The base frame contract must not keep `selectionRect` as unused baggage after
  marquee migration.

#### Closure Evidence

- Green run of the listed verifications.
- Paint tests prove marquee rendering moved from the base painter to the
  overlay painter.
- Structural tests prove base frame contracts no longer carry `selectionRect`.

### Slice 3. [x] View shell consumes split repaint channels without widening public runtime

#### Slice Contract

`SceneViewRuntimeHost`, `SceneViewRenderSurface`, `ScenePainter`, and the
overlay painter consume the split repaint channels while `SceneViewRuntime`
keeps its existing single `renderState` boundary.

#### Change

- Keep `SceneViewRuntime.renderState` as the only runtime render getter.
- Update `test/contract/runtime_contract_interfaces_test.dart` so the contract
  proof continues to pin one runtime `renderState` getter while allowing the
  internal render-state interface to expose `overlayRepaintListenable`.
- Update `SceneViewRenderSurface` to keep cache lifecycle and base painter
  wiring on the scene repaint channel only.
- Update `SceneViewInteractiveOverlayPainter` construction so `CustomPainter`
  repaint ownership is bound to `renderState.overlayRepaintListenable`.
- Add runtime/widget proof tests that mount a split-channel fake render state
  and verify listener attachment:
  the render surface attaches to the scene channel,
  and the overlay painter attaches to the overlay repaint channel.

#### Verification

- MCP test runner shard preset: `model_contract`
- `dart run tool/check_public_api_surface.dart`
- MCP test runner shard preset: `render_view`

#### Positive Scenarios

- The view shell still consumes one assembled `SceneViewRuntime` boundary.
- Split-channel fake render states show the main render surface and overlay
  painter subscribing to different repaint listenables.

#### Negative Scenarios

- No new public runtime getter may appear for overlay rendering.
- The overlay painter must not keep using `renderState` itself as its repaint
  owner.

#### Closure Evidence

- Green run of the listed verifications.
- Widget/runtime tests prove channel-specific listener attachment without a
  public runtime surface split.

### Slice 4. [x] Invariant and docs publish split repaint-channel architecture

#### Slice Contract

The invariant registry, proof surface, and release-ready docs describe one
controller-owned render-state family with split scene/overlay repaint channels
and overlay-owned marquee painting.

#### Change

- Update `tool/invariant_registry.dart` so
  `INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY` no longer claims one repaint
  source and instead pins one controller-owned render-state family with split
  repaint channels plus overlay ownership outside the render surface.
- Update the proof wording in
  `test/interactive/core/scene_controller_architecture_boundary_test.dart`,
  `test/view/scene_view_interactive_test.dart`, and
  `test/view/scene_view_test.dart` so the proof surface matches the invariant
  exactly.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
  `PLAN.md`, and this step document so they publish the same architecture:
  one controller-owned render-state family,
  scene repaint through `SceneViewRenderState`,
  overlay repaint through `overlayRepaintListenable`,
  marquee ownership in the overlay painter,
  and no widget-side render-state glue.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`

#### Positive Scenarios

- The invariant text and proof files describe the same split repaint-channel
  contract.
- Release-ready docs describe overlay-owned marquee painting and no longer
  claim one shared repaint source.

#### Negative Scenarios

- No invariant or doc text may continue to describe marquee painting in the
  base `ScenePainter`.
- No invariant or doc text may continue to describe one shared repaint source
  for main painter and overlay.

#### Closure Evidence

- Green run of the listed verifications.
- `tool/invariant_registry.dart` and proof files contain aligned wording with
  exact `// INV:<id>` coverage.
- Release-ready docs no longer describe the superseded one-repaint-source
  architecture.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/interactive lib/src/view lib/src/render --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner shard preset: `model_contract`
- MCP test runner shard preset: `render_view`
- MCP test runner shard preset: `interactive`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
