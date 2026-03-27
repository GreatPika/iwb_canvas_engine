language: russian

# Шаг 37.1. Разрезать `nodes.dart` на node-family core-local owner-ы

## 1. Change Mandate

Этот шаг разрезает смешанный node primitive owner в `nodes.dart`, чтобы common
node semantics, box-node placement, и vector-node world/local conversion
больше не жили в одной handwritten форме.

## 2. Change Boundary

### Included in the Change

- `SceneNode` common transform / bounds convenience ownership.
- Box-node family placement and local-rect ownership for
  `ImageNode`,
  `TextNode`,
  and
  `RectNode`.
- Vector-node world/local creation and normalization ownership for
  `StrokeNode`
  and
  `LineNode`.

### Not Included in the Change

- `PathNode` cache lifecycle and mutable geometry support bodies targeted by
  step `37.2`.
- `text_layout.dart`, `action_events.dart`, and `id_generator.dart`.
- Reopening `node_geometry.dart`, `scene_spatial_index.dart`, or higher-layer
  production scope beyond direct verification.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/nodes.dart`

### Test Files

- `test/core/nodes_test.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_37_1_node_family_core_owner_decomposition.md`

### Analysis Area

- `lib/src/core/nodes.dart`
- `test/core/nodes_test.dart`
- `test/core/scene_spatial_index_test.dart`
- `test/render/render_geometry_cache_test.dart`
- `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one node-family slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneNode` remains the public mutable base type for runtime nodes.
2. `SceneNode.transform` remains the single source of truth for translation,
   rotation, and scale.
3. `topLeftWorld` remains an AABB-based convenience for UI-like box-node
   positioning.
4. Stroke and line world-to-local normalization remains core ownership and does
   not move into interactive or render layers.
5. Shared runtime geometry ownership in `node_geometry.dart` is not reopened by
   this step.

## 5. Result Requirements

1. `SceneNode` no longer keeps the current mixed ownership shape where common
   transform semantics and family-local box/vector creation paths live in one
   owner body.
2. `ImageNode`, `TextNode`, and `RectNode` consume one focused core-local owner
   for top-left placement and local-rect semantics.
3. `StrokeNode` and `LineNode` consume one focused core-local owner for
   world/local conversion and interactive normalization semantics.
4. The current constructor clone cluster in `lib/src/core/nodes.dart` is no
   longer present in the same handwritten form.
5. Box-node positioning, world/local normalization, and downstream geometry
   parity remain behaviorally equivalent.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current constructor clone cluster in `lib/src/core` has `5` members centered
  on
  `ImageNode.fromTopLeftWorld`,
  `TextNode.fromTopLeftWorld`,
  `RectNode.fromTopLeftWorld`,
  `StrokeNode.fromWorldPoints`,
  and
  `LineNode.fromWorldSegment`.
- Current transform-convenience clone cluster in `lib/src/core` is centered on
  `rotationDeg`,
  `scaleX`,
  and
  `scaleY`.
- `SceneNode` currently carries a near-hot complexity baseline, while
  `nodes.dart` remains the main mixed owner in the `core` layer.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/core/nodes.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- MCP test runner: `test/core/nodes_test.dart`
- MCP test runner: `test/core/scene_spatial_index_test.dart`
- MCP test runner: `test/render/render_geometry_cache_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- `SceneNode.boundsWorld` behavior.
- Box-node `topLeftWorld` behavior.
- Stroke/line world-to-local normalization behavior.
- Existing render and spatial-index parity that depends on node local/world
  semantics.

### 6.4 Allowed Semantic Change Zones

- Common transform and bounds convenience inside `SceneNode`.
- Box-node family placement and local-rect ownership.
- Vector-node family world/local creation ownership.
- Vector-node interactive normalization ownership.

### 6.8 Prohibited

- Moving shared runtime geometry logic out of its existing `node_geometry.dart`
  owner to reduce `nodes.dart` metrics.
- Hiding the same mixed constructor family behind cosmetic wrappers.
- Changing `topLeftWorld` or world/local normalization semantics to improve
  clone counts.
- Pulling `PathNode` cache work or leaf support cleanup into this step.

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

### Slice 1. [x] Box-node family placement owner is isolated

#### Slice Contract

`ImageNode`, `TextNode`, and `RectNode` no longer keep duplicated top-left and
local-rect ownership in separate handwritten bodies.

#### Change

Вынести box-node placement and local-rect semantics behind one focused
core-local owner path beneath the existing node entrypoints.

#### Verification

- `dcm calculate-metrics lib/src/core/nodes.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- MCP test runner: `test/core/nodes_test.dart`
- MCP test runner: `test/render/render_geometry_cache_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The replaced box-node constructor family is no longer present in the same
  handwritten form.

### Slice 2. [x] Vector-node world/local conversion owner is isolated

#### Slice Contract

`StrokeNode` and `LineNode` no longer keep mixed world/local creation and
interactive normalization ownership in separate handwritten bodies.

#### Change

Вынести vector-node world/local creation and normalization semantics behind one
focused core-local owner path beneath the existing node entrypoints.

#### Verification

- `dcm calculate-metrics lib/src/core/nodes.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- MCP test runner: `test/core/nodes_test.dart test/core/scene_spatial_index_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The replaced vector-node constructor / normalization family is no longer
  present in the same handwritten form.

## 9. Final Verification

- `dcm calculate-metrics lib/src/core/nodes.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/core`
- MCP test runner: `test/core/nodes_test.dart test/core/scene_spatial_index_test.dart`
- MCP test runner: `test/render/render_geometry_cache_test.dart`
- MCP test runner:
  `test/interactive/core/scene_controller_interactive_invalid_pointer_input_test.dart`
- `dart run tool/check_import_boundaries.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
