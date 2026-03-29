language: russian

# Шаг 14.1. Закрыть regression-матрицу boundary, model и core

## 1. Change Mandate

This change closes the unresolved non-regression matrix for
`serialization/model/core` without reopening production semantics outside the
current boundary and scene owners.

## 2. Change Boundary

### Included in the Change
- `lib/src/serialization/scene_codec.dart`
- `lib/src/serialization/codec_guards.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/document.dart`
- `lib/src/model/scene_structural_limits.dart`
- `lib/src/core/background_layer_invariants.dart`
- `lib/src/core/id_generator.dart`
- `lib/src/core/revision_policy.dart`
- `lib/src/core/nodes.dart`
- `test/serialization/scene_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_structural_limits_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/core/background_layer_invariants_test.dart`
- `test/core/id_generator_test.dart`
- `test/core/revision_policy_test.dart`
- `test/core/nodes_test.dart`
- `test/core/public_contracts_constants_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

### Not Included in the Change
- Controller commit and command regressions
- Interactive or view pointer-lifecycle regressions
- Render/cache parity and invalidation regressions

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/serialization/scene_codec.dart`
- `lib/src/serialization/codec_guards.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/document.dart`
- `lib/src/model/scene_structural_limits.dart`
- `lib/src/core/background_layer_invariants.dart`
- `lib/src/core/id_generator.dart`
- `lib/src/core/revision_policy.dart`
- `lib/src/core/nodes.dart`

### Test Files
- `test/serialization/scene_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_structural_limits_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/core/background_layer_invariants_test.dart`
- `test/core/id_generator_test.dart`
- `test/core/revision_policy_test.dart`
- `test/core/nodes_test.dart`
- `test/core/public_contracts_constants_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

### Analysis Area
- `lib/src/serialization/**`
- `lib/src/model/**`
- `lib/src/core/background_layer_invariants.dart`
- `lib/src/core/id_generator.dart`
- `lib/src/core/revision_policy.dart`
- `lib/src/core/nodes.dart`
- `test/serialization/**`
- `test/model/**`
- `test/core/background_layer_invariants_test.dart`
- `test/core/id_generator_test.dart`
- `test/core/revision_policy_test.dart`
- `test/core/nodes_test.dart`
- `test/core/public_contracts_constants_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneDataException` remains the public failure contract for serialization
   and import boundaries.
2. Raw JSON length guarding stays on the decode boundary before `jsonDecode`.
3. Scene-level structural and range validation remains owned by
   `lib/src/model/scene_policy.dart`.
4. `backgroundLayer`, id generation, and revision semantics remain owned by the
   current `model/core` modules; this step only closes their regression proofs.

## 5. Result Requirements

1. Serialization regressions are covered for bad maps, oversized JSON, safe-int
   integers, schema-version failures, `TextAlign`, id boundaries, encode/decode
   symmetry, and `code/path/details` contract matrices.
2. Model regressions are covered for `backgroundLayer` policy,
   `TextNodeSnapshot.size`, non-JSON structural limits, legacy id reading,
   revision policy, uniqueness ownership, and the current single-owner
   `backgroundLayer` semantics including `ensureBackgroundLayer`
   materialization and boundary canonicalization.
3. Core regressions are covered for validated value types, id factories,
   revision policy, and one-owner defaults.
4. User-facing `message` snapshots remain limited to explicit user-facing
   templates and do not become the primary regression oracle for all boundary
   failures.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Start from the existing serialization, model, and core tests before adding
  new cases.
- Keep each regression proof at the owner closest to the production seam it
  exercises.
- Prefer extending current matrices over introducing parallel test harnesses
  for the same contract.

### 6.2 Target Verification Units
- `test/serialization/scene_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_structural_limits_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`
- `test/core/background_layer_invariants_test.dart`
- `test/core/id_generator_test.dart`
- `test/core/revision_policy_test.dart`
- `test/core/nodes_test.dart`
- `test/core/public_contracts_constants_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

### 6.3 Protected States, Data, or Structures
- `SceneDataException.code`
- `SceneDataException.path`
- `SceneDataException.details`
- Boundary-safe integer range rules
- Scene background-layer ownership
- Generated id and revision monotonicity rules

### 6.4 Allowed Semantic Change Zones
- Boundary decode and encode failure matrices
- Import/runtime scene validation matrices
- Core invariant matrices for ids, revisions, and node defaults

### 6.8 Prohibited
- Replacing `code/path/details` checks with broad exact-message matching
- Moving model/core semantics into controller or interactive tests
- Adding duplicate validation owners for background-layer or revision behavior

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

### Slice 1. [x] Serialization Boundary Matrix

#### Slice Contract
Serialization entrypoints reject the unresolved boundary defects with explicit
and stable regression proofs.

#### Change
Extend the serialization tests around `scene_codec.dart` and `codec_guards.dart`
to cover the unresolved matrix from the original step `14`.

#### Verification
- `test/serialization/scene_test.dart`
- `test/serialization/scene_fixture_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

#### Positive Scenarios
- `encode -> decode`
- `decode -> encode`
- accepted `TextAlign` values round-trip through the public codec
- supported schema versions decode through the current boundary

#### Negative Scenarios
- invalid map shapes fail with `SceneDataException`
- oversized raw JSON fails before `jsonDecode`
- unsupported schema versions expose the correct `code`
- unsupported align values carry a populated `path`
- invalid safe-int values fail on the public boundary

#### Closure Evidence
- Green run of the listed serialization tests.
- A documented matrix exists for `code/path/details` parity across decode,
  builder, and codec-guard boundaries.

### Slice 2. [x] Scene Model Policy Matrix

#### Slice Contract
Scene/model owners have explicit regression proofs for the unresolved policy
and structural semantics from steps `5.x-7.x`.

#### Change
Extend model tests around `scene_policy.dart`, `scene_builder.dart`,
`document.dart`, and `scene_structural_limits.dart`.

#### Verification
- `test/model/document_model_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/scene_structural_limits_test.dart`
- `test/model/scene_value_validation_primitives_test.dart`

#### Positive Scenarios
- canonical `backgroundLayer` import/export path
- `TextNodeSnapshot.size` matches the current derived policy
- legacy id payloads are still readable when current code allows them

#### Negative Scenarios
- duplicate uniqueness checks cannot diverge across owners
- non-JSON paths still enforce `kMax*` limits
- the current model does not reintroduce a reachable
  `multipleBackgroundLayers` failure path or any failing
  `ensureBackgroundLayer` branch that contradicts the chosen single-owner
  semantics

#### Closure Evidence
- Green run of the listed model tests.
- Each unresolved model item from the original step `14` is mapped to one owner
  file and one regression proof.

### Slice 3. [x] Core Invariant Matrix

#### Slice Contract
Core id, revision, and default-value invariants have explicit non-regression
proofs in owner-level tests.

#### Change
Extend the current core tests for validated values, id generation, revision
allocation, and mutable node revision tracking.

#### Verification
- `test/core/background_layer_invariants_test.dart`
- `test/core/id_generator_test.dart`
- `test/core/revision_policy_test.dart`
- `test/core/nodes_test.dart`
- `test/core/public_contracts_constants_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

#### Positive Scenarios
- generated ids remain valid under the current factory policy
- revision allocators keep the current monotonic contract
- owner defaults remain stable for the current core entrypoints
- public snapshot defaults stay aligned with shared defaults

#### Negative Scenarios
- invalid validated values fail at the current core boundary
- no-op point patch paths do not silently advance `pointsRevision`
- invalid revision inputs fail with the current contract

#### Closure Evidence
- Green run of the listed core tests.
- No unresolved `core` item from the original step `14` remains without a
  target test.

## 9. Final Verification

- `dart run tool/check_invariant_coverage.dart`
- MCP test shards for `test/core`
- MCP test shards for `test/model test/serialization test/contract test/public_api test/entrypoints`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
