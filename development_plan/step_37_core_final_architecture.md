language: russian

# Шаг 37. Замкнуть финальную core architecture через подшаги 37.1-37.4

## 1. Change Mandate

Этот шаг доводит `core` до финальной архитектуры через разрезание смешанных
node-owner seams, изоляцию node-local support ownership, финализацию leaf
support owner-ов и финальное measured closure без metric-only изменений.

## 2. Change Boundary

### Included in the Change

- Decomposition of mixed node primitive ownership in `lib/src/core/nodes.dart`.
- Isolation of node-local mutable geometry and path-cache support ownership in
  `core`.
- Finalization of core leaf support ownership in
  `text_layout.dart`,
  `action_events.dart`,
  and
  `id_generator.dart`.
- Final architecture-doc update, non-regression pinning, and measured
  rebaseline for the `core` layer.

### Not Included in the Change

- Reopening `scene_spatial_index.dart` or `node_geometry.dart` as production
  hotspots beyond minimal adaptation directly required by a step-`37` slice.
- Boundary-matrix, model, serialization, controller, interactive, render, or
  view production refactors outside verification or adaptation directly tied to
  the `core` architecture closure.
- Public API, JSON transport contract, or package export changes introduced
  only to improve `core` metrics.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/nodes.dart`
- `lib/src/core/text_layout.dart`
- `lib/src/core/action_events.dart`
- `lib/src/core/id_generator.dart`
- `ARCHITECTURE.md`
- `DEVELOPMENT_PLAN.md`

### Test Files

- `test/core/nodes_test.dart`
- `test/core/action_events_test.dart`
- `test/core/id_generator_test.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_37_core_final_architecture.md`
- `development_plan/step_37_1_node_family_core_owner_decomposition.md`
- `development_plan/step_37_2_path_cache_and_mutable_geometry_owner_split.md`
- `development_plan/step_37_3_core_leaf_support_owner_finalization.md`
- `development_plan/step_37_4_core_final_architecture_closure.md`

### Analysis Area

- `lib/src/core/**`
- `test/core/**`
- `test/render/render_geometry_cache_test.dart`
- `test/render/scene_stroke_path_cache_test.dart`
- `test/render/scene_text_layout_cache_test.dart`
- `test/model/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/controller/commands/scene_commands_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `development_plan/step_37*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to exactly one step-`37`
  substep.
- Every modified test must be tied to one verification surface.
- Every modified planning or documentation file must be tied to one measured
  baseline or one execution slice.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `core/` remains the low-level layer for primitives, defaults, math, and
   event types, and it depends only on `contract/`.
2. `SceneNode.transform` remains the single source of truth for mutable node
   translation, rotation, and scale.
3. `core/node_geometry.dart` remains the shared runtime geometry owner for
   render, hit-test, and spatial-index consumers; step `37` must not
   reintroduce duplicate geometry ownership in `nodes.dart`.
4. `TextNode.size` remains derived from text layout inputs.
5. Generated-id policy remains internal runtime ownership in
   `src/core/id_generator.dart`; public boundary code does not own generated-id
   formatting.
6. `PathNode` local-path cache invalidation semantics remain protected.

## 5. Result Requirements

1. `core` no longer keeps the current mixed node primitive ownership shape in
   `nodes.dart`; common node semantics, node-family geometry conveniences,
   mutable geometry storage, and path-cache support are separated into focused
   core-local owners.
2. `text_layout.dart`, `action_events.dart`, and `id_generator.dart` each keep
   one explicit leaf support owner without duplicate local parsing, allocation,
   or measurement paths.
3. No accepted residual `HIGH` / `VERY HIGH` hotspot after closure may belong
   to a monolithic `nodes.dart` owner that mixes common node semantics with
   family-local geometry or cache support.
4. Post-step `core` baseline is recorded from actual runs of
   `dcm calculate-metrics lib/src/core --report-all`
   and
   `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`.
5. `ARCHITECTURE.md`, `DEVELOPMENT_PLAN.md`, and the step-`37` documents
   describe one consistent final `core` end-state.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current measured `core` baseline is `7` `HIGH/VERY HIGH` metric entries from
  `dcm calculate-metrics lib/src/core --report-all`.
- Current measured clone baseline for `lib/src/core` is `4` clone clusters and
  `17` pairs.
- Confirmed live clone clusters are:
  - one `nodes.dart` constructor family cluster around
    `fromTopLeftWorld`,
    `fromWorldPoints`,
    and
    `fromWorldSegment`;
  - one `nodes.dart` transform-convenience cluster around
    `rotationDeg`,
    `scaleX`,
    and
    `scaleY`;
  - one `action_events.dart` helper cluster around
    `tryMoveLayerIndices`,
    `tryDrawStyle`,
    and duplicated `tryInt`;
  - one `id_generator.dart` allocation cluster around
    `generateNextNodeId` and `generateNextLayerId`.
- Confirmed live metric hotspots are concentrated in
  `nodes.dart`,
  with additional leaf hotspots in
  `text_layout.dart`,
  `action_events.dart`,
  and
  `id_generator.dart`.
- `scene_spatial_index.dart` local hotspot cleanup is already closed by step
  `20.3` and is not reopened as the main subject of step `37`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/core --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/core`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core`
- MCP test runner:
  `test/render/render_geometry_cache_test.dart test/render/scene_stroke_path_cache_test.dart test/render/scene_text_layout_cache_test.dart`
- MCP test runner: `test/model/scene_builder_test.dart`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart`
- MCP test runner:
  `test/controller/commands/scene_commands_test.dart test/controller/core/scene_controller_copy_on_write_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`

### 6.3 Protected States, Data, or Structures

- `SceneNode.transform` as the single transform source of truth.
- Box-node `topLeftWorld` semantics.
- Stroke/line world-to-local normalization semantics.
- `TextNode.size` derived layout semantics.
- `ActionCommitted` immutable payload and node-id exposure.
- Generated-id allocation ownership and uniqueness semantics.
- `PathNode` cache invalidation semantics.
- Existing render / hit-test / spatial-index geometry parity.

### 6.4 Allowed Semantic Change Zones

- Common `SceneNode` transform and bounds convenience semantics.
- Box-node family placement and local-rect semantics.
- Stroke/line family world-local creation and normalization semantics.
- Node-local mutable geometry revision support.
- Path-local cache and diagnostics support.
- Text layout support ownership.
- Action payload parsing support ownership.
- Generated-id allocation support ownership.
- Final architecture documentation and measured roadmap baseline.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `37.1` closes before `37.2`.
- `37.2` closes before `37.3`.
- `37.4` is forbidden until `37.1-37.3` are closed and the residual
  post-refactor `core` baseline is measured.
- Final baseline recorded by `37.4` must come from actual runs of the listed
  metric and clone tools, not from inferred or copied values.

### 6.8 Prohibited

- Introducing metric-only wrappers, helper indirection, or generic utility
  layers whose primary purpose is to reduce `core` metrics.
- Moving render-, hit-test-, or spatial-index-specific ownership back into
  `nodes.dart`.
- Changing public node, event, or generated-id behavior to reduce hotspot
  counts.
- Reopening model, serialization, controller, interactive, render, or view
  production scope as a substitute for closing `core`.

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

### Slice 1. [ ] Node-family owner decomposition

#### Slice Contract

Закрыть
`development_plan/step_37_1_node_family_core_owner_decomposition.md`
без выхода за ownership boundary `37.1`.

#### Verification

- Verification from `37.1`

### Slice 2. [ ] Node-local support owner split

#### Slice Contract

Закрыть
`development_plan/step_37_2_path_cache_and_mutable_geometry_owner_split.md`
без выхода за ownership boundary `37.2`.

#### Verification

- Verification from `37.2`

### Slice 3. [ ] Leaf support owner finalization

#### Slice Contract

Закрыть
`development_plan/step_37_3_core_leaf_support_owner_finalization.md`
без выхода за ownership boundary `37.3`.

#### Verification

- Verification from `37.3`

### Slice 4. [ ] Core architecture closure

#### Slice Contract

Закрыть
`development_plan/step_37_4_core_final_architecture_closure.md`
без повторного открытия semantic scope `37.1-37.3`.

#### Verification

- Verification from `37.4`

## 9. Final Verification

- `dcm calculate-metrics lib/src/core --report-all`
- `dart run tool/analysis/find_similar_clones.dart lib/src/core`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: `test/core`
- MCP test runner:
  `test/render/render_geometry_cache_test.dart test/render/scene_stroke_path_cache_test.dart test/render/scene_text_layout_cache_test.dart`
- MCP test runner: `test/model/scene_builder_test.dart`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart`
- MCP test runner:
  `test/controller/commands/scene_commands_test.dart test/controller/core/scene_controller_copy_on_write_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
