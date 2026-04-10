language: russian

# Шаг 102. Ввести render-local visibility budget без расширения viewport query в `ScenePainter`

## 1. Change Mandate

Этот шаг вводит один render-local owner visibility budget для `ScenePainter`,
но не расширяет им обычную candidate enumeration. Viewport-first query остаётся
controller-owned, а visibility budget используется только для selected-node
supplement и final cull, чтобы selection halo больше не выпадал из visibility
contract у границы viewport и при этом не возвращал лишнюю off-viewport
geometry/text work для unselected nodes.

## 2. Change Boundary

### Included in the Change

- Render-local visibility-budget owner for base scene painter node visibility.
- Frame and render-state changes required so raw viewport query, selected-node
  supplement, and final node culling use one explicit ownership contract.
- Selection-halo contribution to the base scene visibility budget.
- Render proof, invariant, and documentation updates required to publish the
  viewport-first query plus selection-aware visibility contract.

### Not Included in the Change

- Viewport candidate enumeration ownership or paint-order semantics.
- Text-layout payload ownership, text geometry sizing, or text-paint handoff.
- Overlay repaint topology, marquee ownership, or overlay painter contracts.
- Any new public API surface on `ScenePainter`, `SceneViewRuntime`, or
  `SceneViewRenderState`.
- New visual effects such as shadows, glows, or debug overlays beyond the
  current base budget and selection halo outgrowth.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_node_renderer.dart`

### Test Files

- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`
- `test/support/committed_scene_view_render_state.dart`
- `test/view/scene_view_interactive_test.dart`

### Fixture and Supporting Data Files

- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_102_scene_painter_visibility_budget.md`

### Analysis Area

- `lib/src/contract/scene_view_render_state.dart`
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- `lib/src/render/scene_painter_*`
- `test/render/scene_painter_*`
- `test/view/scene_view_interactive_test.dart`
- `test/support/committed_scene_view_render_state.dart`
- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either introduce the render-local
  visibility-budget owner on the frame path or keep viewport-first candidate
  ownership intact while wiring selected supplement and final culling to the
  same visibility contract.
- Every modified test file must pin one closed seam of this step:
  raw viewport query ownership,
  selected-node supplement visibility,
  per-node final-cull rect parity,
  or selection-halo edge visibility.
- Every modified supporting or documentation file must publish or enforce the
  exact visibility-budget contract closed by this step.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step changes base-scene visibility budgeting only. It must not reopen
   viewport candidate ownership, text-layout ownership, repaint-channel
   topology, or marquee ownership.
2. The exact render-local owner introduced by this step is named
   `ScenePainterVisibilityBudget`.
3. `ScenePainterVisibilityBudget` stays render-local on the frame path. This
   step must not move visibility budgeting into controller state, spatial index
   ownership, or widget-side view code.
4. Ordinary candidate enumeration remains viewport-first and controller-owned.
   This step may add an internal query wrapper so the runtime receives both
   raw viewport ownership and the budgeted visibility rect, but it must not
   widen ordinary enumeration for unselected nodes.
5. The minimum base visibility outset remains `1.0`; this value continues to
   cover the current anti-alias / fuzz budget even when no selection halo is
   active.
6. Selection contribution is derived from the outward visual halo extent, which
   for the current selection renderer equals `selectionStyle.haloWidth`.
   This step must not treat `haloWidth * 2` or total stroke width as the
   outward cull contribution.
7. Overlay-only state, including marquee `selectionRect`, stroke preview, and
   line preview, does not contribute to the base `ScenePainter` visibility
   budget after the repaint split and marquee migration.
8. The budgeted visibility rect must be applied to selected-node supplement
   and final culling. Computing a second independent halo padding path for one
   of those consumers is forbidden.

## 5. Result Requirements

1. `ScenePainter` computes one per-frame visibility budget while ordinary
   candidate enumeration stays viewport-first.
2. The base-scene visibility budget is never smaller than `1.0` and expands to
   match `selectionStyle.haloWidth` when the active selection halo is larger.
3. A selected node whose geometry is just outside the raw viewport but whose
   selection halo still intersects the viewport remains paint-visible in the
   main `ScenePainter`.
4. Unselected nodes in the halo band remain absent from expensive candidate
   resolution, and selected nodes with no halo intersection remain culled.
5. The invariant registry, proof surface, and release-ready docs describe one
   render-local visibility-budget owner plus viewport-first candidate query
   ownership instead of a fixed magic cull padding.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/render/scene_painter_frame.dart` currently hardcodes
  `scenePainterCullPadding = 1.0` and inflates the viewport rect before
  candidate enumeration.
- `lib/src/contract/scene_view_render_state.dart` currently exposes only a
  single rect input for candidate enumeration, which conflates raw viewport
  ownership with selection-aware visibility.
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
  currently owns viewport candidate ordering and selected-preview supplement
  behavior, so it is the correct owning layer for any selection-aware
  supplementation that must preserve viewport-first enumeration.
- `lib/src/render/scene_painter_node_renderer.dart` currently performs final
  culling through `_canPaintNodeInFrame(resolvedNode, frame.viewRect)`, so the
  frame rect already acts as the final visibility gate.
- `lib/src/render/scene_painter_selection.dart` currently draws selection halo
  visuals whose outward extent equals `selectionStyle.haloWidth`, even though
  some stroke widths are expressed as `haloWidth * 2`.
- `tool/invariant_registry.dart` currently publishes frame resolution and
  viewport paint-candidate ownership but does not yet publish the
  selection-aware visibility contract that preserves viewport-first
  enumeration.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/render --report-all`
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

- Existing controller-owned viewport candidate enumeration and paint-order
  contract.
- Existing frame-local text-layout ownership and geometry handoff.
- Existing split scene/overlay repaint channels and overlay-owned marquee.
- Existing public runtime and painter construction surfaces.
- Existing node geometry and selection rendering semantics outside visibility
  budgeting.

### 6.4 Allowed Semantic Change Zones

- Frame-local visibility-budget computation.
- Internal render-state query semantics for viewport-first enumeration and
  selected-node supplement.
- Frame rect semantics for final culling.
- Render-only selection-halo cull contribution.
- Render proof, invariant wording, and release-ready documentation for the
  viewport-first query plus selection-aware visibility contract.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `ScenePainterFrameOwner.create(Size size)` must instantiate
  `ScenePainterVisibilityBudget` before candidate enumeration and must derive
  one budgeted `viewRect` from the raw camera/viewport rect plus that budget.
- `ScenePainterVisibilityBudget` must be computed from the base minimum
  `1.0` and the current `ScenePainterSelectionStyle.haloWidth`, with the
  effective outward extent equal to `max(1.0, selectionStyle.haloWidth)`.
- `renderState.enumeratePaintCandidates(...)` must receive raw viewport
  ownership together with the budgeted visibility rect so ordinary candidates
  stay viewport-first while selected supplements can use halo-aware
  visibility.
- `ScenePainterPaintFrame` must keep `viewRect` as the frame-level final-cull
  rect and provide per-node access so unselected nodes keep raw viewport
  culling semantics even when another node is selected.
- Verification must include one proof that captures both the raw viewport rect
  and the budgeted visibility rect passed into candidate enumeration for a
  non-default `selectionStrokeWidth`.

### 6.8 Prohibited

- Raising the existing constant from `1.0` to another magic number without
  introducing the explicit `ScenePainterVisibilityBudget` owner.
- Widening ordinary candidate enumeration for unselected nodes just because
  any selection exists.
- Treating selection halo contribution as `haloWidth * 2`, total stroke width,
  or any other value larger than the actual outward halo extent.
- Letting overlay-only marquee or draw-preview state influence the base-scene
  visibility budget.
- Reopening viewport-candidate, repaint-topology, or text-layout work inside
  this step.
- Leaving invariants or docs claiming a fixed `scenePainterCullPadding` after
  the step is complete.

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
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered valid.
11. If a slice depends on an unconfirmed architectural decision, planning must
    stop and that decision must be explicitly confirmed by the user before the
    slice can be written or expanded.

## 8. Vertical Slices

### Slice 1. [x] Frame path owns raw viewport query and budgeted final visibility

#### Slice Contract

`ScenePainterFrameOwner` computes one explicit `ScenePainterVisibilityBudget`,
keeps the ordinary candidate query on the raw viewport rect, and carries the
resulting budgeted `viewRect` forward for later final culling.

#### Change

- Introduce `ScenePainterVisibilityBudget` on the render frame path and remove
  the fixed `scenePainterCullPadding` constant.
- Build the raw viewport rect from camera offset and canvas size, then derive
  one budgeted `viewRect` from that raw rect plus the computed visibility
  budget.
- Pass both raw viewport ownership and the budgeted visibility rect into the
  internal candidate query contract.
- Keep `ScenePainterPaintFrame.viewRect` as the frame-level visibility rect
  carried by frame data for final culling.
- Update `test/render/scene_painter_bounds_contract_test.dart` so the
  structural proof pins `ScenePainterVisibilityBudget` construction and the
  raw viewport plus budgeted visibility query assembly.
- Add or update a frame-contract proof in
  `test/render/scene_painter_frame_contract_test.dart` that captures the world
  rects passed to `enumeratePaintCandidates(...)` and proves the viewport
  query stays raw while `frame.viewRect` stays budgeted.

#### Verification

- `dart test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`

#### Positive Scenarios

- A frame built with a non-default `selectionStrokeWidth` passes one inflated
  visibility rect plus the raw viewport rect to candidate enumeration and
  stores the budgeted rect in `ScenePainterPaintFrame.viewRect`.
- Final node culling continues to read frame-owned visibility data rather than
  deriving an independent halo padding path.

#### Negative Scenarios

- `ScenePainterFrameOwner` must not keep a fixed magic cull-padding constant.
- Ordinary candidate enumeration must not switch from raw viewport ownership
  to the halo-expanded rect.

#### Closure Evidence

- Green run of the listed verifications.
- Structural and frame-contract tests prove raw viewport query ownership and a
  frame-owned budgeted final visibility rect.

### Slice 2. [x] Selection halo contributes exact outward visibility extent

#### Slice Contract

The base-scene visibility budget expands by the exact outward selection halo
extent, so selected edge nodes stay visible when only their halo intersects
the viewport while non-intersecting nodes remain culled.

#### Change

- Compute the `ScenePainterVisibilityBudget` outward extent as
  `max(1.0, selectionStyle.haloWidth)`.
- Keep overlay-only marquee and draw-preview state out of that computation.
- Add selected-node supplement ownership in the internal render-state path so
  selected edge nodes can enter frame resolution through the budgeted
  visibility rect without widening ordinary viewport candidates.
- Add render regression coverage in `test/render/scene_painter_test.dart` for
  an edge-selected `RectNodeSnapshot` whose geometry sits just outside the raw
  viewport but whose halo intersects the viewport when
  `selectionStrokeWidth > 1`.
- Add the paired negative proof that an unselected equivalent node, or a
  selected node whose halo still does not intersect the viewport, remains
  culled.

#### Verification

- `flutter test test/render/scene_painter_test.dart`

#### Positive Scenarios

- A selected `RectNodeSnapshot` near the viewport edge still paints when the
  halo intersects the viewport only through the visibility budget.
- The same selected node still uses the existing selection renderer and does
  not require overlay participation for edge visibility.
- Selected edge-node supplementation works even without a non-zero preview
  delta.

#### Negative Scenarios

- An unselected node in the same geometry position remains culled.
- A selected node whose halo does not reach the viewport remains culled.
- The visibility budget must not be derived from `haloWidth * 2`.

#### Closure Evidence

- Green run of the listed verifications.
- Render regression tests prove edge-selected halo visibility and preserve
  culling for non-intersecting nodes.

### Slice 3. [x] Invariant and docs publish viewport-first visibility ownership

#### Slice Contract

The invariant registry, proof surface, and release-ready docs describe one
render-local visibility-budget owner together with viewport-first candidate
enumeration ownership, with selection halo contributing exact outward extent
and no fixed magic padding.

#### Change

- Update `tool/invariant_registry.dart` so
  `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` publishes viewport-first candidate
  enumeration, selected-node supplement through the budgeted visibility rect,
  text/geometry frame resolution, and final culling.
- Update the proof wording in
  `test/render/scene_painter_bounds_contract_test.dart` and
  `test/render/scene_painter_frame_contract_test.dart` so the proof surface
  matches the invariant exactly.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
  `PLAN.md`, and this step document so they publish the same internal
  architecture:
  `ScenePainterVisibilityBudget` as the render-local owner,
  raw viewport query ownership,
  selected-node supplement plus final cull through the budgeted visibility
  rect,
  base minimum `1.0`,
  and selection-halo contribution through exact outward extent.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`

#### Positive Scenarios

- The invariant text and proof files describe the same viewport-first query
  plus selection-aware visibility contract.
- Release-ready docs no longer describe a fixed cull padding for the base
  scene painter.

#### Negative Scenarios

- No invariant or documentation text may continue to describe halo-expanded
  ordinary candidate enumeration or a fixed `scenePainterCullPadding`.

#### Closure Evidence

- Green run of the listed verifications.
- `tool/invariant_registry.dart` and the proof files contain aligned wording
  with exact `// INV:<id>` coverage.
- Release-ready docs describe the final render read-side visibility contract
  without drift.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/render --report-all`
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
