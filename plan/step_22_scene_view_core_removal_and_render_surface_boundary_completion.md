language: russian

# Шаг 22. Убрать `SceneViewCore` и завершить shared view render-surface boundary

## 1. Change Mandate

Этот шаг удаляет production wrapper `SceneViewCore` и завершает shared view
render-surface boundary so core-mode and interactive-mode render policy are
owned inside `scene_view_render_surface.dart` instead of being assembled by
view wrappers.

## 2. Change Boundary

### Included in the Change

- Removal of production `SceneViewCore` and `_SceneViewCoreState`.
- Migration of former core-mode render policy into the shared render-surface
  owner.
- Adoption of the same semantic render-surface boundary by
  `SceneViewInteractive` without wrapper-level generic policy hooks.
- Migration of core-view tests and debug cache access away from
  `SceneViewCore`-specific state lookup.
- Roadmap and architecture documentation required by the ownership change.

### Not Included in the Change

- Public `SceneView` / `SceneViewInteractive` API behavior.
- Pointer host runtime, pointer routing, or overlay painter semantics.
- Render-local hotspot work in `ScenePainter` and its part files.
- Controller, model, serialization, or example-app workflow changes.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/view/scene_view.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_render_surface.dart`
- `lib/src/view/scene_view_defaults.dart`
- `lib/src/render/scene_painter.dart`

### Test Files

- `test/view/scene_view_test.dart`
- `test/view/scene_view_interactive_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_22_scene_view_core_removal_and_render_surface_boundary_completion.md`
- `analysis_options.yaml`

### Analysis Area

- `lib/src/view/**`
- `lib/src/render/scene_painter.dart`
- `test/view/**`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/step_22_scene_view_core_removal_and_render_surface_boundary_completion.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every modified planning or architecture document must be tied to this
  boundary-removal step.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneView` remains a typedef alias of `SceneViewInteractive`, and
   `SceneViewInteractive` remains part of the exported public runtime API.
2. Pointer host and overlay ownership remain outside the shared render-surface
   boundary.
3. `SceneViewCore` is not part of the exported public API surface.
4. Render-cache lifecycle remains view-owned and must stay inside the shared
   render-surface boundary.
5. This step must not introduce a new base widget hierarchy.
6. This step must not introduce a generic forwarding builder or parameter bag
   whose primary purpose is moving the current render-surface arguments behind
   another indirection layer.

## 5. Result Requirements

1. Production `SceneViewCore` and `_SceneViewCoreState` no longer exist under
   `lib/src/view/**`.
2. Former core-mode render policy previously assembled by `SceneViewCore` is
   owned inside `scene_view_render_surface.dart`.
3. `SceneViewInteractive` no longer decides `readControllerEpoch`,
   `createRenderCaches`, `cacheDependencies`, `nodePreviewOffsetResolver`, or
   `selectionRect` at its wrapper boundary.
4. Core-mode cache lifecycle behavior and debug cache access remain available
   through the replacement core-mode seam.
5. Pointer host and overlay ownership remain outside the shared render-surface
   boundary after the boundary completion.
6. Exported public API symbols remain unchanged.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `scene_view.dart` currently exists only as a core-mode wrapper around
  `SceneViewRenderSurface` plus a debug cache lookup seam.
- `SceneViewCore` has no in-repo production callers outside its own file; its
  current runtime coverage lives in `test/view/scene_view_test.dart`.
- `scene_view_render_surface.dart` currently exposes generic callback-based
  policy hooks from the wrapper boundary.
- `SceneViewInteractive` remains the public interactive shell and must keep
  pointer host and overlay outside the shared render-surface owner.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/view lib/src/render --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "class SceneViewCore|State<SceneViewCore>|_SceneViewCoreState|SceneViewCore\\(" lib test`
- `rg -n "readControllerEpoch|createRenderCaches|cacheDependencies|nodePreviewOffsetResolver|selectionRect" lib/src/view/scene_view_interactive.dart`
- MCP test runner: `test/view`
- MCP test runner: `test/render`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Exported `SceneView` / `SceneViewInteractive` API surface.
- Core-mode render-cache lifecycle behavior.
- View-level debug cache access behavior used by the core-view tests.
- Interactive pointer host and overlay separation from the render-surface owner.

### 6.4 Allowed Semantic Change Zones

- Core-mode render-surface entrypoint and cache ownership previously assembled
  by `SceneViewCore`.
- Interactive wrapper adoption of semantic shared render-surface entrypoints.
- View-level debug cache lookup and missing-state behavior after
  `SceneViewCore` removal.
- Targeted render-type alias ownership required to let the view boundary stop
  importing broader render implementation than necessary.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- This step is not closed unless no production `SceneViewCore` or
  `_SceneViewCoreState` remains under `lib/**`.
- `SceneViewInteractive` must consume semantic shared render-surface
  entrypoints instead of the current generic callback-based constructor shape.
- Pointer host and overlay must remain outside the shared render-surface
  boundary after the migration.
- If render-type aliases move, they must move to a smaller direct owner and
  must not be hidden behind a new wrapper layer.

### 6.8 Prohibited

- Exporting `SceneViewRenderSurface` as a new public runtime view surface.
- Moving pointer host or overlay into `SceneViewRenderSurface`.
- Replacing `SceneViewInteractive` with a combined owner that mixes interactive
  runtime and render-surface lifecycle ownership.
- Keeping a production `SceneViewCore` forwarder class after this step closes.
- Reintroducing wrapper-level generic hook plumbing for core or interactive
  mode after the semantic boundary is introduced.

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

## 8. Vertical Slices

### Slice 1. [x] Remove the production `SceneViewCore` wrapper

#### Slice Contract

Former core-mode render behavior remains available without a production
`SceneViewCore` class or `_SceneViewCoreState`.

#### Change

Move core-mode render policy into `scene_view_render_surface.dart`, delete the
production `SceneViewCore` wrapper shape, and migrate core-mode debug cache
access and tests to the replacement seam.

#### Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `dcm calculate-metrics lib/src/view lib/src/render --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `rg -n "class SceneViewCore|State<SceneViewCore>|_SceneViewCoreState|SceneViewCore\\(" lib test`
- MCP test runner: `test/view/scene_view_test.dart`

#### Positive Scenarios

- Core-mode cache lifecycle still clears on epoch changes and controller swap.
- Core-mode cache ownership still supports owned and external caches.
- Core-mode debug cache lookup still resolves from a descendant render-surface
  context.

#### Negative Scenarios

- Core-mode debug cache lookup still throws an explicit missing-state failure
  when no replacement core-mode seam is mounted.

#### Closure Evidence

- Green run of the listed verifications.
- No production `SceneViewCore` or `_SceneViewCoreState` remains under
  `lib/**`.
- `test/view/scene_view_test.dart` no longer instantiates `SceneViewCore`.

### Slice 2. [x] Thin `SceneViewInteractive` to the semantic render-surface boundary

#### Slice Contract

`SceneViewInteractive` no longer wires generic render-surface policy hooks
while pointer host and overlay stay outside the shared render-surface owner.

#### Change

Adopt semantic shared render-surface entrypoints in
`scene_view_interactive.dart` and remove wrapper-level generic hook plumbing
for interactive mode.

#### Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `dcm calculate-metrics lib/src/view lib/src/render --report-all`
- `dart run tool/check_import_boundaries.dart`
- `rg -n "readControllerEpoch|createRenderCaches|cacheDependencies|nodePreviewOffsetResolver|selectionRect" lib/src/view/scene_view_interactive.dart`
- MCP test runner: `test/view/scene_view_interactive_test.dart`

#### Positive Scenarios

- Interactive render caches still clear on epoch changes and controller swap.
- Image resolver and preview rendering still work through the semantic
  render-surface boundary.
- Overlay remains outside the shared render-surface owner.

#### Negative Scenarios

- Interactive debug cache lookup still throws an explicit missing-state failure
  when no interactive render-surface seam is mounted.

#### Closure Evidence

- Green run of the listed verifications.
- Wrapper-level generic policy hooks are absent from
  `scene_view_interactive.dart`.
- Pointer host and overlay ownership remain outside the shared render-surface
  boundary.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/view lib/src/render --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "class SceneViewCore|State<SceneViewCore>|_SceneViewCoreState|SceneViewCore\\(" lib test`
- `rg -n "readControllerEpoch|createRenderCaches|cacheDependencies|nodePreviewOffsetResolver|selectionRect" lib/src/view/scene_view_interactive.dart`
- MCP test runner: `test/core`
- MCP test runner: `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/controller/internal`
- MCP test runner: `test/controller/core test/controller/commands`
- MCP test runner: controller-root `*_test.dart` files
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
