language: russian

# Шаг 18.6. Закрыть review residual boundary matrix cleanup и обновить roadmap

## 1. Change Mandate

Этот шаг устраняет остаточные boundary-matrix кластеры, которые review показал
после rebaseline шага 18.5, и обновляет roadmap по фактическому residual scope
без metric-only wrapper-ов.

## 2. Change Boundary

### Included in the Change

- Contract-side constructor and fast-path family cleanup.
- SceneBuilder decode/import cleanup.
- Model-side mapping cleanup.
- Post-change rebaseline and roadmap refresh.

### Not Included in the Change

- `controller/**`, `interactive/**`, `render/**`, `view/**`.
- Public API surface, `schemaVersion = 5`, and external JSON contract.
- Runtime orchestration and render/view hotspot work.
- Validation matrix work outside the reviewed seams.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/internal/node_patch_fast_path.part.dart`
- `lib/src/contract/internal/node_spec_fast_path.part.dart`
- `lib/src/contract/internal/snapshot_fast_path.part.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/snapshot.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_contract_support.dart`
- `lib/src/model/scene_builder_decode_json.part.dart`
- `lib/src/model/scene_builder_json_require.part.dart`
- `lib/src/model/scene_node_boundary_mapping.dart`
- `lib/src/model/scene_node_boundary_mapping_common.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart`
- `lib/src/model/scene_node_boundary_mapping_from_spec.part.dart`
- `lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart`

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
- `lib/src/model/scene_builder*.dart`
- `lib/src/model/scene_node_boundary_mapping*.dart`
- `development_plan/step_18*.md`
- `DEVELOPMENT_PLAN.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every modified planning document must be tied to one measured baseline or
  one roadmap correction.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `NodeBoundarySchema` remains the only private contract-owned owner of
   boundary field semantics.
2. `SceneBuilder` keeps decode-side transport ownership.
3. Model-side mapping owns `Scene` and `SceneSnapshot` conversion.
4. `schemaVersion = 5`, supported schema versions, and external JSON field
   naming remain unchanged.

## 5. Result Requirements

1. The contract-side family no longer keeps duplicate bodies for the same node
   family across public constructors and validated fast paths.
2. `scene_builder_contract_support.dart` is removed, and `scene_builder.dart`
   imports contract symbols directly.
3. The SceneBuilder decode seam no longer keeps the wrapper matrix around
   `_requireValidatedField`.
4. `scene_node_boundary_mapping_common.part.dart` no longer keeps the reviewed
   `*_FromSnapshot` / `*_FromSpec` / `*_FromNode` triplets.
5. The corrected baseline and roadmap reflect the actual live residual work
   after the cleanup.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current clone inventory still has a 25-member contract cluster spanning
  `node_patch.dart`, `node_spec.dart`, `snapshot.dart`, and
  `snapshot_fast_path.part.dart`.
- Current model clone inventory still shows the decode/helper family centered on
  `scene_builder_decode_json.part.dart`, `scene_builder_json_require.part.dart`,
  and `scene_builder_contract_support.dart`.
- Current model clone inventory still shows the mapping family centered on
  `scene_node_boundary_mapping_common.part.dart`.
- `scene_builder_contract_support.dart` is imported only by `scene_builder.dart`
  and only re-exports contract symbols.
- The review showed `scene_node_boundary_mapping_common.part.dart` still keeps
  triplets such as `*_FromSnapshot`, `*_FromSpec`, and `*_FromNode`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- MCP test runner: `test/contract`
- MCP test runner: `test/model test/public_api`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

### 6.3 Protected States, Data, or Structures

- Public constructor behavior and validated fast-path output.
- Decode-side `SceneDataException` attribution and JSON field naming.
- Runtime conversion semantics between `Scene` and `SceneSnapshot`.
- Public API surface and supported schema versions.

### 6.4 Allowed Semantic Change Zones

- Contract-side family assembly for constructor and fast-path code.
- SceneBuilder decode/import helper ownership.
- Model-side mapping layout and node-family extraction ownership.

### 6.8 Prohibited

- Introducing wrapper-only import barrels that only move imports.
- Leaving replaced helper families next to the new compact path.
- Moving transport ownership into `NodeBoundarySchema`.
- Altering public API or external JSON contract.

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

### Slice 1. [x] Contract family cleanup

#### Slice Contract

The contract seam no longer keeps the live family cluster across public
constructors and validated fast paths.

#### Change

Свести shared family assembly in `node_patch.dart`, `node_spec.dart`,
`snapshot.dart`, and `snapshot_fast_path.part.dart` к одному compact contract
path and убрать оставшиеся duplicate family bodies.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_patch_fast_path.part.dart lib/src/contract/internal/node_spec_fast_path.part.dart lib/src/contract/internal/snapshot_fast_path.part.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/contract`
- MCP test runner: `test/contract`
- MCP test runner: `test/public_api/node_patch_semantics_test.dart test/public_api/snapshot_immutability_test.dart test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Clone inventory for `lib/src/contract` no longer shows the reviewed family in
  the same form.

### Slice 2. [x] Decode/import seam cleanup

#### Slice Contract

SceneBuilder decode/import seam no longer keeps the barrel or the thin wrapper
matrix in the same form.

#### Change

Удалить `scene_builder_contract_support.dart`, restore direct imports in
`scene_builder.dart`, and collapse `_requireValidatedField` wrappers into one
decode-side owner path.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.part.dart lib/src/model/scene_builder_json_require.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_builder_test.dart test/public_api/scene_builder_test.dart`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Decode/import seam no longer keeps the reviewed wrapper matrix in the same
  form.

### Slice 3. [x] Mapping cleanup

#### Slice Contract

The mapping seam no longer keeps the direction-first triplets for the reviewed
node families.

#### Change

Collapse `scene_node_boundary_mapping_common.part.dart` and the related
entrypoint parts onto one family-owned path and remove the replaced
direction-first bodies.

#### Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_clone.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart lib/src/model/scene_builder_snapshot_from_scene.part.dart lib/src/model/scene_snapshot_from_scene.dart lib/src/model/scene_node_boundary_mapping.dart lib/src/model/scene_node_boundary_mapping_common.part.dart lib/src/model/scene_node_boundary_mapping_from_snapshot.part.dart lib/src/model/scene_node_boundary_mapping_from_spec.part.dart lib/src/model/scene_node_boundary_mapping_to_snapshot.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/document_model_test.dart test/model/document_clone_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Clone inventory for `lib/src/model` no longer shows the reviewed mapping
  family in the same form.

### Slice 4. [x] Rebaseline and roadmap correction

#### Slice Contract

The corrected baseline and roadmap reflect the actual live residual work after
slices `18.1-18.3`.

#### Change

Переснять clone inventory и configured DCM baseline, затем обновить
`DEVELOPMENT_PLAN.md` and `development_plan/step_18*.md` from the corrected
residual scope.

#### Verification

- `dcm calculate-metrics lib/src/contract lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Planning files and step docs point at the corrected residual scope instead of
  the stale post-`18.5` assumptions.

## 9. Final Verification

- `dcm calculate-metrics lib/src/contract lib/src/model --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- MCP test runner: `test/contract`
- MCP test runner: `test/model test/public_api`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
