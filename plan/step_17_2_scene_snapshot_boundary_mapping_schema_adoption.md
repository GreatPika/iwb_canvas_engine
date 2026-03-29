language: russian

# Шаг 17.2. Перевести Scene <-> SceneSnapshot mapping на schema-owned boundary path

## 1. Change Mandate

Этот шаг переводит runtime boundary conversion `Scene <-> SceneSnapshot` и
model-side `txnNodeFromSnapshot(...)` / `txnNodeFromSpec(...)` на
schema-owned boundary path без вмешательства в JSON transport.

## 2. Change Boundary

### Included in the Change

- Перевод `txnNodeFromSnapshot(...)` и `txnNodeFromSpec(...)` на
  schema-owned boundary mapping.
- Перевод `Scene -> SceneSnapshot` и `SceneSnapshot -> Scene` conversion path
  на schema-owned boundary mapping.
- Удаление legacy handwritten node-shape bodies из owning model conversion
  seam.

### Not Included in the Change

- `lib/src/contract/**` as the source-of-truth semantics
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_json.part.dart`
- `lib/src/model/scene_builder_json_require.part.dart`
- `lib/src/serialization/scene_codec.dart`
- JSON transport parsing / emission

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/document.dart`
- `lib/src/model/document_clone.dart`
- `lib/src/model/scene_builder_scene_from_snapshot.part.dart`
- `lib/src/model/scene_builder_snapshot_from_scene.part.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`

### Test Files

- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_structural_limits_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`

### Analysis Area

- `lib/src/model/document.dart`
- `lib/src/model/document_clone.dart`
- `lib/src/model/scene_builder_scene_from_snapshot.part.dart`
- `lib/src/model/scene_builder_snapshot_from_scene.part.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `test/model/**`
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

1. `SceneSnapshot` remains the committed boundary model and `Scene` remains the
   internal mutable model.
2. Derived text-size semantics on import / runtime conversion remain unchanged.
3. This step does not change JSON field naming, `SceneDataException` contract,
   or schema-version surface.
4. Model conversion may consume schema-owned descriptors, but it may not define
   a second owner for the same node family semantics.
5. The full runtime conversion seam in `document.dart`,
   `scene_builder_scene_from_snapshot.part.dart`,
   `scene_builder_snapshot_from_scene.part.dart`, and
   `scene_snapshot_from_scene.dart` belongs to this single step and is not
   split into separate mini-owners.

## 5. Result Requirements

1. Runtime boundary conversion uses one schema-owned node-shape path.
2. `Scene <-> SceneSnapshot` round-trip semantics remain equivalent to the
   current behavior.
3. Derived text-size behavior on runtime conversion does not fork.
4. No second handwritten node-shape table remains in the model conversion seam.
5. New owners and step-owned methods do not introduce new `HIGH`/`VERY HIGH`
   configured metric violations from `analysis_options.yaml`.
6. Repeated clone inventory for `lib/src/model` no longer contains the
   baseline conversion-family clusters that this step migrates.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The focus seam is the runtime conversion path where confirmed hotspots and
  duplicate ownership already exist:
  - `txnNodeFromSnapshot(...) = 117` `source-lines-of-code` in
    `lib/src/model/document.dart`;
  - `txnNodeFromSpec(...) = 116` `source-lines-of-code` in
    `lib/src/model/document.dart`;
  - a conversion-family cluster across
    `lib/src/model/document_clone.dart`,
    `lib/src/model/scene_builder_scene_from_snapshot.part.dart`, and
    `lib/src/model/scene_snapshot_from_scene.dart`;
  - `_txnApply*Patch` family clustering inside `document.dart`.
- This step owns runtime conversion only; it must not solve JSON decode or
  encode concerns while closing the model-side duplicate ownership.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_clone.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart lib/src/model/scene_builder_snapshot_from_scene.part.dart lib/src/model/scene_snapshot_from_scene.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/document_model_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`

### 6.3 Protected States, Data, or Structures

- `SceneSnapshot` as the committed boundary model.
- `Scene` as the internal mutable model.
- Derived text-size semantics on import and runtime conversion.
- JSON field naming, `SceneDataException` contract, and schema-version surface.

### 6.4 Allowed Semantic Change Zones

- `txnNodeFromSnapshot(...)`
- `txnNodeFromSpec(...)`
- `Scene -> SceneSnapshot` export path
- `SceneSnapshot -> Scene` import path
- Thin model-specific glue above the schema owner, if it does not become a
  second source of truth

### 6.8 Prohibited

- Defining a second handwritten owner for common or family-specific node-shape
  semantics inside `lib/src/model/**`.
- Changing JSON transport parsing or emission as part of this step.
- Forking derived text-size behavior across the runtime conversion paths.
- Splitting the runtime conversion seam into separate competing owners.
- Leaving legacy duplicate bodies in the owning seam after the migration.

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

### Slice 1. [x] Transaction node conversion adopts the schema-owned mapping

#### Slice Contract

`txnNodeFromSnapshot(...)` and `txnNodeFromSpec(...)` no longer encode their
own handwritten node-shape tables and consume the schema-owned boundary path.

#### Change

Перевести `txnNodeFromSnapshot(...)` и `txnNodeFromSpec(...)` в
`lib/src/model/document.dart` на schema-owned field semantics и удалить
замещённые duplicate bodies.

#### Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_clone.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart lib/src/model/scene_builder_snapshot_from_scene.part.dart lib/src/model/scene_snapshot_from_scene.dart --report-all`
- MCP test runner: `test/model/document_model_test.dart`
- MCP test runner: `test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `document.dart` no longer contains a second handwritten node-shape table for
  `txnNodeFromSnapshot(...)` or `txnNodeFromSpec(...)`.

### Slice 2. [x] Scene and SceneSnapshot conversion share one boundary path

#### Slice Contract

`Scene -> SceneSnapshot` and `SceneSnapshot -> Scene` conversion use one
schema-owned boundary mapping across the model conversion seam.

#### Change

Перевести `lib/src/model/document_clone.dart`,
`lib/src/model/scene_builder_scene_from_snapshot.part.dart`,
`lib/src/model/scene_builder_snapshot_from_scene.part.dart` и
`lib/src/model/scene_snapshot_from_scene.dart` на тот же schema-owned path.
Особое внимание приложить к `_sceneFromSnapshot(...)`,
`_sceneNodeFromSnapshot(...)` и `sceneSnapshotFromScene(...)`.

#### Verification

- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Clone inventory no longer shows the replaced conversion family across
  `document.dart`, `scene_builder_scene_from_snapshot.part.dart`, and
  `scene_snapshot_from_scene.dart`.

### Slice 3. [x] Legacy model conversion bodies are removed

#### Slice Contract

После миграции в model conversion seam не остаётся handwritten node-shape
mapping рядом со schema-owned path.

#### Change

Удалить legacy handwritten node-shape bodies из owning model conversion seam и
свести оставшийся model-specific glue к thin adaptation поверх schema owner-а.

#### Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_clone.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart lib/src/model/scene_builder_snapshot_from_scene.part.dart lib/src/model/scene_snapshot_from_scene.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/document_model_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- No legacy duplicate body remains in the runtime conversion seam after the
  schema-owned mapping is adopted.

## 9. Final Verification

- `dcm calculate-metrics lib/src/model/document.dart lib/src/model/document_clone.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart lib/src/model/scene_builder_snapshot_from_scene.part.dart lib/src/model/scene_snapshot_from_scene.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/model`
- MCP test runner: `test/model/document_model_test.dart test/model/scene_builder_test.dart test/model/scene_structural_limits_test.dart`
- MCP test runner: `test/public_api/scene_builder_test.dart test/public_api/validated_boundary_value_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
