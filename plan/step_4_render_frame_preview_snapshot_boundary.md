# Change Contract

## 1. Change Mandate

Make main-scene rendering consume one frame-owned immutable preview snapshot so
one `SceneViewFrameRead` remains the only preview authority across paint-plan
admission and late node resolution, even if public controller side effects
re-enter during painting.

## 2. Change Boundary

### Included in the Change

- replace the live `previewDeltaResolver` field inside `SceneViewFrameRead`
  with a contract-owned immutable frame-preview value object
- remove the live preview getter from the `SceneViewRenderState` render/view
  seam while keeping the public `SceneController.previewDeltaResolver` live
- capture frame preview data exactly once in
  `SceneControllerSceneViewRenderState.captureFrameRead()` through
  interaction-runtime-owned snapshot materialization
- migrate committed fast-path supplement admission, snapshot-local candidate
  enumeration, and late node paint resolution to the frame-owned preview seam
- add a failing reentrant `imageResolver` reproducer plus neighboring guard
  tests for live public preview reads and frame-preview parity across both
  candidate-enumeration modes
- extend render structural tests so they fail if a live preview callback
  re-enters `SceneViewFrameRead` or render consumers bypass the new frame
  preview object
- update invariant coverage, architecture docs, API guide, README, and
  changelog for frozen frame-preview semantics

### Not Included in the Change

- no new prohibition on `imageResolver` calling public controller APIs during
  paint
- no redesign of move-preview behavior beyond freezing the current per-node
  translation offsets into the frame read
- no change to the public `SceneController.previewDeltaResolver` live read
  contract
- no change to overlay preview ownership for marquee, stroke, or line overlay
  rendering
- no changes to geometry-cache policy, static-layer caching, hit-testing, or
  move-commit delta resolution

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` - active plan index requires one dedicated step document per new
  execution contract
- `lib/src/contract/scene_view_render_state.dart` - `SceneViewFrameRead`
  claims atomic-frame semantics but stores `previewDeltaResolver` as a live
  callback
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  `captureFrameRead()` captures the live resolver and `preparePaintPlan(...)`
  forwards it into both the committed fast path and the snapshot-local fallback
- `lib/src/interactive/internal/scene_controller_graph.dart` - graph assembly
  currently threads `readPreviewDeltaResolver` from `SceneController` into the
  render runtime
- `lib/src/interactive/scene_controller.dart` - the public controller exposes
  a live `previewDeltaResolver` getter and currently supplies that live seam to
  graph assembly
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` -
  runtime owns live preview reads through `previewDeltaForNode(...)` and does
  not forbid public side effects during render callbacks
- `lib/src/interactive/internal/interactive_runtime.dart` -
  `interruptForInteractionConfigChange()` clears move-owned state through
  `_interruptInteractiveState()`
- `lib/src/interactive/internal/interactive_move_session.dart` - live preview
  reads delegate to `InteractiveMovePreviewState.deltaForNode(...)`
- `lib/src/interactive/internal/interactive_move_preview_state.dart` - owns the
  mutable move-preview node set and delta and clears them on interruption
- `lib/src/interactive/scene_controller_interaction.dart` - `setMode(...)`
  calls `interruptForInteractionConfigChange()` and therefore can invalidate
  preview state mid-paint
- `lib/src/render/scene_painter.dart` - `ScenePainter` captures one
  `SceneViewFrameRead` before delegating the whole paint pass
- `lib/src/render/scene_painter_shell.dart` - the same captured `frameRead` is
  reused across background, node, and selection painting
- `lib/src/render/scene_painter_frame.dart` - late node resolution reads
  preview data again from `frameRead`
- `lib/src/render/scene_painter_node_renderer.dart` - `drawImageNode(...)`
  synchronously calls external `imageResolver(...)`, which is the reentrant
  public-callback path during main-scene paint
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart` -
  committed fast-path selected supplement admission uses preview data before
  late node resolution
- `lib/src/core/scene_snapshot_paint_candidates.dart` - snapshot-local
  candidate enumeration also relies on preview data during paint admission
- `lib/src/controller/scene_writer_runtime.dart` - repository precedent for a
  runtime-owned read boundary returning detached immutable values
- `lib/src/interactive/scene_controller_interaction.dart` -
  `MoveCommitDeltaRequest` is the closest public request-object precedent for a
  detached immutable boundary payload
- `lib/src/interactive/internal/interactive_draw_gesture_session.dart` and
  `lib/src/interactive/internal/interactive_draw_coordinator.dart` - existing
  preview-style capture precedent where active draw preview uses captured style
  instead of live config reads
- `test/render/scene_painter_frame_contract_test.dart` - current behavioral
  proof for `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION`, but it only proves
  captured resolver carriage, not frozen semantics
- `test/render/scene_painter_bounds_contract_test.dart` - current structural
  proof for atomic frame capture and render-module split, but it does not ban a
  live preview callback in `SceneViewFrameRead`
- `test/render/scene_painter_test.dart` - render behavior suite already owns
  preview and selection parity tests and is the correct home for the reentrant
  `imageResolver` reproducer
- `test/contract/runtime_contract_interfaces_test.dart` - proves the public
  controller preview resolver is intentionally live and resets to zero after
  `setMode(...)`
- `test/render/scene_static_layer_cache_test.dart` - direct render consumer of
  `CommittedSceneViewReadState` and a surrounding cache regression surface
- `test/view/scene_view_test.dart` - direct view-host consumer of
  `CommittedSceneViewReadState` and a surrounding render-surface regression
  surface
- `test/support/committed_scene_view_read_state.dart` and
  `test/view/scene_view_interactive_test.dart` - in-repo test doubles still
  mirror the current live render seam and must migrate with the contract
- `tool/bench/load_profiles_cases_test.dart` - benchmark-owned
  `SceneViewRenderState` implementation still carries the live preview seam and
  must migrate with the render contract
- `test/tool/bench_run_load_profiles_test.dart` - source-level structural test
  already guards benchmark render-state wiring and should extend to the
  successor frame-preview seam
- `tool/invariant_registry.dart` - the render invariant title mentions one
  atomic frame read but does not yet require frozen frame-preview semantics
- `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md` - the
  repository requires these docs to stay in sync for user-visible behavior
  changes

### Current Entry Path

- `ScenePainter.paint(...)` ->
  `SceneViewRenderState.captureFrameRead()` ->
  `ScenePainterShell.paint(...)` ->
  `ScenePainterFrameOwner.create(...)` ->
  `SceneViewRenderState.preparePaintPlan(...)` ->
  `ScenePainterNodeRenderer._drawVisibleNodes(...)` ->
  `ScenePainterFrameOwner.resolveNodePaintData(...)`
- Reentrant invalidation path during the same paint pass:
  `SceneRichNodeRenderer.drawImageNode(...)` ->
  external `imageResolver(...)` ->
  `SceneControllerInteraction.setMode(...)` ->
  `SceneControllerInteractionRuntime.interruptForInteractionConfigChange(...)`
  -> `InteractiveRuntime._interruptInteractiveState()` ->
  `InteractiveMoveSession.interruptGesture()` ->
  `InteractiveMovePreviewState.clear()`

### Current Owner

- frame-read contract owner:
  `lib/src/contract/scene_view_render_state.dart`
- render-runtime capture owner:
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- live preview owner:
  `lib/src/interactive/internal/interactive_move_preview_state.dart` through
  `SceneControllerInteractionRuntime`
- frame-preview consumers:
  `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`,
  `lib/src/core/scene_snapshot_paint_candidates.dart`, and
  `lib/src/render/scene_painter_frame.dart`

### Adjacent Abstractions

- `SceneControllerPaintCandidateStage` - committed fast-path candidate owner
  adjacent to the frame-preview seam
- `enumerateSnapshotPaintCandidates(...)` - snapshot-local admission path that
  must stay semantically aligned with the committed fast path
- `ScenePainterFrameOwner` - late geometry/preview resolution owner in the
  render layer
- `SceneViewInteractiveOverlayPainter` - live overlay renderer that is
  intentionally outside the `SceneViewFrameRead` main-scene paint seam
- `SceneController.previewDeltaResolver` - public live preview seam that must
  remain distinct from the captured frame seam

### Existing Tests

- `test/render/scene_painter_frame_contract_test.dart` - locks single-frame
  snapshot authority, controller-owned selection revision carriage, active
  frame snapshot fallback, and preview-aware supplement admission
- `test/render/scene_painter_bounds_contract_test.dart` - locks one
  `captureFrameRead()` call, frame-owner/view-rect orchestration, and ordered
  node rendering structure
- `test/render/scene_painter_test.dart` - locks preview application, selection
  parity, culling, and image/text/path paint branches
- `test/contract/runtime_contract_interfaces_test.dart` - locks live public
  preview resolver behavior before and after `setMode(...)`
- `test/view/scene_view_interactive_test.dart` - locks captured draw-style
  semantics for overlay preview after config changes
- `test/render/scene_static_layer_cache_test.dart` - locks surrounding render
  cache behavior through `CommittedSceneViewReadState`
- `test/view/scene_view_test.dart` - locks surrounding view host rendering
  through `CommittedSceneViewReadState`
- `test/tool/bench_run_load_profiles_test.dart` - locks benchmark render-state
  wiring at the source level

### Analogous Implementation Path

- `lib/src/controller/scene_writer_runtime.dart` - runtime-owned read helpers
  already detach immutable values at the boundary instead of exposing live
  owner state
- `lib/src/interactive/scene_controller_interaction.dart` plus
  `MoveCommitDeltaRequest` - public callback payloads are already modeled as
  immutable request objects rather than live callbacks into runtime-owned data
- `lib/src/interactive/internal/interactive_draw_gesture_session.dart` plus
  `lib/src/interactive/internal/interactive_draw_coordinator.dart` - active
  draw preview uses captured style held by the gesture session instead of live
  config reads, proving the repository already prefers captured preview state
  when one preview span must stay coherent

### Governing Repository Rules

- repository instructions - fixes must move to the owner of the invariant, not
  patch one downstream call site
- repository instructions - important invariants should be mechanically
  enforced with tests or tooling rather than prose-only guidance
- repository instructions - public behavior changes must update `README.md`,
  `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md`
- `ARCHITECTURE.md` - frame-authoritative rendering must paint from one atomic
  frame read and the render layer must stay read-only
- `tool/invariant_registry.dart` - render invariants are tracked through
  executable proof surfaces and must stay aligned with structural and
  behavioral tests
- user request for this step - solve the whole class of captured-frame preview
  leakage by freezing preview data at `captureFrameRead()` and making both
  paint-plan preparation and late node resolution consume only that frozen
  snapshot

### Rejected Misleading Local Patterns

- keeping `Offset Function(NodeId)` inside `SceneViewFrameRead` and wrapping it
  in another callback - wrong seam because the captured frame still depends on
  live owner state
- freezing preview only in `preparePaintPlan(...)` or only in
  `resolveNodePaintData(...)` - wrong fix level because it preserves split
  preview authority inside one frame
- forbidding `imageResolver` from mutating the controller during paint - wrong
  owner because render correctness must not depend on app callback purity
- reusing the public `SceneController.previewDeltaResolver` live getter as the
  frame seam - wrong level because the public live read contract is not the
  same thing as the main-scene frame authority
- making the successor frame-preview type an open interface implemented outside
  the contract owner - wrong seam because a live owner could leak back in
  through an externally implemented preview object

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- main-scene render read-boundary ownership between interactive live preview
  state and the frame-captured render pipeline

#### Selected Architectural Form

- introduce a contract-owned final `SceneViewFramePreview` value object in
  `lib/src/contract/scene_view_render_state.dart`
- `SceneViewFrameRead` stores `SceneViewFramePreview` instead of a live preview
  callback
- `SceneControllerSceneViewRenderState.captureFrameRead()` captures one
  detached `SceneViewFramePreview` through interaction-runtime-owned snapshot
  materialization
- the internal constructor seam that currently carries
  `readPreviewDeltaResolver` is replaced with a `captureFramePreview`
  callback of type `SceneViewFramePreview Function()`, so production graph
  wiring, benchmarks, and in-repo test doubles all cross the same frozen
  preview boundary
- all main-scene render consumers read preview data only through
  `SceneViewFramePreview.deltaForNode(...)`
- the public `SceneController.previewDeltaResolver` remains a separate live
  controller seam and is no longer part of `SceneViewRenderState`

#### Owning Layer or Module

- contract shape owner:
  `lib/src/contract/scene_view_render_state.dart`
- frame-preview capture owner:
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
  together with
  `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` and
  `lib/src/interactive/internal/interactive_move_preview_state.dart`
- main-scene preview consumers:
  `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`,
  `lib/src/core/scene_snapshot_paint_candidates.dart`, and
  `lib/src/render/scene_painter_frame.dart`

#### Dependency Direction

- `interactive/**` produces `SceneViewFramePreview` as a contract-owned value
  at frame-capture time
- `render/**` and `core/scene_snapshot_paint_candidates.dart` consume only the
  captured `SceneViewFramePreview`
- `SceneController.previewDeltaResolver` remains a public live read owned by
  `SceneController` and must not feed the frame-capture seam
- graph assembly must route `captureFramePreview:
  interactionRuntime.captureFramePreview` into render-state capture without
  reopening the public controller seam

#### State and Data Ownership

- `InteractiveMovePreviewState` continues to own live mutable move-preview
  state
- `SceneControllerInteractionRuntime` owns conversion from live preview state
  to a detached frame-owned `SceneViewFramePreview`
- `SceneViewFramePreview` owns the immutable per-node preview answers for one
  frame and exposes them only through captured read methods
- `SceneViewFrameRead` owns the lifetime of that frame preview for the whole
  main-scene paint pipeline

#### Entry and Exit Boundaries

- entry boundary:
  `ScenePainter.paint(...)` ->
  `SceneViewRenderState.captureFrameRead()` ->
  interaction-runtime preview capture ->
  `SceneViewFrameRead`
- internal read boundary:
  `preparePaintPlan(...)` and `resolveNodePaintData(...)` read preview data
  only from `frameRead.preview`
- exit boundary:
  main-scene paint outputs, selection accumulation, and culling decisions use
  one frame-owned preview snapshot; public controller preview reads and overlay
  preview reads remain separate live seams

#### Permitted Extension Seam

- future main-scene preview data may extend `SceneViewFramePreview` with new
  captured read methods or additional captured fields, but every new render
  consumer must still depend on the contract-owned frame object rather than on
  live callbacks
- future interactive preview capture logic may optimize internal storage inside
  `SceneViewFramePreview`, but the only supported render-facing API remains the
  frame-owned contract object

#### Rejected Alternatives

- keep `SceneViewRenderState.previewDeltaResolver` and cache its answers in
  selected call sites - rejected because the live seam remains available for
  future leakage
- capture a raw `Map<NodeId, Offset>` in multiple render owners - rejected
  because it duplicates frame-preview ownership across call sites instead of
  centralizing it in one contract object
- add a paint-time reentrancy guard around public controller mutations -
  rejected because it solves callback purity, not frame-authority correctness
- freeze geometry or selected supplements after admission but before paint -
  rejected because one frame would still have multiple preview authorities

#### Why This Level Is Correct

- the defect is not in image painting, node rendering, or supplement staging by
  themselves; it is the shared frame boundary that lets live preview state leak
  into two separate render consumers inside one paint pass
- `SceneViewFrameRead` is the declared atomic authority for the main-scene
  render pipeline, so the invariant must be repaired there and at the capture
  owner that populates it
- the repository already prefers detached immutable boundary objects for
  callback and read seams, so a contract-owned frame-preview value object is
  the dominant local form rather than a new architectural exception

### 4B. Architecture Decision Gate

Not needed. The inspected repository structure, current invariant claims, and
the requested bug-fix scope lock the owner, seam, and dependency direction.

## 5. Locked Decisions

1. `SceneViewFrameRead` carries only immutable frame-owned data and contract
   value objects; no `Function`, `Listenable`, or interactive-owner references
   remain inside it.
2. `SceneViewRenderState.previewDeltaResolver` is retired from the render/view
   seam; the public `SceneController.previewDeltaResolver` live getter remains
   supported and unchanged.
3. `SceneControllerGraphRequest.readPreviewDeltaResolver` is retired; frame
   preview capture is routed as `captureFramePreview` from interaction runtime
   into `SceneControllerSceneViewRenderState.captureFrameRead()`.
4. The successor `SceneViewFramePreview` answers the current move-preview use
   case with per-node `Offset` reads and `Offset.zero` fallback for nodes not
   present in the captured preview snapshot.
5. Both candidate-admission paths - committed fast path and snapshot-local
   fallback - must depend on the same `SceneViewFramePreview` API.
6. Overlay preview style and geometry capture remain live and out of scope for
   this step; only the main-scene `SceneViewFrameRead` contract changes here.

## 6. Result Requirements

1. A public side effect triggered during `imageResolver(...)` cannot change the
   preview seen by later nodes, supplement admission, or selection accumulation
   inside the same captured main-scene frame.
2. One `SceneViewFrameRead` is the single preview authority for the entire
   main-scene paint pass across committed fast-path admission, snapshot-local
   admission, late node resolution, and selection capture.
3. Public controller preview reads remain live outside frame capture and still
   reset immediately when interaction mode changes.
4. Structural tests fail if a live preview callback is reintroduced into
   `SceneViewFrameRead`, `SceneViewRenderState`, or the main-scene render
   consumers.
5. Repository docs and invariant text explicitly distinguish the public live
   preview seam from the frame-captured render seam.

## 7. Execution Order and Gates

### Required Order

- first, add one failing render reproducer for mid-frame preview invalidation
  and 1 to 3 neighboring guard tests for the same contract
- second, introduce `SceneViewFramePreview`, capture it at
  `captureFrameRead()`, and migrate all main-scene render consumers to it
- third, retire the live render seam from `SceneViewRenderState`,
  `SceneViewFrameRead`, and graph assembly after every in-repo consumer is on
  the successor seam
- fourth, update invariant coverage and docs only after the final seam and test
  surfaces are stable

### Successor Seam and Retirement Gates

- successor seam:
  `SceneViewFramePreview` stored inside `SceneViewFrameRead`
- consumer migration order:
  `InteractiveMovePreviewState` and `SceneControllerInteractionRuntime`
  capture preview ->
  `SceneControllerSceneViewRenderState.captureFrameRead()` ->
  `SceneControllerPaintCandidateStage` and
  `enumerateSnapshotPaintCandidates(...)` ->
  `ScenePainterFrameOwner.resolveNodePaintData(...)` ->
  in-repo render/test doubles and widget tests
- retirement gate:
  `SceneViewRenderState.previewDeltaResolver`,
  `SceneViewFrameRead.previewDeltaResolver`, and
  `SceneControllerGraphRequest.readPreviewDeltaResolver` may be removed only
  after every in-repo render consumer and test double compiles against
  `SceneViewFramePreview` and structural tests fail if those live seams return
  to the render contract
- registry and documentation gate:
  `tool/invariant_registry.dart`, `README.md`, `API_GUIDE.md`,
  `ARCHITECTURE.md`, and `CHANGELOG.md` must move to frozen frame-preview
  terminology before the step is marked complete

### Deferred Broad Verification

- full `required_code_change` execution is reserved for the final gate after
  contract, interactive capture, render consumers, tests, invariant registry,
  and docs are all updated
- broad widget/render test runs beyond the named proof files are reserved for
  the final gate and should remain sequential with the required preset

## 8. File Map

### Implementation Files

- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/interactive/internal/scene_controller_graph.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart`
- `lib/src/interactive/internal/interactive_move_session.dart`
- `lib/src/interactive/internal/interactive_move_preview_state.dart`
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart`
- `lib/src/core/scene_snapshot_paint_candidates.dart`
- `lib/src/render/scene_painter_frame.dart`

### Test Files

- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/support/committed_scene_view_read_state.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/view/scene_view_test.dart`
- `test/tool/bench_run_load_profiles_test.dart`
- `tool/bench/load_profiles_cases_test.dart`

### Fixtures and Supporting Data

- existing render pixel helpers and image fixtures inside
  `test/render/scene_painter_test.dart`
- existing `SceneViewRenderState` test doubles in
  `test/support/committed_scene_view_read_state.dart` and
  `test/view/scene_view_interactive_test.dart`
- existing benchmark render-state implementation in
  `tool/bench/load_profiles_cases_test.dart`

### Registry, Inventory, and Workflow Files

- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Analysis Area

- `lib/src/contract/**`
- `lib/src/interactive/**`
- `lib/src/render/**`
- `lib/src/core/scene_snapshot_paint_candidates.dart`
- `test/render/**`
- `test/view/**`
- `tool/bench/**`
- `tool/invariant_registry.dart`
- repository docs listed above

## 9. Implementation Rules

### Protected Invariants

- the main-scene render pipeline paints from one atomic frame read and one
  frame-owned preview authority
- the render layer stays read-only; correctness must not depend on mutating or
  policing app callbacks during paint
- the public `SceneController.previewDeltaResolver` live read remains distinct
  from the captured frame seam
- committed fast-path candidate admission and snapshot-local fallback must stay
  preview-consistent with late node resolution
- overlay repaint ownership remains separate from main-scene frame capture

### Required Proof

- behavioral proof:
  add one failing repro that uses a reentrant `imageResolver(...)` callback to
  clear move preview mid-paint and proves late selected nodes still render from
  the preview captured at frame start; add 1 to 3 guard tests covering live
  public preview reset after `setMode(...)`, committed fast-path preview
  supplement parity, and snapshot-local preview admission parity
- structural proof:
  add source-level render contract tests that fail if
  `SceneViewFrameRead` or `SceneViewRenderState` reintroduce a live preview
  callback, and fail if `scene_controller_scene_view_runtime.dart` or
  `scene_painter_frame.dart` bypass the successor `SceneViewFramePreview` seam
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing
  characterization tests must be added before structural edits, plus 1 to 3
  guard tests for neighboring branches when needed

### Allowed Change Surface

- the `SceneViewFrameRead` contract and its companion frame-preview value
  object
- interaction-runtime capture plumbing needed to materialize frame preview data
- graph assembly and controller wiring needed to retire the live render seam
- committed fast-path, snapshot-local, and late node-resolution render
  consumers
- in-repo test doubles, invariant registry entries, and required docs

### Forbidden Moves

- no new render-time prohibition on `imageResolver(...)` calling public
  controller APIs
- no partial freeze that leaves one main-scene render consumer on a live
  preview seam
- no open interface or callback-based replacement for `SceneViewFramePreview`
- no duplicate ad hoc preview snapshots built independently in candidate
  staging and late node resolution
- no public API export of `SceneViewFrameRead` internals beyond current
  supported package surfaces

### Optional: Recognition Forms That Must Be Supported

- a frame-preview object that returns captured `Offset.zero` for nodes outside
  the captured preview set
- preview consumers reading one frame-owned object from both the committed
  fast-path and the snapshot-local fallback

### Optional: Allowed Forms That Are Not Violations

- the public `SceneController.previewDeltaResolver` staying live is allowed
  because it is not the `SceneViewFrameRead` seam
- overlay painter reads of line/stroke/marquee preview state are allowed
  because they do not flow through `SceneViewFrameRead`

### Optional: Resolution Rules

- `SceneViewFramePreview.deltaForNode(nodeId)` returns a sanitized finite
  `Offset` and falls back to `Offset.zero`
- frame preview capture happens exactly once per `captureFrameRead()` before
  paint-plan preparation or late node resolution begins

## 10. Vertical Slices

### Slice 1. [x] Lock Mid-Frame Preview Invalidation at the Render Boundary

#### Slice Contract

Add a failing end-to-end render reproducer for reentrant mid-frame preview
invalidation and the minimum neighboring guard coverage needed to lock the
current contract before changing owner-side implementation.

#### Change

- add a reentrant `imageResolver(...)` repro in `test/render/scene_painter_test.dart`
  that enters move preview, invalidates it through `setMode(...)` during image
  painting, and proves the current frame must still paint late selected nodes
  from the preview captured at frame start
- add neighboring guard tests in
  `test/render/scene_painter_frame_contract_test.dart` and
  `test/contract/runtime_contract_interfaces_test.dart` for frame-preview
  parity and for the intentionally live public controller preview seam

#### Behavioral Verification

- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/contract/runtime_contract_interfaces_test.dart`
- `flutter test test/render/scene_static_layer_cache_test.dart`
- `flutter test test/view/scene_view_test.dart`

#### Structural Verification

- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/tool/bench_run_load_profiles_test.dart`

#### Fixtures Used

- existing render pixel helpers and `TestRecordingCanvas`
- real `SceneController` interaction flow for move preview

#### Positive Scenarios

- public controller preview still resets to zero after `setMode(...)`
- previewed selected nodes remain paint-visible on both candidate-enumeration
  paths once the owner fix lands

#### Negative Scenarios

- a reentrant `imageResolver(...)` mode change must not make later nodes in the
  same frame read `Offset.zero` preview
- one frame must not mix previewed and non-previewed selected geometry

#### Closure Evidence

- the new repro fails against the live render seam before implementation and
  becomes green once the frame-owned snapshot seam is in place

### Slice 2. [x] Replace the Live Render Preview Seam with SceneViewFramePreview

#### Slice Contract

Introduce the frame-owned preview value object, capture it exactly once at
`captureFrameRead()`, migrate every main-scene render consumer to that object,
and retire the live preview seam from the render contract.

#### Change

- add `SceneViewFramePreview` and replace
  `SceneViewFrameRead.previewDeltaResolver` in
  `lib/src/contract/scene_view_render_state.dart`
- add interaction-runtime-owned frame-preview capture in
  `InteractiveMovePreviewState`,
  `SceneControllerInteractionRuntime`, and
  `SceneControllerSceneViewRenderState.captureFrameRead()`
- retire `SceneViewRenderState.previewDeltaResolver` and
  `SceneControllerGraphRequest.readPreviewDeltaResolver`
- replace the internal constructor seam with `captureFramePreview` for
  production wiring, benchmarks, and in-repo test doubles
- migrate `SceneControllerPaintCandidateStage`,
  `enumerateSnapshotPaintCandidates(...)`, and
  `ScenePainterFrameOwner.resolveNodePaintData(...)` to
  `SceneViewFramePreview`
- update in-repo render/test doubles, widget test support, and benchmark
  render-state support to the successor seam

#### Behavioral Verification

- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/contract/runtime_contract_interfaces_test.dart`
- `flutter test test/render/scene_static_layer_cache_test.dart`
- `flutter test test/view/scene_view_test.dart`
- `flutter test test/view/scene_view_interactive_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart --plain-name 'load profile background-layer-paint profile=smoke'`

#### Structural Verification

- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/tool/bench_run_load_profiles_test.dart`

#### Fixtures Used

- `test/support/committed_scene_view_read_state.dart`
- fake render-state implementations in render and view tests

#### Positive Scenarios

- captured frame preview survives live preview invalidation during
  `imageResolver(...)`
- committed fast-path admission and snapshot-local fallback use the same
  frame-owned preview answers
- late node resolution, culling, and selection capture agree on one preview
  snapshot

#### Negative Scenarios

- no main-scene render consumer can read preview from a live callback after the
  seam migration
- no in-repo `SceneViewRenderState` implementation still depends on a live
  preview getter

#### Closure Evidence

- render behavior tests are green, the live render seam is retired, and the
  structural render tests fail if a live callback returns to the frame seam

### Slice 3. [x] Sync Invariants and Documentation to Frozen Frame Semantics

#### Slice Contract

Update the invariant registry and release-ready docs so the repository states
the final frozen frame-preview model explicitly and points at the correct proof
surfaces.

#### Change

- extend `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` in
  `tool/invariant_registry.dart` to mention frame-frozen preview semantics and
  point at the final behavioral plus structural proof surfaces
- update `README.md`, `API_GUIDE.md`, and `ARCHITECTURE.md` to distinguish the
  public live preview seam from the frame-captured render seam
- add an `Unreleased` fix entry to `CHANGELOG.md`

#### Behavioral Verification

- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`

#### Structural Verification

- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- existing invariant proof surfaces named above

#### Positive Scenarios

- repository docs describe one frozen frame-preview authority for main-scene
  paint
- invariant coverage points at the final proof surfaces for that contract

#### Negative Scenarios

- no doc text still implies that a live preview resolver is part of the atomic
  frame read

#### Closure Evidence

- invariant coverage is green and every release-ready doc names the final seam
  correctly

## 11. Final Verification

- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_static_layer_cache_test.dart`
- `flutter test test/contract/runtime_contract_interfaces_test.dart`
- `flutter test test/view/scene_view_test.dart`
- `flutter test test/view/scene_view_interactive_test.dart`
- `flutter test test/tool/bench_run_load_profiles_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart --plain-name 'load profile background-layer-paint profile=smoke'`
- `dart run tool/check_invariant_coverage.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_4_render_frame_preview_snapshot_boundary.md' 'lib/src/contract/scene_view_render_state.dart' 'lib/src/interactive/scene_controller.dart' 'lib/src/interactive/internal/scene_controller_graph.dart' 'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart' 'lib/src/interactive/internal/scene_controller_interaction_runtime.dart' 'lib/src/interactive/internal/interactive_move_session.dart' 'lib/src/interactive/internal/interactive_move_preview_state.dart' 'lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart' 'lib/src/core/scene_snapshot_paint_candidates.dart' 'lib/src/render/scene_painter_frame.dart' 'test/render/scene_painter_test.dart' 'test/render/scene_painter_frame_contract_test.dart' 'test/render/scene_painter_bounds_contract_test.dart' 'test/render/scene_static_layer_cache_test.dart' 'test/contract/runtime_contract_interfaces_test.dart' 'test/support/committed_scene_view_read_state.dart' 'test/view/scene_view_test.dart' 'test/view/scene_view_interactive_test.dart' 'test/tool/bench_run_load_profiles_test.dart' 'tool/bench/load_profiles_cases_test.dart' 'tool/invariant_registry.dart' 'README.md' 'API_GUIDE.md' 'ARCHITECTURE.md' 'CHANGELOG.md' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- main-scene rendering uses only a frame-owned preview snapshot after
  `captureFrameRead()` and cannot observe live preview changes mid-frame
- committed fast-path admission, snapshot-local admission, and late node
  resolution agree on one preview authority inside the same frame
- the public `SceneController.previewDeltaResolver` remains live and distinct
  from the frame-captured render seam
- structural render tests fail if a live preview callback is reintroduced into
  `SceneViewFrameRead`, `SceneViewRenderState`, or the main-scene render
  consumers
- invariant coverage, docs, and changelog all describe the frozen frame-preview
  model and the final proof surfaces
