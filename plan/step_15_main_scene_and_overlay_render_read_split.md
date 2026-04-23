# Change Contract

## 1. Change Mandate

Split the mixed controller-owned render seam into separate main-scene and
overlay read contracts behind `SceneViewRuntime`, migrate every consumer to the
correct read side, and retire the legacy `SceneViewRenderState` seam.

## 2. Change Boundary

### Included in the Change

- replace `SceneViewRuntime.renderState` and the mixed
  `SceneViewRenderState` contract with one main-scene read seam and one
  overlay-preview read seam
- keep one assembled `SceneViewRuntime` boundary while splitting the concrete
  controller-owned read implementation inside
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- migrate `SceneViewRuntimeHost`, `SceneViewRenderSurface`,
  `SceneViewInteractiveOverlayPainter`, `ScenePainter`,
  `ScenePainterFrameOwner`, and `SceneController` to the correct successor seam
- migrate in-repo render-state fixtures, benchmark-owned render-state support,
  guardrail sandbox support, and structural guardrail cases away from the
  legacy mixed seam
- update structural proof so the view shell cannot recombine the split seam by
  routing a broad render-state contract through `view/**` or by letting
  controller/store owners implement the full scene-view read family
- update `ARCHITECTURE.md` and `tool/invariant_registry.dart` so the checked-in
  architecture describes the split read boundary and its final proof surfaces

### Not Included in the Change

- no composition-root or facade compression work from the composition family
- no mutation-gateway narrowing, interaction-family compression, or store-facade
  cleanup
- no change to `SceneViewFrameRead` / `SceneViewFramePreview` frozen-frame
  semantics from Step 4 beyond moving them under the narrowed main-scene read
  seam
- no change to pointer-session ownership, runtime swap order, or pointer-host
  lifecycle
- no public barrel export changes and no public `SceneController` API additions
- no ADR or target-architecture updates; ADR 0001 plus the target flow/family
  docs already lock the owner-level split and consumer direction, while this
  step locks the exact checked-in successor seam locally
- no `README.md`, `API_GUIDE.md`, or `CHANGELOG.md` update because this step
  changes checked-in internal architecture, not public package behavior

## 3. Surrounding Code Review

### Inspected Artifacts

- `PLAN.md` - the active plan index requires a dedicated step document for each
  new execution contract
- `docs/adr/0001_target_engine_architecture.md` - locks one
  `SceneViewRuntime` boundary with separate main-scene and overlay read roles
- `docs/adr/0002_post_target_optimization_scope.md` - makes the render-seam
  split the first required primary cut before phase-2 compression work
- `docs/target_architecture/families/view_runtime_and_render_seam.md` - fixes
  the local target shape, owner inventory, and concrete files for the split
- `lib/src/contract/scene_view_runtime.dart` - the runtime boundary still
  exposes one `renderState` getter
- `lib/src/contract/scene_view_render_state.dart` - one interface still mixes
  `captureFrameRead()` / `preparePaintPlan(...)` with overlay repaint and live
  preview getters
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` -
  `SceneControllerSceneViewRuntime` and
  `SceneControllerSceneViewRenderState` still centralize both read roles in one
  owner
- `lib/src/view/scene_view_runtime_host.dart` - the host still reads one
  `_activeRuntime.renderState` value and forwards it to both view consumers
- `lib/src/view/scene_view_render_surface.dart` - the main-scene render
  surface is typed to `SceneViewRenderState` even though it only needs the
  main-scene read path
- `lib/src/view/scene_view_interactive_overlay_painter.dart` - the overlay
  painter is typed to the same mixed contract even though it only consumes live
  overlay state
- `lib/src/render/scene_painter.dart` and `lib/src/render/scene_painter_frame.dart`
  - the render layer only uses frame-capture and paint-plan APIs from the mixed
  seam
- `lib/src/interactive/scene_controller.dart` - public selection and overlay
  preview getters still route through the mixed read seam
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` -
  current structural proof locks `SceneViewRuntime.renderState` and host wiring
  to a single mixed contract
- `test/interactive/core/scene_controller_public_listener_contract_test.dart` -
  runtime repaint and public-listener behavior are already locked around split
  scene and overlay repaint channels
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
  - move-preview scene-repaint invariants still read through
  `sceneControllerViewRuntimeOf(controller).renderState` on move, interrupt,
  and detach paths
- `test/contract/runtime_contract_interfaces_test.dart` - current runtime
  contract proof still asserts one mixed `SceneViewRenderState`
- `test/render/scene_painter_test.dart`,
  `test/render/scene_painter_frame_contract_test.dart`,
  `test/render/scene_static_layer_cache_test.dart`,
  `test/view/scene_view_test.dart`, and
  `test/view/scene_view_interactive_test.dart` - existing render/view behavior
  suites consume the current seam directly or through local runtime stubs
- `test/support/committed_scene_view_render_state.dart` - in-repo fixture still
  implements the mixed contract
- `tool/bench/load_profiles_cases_test.dart` and
  `test/tool/bench_run_load_profiles_test.dart` - benchmark-owned production
  render-state wiring still uses the mixed contract and has source-level proof
  over that wiring
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_facade_rules.dart`
  - still rejects `SceneController` implementing `SceneViewRenderState`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart`
  - still requires `SceneControllerSceneViewRenderState` to implement
  `SceneViewRenderState`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_view_surface_rules.dart`
  and
  `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_view_host_rules.dart`
  - still guard the mixed render-state parameter and host property chain
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` and
  `test/tool/guardrails/guardrails_controller_api_tool_test.dart` - still treat
  `SceneViewRenderState` as the full controller-forbidden read seam
- `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`,
  `view_runtime_host_cases.dart`, `view_surface_and_runtime_cases.dart`,
  `runtime_and_draw_ownership_cases.dart`,
  `owner_and_mutation_boundary_cases.dart`, and
  `pointer_host_and_public_shell_cases.dart` - guardrail case fixtures still
  encode the mixed seam
- `test/tool/support/guardrails_sandbox_support.dart` - shared guardrail
  sandbox scaffold still defines `SceneViewRuntime.renderState` and
  `SceneViewRenderState`
- `ARCHITECTURE.md` - the checked-in architecture still documents
  `SceneControllerSceneViewRenderState` as one assembled read-side state used by
  both the main render surface and the overlay
- `tool/invariant_registry.dart` - `INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY`
  and `INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE` still describe the old
  mixed seam

### Current Entry Path

- `SceneViewInteractive.build()` -> `SceneViewRuntimeHost.build()` ->
  `_activeRuntime.renderState` -> `SceneViewRenderSurface` and
  `SceneViewInteractiveOverlayPainter`
- `SceneViewRenderSurface` -> `ScenePainter.paint()` ->
  `SceneViewRenderState.captureFrameRead()` ->
  `ScenePainterFrameOwner.createPrepared()` ->
  `SceneViewRenderState.preparePaintPlan(...)`
- `SceneViewInteractiveOverlayPainter.paint()` ->
  `SceneViewRenderState.cameraOffset` / `selectionRect` /
  `activeStrokePreview*` / `activeLinePreview*`
- `SceneController.selectionRect` / `cameraOffset` / overlay preview getters ->
  `_graph.sceneViewRuntime.renderState`

### Current Owner

- contract owner of the mixed seam:
  `lib/src/contract/scene_view_render_state.dart`
- runtime implementation owner of the mixed seam:
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- view-shell consumers of the seam:
  `lib/src/view/scene_view_runtime_host.dart`,
  `lib/src/view/scene_view_render_surface.dart`, and
  `lib/src/view/scene_view_interactive_overlay_painter.dart`
- render-layer consumers of the main-scene portion:
  `lib/src/render/scene_painter.dart` and
  `lib/src/render/scene_painter_frame.dart`
- public facade consumer of the overlay portion:
  `lib/src/interactive/scene_controller.dart`

### Adjacent Abstractions

- `lib/src/contract/scene_render_state.dart` - the narrower committed
  read-side contract already used by the render surface path
- `SceneViewFrameRead`, `SceneViewFramePreview`, and
  `ScenePreparedPaintPlan` in `lib/src/contract/scene_view_render_state.dart` -
  the main-scene frame-capture support objects that must stay on the
  main-scene read side
- `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart` -
  committed fast-path paint-plan support owner adjacent to the main-scene seam
- `lib/src/interactive/scene_controller_interaction.dart` - public source of
  live selection and draw-preview state adjacent to the overlay seam, but not
  the view boundary owner
- `lib/src/controller/scene_store_controller.dart` - the committed read owner
  adjacent to the main-scene seam, but intentionally narrower than the full
  interactive view-runtime family

### Existing Tests

- `test/contract/runtime_contract_interfaces_test.dart` - locks the assembled
  runtime boundary and the current mixed read contract shape
- `test/render/scene_painter_test.dart` - locks main-scene rendering behavior
  and scene-painter integration against controller-owned and mirrored render
  reads
- `test/render/scene_painter_frame_contract_test.dart` - locks atomic
  frame-read usage, paint-plan preparation, and frame-owner resolution
- `test/render/scene_static_layer_cache_test.dart` - locks render-surface cache
  lifecycle through a mirror render-state implementation
- `test/view/scene_view_test.dart` - locks render-surface widget behavior and
  debug probes through a mirror render-state implementation
- `test/view/scene_view_interactive_test.dart` - locks runtime-host behavior,
  overlay painter behavior, and local runtime stubs around the mixed seam
- `test/interactive/core/scene_controller_public_listener_contract_test.dart` -
  locks public notification behavior against split scene and overlay repaint
  channels
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
  - locks move-preview scene-repaint behavior through the current runtime read
  seam across move, interrupt, and detached-session paths
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` -
  locks the current architecture boundary and runtime-host property chain
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` - locks the
  interactive architecture guardrails through negative structural scenarios
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` - locks the
  controller-side prohibition on implementing the full scene-view read seam
- `test/tool/bench_run_load_profiles_test.dart` - locks benchmark source
  wiring so performance cases keep using production render owners

### Analogous Implementation Path

- `lib/src/contract/scene_render_state.dart` plus
  `lib/src/controller/scene_store_controller.dart` - the repository already
  keeps a narrower main-scene read surface on a separate contract, which is
  the closest checked-in precedent for shrinking a broader read seam even
  though it is not itself a split `SceneViewRuntime` boundary
- `SceneViewFrameRead` and `SceneViewFramePreview` in
  `lib/src/contract/scene_view_render_state.dart` - the same family already
  treats frame-authoritative main-scene data as a distinct seam from live
  overlay state
- `lib/src/interactive/internal/interactive_draw_gesture_session.dart` and
  `lib/src/interactive/internal/interactive_draw_coordinator.dart` - the
  repository already keeps live overlay-style draw preview data on an
  interaction-owned path that stays separate from main-scene frame reads

### Governing Repository Rules

- `docs/adr/0001_target_engine_architecture.md` - the accepted target keeps one
  `SceneViewRuntime` boundary while requiring separate main-scene and overlay
  read contracts or facets
- `docs/target_architecture/families/view_runtime_and_render_seam.md` - the
  runtime family stays controller-owned, the main-scene render surface consumes
  only the main-scene read, and the overlay painter consumes only the overlay
  read
- repository instructions - fix the shared owner of the invariant instead of
  patching one downstream call site
- repository instructions - important invariants must be mechanically enforced
  with tests or tooling, not prose only
- `ARCHITECTURE.md` - the render layer is read-only and the view shell reaches
  the engine only through `SceneViewRuntime`
- repository verification rule - final code-change verification must run the
  `required_code_change` preset with the actual changed-path list; Section 11
  records the exact final command for this step

### Rejected Misleading Local Patterns

- keep `SceneViewRuntime.renderState` and hide the split behind one family
  wrapper - wrong seam because the view shell would still transport one broad
  mixed type to both consumers and structural drift would stay hard to catch
- add view-local adapters that derive the split from `SceneController` or
  `SceneControllerInteraction` - wrong owner because the view shell must
  consume the assembled runtime boundary instead of reconstructing ownership
- push the main-scene render contract down into `SceneStoreController` - wrong
  level because committed-store reads do not own frame capture or paint-plan
  preparation
- let the overlay painter depend on `SceneControllerInteraction` directly -
  wrong boundary because it bypasses `SceneViewRuntime` and reopens a concrete
  controller seam in `view/**`
- keep `SceneViewRenderState` as a typedef or deprecated alias after migration -
  wrong retirement shape because it preserves the same mixed-owner escape hatch

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- the controller-owned view/runtime seam between one assembled
  `SceneViewRuntime` boundary and two distinct downstream read consumers

#### Selected Architectural Form

- define two successor contract interfaces in
  `lib/src/contract/scene_view_render_state.dart`:
  `SceneViewMainSceneRenderRead` and `SceneViewOverlayPreviewRead`
- `SceneViewMainSceneRenderRead` extends `SceneRenderState` and owns
  `controllerEpoch`, `captureFrameRead()`, and `preparePaintPlan(...)`
- `SceneViewOverlayPreviewRead` owns `overlayRepaintListenable`,
  `cameraOffset`, `selectionRect`, and the live stroke/line preview getters
- `SceneViewRuntime` exposes `mainSceneRenderRead` and `overlayPreviewRead`;
  the runtime boundary does not retain a `renderState` getter
- `SceneControllerSceneViewRuntime` remains one assembled runtime boundary and
  one pointer-session factory, but internally owns one concrete main-scene read
  owner and one concrete overlay-preview read owner
- `SceneViewRuntimeHost` remains the only view-shell owner that touches both
  reads and routes them separately:
  `mainSceneRenderRead` to `SceneViewRenderSurface` and
  `overlayPreviewRead` to `SceneViewInteractiveOverlayPainter`
- `SceneController` public selection and overlay preview getters route only
  through the overlay-preview read seam; render-layer consumers route only
  through the main-scene read seam

#### Owning Layer or Module

- contract layer:
  `lib/src/contract/scene_view_runtime.dart` and
  `lib/src/contract/scene_view_render_state.dart`
- controller-owned runtime implementation:
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- view-shell consumers:
  `lib/src/view/scene_view_runtime_host.dart`,
  `lib/src/view/scene_view_render_surface.dart`, and
  `lib/src/view/scene_view_interactive_overlay_painter.dart`
- render-layer consumers:
  `lib/src/render/scene_painter.dart` and
  `lib/src/render/scene_painter_frame.dart`
- public facade bridge:
  `lib/src/interactive/scene_controller.dart`

#### Dependency Direction

- no layer-DAG change is introduced by this step; `view/**` keeps its existing
  dependencies on `render/**`, `interactive/**`, `core/**`, and `contract/**`
  while consuming the runtime/render seam only through `SceneViewRuntime` plus
  the successor read contracts
- `render/**` continues to depend on `contract/**` and `core/**`; its
  scene-view seam narrows from the mixed `SceneViewRenderState` contract to
  `SceneViewMainSceneRenderRead`
- `interactive/internal/**` implements the successor read interfaces and
  assembles them under `SceneViewRuntime`
- `SceneController` continues to depend on `SceneViewRuntime` and the
  overlay-preview read contract as boundary types only; it does not depend on a
  concrete runtime implementation
- controller guardrails keep `SceneStoreController` and `SceneController` out
  of the full scene-view read family

#### State and Data Ownership

- the main-scene read side owns scene repaint listening, controller epoch,
  frame capture, and paint-plan preparation
- the overlay-preview read side owns overlay repaint listening, camera offset,
  marquee selection, and live draw-preview reads
- `SceneViewFrameRead`, `SceneViewFramePreview`, and
  `ScenePreparedPaintPlan` remain main-scene read support objects only
- live preview and marquee data remain interaction-owned; the overlay read side
  exposes them but does not own their lifecycle

#### Entry and Exit Boundaries

- entry boundary:
  `SceneViewRuntimeHost.build()` reads
  `_activeRuntime.mainSceneRenderRead` and
  `_activeRuntime.overlayPreviewRead`
- main-scene exit boundary:
  `SceneViewRenderSurface` and the render layer accept only
  `SceneViewMainSceneRenderRead`
- overlay exit boundary:
  `SceneViewInteractiveOverlayPainter` and `SceneController` preview getters
  accept only `SceneViewOverlayPreviewRead`

#### Permitted Extension Seam

- new frame-authoritative render APIs may extend only
  `SceneViewMainSceneRenderRead`, `SceneViewFrameRead`, or
  `ScenePreparedPaintPlan`
- new live marquee, stroke, or line preview APIs may extend only
  `SceneViewOverlayPreviewRead`
- `SceneViewRuntime` remains the only owner allowed to hand both read seams to
  the view shell at once

#### Rejected Alternatives

- keep one `SceneViewRenderState` and add facet getters on top of it - rejected
  because the same broad transport type would still cross the view boundary and
  weaken structural enforcement
- split the seam only with view-local helper adapters - rejected because the
  view shell would reassemble engine ownership locally
- expose `SceneControllerInteraction` or `SceneStoreController` directly to the
  view shell - rejected because it bypasses `SceneViewRuntime` and crosses the
  wrong layer boundary

#### Why This Level Is Correct

- the hot spot is already centralized in one controller-owned runtime boundary
  and two downstream consumers, so the split can land once without duplicating
  policy
- the render layer already uses only the main-scene subset of the current
  contract, and the overlay painter already uses only the overlay subset, so
  the split matches current behavior instead of inventing new runtime roles
- `SceneViewRuntime` and `SceneViewRenderState` are not public package exports,
  so the successor seam can be explicit without creating a public API break

## 5. Locked Decisions

1. The successor contract names are fixed as
   `SceneViewMainSceneRenderRead`,
   `SceneViewOverlayPreviewRead`,
   `SceneViewRuntime.mainSceneRenderRead`, and
   `SceneViewRuntime.overlayPreviewRead`.
2. `SceneViewRenderSurface` and its constructor parameter move to the
   `mainSceneRenderRead` name; `SceneViewInteractiveOverlayPainter` and its
   constructor parameter move to the `overlayPreviewRead` name.
3. `SceneViewMainSceneRenderRead` is the only scene-view read contract allowed
   to extend `SceneRenderState`; `SceneViewOverlayPreviewRead` does not extend
   `Listenable` and keeps overlay invalidation explicit through
   `overlayRepaintListenable`.
4. `SceneControllerSceneViewRuntime` stays in one file and one top-level runtime
   class; the split happens by introducing concrete read owners inside the same
   runtime family, not by creating a second peer runtime.
5. `SceneController` routes `selectionRect`, `cameraOffset`, and live
   stroke/line preview getters only through `SceneViewOverlayPreviewRead`;
   `previewDeltaResolver` stays on the interaction/graph path and is outside
   this step.
6. Test-only and benchmark-only fixtures may implement both successor
   interfaces in one class if a single fixture needs both read shapes, but
   production `lib/src/view/**`, `lib/src/render/**`, and
   `lib/src/interactive/**` must type against the specific successor interface
   they consume.
7. The legacy `SceneViewRenderState` and `SceneViewRuntime.renderState` seam is
   retired in this step after all production consumers, guardrails, benchmark
   scaffolds, and fixtures migrate.

## 6. Result Requirements

1. Production main-scene rendering compiles only against
   `SceneViewMainSceneRenderRead`; `SceneViewRenderSurface`,
   `ScenePainter`, and `ScenePainterFrameOwner` cannot reach overlay-preview
   getters.
2. Production overlay rendering and public controller overlay/selection getters
   compile only against `SceneViewOverlayPreviewRead`; they cannot reach
   `captureFrameRead()` or `preparePaintPlan(...)`.
3. `SceneViewRuntimeHost` remains the only owner that reads both successor
   seams and routes them from the active runtime.
4. `SceneControllerSceneViewRuntime` remains one assembled `SceneViewRuntime`
   boundary and one pointer-session owner after the split.
5. No checked-in production, fixture, benchmark, or guardrail file still
   depends on `SceneViewRenderState` or `SceneViewRuntime.renderState` after the
   step closes.

## 7. Execution Order and Gates

### Required Order

- first, add or update characterization tests and structural checks so the
  current render, overlay, runtime-host, and controller behavior is locked
  before the seam changes
- second, introduce the successor read contracts and migrate every compile-time
  consumer that must understand those new names in the same slice: production
  view/render consumers, runtime-host wiring, fixtures, benchmark-owned
  render-state support, guardrail sandbox scaffolds, and controller/interactive
  structural checks
- third, split the controller-owned runtime implementation, migrate the public
  facade to the narrowed overlay seam, and retire the legacy mixed seam
- fourth, update invariant and architecture source-of-truth artifacts once the
  final code path and proof surfaces are in place

### Successor Seam and Retirement Gates

- `SceneViewMainSceneRenderRead` and `SceneViewOverlayPreviewRead` succeed
  `SceneViewRenderState`; `mainSceneRenderRead` and `overlayPreviewRead`
  succeed `renderState`
- the legacy mixed seam must not be deleted until these move to the successor
  seam:
  `SceneViewRuntimeHost`, `SceneViewRenderSurface`,
  `SceneViewInteractiveOverlayPainter`, `ScenePainter`,
  `ScenePainterFrameOwner`, `SceneController`,
  `SceneControllerSceneViewRuntime`,
  `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`,
  `test/support/committed_scene_view_render_state.dart`,
  the local runtime stubs in `test/view/scene_view_interactive_test.dart`,
  `tool/bench/load_profiles_cases_test.dart`,
  `test/tool/support/guardrails_sandbox_support.dart`,
  the interactive/controller guardrail rules, and the guardrail case fixtures
- `tool/invariant_registry.dart` and `ARCHITECTURE.md` update only after the
  legacy seam is gone and the final proof surfaces are already green

### Deferred Broad Verification

- reserve the Section 11 `required_code_change` preset command for the final
  gate after the legacy seam is retired
- reserve `dart run tool/check_guardrails.dart` for the final gate because it
  aggregates the full guardrail surface and is broader than the slice-local
  targeted tool suites

## 8. File Map

### Implementation Files

- `lib/src/contract/scene_view_runtime.dart`
- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/interactive/scene_controller.dart`
- `lib/src/view/scene_view_runtime_host.dart`
- `lib/src/view/scene_view_render_surface.dart`
- `lib/src/view/scene_view_interactive_overlay_painter.dart`
- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_frame.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_facade_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_view_surface_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_view_host_rules.dart`
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`

### Test Files

- `test/contract/runtime_contract_interfaces_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_static_layer_cache_test.dart`
- `test/view/scene_view_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/interactive/core/scene_controller_public_listener_contract_test.dart`
- `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/view_runtime_host_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/view_surface_and_runtime_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/owner_and_mutation_boundary_cases.dart`
- `test/tool/guardrails/interactive_api/architecture_boundary/pointer_host_and_public_shell_cases.dart`
- `test/tool/bench_run_load_profiles_test.dart`
- `tool/bench/load_profiles_cases_test.dart`

### Fixtures and Supporting Data

- `test/support/committed_scene_view_render_state.dart`
- `test/tool/support/guardrails_sandbox_support.dart`

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_15_main_scene_and_overlay_render_read_split.md`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `tool/run_tool_tests.dart`
- `tool/check_guardrails.dart`
- `tool/check_invariant_coverage.dart`
- `tool/run_verification_preset.dart`

### Analysis Area

- `lib/src/contract/**`
- `lib/src/interactive/internal/**`
- `lib/src/view/**`
- `lib/src/render/**`
- `tool/src/guardrails/rules/**`
- `test/tool/guardrails/**`

## 9. Implementation Rules

### Protected Invariants

- `SceneViewRuntime` remains the only view-facing bridge into interactive
  internals
- main-scene rendering stays frame-authoritative and read-only
- overlay repaint ownership stays outside the render surface and remains live
- `SceneStoreController` remains committed-store-only on the read side and does
  not implement either successor scene-view read contract
- `SceneController` remains a facade and does not implement either successor
  scene-view read contract

### Required Proof

- behavioral proof:
  `test/contract/runtime_contract_interfaces_test.dart`,
  `test/render/scene_painter_test.dart`,
  `test/render/scene_painter_frame_contract_test.dart`,
  `test/render/scene_static_layer_cache_test.dart`,
  `test/view/scene_view_test.dart`,
  `test/view/scene_view_interactive_test.dart`, and
  `test/interactive/core/scene_controller_public_listener_contract_test.dart`,
  `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
  must stay green across the seam split
- structural proof:
  `test/interactive/core/scene_controller_architecture_boundary_test.dart`,
  `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`,
  `test/tool/guardrails/guardrails_controller_api_tool_test.dart`,
  `test/tool/bench_run_load_profiles_test.dart`, and
  `dart run tool/check_invariant_coverage.dart`
  must make future drift in the split seam mechanically visible
- for refactors: the existing locking tests above must be kept green or
  extended before the minimal structural edit set widens

### Allowed Change Surface

- change only the files listed in Section 8
- keep the split seam inside the existing contract and runtime owner files;
  this step must not create a second runtime family or a new public export
- new helper types are allowed only inside the existing contract/runtime files
  when they preserve those files as the clear owners of the seam

### Forbidden Moves

- no view-local adapter that reconstructs the split seam from `SceneController`,
  `SceneControllerInteraction`, or `SceneStoreController`
- no compatibility alias, deprecated wrapper, or fallback getter that keeps the
  legacy `renderState` seam alive after Slice 2
- no move of frame-capture or paint-plan APIs onto the overlay seam
- no move of live overlay preview getters onto the main-scene render seam
- no ADR or target-architecture edits as part of this step

### Optional: Allowed Forms That Are Not Violations

- a test-only or benchmark-only fixture may implement both successor read
  interfaces in one class when one fixture intentionally models both read
  shapes for local verification

## 10. Vertical Slices

### Slice 1. [ ] Introduce Explicit Read Contracts and Migrate Compile-Time Consumers

#### Slice Contract

Introduce the successor read contracts and migrate every compile-time consumer,
fixture, benchmark seam, and structural guardrail that must understand those
contracts before the runtime implementation itself is split.

#### Change

- add `SceneViewMainSceneRenderRead` and `SceneViewOverlayPreviewRead` in
  `lib/src/contract/scene_view_render_state.dart`
- add `mainSceneRenderRead` and `overlayPreviewRead` to
  `lib/src/contract/scene_view_runtime.dart`
- migrate `SceneViewRuntimeHost`, `SceneViewRenderSurface`,
  `SceneViewInteractiveOverlayPainter`, `ScenePainter`, and
  `ScenePainterFrameOwner` to the explicit successor types and seam names
- migrate `test/support/committed_scene_view_render_state.dart`,
  `test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`,
  `tool/bench/load_profiles_cases_test.dart`,
  `test/tool/support/guardrails_sandbox_support.dart`, and the affected
  guardrail case fixtures to the successor seam while the legacy mixed seam
  still exists as a temporary bridge for the next slice
- update interactive and controller guardrail rules plus their targeted tool
  suites so the new successor contracts are already protected before the legacy
  seam is retired
- update render/view tests and the architecture-boundary proof so the host and
  consumers assert the explicit read split

#### Behavioral Verification

- `flutter test test/contract/runtime_contract_interfaces_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_static_layer_cache_test.dart`
- `flutter test test/view/scene_view_test.dart`
- `flutter test test/view/scene_view_interactive_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`

#### Fixtures Used

- `test/support/committed_scene_view_render_state.dart`
- `test/tool/support/guardrails_sandbox_support.dart`
- local runtime stubs inside `test/view/scene_view_interactive_test.dart`

#### Positive Scenarios

- `SceneViewRenderSurface` still paints from one captured frame through the
  main-scene read contract
- `SceneViewInteractiveOverlayPainter` still reads live marquee and draw
  preview state through the overlay-preview read contract
- `SceneViewRuntimeHost` still owns runtime replacement and pointer-session
  swap behavior while routing both read seams from `_activeRuntime`
- benchmark-owned production render-state support and guardrail sandbox support
  both compile and execute against the successor seam names
- move-preview scene repaint invariants stay stable after the test-facing seam
  migrates from `renderState` to the successor main-scene read

#### Negative Scenarios

- the render surface cannot depend on overlay-preview-only APIs
- the overlay painter cannot depend on `captureFrameRead()` or
  `preparePaintPlan(...)`
- `SceneStoreController` and `SceneController` cannot start implementing either
  successor read contract without failing the targeted controller guardrails

#### Closure Evidence

- production view/render consumers, fixtures, benchmark wiring, and targeted
  guardrail scaffolds all understand the successor seam names, and the
  successor contracts already have structural drift checks before the runtime
  owner split lands

### Slice 2. [ ] Retire the Mixed Runtime Read Owner

#### Slice Contract

Split the controller-owned runtime implementation into separate read owners,
migrate the public facade to the narrowed overlay seam, and remove the legacy
mixed `SceneViewRenderState` seam from the repository now that the compile-time
consumers and structural guardrails already understand the successor contracts.

#### Change

- replace the concrete mixed read owner inside
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` with
  one main-scene read owner and one overlay-preview read owner
- migrate `SceneController` preview and selection getters to
  `SceneViewOverlayPreviewRead`
- remove `SceneViewRenderState` and `SceneViewRuntime.renderState`
- retire the temporary mixed-seam bridge paths that remained only to keep Slice
  1 compile-safe while the concrete runtime owner was still unsplit

#### Behavioral Verification

- `flutter test test/contract/runtime_contract_interfaces_test.dart`
- `flutter test test/interactive/core/scene_controller_public_listener_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_static_layer_cache_test.dart`
- `flutter test test/view/scene_view_test.dart`
- `flutter test test/view/scene_view_interactive_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`

#### Fixtures Used

- `test/support/committed_scene_view_render_state.dart`
- `test/tool/support/guardrails_sandbox_support.dart`
- local runtime stubs inside `test/view/scene_view_interactive_test.dart`

#### Positive Scenarios

- `SceneController` public selection and overlay preview getters behave exactly
  as before while reading only from the overlay seam
- scene repaint and overlay repaint delivery stay unchanged across the split
- benchmark cases still use production-owned render/runtime seams

#### Negative Scenarios

- no checked-in file still declares or implements `SceneViewRenderState`
- no `SceneViewRuntime` implementation still exposes a `renderState` getter

#### Closure Evidence

- the legacy mixed seam is gone from production code, fixtures, benchmarks, and
  structural guardrail scaffolds while the existing behavior suites remain
  green

### Slice 3. [ ] Sync Invariants and Checked-In Architecture

#### Slice Contract

Update invariant coverage and the checked-in architecture document so the
repository describes the final split seam and points at the correct proof
surfaces.

#### Change

- update `INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY` and
  `INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE` in
  `tool/invariant_registry.dart` to describe the successor read seams
- update `ARCHITECTURE.md` sections that still describe one mixed
  `SceneControllerSceneViewRenderState` seam shared by the render surface and
  overlay
- update `PLAN.md` and this step document checkbox state when the step closes

#### Behavioral Verification

- `flutter test test/contract/runtime_contract_interfaces_test.dart`
- `flutter test test/interactive/core/scene_controller_public_listener_contract_test.dart`

#### Structural Verification

- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- the invariant proof surfaces named above

#### Positive Scenarios

- checked-in architecture text describes one runtime boundary with distinct
  main-scene and overlay read seams
- invariant coverage points at the final proof surfaces for the split contract

#### Negative Scenarios

- no invariant or architecture text still describes one mixed
  `SceneViewRenderState` transport across the view boundary

#### Closure Evidence

- invariant coverage is green and the checked-in architecture contract matches
  the implemented split seam

## 11. Final Verification

- `flutter test test/contract/runtime_contract_interfaces_test.dart`
- `flutter test test/render/scene_painter_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`
- `flutter test test/render/scene_static_layer_cache_test.dart`
- `flutter test test/view/scene_view_test.dart`
- `flutter test test/view/scene_view_interactive_test.dart`
- `flutter test test/interactive/core/scene_controller_public_listener_contract_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`
- `flutter test tool/bench/load_profiles_cases_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_15_main_scene_and_overlay_render_read_split.md' 'lib/src/contract/scene_view_runtime.dart' 'lib/src/contract/scene_view_render_state.dart' 'lib/src/interactive/internal/scene_controller_scene_view_runtime.dart' 'lib/src/interactive/scene_controller.dart' 'lib/src/view/scene_view_runtime_host.dart' 'lib/src/view/scene_view_render_surface.dart' 'lib/src/view/scene_view_interactive_overlay_painter.dart' 'lib/src/render/scene_painter.dart' 'lib/src/render/scene_painter_frame.dart' 'test/contract/runtime_contract_interfaces_test.dart' 'test/render/scene_painter_test.dart' 'test/render/scene_painter_frame_contract_test.dart' 'test/render/scene_static_layer_cache_test.dart' 'test/view/scene_view_test.dart' 'test/view/scene_view_interactive_test.dart' 'test/interactive/core/scene_controller_public_listener_contract_test.dart' 'test/interactive/core/scene_controller_interactive_move_preview_invariants_test.dart' 'test/interactive/core/scene_controller_architecture_boundary_test.dart' 'test/support/committed_scene_view_render_state.dart' 'test/tool/guardrails/guardrails_interactive_api_tool_test.dart' 'test/tool/guardrails/guardrails_controller_api_tool_test.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/view_and_graph_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/view_runtime_host_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/view_surface_and_runtime_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/runtime_and_draw_ownership_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/owner_and_mutation_boundary_cases.dart' 'test/tool/guardrails/interactive_api/architecture_boundary/pointer_host_and_public_shell_cases.dart' 'test/tool/support/guardrails_sandbox_support.dart' 'test/tool/bench_run_load_profiles_test.dart' 'tool/bench/load_profiles_cases_test.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_facade_rules.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_pointer_rules.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_view_surface_rules.dart' 'tool/src/guardrails/rules/interactive/interactive_architecture_boundary_view_host_rules.dart' 'tool/src/guardrails/rules/controller/write_only_mutation_rules.dart' 'tool/invariant_registry.dart' 'ARCHITECTURE.md' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- `SceneViewRuntime` exposes `mainSceneRenderRead` and `overlayPreviewRead`,
  and no production `renderState` getter remains
- production main-scene rendering depends only on
  `SceneViewMainSceneRenderRead`, and production overlay rendering plus public
  controller preview getters depend only on `SceneViewOverlayPreviewRead`
- `SceneControllerSceneViewRuntime` remains the single assembled runtime
  boundary and pointer-session owner, but the mixed concrete render-state owner
  is gone
- controller and interactive guardrails reject `SceneStoreController` or
  `SceneController` if they try to re-enter the full scene-view read family
- the checked-in architecture and invariant registry describe the split read
  boundary and point at the final proof surfaces
