language: russian

# Шаг 25. Сделать `ScenePainter` тонким orchestration shell без painter `part`-coupling

## 1. Change Mandate

Этот шаг завершает render-layer architecture by turning `ScenePainter` into a
thin orchestration shell and replacing painter-local `part` coupling with
explicit private module boundaries.

## 2. Change Boundary

### Included in the Change

- Final painter-shell cleanup inside `ScenePainter`.
- Removal of painter-local `part` coupling across frame, node-render, and
  selection owners.
- Targeted creation of private painter-local shared contracts/helpers only
  where they are required to remove `part` coupling without reopening owner
  boundaries.
- Architecture and roadmap updates required by the final painter-shell change.

### Not Included in the Change

- View and shared render-surface work in `SceneViewInteractive` or
  `SceneViewRenderSurface`.
- New render-feature work or new public `ScenePainter` API surface.
- Render-cache lifecycle work in `SceneRenderCaches` or view owners.
- Cleanup in `scene_spatial_index.dart` or `node_geometry.dart`.
- Selection residual `SLOC` cleanup as a standalone concern.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/render/scene_painter.dart`
- `lib/src/render/scene_painter_shell.dart`
- `lib/src/render/scene_painter_contract.dart`
- `lib/src/render/scene_painter_shared.dart`
- `lib/src/render/scene_painter_frame.dart`
- `lib/src/render/scene_painter_node_renderer.dart`
- `lib/src/render/scene_painter_selection.dart`

### Test Files

- `test/render/scene_painter_test.dart`
- `test/render/scene_painter_bounds_contract_test.dart`
- `test/render/scene_painter_frame_contract_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_25_scene_painter_shell_finalization.md`

### Analysis Area

- `lib/src/render/scene_painter*.dart`
- `lib/src/view/**`
- `lib/src/render/**`
- `lib/src/core/scene_spatial_index.dart`
- `lib/src/core/node_geometry.dart`
- `test/render/**`
- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_25_scene_painter_shell_finalization.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to the painter-shell slice.
- Every new or modified test must be tied to a listed render verification.
- Every modified planning or architecture document must be tied to this final
  painter-shell step.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `ScenePainter` remains the public render entrypoint and this step must not
   introduce a new public painter API surface.
2. View-owned render-cache lifecycle remains outside the painter shell.
3. Frame, node-render, and selection ownership remain separate after this
   change.
4. Clone-driven refactoring is not part of this step because
   `tool/analysis/find_similar_clones.dart` currently reports no similar
   fragments in the analyzed zone.
5. This step targets physical painter-shell architecture; it must not reopen
   view work, node-family decomposition, or selection-boundary decomposition.
6. Metric improvement is valid only when it follows from deleting painter
   integration coupling or `part`-coupled physical ownership.

## 5. Result Requirements

1. `scene_painter.dart` no longer contains painter-local `part` declarations.
2. `scene_painter.dart` contributes `1` or fewer `HIGH` entries after the
   change.
3. `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
   reports `6` or fewer `HIGH` entries after the change.
4. Frame, node-render, and selection modules still consume frame-resolved data
   and do not reopen direct `RenderGeometryCache` lookup inside their own
   logic.
5. `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
   still reports no similar fragments.
6. Public `ScenePainter` construction, paint output, and
   `shouldRepaint(...)` behavior remain unchanged.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The current analyzed zone baseline is `7 HIGH` entries.
- The current render cluster contributes `3 HIGH` entries, the current view
  cluster contributes `3 HIGH` entries, and the current core cluster
  contributes `1 HIGH` entry.
- `scene_painter.dart` currently contributes `2 HIGH` entries:
  - file imports `14`
  - class coupling `20`
- `scene_painter_selection.part.dart` currently contributes `1 HIGH` entry:
  local function `SLOC 42`.
- The current painter-local physical architecture still uses `part`
  declarations across `scene_painter.dart`, `scene_painter_frame.part.dart`,
  `scene_painter_node_renderer.part.dart`, and
  `scene_painter_selection.part.dart`.
- Painter-local frame, node-render, and selection modules currently share
  helper types and functions through the `part`-coupled library surface.
- `test/render/scene_painter_test.dart` already protects paint parity,
  preview-delta behavior, grid/background behavior, cache behavior, and
  `shouldRepaint(...)`.
- `test/render/scene_painter_bounds_contract_test.dart` already protects
  frame-local geometry and `localPath` consumption.
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
  currently returns `No similar fragments found.`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/render/scene_painter*.dart --report-all`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
- `dart run tool/check_import_boundaries.dart`
- `flutter analyze`
- `rg -n "^part 'scene_painter_|^part of 'scene_painter" lib/src/render/scene_painter*.dart`
- MCP test runner: `test/render`

### 6.3 Protected States, Data, or Structures

- `ScenePainter` constructor contract and `shouldRepaint(...)` behavior.
- Grid/background output behavior.
- Frame-local geometry reuse and preview-delta application.
- Node-family render parity for rect/path, line/stroke, text, and image.
- Selection render parity and selection-local cache behavior.

### 6.4 Allowed Semantic Change Zones

- Painter-shell orchestration and repaint-configuration ownership.
- Explicit private painter-local contracts/helpers required to remove
  `part` coupling.
- Physical imports and module boundaries between frame, node-render, and
  selection render modules.
- Painter-local helper ownership for shared draw math that is reused across
  painter modules.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- Painter-local `part` coupling must be replaced with explicit private module
  dependencies; new public exports are forbidden.
- If a new shared private painter-local module is introduced, it must own only
  contracts/helpers that are used by multiple painter modules.
- Frame, node-render, and selection modules must continue to consume
  frame-resolved data; direct `RenderGeometryCache` lookup or geometry parsing
  inside those modules is forbidden.
- Metric closure is evaluated against the current thresholds in
  `analysis_options.yaml` and the full analyzed zone listed in this contract.
- The clone tool remains diagnostic only; with a zero-clone baseline, this
  step is not allowed to add abstraction layers justified only by potential
  future clone reuse.

### 6.8 Prohibited

- Reopening view-layer boundary work or changing `lib/src/view/**`.
- Re-merging frame, node-render, and selection ownership back into one mixed
  painter owner.
- Introducing generic painter hierarchies, registries, or public helper APIs.
- Changing render output, cache semantics, or repaint behavior solely to
  reduce metrics.
- Leaving `part` declarations in place behind a newly added shell layer.

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

### Slice 1. [x] Finalize `ScenePainter` as a thin orchestration shell

#### Slice Contract

`ScenePainter` becomes a thin orchestration shell over explicit private
frame/node/selection modules, and the measured render/view `HIGH` count drops
within the contract target without behavior drift.

#### Change

Remove painter-local `part` coupling, move shared painter-local
contracts/helpers behind explicit private module boundaries, and keep
`scene_painter.dart` as the thin public shell over frame, node-render, and
selection owners.

#### Verification

- `dcm calculate-metrics lib/src/render/scene_painter*.dart --report-all`
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart`
- `dart run tool/check_import_boundaries.dart`
- `flutter analyze`
- `rg -n "^part 'scene_painter_|^part of 'scene_painter" lib/src/render/scene_painter*.dart`
- MCP test runner: `test/render`

#### Positive Scenarios

- `ScenePainter` still renders grid/background, nodes, and selection through
  the same frame-resolved data flow.
- `shouldRepaint(...)` still reacts to the same public constructor fields.
- Node, selection, and frame modules remain physically separate and explicit.

#### Negative Scenarios

- Painter-local modules do not reopen geometry lookup or selection/node
  semantics through new integration glue.
- No new similar fragments appear in the analyzed zone.

#### Closure Evidence

- Green run of the listed verifications.
- `dcm calculate-metrics lib/src/view lib/src/render lib/src/core/scene_spatial_index.dart lib/src/core/node_geometry.dart --report-all`
  reports `6` or fewer `HIGH` entries.
- `scene_painter.dart` contributes `1` or fewer `HIGH` entries.
- `rg -n "^part 'scene_painter_|^part of 'scene_painter" lib/src/render/scene_painter*.dart`
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
