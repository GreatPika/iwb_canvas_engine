language: russian

# Шаг 17.4. Перевести SceneCodec JSON encode/export на schema-owned boundary path

## 1. Change Mandate

Этот шаг переводит `SceneCodec` JSON encode/export на schema-owned boundary
path и оставляет encode seam owner-ом только canonical JSON emission.

## 2. Change Boundary

### Included in the Change

- Перевод `_encodeNode(...)` на schema-owned boundary field descriptions.
- Перевод canonical snapshot export на schema-owned node shape.
- Удаление legacy handwritten node-shape mapping из `scene_codec.dart`.

### Not Included in the Change

- `lib/src/model/**`
- `lib/src/contract/**` as the source-of-truth semantics
- JSON decode / import path
- Runtime `Scene <-> SceneSnapshot` conversion

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/serialization/scene_codec.dart`

### Test Files

- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/serialization/scene_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`

### Analysis Area

- `lib/src/serialization/scene_codec.dart`
- `test/serialization/**`
- `test/public_api/**`
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

1. `SceneCodec` remains the owner of canonical JSON emission and does not
   become the owner of field schema semantics.
2. The contract-owned schema owner does not become a transport-level encoder
   and does not replace `SceneCodec`.
3. JSON field naming, supported schema versions, and the observable export
   contract remain unchanged.
4. Encode-side omission / ordering behavior may be expressed only through the
   existing JSON contract and not through a new public abstraction layer.
5. `scene_codec.dart` belongs entirely to this single step and is not split
   between multiple owners.

## 5. Result Requirements

1. No handwritten node-shape table remains in the encode seam next to the
   schema-owned path.
2. Observable JSON export contract, field naming, and supported schema versions
   remain equivalent to the current behavior.
3. `SceneCodec` does not become a second source of truth for boundary field
   semantics.
4. New owners and step-owned methods do not introduce new `HIGH`/`VERY HIGH`
   configured metric violations from `analysis_options.yaml`.
5. Repeated clone inventory for `lib/src/serialization` no longer contains the
   baseline encode-side families that this step migrates.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The encode seam has confirmed hotspots in
  `lib/src/serialization/scene_codec.dart`:
  - `_encodeCanonicalSnapshot(...) = 52` `source-lines-of-code`;
  - `_encodeNode(...) = 14` `cyclomatic-complexity` and `83`
    `source-lines-of-code`.
- `scene_codec.dart` is already part of the baseline boundary hot zones for
  step `17`; this step closes the encode-side duplicate ownership without
  reopening decode/import semantics.
- Raw JSON parsing, `SceneDataException` attribution, and import-path semantics
  stay outside this step.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/serialization/scene_codec.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/serialization`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart test/serialization/scene_test.dart`
- MCP test runner: `test/public_api/validated_boundary_value_test.dart`

### 6.3 Protected States, Data, or Structures

- Canonical JSON emission ownership of `SceneCodec`.
- JSON field naming and supported schema versions.
- Observable export contract.
- Current encode-side omission and ordering behavior expressed by the existing
  JSON contract.

### 6.4 Allowed Semantic Change Zones

- `_encodeNode(...)`
- `_encodeCanonicalSnapshot(...)`
- Encode-side helper-ы, которые определяют field emission внутри
  `scene_codec.dart`
- Thin schema-owned consumption inside the encode seam without changing the
  public transport surface

### 6.8 Prohibited

- Moving encode ownership into the contract-owned schema owner.
- Changing JSON field naming, supported schema versions, or observable export
  semantics.
- Introducing a new public abstraction layer for encode-side omission or
  ordering behavior.
- Leaving a manual common or family-specific field table in `scene_codec.dart`
  after the migration.
- Mixing decode/import concerns into this encode-only step.

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

### Slice 1. [ ] Node encoding consumes schema-owned field descriptions

#### Slice Contract

`_encodeNode(...)` no longer defines a second handwritten node-shape mapping
and consumes the schema-owned boundary path.

#### Change

Перевести `_encodeNode(...)` и related encode-side helpers на schema-owned
field descriptions.

#### Verification

- `dcm calculate-metrics lib/src/serialization/scene_codec.dart --report-all`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart test/serialization/scene_test.dart`
- MCP test runner: `test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `scene_codec.dart` no longer keeps a second handwritten field table for
  common or family-specific node semantics.

### Slice 2. [ ] Canonical snapshot export remains the transport owner

#### Slice Contract

Canonical snapshot export consumes the schema-owned node shape while
`SceneCodec` remains the owner of JSON object assembly and field emission
policy.

#### Change

Перевести `_encodeCanonicalSnapshot(...)` на schema-owned node shape и удалить
legacy encode-side duplicate mapping из `scene_codec.dart`. Особое внимание
приложить к `_encodeCanonicalSnapshot(...)`, `_encodeNode(...)` и
encode-side helper-ам, которые определяют field emission.

#### Verification

- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/serialization`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart test/serialization/scene_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Clone inventory for `lib/src/serialization` no longer shows the baseline
  encode-side family that this step migrates.

## 9. Final Verification

- `dcm calculate-metrics lib/src/serialization/scene_codec.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/serialization`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart test/serialization/scene_fixture_test.dart test/serialization/scene_test.dart`
- MCP test runner: `test/public_api/validated_boundary_value_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
