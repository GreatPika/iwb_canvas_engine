language: russian

# Шаг 102. Ввести единый visibility budget для query и final cull в `ScenePainter`

## 1. Change Mandate

Этот шаг вводит один render-local owner visibility budget для `ScenePainter`,
чтобы candidate query и final cull опирались на один и тот же budgeted rect, а
selection halo больше не выпадал из visibility contract у границы viewport.

## 2. Change Boundary

### Included in the Change

- Render-local visibility-budget owner for base scene painter node visibility.
- Frame assembly changes required so one budgeted rect drives both
  `enumeratePaintCandidates(...)` and final node culling.
- Selection-halo contribution to the base scene visibility budget.
- Render proof, invariant, and documentation updates required to publish one
  unified visibility-budget contract.

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

- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_node_renderer.dart`

### Test Files

- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`
- `test/render/scene_painter_test.dart`

### Fixture and Supporting Data Files

- `tool/invariant_registry.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_102_scene_painter_visibility_budget.md`

### Analysis Area

- `lib/src/render/scene_painter_*`
- `test/render/scene_painter_*`
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

- Every modified implementation file must either introduce the unified
  visibility-budget owner on the frame path or keep final culling wired to the
  same frame rect without widening frame contracts.
- Every modified test file must pin one closed seam of this step:
  unified budgeted rect assembly,
  query/final-cull rect parity,
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
4. `ScenePainterPaintFrame.viewRect` remains the single frame-level visibility
   rect consumed by both candidate enumeration and final culling. This step
   must not introduce parallel query and cull rect surfaces.
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
8. The same computed visibility budget must be applied to both
   `renderState.enumeratePaintCandidates(...)` input and
   `_canPaintNodeInFrame(...)` via the shared frame rect. Computing separate
   paddings for query and final cull is forbidden.

## 5. Result Requirements

1. `ScenePainter` computes one per-frame visibility budget and uses the same
   budgeted world rect for candidate enumeration and final node culling.
2. The base-scene visibility budget is never smaller than `1.0` and expands to
   match `selectionStyle.haloWidth` when the active selection halo is larger.
3. A selected node whose geometry is just outside the raw viewport but whose
   selection halo still intersects the viewport remains paint-visible in the
   main `ScenePainter`.
4. Unselected nodes and selected nodes with no halo intersection remain culled
   by the same unified frame rect.
5. The invariant registry, proof surface, and release-ready docs describe one
   render-local visibility-budget owner instead of a fixed magic cull padding.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/render/scene_painter_frame.dart` currently hardcodes
  `scenePainterCullPadding = 1.0` and inflates the viewport rect before
  `renderState.enumeratePaintCandidates(viewRect)`.
- `lib/src/render/scene_painter_node_renderer.dart` currently performs final
  culling through `_canPaintNodeInFrame(resolvedNode, frame.viewRect)`, so the
  frame rect already acts as the final visibility gate.
- `lib/src/render/scene_painter_selection.dart` currently draws selection halo
  visuals whose outward extent equals `selectionStyle.haloWidth`, even though
  some stroke widths are expressed as `haloWidth * 2`.
- `tool/invariant_registry.dart` currently publishes frame resolution and
  viewport paint-candidate ownership but does not yet publish one unified
  visibility-budget contract for query and final cull.

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
- Frame rect semantics for candidate enumeration and final culling.
- Render-only selection-halo cull contribution.
- Render proof, invariant wording, and release-ready documentation for the
  unified visibility-budget contract.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `ScenePainterFrameOwner.create(Size size)` must instantiate
  `ScenePainterVisibilityBudget` before candidate enumeration and must derive
  one budgeted `viewRect` from the raw camera/viewport rect plus that budget.
- `ScenePainterVisibilityBudget` must be computed from the base minimum
  `1.0` and the current `ScenePainterSelectionStyle.haloWidth`, with the
  effective outward extent equal to `max(1.0, selectionStyle.haloWidth)`.
- `renderState.enumeratePaintCandidates(...)` must keep receiving the same
  `frame.viewRect` that final culling consumes later in
  `_canPaintNodeInFrame(...)`.
- `ScenePainterPaintFrame` must not grow a second raw viewport rect or a
  second cull rect in parallel with `viewRect` for this step.
- Verification must include one proof that captures the world rect passed to
  `enumeratePaintCandidates(...)` and shows it matches the budgeted frame rect
  for a non-default `selectionStrokeWidth`.

### 6.8 Prohibited

- Raising the existing constant from `1.0` to another magic number without
  introducing the explicit `ScenePainterVisibilityBudget` owner.
- Computing query padding and final-cull padding in two independent paths.
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

### Slice 1. [ ] Frame path owns one unified visibility budget rect

#### Slice Contract

`ScenePainterFrameOwner` computes one explicit `ScenePainterVisibilityBudget`
and uses the resulting single `viewRect` both for candidate enumeration and
for later final culling.

#### Change

- Introduce `ScenePainterVisibilityBudget` on the render frame path and remove
  the fixed `scenePainterCullPadding` constant.
- Build the raw viewport rect from camera offset and canvas size, then derive
  one budgeted `viewRect` from that raw rect plus the computed visibility
  budget.
- Keep `ScenePainterPaintFrame.viewRect` as the only visibility rect carried by
  frame data.
- Update `test/render/scene_painter_bounds_contract_test.dart` so the
  structural proof pins `ScenePainterVisibilityBudget` construction and the
  `renderState.enumeratePaintCandidates(viewRect)` call on the budgeted frame
  rect.
- Add or update a frame-contract proof in
  `test/render/scene_painter_frame_contract_test.dart` that captures the world
  rect passed to `enumeratePaintCandidates(...)` and proves it equals the
  budgeted frame `viewRect`.

#### Verification

- `dart test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`

#### Positive Scenarios

- A frame built with a non-default `selectionStrokeWidth` passes one inflated
  world rect to candidate enumeration and stores that same rect in
  `ScenePainterPaintFrame.viewRect`.
- Final node culling continues to read `frame.viewRect` rather than deriving a
  second independent cull rect.

#### Negative Scenarios

- `ScenePainterFrameOwner` must not keep a fixed magic cull-padding constant.
- `ScenePainterPaintFrame` must not gain a second query-only or cull-only rect
  surface.

#### Closure Evidence

- Green run of the listed verifications.
- Structural and frame-contract tests prove one budgeted frame rect is shared
  by candidate enumeration and final culling.

### Slice 2. [ ] Selection halo contributes exact outward visibility extent

#### Slice Contract

The base-scene visibility budget expands by the exact outward selection halo
extent, so selected edge nodes stay visible when only their halo intersects
the viewport while non-intersecting nodes remain culled.

#### Change

- Compute the `ScenePainterVisibilityBudget` outward extent as
  `max(1.0, selectionStyle.haloWidth)`.
- Keep overlay-only marquee and draw-preview state out of that computation.
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

#### Negative Scenarios

- An unselected node in the same geometry position remains culled.
- A selected node whose halo does not reach the viewport remains culled.
- The visibility budget must not be derived from `haloWidth * 2`.

#### Closure Evidence

- Green run of the listed verifications.
- Render regression tests prove edge-selected halo visibility and preserve
  culling for non-intersecting nodes.

### Slice 3. [ ] Invariant and docs publish unified visibility-budget ownership

#### Slice Contract

The invariant registry, proof surface, and release-ready docs describe one
render-local visibility-budget owner for candidate query and final cull, with
selection halo contributing exact outward extent and no fixed magic padding.

#### Change

- Update `tool/invariant_registry.dart` so
  `INV-ENG-SCENE-PAINTER-FRAME-RESOLUTION` publishes one budgeted frame rect
  shared by candidate enumeration, text/geometry frame resolution, and final
  culling.
- Update the proof wording in
  `test/render/scene_painter_bounds_contract_test.dart` and
  `test/render/scene_painter_frame_contract_test.dart` so the proof surface
  matches the invariant exactly.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
  `PLAN.md`, and this step document so they publish the same internal
  architecture:
  `ScenePainterVisibilityBudget` as the render-local owner,
  one budgeted `viewRect` shared by query and final cull,
  base minimum `1.0`,
  and selection-halo contribution through exact outward extent.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- `flutter test test/render/scene_painter_bounds_contract_test.dart`
- `flutter test test/render/scene_painter_frame_contract_test.dart`

#### Positive Scenarios

- The invariant text and proof files describe the same unified visibility
  budget contract.
- Release-ready docs no longer describe a fixed cull padding for the base
  scene painter.

#### Negative Scenarios

- No invariant or documentation text may continue to describe independent
  query/cull padding paths or a fixed `scenePainterCullPadding`.

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
