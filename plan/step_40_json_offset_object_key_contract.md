# Change Contract

## 1. Change Mandate

Close `KI-18` by making every JSON offset boundary value reject object maps
with non-string keys while preserving model-owned import diagnostic paths for
line endpoints and stroke points.

## 2. Change Boundary

### Included in the Change

- make JSON offset boundary-value parsing reject non-string object keys before
  reading `x` and `y`
- prove the rule at the public validated value boundary through
  `FiniteOffsetValue.fromJson(...)`
- prove `SceneBuilder.buildFromJson(...)` and `decodeScene(...)` reject
  malformed parsed-map line `localA`, line `localB`, and stroke
  `localPoints[i]` offset objects with stable `SceneDataException` details
  and caller-visible JSON paths
- state explicitly that the same non-string-key malformed object shape is not
  representable at the raw JSON string boundary used by `decodeSceneFromJson(...)`
- keep `SceneDataException.jsonObjectKeysMustBeStrings(...)` as the error
  category for non-string JSON object keys
- remove `KI-18` from `KNOWN_ISSUES.md` in the same implementation change that
  adds regression proof
- update `CHANGELOG.md`, `PLAN.md`, and this step document in the same
  implementation change

### Not Included in the Change

- no public API expansion, rename, or schema-version change
- no migration of line or stroke range-path ownership out of the model layer
- no broad rewrite of scene builder decode helpers, JSON object helpers, or
  serialization codecs
- no new synchronizer or secondary offset-shape policy outside the existing
  validated boundary value owner
- no implementation for `KI-16`, `KI-17`, `KI-19`, `KI-20`, or any other
  active known issue

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` - records `KI-18` as an active `P2` defect because
  `line.localA`, `line.localB`, and `stroke.localPoints[i]` flow through
  `validatedRequireJsonFiniteOffset(...)`, which accepts
  `Map<Object?, Object?>` and reads only `x` and `y`.
- `ARCHITECTURE.md` - defines strict boundary validation as a core
  architectural goal and states that import, build, and serialization failures
  use stable `SceneDataException` categories and structured details.
- `docs/ARCHITECTURE_ATLAS.md` - routes architecture decisions through family
  documents and active confirmed defects through `KNOWN_ISSUES.md`.
- `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`
  - owns immutable contract document objects and validated boundary values.
- `docs/architecture/families/import_build_materialization.md` - owns scene
  import/build validation and stable path-aware diagnostics.
- `docs/architecture/families/serialization_and_schema.md` - owns JSON
  encode/decode behavior and forbids silently widening accepted serialized
  data.
- `docs/proof_architecture/families/invariant_registry_and_proof_reachability.md`
  - requires executable proof paths to stay explicit and reachable from the
  required code-change preset.
- `lib/src/contract/validated/validated_value_support.dart` -
  `validatedRequireJsonFiniteOffset(...)` checks the value is a map, reads
  `x` and `y`, validates numeric finiteness, and currently does not reject
  non-string extra keys.
- `lib/src/contract/validated/finite_offset_value.dart` -
  `FiniteOffsetValue.fromJson(...)` delegates directly to
  `validatedRequireJsonFiniteOffset(...)`.
- `lib/src/contract/scene_data_exception.dart` - already provides
  `SceneDataException.jsonObjectKeysMustBeStrings(...)` with details template
  `jsonObjectKeysMustBeStrings`.
- `lib/src/model/scene_builder_json_require.dart` - `sceneBuilderCastMap(...)`
  rejects non-string keys for general parsed JSON object maps, proving the
  desired object-key contract already exists for other object boundaries.
- `lib/src/model/scene_builder_decode_line.dart` - line `localA` and
  `localB` parse through `validatedRequireJsonFiniteOffset(...)`.
- `lib/src/model/scene_builder_decode_stroke.dart` - stroke
  `localPoints[i]` parses through `FiniteOffsetValue.fromJson(...)`.
- `lib/src/model/scene_validation_path_surface.dart` - records JSON import
  aliases for line and stroke paths: `localA`, `localB`, and `localPoints`.
- `test/public_api/validated_boundary_value_test.dart` - already covers
  public validated values and alias-bearing JSON range diagnostics.
- `test/public_api/scene_builder_test.dart` - already contains
  `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` proof for `SceneBuilder.buildFromJson`
  and line/stroke JSON path spelling.
- `test/serialization/scene_codec_validation_test.dart` - already contains
  `INV-SER-JSON-NUMERIC-VALIDATION` and
  `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` proof for decode surfaces.
- `test/model/scene_validation_path_surface_contract_test.dart` - locks the
  model-owned path surface aliases for JSON and typed import surfaces.
- `tool/invariant_registry.dart` - names `INV-SER-JSON-NUMERIC-VALIDATION` and
  `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` as required serialization/model proof.
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/validated/validated_value_support.dart validatedRequireJsonFiniteOffset --direction=both --depth=2 --json`
  - confirms incoming production calls from `FiniteOffsetValue.fromJson(...)`
  and line decode, with stroke decode reaching the validator through
  `FiniteOffsetValue.fromJson(...)`.
- `dart run tool/run_repository_audits.dart` - passes all current standalone
  audits while `KI-18` remains active, proving the fix needs explicit
  behavioral regression proof rather than relying on an existing audit.
- `dart run tool/trace_proof_inventory.dart --json` - confirms
  `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` and `INV-SER-JSON-NUMERIC-VALIDATION`
  are reachable from the `required_code_change` preset through
  `scope_model_contract`.

### Current Entry Path

- public validated value path:
  `FiniteOffsetValue.fromJson(...) -> validatedRequireJsonFiniteOffset(...)`
- line JSON import path:
  `SceneBuilder.buildFromJson(...)` or `decodeScene(...)` ->
  line node decode -> `validatedRequireJsonFiniteOffset(...)` for `localA`
  and `localB`
- stroke JSON import path:
  `SceneBuilder.buildFromJson(...)` or `decodeScene(...)` ->
  stroke node decode -> `FiniteOffsetValue.fromJson(...)` ->
  `validatedRequireJsonFiniteOffset(...)` for each `localPoints[i]`
- raw JSON string path:
  `decodeSceneFromJson(...)` parses transport JSON before entering the same
  decoded scene validation path used by `decodeScene(...)`; non-string object
  keys are not representable in valid JSON text after `jsonDecode`

### Current Owner

- `lib/src/contract/validated/validated_value_support.dart` owns primitive
  validated JSON value parsing for offsets.
- `lib/src/contract/validated/finite_offset_value.dart` owns the public
  validated offset boundary type.
- `lib/src/model/**` owns import/build path spelling and canonicalization.
- `lib/src/serialization/scene_codec.dart` owns public JSON decode entrypoints
  and delegates scene validation to the model import path.

### Adjacent Abstractions

- `sceneBuilderCastMap(...)` is the adjacent model-side object-key guard for
  parsed JSON-compatible maps.
- `validatedRequireJsonFiniteDouble(...)` and related helpers are adjacent
  primitive JSON value validators in the same contract support file.
- `SceneDataException.fieldMustBeOffsetObject(...)` remains the correct error
  for non-map offsets and missing/non-numeric `x` or `y`.
- `SceneValidationPathSurface` is the model-owned alias surface for JSON
  `localA`, `localB`, and `localPoints` paths.

### Existing Tests

- `test/public_api/validated_boundary_value_test.dart` - proves public
  validated value behavior and public import range-path diagnostics.
- `test/public_api/scene_builder_test.dart` - proves
  `SceneBuilder.buildFromJson(...)` diagnostic parity with decode surfaces for
  line and stroke JSON paths.
- `test/serialization/scene_codec_validation_test.dart` - proves
  `decodeSceneFromJson(...)`, `decodeScene(...)`, and
  `SceneBuilder.buildFromJson(...)` share stable error contracts for
  representable JSON and parsed-map malformed inputs.
- `test/model/scene_validation_path_surface_contract_test.dart` - proves the
  model-owned alias mapping for JSON and typed path surfaces.

### Analogous Implementation Path

- `sceneBuilderCastMap(...)` in `lib/src/model/scene_builder_json_require.dart`
  is the closest valid precedent for rejecting non-string keys in parsed
  JSON-compatible map objects.
- `FiniteOffsetValue.fromJson(...)` is the closest public boundary precedent
  for routing raw JSON offset parsing through one validated value owner.
- Existing alias-bearing range diagnostics for line/stroke in
  `test/public_api/scene_builder_test.dart` and
  `test/serialization/scene_codec_validation_test.dart` are the closest proof
  precedent for preserving JSON path spelling while tightening validation.

### Governing Repository Rules

- `AGENTS.md` - known issues are active defects only and must be removed in the
  same change that fixes them and adds regression proof.
- `AGENTS.md` - public behavior changes must update `CHANGELOG.md`; after
  code changes, run the required verification preset with every changed path.
- `ARCHITECTURE.md` - contract owns validated boundary values and stable
  boundary errors; model owns document conversion, import validation, and
  diagnostic path surfaces.
- `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`
  - boundary data remains immutable and validated before public exposure.
- `docs/architecture/families/import_build_materialization.md` - external
  input is validated at the import/build boundary and diagnostics remain
  stable and path-aware.
- `docs/architecture/families/serialization_and_schema.md` - accepted
  serialized data must not be silently widened.
- `tool/invariant_registry.dart` - `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` and
  `INV-SER-JSON-NUMERIC-VALIDATION` identify the required proof surfaces.

### Rejected Misleading Local Patterns

- Adding ad hoc guards only in `scene_builder_decode_line.dart` and
  `scene_builder_decode_stroke.dart` is the wrong owner because it leaves
  `FiniteOffsetValue.fromJson(...)` with a weaker object-key contract.
- Moving line/stroke path spelling into contract validators is the wrong seam
  because the model layer owns caller-visible import diagnostic path surfaces.
- Broadening `sceneBuilderCastMap(...)` into a dependency of the contract layer
  is the wrong dependency direction because contract must not import model.
- Treating this as a schema-version migration is misleading because the
  current schema already expects JSON objects with string keys; the defect is
  parsed-map admission parity, not a new schema shape.
- Adding a new standalone audit is not required for this slice unless
  implementation discovers repeated object-key bypasses outside offset parsing;
  current repository audits pass and the known defect is a narrow behavioral
  admission gap.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- This is a contract-owned JSON boundary value validation fix with
  model/serialization import-surface regression proof.

#### Selected Architectural Form

- Tighten `validatedRequireJsonFiniteOffset(...)` so JSON offset maps reject
  any non-string key before reading `x` and `y`.
- Keep path spelling and entrypoint-specific diagnostic surface selection in
  model/serialization tests and owners.
- Keep the existing `SceneDataException.jsonObjectKeysMustBeStrings(...)`
  category for the new rejection.

#### Owning Layer or Module

- Implementation owner: `lib/src/contract/validated/validated_value_support.dart`.
- Public boundary type owner: `lib/src/contract/validated/finite_offset_value.dart`.
- Import proof owners: `test/public_api/scene_builder_test.dart` and
  `test/serialization/scene_codec_validation_test.dart`.
- Direct boundary proof owner: `test/public_api/validated_boundary_value_test.dart`.

#### Dependency Direction

- Contract validation may depend only on contract-layer error and validation
  support.
- Model decode files may continue depending on contract validated values.
- Serialization decode may continue delegating to model import/build
  validation.
- No contract code may import `lib/src/model/**` helpers.

#### State and Data Ownership

- Offset JSON object shape is owned by the contract validated-value parser.
- JSON alias path strings for line and stroke fields remain model-owned.
- No new state, cache, registry, or synchronization layer is introduced.

#### Entry and Exit Boundaries

- Entry: raw parsed JSON-compatible offset values entering
  `FiniteOffsetValue.fromJson(...)` or `validatedRequireJsonFiniteOffset(...)`.
- Exit on success: a finite `Offset` value whose object wrapper had only
  string keys.
- Exit on failure: `SceneDataException` with stable code, path, details, and
  source appropriate to the malformed key.

#### Permitted Extension Seam

- The only permitted implementation seam is a small contract-local key guard
  inside or directly adjacent to `validatedRequireJsonFiniteOffset(...)`.
- Test support may add small local fixtures only inside the named test files
  when it reduces repeated malformed scene setup.

#### Rejected Alternatives

- Guard only line and stroke decode call sites - rejected because it duplicates
  policy and leaves the public validated offset value weaker.
- Reuse `sceneBuilderCastMap(...)` from contract code - rejected because it
  reverses the layer dependency from contract to model.
- Add a new schema version or migration - rejected because the accepted schema
  contract is being tightened to match existing JSON object rules, not changed
  to a new document format.
- Add a broad JSON object validation rewrite - rejected because `KI-18` is a
  narrow offset object bypass and the repository already has a working object
  guard precedent for other map fields.

#### Why This Level Is Correct

- The lsp trace shows all affected line and stroke paths converge on the same
  offset validator, either directly or through `FiniteOffsetValue.fromJson(...)`.
- The public validated value type exposes the same JSON parser independently of
  scene import; fixing only model decode would preserve the root weakness.
- Architecture docs assign validated boundary values to contract and import
  diagnostic paths to model, so the fix belongs in contract and the proof must
  cover model/serialization path preservation.

### 4B. Architecture Decision Gate

- Not used. Section 4A locks the owner, seam, dependency direction, state
  ownership, and verification strategy.

## 5. Locked Decisions

1. The offset object-key rule is enforced in the contract validated offset JSON
   parser.
2. The implementation uses `SceneDataException.jsonObjectKeysMustBeStrings(...)`
   for non-string keys.
3. The public validated value proof and scene import/decode proof are both
   required before the implementation is considered complete.
4. `KI-18` is removed only after failing reproducer tests and neighboring guard
   tests pass with the owner-side fix.
5. No schema-version constants or public exported symbols change.

## 6. Result Requirements

1. `FiniteOffsetValue.fromJson(...)` rejects offset object maps containing any
   non-string key, even when `x` and `y` are otherwise valid.
2. Line `localA` and `localB` reject non-string extra keys through parsed-map
   surfaces `SceneBuilder.buildFromJson(...)` and `decodeScene(...)`.
3. Stroke `localPoints[i]` rejects non-string extra keys through the same
   parsed-map import/decode surfaces.
4. Rejections preserve `SceneDataException` structured error behavior and
   caller-visible JSON paths.
5. The malformed non-string-key object shape is explicitly documented as not
   representable through `decodeSceneFromJson(...)` because JSON text object
   keys decode as strings.
6. Valid offset objects with string keys and finite numeric `x`/`y` continue to
   import successfully.
7. `KNOWN_ISSUES.md` no longer lists `KI-18` after the proof is in place.

## 7. Execution Order and Gates

### Required Order

- Add the direct public `FiniteOffsetValue.fromJson(...)` failing reproducer
  before changing implementation.
- Add 1 to 3 owner-level guard tests for neighboring offset JSON branches
  before changing implementation: valid string-keyed finite offset acceptance,
  missing or non-numeric coordinate behavior, and non-finite coordinate
  behavior.
- Apply the minimal contract-owner fix only after the failing proof exists.
- Add line/stroke parsed-map import/decode propagation proof after the
  owner-level fix is green.
- Remove `KI-18`, update release notes, and mark this step complete only after
  targeted proof passes.
- Run final required verification after all changed files are known.

### Successor Seam and Retirement Gates

- No successor seam is created.
- No shared support file is retired.
- `KI-18` retirement gate: direct boundary proof and import/decode proof pass,
  and `KNOWN_ISSUES.md` entry `KI-18` is removed in the same change.

### Deferred Broad Verification

- Reserve
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`
  for the final gate after implementation, tests, `KNOWN_ISSUES.md`,
  `CHANGELOG.md`, `PLAN.md`, and this step document are updated.

## 8. File Map

### Implementation Files

- `lib/src/contract/validated/validated_value_support.dart`

### Test Files

- `test/public_api/validated_boundary_value_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

### Fixtures and Supporting Data

- Existing local scene JSON fixture helpers in the named test files and
  `test/support/scene_builder_json_fixtures.dart` may be reused.

### Registry, Inventory, and Workflow Files

- `KNOWN_ISSUES.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_40_json_offset_object_key_contract.md`

### Analysis Area

- `lib/src/contract/validated/**`
- `lib/src/model/scene_builder_decode_line.dart`
- `lib/src/model/scene_builder_decode_stroke.dart`
- `lib/src/model/scene_validation_path_surface.dart`
- `lib/src/serialization/scene_codec.dart`
- `tool/invariant_registry.dart`

## 9. Implementation Rules

### Protected Invariants

- `INV-SER-IMPORT-DIAGNOSTIC-SURFACE`
- `INV-SER-JSON-NUMERIC-VALIDATION`
- contract validated values remain model-independent
- model-owned JSON import path spelling remains `localA`, `localB`, and
  `localPoints`

### Required Proof

- behavioral proof: direct `FiniteOffsetValue.fromJson(...)` rejection for a
  non-string extra key, plus parsed-map scene import/decode rejection for line
  endpoints and stroke point items through `SceneBuilder.buildFromJson(...)`
  and `decodeScene(...)`
- structural proof: existing import-boundary, guardrail, invariant-coverage,
  and architecture-atlas checks from the required code-change preset must pass
  at final verification; no new structural audit is required unless the
  implementation moves ownership or introduces a new seam
- for this bug fix: one failing `FiniteOffsetValue.fromJson(...)` reproducer
  first, plus 1 to 3 owner-level guard tests covering valid string-keyed finite
  offset acceptance, missing or non-numeric coordinate behavior, and non-finite
  coordinate behavior before the minimal owner-side fix
- for refactors: not applicable; this is a bug fix and behavior tightening

### Allowed Change Surface

- Minimal contract-local validation inside
  `validatedRequireJsonFiniteOffset(...)` or a private helper in the same file.
- Test additions in the named public API and serialization test files.
- Required source-of-truth updates for known issue retirement, changelog, and
  plan completion.

### Forbidden Moves

- Do not add call-site-only guards in line or stroke decode as the sole fix.
- Do not import model helpers from contract code.
- Do not change `SceneDataException` public categories unless an existing
  category cannot represent the malformed object-key case.
- Do not change schema version constants.
- Do not broaden the task into general JSON parser normalization or unrelated
  known issues.

### Optional: Recognition Forms That Must Be Supported

- Non-string extra keys in maps that still contain valid string `x` and `y`.
- Non-string extra keys on both line endpoint offsets and stroke point item
  offsets.

### Optional: Allowed Forms That Are Not Violations

- Offset object maps with only string keys and finite numeric `x` and `y`.
- Existing invalid offset forms, such as non-map raw values, missing `x` or
  `y`, non-numeric coordinates, and non-finite coordinates, must keep their
  existing error categories unless the new non-string-key check is the first
  applicable boundary failure.

### Optional: Resolution Rules

- When an offset map contains a non-string key, the object-key violation wins
  before the parser reads `x` and `y`.
- Path strings are supplied by the caller and must not be rewritten inside the
  contract validator.

## 10. Vertical Slices

### Slice 1. [x] Public Offset Boundary Key Guard

#### Slice Contract

Lock and fix the public validated offset JSON object-key contract at the
contract owner.

#### Change

Add a failing public boundary test for `FiniteOffsetValue.fromJson(...)` with
a valid `x`/`y` offset map that also contains a non-string extra key. Add or
confirm owner-level guard tests for valid string-keyed finite offset
acceptance, missing or non-numeric coordinate behavior, and non-finite
coordinate behavior before adding the minimal contract-local key guard in
`validatedRequireJsonFiniteOffset(...)`.

#### Behavioral Verification

- `flutter test --no-pub test/public_api/validated_boundary_value_test.dart`

#### Structural Verification

- Final required-code-change preset must run `tool/check_import_boundaries.dart`
  and `tool/check_guardrails.dart` to prove the contract/model dependency
  direction remains valid.

#### Fixtures Used

- Inline malformed offset map in `test/public_api/validated_boundary_value_test.dart`.

#### Positive Scenarios

- `FiniteOffsetValue.fromJson(...)` continues accepting a normal string-keyed
  finite offset object.
- Existing missing or non-numeric coordinate failures keep the offset-object
  error category.
- Existing non-finite coordinate failures keep the coordinate-finiteness error
  category.

#### Negative Scenarios

- `FiniteOffsetValue.fromJson(...)` rejects a valid-looking offset map with a
  non-string extra key using the JSON object-key error category.

#### Closure Evidence

- The direct public boundary test fails before the implementation change and
  passes after the contract-local fix.

### Slice 2. [x] Scene Import Offset Key Parity

#### Slice Contract

Prove public parsed-map scene import/decode surfaces inherit the
contract-owned offset object-key rule without losing model-owned JSON path
spelling.

#### Change

Add import/decode propagation tests for line `localA`, line `localB`, and
stroke `localPoints[i]` parsed-map offset objects with non-string extra keys,
then verify the slice passes with the Slice 1 contract-owner fix.

#### Behavioral Verification

- `flutter test --no-pub test/public_api/scene_builder_test.dart`
- `flutter test --no-pub test/serialization/scene_codec_validation_test.dart`

#### Structural Verification

- Existing `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` markers in the named test files
  remain attached to the import/decode proof surface.
- Final required-code-change preset must run `tool/check_invariant_coverage.dart`
  and `tool/check_architecture_atlas.dart`.

#### Fixtures Used

- Existing minimal scene JSON helpers from the named test files and
  `test/support/scene_builder_json_fixtures.dart`.

#### Positive Scenarios

- Valid line endpoint and stroke point offset objects with only string keys
  still import successfully through parsed-map import/decode surfaces.
- `decodeSceneFromJson(...)` is not used for the non-string-key malformed
  parsed-map case because JSON text cannot represent non-string object keys.

#### Negative Scenarios

- Line `localA` rejects a non-string extra key at
  `layers[0].nodes[0].localA`.
- Line `localB` rejects a non-string extra key at
  `layers[0].nodes[0].localB`.
- Stroke `localPoints[i]` rejects a non-string extra key at the indexed point
  path.

#### Closure Evidence

- `SceneBuilder.buildFromJson(...)` and `decodeScene(...)` report the same
  structured error contract for the malformed parsed-map offset cases.
- The contract documents that `decodeSceneFromJson(...)` cannot be used to
  construct the same non-string-key malformed object shape.

### Slice 3. [x] Known Issue Retirement and Release Ledger

#### Slice Contract

Retire the active defect only after the executable proof is in place and keep
the repository source-of-truth files synchronized.

#### Change

Remove `KI-18` from `KNOWN_ISSUES.md`, add a concise user-visible
`CHANGELOG.md` fixed entry, and mark Step 40 complete in `PLAN.md` and this
step file.

#### Behavioral Verification

- Re-run the Slice 1 and Slice 2 targeted tests after documentation updates.

#### Structural Verification

- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`
  with every modified, added, renamed, or deleted repository-relative path
  listed.

#### Fixtures Used

- No new fixtures.

#### Positive Scenarios

- `KNOWN_ISSUES.md` contains only still-active defects after `KI-18` removal.
- `CHANGELOG.md` records the JSON import behavior tightening under
  `## Unreleased`.

#### Negative Scenarios

- Do not remove `KI-18` before regression proof passes.
- Do not mark Step 40 complete before final verification is run.

#### Closure Evidence

- Final verification command passes and this step's checklist is complete.

## 11. Final Verification

- `flutter test --no-pub test/public_api/validated_boundary_value_test.dart`
- `flutter test --no-pub test/public_api/scene_builder_test.dart`
- `flutter test --no-pub test/serialization/scene_codec_validation_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`
  with every modified, added, renamed, or deleted repository-relative path
  listed

## 12. Acceptance Criteria

- JSON offset maps with non-string keys are rejected at the contract validated
  value owner.
- Line `localA`, line `localB`, and stroke `localPoints[i]` parsed-map offset
  objects cannot bypass the object-key rule through
  `SceneBuilder.buildFromJson(...)` or `decodeScene(...)`.
- The contract does not require `decodeSceneFromJson(...)` to reproduce
  non-string parsed-map keys because JSON text cannot encode that malformed
  shape.
- Valid string-keyed finite offset objects continue to import and parse.
- Error contracts remain stable and path-aware for public import/decode
  surfaces.
- `KI-18` is removed from `KNOWN_ISSUES.md` only with passing regression proof.
- `CHANGELOG.md`, `PLAN.md`, and this step document reflect the completed
  behavior change when implementation closes the step.
