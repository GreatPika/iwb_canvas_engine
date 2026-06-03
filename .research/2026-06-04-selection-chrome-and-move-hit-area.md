---
date: 2026-06-04
researcher: Codex
commit: eeab3dd9
branch: new-architecture
research_question: "Research current selection chrome, multi-selection bounds, selection z-order, inside selection frames, and selected-move hit area behavior."
---

# Research: Selection Chrome And Move Hit Area

## Summary

Current selection decoration is a frame-owned, separate main-scene decoration
pass. `SelectionDecorationPlanner` creates one `SelectionDecorationPrimitive`
per selected element from each selected element's paint bounds, and
`MainFramePainter` paints all selection decorations after all main-frame element
records. This makes selection chrome appear above higher-order scene content.

Current selected-move admission is interaction-owned and starts only on pointer
down when the down point hits the topmost geometry of a selected movable
element. The interaction start facts do not expose selection-union bounds or an
inside-selection-box hit fact. Selection-union bounds are computed later for
selected-move commit facts.

Legacy and current docs show per-element selection decoration and top-node
selected-move start behavior. The searched repository and legacy scope did not
contain an existing group-selection chrome contract, bounding-box-interior drag
contract, or inside-selection-frame contract.

## Detailed Findings

### 1. Current Selection Decoration Construction

- **Location**: `lib/src/frame/selection_decoration_planner.dart:93`
- **Description**: `SelectionDecorationPlanner` builds and caches one
  `SelectionDecorationPlan`. The key includes selection revision, selected ids,
  bounds revision, selected-move delta, preview revision, selection style, and
  device pixel ratio (`lib/src/frame/selection_decoration_planner.dart:12`,
  `lib/src/frame/selection_decoration_planner.dart:139`).
- **Dependencies**: It consumes `CapturedMainFrame`, `FrameElementFacts`,
  `CanvasSelectionStyle`, and `RenderElementRecord.fromFacts`
  (`lib/src/frame/selection_decoration_planner.dart:5`,
  `lib/src/frame/selection_decoration_planner.dart:8`,
  `lib/src/frame/selection_decoration_planner.dart:9`).
- **Data flow**: `CapturedMainFrame` -> selected ids/style ->
  `_primitivesFor` -> `SelectionDecorationPlan`.

`_primitivesFor` loops over `frame.snapshot.elements`; when an element id is
selected, it yields one `SelectionDecorationPrimitive` for that element
(`lib/src/frame/selection_decoration_planner.dart:113`,
`lib/src/frame/selection_decoration_planner.dart:116`,
`lib/src/frame/selection_decoration_planner.dart:118`,
`lib/src/frame/selection_decoration_planner.dart:122`). The primitive shape
contains only `boundsWorld`, color, stroke width, and halo width; it does not
carry element family or order token (`lib/src/frame/selection_decoration_planner.dart:69`).

### 2. Current Selection Decoration Bounds

- **Location**: `lib/src/frame/selection_decoration_planner.dart:155`
- **Description**: Selection decoration bounds are derived from
  `RenderElementRecord.fromFacts(facts).paintBoundsWorld`, then shifted by the
  active selected-move delta when present
  (`lib/src/frame/selection_decoration_planner.dart:159`,
  `lib/src/frame/selection_decoration_planner.dart:160`,
  `lib/src/frame/selection_decoration_planner.dart:162`).
- **Dependencies**: `RenderElementRecord.fromFacts` reads geometry bounds from
  `GeometryPolicy.boundsFor(facts)` (`lib/src/frame/render_element_record.dart:151`,
  `lib/src/frame/render_element_record.dart:155`).
- **Data flow**: selected `FrameElementFacts` -> render element record ->
  paint bounds -> optional selected-move delta shift -> decoration primitive.

`GeometryPolicy.boundsFor` computes finite paint and hit bounds from element
facts and transform; invisible elements produce zero paint bounds
(`lib/src/geometry/geometry_policy.dart:25`,
`lib/src/geometry/geometry_policy.dart:31`,
`lib/src/geometry/geometry_policy.dart:42`). Rect bounds include stroke-aware
expansion (`lib/src/geometry/geometry_policy.dart:304`,
`lib/src/geometry/geometry_policy.dart:312`,
`lib/src/geometry/geometry_policy.dart:325`). Image local bounds use centered
size (`lib/src/geometry/geometry_policy.dart:291`).

### 3. Current Selection Decoration Paint Order

- **Location**: `lib/src/surface/main_painter.dart:15`
- **Description**: `MainFramePainter.paint` draws the static background, then
  paints all `selectedMoveSupplementPlan.mergedRecords`, and only after that
  paints selection decorations (`lib/src/surface/main_painter.dart:23`,
  `lib/src/surface/main_painter.dart:25`,
  `lib/src/surface/main_painter.dart:35`).
- **Dependencies**: Element records are normalized by
  `mainFrameRecordsInPaintOrder`; topmost-first streams are reversed before
  painting (`lib/src/surface/main_painter.dart:48`,
  `lib/src/surface/main_painter.dart:51`).
- **Data flow**: `MainFramePaintOutput` -> static background -> ordered element
  records -> selection decoration primitives.

Because `_paintSelectionDecorations` is called after the record paint loop, the
current selected element chrome is painted over all main-frame records
(`lib/src/surface/main_painter.dart:25`, `lib/src/surface/main_painter.dart:35`).
The painter draws halo as an inflated rectangle and stroke as a rectangle
centered on primitive bounds (`lib/src/surface/main_painter.dart:80`,
`lib/src/surface/main_painter.dart:91`).

### 4. Frame Output Assembly And Documentation

- **Location**: `lib/src/frame/frame_engine.dart:92`
- **Description**: Main frame assembly builds ordinary paint, selected-move
  supplement, static background, selection decoration, selected order snapshot,
  render primitive snapshot, and asset bindings before returning
  `MainFramePaintOutput` (`lib/src/frame/frame_engine.dart:97`,
  `lib/src/frame/frame_engine.dart:107`,
  `lib/src/frame/frame_engine.dart:118`).
- **Dependencies**: `MainFramePaintOutput` stores `selectionDecorationPlan`,
  `selectedOrderSnapshot`, and `selectedMoveSupplementPlan` separately
  (`lib/src/frame/frame_paint_output.dart:17`,
  `lib/src/frame/frame_paint_output.dart:28`,
  `lib/src/frame/frame_paint_output.dart:29`,
  `lib/src/frame/frame_paint_output.dart:30`).
- **Data flow**: captured frame facts -> frame planners -> immutable main frame
  paint output -> painter.

The frame rendering contract identifies `SelectionDecorationPlanner` as owner
of selection UI decoration and the decoration key, including bounds revision and
selected-move preview movement facts (`docs/contracts/frame_rendering.md:147`,
`docs/contracts/frame_rendering.md:152`). The same contract states ordinary
paint excludes selection state and selected move delta (`docs/contracts/frame_rendering.md:157`,
`docs/contracts/frame_rendering.md:213`). It also records selection decoration
as separate from ordinary paint plan cache identity
(`docs/contracts/frame_rendering.md:279`,
`docs/contracts/frame_rendering.md:284`,
`docs/contracts/frame_rendering.md:291`).

### 5. Current Selected-Move Start Path

- **Location**: `lib/src/interaction/interaction_engine.dart:386`
- **Description**: In move mode, pointer down calls
  `_selectedMoveStartDecision`; if admitted, it creates a selected-move pointer
  session. If rejected, the engine falls through to marquee behavior
  (`lib/src/interaction/interaction_engine.dart:386`,
  `lib/src/interaction/interaction_engine.dart:390`,
  `lib/src/interaction/interaction_engine.dart:392`).
- **Dependencies**: The path uses `InteractionReadPort`, `MoveMachine`, and
  `PointerSession`.
- **Data flow**: pointer down sample -> selected move start facts ->
  `MoveMachine.start` -> selected move session or marquee fallback.

`MoveMachine.start` rejects when selected ids are empty, movable selected ids
are empty, or `hitSelectedMovable` is false (`lib/src/interaction/move_machine.dart:15`).
The admitted decision stores selected ids, movable ids, selection revision, and
selection bounds from facts (`lib/src/interaction/move_machine.dart:22`,
`lib/src/interaction/move_machine.dart:60`).

Pointer move does not perform selected-move admission. Move samples require an
existing active session with the same pointer id and controller epoch before
the selected-move preview path updates delta (`lib/src/interaction/interaction_engine.dart:512`,
`lib/src/interaction/interaction_engine.dart:573`).

### 6. Current Selected-Move Start Facts

- **Location**: `lib/src/runtime/runtime_interaction_read_adapter.dart:42`
- **Description**: `RuntimeInteractionReadAdapter.selectedMoveStartFacts`
  builds start facts from document-ordered selected ids, movable selected ids,
  a spatial point query at the pointer-down world position, a topmost hit id,
  and `hitSelectedMovable`.
- **Dependencies**: It uses `SelectionFactsPort`, `FrameFactsPort`,
  `SpatialKernel`, and `HitTestPolicy`.
- **Data flow**: pointer world position -> spatial point query -> topmost
  object hit -> membership in movable selected ids -> selected move start facts.

`hitSelectedMovable` is computed as `hitId != null && movableIds.contains(hitId)`
(`lib/src/runtime/runtime_interaction_read_adapter.dart:72`). Movability
requires content location, visibility, selectable status, not locked, and
transformable state (`lib/src/runtime/runtime_interaction_read_adapter.dart:449`).

The exact hit-test path uses `HitTestPolicy.topmostHit`, which sorts candidates
by order token, resolves facts, skips background, and requires exact geometry
hit (`lib/src/geometry/hit_test_policy.dart:21`). Hit eligibility requires a
finite point, visible element, selectable element, content location, and finite
transform (`lib/src/geometry/geometry_policy.dart:48`).

### 7. Current Selection Union Bounds Availability

- **Location**: `lib/src/runtime/runtime_interaction_read_adapter.dart:78`
- **Description**: Selected-move commit facts recompute movable ids, collect
  moved element reads, compute document summary, and provide
  `selectionBoundsWorld`.
- **Dependencies**: The commit facts path delegates to
  `selectedMoveReadModels` (`lib/src/runtime/runtime_interaction_read_adapter.dart:87`).
- **Data flow**: selected ids captured in pointer session -> current movable
  selected read models -> moved elements -> union selection bounds -> commit
  facts.

`RuntimeSelectedMoveReadModels` computes `selectionBoundsWorld` from moved
elements (`lib/src/runtime/runtime_interaction_move_read_models.dart:16`,
`lib/src/runtime/runtime_interaction_move_read_models.dart:70`). The start-facts
surface currently exposes selected ids, movable selected ids, selection
revision, query facts, hit selected movable, and selected move bounds fields
defined in `SelectedMoveStartFacts`, but the current start-hit decision is
documented and tested around object-hit membership
(`lib/src/interaction/interaction_read_port.dart:52`,
`lib/src/interaction/move_machine.dart:15`,
`lib/src/runtime/runtime_interaction_read_adapter.dart:72`).

### 8. Current Tests And Diagrams

- **Location**: `test/frame/fixtures/selection_decoration_plan_fixture.dart:17`
- **Description**: Selection decoration tests assert that the decoration key
  includes selection, style, DPR, and bounds facts; a selected rect produces a
  single decoration primitive with expected bounds
  (`test/frame/fixtures/selection_decoration_plan_fixture.dart:64`,
  `test/frame/fixtures/selection_decoration_plan_fixture.dart:72`).
- **Dependencies**: The fixture uses `SelectionDecorationPlanner` and captured
  frame facts.
- **Data flow**: fixture frame facts -> planner -> plan key and primitive bounds.

The same fixture verifies selected-move preview updates key delta/revision and
shifts decoration bounds (`test/frame/fixtures/selection_decoration_plan_fixture.dart:95`,
`test/frame/fixtures/selection_decoration_plan_fixture.dart:98`). The fixture
also asserts ordinary paint key remains unchanged when selection-only facts
change (`test/frame/fixtures/selection_decoration_plan_fixture.dart:82`).

`test/interaction/fixtures/move_machine_fixture.dart` covers selected-move
admission where pointer down hits a selected element at the origin
(`test/interaction/fixtures/move_machine_fixture.dart:30`,
`test/interaction/fixtures/move_machine_fixture.dart:32`). It also covers
terminal commit, moved ids, selection bounds in the request, transform commits,
move action, and preview cleanup (`test/interaction/fixtures/move_machine_fixture.dart:163`,
`test/interaction/fixtures/move_machine_fixture.dart:165`).

`test/interaction/fixtures/interaction_read_port_fixture.dart` covers start
facts with document-ordered selected ids, movable selected ids, and
`hitSelectedMovable == true` for a point inside the selected movable element
(`test/interaction/fixtures/interaction_read_port_fixture.dart:33`,
`test/interaction/fixtures/interaction_read_port_fixture.dart:34`).

The selected-move sequence diagram records read-port facts including selected
ids, movable flags, spatial hit-test, and hit-selected fact
(`docs/diagrams/seq_selected_move_preview_commit.mmd:37`). The selected-move
state diagram states admission requires a selected target and at least one
movable selected id (`docs/diagrams/state_selected_move.mmd:16`,
`docs/diagrams/state_selected_move.mmd:20`).

### 9. Legacy Selection Rendering Evidence

- **Location**: `legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:23`
- **Description**: Legacy `ScenePainterSelectionRenderer.drawSceneSelection`
  draws scene selection only when the frame has node selection, then loops over
  `frame.selectedNodes` and draws selection for each selected node
  (`legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:23`,
  `legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:31`).
- **Dependencies**: It uses `ScenePainterPaintFrame`,
  `ScenePainterSelectionStyle`, `ScenePathMetricsCache`, and
  `selection_halo_compositing.dart`
  (`legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:4`,
  `legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:6`,
  `legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:8`,
  `legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:10`).
- **Data flow**: paint frame selected nodes -> per-node selection rendering.

Legacy image, text, and rect selection route to `_drawWorldBoundsSelection`,
which uses node `geometry.worldBounds` and draws a bounded rectangular halo
(`legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:69`,
`legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:72`,
`legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:240`,
`legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:244`,
`legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:248`).
`drawBoundedRectHalo` uses a bounded saveLayer, draws a stroked rectangle, then
clears the rect interior with `BlendMode.clear`
(`legacy/iwb_canvas_engine/lib/src/render/selection_halo_compositing.dart:18`,
`legacy/iwb_canvas_engine/lib/src/render/selection_halo_compositing.dart:27`,
`legacy/iwb_canvas_engine/lib/src/render/selection_halo_compositing.dart:37`).

Legacy scene paint order is background, node layers, then scene selection
(`legacy/iwb_canvas_engine/lib/src/render/scene_painter_shell.dart:40`,
`legacy/iwb_canvas_engine/lib/src/render/scene_painter_shell.dart:41`,
`legacy/iwb_canvas_engine/lib/src/render/scene_painter_shell.dart:42`,
`legacy/iwb_canvas_engine/lib/src/render/scene_painter_shell.dart:48`).

### 10. Legacy Selected-Move Evidence

- **Location**: `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart:119`
- **Description**: Legacy move-mode pointer down begins a gesture, hit-tests the
  top node at the scene point, chooses marquee when no hit is found, selects the
  hit node when needed, and starts move preview when preview ids include the
  hit id (`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart:119`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart:122`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart:125`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart:131`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart:134`).
- **Dependencies**: It uses `InteractiveMoveHitTestEngine`,
  `InteractiveMoveSelectionCoordinator`, and `InteractiveMovePreviewState`
  (`legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart:18`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart:23`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart:35`).
- **Data flow**: pointer down scene point -> top node hit-test -> selection
  coordinator -> move preview target or marquee target.

The inspected legacy path starts selected move from a top-node hit. Searches did
not find a legacy contract or code path for selected group movement from
bounding-box interior without object hit.

### 11. Donor And Implementation Docs Evidence

- **Location**: `docs/implementation/p9_frame_rendering_and_caches.md:58`
- **Description**: P9 implementation docs repeat the current split:
  `SelectedMoveSupplementPlanner` owns selected move filtering/merge by
  `orderToken`; `SelectionDecorationPlanner` owns selection UI decoration with
  bounds revision and preview movement facts
  (`docs/implementation/p9_frame_rendering_and_caches.md:58`,
  `docs/implementation/p9_frame_rendering_and_caches.md:62`,
  `docs/implementation/p9_frame_rendering_and_caches.md:63`).
- **Dependencies**: P9 requires selected supplement staging, selection
  decoration through captured selection facts, and exclusion of selection state
  from ordinary paint-plan keys (`docs/implementation/p9_frame_rendering_and_caches.md:22`,
  `docs/implementation/p9_frame_rendering_and_caches.md:23`,
  `docs/implementation/p9_frame_rendering_and_caches.md:33`).
- **Data flow**: implementation-phase docs -> frame collaborator ownership and
  test expectations.

P10 docs include move/select/marquee state machines, selected move main-scene
preview, delta-only selected move preview payload, resolver rules, and selected
move commit/cancel (`docs/implementation/p10_selection_and_move.md:20`,
`docs/implementation/p10_selection_and_move.md:21`,
`docs/implementation/p10_selection_and_move.md:22`,
`docs/implementation/p10_selection_and_move.md:24`). P10 also states selected
move preview increments main repaint, not overlay repaint
(`docs/implementation/p10_selection_and_move.md:173`,
`docs/implementation/p10_selection_and_move.md:174`).

The donor registry maps frame donors to ordered paint plan, selected
supplements, preview shifted bounds, and merge without global sort
(`docs/_registry/donors.yaml:642`, `docs/_registry/donors.yaml:650`). It maps
`interaction_move_session` to move preview, marquee selection, commit-on-up, and
cancel restore, while excluding legacy selection ownership and direct hit-test
or store reads from copy (`docs/_registry/donors.yaml:1215`,
`docs/_registry/donors.yaml:1224`, `docs/_registry/donors.yaml:1225`).

## Code References

- `lib/src/frame/selection_decoration_planner.dart:113` - per-selected-element
  primitive generation.
- `lib/src/frame/selection_decoration_planner.dart:155` - selection decoration
  bounds helper.
- `lib/src/surface/main_painter.dart:25` - main record paint loop.
- `lib/src/surface/main_painter.dart:35` - selection decorations painted after
  main records.
- `lib/src/frame/frame_engine.dart:97` - captured main frame and ordinary plan
  assembly.
- `lib/src/frame/frame_engine.dart:107` - selection decoration plan assembly.
- `lib/src/interaction/interaction_engine.dart:386` - selected-move admission
  on pointer down.
- `lib/src/interaction/interaction_engine.dart:512` - pointer move requires an
  active session.
- `lib/src/interaction/move_machine.dart:15` - selected-move start rejection
  predicates.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:42` - selected-move
  start facts construction.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:72` - hit selected
  movable computation.
- `lib/src/runtime/runtime_interaction_move_read_models.dart:16` -
  commit-time selected move read models compute selection bounds.
- `lib/src/geometry/hit_test_policy.dart:21` - topmost exact object hit path.
- `legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:31` -
  legacy per-selected-node selection drawing loop.
- `legacy/iwb_canvas_engine/lib/src/render/selection_halo_compositing.dart:37` -
  legacy bounded rect halo clears interior.
- `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart:122` -
  legacy selected-move start uses top-node hit-test.
- `docs/contracts/frame_rendering.md:152` - current frame contract selection
  decoration owner row.
- `docs/diagrams/seq_selected_move_preview_commit.mmd:37` - documented selected
  move start read facts.

## Search Coverage

- **Inspected**:
  `lib/src/frame/selection_decoration_planner.dart`,
  `lib/src/surface/main_painter.dart`, `lib/src/frame/frame_engine.dart`,
  `lib/src/frame/frame_paint_output.dart`, `lib/src/frame/render_element_record.dart`,
  `lib/src/geometry/geometry_policy.dart`, `lib/src/interaction/interaction_read_port.dart`,
  `lib/src/interaction/move_machine.dart`, `lib/src/interaction/interaction_engine.dart`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart`,
  `lib/src/runtime/runtime_interaction_move_read_models.dart`,
  `lib/src/geometry/hit_test_policy.dart`,
  `test/frame/fixtures/selection_decoration_plan_fixture.dart`,
  `test/interaction/fixtures/move_machine_fixture.dart`,
  `test/interaction/fixtures/interaction_read_port_fixture.dart`,
  `docs/contracts/frame_rendering.md`,
  `docs/implementation/p9_frame_rendering_and_caches.md`,
  `docs/implementation/p10_selection_and_move.md`,
  `docs/diagrams/seq_selected_move_preview_commit.mmd`,
  `docs/diagrams/state_selected_move.mmd`,
  `docs/_registry/donors.yaml`,
  `legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart`,
  `legacy/iwb_canvas_engine/lib/src/render/selection_halo_compositing.dart`,
  `legacy/iwb_canvas_engine/lib/src/render/scene_painter_shell.dart`,
  `legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_overlay_painter.dart`,
  `legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_session.dart`.

- **Searched**:
  `SelectionDecorationPrimitive`, `SelectionDecorationPlan`,
  `selectionDecorationPlan`, `paintSelection`, `selection chrome`,
  `group selection`, `union selection`, `inside selection`, `orderToken`,
  `mainFrameRecordsInPaintOrder`, `selectedMoveStartFacts`,
  `SelectedMoveStartFacts`, `hitSelectedMovable`, `movableSelectedIds`,
  `selectionBoundsWorld`, `CanvasSelectedMovePreview`, `moveSelection`,
  `topmostHit`, `selected move`, `selection bounding box`, `bounding box`,
  `drag selected group`, `selected group`, `per-element`, `per element`,
  `group decoration`, `selection frame`, `z-order`, `z order`, `paint order`,
  `marquee`.

- **Not found**:
  Existing current-package group selection union primitive; existing
  current-package inside-frame special case for rect/image selection
  decoration; existing current-package test asserting upper scene objects
  overlap selection chrome; direct legacy/docs hits for `selection chrome`,
  `group selection chrome`, `group selection`, `drag selected group`,
  `bounding box interior`, `inside selection frame`, `selection frame interior`,
  `per-element selection`, `per element selection`, `group decoration`, or
  `selection bounding box`.

- **Not inspected**:
  Generated build output and `.dart_tool` output were not inspected because the
  research question concerns repository source, docs, tests, and legacy source.

## Observed Architecture Facts

- **Pattern observed**: Selection decoration is separate from ordinary paint
  records. The frame contract states ordinary paint excludes selection state
  (`docs/contracts/frame_rendering.md:157`), while `SelectionDecorationPlanner`
  owns selection UI decoration (`docs/contracts/frame_rendering.md:152`).

- **Data flow observed**: Selected ids in captured frame facts ->
  `SelectionDecorationPlanner._primitivesFor` ->
  `SelectionDecorationPlan.primitives` -> `MainFramePainter._paintSelectionDecorations`
  (`lib/src/frame/selection_decoration_planner.dart:113`,
  `lib/src/frame/selection_decoration_planner.dart:122`,
  `lib/src/surface/main_painter.dart:35`).

- **Pattern observed**: Current multi-select decoration is per-element because
  `_primitivesFor` yields one primitive for each selected element facts row
  (`lib/src/frame/selection_decoration_planner.dart:118`,
  `lib/src/frame/selection_decoration_planner.dart:122`).

- **Pattern observed**: Current selection chrome is painted after all main
  records because `_paintSelectionDecorations` is called after the record loop
  (`lib/src/surface/main_painter.dart:25`,
  `lib/src/surface/main_painter.dart:35`).

- **Data flow observed**: Pointer down in move mode -> selected-move start
  facts -> `MoveMachine.start` -> selected-move session or marquee fallback
  (`lib/src/interaction/interaction_engine.dart:386`,
  `lib/src/interaction/interaction_engine.dart:390`,
  `lib/src/interaction/move_machine.dart:15`).

- **Pattern observed**: Current selected-move start is tied to topmost selected
  movable object hit. The read adapter computes `hitSelectedMovable` from
  topmost hit id membership in movable selected ids
  (`lib/src/runtime/runtime_interaction_read_adapter.dart:72`), and
  `MoveMachine.start` rejects when that fact is false
  (`lib/src/interaction/move_machine.dart:15`).

- **Legacy pattern observed**: Legacy selection drawing was also per-selected
  node and painted after node layers
  (`legacy/iwb_canvas_engine/lib/src/render/scene_painter_selection.dart:31`,
  `legacy/iwb_canvas_engine/lib/src/render/scene_painter_shell.dart:48`).

## Open Questions

- No existing source in the inspected current, docs, or legacy scope defines a
  group-selection union chrome contract.
- No existing source in the inspected current, docs, or legacy scope defines
  bounding-box-interior selected group drag admission.
- No existing source in the inspected current, docs, or legacy scope defines an
  inside-selection-frame rule for rect/image selection decoration.
