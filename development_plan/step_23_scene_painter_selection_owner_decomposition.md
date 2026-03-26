language: russian

# Шаг 23. Разрезать `ScenePainter` selection owner на атомарные render-local owners

## 1. Change Mandate

Этот шаг разрезает mixed-responsibility selection hotspot inside
`ScenePainter`, so the main render `HIGH` cluster drops by deleting one fat
owner instead of shifting the same logic behind new wrappers.

## 2. Change Boundary

### Included in the Change

- Selection-local ownership decomposition inside `ScenePainter`.
- Targeted supporting changes in painter-local frame data only where they are
  required to feed the new selection boundary.
- Architecture and roadmap updates required by the render-owner change.

### Not Included in the Change

- View and shared render-surface work in `SceneViewInteractive` or
  `SceneViewRenderSurface`.
- Node-renderer decomposition outside the selection boundary.
- `part`-to-library migration for `ScenePainter`.
- Spatial-index or `node_geometry.dart` cleanup.
- Public API changes in `ScenePainter` constructor, exports, or repaint
  contract.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_frame.part.dart`
- `lib/src/render/scene_painter_selection.part.dart`

### Test Files

- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_23_scene_painter_selection_owner_decomposition.md`

### Analysis Area

- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_frame.part.dart`
- `lib/src/render/scene_painter_selection.part.dart`
- `lib/src/view/**`
- `lib/src/render/**`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`
- `test/render/**`
- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_23_scene_painter_selection_owner_decomposition.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to the selection-hotspot
  slice.
- Every new or modified test must be tied to a listed render verification.
- Every modified planning or architecture document must be tied to this
  selection-owner step.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneViewInteractive` and `SceneViewRenderSurface` are not reopened in this
   step.
2. Clone-driven refactoring is not part of this step because
   `tool/analysis/find_similar_clones.dart` currently reports no similar
   fragments in the analyzed zone.
3. `ScenePainter` remains a render-local boundary and this step must not
   introduce a generic renderer hierarchy or a new public API surface.
4. Selection rendering continues to consume `_PaintFrame` and
   `_ResolvedNodePaintData`; the selection boundary must not reopen geometry
   resolution inside its own logic.
5. This step targets the selection cluster only; node-renderer decomposition
   and `part`-to-library boundary work remain separate follow-up work.
6. Metric improvement is valid only when it follows from deleting mixed
   selection ownership.

## 5. Result Requirements

1. `_ScenePainterSelectionOwner` no longer exists as the single owner for
   marquee draw, node-family dispatch, path contour selection, and halo
   primitives.
2. Selection rendering still uses frame-resolved `localPath` and `worldBounds`;
   selection code does not parse geometry or query `RenderGeometryCache`
   directly.
3. `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
   reports `9` or fewer `HIGH` entries after the change.
4. The `ScenePainter` selection boundary contributes `2` or fewer `HIGH`
   entries after the change.
5. `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
   still reports no similar fragments.
6. Public `ScenePainter` construction, `shouldRepaint(...)`, and selection
   rendering behavior remain unchanged.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The current analyzed zone baseline is `14 HIGH` entries.
- The current render cluster contributes `10 HIGH` entries, the current view
  cluster contributes `3 HIGH` entries, and the current core cluster
  contributes `1 HIGH` entry.
- `scene_painter_selection.part.dart` currently contributes `7 HIGH` entries.
- `scene_painter_selection.part.dart` currently mixes marquee rect draw,
  node-family dispatch, line/stroke/path/world-bounds selection rendering, and
  halo primitive ownership inside one class.
- `test/render/scene_painter_bounds_contract_test.dart` already protects the
  selection boundary from reopening geometry/cache lookup inside selection
  code.
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
  currently returns `No similar fragments found.`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/render/scene_painter.dart lib/src/render/scene_painter_frame.part.dart lib/src/render/scene_painter_selection.part.dart --report-all`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
- `dart run tool/check_import_boundaries.dart`
- `flutter analyze`
- `rg -n "class _ScenePainterSelectionOwner" lib/src/render`
- MCP test runner: `test/render`

### 6.3 Protected States, Data, or Structures

- Marquee selection rectangle rendering in view space.
- Selection rendering parity for background-layer and content-layer nodes.
- Preview-delta parity between node rendering and selection halos.
- Frame-local geometry reuse and selection-local cache usage for stroke/path
  selection.
- `ScenePainter` constructor and `shouldRepaint(...)` behavior.
- Canvas save-stack balance around preview and selection scopes.

### 6.4 Allowed Semantic Change Zones

- Selection dispatch for resolved nodes.
- Marquee selection rectangle rendering.
- Selection-specific line, stroke, path, and world-bounds renderers.
- Selection-local halo primitive ownership.
- Selection-facing data flow from `_PaintFrame` into selection rendering.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- If selection responsibilities move between private units, the replaced mixed
  bodies must be deleted rather than forwarded through a compatibility layer.
- New helpers introduced by this step must stay private to `render/` and must
  not be exported from `scene_painter.dart`.
- Selection code must continue to use `resolvedNode.geometry.localPath` and
  `resolvedNode.geometry.worldBounds`; direct geometry parsing or direct
  `RenderGeometryCache` lookup inside selection code is forbidden.
- Metric closure is evaluated against the current thresholds in
  `analysis_options.yaml` and the full analyzed zone listed in this contract.
- The clone tool remains diagnostic only; with a zero-clone baseline, this
  step is not allowed to add abstraction layers justified only by potential
  future clone reuse.

### 6.8 Prohibited

- Reopening view-layer boundary work or changing `lib/src/view/**`.
- Moving selection behavior into controller, view, or a new public render
  surface.
- Introducing generic renderer base classes, strategy registries, or
  configuration bags for selection drawing.
- Changing selection visuals, cache semantics, or preview parity solely to
  reduce metrics.
- Adding new wrapper layers or aliases without deleting the mixed owner they
  replace.

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

### Slice 1. [ ] Decompose the `ScenePainter` selection hotspot

#### Slice Contract

`ScenePainter` selection rendering is owned by focused render-local units
instead of one mixed owner, and the measured `HIGH` cluster drops within the
contract target without behavior drift.

#### Change

Split `scene_painter_selection.part.dart` so marquee draw, node-family
dispatch, selection geometry rendering, and halo primitives stop living under
one `_ScenePainterSelectionOwner`, keeping the frame-fed geometry contract and
`ScenePainter` public shape intact.

#### Verification

- `dcm calculate-metrics lib/src/render/scene_painter.dart lib/src/render/scene_painter_frame.part.dart lib/src/render/scene_painter_selection.part.dart --report-all`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
- `dart run tool/check_import_boundaries.dart`
- `flutter analyze`
- `rg -n "class _ScenePainterSelectionOwner" lib/src/render`
- MCP test runner: `test/render`

#### Positive Scenarios

- Marquee selection rectangle still paints in view space.
- Selected background-layer and content-layer nodes keep preview-delta and
  selection parity.
- Path and stroke selection still preserve local cache usage and halo output.

#### Negative Scenarios

- Selection rendering does not reopen geometry lookup or path building inside
  the selection boundary.
- No new similar fragments appear in the analyzed zone.

#### Closure Evidence

- Green run of the listed verifications.
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
  reports `9` or fewer `HIGH` entries.
- The `ScenePainter` selection boundary contributes `2` or fewer `HIGH`
  entries.
- `rg -n "class _ScenePainterSelectionOwner" lib/src/render` returns no
  matches.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/controller/internal`
- MCP test runner:
  `test/controller/core test/controller/commands test/controller/scene_invariants_test.dart test/controller/scene_snapshot_invariant_assertions_test.dart test/controller/scene_controller_randomized_txn_test.dart`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test` with MCP root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
