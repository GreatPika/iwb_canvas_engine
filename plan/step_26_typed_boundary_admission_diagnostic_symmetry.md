# Change Contract

## 1. Change Mandate

Establish one symmetric public diagnostic contract for unsupported typed scene
boundary subtypes so `SceneBuilder.buildFromSnapshot(...)`, `encodeScene(...)`,
and `encodeSceneToJson(...)` report the same stable `SceneDataException`
surface while keeping subtype admission/canonicalization in the contract layer
and keeping serialization free of typed-boundary policy.

## 2. Change Boundary

### Included in the Change

- restore symmetric public diagnostics for unsupported typed `SceneSnapshot`,
  layer, metadata, and node subtypes on the typed snapshot import/build/encode
  path
- ensure top-level typed snapshot import reuses the existing contract-owned
  admission/canonicalization pattern before `sceneImportDraftFromSnapshot(...)`
- add one narrow model-owned translation from typed admission failure to stable
  public `SceneDataException`
- preserve `encodeScene(...)` and `encodeSceneToJson(...)` as passive callers
  of `SceneBuilder.buildFromSnapshot(...)` rather than independent typed
  boundary owners
- add regression tests, invariant updates, and public-contract documentation
  updates for the typed unsupported-subtype diagnostic contract

### Not Included in the Change

- sealing, finalizing, or otherwise breaking the public snapshot family API
- broad error-model redesign outside the unsupported typed boundary subtype
  contract
- moving typed subtype support policy into `serialization/**`
- changing JSON transport diagnostics such as `invalidJsonPayload`
- changing debug/internal helper behavior where raw strict-seam `StateError`
  remains the intentional contract
- unrelated cleanup of node/spec/patch admission beyond the snapshot-family
  path needed for this defect

## 3. Surrounding Code Review

### Inspected Artifacts

- `lib/src/model/scene_builder_api.dart` - `SceneBuilder.buildFromSnapshot(...)`
  is documented as the public typed import/canonicalization gateway and promises
  `SceneDataException` for public boundary failures
- `lib/src/model/scene_builder.dart` - `sceneBuildFromSnapshot(...)` currently
  routes raw snapshots directly into `sceneImportDraftFromSnapshot(...)`
  without a typed-boundary diagnostic guard
- `lib/src/model/scene_import_draft_from_snapshot.dart` - converts a typed
  snapshot straight into `sceneSnapshotBackingOf(...)`, which means the current
  public typed path reaches the strict backing seam directly
- `lib/src/contract/snapshot.dart` - aggregate snapshot admission already
  canonicalizes supported nested boundary subtypes through `_admit*` helpers and
  rejects unsupported nested subtypes at admission via
  `_throwUnsupportedBoundarySubtype(...)`
- `lib/src/contract/internal/snapshot_boundary_impl.dart` - the strict backing
  rebuild seam still requires exact runtime types and throws raw `StateError`
  when non-exact public subtypes leak that far
- `lib/src/contract/internal/boundary_impl_support.dart` - exact-type seam
  enforcement is centralized in `requireExactBoundaryRuntimeType(...)`
- `lib/src/serialization/scene_codec.dart` - `encodeScene(...)` canonicalizes
  through `SceneBuilder.buildFromSnapshot(...)`; `encodeSceneToJson(...)`
  delegates to `encodeScene(...)`
- `lib/src/serialization/codec_guards.dart` - `_guardEncode(...)` rethrows only
  `SceneDataException` and maps any other failure to
  `SceneDataException.invalidJsonPayload(...)`
- `tool/invariant_registry.dart` -
  `INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES` and
  `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` already constrain the intended split
- `ARCHITECTURE.md` - checked-in architecture explicitly says contract owns the
  public boundary, model owns validated import proof minting, public boundary
  admission happens before draft materialization, and serialization encodes via
  `SceneBuilder.buildFromSnapshot(...)`
- `API_GUIDE.md` - public import/export paths already promise one shared
  boundary contract and say unsupported boundary subtypes fail at admission
  before later backing/materialization seams
- `plan/step_7_import_boundary_diagnostic_surface.md` - fixes the
  caller-visible diagnostic surface as model-owned and explicitly rejects moving
  boundary-path policy into serialization or carriers
- `plan/step_8_validated_import_materialization_boundary.md` - locks the model
  import spine around `ScenePolicy.validateImportDraft(...)` and
  `ValidatedSceneImportDraft`
- `plan/step_9_boundary_admission_canonicalization_and_unsafe_materialization_split.md`
  - locks the contract-owned admission/canonicalization split and explicitly
  rejects using strict fallback/backing seams as the first failure surface
- `test/contract/validated_fast_path_contract_test.dart` - proves unsupported
  nested boundary subtypes fail at admission before seam rebuild and that the
  strict seam still rejects unsupported raw subtypes
- `test/public_api/scene_builder_test.dart` - already proves public path parity
  for neighboring typed-vs-json diagnostics, but does not lock the unsupported
  typed subtype public contract
- `test/serialization/scene_codec_validation_test.dart` - currently locks only
  the debug/internal raw `StateError` behavior for unsupported subtypes, not
  the public typed entrypoints
- `dart run tool/lsp_trace_symbol.dart lib/src/model/scene_import_draft_from_snapshot.dart sceneImportDraftFromSnapshot --direction=both --depth=4 --json`
  - mechanically confirms that `SceneBuilder.buildFromSnapshot(...)`,
  `encodeScene(...)`, and `encodeSceneToJson(...)` converge on the same direct
  path into `sceneSnapshotBackingOf(...)`
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/snapshot.dart _validatedSceneSnapshotFields --direction=both --depth=4 --json`
  - mechanically confirms that the checked-in aggregate snapshot admission owner
  already lives in `contract/snapshot.dart`
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/snapshot.dart _admitNodeSnapshot --direction=both --depth=4 --json`
  - mechanically confirms that nested subtype admission already follows the
  contract-owned eager canonicalization/rejection pattern
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/model --classification=pure-forwarder`
  - mechanically confirms that `scene_policy.dart` remains orchestration-heavy
  but intentionally thin in the relevant forwarder seams
- `dart run tool/lsp_find_thin_wrappers.dart lib/src/serialization --classification=pure-forwarder`
  - finds no corresponding serialization-owned policy seam, which supports
  keeping typed subtype policy out of `serialization/**`
- `dcm calculate-metrics lib/src/model/scene_builder.dart` - shows no metric
  pressure that would justify pushing this policy into a new helper/service
- `dcm calculate-metrics lib/src/serialization/scene_codec.dart` - shows
  `scene_codec.dart` is already boundary-heavy, which is a signal against
  widening its ownership

### Current Entry Path

- typed snapshot public path:
  `SceneBuilder.buildFromSnapshot(...) ->
  sceneBuildFromSnapshot(...) ->
  sceneImportDraftFromSnapshot(...) ->
  sceneSnapshotBackingOf(...) ->
  requireExactBoundaryRuntimeType(...)`
- typed encode path:
  `encodeScene(...) ->
  SceneBuilder.buildFromSnapshot(...) ->
  sceneBuildFromSnapshot(...) ->
  sceneImportDraftFromSnapshot(...) ->
  sceneSnapshotBackingOf(...) ->
  requireExactBoundaryRuntimeType(...) ->
  _guardEncode(...)`
- current nested aggregate admission path:
  `SceneSnapshot(...) / BackgroundLayerSnapshot(...) / ContentLayerSnapshot(...)`
  -> `_validatedSceneSnapshotFields(...)` / `_admit*`
  -> eager exact-value canonicalization or admission failure

### Current Owner

- contract-layer snapshot admission in `lib/src/contract/snapshot.dart`
- model-layer typed import/build gateway in `lib/src/model/scene_builder.dart`
  and `lib/src/model/scene_builder_api.dart`
- serialization-layer JSON transport guarding in
  `lib/src/serialization/scene_codec.dart` and `codec_guards.dart`

### Adjacent Abstractions

- `lib/src/model/scene_policy.dart` - validated import proof owner that must
  remain downstream of typed admission rather than absorb subtype policy
- `lib/src/model/scene_validation_path_surface.dart` - existing model-owned
  caller-visible diagnostic surface seam
- `lib/src/model/scene_value_validation_support.dart` - existing model-to-
  public `SceneDataException` conversion seam
- `lib/src/contract/internal/snapshot_fast_path.dart` - validated bridge surface
  already shared with model and serialization
- `lib/src/contract/internal/snapshot_node_boundary_fallback.dart` - strict
  raw subtype rejection seam that must remain a backstop, not the first public
  failure surface

### Existing Tests

- `test/contract/validated_fast_path_contract_test.dart` - locks contract
  admission for nested snapshot boundary families and raw strict-seam rejection
- `test/public_api/scene_builder_test.dart` - locks public builder parity and
  neighboring typed public `SceneDataException` behavior
- `test/serialization/scene_codec_validation_test.dart` - locks encode/decode
  parity for neighboring public contracts and debug raw-seam behavior
- `test/model/scene_builder_test.dart` - locks direct model import spines such
  as `sceneCanonicalizeAndValidateSnapshot(...)` and `ScenePolicy.validateImportSnapshot(...)`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` -
  already locks model ownership for the diagnostic path surface and keeps
  `scene_policy.dart` orchestration-only on import diagnostics

### Analogous Implementation Path

- `lib/src/contract/snapshot.dart` `_admitNodeSnapshot(...)`,
  `_admitBackgroundLayerSnapshot(...)`, and `_admitContentLayerSnapshot(...)`
  - the closest checked-in precedent because they already canonicalize supported
  carrier-backed values to exact public contract instances and reject
  unsupported boundary subtypes at admission instead of leaving the first
  failure to later strict seams

### Governing Repository Rules

- `AGENTS.md` - fix the shared owner of the invariant rather than patching only
  one downstream caller
- `AGENTS.md` - when recurring behavior matters, encode it in checked-in proof
  and source-of-truth docs rather than in chat
- `ARCHITECTURE.md` - `contract` owns the public boundary and `model` owns
  validated import proof minting
- `ARCHITECTURE.md` - public boundary admission happens before validated draft
  materialization and serialization encodes through `SceneBuilder.buildFromSnapshot(...)`
- `API_GUIDE.md` - unsupported boundary subtypes fail at admission before later
  backing/materialization seams
- `plan/step_7_import_boundary_diagnostic_surface.md` - caller-visible import
  diagnostics stay model-owned; do not push them into serialization or carriers
- `plan/step_9_boundary_admission_canonicalization_and_unsafe_materialization_split.md`
  - strict fallback/backing seams remain backstops rather than the first public
  failure surface
- repository verification rules in `AGENTS.md` - final implementation must run
  the required code-change preset and update source-of-truth docs for the
  public behavior change

### Rejected Misleading Local Patterns

- `_guardEncode(...)` special-casing this `StateError` - wrong owner because it
  would keep typed boundary classification in serialization and continue to mix
  typed admission with JSON transport policy
- broad `catch` in `SceneBuilder.buildFromSnapshot(...)` - wrong seam because it
  would hide arbitrary implementation defects instead of translating only the
  known admission failure class
- model-owned manual traversal of the snapshot graph - wrong level because it
  would duplicate the checked-in contract admission logic that already exists in
  `snapshot.dart`
- storing typed subtype provenance on `SceneImportDraft` or snapshot backing -
  wrong data owner and explicitly rejected by Step 7 and Step 8
- changing debug/internal helpers to `SceneDataException` by default - wrong
  scope because those helpers intentionally probe the raw strict seam
- sealing the public snapshot family - wrong scope and a breaking public API
  move not justified by this bug

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- contract-owned typed boundary admission for aggregate snapshot families plus
  model-owned public diagnostic translation for typed snapshot import/build
  entrypoints

#### Selected Architectural Form

- keep unsupported subtype support policy in the snapshot-family admission owner
  in `lib/src/contract/snapshot.dart`
- make the typed snapshot public gateway explicitly re-enter the checked-in
  contract admission/canonicalization path before
  `sceneImportDraftFromSnapshot(...)` so raw top-level `SceneSnapshot` subtypes
  cannot bypass admission and fall straight into the strict backing seam
- add one narrow model-owned translation around that typed admission step so
  only admission-class unsupported subtype failures become a stable public
  `SceneDataException`
- keep `ScenePolicy`, validated import proof minting, and runtime materialization
  downstream of successful typed admission; do not move subtype policy into
  `scene_policy.dart`
- keep `encodeScene(...)` and `encodeSceneToJson(...)` delegating to
  `SceneBuilder.buildFromSnapshot(...)` so the fixed typed public contract is
  inherited automatically rather than reimplemented in serialization
- keep strict backing/fallback seams and debug helper paths fail-fast on raw
  `StateError` as an internal backstop contract

#### Owning Layer or Module

- contract admission owner: `lib/src/contract/snapshot.dart`
- model gateway owner: `lib/src/model/scene_builder.dart` and
  `lib/src/model/scene_builder_api.dart`
- public error surface owner: `lib/src/contract/scene_data_exception.dart`
- passive transport owner: `lib/src/serialization/scene_codec.dart`

#### Dependency Direction

- public typed snapshot entrypoints call the model snapshot gateway
- the model gateway re-enters contract admission/canonicalization before draft
  conversion
- only admitted snapshots flow into `sceneImportDraftFromSnapshot(...)`,
  `ScenePolicy.validateImportDraft(...)`, and later runtime/canonical
  materialization
- serialization depends on the fixed model gateway and must not add its own
  typed subtype classification

#### State and Data Ownership

- subtype support and exact-value canonicalization remain owned by aggregate
  snapshot admission in `contract`
- `SceneImportDraft` and snapshot backing remain canonical carriers only and do
  not store subtype-diagnostic provenance
- the model gateway owns the public typed boundary classification that turns the
  internal admission failure into stable `SceneDataException.code/path/details`
- `_guardEncode(...)` keeps owning JSON transport wrapping only; it does not
  become a typed boundary classifier

#### Entry and Exit Boundaries

- entry boundaries:
  `SceneBuilder.buildFromSnapshot(...)`,
  `encodeScene(...)`,
  `encodeSceneToJson(...)`
- internal typed admission boundary:
  one model-owned snapshot admission call immediately before
  `sceneImportDraftFromSnapshot(...)`
- downstream exit boundaries:
  `sceneImportDraftFromSnapshot(...)`,
  `ScenePolicy.validateImportDraft(...)`,
  `_encodeCanonicalSnapshot(...)`

#### Permitted Extension Seam

- the only permitted admission extension is adjacent to the existing snapshot
  family admission owner in `contract/snapshot.dart` or by explicit reuse of
  that owner from the model gateway
- the only permitted public error extension is one stable typed unsupported
  boundary subtype shape in `SceneDataException` and its message derivation
- no new general-purpose import gateway, provenance carrier, or serialization
  subtype helper may be introduced

#### Rejected Alternatives

- serialization-side subtype mapping - rejected because the typed boundary
  contract would remain split between model and serialization and would still be
  semantically wrong for non-JSON input
- model-owned graph walk preflight - rejected because it duplicates the
  existing contract admission owner instead of reusing it
- broad catch/rewrap of all `StateError` from `buildFromSnapshot(...)` -
  rejected because it would hide real defects behind public boundary errors
- public API sealing/finalization of snapshot classes - rejected because it is a
  breaking scope increase unrelated to the immediate invariant gap

#### Why This Level Is Correct

- LSP flow probes show the bug exists exactly because the public typed path
  reaches the strict backing seam before reusing the checked-in contract
  admission owner
- the contract layer already has the dominant local form for eager supported-
  subtype canonicalization and unsupported-subtype rejection
- the model layer already owns caller-visible typed import diagnostics and the
  validated import spine, so it is the correct place to translate the admission
  failure into `SceneDataException`
- serialization is factually only a passive caller of
  `SceneBuilder.buildFromSnapshot(...)`, so making it a second typed-boundary
  owner would be an architecture regression rather than a fix

## 5. Locked Decisions

1. The public typed unsupported-subtype contract must not use
   `SceneDataErrorCode.invalidJson` or the `invalidJsonPayload` template.
2. `SceneBuilder.buildFromSnapshot(...)`, `encodeScene(...)`, and
   `encodeSceneToJson(...)` must compare equal on `code`, `path`, and `details`
   for the same unsupported typed subtype payload.
3. The fix must cover unsupported scene, layer, metadata, and node subtypes on
   the typed snapshot path, not only the top-level `SceneSnapshot` subclass.
4. Debug/internal seams such as `debugEncodeCanonicalSnapshotForTest(...)`
   remain allowed to expose raw strict-seam `StateError`.
5. The translation must stay narrow to admission-class subtype failures; the
   implementation must not turn arbitrary internal errors into
   `SceneDataException`.
6. The defect to repair in this step is the top-level typed `SceneSnapshot`
   bypass into the strict backing seam; existing nested layer, metadata, and
   node admission coverage remains part of the protection envelope and must
   stay green rather than be re-designed in parallel.

## 6. Result Requirements

1. A typed unsupported boundary subtype reaching
   `SceneBuilder.buildFromSnapshot(...)` must fail as `SceneDataException`
   instead of raw `StateError`.
2. The same typed unsupported subtype reaching `encodeScene(...)` and
   `encodeSceneToJson(...)` must fail with the same `SceneDataException`
   contract as `SceneBuilder.buildFromSnapshot(...)`.
3. JSON transport failures and malformed parsed-map failures must keep their
   current `invalidJsonPayload` behavior unchanged.
4. Supported carrier-backed typed snapshots must continue to canonicalize to
   exact built-in public contract values before draft conversion.
5. Checked-in invariants, public docs, and regression tests must make later
   typed-boundary diagnostic drift mechanically visible.
6. Release-ready public docs, including `README.md`, must describe the repaired
   typed import/export contract consistently with `API_GUIDE.md` and
   `ARCHITECTURE.md`.
7. Step closure must update both `PLAN.md` and this step document in the same
   change when the implementation is complete.

## 7. Execution Order and Gates

### Required Order

- first, add the failing public reproducer on the current owner surface and add
  neighboring guard tests for the same typed contract
- next, land the minimal contract-admission reuse plus narrow model-side public
  diagnostic translation
- then, update invariants and public docs after the behavior is green and the
  owner split is fixed

### Successor Seam and Retirement Gates

- successor seam: typed public entrypoints must pass through contract snapshot
  admission before `sceneImportDraftFromSnapshot(...)`, with model-owned public
  error translation around that admission step
- retirement gate: the old behavior is retired only after no public typed
  entrypoint exposes raw strict-seam `StateError` or `invalidJsonPayload` for
  this contract, while debug/internal helpers still prove the raw seam remains
  strict

### Deferred Broad Verification

- reserve `dart run tool/check_guardrails.dart` for the final gate after any
  invariant wording or guardrail references are updated
- reserve `dart run tool/check_invariant_coverage.dart` for the final gate
  after invariant wording and proof markers are in place
- reserve `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<...>`
  for the final gate after all implementation and documentation files for this
  step are updated

## 8. File Map

### Implementation Files

- `lib/src/contract/snapshot.dart`
- `lib/src/model/scene_builder.dart`
- `lib/src/model/scene_builder_api.dart`
- `lib/src/contract/scene_data_exception.dart`

### Test Files

- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/model/scene_builder_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `test/tool/invariant_coverage_tool_test.dart`

### Fixtures and Supporting Data

- no new long-lived fixture files are expected; use local unsupported subtype
  test doubles in the existing suites unless the current helpers become
  insufficient

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_26_typed_boundary_admission_diagnostic_symmetry.md`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `API_GUIDE.md`
- `README.md`
- `CHANGELOG.md`

### Analysis Area

- `lib/src/contract/**`
- `lib/src/model/**`
- `lib/src/serialization/**`
- `test/public_api/**`
- `test/serialization/**`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES` must continue to mean unsupported
  public boundary subtypes are rejected at admission before strict raw seams
- `INV-SER-IMPORT-DIAGNOSTIC-SURFACE` must continue to mean caller-visible
  typed diagnostics stay model-owned and do not move into serialization
- `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY` must continue to hold;
  this step must not bypass `ScenePolicy.validateImportDraft(...)`
- existing debug/internal strict-seam tests must continue to prove the raw
  backstop remains strict after the public typed contract is repaired

### Required Proof

- behavioral proof:
  `test/public_api/scene_builder_test.dart` must first fail on
  `SceneBuilder.buildFromSnapshot(_UnsupportedSceneSnapshot())` and add 1 to 3
  neighboring guard tests for the same contract
- behavioral proof:
  `test/serialization/scene_codec_validation_test.dart` must prove
  `encodeScene(...)` and `encodeSceneToJson(...)` match the same
  `SceneDataException.code/path/details` as `SceneBuilder.buildFromSnapshot(...)`
  for the unsupported typed subtype case
- behavioral proof:
  `test/contract/validated_fast_path_contract_test.dart` must continue to prove
  nested contract admission and raw strict-seam rejection, so the public fix
  does not regress the checked-in contract split
- structural proof:
  existing `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
  and `dart run tool/check_guardrails.dart` must stay green, proving the fix did
  not move typed diagnostic ownership into the wrong layer
- structural proof:
  `test/tool/invariant_coverage_tool_test.dart` and
  `dart run tool/check_invariant_coverage.dart` must stay aligned with the
  updated invariant wording
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract

### Allowed Change Surface

- narrow additions or refactors in the typed snapshot gateway, snapshot
  admission owner, and public `SceneDataException` support
- exact documentation and invariant wording needed to describe the public typed
  contract
- minimal encode-path adjustments only where they are required to preserve the
  gateway-owned `SceneDataException`

### Forbidden Moves

- no serialization-owned subtype policy helper
- no carrier provenance fields on `SceneImportDraft` or snapshot backing
- no duplication of snapshot graph admission logic across multiple layers
- no broad catch-all conversion of internal errors to `SceneDataException`
- no change that widens debug/internal helper semantics from raw seam probing to
  public contract semantics

### Optional: Allowed Forms That Are Not Violations

- the implementation may reuse the exact public `SceneSnapshot(...)`
  reconstruction path to re-enter contract admission, or it may factor a small
  contract-adjacent helper, as long as subtype support remains contract-owned
  and model does not duplicate the admission traversal
- the implementation may add a narrow internal discriminator for admission-class
  subtype failures if it avoids brittle policy leakage into model or
  serialization

### Optional: Resolution Rules

- if the implementation needs a new public error constructor or template, it
  must describe only typed unsupported boundary subtypes and must not be shared
  with JSON transport failures
- if the top-level scene subtype case cannot carry a meaningful field path, the
  contract may leave `path` null there, but nested typed subtypes must keep the
  canonical typed path surface

## 10. Vertical Slices

### Slice 1. [x] Lock The Broken Public Contract

#### Slice Contract

Add the failing public reproducer and guard tests on the current owner surfaces
so the typed unsupported-subtype diagnostic drift is visible before any owner
change lands.

#### Change

- add a public builder reproducer for unsupported typed scene subtypes
- add encode-path parity tests for `encodeScene(...)` and `encodeSceneToJson(...)`
- add one neighboring guard that proves the debug/internal raw seam contract is
  still distinct from the public typed contract

#### Behavioral Verification

- targeted `flutter test test/public_api/scene_builder_test.dart`
- targeted `flutter test test/serialization/scene_codec_validation_test.dart`

#### Structural Verification

- existing `dart run tool/check_guardrails.dart`

#### Fixtures Used

- local `_Unsupported*Snapshot` test doubles in the existing public and
  serialization suites

#### Positive Scenarios

- supported exact typed snapshots still build and encode normally

#### Negative Scenarios

- public typed unsupported subtype currently leaks raw `StateError`
- encode path currently misclassifies the same failure as `invalidJsonPayload`

#### Closure Evidence

- the new reproducer fails before implementation and names the expected stable
  public parity contract

### Slice 2. [x] Restore Admission Before Draft Conversion

#### Slice Contract

Route the typed public snapshot gateway through contract-owned admission before
draft conversion and translate only admission-class unsupported subtype failures
to the stable public `SceneDataException`.

#### Change

- add the minimal typed snapshot admission reuse on the model gateway
- add one narrow public error translation for unsupported typed admission
  failures
- keep `ScenePolicy` and serialization free of new typed subtype policy
- keep the implementation scoped to the top-level typed `SceneSnapshot` bypass
  while preserving the already-checked nested admission contracts

#### Behavioral Verification

- targeted `flutter test test/public_api/scene_builder_test.dart`
- targeted `flutter test test/serialization/scene_codec_validation_test.dart`
- targeted `flutter test test/model/scene_builder_test.dart`

#### Structural Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used

- existing unsupported subtype test doubles and direct model entrypoint tests

#### Positive Scenarios

- supported carrier-backed typed snapshots still canonicalize to exact public
  contract values before import
- public encode path now inherits the same stable `SceneDataException`

#### Negative Scenarios

- the top-level typed `SceneSnapshot` bypass no longer leaks into the raw
  strict seam, while the already-existing nested layer, metadata, and node
  admission protections remain intact and continue to reject unsupported
  subtypes without JSON transport wrapping

#### Closure Evidence

- builder and encode parity tests pass without changing debug/internal raw seam
  behavior

### Slice 3. [x] Lock Repository Truth For The Typed Contract

#### Slice Contract

Update invariants and public docs so the repaired typed unsupported-subtype
contract becomes explicit repository truth rather than chat-only knowledge.

#### Change

- update invariant wording for the admission/public diagnostic split
- update architecture and public API docs for typed unsupported-subtype parity
- update `README.md` so the public import/export contract remains release-ready
- add an unreleased changelog entry for the public bug fix
- update `PLAN.md` and this step document together so the completed step state
  is closed in the same change as the implementation

#### Behavioral Verification

- targeted `flutter test test/public_api/scene_builder_test.dart`
- targeted `flutter test test/serialization/scene_codec_validation_test.dart`

#### Structural Verification

- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_guardrails.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- repository docs now describe the same owner split and public contract that the
  code enforces
- plan state and step state close together without leaving the active roadmap
  stale

#### Negative Scenarios

- no stale doc wording remains that implies the strict backing seam is still the
  first public failure surface for typed unsupported subtypes

#### Closure Evidence

- docs, invariants, and changelog align with the passing implementation and
  proof files
- `PLAN.md` and this step file are updated together to reflect step closure

## 11. Final Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

## 12. Acceptance Criteria

- public typed unsupported boundary subtypes no longer leak raw `StateError`
  from `SceneBuilder.buildFromSnapshot(...)`
- `SceneBuilder.buildFromSnapshot(...)`, `encodeScene(...)`, and
  `encodeSceneToJson(...)` now agree on `SceneDataException.code/path/details`
  for the same unsupported typed subtype payload
- JSON transport errors still report `invalidJsonPayload` only for JSON
  transport failures, not for typed snapshot subtype failures
- contract admission remains the owner of subtype support/canonicalization and
  strict raw seams remain an internal/debug backstop
- invariants, docs, and tests make future typed-boundary diagnostic drift
  mechanically visible
- `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `PLAN.md`,
  and this step document are all synchronized with the landed behavior and
  closure state
