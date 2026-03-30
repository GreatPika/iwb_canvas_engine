language: russian

# Шаг 65. Свести clone/import/export обход сцены к одному canonical traversal helper

## 1. Change Mandate

Этот шаг дожимает residual scene-graph traversal seam:
верхнеуровневый обход и сборка
`Scene`,
`BackgroundLayer`,
`ContentLayer`,
`Camera`,
`Background`,
и
`ScenePalette`
перестаёт жить в трёх параллельных owner-ах:
`document_clone.dart`,
`scene_from_snapshot.dart`,
и
`scene_snapshot_from_scene.dart`.

После шага один internal traversal helper становится canonical owner-ом
scene-level traversal and container assembly,
а текущие entrypoint-ы остаются thin adapters над ним.
Узловое преобразование не переизобретается и по-прежнему делегируется в
`scene_node_boundary_mapping.dart`.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/document_clone.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_graph_traversal.dart`
- `lib/src/model/scene_node_boundary_mapping.dart` only if direct adaptation
  is required to keep node-level conversion as the canonical delegated owner
- `lib/src/model/document.dart` only if direct adaptation is required to keep
  existing model entrypoints thin after the traversal helper is introduced
- `lib/src/model/scene_builder.dart` only if direct adaptation is required to
  keep the current import/export facade behavior
- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `PLAN.md`
- `plan/model_target_architecture.md`
- `plan/step_48_model_residual_architecture_closure.md`
- `plan/step_51_scene_decode_and_scene_mutation_owner_split.md`
- `plan/step_65_scene_graph_traversal_helper.md`

### Not Included in the Change

- `lib/src/model/scene_node_boundary_mapping_common.dart`
- `lib/src/model/scene_node_boundary_mapping_image.dart`
- `lib/src/model/scene_node_boundary_mapping_text.dart`
- `lib/src/model/scene_node_boundary_mapping_stroke.dart`
- `lib/src/model/scene_node_boundary_mapping_line.dart`
- `lib/src/model/scene_node_boundary_mapping_rect.dart`
- `lib/src/model/scene_node_boundary_mapping_path.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_builder_decode*.dart`
- `lib/src/model/scene_value_validation*.dart`
- `ARCHITECTURE.md`
- `API_GUIDE.md`
- `README.md`
- `CHANGELOG.md`
- Any JSON serialization helper or generic `support/utils` bucket
- Reopening node-level mapping ownership already centralized in
  `scene_node_boundary_mapping.dart`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/document_clone.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_graph_traversal.dart`
- `PLAN.md`

### Test Files

- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`

### Fixture and Supporting Data Files

- `plan/model_target_architecture.md`
- `plan/step_48_model_residual_architecture_closure.md`
- `plan/step_51_scene_decode_and_scene_mutation_owner_split.md`
- `plan/step_65_scene_graph_traversal_helper.md`

### Analysis Area

- `lib/src/model/document_clone.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_graph_traversal.dart`
- `lib/src/model/scene_node_boundary_mapping.dart`
- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied either to the new canonical
  scene traversal helper or to reducing one of the current clone/import/export
  entrypoints to a thin adapter over it.
- Every modified test must pin one proof that clone/import/export behavior or
  traversal-specific edge handling stayed equivalent after the helper move.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `scene_node_boundary_mapping.dart` remains the canonical owner of node-level
   mapping and cloning logic.
2. `document_clone.dart`,
   `scene_from_snapshot.dart`,
   and
   `scene_snapshot_from_scene.dart`
   remain the model entrypoints for clone/import/export behavior, but after
   this step they are thin adapters over one internal traversal owner.
3. `scene_policy.dart` remains the owner of scene-level semantic validation;
   this step must not move validation or duplicate/range semantics into the
   traversal helper.
4. The new internal owner is a focused traversal helper, not a generic
   `support/helpers/utils` bucket and not a second node-mapping owner.
5. Differences between clone, import, and export remain strategy-defined:
   shallow vs deep node handling,
   snapshot/runtime result type,
   and instance-revision policy stay explicit at the adapter edge.
6. Public or downstream-visible behavior of clone/import/export entrypoints
   must remain unchanged.
7. Metric or clone improvement counts only when the repeated scene-level
   traversal and container assembly is genuinely centralized.

## 5. Result Requirements

1. One internal canonical scene traversal helper exists and owns scene-level
   traversal plus top-level container assembly.
2. `document_clone.dart`,
   `scene_from_snapshot.dart`,
   and
   `scene_snapshot_from_scene.dart`
   become thin adapters over that helper.
3. Node-level conversion continues to be delegated to
   `scene_node_boundary_mapping.dart`.
4. Deep clone, shallow clone, snapshot import, and snapshot export preserve
   their current visible behavior.
5. Instance-revision handling differences remain explicit and covered by tests.
6. No second node-mapping owner or generic helper bucket is introduced.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `document_clone.dart`,
  `scene_from_snapshot.dart`,
  and
  `scene_snapshot_from_scene.dart`
  currently each rebuild scene-level traversal and container assembly for
  `backgroundLayer`,
  `layers`,
  `camera`,
  `background`,
  and
  `palette`.
- Node-level conversion is already centralized:
  cloning uses `cloneSceneNodeViaBoundarySchema(...)`,
  snapshot import uses `sceneNodeFromSnapshotViaBoundarySchema(...)`,
  and snapshot export uses `sceneNodeSnapshotBackingFromViaBoundarySchema(...)`.
- The residual seam is therefore not node mapping but scene-level traversal
  orchestration above it.
- `scene_from_snapshot.dart` and `scene_snapshot_from_scene.dart` stay the
  runtime import/export spine; this step only moves their repeated traversal
  into one internal owner beneath those same entrypoints.
- `document_clone.dart` keeps its public/model transaction helpers, but its
  clone traversal should reuse the same canonical scene-level owner instead of
  carrying a parallel shell assembly.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/document_clone.dart lib/src/model/scene_from_snapshot.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/scene_graph_traversal.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- `dart run tool/analysis/find_similar_clones.dart lib/src/model`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `core`
- MCP test runner preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Visible behavior of
  `txnCloneSceneShallow(...)`,
  `txnCloneScene(...)`,
  `sceneImportFromSnapshot(...)`,
  `sceneFromSnapshot(...)`,
  and
  `sceneSnapshotFromScene(...)`.
- Shallow-vs-deep clone semantics for layers, nodes, and mutable lists.
- Snapshot import/export behavior around camera, background, palette, and
  background-layer presence.
- Node-level mapping ownership in `scene_node_boundary_mapping.dart`.

### 6.4 Allowed Semantic Change Zones

- New internal traversal owner in `lib/src/model/scene_graph_traversal.dart`
- Scene-level traversal and container assembly in
  `document_clone.dart`,
  `scene_from_snapshot.dart`,
  and
  `scene_snapshot_from_scene.dart`
- Minimal direct adaptation in `document.dart` or `scene_builder.dart` only if
  required to preserve the current thin entrypoint behavior after the helper is
  introduced
- Test adaptation required to prove behavioral equivalence

### 6.8 Prohibited

- Reopening node-level mapping logic already owned by
  `scene_node_boundary_mapping.dart`.
- Moving scene-level validation semantics out of `scene_policy.dart`.
- Replacing the repeated traversal with a generic helper bucket that obscures
  ownership rather than clarifying it.
- Expanding the scope into builder decode, node validation, or render work.
- Mixing JSON serialization concerns into the traversal helper.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes clone/import/export attribution or result shape, the
   exact visible behavior must be pinned by tests in the same change.
7. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Introduce one canonical scene-level traversal helper

#### Slice Contract

Scene-level traversal and container assembly live in one focused internal
owner instead of being rebuilt independently by clone/import/export entrypoints.

#### Change

Introduce `lib/src/model/scene_graph_traversal.dart` as the canonical scene
traversal owner for
`backgroundLayer`,
`layers`,
`camera`,
`background`,
and
`palette`,
with explicit strategy callbacks for node conversion and result construction.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_graph_traversal.dart lib/src/model/document_clone.dart lib/src/model/scene_from_snapshot.dart lib/src/model/scene_snapshot_from_scene.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- MCP test runner preset: `model_contract`

#### Positive Scenarios

- The helper can support deep clone, snapshot import, and snapshot export
  without changing node-level mapping ownership.
- Background layer presence and content-layer ordering remain unchanged.

#### Negative Scenarios

- The helper does not become a second node-mapping owner.
- Validation or JSON responsibilities do not leak into the traversal helper.

#### Closure Evidence

- Green run of the listed verifications.
- One internal helper now owns the repeated scene-level traversal and
  container assembly.

### Slice 2. [x] Reduce clone/import/export entrypoints to thin adapters

#### Slice Contract

`document_clone.dart`,
`scene_from_snapshot.dart`,
and
`scene_snapshot_from_scene.dart`
retain their external roles but stop carrying parallel scene-level traversal
logic.

#### Change

Refactor the three entrypoints so they delegate traversal and top-level
container assembly to `scene_graph_traversal.dart`, while keeping their
strategy-specific behavior for shallow vs deep clone, import/export result
type, and instance-revision handling.

#### Verification

- `dcm calculate-metrics lib/src/model/document_clone.dart lib/src/model/scene_from_snapshot.dart lib/src/model/scene_snapshot_from_scene.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/model`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `core`
- MCP test runner preset: `example`

#### Positive Scenarios

- Shallow clone still shares node objects where it shared them before.
- Deep clone still duplicates mutable node state where it duplicated it before.
- Snapshot import/export still preserve camera, background, palette, and layer
  structure.

#### Negative Scenarios

- Entry points do not regain duplicated scene shell assembly after the helper
  is introduced.
- Node conversion does not move out of `scene_node_boundary_mapping.dart`.
- Instance-revision policy does not become implicit or hidden.

#### Closure Evidence

- Green run of the listed verifications.
- The three entrypoints are visibly thinner and strategy-focused.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner preset: `core`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `controller_internal`
- MCP test runner preset: `controller`
- MCP test runner preset: `render_view`
- MCP test runner preset: `interactive`
- MCP test runner preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
