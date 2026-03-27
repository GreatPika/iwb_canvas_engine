language: russian

# Шаг 33. Разрезать draw-path interactive на focused draw-local owner-ы

## 1. Change Mandate

Этот шаг разрезает draw-path под `InteractiveDrawCoordinator` на focused
draw-local owner-ы without changing public draw behavior.

## 2. Change Boundary

### Included in the Change

- Draw-family ownership beneath `InteractiveDrawCoordinator`.
- Draw-local shared gesture state and terminal commit branching currently mixed
  into `InteractiveDrawCoordinator`.
- Eraser-path candidate query, delete filtering, and precise hit geometry
  ownership.

### Not Included in the Change

- Boundary runtime ownership covered by step `32`.
- Move-session ownership and move-path semantics.
- Final interactive architecture closure in docs, structural tests, and
  accepted residual baseline.
- View-side raw pointer routing ownership.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/interactive/internal/interactive_draw_coordinator.dart`
- `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
- `lib/src/interactive/internal/interactive_draw_line_engine.dart`
- `lib/src/interactive/internal/interactive_draw_stroke_engine.dart`
- `lib/src/interactive/internal/interactive_geometry.dart`

### Test Files

- `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_eraser_lifecycle_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_line_test.dart`
- `test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart`
- `test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_33_interactive_draw_path_owner_decomposition.md`

### Analysis Area

- `lib/src/interactive/internal/interactive_draw*.dart`
- `lib/src/interactive/internal/interactive_geometry.dart`
- `test/interactive/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must remove mixed draw-path ownership from
  the current coordinator or eraser owner body, or become one explicit focused
  internal owner beneath the draw-path graph.
- Every modified test must validate draw-local behavior or the updated draw-path
  owner boundary.
- Any new internal owner file created by this step must remain under
  `lib/src/interactive/internal/` and be tied to one draw-path slice.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `InteractiveDrawCoordinator` is not the owner of pointer identity.
2. Pending line and its timer remain owned by `InteractiveDrawLineEngine`.
3. Eraser delete admissibility remains owned by
   `interaction_eligibility_policy.dart`.
4. Boundary pointer normalization, active gesture ownership, and family
   admission remain outside this step under the interactive runtime boundary.

## 5. Result Requirements

1. `InteractiveDrawCoordinator` no longer keeps the current mixed draw-local
   gesture state, tool-family terminal branching, and erase-action construction
   in one owner body.
2. One explicit draw-local state and terminal-commit owner boundary exists
   beneath `InteractiveDrawCoordinator`; coordinator-level family routing does
   not keep shared draw-local gesture state or terminal commit envelopes.
3. One draw-local owner boundary exists beneath `InteractiveDrawCoordinator`
   for eraser candidate-query and delete filtering separate from precise eraser
   hit geometry.
4. Public draw behavior remains equivalent for:
   pending line,
   line tap and drag creation,
   stroke and eraser gesture buffer soft caps,
   erase eligibility,
   erase action emission,
   cancel cleanup,
   and forced reset cleanup.
5. The measured hotspot baseline improves against the current confirmed
   draw-path scope as evidence of removed mixed ownership, and metric or clone
   improvement alone does not close the step:
   `InteractiveDrawEraserEngine` imports `12`, class `RFC 50`, `WMC 74`,
   and
   `InteractiveDrawCoordinator` near-threshold class metrics
   `CBO 11`, `RFC 33`, `WMC 32`.
6. The current measured draw-local clone set improves for:
   `handleMove` in stroke/eraser,
   `_eraserHitsLine(...)` vs `_eraserHitsStroke(...)`,
   `_localEraserSegmentsHitLine(...)` vs `_eraserSegmentHitsStrokeBatch(...)`,
   and
   `_emitLineCommit(...)` vs stroke `commitOnUp(...)`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed draw-path hotspot files are:
  - `lib/src/interactive/internal/interactive_draw_coordinator.dart`
  - `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
  - `lib/src/interactive/internal/interactive_draw_line_engine.dart`
  - `lib/src/interactive/internal/interactive_draw_stroke_engine.dart`
- Current confirmed draw-path metric signals are:
  - `InteractiveDrawCoordinator` near-threshold class metrics
    `CBO 11`, `RFC 33`, `WMC 32`
  - `InteractiveDrawCoordinator._handleUp(...)` near-threshold
    `SLOC 34`
  - `InteractiveDrawEraserEngine` imports `12`, class `RFC 50`, `WMC 74`
  - `InteractiveDrawEraserEngine._queryEraserCandidates(...)` near-threshold
    `SLOC 35`
- Current confirmed draw-local clone clusters inside `lib/src/interactive`
  include:
  - `interactive_draw_eraser_engine.dart::handleMove` and
    `interactive_draw_stroke_engine.dart::handleMove`
  - `InteractiveDrawEraserEngine._eraserHitsLine(...)` and
    `InteractiveDrawEraserEngine._eraserHitsStroke(...)`
  - `InteractiveDrawEraserEngine._localEraserSegmentsHitLine(...)` and
    `InteractiveDrawEraserEngine._eraserSegmentHitsStrokeBatch(...)`
  - `InteractiveDrawLineEngine._emitLineCommit(...)` and
    `InteractiveDrawStrokeEngine.commitOnUp(...)`
- Step `11.5` already locked draw-side lifecycle rules:
  `InteractiveDrawCoordinator` does not own pointer identity,
  pending line stays in `InteractiveDrawLineEngine`,
  and eraser delete admissibility uses shared interactive policy.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/interactive_draw_eraser_engine.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/interactive_draw_stroke_engine.dart lib/src/interactive/internal/interactive_geometry.dart --report-all`
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
  `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_guardrails_eraser_lifecycle_test.dart test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_guardrails_line_test.dart test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

### 6.3 Protected States, Data, or Structures

- Pending-line latent state and timer lifecycle.
- Stroke and eraser gesture buffer cap behavior.
- Eraser delete eligibility.
- Erase, line, stroke, and highlighter action emission behavior.
- Cancel and forced-reset cleanup behavior for draw-local state.

### 6.4 Allowed Semantic Change Zones

- Draw-family orchestration beneath the coordinator.
- Shared draw-local state and terminal-commit ownership beneath the
  coordinator.
- Shared draw-local gesture state ownership.
- Eraser candidate-query and delete-filter ownership.
- Eraser precise hit-geometry ownership.
- Draw-local commit and action emission ownership.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- This step starts only after step `32` is closed; it must consume the narrowed
  interactive runtime boundary instead of reopening runtime mixed ownership.
- The step must establish one explicit draw-local state / terminal-commit
  boundary beneath `InteractiveDrawCoordinator`; hiding the same mixed logic
  behind helpers in the coordinator does not satisfy the step.
- `InteractiveDrawCoordinator` may remain the draw-family orchestration owner,
  but the step is not closed if the current mixed draw-local state and terminal
  tool branching remain in the same owner body.
- The stroke/eraser shared sample-buffer lifecycle and the line/stroke terminal
  commit envelope must resolve through explicit owner boundaries beneath the
  draw family; helper-only clone reduction inside mixed owners does not satisfy
  the step.
- Any extracted eraser-local owner created by this step must stay internal to
  `lib/src/interactive/internal/` and must not move draw-local state into the
  public facade or view layer.

### 6.8 Prohibited

- Reintroducing pointer identity ownership into `InteractiveDrawCoordinator`.
- Moving pending line or pending timer ownership out of
  `InteractiveDrawLineEngine`.
- Changing erase geometry semantics for the primary purpose of satisfying
  metrics.
- Introducing a generic tool/plugin hierarchy for draw tools.
- Replacing draw-local duplication with helper-only extraction while the same
  mixed coordinator or eraser owner bodies remain.
- Reopening boundary-runtime or move-session scope as part of this step.

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

### Slice 1. [ ] Draw coordinator becomes draw-family orchestration owner only

#### Slice Contract

`InteractiveDrawCoordinator` no longer keeps the current mixed draw-local state
and terminal tool commit bodies in one owner body.

#### Change

Split the current mixed draw-local gesture state and terminal tool commit
branching beneath `InteractiveDrawCoordinator` into one explicit draw-local
state / terminal-commit boundary while keeping coordinator-level family routing
and public draw behavior equivalent.

#### Verification

- `dcm calculate-metrics lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/interactive_draw_stroke_engine.dart --report-all`
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
  `test/interactive/core/scene_controller_interactive_guardrails_line_test.dart test/interactive/core/scene_controller_interactive_guardrails_stroke_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_line_pending_cancel_test.dart test/interactive/core/scene_controller_interactive_line_tool_flow_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

#### Positive Scenarios

- Line tap and drag creation remain behaviorally equivalent.
- Stroke and highlighter commit behavior remain behaviorally equivalent.
- Draw action payloads remain behaviorally equivalent on the public controller
  surface.

#### Negative Scenarios

- Pending line does not survive forced reset or cancel.
- Draw-local refactor does not move pointer identity ownership into the
  coordinator.
- Draw-local refactor does not reintroduce controller-side ad hoc cleanup paths
  for pending line state.

#### Closure Evidence

- Green run of the listed verifications.
- `InteractiveDrawCoordinator` no longer contains the removed mixed draw-local
  state and terminal commit branching in the same owner body.
- Line/stroke terminal commit flow no longer remains duplicated without an
  explicit draw-local owner boundary beneath the coordinator.
- The targeted metric baseline improves for
  `interactive_draw_coordinator.dart`.

### Slice 2. [ ] Eraser path is split into focused query and geometry owners

#### Slice Contract

The eraser path no longer mixes candidate-query/delete-filter ownership with
precise hit geometry ownership in one owner body.

#### Change

Split the eraser path beneath the draw-family owner so candidate query and
delete filtering are separated from precise line/stroke hit geometry without
changing erase behavior.

#### Verification

- `dcm calculate-metrics lib/src/interactive/internal/interactive_draw_eraser_engine.dart lib/src/interactive/internal/interactive_geometry.dart --report-all`
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
  `test/interactive/core/interactive_draw_eraser_engine_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_guardrails_eraser_lifecycle_test.dart test/interactive/core/scene_controller_interactive_guardrails_eraser_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

#### Positive Scenarios

- Singular-transform fallback cases for line and stroke erasure remain green.
- Eraser delete eligibility remains behaviorally equivalent.
- Erase action emission remains behaviorally equivalent.

#### Negative Scenarios

- Cancel does not mutate scene state and does not emit erase actions.
- Forced reset still clears eraser-local gesture buffers.
- The refactor does not broaden eraser delete eligibility beyond the shared
  policy owner.

#### Closure Evidence

- Green run of the listed verifications.
- The targeted metric baseline improves for
  `interactive_draw_eraser_engine.dart`.
- The current draw-local clone pairs around eraser hit geometry and draw commit
  flow improve against the confirmed starting set.

## 9. Final Verification

- `dcm calculate-metrics lib/src/interactive/internal/interactive_draw_coordinator.dart lib/src/interactive/internal/interactive_draw_eraser_engine.dart lib/src/interactive/internal/interactive_draw_line_engine.dart lib/src/interactive/internal/interactive_draw_stroke_engine.dart lib/src/interactive/internal/interactive_geometry.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner: `test/controller/internal`
- MCP test runner:
  `test/controller/core test/controller/commands`
  plus
  controller-root
  `scene_snapshot_invariant_assertions_test.dart`,
  `scene_invariants_test.dart`,
  and
  `scene_controller_randomized_txn_test.dart`
- MCP test runner: `test/render test/view`
- MCP test runner: `test/interactive`
- MCP test runner: `example/test` with root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
