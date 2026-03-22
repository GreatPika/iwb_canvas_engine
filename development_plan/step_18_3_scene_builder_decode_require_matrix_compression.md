language: russian

# Шаг 18.3. Сжать SceneBuilder decode/require matrix без transport drift

## 1. Change Mandate

Этот шаг сжимает decode/require matrix в `SceneBuilder`, не меняя decode-side
transport ownership, `SceneDataException` attribution, or import semantics.

## 2. Change Boundary

### Included in the Change

- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_json.part.dart`
- `lib/src/model/scene_builder_json_require.part.dart`

### Not Included in the Change

- Contract-side field semantics owner
- Runtime conversion outside decode/import seam
- Encode/export seam
- Value-validation matrix outside decode-side helper ownership

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_json.part.dart`
- `lib/src/model/scene_builder_json_require.part.dart`

### Test Files

- `test/model/scene_builder_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_fixture_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_18_3_scene_builder_decode_require_matrix_compression.md`

### Analysis Area

- `lib/src/model/scene_builder*`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/scene_fixture_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one decode-side slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Raw JSON parsing and `SceneDataException` attribution remain decode-side
   ownership.
2. Supported schema versions and JSON field naming remain unchanged.
3. This step may compress helper and node-family decode bodies but must not
   move transport concerns into `NodeBoundarySchema`.
4. The step must remove duplicate helper families instead of wrapping them.

## 5. Result Requirements

1. `SceneBuilder` decode/import no longer keeps a duplicate `_require*` /
   `_optional*` helper matrix across the owned seam.
2. Family-specific node decode no longer keeps the current handwritten matrix
   next to the schema-owned path.
3. Decode/import behavior remains equivalent on the public boundary.
4. Decode-side consumers of `*NodeSnapshotFromValidated(...)` close the
   remaining snapshot fast-path hotspot migration deferred from `18.1`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed decode hotspot family is centered on
  `scene_builder_decode_json.part.dart` and
  `scene_builder_json_require.part.dart`.
- Confirmed repeating helper bodies include `_require*`, `_optional*`,
  `_requireObjectValue(...)`, `_requireTypedField(...)`, and related
  transport-specific helpers.
- Confirmed node-family decode bodies include
  `_decode*Node(...)`, `_decode*Fields(...)`, and related common-field decode.
- `scene_builder_decode_json.part.dart` is the decode-side owner of the
  remaining compact-call migration for `*NodeSnapshotFromValidated(...)`
  consumers that cannot be closed inside `18.1`.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.part.dart lib/src/model/scene_builder_json_require.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_builder_test.dart test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

### 6.3 Protected States, Data, or Structures

- Decode-side transport ownership.
- `SceneDataException` attribution.
- Supported schema versions and JSON field naming.

### 6.4 Allowed Semantic Change Zones

- `_require*` and `_optional*` helper ownership.
- Family-specific node decode and common node-field decode.
- Thin decode-side glue in `scene_builder.dart`.

### 6.8 Prohibited

- Moving transport parsing into the schema owner.
- Mixing encode/export concerns into this decode-only step.
- Leaving the replaced helper or node decode matrix next to the new compact
  path.

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

### Slice 1. [ ] One decode-side owner remains for require helpers

#### Slice Contract

`SceneBuilder` has one decode-side owner for require/optional helper families
 inside the decode seam.

#### Change

Свести helper matrix in `scene_builder_decode_json.part.dart` and
`scene_builder_json_require.part.dart` to one decode-side owner and remove the
replaced duplicates.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.part.dart lib/src/model/scene_builder_json_require.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_builder_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Decode seam no longer keeps the replaced helper family in two places.

### Slice 2. [ ] Family-specific node decode consumes one compact path

#### Slice Contract

Family-specific node decode and common node-field decode consume one compact
decode-side path above `NodeBoundarySchema`.

#### Change

Перевести `_decode*Fields(...)`, `_decode*Node(...)`, and related common-field
decode bodies on one compact decode-side path, migrate the owned
`*NodeSnapshotFromValidated(...)` decode consumers to the compact contract
call shape, and remove the replaced matrix.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder_decode_json.part.dart lib/src/model/scene_builder_json_require.part.dart --report-all`
- MCP test runner: `test/model/scene_builder_test.dart test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Decode seam no longer keeps the replaced node decode matrix next to the new
  compact path.

## 9. Final Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.part.dart lib/src/model/scene_builder_json_require.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_builder_test.dart test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
