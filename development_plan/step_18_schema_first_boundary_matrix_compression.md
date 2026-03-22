language: russian

# Шаг 18. Сжать `schema-first` boundary matrix через подшаги 18.1-18.6

## 1. Change Mandate

Этот шаг сжимает оставшуюся `schema-first` boundary matrix в `contract/model`,
сохраняя одного owner-а field semantics и не меняя public contract behavior.

## 2. Change Boundary

### Included in the Change

- Contract-side constructor / fast-path family assembly.
- Model-side boundary mapping, decode/require matrix, and value-validation
  matrix.
- Post-step rebaseline и roadmap refresh по `lib/**`.

### Not Included in the Change

- `controller/**`, `interactive/**`, `render/**`, `view/**`.
- Public API, export surface, `schemaVersion = 5`, and external JSON contract.
- Runtime orchestration and render/view hotspot work outside the listed seam.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/internal/node_boundary_schema.dart`
- `lib/src/contract/internal/node_boundary_schema_patch.part.dart`
- `lib/src/contract/internal/node_boundary_schema_spec.part.dart`
- `lib/src/contract/internal/node_boundary_schema_snapshot.part.dart`
- `lib/src/contract/internal/node_patch_fast_path.part.dart`
- `lib/src/contract/internal/node_spec_fast_path.part.dart`
- `lib/src/contract/internal/snapshot_fast_path.part.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/snapshot.dart`
- `lib/src/model/document.dart`
- `lib/src/model/document_clone.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_json.part.dart`
- `lib/src/model/scene_builder_json_require.part.dart`
- `lib/src/model/scene_builder_scene_from_snapshot.part.dart`
- `lib/src/model/scene_builder_snapshot_from_scene.part.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/scene_node_boundary_mapping_common.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_spec.part.dart`
- `lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart`
- `lib/src/model/scene_value_validation.dart`
- `lib/src/model/scene_value_validation_node.part.dart`
- `lib/src/model/scene_value_validation_palette_grid.part.dart`
- `lib/src/model/scene_value_validation_primitives.part.dart`
- `lib/src/model/scene_value_validation_top_level.part.dart`

### Test Files

- `test/contract/**`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/scene_fixture_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `DEVELOPMENT_PLAN.md`
- `development_plan/step_18*.md`

### Analysis Area

- `lib/src/contract/**`
- `lib/src/model/**`
- `test/contract/**`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/scene_fixture_test.dart`
- `development_plan/step_18*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to exactly one substep.
- Every new or modified test must be tied to a specific verification surface.
- Every modified planning document must be tied to one measured baseline or one
  execution slice.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `NodeBoundarySchema` remains the only private contract-owned owner of
   boundary field semantics.
2. Public contract types remain explicit and are not replaced with a generic
   nullable payload object.
3. Decode-side transport ownership stays in `SceneBuilder`, and encode-side
   transport ownership stays in `SceneCodec`.
4. `schemaVersion = 5`, supported schema versions, and external JSON field
   naming remain unchanged.
5. This step compresses the matrix shape of the seam and must not reopen
   runtime orchestration or render/view scope.

## 5. Result Requirements

1. The targeted boundary seam keeps one field-semantics owner and no longer
   keeps direction-first duplicate bodies for the same node family in the owned
   zones of this step.
2. Contract and model consumers remain behaviorally equivalent on the public
   boundary.
3. The targeted hotspots improve against the current confirmed baseline:
   `28` `HIGH+` entries in the boundary matrix family and `19` related clone
   clusters inside `lib`.
4. Residual work after the step is captured from the new measured baseline and
   does not rely on the stale post-step assumptions of `17.5`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed boundary-matrix hotspot family contributes `28` of `104`
  `HIGH+` entries in `lib/src`.
- Current confirmed clone inventory for `lib` contains `58` clusters total, of
  which `19` involve
  `node_boundary_schema`, `fast_path`, `scene_node_boundary_mapping`,
  `scene_builder`, or `scene_value_validation`.
- The dominant residual families are:
  - contract-side fast paths in
    `snapshot_fast_path.part.dart`,
    `node_spec_fast_path.part.dart`,
    `node_patch_fast_path.part.dart`;
  - model-side direction-first mapping in
    `scene_node_boundary_mapping*.part.dart`;
  - decode/require and validation helper matrices in
    `scene_builder*.part.dart` and `scene_value_validation*.part.dart`.
- Within that family, `snapshot_fast_path.part.dart` spans contract-owned
  assembly and downstream model/decode consumers, so its hotspot closure is
  split across `18.1`, `18.2`, and `18.3` instead of being owned entirely by
  the contract-only boundary of `18.1`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/contract`
- MCP test runner: `test/model test/public_api`
- MCP test runner: `test/serialization/scene_fixture_test.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`

### 6.3 Protected States, Data, or Structures

- `NodeBoundarySchema` ownership of field semantics.
- Public contract and transport behavior on `snapshot/spec/patch`.
- Supported schema versions and JSON field naming.
- Decode-side and encode-side transport ownership.

### 6.4 Allowed Semantic Change Zones

- Contract-side family assembly for constructor and fast-path code.
- Model-side boundary conversion and decode-side helper ownership.
- Model-side validation combinators and family-specific validation paths.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `18.1` closes before `18.2`.
- `18.2` closes before `18.3`.
- `18.3` closes before `18.4`.
- `18.6` is forbidden until `18.1-18.5` are closed and remeasured.

### 6.8 Prohibited

- Introducing a second owner of boundary field semantics.
- Reopening runtime/controller or render/view work as part of this step.
- Replacing duplicate bodies with cosmetic wrappers that preserve the same
  direction-first matrix shape.

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

### Slice 1. [x] Contract family compression

#### Slice Contract

Закрыть `development_plan/step_18_1_contract_fast_path_and_constructor_family_compression.md`
без выхода за ownership boundary `18.1`.

#### Verification

- Verification from `18.1`

### Slice 2. [x] Model boundary mapping verticalization

#### Slice Contract

Закрыть `development_plan/step_18_2_model_boundary_mapping_vertical_slices.md`
без выхода за ownership boundary `18.2`.

#### Verification

- Verification from `18.2`

### Slice 3. [x] SceneBuilder matrix compression

#### Slice Contract

Закрыть `development_plan/step_18_3_scene_builder_decode_require_matrix_compression.md`
без выхода за ownership boundary `18.3`.

#### Verification

- Verification from `18.3`

### Slice 4. [x] Validation matrix compression

#### Slice Contract

Закрыть `development_plan/step_18_4_scene_value_validation_matrix_compression.md`
без выхода за ownership boundary `18.4`.

#### Verification

- Verification from `18.4`

### Slice 5. [x] Boundary matrix rebaseline

#### Slice Contract

Закрыть `development_plan/step_18_5_boundary_matrix_rebaseline_and_roadmap.md`
без повторного открытия semantic scope `18.1-18.4`.

#### Verification

- Verification from `18.5`

### Slice 6. [x] Review residual boundary matrix cleanup

#### Slice Contract

Corrective cleanup closes the live contract, decode, and mapping clusters that
remained after the `18.5` rebaseline.

#### Change

Закрыть remaining live boundary-matrix clusters that the review exposed after
`18.5`, then refresh the roadmap from the corrected baseline.

#### Verification

- Verification from `18.6`

#### Closure Evidence

- Green run of the listed verifications.
- The corrected baseline and roadmap no longer rely on the stale residual
  assumptions that were left after `18.5`.

## 9. Final Verification

- `dcm calculate-metrics lib/src/contract lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- MCP test runner: `test/contract`
- MCP test runner: `test/model test/public_api`
- MCP test runner: `test/serialization/scene_fixture_test.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
