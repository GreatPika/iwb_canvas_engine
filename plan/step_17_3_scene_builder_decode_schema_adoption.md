language: russian

# Шаг 17.3. Перевести SceneBuilder JSON decode/import на schema-owned boundary path

## 1. Change Mandate

Этот шаг переводит `SceneBuilder` JSON decode/import на schema-owned boundary
path и оставляет в decode seam только transport-specific parsing и
`SceneDataException` attribution.

## 2. Change Boundary

### Included in the Change

- Сведение raw JSON require helpers к одному decode-side owner-у внутри
  `SceneBuilder` seam.
- Перевод common node-field decode и family-specific node decode на
  schema-owned field descriptions.
- Удаление legacy duplicate helpers и duplicate node-family decode bodies в
  owning decode seam.

### Not Included in the Change

- Runtime `Scene <-> SceneSnapshot` conversion
- `lib/src/serialization/scene_codec.dart`
- `controller/**`, `interactive/**`, `render/**`, `view/**`

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

### Analysis Area

- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_json.part.dart`
- `lib/src/model/scene_builder_json_require.part.dart`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/**`
- `analysis_options.yaml`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified supporting file must be tied to a specific
  verification or metric gate.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneBuilder` decode/import remains the owner of raw JSON parsing and
   `SceneDataException` attribution.
2. The contract-owned schema owner does not become a JSON parser and does not
   throw `SceneDataException` instead of the decode seam.
3. Supported schema versions, JSON field naming, and import-visible validation
   semantics remain unchanged.
4. Derived text-size semantics on the import path remain unchanged.
5. `scene_builder.dart`, `scene_builder_decode_json.part.dart`, and
   `scene_builder_json_require.part.dart` belong to this single step and are
   not split between multiple owners.

## 5. Result Requirements

1. In `SceneBuilder` decode/import there is one owner for raw JSON require
   helpers and one schema-owned owner for boundary field semantics.
2. JSON field naming, required-field behavior, and `SceneDataException`
   attribution do not fork.
3. Import-visible validation semantics and derived text-size behavior remain
   equivalent to the current behavior.
4. No handwritten node-shape table remains in the decode seam next to the
   schema-owned path.
5. New owners and step-owned methods do not introduce new `HIGH`/`VERY HIGH`
   configured metric violations from `analysis_options.yaml`.
6. Repeated clone inventory for `lib/src/model` no longer contains the
   baseline helper / decode families that this step migrates.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The decode seam already contains the largest confirmed graph cluster between
  `lib/src/model/scene_builder_decode_json.part.dart` and
  `lib/src/model/scene_builder_json_require.part.dart` around `_require*`,
  `_optional*`, `_requireObjectValue(...)`, `_requireTypedField(...)`, and
  related helpers.
- Confirmed DCM hotspots inside
  `lib/src/model/scene_builder_decode_json.part.dart` must be resolved through
  consolidation, not cosmetic extraction:
  - `_decodeNodeBaseFields(...) = 41` `source-lines-of-code`;
  - `_decodeTextFields(...) = 65` `source-lines-of-code`.
- The seam already owns handwritten node-family decode bodies:
  `_decodeLineNode(...)`, `_decodePathNode(...)`, `_decodeRectNode(...)`,
  `_decodeStrokeNode(...)`.
- Field presence, raw type mismatch, and `SceneDataException` attribution stay
  owned by the decode seam after the migration.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.part.dart lib/src/model/scene_builder_json_require.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_builder_test.dart test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

### 6.3 Protected States, Data, or Structures

- `SceneBuilder` ownership of raw JSON parsing.
- `SceneDataException` attribution on the import path.
- Supported schema versions and JSON field naming.
- Import-visible validation semantics and derived text-size behavior.

### 6.4 Allowed Semantic Change Zones

- One decode-side owner for `_require*` and `_optional*` helper families.
- Common node-field decode through schema-owned field descriptions.
- Family-specific node decode through schema-owned field descriptions.
- Thin transport-specific parsing and attribution glue inside the decode seam.

### 6.8 Prohibited

- Moving raw JSON parsing or `SceneDataException` attribution into the
  contract-owned schema owner.
- Changing supported schema versions or JSON field naming.
- Leaving duplicated `_require*` / `_optional*` helper families across
  `decode_json` and `json_require`.
- Leaving duplicate node-family decode bodies in the owning seam after the
  migration.
- Mixing encode/export concerns into this decode-only step.

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

### Slice 1. [x] One decode-side owner for raw JSON require helpers

#### Slice Contract

`SceneBuilder` decode/import has one owner for raw JSON require helpers inside
the decode seam.

#### Change

Свести `_require*`, `_optional*`, `_requireObjectValue(...)`,
`_requireTypedField(...)` и related helpers к одному decode-side owner-у внутри
`SceneBuilder` seam.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.part.dart lib/src/model/scene_builder_json_require.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_builder_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Graph clone inventory no longer shows the replaced helper family between
  `scene_builder_decode_json.part.dart` and
  `scene_builder_json_require.part.dart`.

### Slice 2. [x] Node decode consumes schema-owned field descriptions

#### Slice Contract

Common node-field decode and family-specific node decode no longer define a
second handwritten node-shape mapping in `SceneBuilder`.

#### Change

Перевести `_decodeNodeBaseFields(...)`, `_decodeTextFields(...)`,
`_decodeLineNode(...)`, `_decodePathNode(...)`, `_decodeRectNode(...)` и
`_decodeStrokeNode(...)` на schema-owned field descriptions.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_builder.dart lib/src/model/scene_builder_decode_json.part.dart lib/src/model/scene_builder_json_require.part.dart --report-all`
- MCP test runner: `test/model/scene_builder_test.dart test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Decode seam no longer keeps a handwritten node-shape table next to the
  schema-owned path.

### Slice 3. [x] Decode seam retains transport ownership after cleanup

#### Slice Contract

После migration decode seam retains field presence checks, raw type mismatch
handling, and `SceneDataException` attribution while all duplicate helper and
node-family bodies are removed.

#### Change

Удалить legacy duplicate helpers и duplicate node-family decode bodies и
оставить в `SceneBuilder` только transport-specific parsing и attribution.

#### Verification

- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_builder_test.dart test/model/scene_value_validation_primitives_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`
- MCP test runner: `test/serialization/scene_fixture_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- The decode seam still owns raw JSON parsing and `SceneDataException`
  attribution, but no duplicate helper or node-family decode body remains.

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
