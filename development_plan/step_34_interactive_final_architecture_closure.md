language: russian

# Шаг 34. Замкнуть финальную interactive architecture на docs, structural tests и baseline

## 1. Change Mandate

Этот шаг завершает interactive-layer sequence after steps `32-33`: финальная
архитектура interactive должна быть явно зафиксирована в in-repo
документации, подтверждена structural non-regression tests / guardrails и
закрыта финальным measured baseline без reopening production ownership slices.

## 2. Change Boundary

### Included in the Change

- Final architecture-doc update for the interactive boundary graph after steps
  `32-33`.
- Extension of existing interactive structural contract tests and guardrails so
  the final public-facade, boundary-runtime, and draw-family boundaries are
  pinned against regression.
- Final interactive metrics/clone rebaseline and roadmap closure tied directly
  to steps `32-34`.

### Not Included in the Change

- Reopening production interactive refactors from steps `32-33` beyond minimal
  adaptation required to satisfy the structural contract tests introduced by
  this step.
- Public API changes for `SceneControllerInteractive`,
  `CanvasPointerInput`, `SceneViewInteractive`, actions, or
  `editTextRequests`.
- New public tooling entrypoints or package exports created only for this step.
- Work in `controller/**`, `render/**`, `view/**`, `model/**`,
  `serialization/**`, or `contract/**` outside documentation or verification
  that is directly tied to the interactive architecture closure.

## 3. File Map and Analysis Areas

### Implementation Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/guardrails_runner.dart`
- `tool/src/guardrails/interactive_api_guardrails.dart`
- `tool/invariant_registry.dart`

### Test Files

- `test/interactive/core/interactive_move_session_test.dart`
- `test/interactive/core/scene_controller_interactive_runtime_contract_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixture and Supporting Data Files

- `development_plan/step_32_interactive_runtime_boundary_owner_split.md`
- `development_plan/step_33_interactive_draw_path_owner_decomposition.md`
- `development_plan/step_34_interactive_final_architecture_closure.md`

### Analysis Area

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `lib/src/interactive/**`
- `tool/check_guardrails.dart`
- `tool/src/guardrails/**`
- `tool/invariant_registry.dart`
- `test/interactive/core/**`
- `test/tool/guardrails/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified documentation file must either describe the final interactive
  architecture or record the final measured interactive baseline.
- Every modified tool or test file must pin one final interactive boundary
  against architectural regression.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneControllerInteractive` remains the public interactive facade over a
   controller-private boundary runtime.
2. Boundary pointer normalization, active gesture identity, and family
   admission remain owned under `interactive/` and do not move back into
   `view/`.
3. Draw-family ownership remains beneath the interactive runtime boundary and
   does not move back into `SceneControllerInteractive`.
4. `interaction_eligibility_policy.dart` remains the single interactive policy
   owner for controller-side transform/delete preflight and move-side
   admissibility shaping.
5. Public interactive pointer, preview, action, and edit-text semantics are not
   reopened in this step.

## 5. Result Requirements

1. `ARCHITECTURE.md` describes the final interactive architecture with:
   `SceneControllerInteractive` as thin public facade,
   a controller-private boundary runtime owning pointer normalization and active
   gesture orchestration,
   an explicit interactive event/timeline owner behind
   `interactive_event_dispatcher.dart`,
   explicit move and draw family owners beneath that runtime,
   draw-local eraser query / geometry ownership separated beneath the draw
   family,
   and view-side raw pointer routing remaining outside the interactive
   controller.
2. Existing interactive structural contract tests and guardrails pin the final
   interactive architecture and fail if:
   `scene_controller_interactive.dart` reabsorbs boundary-runtime or
   draw-local mixed ownership,
   `interactive_runtime.dart` reabsorbs event-timeline or draw-local ownership,
   or draw-family owners reabsorb the mixed eraser/query/geometry seams removed
   by steps `32-33`.
3. `DEVELOPMENT_PLAN.md` and the step `32-34` documents describe one consistent
   interactive end-state with no stale references to remaining runtime or
   draw-path architecture debt.
4. Final measured interactive baseline is recorded from actual runs of
   `dcm calculate-metrics lib/src/interactive --report-all` and
   `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`;
   no remaining `HIGH` / `VERY HIGH` entry may belong to
   `interactive_runtime.dart` or to a mixed draw owner that step `33`
   explicitly decomposes.
5. Any accepted residual hotspot or clone pair that remains after the
   step-`32-33` refactors is limited to public facade API breadth or to focused
   single-purpose policy/action owners, and is explicitly documented as
   closure-state residual work; boundary-runtime and mixed draw owners are not
   accepted residual candidates.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `ARCHITECTURE.md` already documents interactive invariants at a high level,
  but it does not yet record the final step-`32-33` owner graph or the final
  accepted residual baseline for interactive.
- Existing interactive guardrails currently enforce
  `INV-ENG-INTERACTIVE-RESOLVER-PURITY` for public entrypoints in
  `SceneControllerInteractive`, but they do not yet pin the final
  facade/runtime/event-owner/draw-family boundary shape.
- `interactive_move_session_test.dart` already shows the existing repo pattern
  for internal interactive contract coverage; this step may extend that pattern
  or add one focused source-based contract test for the final boundary graph.
- Current confirmed pre-closure interactive baseline is:
  `11` `HIGH/VERY HIGH` metric entries and `9` clone pairs across
  `lib/src/interactive`;
  the main live hotspots are
  `scene_controller_interactive.dart`,
  `interactive_runtime.dart`,
  `interactive_draw_eraser_engine.dart`,
  and near-hot `interactive_draw_coordinator.dart`.
- Final closure baseline recorded by this step must be captured from actual
  post-step runs and must not be copied from the pre-closure snapshot above.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/interactive --report-all`
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
- `dart run tool/run_tool_tests.dart`

### 6.3 Protected States, Data, or Structures

- Final public interactive API and host-facing pointer contract.
- Boundary pointer normalization and terminal sample semantics.
- Single controller-owned active gesture machine and forced boundary reset
  semantics.
- Asynchronous/coalesced interactive event delivery and monotonic timestamp
  semantics.
- Ephemeral move/draw preview semantics and cancel cleanup semantics.
- Accepted residual interactive seams and their final measured baseline.

### 6.4 Allowed Semantic Change Zones

- Interactive architecture documentation.
- Structural source-level contract tests and guardrails for the final
  interactive boundary graph.
- Roadmap and baseline documentation tied directly to the final interactive
  architecture.
- Interactive event/timeline owner documentation and structural pinning.
- Minimal production adaptations required to satisfy the new structural tests
  without reopening step-`32-33` ownership work.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- Direct reabsorption of boundary-runtime helpers into
  `SceneControllerInteractive`.
- Private-helper bypass where `SceneControllerInteractive` regains
  pointer-normalization, timestamp, or draw-local algorithm ownership under a
  different helper name.
- Runtime-local reabsorption where `InteractiveRuntime` regains
  draw-local or event-timeline ownership removed by step `32`.
- Draw-family reabsorption where the coordinator or eraser owner regains mixed
  query/filter/geometry bodies removed by step `33`.

### 6.6 Allowed Forms That Do Not Count as Violations

- Public facade methods delegating into the boundary runtime or controller core.
- Boundary-runtime orchestration delegating into explicit move/draw owners.
- Draw-family orchestration that sequences focused owners without owning
  candidate-query and precise hit-geometry bodies in the same owner body.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- This step starts only after steps `32` and `33` are closed; it must consume
  the narrowed runtime boundary and draw-family owner graph instead of reopening
  them as the main subject of change.
- Structural assertions must read and pin the final interactive file graph
  directly enough to fail when mixed ownership returns to
  `scene_controller_interactive.dart`,
  `interactive_runtime.dart`,
  the event/timeline owner behind `interactive_event_dispatcher.dart`,
  or draw-family owners beneath the runtime boundary.
- Any new or modified invariant enforcement introduced by this step must use an
  exact `// INV:<id>` marker and keep
  `dart run tool/check_invariant_coverage.dart` green.
- Final measured interactive baseline must be recorded from actual verification
  runs, not from inferred or copied numbers.

### 6.8 Prohibited

- Reopening production runtime or draw refactors as a substitute for
  documenting or pinning the final interactive architecture.
- Leaving the final interactive architecture implicit only in step documents
  without updating `ARCHITECTURE.md`.
- Accepting a final baseline without structural non-regression tests or
  guardrails that pin the final boundary shape.
- Accepting residual `HIGH` / `VERY HIGH` entries in `interactive_runtime.dart`
  or in mixed draw owners as closure-state seams.
- Adding wrapper layers, helper indirection, or metric-only structure changes
  whose primary purpose is to improve closure numbers instead of pinning the
  final architecture.

## 7. Execution Rules

1. This step starts only after steps `32` and `33` are closed.
2. This step closes only if the final interactive architecture is both
   documented and mechanically pinned against regression.
3. Rebaseline alone does not count as closure without the corresponding
   documentation and structural test / guardrail updates.
4. Scope expansion beyond interactive architecture closure is forbidden.

## 8. Vertical Slices

### Slice 1. [x] Extend structural contract tests to pin final interactive boundaries

#### Slice Contract

Interactive structural contract tests and guardrails fail when the final
interactive facade/runtime/event-owner/draw-family boundaries regress back into
mixed owners.

#### Change

Extend the existing interactive guardrails and add one focused interactive
contract test so they pin the final boundary shape after steps `32-33`,
including the final public facade, boundary runtime, event/timeline owner, and
draw-family owner graph.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner:
  `test/interactive/core/interactive_move_session_test.dart test/interactive/core/scene_controller_interactive_runtime_contract_test.dart`
- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Public interactive entrypoints remain thin guarded delegations into the final
  boundary runtime / controller bridge.
- Interactive event delivery and monotonic timestamp sequencing remain
  externalized from `InteractiveRuntime`.
- Runtime orchestration remains delegated into explicit move and draw owners.
- Draw-family orchestration remains externalized beneath the runtime boundary.

#### Negative Scenarios

- `SceneControllerInteractive` does not regain pointer normalization,
  timestamp/event timeline ownership, or eraser hit geometry bodies.
- `InteractiveRuntime` does not regain mixed draw-local or event-timeline
  ownership removed by step `32`.
- Draw-family owners do not collapse back into a mixed eraser/query/geometry
  owner shape removed by step `33`.

#### Closure Evidence

- Green run of the listed verifications.
- Structural assertions cover the final interactive public-facade,
  boundary-runtime, event-owner, and draw-family boundaries.
- The added interactive contract test fails if final mixed ownership returns to
  `scene_controller_interactive.dart`,
  `interactive_runtime.dart`,
  the event/timeline boundary,
  or the draw-family owner graph.

### Slice 2. [x] Rebaseline and document final interactive architecture

#### Slice Contract

The final interactive architecture and its accepted residual seams are recorded
consistently in the repo documentation and roadmap.

#### Change

Update `ARCHITECTURE.md`, `DEVELOPMENT_PLAN.md`, and the step `32-34`
documents to describe the final interactive architecture, then record the final
measured interactive metrics and clone baseline from actual runs.

#### Verification

- `dcm calculate-metrics lib/src/interactive --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `ARCHITECTURE.md` and `DEVELOPMENT_PLAN.md` reflect the same final
  interactive end-state as the step `32-34` contracts.
- Final measured interactive baseline is recorded from the verification runs.
- Recorded closure baseline explicitly lists accepted residual seams, if any,
  instead of leaving runtime/draw residual debt implicit.

### Recorded Closure Baseline

- `dcm calculate-metrics lib/src/interactive --report-all` recorded
  `7` `HIGH/VERY HIGH` metric entries across `lib/src/interactive`.
- No remaining `HIGH/VERY HIGH` entry belongs to
  `interactive_runtime.dart` or `interactive_draw_coordinator.dart`.
- The remaining metric hotspots are limited to:
  `scene_controller_interactive.dart` public-facade breadth,
  `interactive_draw_eraser_engine.dart` as a focused eraser-local owner,
  and `interactive_draw_action_emitter.dart` as a focused action owner.
- `dart run tool/analysis/find_similar_clones.dart lib/src/interactive`
  recorded `5` remaining clone pairs:
  `interaction_eligibility_policy.dart`,
  `interactive_draw_eraser_engine.dart`,
  `interactive_move_hit_test_engine.dart`,
  `interactive_gesture_router.dart`,
  and constructor wiring between
  `interactive_draw_coordinator.dart` and `interactive_runtime.dart`.
- These residuals were kept explicit because further reduction would require
  wrapper-style indirection or ownership drift that the repo rules reject.

## 9. Final Verification

- `dcm calculate-metrics lib/src/interactive --report-all`
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
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
