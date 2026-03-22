language: russian

# Шаг 18.2. Перевести model boundary mapping на node-family vertical slices

## 1. Change Mandate

Этот шаг переводит model-side boundary conversion с direction-first matrix на
node-family vertical slices без изменения runtime и public boundary semantics.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/document.dart` only for `txnNodeFromSnapshot(...)`,
  `txnNodeFromSpec(...)`, and their conversion-local glue
- `lib/src/model/document_clone.dart`
- `lib/src/model/scene_builder_scene_from_snapshot.part.dart`
- `lib/src/model/scene_builder_snapshot_from_scene.part.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/scene_node_boundary_mapping_common.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_spec.part.dart`
- `lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart`

### Not Included in the Change

- Decode/import helper matrix in `SceneBuilder`
- Value-validation matrix
- Contract-side field-semantics owner
- Patch/apply helpers and unrelated document-local runtime utilities in
  `document.dart`
- Runtime orchestration and render/view work

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/document.dart` only for `txnNodeFromSnapshot(...)`,
  `txnNodeFromSpec(...)`, and their conversion-local glue
- `lib/src/model/document_clone.dart`
- `lib/src/model/scene_builder_scene_from_snapshot.part.dart`
- `lib/src/model/scene_builder_snapshot_from_scene.part.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/scene_node_boundary_mapping_common.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_spec.part.dart`
- `lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart`

### Test Files

- `test/model/document_model_test.dart`
- `test/model/document_clone_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_structural_limits_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_fixture_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_18_2_model_boundary_mapping_vertical_slices.md`

### Analysis Area

- `lib/src/model/**`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/scene_fixture_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one model-side mapping
  slice.
- Changes in `document.dart` are limited to the conversion-entrypoint span used
  by this step; unrelated patch/apply helpers are out of scope.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `NodeBoundarySchema` remains the source of field semantics.
2. Runtime conversion must not become a second handwritten owner of the same
   node-family rules.
3. `SceneSnapshot` stays the committed boundary model and `Scene` stays the
   mutable runtime model.
4. Derived text-size semantics remain single-owned and must not fork.

## 5. Result Requirements

1. Model-side conversion no longer uses direction-first duplicate bodies for
   the same node families inside the owned seam.
2. `Scene -> SceneSnapshot`, `SceneSnapshot -> Scene`, `txnNodeFromSnapshot`,
   and `txnNodeFromSpec` remain behaviorally equivalent to the current
   contract.
3. The current confirmed model mapping cluster family improves against the
   starting baseline centered on `scene_node_boundary_mapping*.part.dart`.
4. `scene_node_boundary_mapping_to_snapshot.part.dart` no longer keeps the
   legacy direction-first family bodies, while model-side snapshot conversion
   continues to consume the existing contract fast-path surface without opening
   a new contract-owned API in this step.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed dominant cluster in `lib` is the mapping family across:
  - `scene_node_boundary_mapping_from_snapshot.part.dart`
  - `scene_node_boundary_mapping_from_spec.part.dart`
  - `scene_node_boundary_mapping_to_snapshot.part.dart`
- Current confirmed pair inventory shows exact-family repetition across
  `_image*`, `_text*`, `_stroke*`, `_line*`, `_rect*`, and `_path*`
  conversion bodies.
- `scene_node_boundary_mapping_to_snapshot.part.dart` is an owned downstream
  consumer of `*NodeSnapshotFromValidated(...)`; this step may reorganize those
  consumers around model-side node-family slices, but it does not reopen the
  contract-owned fast-path API surface closed by `18.1`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_clone.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart lib/src/model/scene_builder_snapshot_from_scene.part.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_common.part.dart lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart lib/src/model/scene_node_boundary_mapping_from_spec.part.dart lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/document_model_test.dart test/model/document_clone_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`

### 6.3 Protected States, Data, or Structures

- Runtime conversion semantics between `Scene` and `SceneSnapshot`.
- Derived text-size behavior.
- `NodeBoundarySchema` ownership of field semantics.
- Existing patch/apply semantics and document-local mutation helpers outside the
  conversion-entrypoint span.

### 6.4 Allowed Semantic Change Zones

- Runtime conversion entrypoints `txnNodeFromSnapshot(...)` and
  `txnNodeFromSpec(...)` in `document.dart`.
- Model-side conversion helpers around `Scene <-> SceneSnapshot`.
- Private model-side mapping layout and helper ownership.

### 6.8 Prohibited

- Forking node-family rules away from `NodeBoundarySchema`.
- Mixing decode/import or encode/export transport ownership into this step.
- Editing `txnApply*`, patch-target validation, insertion, locator, or other
  unrelated runtime helpers in `document.dart` as part of this step.
- Leaving legacy direction-first conversion bodies next to the new vertical
  slices.

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

### Slice 1. [x] Runtime conversion entrypoints consume node-family vertical slices

#### Slice Contract

`txnNodeFromSnapshot(...)` and `txnNodeFromSpec(...)` no longer depend on
direction-first duplicate bodies for the migrated node families.

#### Change

Перевести только `txnNodeFromSnapshot(...)`, `txnNodeFromSpec(...)`, and the
model-side conversion glue on node-family vertical slices built above
`NodeBoundarySchema`.

#### Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_common.part.dart lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart lib/src/model/scene_node_boundary_mapping_from_spec.part.dart --report-all`
- MCP test runner: `test/model/document_model_test.dart`
- MCP test runner: `test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Conversion-entrypoint span in `document.dart` no longer keeps the replaced
  direction-first family bodies.

### Slice 2. [x] Scene and SceneSnapshot conversion share the same node-family slices

#### Slice Contract

`Scene -> SceneSnapshot` and `SceneSnapshot -> Scene` conversion paths reuse
the same node-family slices without keeping the legacy direction-first matrix.

#### Change

Перевести `document_clone.dart`,
`scene_builder_scene_from_snapshot.part.dart`,
`scene_builder_snapshot_from_scene.part.dart`,
`scene_snapshot_from_scene.dart`, and the remaining mapping parts on the same
node-family slices, reorganize the owned
`*NodeSnapshotFromValidated(...)` consumers in
`scene_node_boundary_mapping_to_snapshot.part.dart` around the same
model-side family slices, and remove the replaced direction-first bodies
without expanding the contract boundary.

#### Verification

- `dcm calculate-metrics lib/src/model/document_clone.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart lib/src/model/scene_builder_snapshot_from_scene.part.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/document_clone_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Model clone inventory no longer shows the replaced mapping family in the same
  form.

## 9. Final Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_clone.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart lib/src/model/scene_builder_snapshot_from_scene.part.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_common.part.dart lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart lib/src/model/scene_node_boundary_mapping_from_spec.part.dart lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/document_model_test.dart test/model/document_clone_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
