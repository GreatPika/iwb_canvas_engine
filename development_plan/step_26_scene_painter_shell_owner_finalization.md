language: russian

# Шаг 26. Довести `ScenePainterShell` до чистого orchestration owner без background/cache assembly

## 1. Change Mandate

Этот шаг завершает render-layer cleanup после шага 25: `ScenePainterShell`
должен остаться только orchestration owner-ом paint pipeline, а background
ownership и assembly тяжесть должны быть вынесены из него так, чтобы
архитектура стала чище и metric delta был следствием этого упрощения.

## 2. Change Boundary

### Included in the Change

- Final cleanup of `ScenePainterShell` as orchestration-only owner.
- Extraction of background/static-grid ownership from `ScenePainterShell`.
- Targeted cleanup of painter-local assembly so shell больше не собирает
  frame/node/selection owners и не держит прямое знание о cache/geometry
  wiring.
- Contract, architecture, and roadmap updates tied to this final render step.

### Not Included in the Change

- Any work in `lib/src/view/**`.
- Public API changes for `ScenePainter`.
- Reopening frame/node/selection decomposition work.
- Cleanup in `scene_spatial_index.dart` or other core hotspots.
- Clone-driven abstractions or speculative render feature work.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_shell.dart`
- `lib/src/render/scene_painter_contract.dart`
- `lib/src/render/scene_painter_shared.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_node_renderer.dart`
- `lib/src/render/scene_painter_selection.dart`
- `lib/src/render/scene_render_caches.dart`
- `lib/src/render/scene_painter_background.dart`

### Test Files

- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_26_scene_painter_shell_owner_finalization.md`

### Analysis Area

- `lib/src/render/scene_painter*.dart`
- `lib/src/render/scene_render_caches.dart`
- `lib/src/view/**`
- `lib/src/render/**`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`
- `test/render/**`
- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which the slice
  verification cannot be closed.

### File Change Rule

- Every modified implementation file must reduce shell ownership or support the
  extracted background/assembly boundary.
- Every new helper or contract must have one clear reason to change.
- Every modified test must validate a contract from this step.
- Untied changes are out of scope.

## 4. Locked Decisions

1. `ScenePainter` remains the public render entrypoint; no new public painter
   API surface is allowed.
2. `ScenePainterShell` must end this step as orchestration-only owner:
   sequence frame creation, background paint, node paint, selection paint.
3. Background/static-grid ownership must live outside `ScenePainterShell`.
4. View-owned render cache lifecycle remains outside render shell logic.
5. This step must not introduce a new generic render hierarchy, registry, or
   speculative stage abstraction.
6. Metric improvement is valid only when it follows from a real separation of
   orchestration, background ownership, and assembly responsibilities.

## 5. Result Requirements

1. `ScenePainterShell` no longer directly constructs frame/node/selection
   owners.
2. `ScenePainterShell` no longer directly imports cache modules,
   `render_geometry_cache.dart`, or `scene_grid_renderer.dart`.
3. Background/static-grid ownership is moved to a dedicated private painter
   module with one clear reason to change.
4. `dcm calculate-metrics lib/src/render/scene_painter*.dart --report-all`
   reports `1` or fewer `HIGH` entries in `scene_painter_shell.dart`.
5. `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
   reports `5` or fewer `HIGH` entries after the change.
6. `scene_painter.dart` remains at `1` or fewer `HIGH` entries.
7. Public `ScenePainter` constructor behavior, paint output, cache semantics,
   and `shouldRepaint(...)` behavior remain unchanged.
8. Clone scan remains empty.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current analyzed-zone baseline is `6 HIGH` entries.
- Current render cluster contributes `2 HIGH` entries, both in
  `scene_painter_shell.dart`:
  - file imports `13`
  - class coupling `15`
- Current view cluster contributes `3 HIGH` entries.
- Current core cluster contributes `1 HIGH` entry in
  `scene_spatial_index.dart`.
- `ScenePainterShell` currently mixes three reasons to change:
  - stage assembly in its constructor
  - paint orchestration in `paint(...)`
  - background/static-grid ownership in `_paintBackground(...)`
- Current `ScenePainterShell` directly imports cache types,
  `render_geometry_cache.dart`, and `scene_grid_renderer.dart`.
- `tool/analysis/find_similar_clones.dart` currently reports no similar
  fragments in the analyzed zone.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/render/scene_painter*.dart --report-all`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `flutter analyze`
- `rg -n "cache/scene_|render_geometry_cache|scene_grid_renderer" lib/src/render/scene_painter_shell.dart`
- MCP test runner: `test/render`

### 6.3 Protected States, Data, or Structures

- Public `ScenePainter` constructor surface.
- `ScenePainter.shouldRepaint(...)` trigger semantics.
- Grid/background output behavior and static layer cache semantics.
- Frame-local geometry reuse and preview-delta behavior.
- Node-family render parity.
- Selection render parity and selection-local cache behavior.

### 6.4 Allowed Semantic Change Zones

- `ScenePainterShell` construction and dependency surface.
- Dedicated painter-local background owner.
- Internal painter-local contracts needed to keep shell orchestration-only.
- Internal painter-local assembly cleanup tied directly to this ownership split.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `ScenePainterShell` must keep only orchestration responsibilities.
- If a new assembly helper is introduced, it must be minimal, private, and
  justified by one reason to change; it must not become a new mixed render
  owner.
- If `scene_render_caches.dart` participates in the cleanup, it must improve
  internal render dependency structure rather than broaden public API.
- No new public exports are allowed.
- Frame/node/selection modules must continue to consume frame-resolved data;
  direct `RenderGeometryCache` lookup/parsing inside node/selection remains
  forbidden.

### 6.8 Prohibited

- Reopening `lib/src/view/**`.
- Moving background policy into `ScenePainterFrameOwner`.
- Re-merging background, frame, node, and selection into one owner.
- Introducing abstraction layers whose only purpose is to appease metrics.
- Changing output, cache semantics, or repaint semantics solely to reduce
  metrics.

## 7. Execution Rules

1. This step closes only if architecture and metrics improve together.
2. Preparatory movement of code without ownership clarification does not count
   as closure.
3. A new helper is valid only when it removes one mixed responsibility from
   the shell.
4. Scope expansion is forbidden until the slice below is green.

## 8. Vertical Slices

### Slice 1. [x] Finalize `ScenePainterShell` as orchestration-only owner

#### Slice Contract

`ScenePainterShell` loses direct background/cache assembly ownership and
becomes a thin orchestrator over dedicated painter-local owners, while the
measured `HIGH` count drops within contract targets without render drift.

#### Change

Extract background/static-grid ownership into a dedicated private painter
module, remove direct stage construction and cache/geometry/grid knowledge from
`ScenePainterShell`, and keep the shell responsible only for paint sequencing.

#### Verification

- `dcm calculate-metrics lib/src/render/scene_painter*.dart --report-all`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `flutter analyze`
- `rg -n "cache/scene_|render_geometry_cache|scene_grid_renderer" lib/src/render/scene_painter_shell.dart`
- MCP test runner: `test/render`

#### Positive Scenarios

- `ScenePainterShell` still sequences frame creation, background paint, node
  paint, and selection paint in the same order.
- Grid/background output and static cache behavior remain unchanged.
- `ScenePainter` public behavior remains unchanged.

#### Negative Scenarios

- `ScenePainterShell` does not regain direct cache or geometry ownership
  through new helper glue.
- No new similar fragments appear in the analyzed zone.

#### Closure Evidence

- Green run of the listed verifications.
- `scene_painter_shell.dart` contributes `1` or fewer `HIGH` entries.
- Full analyzed zone reports `5` or fewer `HIGH` entries.
- `rg -n "cache/scene_|render_geometry_cache|scene_grid_renderer" lib/src/render/scene_painter_shell.dart`
  returns no matches.

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
- MCP test shards:
  - `test/render`
  - `test/view`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
