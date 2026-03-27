language: russian

# Шаг 37.4. Замкнуть финальную core architecture на docs, non-regression pinning и baseline

## 1. Change Mandate

Этот шаг завершает `core`-layer sequence after steps `37.1-37.3`: финальная
архитектура `core` должна быть явно зафиксирована в in-repo документации,
подтверждена existing non-regression proofs и закрыта финальным measured
baseline без reopening production ownership slices.

## 2. Change Boundary

### Included in the Change

- Final architecture-doc update for the `core` owner graph after steps
  `37.1-37.3`.
- Extension of existing core owner tests and invariant-backed proofs so the
  final node-family, node-support, and leaf-support boundaries are pinned
  against regression.
- Final core metrics/clone rebaseline and roadmap closure tied directly to
  steps `37.1-37.4`.

### Not Included in the Change

- Reopening production `core` refactors from steps `37.1-37.3` beyond minimal
  adaptation required to satisfy the proofs introduced by this step.
- Public API changes for mutable node types, action events, or generated ids.
- New package exports or transport-contract changes created only for this step.
- Production work in `model/**`, `serialization/**`, `controller/**`,
  `interactive/**`, `render/**`, or `view/**` outside documentation or
  verification directly tied to `core` architecture closure.

## 3. File Map and Analysis Areas

### Implementation Files

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`

### Test Files

- `test/core/nodes_test.dart`
- `test/core/action_events_test.dart`
- `test/core/id_generator_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`

### Fixture and Supporting Data Files

- `development_plan/step_37_core_final_architecture.md`
- `development_plan/step_37_1_node_family_core_owner_decomposition.md`
- `development_plan/step_37_2_path_cache_and_mutable_geometry_owner_split.md`
- `development_plan/step_37_3_core_leaf_support_owner_finalization.md`
- `development_plan/step_37_4_core_final_architecture_closure.md`

### Analysis Area

- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`
- `lib/src/core/**`
- `test/core/**`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`
- `development_plan/step_37*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified documentation file must either describe the final `core`
  architecture or record the final measured `core` baseline.
- Every modified test must pin one final `core` boundary or invariant against
  architectural regression.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `core` remains the low-level layer for primitives, defaults, math, and
   event types.
2. `SceneNode.transform` remains the single source of truth for mutable node
   transforms.
3. `node_geometry.dart` and `scene_spatial_index.dart` remain the existing
   focused owners for runtime geometry and spatial-query concerns.
4. `TextNode.size` remains derived from text layout inputs.
5. `PathNode` cache invalidation, immutable action payload exposure, and
   generated-id ownership are not reopened as public-contract changes in this
   step.

## 5. Result Requirements

1. `ARCHITECTURE.md` describes the final `core` architecture with:
   `SceneNode` as common transform / bounds shell,
   explicit node-family owners beneath mutable node entrypoints,
   isolated node-local mutable geometry and path-cache support,
   explicit leaf support owners for text layout, action payload parsing, and
   generated-id allocation,
   and existing shared geometry ownership staying in
   `node_geometry.dart` / `scene_spatial_index.dart`.
2. Existing core proofs and invariants pin the final `core` architecture and
   fail if mixed node-family, node-support, or leaf-support ownership returns
   in the same form removed by steps `37.1-37.3`.
3. `DEVELOPMENT_PLAN.md` and the step-`37` documents describe one consistent
   final `core` end-state with no stale references to remaining architecture
   debt that actually belongs to `nodes.dart`, `text_layout.dart`,
   `action_events.dart`, or `id_generator.dart`.
4. Final measured `core` baseline is recorded from actual runs of
   `dcm calculate-metrics lib/src/core --report-all`
   and
   `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`;
   no remaining accepted residual hotspot or clone cluster may belong to a
   mixed owner shape explicitly decomposed by steps `37.1-37.3`.
5. Any accepted residual hotspot that remains after closure is limited to a
   focused single-purpose `core` unit and is explicitly documented as a
   closure-state residual seam.

## 6. Implementation Specification

### 6.1 Analysis Scope

- This step starts only after `37.1-37.3` are closed.
- Current confirmed pre-closure `core` baseline is `7` `HIGH/VERY HIGH`
  entries and `4` clone clusters.
- Existing invariant-backed proofs already pin three closure-critical `core`
  semantics:
  `INV-ENG-TEXT-SIZE-DERIVED`,
  `INV-ENG-EVENTS-IMMUTABLE`,
  and
  `INV-ENG-PATH-NODE-CACHE-INVALIDATION`.
- Final closure baseline must be captured from actual post-step runs and must
  not be copied from the pre-closure snapshot above.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/core --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
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

### 6.3 Protected States, Data, or Structures

- Final mutable-node transform and local/world geometry semantics.
- Derived text-size semantics.
- Immutable event payload exposure.
- Generated-id ownership and uniqueness behavior.
- Path-cache invalidation behavior.
- Accepted residual `core` seams and their final measured baseline.

### 6.4 Allowed Semantic Change Zones

- Core architecture documentation.
- Existing invariant-backed proofs and owner-level non-regression tests.
- Roadmap and baseline documentation tied directly to the final `core`
  architecture.
- Minimal production adaptations required to satisfy the final proofs without
  reopening step-`37.1-37.3` ownership work.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- This step must reuse existing `core` proof surfaces where possible instead of
  creating new public verification entrypoints.
- Structural assertions and owner-level proofs must pin the final `core` file
  graph directly enough to fail when mixed ownership returns to
  `nodes.dart`,
  `text_layout.dart`,
  `action_events.dart`,
  or
  `id_generator.dart`.
- Final measured `core` baseline must be recorded from actual verification
  runs, not from inferred or copied numbers.

### 6.8 Prohibited

- Reopening production `core` refactors as a substitute for documenting or
  pinning the final architecture.
- Leaving the final `core` architecture implicit only in step documents without
  updating `ARCHITECTURE.md`.
- Accepting a final baseline without proof surfaces that pin the final owner
  shape removed by steps `37.1-37.3`.
- Accepting residual mixed-owner hotspots in
  `nodes.dart`,
  `text_layout.dart`,
  `action_events.dart`,
  or
  `id_generator.dart`
  as closure-state seams.

## 7. Execution Rules

1. This step starts only after steps `37.1-37.3` are closed.
2. This step closes only if the final `core` architecture is both documented
   and mechanically pinned against regression.
3. Rebaseline alone does not count as closure without the corresponding
   documentation and proof updates.
4. Scope expansion beyond `core` architecture closure is forbidden.

## 8. Vertical Slices

### Slice 1. [ ] Existing proofs pin the final core owner boundaries

#### Slice Contract

Existing `core` proofs and invariant-backed tests fail when mixed node-family,
node-support, or leaf-support ownership returns to the final `core` seams.

#### Change

Extend the existing `core` proof surfaces so they pin the final owner graph
after steps `37.1-37.3`, including the final node-family, node-support, and
leaf-support boundaries.

#### Verification

- MCP test runner:
  `test/core/nodes_test.dart test/core/action_events_test.dart test/core/id_generator_test.dart`
- MCP test runner:
  `test/render/render_geometry_cache_test.dart test/render/scene_stroke_path_cache_test.dart test/render/scene_text_layout_cache_test.dart`
- MCP test runner: `test/controller/core/scene_controller_copy_on_write_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Existing proofs cover the final `core` owner boundaries removed by
  `37.1-37.3`.

### Slice 2. [ ] Rebaseline and document final core architecture

#### Slice Contract

The final `core` architecture and its accepted residual seams are recorded
consistently in repo documentation and roadmap.

#### Change

Update `ARCHITECTURE.md`, `DEVELOPMENT_PLAN.md`, and the step-`37` documents to
describe the final `core` architecture, then record the final measured `core`
metrics and clone baseline from actual runs.

#### Verification

- `dcm calculate-metrics lib/src/core --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `ARCHITECTURE.md`, `DEVELOPMENT_PLAN.md`, and the step-`37` documents reflect
  the same final `core` architecture and measured baseline.

## 9. Final Verification

- `dcm calculate-metrics lib/src/core --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
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
