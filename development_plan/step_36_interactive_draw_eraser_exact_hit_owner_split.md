language: russian

# Шаг 36. Разрезать `InteractiveDrawEraserEngine` на exact-hit owner-ы по node family

## 1. Change Mandate

Этот шаг выносит exact-hit geometry из `InteractiveDrawEraserEngine` в явную
eraser-local boundary и разрезает её на focused owner-ы по node family без
изменения public eraser behavior.

## 2. Change Boundary

### Included in the Change

- Eraser exact-hit ownership beneath `interactive_draw_eraser_engine.dart`.
- Shared projection, world-bounds fallback, and node-family dispatch currently
  mixed into the eraser engine.
- Line-local and stroke-local exact-hit geometry paths.
- Structural non-regression coverage required to pin the tightened eraser
  geometry boundary.

### Not Included in the Change

- Reopening draw-family orchestration in `interactive_draw_coordinator.dart`.
- Reopening coarse candidate query / delete filtering already owned by
  `interactive_draw_eraser_targets.dart`.
- Reopening boundary runtime ownership from steps `32-35`.
- Public API changes for `SceneControllerInteractive`, interactive debug
  counters, or eraser-tool behavior.
- Generic geometry/plugin abstractions outside the eraser-local area.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_targets.dart`
- `lib/src/interactive/internal/interactive_geometry.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_eraser_lifecycle_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixture and Supporting Data Files

- `DEVELOPMENT_PLAN.md`
- `development_plan/step_36_interactive_draw_eraser_exact_hit_owner_split.md`

### Analysis Area

- `lib/src/interactive/internal/interactive_draw_eraser*.dart`
- `lib/src/interactive/internal/interactive_geometry.dart`
- `test/interactive/core/interactive_draw_eraser*_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_eraser*_test.dart`
- `tool/src/guardrails/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must remove exact-hit geometry ownership
  from `InteractiveDrawEraserEngine` or become one focused eraser-local owner
  beneath the new exact-hit boundary.
- Every modified structural test or guardrail must pin the new eraser geometry
  owner graph introduced by this step.
- Any new focused eraser owner created by this step must stay under
  `lib/src/interactive/internal/interactive_draw_eraser*.dart`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `InteractiveDrawEraserEngine` remains the eraser gesture/commit owner.
2. `InteractiveDrawEraserTargets` remains the coarse candidate-query and
   deletable-filter owner.
3. `InteractiveDrawCoordinator` remains a draw-family orchestrator and does not
   re-own eraser geometry.
4. Eraser spatial-query and precise-segment debug counters remain observable
   through the current interactive runtime/controller test path.
5. This step must not introduce a generic geometry platform or draw-tool plugin
   hierarchy.

## 5. Result Requirements

1. `InteractiveDrawEraserEngine` no longer owns shared exact-hit projection,
   world-bounds fallback, or both line/stroke exact-hit bodies in one owner.
2. One explicit eraser-local exact-hit boundary exists beneath
   `InteractiveDrawEraserEngine` for node-family dispatch and shared
   projection/fallback behavior.
3. Separate focused exact-hit owners exist beneath that boundary for line-local
   and stroke-local geometry.
4. Public eraser behavior remains equivalent for:
   singular-transform fallback on line and stroke,
   single-point eraser hits,
   segment-based eraser hits,
   delete eligibility,
   spatial-query and precise-segment debug counters,
   gesture-buffer lifecycle,
   and cancel/reset cleanup.
5. Structural tests and guardrails fail if exact-hit geometry reabsorbs into
   `InteractiveDrawEraserEngine` or `InteractiveDrawCoordinator`.
6. The measured eraser hotspot improves against the current confirmed residual
   scope as evidence of owner transfer, and metric or clone improvement alone
   does not close the step:
   `InteractiveDrawEraserEngine` imports `10`,
   class `RFC 39`,
   `WMC 60`,
   and current clone pairs still include
   `_eraserHitsLine(...)` vs `_eraserHitsStroke(...)`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `InteractiveDrawEraserEngine` currently already delegates buffer lifecycle to
  `InteractiveDrawPathBuffer` and coarse candidate query/filtering to
  `InteractiveDrawEraserTargets`, but it still owns:
  node-family dispatch,
  shared projection to local space,
  world-bounds fallback,
  line exact-hit geometry,
  stroke exact-hit geometry,
  and precise segment-check counting triggers.
- The current mixed exact-hit surface is concentrated in:
  `_eraserHitsNode(...)`,
  `_eraserHitsLine(...)`,
  `_localEraserSegmentsHitLine(...)`,
  `_eraserHitsStroke(...)`,
  `_eraserSegmentsHitStroke(...)`,
  `_projectEraserToLocal(...)`,
  and `_fallbackWorldBoundsHit(...)`.
- Current structural guardrails already pin that
  `InteractiveDrawCoordinator` must not re-own eraser geometry, but they do not
  yet pin an explicit exact-hit split beneath the eraser engine.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/interactive/internal/interactive_draw_eraser*.dart lib/src/interactive/internal/interactive_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/interactive/core/interactive_draw_eraser_engine_test.dart test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart test/interactive/core/scene_controller_interactive_guardrails_eraser_lifecycle_test.dart`
- MCP test runner: `test/interactive`
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Eraser delete eligibility and target ordering.
- Singular-transform fallback behavior for line and stroke.
- Spatial-query and precise-segment debug counters.
- Gesture buffer soft-limit behavior and terminal append behavior.
- Cancel/reset cleanup semantics for eraser-owned state.

### 6.4 Allowed Semantic Change Zones

- Eraser-local exact-hit geometry ownership beneath the existing eraser engine.
- Shared eraser-local projection and world-bounds fallback ownership.
- Node-family-specific exact-hit ownership for line and stroke.
- Structural source-level contract tests and guardrails tied directly to the
  new eraser geometry boundary.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- direct reabsorption of exact-hit geometry into `InteractiveDrawEraserEngine`
- private-helper bypass where extracted exact-hit bodies remain inside the
  engine under renamed private helpers
- helper-only extraction where the same mixed line/stroke geometry remains in
  one owner body behind utility wrappers
- coordinator bypass where `InteractiveDrawCoordinator` regains eraser exact-hit
  geometry after this split

### 6.6 Allowed Forms That Do Not Count as Violations

- `InteractiveDrawEraserEngine` keeping gesture/commit flow, coarse target
  query integration, and debug-counter ownership.
- One explicit eraser-local exact-hit owner dispatching by node family and
  reusing shared projection/fallback logic.
- Separate focused line and stroke exact-hit owners beneath that boundary.
- Precise-segment counter increments delegated through callbacks from focused
  exact-hit owners back to the eraser engine.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- This step starts only after step `35` is closed and must consume the tightened
  public facade boundary instead of reopening it.
- The step is not closed if `InteractiveDrawEraserEngine` keeps shared
  projection/fallback plus both line and stroke exact-hit bodies in the same
  owner, even if helper extraction reduces metrics.
- Any new exact-hit owner created by this step must stay internal to
  `lib/src/interactive/internal/interactive_draw_eraser*.dart`.
- Structural assertions introduced or updated by this step must fail when
  eraser exact-hit geometry returns to `InteractiveDrawEraserEngine` or to
  `InteractiveDrawCoordinator`.
- The step must preserve the current debug-counter observation path through the
  runtime/controller test helpers; moving those counters into a detached debug
  platform does not satisfy the step.
- The step is not closed if precise-segment or spatial-query counter ownership
  leaves `InteractiveDrawEraserEngine`; focused exact-hit owners may only
  increment those counters through callbacks back into the engine.

### 6.8 Prohibited

- Reopening coarse candidate query/filter ownership already handled by
  `InteractiveDrawEraserTargets`.
- Moving eraser exact-hit geometry upward into `InteractiveDrawCoordinator` or
  `InteractiveRuntime`.
- Introducing a generic geometry service or plugin model shared across draw
  tools.
- Splitting line and stroke exact-hit logic only by file placement while
  keeping the same mixed owner boundary.
- Treating WMC or clone improvement as sufficient evidence without explicit
  owner transfer and structural pinning.

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

### Slice 1. [x] Eraser engine delegates exact-hit boundary

#### Slice Contract

`InteractiveDrawEraserEngine` no longer owns the shared exact-hit geometry
entrypoint itself.

#### Change

Introduce one explicit eraser-local exact-hit owner for node-family dispatch,
shared projection to local space, and world-bounds fallback, and rewire the
eraser engine to delegate exact-hit decisions through that owner while
preserving current counters and commit flow.

#### Verification

- `dcm calculate-metrics lib/src/interactive/internal/interactive_draw_eraser*.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/interactive/core/interactive_draw_eraser_engine_test.dart test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart test/interactive/core/scene_controller_interactive_guardrails_eraser_lifecycle_test.dart`

#### Positive Scenarios

- Singular-transform fallback still erases a matching line.
- Singular-transform fallback still erases a matching stroke.
- Eraser commit flow still observes coarse query count and precise segment
  checks through the existing runtime/controller path.

#### Negative Scenarios

- The engine does not keep exact-hit projection/fallback as a private helper
  while only renaming the call site.
- The step does not move geometry upward into the draw coordinator.

#### Closure Evidence

- Green run of the listed verifications.
- Source proof that `_eraserHitsNode(...)` and shared projection/fallback no
  longer live in `interactive_draw_eraser_engine.dart`.

### Slice 2. [x] Line and stroke exact-hit logic have separate focused owners

#### Slice Contract

Line-local and stroke-local eraser exact-hit geometry no longer share one
mixed owner body.

#### Change

Split the eraser exact-hit boundary into separate focused owners for line and
stroke geometry, and extend structural tests / guardrails so the new eraser
owner graph fails if mixed exact-hit geometry returns to the engine or the
coordinator.

#### Verification

- `dcm calculate-metrics lib/src/interactive/internal/interactive_draw_eraser*.dart lib/src/interactive/internal/interactive_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/interactive`
- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Line-local exact-hit path still erases matching line geometry.
- Stroke-local exact-hit path still erases matching stroke geometry.
- Structural tests and guardrails accept the final eraser exact-hit owner graph.

#### Negative Scenarios

- Structural proof fails if mixed line/stroke exact-hit geometry returns to
  `InteractiveDrawEraserEngine`.
- Structural proof fails if `InteractiveDrawCoordinator` regains eraser
  geometry bodies.

#### Closure Evidence

- Green run of the listed verifications.
- Diagnostic output from the new or updated structural proof when banned
  reabsorption forms are reintroduced.

## 9. Final Verification

- `dcm calculate-metrics lib/src/interactive/internal/interactive_draw_eraser*.dart lib/src/interactive/internal/interactive_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/interactive`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
