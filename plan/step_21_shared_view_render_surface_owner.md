language: russian

# Шаг 21. Ввести shared view render-surface boundary для `SceneViewCore` и `SceneViewInteractive`

## 1. Change Mandate

Этот шаг вводит одну внутреннюю shared view render-surface boundary, которая
становится единственным owner-ом view-side render-cache lifecycle и
`ScenePainter` assembly для `SceneViewCore` и `SceneViewInteractive`, не
смешивая в эту boundary pointer host и overlay concerns.

## 2. Change Boundary

### Included in the Change

- Shared render-surface boundary inside the view layer.
- Migration of `SceneViewCore` to the shared render-surface boundary.
- Migration of `SceneViewInteractive` to the same shared render-surface
  boundary.
- Structural tests and assertions that prove wrapper states no longer own
  render-cache lifecycle and do not instantiate `ScenePainter` directly.

### Not Included in the Change

- Pointer admission, flush/timer lifecycle, pointer routing, or pointer slot
  ownership.
- Overlay painter behavior.
- Core geometry, spatial index, hit-test, serialization, or controller
  orchestration.
- Rebaseline and roadmap-only work from `20.5`.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/view/scene_view.dart`
- `lib/src/view/scene_view_interactive.dart`
- `lib/src/view/scene_view_render_surface.dart`
- `lib/src/render/scene_painter.dart`

### Test Files

- `test/view/scene_view_test.dart`
- `test/view/scene_view_interactive_test.dart`
- `test/render/scene_painter_test.dart`
- `test/render/scene_render_caches_test.dart`

### Analysis Area

- `lib/src/view/**`
- `lib/src/render/scene_painter.dart`
- `test/view/**`
- `test/render/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every modified test must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step starts only after `20.5` is closed and the render/view roadmap is
   rebaselined from measured data.
2. Shared render-surface ownership stays internal to the view layer.
3. Existing `SceneViewRenderCacheLifecycle` remains the cache lifecycle helper
   and is reused rather than duplicated.
4. A helper-owner that only proxies `SceneViewRenderCacheLifecycle` and exposes
   a fat `buildPainter(...)` forwarding wrapper is a rejected form for this
   step.
5. No generic renderer hierarchy or proxy layer is introduced for the primary
   purpose of metric reduction.

## 5. Result Requirements

1. `_SceneViewCoreState` no longer owns `SceneViewRenderCacheLifecycle`.
2. `_SceneViewCoreState` no longer instantiates `ScenePainter` directly.
3. `_SceneViewInteractiveState` no longer owns
   `SceneViewRenderCacheLifecycle`.
4. `_SceneViewInteractiveState` no longer instantiates `ScenePainter`
   directly.
5. One internal shared view render-surface boundary is the single source of
   truth for view-side render-cache lifecycle and `ScenePainter` assembly used
   by both wrappers.
6. Pointer routing, flush timing, and overlay painting remain outside the
   shared render-surface boundary.
7. Public behavior and public API remain unchanged.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current ownership of `SceneViewRenderCacheLifecycle` in `SceneViewCore` and
  `SceneViewInteractive`.
- Current direct `ScenePainter` assembly in both wrapper files.
- Shared render-surface boundary that can own the render surface itself instead
  of returning a forwarded `ScenePainter`.
- Pointer host and overlay adoption points that must stay outside the shared
  boundary.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/view lib/src/render --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "SceneViewRenderCacheLifecycle|ScenePainter\\(" lib/src/view/scene_view.dart`
- `rg -n "SceneViewRenderCacheLifecycle|ScenePainter\\(" lib/src/view/scene_view_interactive.dart`
- MCP test runner: `test/view`
- MCP test runner: `test/render`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Render output.
- Selection overlay behavior.
- Pointer routing and flush timing.
- View cache lifecycle ownership.
- Public API surface.

### 6.4 Allowed Semantic Change Zones

- Shared render-surface boundary inside the view layer.
- Wrapper adoption points in `SceneViewCore` and `SceneViewInteractive`.
- Structural assertions that prove the wrappers stopped owning render-cache
  lifecycle and direct `ScenePainter` construction.
- Direct supporting render/view glue required to let both wrappers consume the
  same render-surface boundary.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct wrapper ownership of `SceneViewRenderCacheLifecycle`;
- direct wrapper construction of `ScenePainter`;
- private helper-owner that forwards the `ScenePainter` constructor;
- fat parameter-bag builder that only repackages the render-surface arguments.

### 6.6 Allowed Forms That Do Not Count as Violations

- an internal shared render-surface widget or stateful view component that owns
  the render surface itself;
- reuse of `SceneViewRenderCacheLifecycle` inside that shared render-surface
  boundary;
- wrapper-level ownership of pointer host or overlay concerns outside the
  shared render-surface boundary.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The shared render-surface boundary must own the render surface itself and may
  not be implemented as a helper object whose primary output is a forwarded
  `ScenePainter`.
- `SceneViewCore` and `SceneViewInteractive` wrappers must consume the shared
  boundary instead of assembling the render surface in their own state classes.
- Slice 1 is not closed unless `_SceneViewCoreState` no longer contains
  `SceneViewRenderCacheLifecycle` ownership and no longer constructs
  `ScenePainter` directly.
- Slice 2 is not closed unless `_SceneViewInteractiveState` no longer contains
  `SceneViewRenderCacheLifecycle` ownership and no longer constructs
  `ScenePainter` directly.
- If these conditions cannot be achieved without a proxy or plumbing layer, the
  step must stop as not satisfiable in its current formulation.

### 6.8 Prohibited

- Introducing a helper-owner that only proxies `SceneViewRenderCacheLifecycle`.
- Introducing a `buildPainter(...)` wrapper or any equivalent fat forwarding
  method for the primary purpose of moving `ScenePainter` assembly out of the
  wrapper files.
- Moving pointer host or overlay behavior into the shared render-surface
  boundary.
- Moving view cache lifecycle into controller or render-global owners.
- Changing public behavior solely to reduce metrics.

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

### Slice 1. [x] Migrate `SceneViewCore` to the shared render-surface boundary

#### Slice Contract

`SceneViewCore` consumes the shared render-surface boundary and
`_SceneViewCoreState` no longer owns render-cache lifecycle or direct
`ScenePainter` assembly.

#### Change

Introduce the internal shared render-surface boundary and route
`SceneViewCore` through it so the wrapper state stops owning
`SceneViewRenderCacheLifecycle` and stops constructing `ScenePainter`
directly.

#### Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `dcm calculate-metrics lib/src/view lib/src/render --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `rg -n "SceneViewRenderCacheLifecycle|ScenePainter\\(" lib/src/view/scene_view.dart`
- MCP test runner: `test/view`
- MCP test runner: `test/render`

#### Closure Evidence

- Green run of the listed verifications.
- `_SceneViewCoreState` no longer owns `SceneViewRenderCacheLifecycle`.
- `_SceneViewCoreState` no longer constructs `ScenePainter` directly.

### Slice 2. [x] Migrate `SceneViewInteractive` to the shared render-surface boundary

#### Slice Contract

`SceneViewInteractive` consumes the same shared render-surface boundary and
`_SceneViewInteractiveState` no longer owns render-cache lifecycle or direct
`ScenePainter` assembly while pointer host and overlay remain outside the
boundary.

#### Change

Route `SceneViewInteractive` through the same shared render-surface boundary
and keep `SceneViewInteractivePointerHost` and
`SceneViewInteractiveOverlayPainter` outside that boundary.

#### Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `dcm calculate-metrics lib/src/view lib/src/render --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `rg -n "SceneViewRenderCacheLifecycle|ScenePainter\\(" lib/src/view/scene_view_interactive.dart`
- MCP test runner: `test/view`
- MCP test runner: `test/render`

#### Closure Evidence

- Green run of the listed verifications.
- `_SceneViewInteractiveState` no longer owns `SceneViewRenderCacheLifecycle`.
- `_SceneViewInteractiveState` no longer constructs `ScenePainter` directly.
- Pointer host and overlay ownership remain outside the shared render-surface
  boundary.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/view lib/src/render --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "SceneViewRenderCacheLifecycle|ScenePainter\\(" lib/src/view/scene_view.dart`
- `rg -n "SceneViewRenderCacheLifecycle|ScenePainter\\(" lib/src/view/scene_view_interactive.dart`
- MCP test runner: `test/view`
- MCP test runner: `test/render`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
