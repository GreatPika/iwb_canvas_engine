language: russian

# Шаг 24. Разрезать `ScenePainter` node renderer на атомарные render-local owners

## 1. Change Mandate

Этот шаг разрезает mixed-responsibility node-render hotspot inside
`ScenePainter`, so node-family rendering stops living under one fat render
owner and the measured render/view `HIGH` count drops again without reopening
view or selection work.

## 2. Change Boundary

### Included in the Change

- Node-render ownership decomposition inside `ScenePainter`.
- Targeted supporting changes in `ScenePainter` and frame-fed node render data
  flow only where they are required to feed the new node-render boundary.
- Architecture and roadmap updates required by the node-render owner change.

### Not Included in the Change

- View and shared render-surface work in `SceneViewInteractive` or
  `SceneViewRenderSurface`.
- Selection-boundary refactoring outside node-render feed changes.
- `part`-to-library migration for `ScenePainter`.
- Cleanup in `scene_spatial_index.dart` or `node_geometry.dart`.
- Public API changes in `ScenePainter` constructor, exports, or repaint
  contract.
- Work whose only purpose is reducing `scene_painter.dart` import count.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_frame.part.dart`
- `lib/src/render/scene_painter_node_renderer.part.dart`

### Test Files

- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_24_scene_painter_node_renderer_decomposition.md`

### Analysis Area

- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_frame.part.dart`
- `lib/src/render/scene_painter_node_renderer.part.dart`
- `lib/src/view/**`
- `lib/src/render/**`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`
- `test/render/**`
- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_24_scene_painter_node_renderer_decomposition.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to the node-render hotspot
  slice.
- Every new or modified test must be tied to a listed render verification.
- Every modified planning or architecture document must be tied to this
  node-render step.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneViewInteractive` and `SceneViewRenderSurface` are not reopened in this
   step.
2. Clone-driven refactoring is not part of this step because
   `tool/analysis/find_similar_clones.dart` currently reports no similar
   fragments in the analyzed zone.
3. `ScenePainter` remains a render-local boundary and this step must not
   introduce a generic renderer hierarchy, strategy registry, or new public
   API surface.
4. Node rendering continues to consume frame-resolved data; the node-render
   boundary must not reopen geometry resolution or direct
   `RenderGeometryCache` lookup inside its own logic.
5. This step targets the node-render cluster only; `scene_painter.dart`
   integration-shell cleanup and selection residual cleanup remain separate
   follow-up work.
6. Metric improvement is valid only when it follows from deleting mixed
   node-render ownership.

## 5. Result Requirements

1. `_ScenePainterNodeRenderer` no longer exists as the single owner for
   rect/path, line/stroke, text, and image rendering.
2. Node rendering still consumes frame-resolved `localPath` and
   `resolvedNode.previewDelta`; node-render code does not query
   `RenderGeometryCache` directly.
3. `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
   reports `7` or fewer `HIGH` entries after the change.
4. The `ScenePainter` node-render boundary contributes `0 HIGH` entries after
   the change.
5. `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
   still reports no similar fragments.
6. Public `ScenePainter` construction, node render output, and
   `shouldRepaint(...)` behavior remain unchanged.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The current analyzed zone baseline is `8 HIGH` entries.
- The current render cluster contributes `4 HIGH` entries, the current view
  cluster contributes `3 HIGH` entries, and the current core cluster
  contributes `1 HIGH` entry.
- `scene_painter_node_renderer.part.dart` currently contributes `1 HIGH`
  entry: class coupling `14`.
- `scene_painter_node_renderer.part.dart` currently mixes rect/path shape
  rendering, line/stroke rendering, text layout rendering, and image
  rendering inside one class.
- `test/render/scene_painter_bounds_contract_test.dart` already protects the
  node-render boundary from reopening frame-local `localPath` lookup.
- `test/render/scene_painter_test.dart` already covers all node families,
  text-direction behavior, image placeholder behavior, preview delta, and
  stroke cache rebuild behavior.
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
  currently returns `No similar fragments found.`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/render/scene_painter.dart lib/src/render/scene_painter_frame.part.dart lib/src/render/scene_painter_node_renderer.part.dart --report-all`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
- `dart run tool/check_import_boundaries.dart`
- `flutter analyze`
- `rg -n "class _ScenePainterNodeRenderer" lib/src/render`
- MCP test runner: `test/render`

### 6.3 Protected States, Data, or Structures

- Node render parity for all supported node families.
- Preview-delta parity between frame-resolved node data and rendered output.
- Frame-local geometry reuse for `PathNodeSnapshot`.
- Text layout behavior, image placeholder behavior, and text-direction
  behavior.
- Stroke path cache usage and rebuild behavior.
- `ScenePainter` constructor and `shouldRepaint(...)` behavior.

### 6.4 Allowed Semantic Change Zones

- Node-family dispatch for resolved nodes.
- Shape-node rendering for rect and path nodes.
- Stroke-node rendering for line and stroke nodes.
- Rich-node rendering for text and image nodes.
- Node-render-facing data flow from `_ResolvedNodePaintData` into node-family
  render helpers.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- If node-render responsibilities move between private units, the replaced
  mixed bodies must be deleted rather than forwarded through a compatibility
  layer.
- New helpers introduced by this step must stay private to `render/` and must
  not be exported from `scene_painter.dart`.
- Node-render code must continue to use `resolvedNode.geometry.localPath` and
  `resolvedNode.previewDelta`; direct geometry parsing or direct
  `RenderGeometryCache` lookup inside node-render code is forbidden.
- Metric closure is evaluated against the current thresholds in
  `analysis_options.yaml` and the full analyzed zone listed in this contract.
- The clone tool remains diagnostic only; with a zero-clone baseline, this
  step is not allowed to add abstraction layers justified only by potential
  future clone reuse.

### 6.8 Prohibited

- Reopening view-layer boundary work or changing `lib/src/view/**`.
- Moving node-render behavior into selection helpers, controller, or a new
  public render surface.
- Introducing generic renderer base classes, strategy registries, or
  configuration bags for node drawing.
- Changing render output, text/image behavior, or cache semantics solely to
  reduce metrics.
- Adding new wrapper layers or aliases without deleting the mixed owner bodies
  they replace.

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

### Slice 1. [x] Decompose the `ScenePainter` node-render hotspot

#### Slice Contract

`ScenePainter` node rendering is owned by focused render-local units instead of
one mixed node-render owner, and the measured `HIGH` cluster drops within the
contract target without behavior drift.

#### Change

Split `scene_painter_node_renderer.part.dart` so node-family dispatch,
shape-node rendering, stroke-node rendering, and rich-node rendering stop
living under one `_ScenePainterNodeRenderer`, keeping the frame-fed node data
contract and `ScenePainter` public shape intact.

#### Verification

- `dcm calculate-metrics lib/src/render/scene_painter.dart lib/src/render/scene_painter_frame.part.dart lib/src/render/scene_painter_node_renderer.part.dart --report-all`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
- `dart run tool/check_import_boundaries.dart`
- `flutter analyze`
- `rg -n "class _ScenePainterNodeRenderer" lib/src/render`
- MCP test runner: `test/render`

#### Positive Scenarios

- All supported node families still render through frame-resolved node data.
- Text-direction, image placeholder, preview delta, and stroke cache behavior
  stay unchanged.
- Path rendering still consumes frame-resolved `localPath`.

#### Negative Scenarios

- Node rendering does not reopen geometry lookup or path building inside the
  node-render boundary.
- No new similar fragments appear in the analyzed zone.

#### Closure Evidence

- Green run of the listed verifications.
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
  reports `7` or fewer `HIGH` entries.
- The `ScenePainter` node-render boundary contributes `0 HIGH` entries.
- `rg -n "class _ScenePainterNodeRenderer" lib/src/render` returns no matches.

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
