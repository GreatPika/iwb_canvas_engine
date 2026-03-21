language: russian

# Шаг 17.3.1. Выровнять owner-а snapshot `instanceRevision` перед encode schema adoption

## 1. Change Mandate

Этот шаг выносит canonical normalization snapshot `instanceRevision` из
private txn-only owner-а в переиспользуемый owner, который нужен downstream
encode adoption без изменения текущего export contract.

## 2. Change Boundary

### Included in the Change

- Вынесение snapshot-sourced `instanceRevision` normalization из
  `document.dart` в один переиспользуемый owner.
- Перевод `txnNodeFromSnapshot(...)` на новый owner без изменения текущей
  positive/non-positive revision semantics.
- Подтверждение, что текущий `SceneCodec` contract остаётся эквивалентным
  через существующий encode path.

### Not Included in the Change

- `lib/src/serialization/scene_codec.dart`
- Common/family-specific node field schema adoption в encode seam
- JSON field naming, `schemaVersion`, `schemaVersionsRead`
- Runtime `Scene <-> SceneSnapshot` node-shape migration beyond
  `instanceRevision` normalization ownership

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/core/revision_policy.dart`
- `lib/src/model/document.dart`
- `lib/src/model/scene_builder_scene_from_snapshot.part.dart`

### Test Files

- `test/model/document_model_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_test.dart`

### Fixture and Supporting Data Files

- `DEVELOPMENT_PLAN.md`
- `development_plan/step_17_schema_first_boundary_transition.md`
- `development_plan/step_17_3_1_snapshot_instance_revision_owner_alignment.md`

### Analysis Area

- `lib/src/core/revision_policy.dart`
- `lib/src/model/document.dart`
- `lib/src/model/scene_builder_scene_from_snapshot.part.dart`
- `test/model/document_model_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/serialization/scene_test.dart`
- `development_plan/step_17*.md`
- `DEVELOPMENT_PLAN.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified supporting file must be tied to a specific
  verification or execution-control update.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneCodec` remains the owner of canonical JSON emission, and encode-side
   field-schema adoption stays in `17.4`.
2. Positive snapshot `instanceRevision` values remain preserved and
   non-positive snapshot values remain normalized through allocator-backed
   revision policy.
3. Current public encode contract continues to emit `instanceRevision` for
   every node.
4. This preparatory step does not reopen common/family node-shape ownership in
   `scene_codec.dart`.

## 5. Result Requirements

1. Snapshot-sourced `instanceRevision` normalization has one reusable owner
   outside the private txn-only body in `document.dart`.
2. `txnNodeFromSnapshot(...)` consumes that owner and preserves the current
   positive/non-positive revision behavior.
3. `encodeScene(...)` keeps the current canonical `instanceRevision` emission
   contract for nodes, including `>= 1` normalization for non-positive or
   missing snapshot revisions on the existing encode path.
4. Step-owned files do not introduce new `HIGH`/`VERY HIGH` configured metric
   violations from `analysis_options.yaml`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `SceneCodec` currently canonicalizes snapshots and then reaches
  `txnNodeFromSnapshot(...)` inside `_encodeCanonicalSnapshot(...)`.
- `txnNodeFromSnapshot(...)` currently resolves snapshot revisions through the
  private helper `_txnResolveSnapshotInstanceRevision(...)` in
  `document.dart`.
- Runtime snapshot import in `scene_builder_scene_from_snapshot.part.dart`
  currently keeps a second private `_resolveSnapshotInstanceRevision(...)`
  helper with the same positive/non-positive revision semantics.
- Existing regression tests prove the protected behavior:
  `encode -> decode -> encode is stable`,
  `decodeScene accepts JSON without instanceRevision and re-encodes with it`,
  and `encodeScene always writes instanceRevision for nodes`.
- A direct encode-side switch to raw `NodeSnapshot` field consumption without a
  shared revision owner breaks the protected `instanceRevision` contract.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/core/revision_policy.dart lib/src/model/document.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart --report-all`
- MCP test runner: `test/model/document_model_test.dart`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart test/serialization/scene_test.dart`

### 6.3 Protected States, Data, or Structures

- Current `instanceRevision` import/export behavior for positive and
  non-positive snapshot values.
- Current `SceneCodec` canonical JSON emission contract.
- Current JSON field naming, schema-version surface, and observable export
  shape.
- Ownership split where field-schema adoption remains in `17.4`.

### 6.4 Allowed Semantic Change Zones

- One reusable entrypoint for snapshot `instanceRevision` normalization above
  the low-level revision allocator primitives.
- `txnNodeFromSnapshot(...)` wiring to that shared owner.
- Regression coverage that proves the existing encode contract still holds
  through the current path.

### 6.8 Prohibited

- Changing JSON field naming, supported schema versions, or observable
  `instanceRevision` export behavior.
- Moving common/family node field emission or schema adoption into this step.
- Leaving both a shared snapshot revision owner and a second private copy of
  the same normalization rule in `document.dart`.
- Touching `lib/src/serialization/scene_codec.dart` as part of this
  preparatory step.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must
   be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Snapshot `instanceRevision` normalization has one reusable owner

#### Slice Contract

The rule that preserves positive snapshot revisions and allocates
non-positive snapshot revisions no longer lives only inside the private txn
seam and is reusable by downstream encode work.

#### Change

Extract one shared owner for snapshot `instanceRevision` normalization above
`document.dart` and `scene_builder_scene_from_snapshot.part.dart`, wire
`txnNodeFromSnapshot(...)` and runtime snapshot import through it, and keep
the current encode regression surface green without touching
`scene_codec.dart`.

#### Verification

- `dcm calculate-metrics lib/src/core/revision_policy.dart lib/src/model/document.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart --report-all`
- MCP test runner: `test/model/document_model_test.dart`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart test/serialization/scene_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `document.dart` and `scene_builder_scene_from_snapshot.part.dart` no longer
  contain private snapshot-revision normalization bodies that duplicate the
  shared owner.

## 9. Final Verification

- `dcm calculate-metrics lib/src/core/revision_policy.dart lib/src/model/document.dart lib/src/model/scene_builder_scene_from_snapshot.part.dart --report-all`
- MCP test runner: `test/model/document_model_test.dart`
- MCP test runner: `test/serialization/scene_codec_validation_test.dart test/serialization/scene_test.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
