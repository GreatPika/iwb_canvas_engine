language: russian

# Change Contract

## 1. Change Mandate

Этот шаг делает публичный `SceneSnapshot` globally valid by construction:
duplicate ids, content-layer overflow, and scene node-budget overflow must be
rejected at the public snapshot boundary instead of living only as a later
import-time failure.

## 2. Change Boundary

### Included in the Change

- Введение одного contract-owned shared structural validation owner-а для
  scene-wide document structure: duplicate `NodeId`, duplicate `LayerId`,
  content-layer count limit, total node-budget limit.
- Перевод публичного `SceneSnapshot` constructor path на eager scene-level
  structural validation with current deterministic `SceneDataException`
  diagnostics.
- Перевод model import policy onto the same shared structural validation core
  instead of keeping duplicate/count validation logic private inside
  `ScenePolicy`.
- Перевод validated public snapshot producer paths onto structure-checked
  assembly so normal runtime/export/import producers no longer materialize
  structurally malformed public snapshots.
- Сохранение одного explicit internal malformed-snapshot bypass under
  `contract/internal/**` for tests and package-internal support code.
- Обновление public/source-of-truth docs and invariant registry:
  `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
  `tool/invariant_registry.dart`, `PLAN.md`, this step file.

### Not Included in the Change

- Любая смена JSON schema, encoded field set, or scene document field names.
- Любая смена public `SceneSnapshot` defaults, field list, or immutable list
  ownership semantics.
- Любая смена runtime-scene invariant assertions in
  `test/controller/scene_invariants_test.dart` beyond adapting proof wording
  if required by the new public snapshot contract.
- Любая попытка перенести duplicate/count policy into
  `scene_value_validation*.dart`; value validation remains a separate family.
- Любая работа по palette contract alignment, node-field value rules, or other
  non-structural boundary families.
- Любое введение нового public raw/draft snapshot type or any expansion of the
  public export surface.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/scene_contract_limits.dart`
- `lib/src/contract/scene_structure_validation.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/contract/internal/snapshot_boundary_impl.dart`
- `lib/src/core/scene_limits.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_layers.dart`
- `lib/src/model/scene_builder_decode_scene.dart`
- `lib/src/model/scene_import_draft.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`
- `lib/src/model/scene_structural_limits.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `tool/invariant_registry.dart`

### Test Files

- `test/public_api/validated_boundary_value_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/contract/scene_structure_validation_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/model/scene_builder_test.dart`
- `test/model/document_model_test.dart`
- `test/model/scene_structural_limits_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/controller/scene_snapshot_invariant_assertions_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/step_89_scene_snapshot_global_validity_by_construction.md`

### Analysis Area

- `lib/src/contract/**`
- `lib/src/model/**`
- `lib/src/core/scene_limits.dart`
- `test/public_api/**`
- `test/contract/**`
- `test/model/**`
- `test/controller/core/**`
- `test/controller/scene_snapshot_invariant_assertions_test.dart`
- `test/serialization/**`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`
- `tool/invariant_registry.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new production file under `lib/**` must be tied to a dedicated
  `dcm calculate-metrics` verification.
- Every deleted implementation or test file must be replaced by a slice-owned
  source of truth or proof surface with the same responsibility.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. User-confirmed target state: public `SceneSnapshot` is a canonical document
   boundary and must be globally structurally valid by construction.
2. No new public raw/draft snapshot type is introduced in this step; invalid
   and intermediate scene state remains internal-only.
3. Scene-wide structural failures at the public snapshot boundary must keep the
   existing `SceneDataException` taxonomy for duplicate/count overflow
   diagnostics instead of introducing a new error family.
4. Local field validation semantics stay unchanged in this step: existing
   eager boundary `ArgumentError` checks for ids, numeric fields, and node/local
   snapshot semantics remain in place.
5. `scene_value_validation*.dart` remains value-only; scene-wide duplicate/count
   policy moves to a shared structural validation core rather than becoming part
   of value validation.
6. `ScenePolicy` remains the import/runtime orchestration owner, but duplicate
   id and scene-wide count validation must stop living only as private
   `ScenePolicy` implementation logic.
7. One explicit malformed public snapshot bypass may remain only under
   `lib/src/contract/internal/**`; it is package-internal support, not a public
   API contract.
8. This step does not change JSON field names, schema version, runtime scene
   shape, or export barrel surface.

## 5. Result Requirements

1. `SceneSnapshot(...)` rejects duplicate `NodeId` across background/content,
   duplicate content `LayerId`, content-layer overflow, and total node-budget
   overflow before a public snapshot instance can escape normal public
   construction.
2. The same shared structural validation owner is used by the public snapshot
   boundary and by model import validation, and both paths preserve the current
   deterministic `SceneDataException.code`, `path`, and immutable `details`
   contract for duplicate/count failures.
3. Normal public snapshot producer paths
   (`SceneSnapshot(...)`, `sceneSnapshotFromValidated(...)`,
   runtime `txnSceneToSnapshot(...)`, and validated import-draft to public
   snapshot conversion) do not produce structurally malformed public snapshots.
4. Explicit structurally malformed `SceneSnapshot` instances can still be
   created only through the internal raw materialization/backing bypass under
   `contract/internal/**`, and tests that need malformed public snapshots use
   that bypass explicitly.
5. `sceneValidateSnapshotValues(...)` remains a value-only validator and does
   not become a second owner of duplicate/count structural policy.
6. Public docs and invariant registry describe `SceneSnapshot` as structurally
   valid by construction for public callers and document the internal bypass as
   package-internal only.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/contract/snapshot.dart` currently validates only local boundary
  fields and copies/defaults scene fields, but does not reject duplicate ids or
  scene-wide count overflow.
- `lib/src/model/scene_policy.dart` currently owns duplicate/count structural
  checks via `_validateStructuralInvariants(...)`,
  `_validateContentLayerStructure(...)`, `_validateLayerNodeUniqueness(...)`,
  and helpers from `lib/src/model/scene_structural_limits.dart`.
- `lib/src/model/scene_structural_limits.dart` currently owns content-layer and
  node-budget limit enforcement even though these limits describe public scene
  document structure.
- `lib/src/model/scene_builder_decode_layers.dart` and
  `lib/src/model/scene_builder_decode_scene.dart` currently import
  `scene_structural_limits.dart` to enforce early parsed-JSON content-layer and
  node-budget guards during decode.
- `lib/src/contract/scene_contract_limits.dart` currently lacks
  `kMaxContentLayersPerScene` and `kMaxNodesPerScene`, while
  `lib/src/core/scene_limits.dart` still owns them.
- `lib/src/model/scene_import_draft.dart` currently exposes
  `sceneSnapshotFromImportDraft(...)` that materializes a public `SceneSnapshot`
  from arbitrary draft backing without a dedicated validated-only contract.
- `lib/src/contract/internal/snapshot_materialization.dart` currently exposes
  `sceneSnapshotFromValidated(...)` but does not enforce scene-wide structural
  validity; tests use it to materialize snapshots with invalid values and, in a
  few places, invalid scene structure.
- `lib/src/model/scene_snapshot_from_scene.dart` currently materializes public
  `SceneSnapshot` from runtime scene backing through raw
  `materializeSceneSnapshot(...)`.
- `lib/src/contract/internal/snapshot_boundary_impl.dart` currently keeps raw
  internal materialization available through `_MaterializedSceneSnapshot`;
  this is the only package-internal seam that can remain as the explicit raw
  malformed public snapshot bypass after this step.
- Existing public/model/controller/serialization tests already prove duplicate
  id and count-overflow diagnostics, but many of those proofs currently create
  malformed public snapshots through normal `SceneSnapshot(...)` construction
  and therefore must be split between eager public-failure tests and explicit
  internal-bypass tests.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract/scene_structure_validation.dart --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- `test ! -e lib/src/model/scene_structural_limits.dart`
- MCP test runner: root `.` paths `test/public_api/validated_boundary_value_test.dart`
- MCP test runner: root `.` paths `test/public_api/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/contract/scene_structure_validation_test.dart`
- MCP test runner: root `.` paths `test/contract/validated_fast_path_contract_test.dart`
- MCP test runner: root `.` paths `test/model/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/model/document_model_test.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_commit_failures_test.dart`
- MCP test runner: root `.` paths `test/controller/scene_snapshot_invariant_assertions_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_codec_validation_test.dart`

### 6.3 Protected States, Data, or Structures

- Existing public constructor defaults for empty `backgroundLayer`, empty
  `layers`, safe `camera`, safe `background`, and safe `palette`.
- Existing `SceneDataException` path/details parity for duplicate node ids,
  duplicate layer ids, content-layer overflow, and total node overflow across
  builder/controller/codec/runtime import surfaces.
- Existing non-structural invalid snapshot tests that rely on
  `sceneSnapshotFromValidated(...)` for malformed values such as invalid path
  data, invalid palette values, or invalid numeric ranges; this step must not
  widen itself into a general fast-path value-validation rewrite.
- Existing public API surface and exact `contract/internal/**` non-public
  boundary.
- Existing runtime export canonicalization of absent runtime background layer
  into the dedicated public `backgroundLayer`.

### 6.4 Allowed Semantic Change Zones

- Scene-wide structural validation ownership for public document structure.
- Public `SceneSnapshot` eager rejection point for scene-level structural
  invalidity.
- Validated public snapshot producer paths under model/contract internals.
- Internal raw malformed-snapshot bypass usage in tests/support code.
- Public and architectural source-of-truth wording for snapshot validity.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- `lib/src/contract/scene_structure_validation.dart` must stay below `model/`
  in the layer graph and must not import `lib/src/model/**`.
- Shared structural validation logic must be reusable from both
  `lib/src/contract/snapshot.dart` and `lib/src/model/scene_policy.dart`
  without creating a `contract -> model` dependency.
- Public snapshot constructor code must not call into `ScenePolicy`.
- Runtime/export and validated-import producers may consume shared structural
  validation, but they must not expose new public helper entrypoints.
- `sceneSnapshotFromImportDraft(...)` must be replaced with
  `sceneSnapshotFromValidatedImportDraft(...)`; a function with the old name
  must not remain materializing a public `SceneSnapshot` from arbitrary
  unvalidated draft state.
- Tests that require structurally malformed public snapshots must use explicit
  `contract/internal` raw backing/materialization helpers and must not rely on
  ordinary public constructors or validated-helper names.

### 6.8 Prohibited

- Keeping active duplicate/count structural validation logic only inside
  `ScenePolicy` after this step.
- Introducing a second scene-wide duplicate/count owner inside
  `scene_value_validation*.dart`.
- Leaving parsed-JSON decode owners on deleted `scene_structural_limits.dart`
  or forcing them to invent separate local structural constants/helpers.
- Preserving `sceneSnapshotFromValidated(...)` as a helper that can still build
  structurally malformed public snapshots through its normal call contract.
- Continuing to materialize public snapshots through raw
  `materializeSceneSnapshot(...)` on normal runtime/export or validated-import
  paths.
- Replacing the explicit internal raw bypass with a public or publicly
  documented escape hatch.
- Broadening this step into JSON schema migration or non-structural value-rule
  rewrites.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes the public rejection point for malformed snapshots, its
   verification must cover both eager public failure and preserved late-failure
   parity for parsed JSON or explicit internal-bypass inputs.
7. If a slice moves structural validation ownership, the old owner must be
   removed or reduced to zero validation logic before the slice is closed.
8. If a slice keeps an internal malformed-snapshot bypass, that bypass must be
   non-public and named/documented as internal support only.
9. Scope expansion is forbidden until the mandatory slices are closed.
10. The plan must be detailed enough that the implementing agent has no
    material branch in how to execute a slice.
11. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming`.

## 8. Vertical Slices

### Slice 1. [ ] Shared Structural Validation Moves Under Contract

#### Slice Contract

One contract-owned shared structural validation core exists for scene-wide
document structure, model import validation delegates to it, and the old
model-local structural limit owner is removed.

#### Change

Create `lib/src/contract/scene_structure_validation.dart` as the shared owner
for scene-wide duplicate/count structural checks and move
`kMaxContentLayersPerScene` and `kMaxNodesPerScene` into
`lib/src/contract/scene_contract_limits.dart`, keeping
`lib/src/core/scene_limits.dart` as the re-export site for downstream runtime
consumers. Rework `lib/src/model/scene_policy.dart` so duplicate `NodeId`,
duplicate `LayerId`, content-layer overflow, and node-budget overflow validate
through the new shared contract core instead of private
`ScenePolicy`-local helper logic. Rework
`lib/src/model/scene_builder_decode_layers.dart` and
`lib/src/model/scene_builder_decode_scene.dart` so their existing early
parsed-JSON layer/node budget guards call the new contract-owned limit/guard
surface instead of `scene_structural_limits.dart`; these early decode checks
remain transport-side guardrails and do not become a second semantic owner.
Delete `lib/src/model/scene_structural_limits.dart` and migrate its focused
proof surface from
`test/model/scene_structural_limits_test.dart` to
`test/contract/scene_structure_validation_test.dart`.

#### Verification

- `dcm calculate-metrics lib/src/contract/scene_structure_validation.dart --report-all`
- `test ! -e lib/src/model/scene_structural_limits.dart`
- MCP test runner: root `.` paths `test/contract/scene_structure_validation_test.dart`
- MCP test runner: root `.` paths `test/model/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_codec_validation_test.dart`

#### Positive Scenarios

- Draft import validation still rejects duplicate node ids, duplicate layer
  ids, content-layer overflow, and node-budget overflow with the same
  `SceneDataException` code/path/details contract.
- Parsed JSON decode and typed import still reuse the same structural rejection
  semantics through `ScenePolicy`.
- Parsed JSON decode still rejects oversized content-layer counts and node
  counts at the same decode-stage paths as before.

#### Negative Scenarios

- No active duplicate/count structural helper remains under
  `lib/src/model/scene_policy.dart` or a surviving
  `lib/src/model/scene_structural_limits.dart`.
- Scene-wide structural limits no longer live only under `core/` + `model/`
  while the public boundary is expected to enforce them.

#### Closure Evidence

- Green run of the listed verifications.
- `lib/src/model/scene_structural_limits.dart` no longer exists.

### Slice 2. [ ] Public SceneSnapshot Rejects Structural Invalidity Eagerly

#### Slice Contract

Ordinary public `SceneSnapshot(...)` construction rejects duplicate ids and
scene-wide count overflow eagerly while preserving current defaults, local
field validation behavior, and deterministic `SceneDataException` diagnostics
for structural failures.

#### Change

Rework `lib/src/contract/snapshot.dart` so `SceneSnapshot(...)` assembles the
defaulted immutable field set and then runs the shared structural validation
core against that candidate scene document before the instance escapes.
Keep local boundary validation exactly where it already lives for layer ids,
node ids, numeric fields, and node-family field semantics. Public scene-wide
structural failures must continue using the existing duplicate/max
`SceneDataException` contract rather than converting to `ArgumentError`.

#### Verification

- MCP test runner: root `.` paths `test/public_api/validated_boundary_value_test.dart`
- MCP test runner: root `.` paths `test/public_api/scene_builder_test.dart`

#### Positive Scenarios

- Valid public `SceneSnapshot(...)` construction still succeeds with the same
  defaults for omitted `backgroundLayer`, `layers`, `camera`, `background`, and
  `palette`.
- Existing local `ArgumentError` constructor checks for invalid field values
  remain unchanged.

#### Negative Scenarios

- Constructing a public `SceneSnapshot` with duplicate node ids fails before
  `SceneBuilder.buildFromSnapshot(...)` is called.
- Constructing a public `SceneSnapshot` with duplicate content layer ids fails
  before any model import path is entered.
- Constructing a public `SceneSnapshot` with too many content layers or too
  many total nodes fails at the public snapshot boundary.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 3. [ ] Validated Public Snapshot Producers Stop Using Raw Materialization

#### Slice Contract

Normal validated producer paths no longer emit structurally malformed public
snapshots, and tests that still need malformed public `SceneSnapshot` values
use the explicit internal raw backing/materialization bypass instead.

#### Change

Rework `lib/src/model/scene_import_draft.dart` so validated import-draft to
public snapshot conversion is exposed only as
`sceneSnapshotFromValidatedImportDraft(...)` and cannot materialize an
arbitrary raw draft as a public document.
Rework `lib/src/contract/internal/snapshot_materialization.dart` so
`sceneSnapshotFromValidated(...)` enforces shared structural validation before
producing a public snapshot, while keeping `materializeSceneSnapshot(...)` as
the explicit internal raw bypass. Rewire
`lib/src/model/scene_builder.dart`, `lib/src/model/scene_snapshot_from_scene.dart`,
and any downstream call sites onto the validated producer path instead of raw
`materializeSceneSnapshot(...)`. Rewrite affected tests in
`test/model/scene_builder_test.dart`,
`test/model/document_model_test.dart`,
`test/controller/core/scene_controller_commit_failures_test.dart`,
`test/controller/scene_snapshot_invariant_assertions_test.dart`,
`test/serialization/scene_codec_validation_test.dart`, and
`test/contract/validated_fast_path_contract_test.dart` so structurally
malformed public snapshots are created only through explicit internal backing
materialization, while non-structural invalid fast-path value tests continue to
use the existing validated helper surface.

#### Verification

- MCP test runner: root `.` paths `test/contract/validated_fast_path_contract_test.dart`
- MCP test runner: root `.` paths `test/model/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/model/document_model_test.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_commit_failures_test.dart`
- MCP test runner: root `.` paths `test/controller/scene_snapshot_invariant_assertions_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_codec_validation_test.dart`

#### Positive Scenarios

- `txnSceneToSnapshot(...)` and other normal public snapshot producer paths
  still return canonical public snapshots for valid runtime scenes.
- Builder/controller/codec paths still surface the same duplicate/count
  diagnostics when fed parsed JSON or explicit internal malformed public
  snapshots.
- `sceneValidateSnapshotValues(...)` still behaves as a value-only validator
  when invoked on an explicitly malformed internal-bypass snapshot.

#### Negative Scenarios

- No normal validated producer path still calls raw
  `materializeSceneSnapshot(...)` to create public snapshots.
- No test that needs a structurally malformed public snapshot still relies on
  ordinary `SceneSnapshot(...)` construction or on
  `sceneSnapshotFromValidated(...)`.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 4. [ ] Source Of Truth Pins Public SceneSnapshot Global Validity

#### Slice Contract

Repository docs and invariant registry consistently state that public
`SceneSnapshot` is structurally valid by construction for public callers, and
the repository guardrails/tooling remain green.

#### Change

Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`,
`PLAN.md`, and this step document so public snapshot construction is described
as eager scene-document validation, not merely local field validation. Update
`tool/invariant_registry.dart` with invariant
`INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY` and attach its primary proof to
`test/public_api/validated_boundary_value_test.dart`. Adjust architecture
wording so `ScenePolicy` is documented as import/runtime orchestration owner,
while the shared contract structural validator owns public scene document
structure rules consumed by both public boundary and model import validation.

#### Verification

- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Source-of-truth docs describe duplicate/count structural invalidity as an
  eager public snapshot rejection for ordinary public callers.
- Invariant coverage passes with the new public snapshot global-validity
  invariant and matching proof marker.

#### Negative Scenarios

- No source-of-truth file still claims that public `SceneSnapshot` constructors
  validate only local boundary fields.
- No source-of-truth file still claims that duplicate/count structural
  validation lives only inside `ScenePolicy`.

#### Closure Evidence

- Green run of the listed verifications.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/contract/scene_structure_validation.dart --report-all`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test shard preset `core`
- MCP test shard preset `model_contract`
- MCP test shard preset `controller_internal`
- MCP test shard preset `controller`
- MCP test shard preset `render_view`
- MCP test shard preset `interactive`
- MCP test shard preset `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
