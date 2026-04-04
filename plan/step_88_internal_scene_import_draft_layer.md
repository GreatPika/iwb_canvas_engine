language: russian

# Change Contract

## 1. Change Mandate

Этот шаг вводит model-owned internal draft/import слой для pre-canonical scene
state, чтобы import/decode/runtime replacement перестали использовать публичный
`SceneSnapshot` как контейнер для ещё не закрытых scene-level invariants и
промежуточной canonicalization.

## 2. Change Boundary

### Included in the Change

- Введение одного non-public model owner-а для pre-canonical scene import
  state beneath typed snapshot import, parsed-map decode, and runtime snapshot
  replacement.
- Перевод typed `SceneSnapshot -> import` path на immediate conversion в этот
  internal draft before scene-level policy validation.
- Перевод parsed JSON decode path на direct construction of the same internal
  draft instead of materializing a public `SceneSnapshot` before policy
  closure.
- Перепривязка `ScenePolicy`, `scene_builder.dart`, `scene_from_snapshot.dart`,
  `document.dart`, and downstream `txnSceneFromSnapshot(...)` consumers onto
  the new draft-based import spine.
- Обновление repository source of truth для import architecture:
  `API_GUIDE.md`, `ARCHITECTURE.md`, `PLAN.md`, this step file.

### Not Included in the Change

- Любая смена публичных constructor signatures или exported API surface for
  `SceneSnapshot`, `SceneBuilder`, `decodeScene*`, or controller entrypoints.
- Любая попытка сделать публичный `SceneSnapshot` globally valid by
  construction in этом шаге; этот architectural move остаётся отдельным
  последующим шагом.
- Любая смена JSON schema, encoded field set, or runtime export
  `Scene -> SceneSnapshot` contract.
- Любая смена owner-а scene-level duplicate/count/range policy;
  `ScenePolicy` remains the single semantic owner.
- Любая работа по palette contract alignment, text layout ownership, pointer
  contracts, or other unrelated boundary families.
- Любое расширение `contract/internal` bridge allowlist beyond the already
  approved exact surfaces.

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/model/scene_builder_api.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_decode_json.dart`
- `lib/src/model/scene_builder_decode_scene.dart`
- `lib/src/model/scene_builder_decode_scene_metadata.dart`
- `lib/src/model/scene_builder_decode_layers.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_value_validation.dart`
- `lib/src/model/scene_value_validation_scene.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/document.dart`
- `lib/src/model/scene_import_draft.dart`
- `lib/src/model/scene_import_draft_from_snapshot.dart`
- `lib/src/model/scene_from_import_draft.dart`
- `API_GUIDE.md`
- `ARCHITECTURE.md`

### Test Files

- `test/model/scene_builder_test.dart`
- `test/model/document_model_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/serialization/scene_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/controller/core/scene_controller_commit_failures_test.dart`
- `test/entrypoints/basic_smoke_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/step_88_internal_scene_import_draft_layer.md`

### Analysis Area

- `lib/src/model/**`
- `lib/src/controller/**`
- `lib/src/serialization/**`
- `test/model/**`
- `test/public_api/**`
- `test/serialization/**`
- `test/controller/core/**`
- `test/entrypoints/**`
- `API_GUIDE.md`
- `ARCHITECTURE.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new production file under `lib/**` must be tied to a dedicated
  `dcm calculate-metrics` verification.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Публичный `SceneSnapshot` remains the immutable public document boundary in
   this step; callers still construct and pass it through the same public
   APIs.
2. Invalid and intermediate scene import state moves under a model-owned
   internal draft/import owner and must stop using public `SceneSnapshot` as
   the scene-level working container.
3. `ScenePolicy` remains the single owner of scene-level duplicate/count/range
   semantics; this step changes the input carrier, not the semantic owner.
4. Parsed-map normalization remains in `model/` and must not move into
   `serialization/`.
5. Existing exact `contract/internal` bridge surfaces
   `lib/src/contract/internal/node_boundary_schema.dart` and
   `lib/src/contract/internal/snapshot_fast_path.dart` remain the only
   cross-layer bridges touched by this step; no new bridge surface is
   introduced.
6. This step does not make public `SceneSnapshot` globally valid by
   construction; semantically invalid typed snapshots may still be constructed
   and rejected later at the canonical import boundary until the subsequent
   global-validity step.
7. Public entrypoints `SceneBuilder.buildFromSnapshot(...)`,
   `SceneBuilder.buildFromJson(...)`, `decodeScene(...)`,
   `decodeSceneFromJson(...)`, `txnSceneFromSnapshot(...)`, and
   `SceneStoreController(initialSnapshot: ...)` remain supported and preserve
   deterministic `SceneDataException.code`, `path`, and immutable `details`.

## 5. Result Requirements

1. Один non-public model owner exists for pre-canonical scene import state, and
   both typed snapshot import and parsed-map import build that owner before
   scene-level policy validation.
2. No import/decode/runtime replacement path materializes a public
   `SceneSnapshot` as the raw scene-level working container before scene-level
   validation has closed.
3. `ScenePolicy` validates the internal draft/import state and continues to
   produce the same deterministic duplicate/count/range diagnostics as before.
4. `sceneBuildFromSnapshot(...)`, `sceneBuildFromDynamicJsonMap(...)`,
   `txnSceneFromSnapshot(...)`, `SceneBuilder.buildFromSnapshot(...)`,
   `SceneBuilder.buildFromJson(...)`, `decodeScene(...)`,
   `decodeSceneFromJson(...)`, and controller `initialSnapshot` preserve
   current canonical outputs and failure parity.
5. Runtime export and serialization still materialize public `SceneSnapshot`
   only as canonical document output; this step does not route export through
   the draft layer.
6. API and architecture docs describe `SceneSnapshot` only as the public
   document boundary and describe the new internal draft/import owner beneath
   import/decode/runtime replacement paths.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `lib/src/model/scene_builder_decode_scene.dart` currently decodes parsed JSON
  into `SceneSnapshotBacking` and immediately materializes a public
  `SceneSnapshot` before scene-level policy closure.
- `lib/src/model/scene_builder.dart` currently treats typed `SceneSnapshot` as
  `rawSnapshot`, and `sceneCanonicalizeAndValidateSnapshot(...)` currently
  delegates directly to `ScenePolicy.validateImportSnapshot(rawSnapshot)`.
- `lib/src/model/scene_from_snapshot.dart` currently accepts raw public
  `SceneSnapshot`, validates it through `ScenePolicy`, and then materializes a
  runtime `Scene` from the canonical snapshot.
- `lib/src/model/document.dart` exposes `txnSceneFromSnapshot(...)`, and
  `SceneStoreController(initialSnapshot: ...)` currently enters the runtime
  import path through that adapter.
- `lib/src/model/scene_value_validation_scene.dart` already owns one generic
  scene-value validation core with separate accessor sets for public snapshot
  and runtime scene; draft validation must reuse this owner instead of opening
  a parallel validation family elsewhere.
- Existing public/model/serialization/controller tests already prove parity for
  `SceneBuilder.buildFromSnapshot(...)`, `SceneBuilder.buildFromJson(...)`,
  `decodeScene(...)`, `txnSceneFromSnapshot(...)`, and
  `SceneStoreController(initialSnapshot: ...)` on duplicate-id, malformed
  parsed-map, canonical background-layer, and runtime import scenarios.
- Existing import guardrails already pin
  `contract/internal/node_boundary_schema.dart` and
  `contract/internal/snapshot_fast_path.dart` as the only approved
  `model -> contract/internal` bridge surfaces.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/model/scene_import_draft.dart lib/src/model/scene_import_draft_from_snapshot.dart lib/src/model/scene_from_import_draft.dart --report-all`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_public_api_surface.dart`
- `rg -n "materializeSceneSnapshot\\(" lib/src/model/scene_builder_decode_scene.dart lib/src/model/scene_builder_decode_json.dart`
- MCP test runner: root `.` paths `test/public_api/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/public_api/validated_boundary_value_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_codec_validation_test.dart`
- MCP test runner: root `.` paths `test/model/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/model/document_model_test.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_commit_failures_test.dart`
- MCP test runner: root `.` paths `test/entrypoints/basic_smoke_test.dart`

### 6.3 Protected States, Data, or Structures

- Deterministic `SceneDataException.code`, `path`, and immutable `details`
  parity across `SceneBuilder.buildFromSnapshot(...)`,
  `SceneBuilder.buildFromJson(...)`, `decodeScene(...)`,
  `decodeSceneFromJson(...)`, and controller `initialSnapshot` rejection.
- Canonical dedicated background-layer materialization for typed snapshot and
  parsed-map import paths.
- Runtime `instanceRevision` allocation semantics when imported
  `instanceRevision == 0`.
- Existing runtime export spine `txnSceneToSnapshot(...)` and encode paths.
- Existing import-boundary bridge policy for `model -> contract/internal`.

### 6.4 Allowed Semantic Change Zones

- The internal carrier for pre-canonical scene import state.
- The typed `SceneSnapshot -> internal draft` adapter.
- The parsed JSON `Map -> internal draft` decode owner.
- Scene-level draft validation and runtime materialization from validated draft.
- Documentation of public document boundary versus internal draft/import owner.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- New draft-layer files must live under `lib/src/model/**` and must not be
  re-exported from `lib/iwb_canvas_engine.dart` or any other public barrel.
- `serialization/**`, `controller/**`, `interactive/**`, `render/**`, and
  `view/**` must continue consuming canonical model/public facades; they must
  not import the new draft-layer files directly.
- `scene_builder_api.dart` remains a thin public facade and must not expose the
  internal draft type.
- `scene_builder_decode_scene.dart` and `scene_builder_decode_json.dart` may
  remain thin builder-local adapters, but scene-level import ownership must
  move under the draft layer rather than staying on a raw public
  `SceneSnapshot`.
- `scene_from_snapshot.dart` may remain as a typed public adapter, but it must
  convert to draft immediately and must not own scene-level validation on a
  raw public snapshot.

### 6.8 Prohibited

- Introducing a second public/raw snapshot type instead of one internal
  draft/import owner.
- Validating or canonicalizing import by first materializing a public
  `SceneSnapshot` and only then converting to draft.
- Moving import canonicalization into `serialization/` or `controller/`.
- Expanding the approved `contract/internal` bridge set.
- Routing runtime export or encode paths through the new draft layer.
- Changing JSON schema, encoded field names, or public constructor semantics in
  this step.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes import/decode parity work, typed snapshot and parsed-map
   paths must both be covered.
7. If a slice closes runtime import rewiring, `txnSceneFromSnapshot(...)` and
   `SceneStoreController(initialSnapshot: ...)` must both be covered.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming`.
11. This step must not reopen the later global-validity move for public
    `SceneSnapshot`.

## 8. Vertical Slices

### Slice 1. [x] One Internal Draft Owner For Typed And JSON Import

#### Slice Contract

Typed snapshot import and parsed-map JSON decode both normalize into one
non-public `SceneImportDraft`, and parsed-map decode stops materializing a
public `SceneSnapshot` before scene-level policy closure.

#### Change

Create `lib/src/model/scene_import_draft.dart` as the single model-owned
pre-canonical scene import carrier and `lib/src/model/scene_import_draft_from_snapshot.dart`
as the typed public snapshot adapter into that carrier. Rework
`lib/src/model/scene_builder_decode_scene.dart` and
`lib/src/model/scene_builder_decode_json.dart` so parsed-map decode builds the
same `SceneImportDraft` directly from existing low-level decode owners
(`scene_builder_decode_scene_metadata.dart`, `scene_builder_decode_layers.dart`,
and downstream node-family decoders) instead of calling
`materializeSceneSnapshot(...)`. Reuse the existing approved
`snapshot_fast_path.dart` bridge payloads under the draft owner; do not
introduce a new `contract/internal` bridge.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_import_draft.dart lib/src/model/scene_import_draft_from_snapshot.dart --report-all`
- `rg -n "materializeSceneSnapshot\\(" lib/src/model/scene_builder_decode_scene.dart lib/src/model/scene_builder_decode_json.dart`
- MCP test runner: root `.` paths `test/public_api/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/public_api/validated_boundary_value_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_test.dart`
- MCP test runner: root `.` paths `test/serialization/scene_codec_validation_test.dart`
- MCP test runner: root `.` paths `test/model/scene_builder_test.dart`

#### Positive Scenarios

- `SceneBuilder.buildFromSnapshot(...)` still accepts a valid typed
  `SceneSnapshot` and returns the same canonical public result.
- `SceneBuilder.buildFromJson(...)` and `decodeScene(...)` still return the
  same canonical document for the same parsed-map payload.
- Parsed-map import still canonicalizes missing `backgroundLayer` to the empty
  dedicated background layer.

#### Negative Scenarios

- Malformed parsed maps still surface `invalidJsonPayload` parity between
  `SceneBuilder.buildFromJson(...)` and `decodeScene(...)`.
- Path-aware duplicate-id and oversized-value diagnostics from the parsed-map
  import path remain unchanged after the new draft owner is introduced.

#### Closure Evidence

- Green run of the listed verifications.
- The `rg` verification returns no `materializeSceneSnapshot(...)` call inside
  the parsed-map draft decode owner files.

### Slice 2. [x] Runtime Import Spine Validates Draft Instead Of Raw Snapshot

#### Slice Contract

`ScenePolicy`, model builder helpers, `txnSceneFromSnapshot(...)`, and
controller `initialSnapshot` all route through draft validation/materialization
instead of treating public `SceneSnapshot` as the scene-level working state.

#### Change

Create `lib/src/model/scene_from_import_draft.dart` as the runtime materializer
from validated draft to mutable `Scene`. Rework `lib/src/model/scene_policy.dart`
so scene-level structure/value/range validation operates on `SceneImportDraft`,
reusing the generic owner in `lib/src/model/scene_value_validation_scene.dart`
instead of opening a second draft-only validation family. Rewire
`lib/src/model/scene_from_snapshot.dart`, `lib/src/model/scene_builder.dart`,
and `lib/src/model/document.dart` so public typed `SceneSnapshot` inputs are
converted to draft immediately, validated through the draft path, and then
materialized to runtime scene or canonical public snapshot as needed.
`sceneCanonicalizeAndValidateSnapshot(...)` may remain as an internal adapter
returning `SceneSnapshot`, but it must implement that behavior through the new
draft spine rather than direct `ScenePolicy.validateImportSnapshot(...)`
validation on a raw public snapshot.

#### Verification

- `dcm calculate-metrics lib/src/model/scene_from_import_draft.dart --report-all`
- MCP test runner: root `.` paths `test/model/document_model_test.dart`
- MCP test runner: root `.` paths `test/model/scene_builder_test.dart`
- MCP test runner: root `.` paths `test/controller/core/scene_controller_commit_failures_test.dart`
- MCP test runner: root `.` paths `test/entrypoints/basic_smoke_test.dart`

#### Positive Scenarios

- `txnSceneFromSnapshot(...)` still materializes canonical background-layer
  state and preserves runtime instance-revision allocation semantics.
- `SceneStoreController(initialSnapshot: validSnapshot)` still boots normally
  and exposes the committed canonical snapshot through the public entrypoint.
- `sceneCanonicalizeAndValidateSnapshot(...)` still returns a canonical public
  snapshot for valid typed input.

#### Negative Scenarios

- `txnSceneFromSnapshot(...)` still rejects malformed snapshot inputs with the
  same deterministic `SceneDataException` contract.
- `SceneStoreController(initialSnapshot: malformedSnapshot)` still fails with
  the same duplicate/count/range diagnostics as before.
- `sceneBuildFromSnapshot(...)` and
  `sceneCanonicalizeAndValidateSnapshot(...)` still reject duplicate ids and
  oversized imported payloads at the canonical import boundary.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 3. [x] Source Of Truth Pins Public Document Boundary And Draft Owner

#### Slice Contract

Repository docs and structural checks consistently describe `SceneSnapshot` as
the public document boundary and the new draft layer as a model-internal
pre-canonical import owner, while import boundaries and public API guardrails
stay green.

#### Change

Update `API_GUIDE.md`, `ARCHITECTURE.md`, `PLAN.md`, and this step document so
typed snapshot import and parsed-map decode are documented as flowing through a
model-internal draft/import owner before scene-level policy closure. Keep the
public API wording unchanged for callers: `SceneBuilder`, `decodeScene*`, and
controller entrypoints still consume/return public `SceneSnapshot`, but the
docs must stop describing `SceneSnapshot` as the internal raw import working
state. Run structural checks required for the new model files and import graph.

#### Verification

- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_public_api_surface.dart`

#### Positive Scenarios

- Import-boundary checks accept the new model-owned draft files and exact
  existing `contract/internal` bridges.
- Public API surface remains unchanged.

#### Negative Scenarios

- No source-of-truth file still describes public `SceneSnapshot` as the
  pre-canonical internal import working container.
- No non-model layer can import the new draft-layer files directly without
  failing the existing guardrails/import-boundary checks.

#### Closure Evidence

- Green run of the listed verifications.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/model/scene_import_draft.dart lib/src/model/scene_import_draft_from_snapshot.dart lib/src/model/scene_from_import_draft.dart --report-all`
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

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
