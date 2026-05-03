# Change Contract

## 1. Change Mandate

Close `KI-15` by making scene snapshot backing fast paths mechanically
distinguish fully structure-validated backing construction from explicit raw
internal backing assembly.

## 2. Change Boundary

### Included in the Change

- make `sceneSnapshotBackingFromValidated(...)` prove global
  `SceneSnapshotBacking` structure before returning
- keep direct `SceneSnapshotBacking(...)` construction as the explicit raw
  internal bypass for malformed backing tests and owner-side negative scenarios
- remove or avoid duplicate structure-validation hops where the same
  `sceneSnapshotBackingFromValidated(...)` call already proves the backing and
  no separate public boundary is being defended
- preserve public `SceneSnapshot(...)` constructors as globally valid by
  construction
- preserve `ScenePolicy.validateImportDraft(...)` as the import boundary that
  validates raw `SceneImportDraft.fromBacking(...)` payloads
- update regression tests, structural audits, known-issue state, architecture
  family status, release notes, `PLAN.md`, and this step document in the same
  implementation change

### Not Included in the Change

- no public package API expansion, rename, or schema-version change
- no public exposure of `SceneSnapshotBacking` or raw backing constructors
- no migration of full model value validation into the contract backing helper
- no rewrite of `ScenePolicy`, import canonicalization, serialization decode,
  runtime scene export, or public snapshot constructors beyond adopting the
  corrected backing contract where required
- no broad cleanup of unrelated raw backing test fixtures
- no implementation for `KI-16`, `KI-17`, `KI-18`, `KI-19`, `KI-20`, or any
  other active known issue

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` - records `KI-15` as an active `P2` defect because
  `sceneSnapshotBackingFromValidated(...)` returns `SceneSnapshotBacking`
  without proving global scene structure while duplicate layer or node ids can
  still be represented.
- `docs/ARCHITECTURE_ATLAS.md` - identifies the atlas as the architecture
  navigation entrypoint and routes active confirmed defects through
  `KNOWN_ISSUES.md`.
- `docs/architecture/overview.md` - marks
  `contract_document_model_and_validated_fast_paths` as `known issue` while the
  rest of the surrounding engine families remain `locked`.
- `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`
  - owns immutable contract document objects and validated fast-path
  materialization rules; it explicitly requires validated backing builders for
  backing types with global structure validators to route through the matching
  structure validator.
- `docs/architecture/families/import_build_materialization.md` - keeps external
  input validation and model-owned snapshot projection in the import/build
  family, proving `KI-15` is not an import pipeline owner change.
- `docs/architecture/families/model_document_mutation_and_topology.md` - keeps
  runtime topology invariants model-owned, proving the backing helper must not
  become a runtime topology owner.
- `docs/architecture/families/serialization_and_schema.md` - keeps JSON schema
  validation parity in serialization/model value-validation owners, proving this
  change must not widen serialized data admission.
- `docs/architecture/families/public_package_boundary.md` - keeps public callers
  on `package:iwb_canvas_engine/iwb_canvas_engine.dart` and public symbols
  backed by public API proof, proving this change must preserve the public
  package surface.
- `docs/proof_architecture/overview.md` - marks proof families as `locked`, so
  proof changes must preserve the current guardrail and invariant architecture.
- `docs/proof_architecture/families/guardrail_runner_and_artifact_model.md` -
  owns guardrail runner artifacts and confirms existing guardrail evidence must
  remain explicit rather than becoming prose-only.
- `docs/proof_architecture/families/invariant_registry_and_proof_reachability.md`
  - owns invariant proof reachability and requires executable required proofs
  to stay reachable from the `required_code_change` preset.
- `lib/src/contract/internal/snapshot_backing.dart` -
  `sceneSnapshotBackingFromValidated(...)` validates camera, background, and
  palette metadata values, then returns `SceneSnapshotBacking(...)` without
  calling `sceneValidateSceneSnapshotBackingStructure(...)`.
- `lib/src/contract/scene_structure_validation.dart` -
  `sceneValidateSceneSnapshotBackingStructure(...)` is the matching global
  structure validator for `SceneSnapshotBacking`; it enforces content-layer
  count, duplicate content-layer ids, duplicate node ids across background and
  content layers, and total node budget.
- `lib/src/contract/internal/snapshot_materialization.dart` -
  `sceneSnapshotFromValidated(...)` currently builds backing through
  `sceneSnapshotBackingFromValidated(...)`, then calls
  `sceneValidateSceneSnapshotBackingStructure(...)` and
  `validateSceneSnapshotBackingMetadataValues(...)` before internal
  materialization.
- `lib/src/contract/snapshot.dart` - public `SceneSnapshot(...)` construction
  already routes admitted public snapshots through
  `sceneValidateSceneStructure(...)`, making ordinary public construction
  globally valid by construction.
- `lib/src/contract/internal/snapshot_fast_path.dart` - exposes the internal
  bridge surface that includes raw backing carriers and typed validated helper
  functions for model and serialization friend layers.
- `lib/src/contract/internal/snapshot_boundary_impl.dart` -
  `materializeSceneSnapshotForInternalUse(...)` is the explicit internal
  materialization seam for backing carriers and does not own validation.
- `lib/src/model/scene_import_draft.dart` - ordinary `SceneImportDraft(...)`
  currently builds backing through `sceneSnapshotBackingFromValidated(...)`,
  while `SceneImportDraft.fromBacking(...)` is the explicit raw backing
  admission seam.
- `lib/src/model/scene_policy.dart` -
  `ScenePolicy.validateImportDraft(...)` validates raw import draft structure
  before value validation and remains the owner that mints
  `ValidatedSceneImportDraft`.
- `lib/src/model/scene_builder_decode_scene.dart` - JSON decode builds a raw
  `SceneSnapshotBacking(...)` and wraps it with `SceneImportDraft.fromBacking`,
  which is correct because import validation happens later through
  `ScenePolicy`.
- `lib/src/model/scene_snapshot_from_scene.dart` - runtime scene export builds
  backing with validated backing helpers and projects the result through
  `projectValidatedSceneSnapshot(...)`.
- `lib/src/model/scene_snapshot_projection.dart` -
  `projectValidatedSceneSnapshot(...)` projects backing to public snapshot
  objects through typed validated node helpers and public aggregate
  constructors; it is not the owner for raw backing construction.
- `test/contract/scene_structure_validation_test.dart` - already proves
  `sceneValidateSceneSnapshotBackingStructure(...)` reports duplicate node ids
  and duplicate layer ids when handed malformed backing.
- `test/contract/validated_fast_path_contract_test.dart` - already proves
  validated snapshot producers reject malformed backing while explicit unsafe
  internal materialization can preserve malformed raw backing.
- `test/model/scene_builder_test.dart` - already covers
  `ScenePolicy.validateImportDraft(...)` diagnostics and
  `SceneImportDraft(...)` ordinary construction versus
  `SceneImportDraft.fromBacking(...)` raw bypass behavior.
- `tool/audit_validated_backing_structure.dart` - inventories public
  `*BackingFromValidated` functions that return backing types with separate
  global structure validators without reaching the matching validator.
- `tool/audit_validated_materialization_paths.dart` - confirms validated public
  functions do not directly bypass through raw materialization.
- `tool/audit_bridge_surfaces.dart` - confirms bridge surfaces do not leak
  generic backing-to-public materializers when run through the registered bridge
  surface inventory.
- `tool/run_repository_audits.dart` - current standalone audit bundle passes
  every audit except `validated_backing_structure`.
- `tool/invariant_registry.dart` - the relevant invariant family includes
  `INV-ENG-NO-EXTERNAL-MUTATION`,
  `INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY`,
  `INV-ENG-SHARED-SCENE-METADATA-CONTRACT`,
  `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`, and
  `INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES` for the contract document model
  and validated fast-path family.
- `dart run tool/audit_validated_backing_structure.dart --json lib/src/contract`
  - reports exactly one violation:
  `lib/src/contract/internal/snapshot_backing.dart:297
  sceneSnapshotBackingFromValidated returns SceneSnapshotBacking without
  calling sceneValidateSceneSnapshotBackingStructure`.
- `dart run tool/audit_validated_materialization_paths.dart lib/src/contract`
  - passes, proving `KI-15` is not a direct raw materialization bypass.
- `dart run tool/audit_bridge_surfaces.dart` - passes, proving `KI-15` is not a
  bridge-surface generic materializer leak.
- `dart run tool/run_repository_audits.dart` - reports 7 passed audits and one
  failure in `validated_backing_structure`, proving the active defect is
  localized to the validated backing-builder contract.
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/internal/snapshot_backing.dart sceneSnapshotBackingFromValidated --direction=both --depth=2 --json`
  - confirms incoming production calls from `snapshot_materialization.dart`,
  `SceneImportDraft(...)`, and runtime scene export, plus test-only malformed
  backing scenarios.
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/scene_structure_validation.dart sceneValidateSceneSnapshotBackingStructure --direction=both --depth=2 --json`
  - confirms the validator is reached today by `sceneSnapshotFromValidated(...)`
  and `ScenePolicy.validateImportDraft(...)`, but not by
  `sceneSnapshotBackingFromValidated(...)`.
- `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json`
  - confirms the public package surface exports public snapshots and validated
  value classes, not internal backing types.
- `dart run tool/trace_proof_inventory.dart --json` - confirms proof inventory
  and required-code-change reachability are already locked and must remain
  intact.
- `dart run tool/check_guardrails.dart`,
  `dart run tool/check_public_api_surface.dart`,
  `dart run tool/check_invariant_coverage.dart`, and
  `dart run tool/check_architecture_atlas.dart` - pass before this step, so the
  contract must preserve the current package/API/proof architecture while
  retiring the known-issue status.

### Current Entry Path

- defect path:
  `snapshot_fast_path.dart -> snapshot_backing.dart ->
  sceneSnapshotBackingFromValidated(...) -> SceneSnapshotBacking(...)`, with no
  `sceneValidateSceneSnapshotBackingStructure(...)` hop
- currently safe public snapshot path:
  `SceneSnapshot(...) -> _validatedSceneSnapshotFields(...) ->
  sceneValidateSceneStructure(...)`
- currently safe public validated snapshot helper path:
  `sceneSnapshotFromValidated(...) -> sceneSnapshotBackingFromValidated(...) ->
  sceneValidateSceneSnapshotBackingStructure(...) ->
  materializeSceneSnapshotForInternalUse(...)`
- import validation path:
  `ScenePolicy.validateImportDraft(...) ->
  sceneValidateSceneSnapshotBackingStructure(rawDraft.backing) ->
  sceneValidateImportDraftValues(...) -> ValidatedSceneImportDraft`
- raw internal bypass path:
  `SceneSnapshotBacking(...) -> unsafeMaterializeSceneSnapshot(...)` or
  `SceneImportDraft.fromBacking(...)` in test and internal negative scenarios

### Current Owner

- `lib/src/contract/internal/snapshot_backing.dart` owns backing carriers and
  validated backing builders.
- `lib/src/contract/scene_structure_validation.dart` owns generic and
  backing-specific scene structure validators.
- `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`
  owns the target rule that validated backing builders for backing types with
  global structure validators must route through the matching validator.

### Adjacent Abstractions

- `validateSceneSnapshotBackingMetadataValues(...)` validates only camera,
  background grid, and palette backing metadata values.
- `sceneValidateSceneStructure(...)` is the generic structure validator used by
  both public snapshots and backing-specific validation.
- `backgroundLayerSnapshotBackingFromValidated(...)` and
  `contentLayerSnapshotBackingFromValidated(...)` build local backing pieces;
  they cannot prove global cross-layer uniqueness by themselves.
- `SceneImportDraft.fromBacking(...)` is the explicit raw backing draft seam
  and must stay available for decoded or test-owned raw payloads.
- `materializeSceneSnapshotForInternalUse(...)` is the raw internal
  materialization seam and must not become a validation owner.

### Existing Tests

- `test/contract/scene_structure_validation_test.dart` - proves the dedicated
  structure validator catches duplicate node ids and duplicate layer ids.
- `test/contract/validated_fast_path_contract_test.dart` - proves validated
  snapshot producers enforce structure and that raw internal materialization
  can preserve intentionally malformed backing.
- `test/model/scene_builder_test.dart` - proves import validation diagnostics
  and raw draft bypass behavior.
- `test/public_api/validated_boundary_value_test.dart` - backs public snapshot
  global validity through required proof inventory.
- `test/tool/audit/audit_validated_backing_structure_tool_test.dart` - proves
  the structural audit detects and accepts validator hops for validated backing
  builders.

### Analogous Implementation Path

- `SceneSnapshot(...)` in `lib/src/contract/snapshot.dart` is the closest
  public-object precedent: it validates admitted aggregate structure before the
  object escapes.
- `sceneSnapshotFromValidated(...)` in
  `lib/src/contract/internal/snapshot_materialization.dart` is the closest
  validated fast-path precedent: it already calls
  `sceneValidateSceneSnapshotBackingStructure(...)` before returning a public
  snapshot object.
- `ScenePolicy.validateImportDraft(...)` in `lib/src/model/scene_policy.dart`
  is the closest raw-boundary precedent: raw backing is allowed to enter only
  through an explicit raw draft seam and is validated by the boundary owner
  before becoming a validated import draft.

### Governing Repository Rules

- `AGENTS.md` - active confirmed defects belong in `KNOWN_ISSUES.md`; an entry
  must be removed in the same change that fixes it and adds regression proof.
- `AGENTS.md` - when adding a new step to `PLAN.md`, use `$change-contract`
  directly as the canonical step-contract template.
- `AGENTS.md` - after completing a plan step, update the corresponding
  checkbox entries in `PLAN.md` and the linked step document in the same
  change.
- `AGENTS.md` - public behavior changes must update `README.md`,
  `API_GUIDE.md`, and `CHANGELOG.md`; architecture/invariant/module ownership
  changes must update `ARCHITECTURE.md` or the architecture family source of
  truth when applicable.
- `AGENTS.md` - after code changes, run
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`
  with every modified, added, renamed, or deleted repository-relative path.
- `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`
  - validated backing builders for backing types with global structure
  validators must route through the matching structure validator before
  returning the backing.
- `tool/invariant_registry.dart` - invariant expectations for this family are
  registry-owned and must remain executable through required proof surfaces.

### Rejected Misleading Local Patterns

- Renaming `sceneSnapshotBackingFromValidated(...)` to an unchecked/raw helper -
  this would make the audit pass by changing the name, but it would leave the
  contract layer without a fully validated scene backing builder and keep the
  unsafe local pattern convenient.
- Moving global structure validation into `projectValidatedSceneSnapshot(...)`
  - wrong owner because projection assumes validated backing and should not
  become a raw backing admission validator.
- Moving the fix into `ScenePolicy.validateImportDraft(...)` - wrong level
  because that path already validates raw import drafts and does not fix the
  shared `*BackingFromValidated` contract defect.
- Treating `backgroundLayerSnapshotBackingFromValidated(...)` or
  `contentLayerSnapshotBackingFromValidated(...)` as sufficient proof - wrong
  level because duplicate ids and node budgets are global scene properties.
- Using `materializeSceneSnapshotForInternalUse(...)` as proof - wrong seam
  because it is the explicit internal raw materialization path and owns no
  validation.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- This is a contract backing-builder invariant defect, not an import,
  serialization, runtime topology, or public package API defect.

#### Selected Architectural Form

- `sceneSnapshotBackingFromValidated(...)` must become the single fully
  structure-validated `SceneSnapshotBacking` builder.
- Direct `SceneSnapshotBacking(...)` construction remains the explicit raw
  internal bypass for malformed or pre-validation backing payloads.

#### Owning Layer or Module

- Owner: `lib/src/contract/internal/snapshot_backing.dart`.
- Validator owner reused by the fix:
  `lib/src/contract/scene_structure_validation.dart`.
- Architecture source of truth:
  `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`.

#### Dependency Direction

- Contract internals may depend on contract validators.
- Contract internals must not depend on model, serialization, controller,
  render, view, or interactive layers.
- Model and serialization friend layers may continue to consume the
  `snapshot_fast_path.dart` bridge surface.

#### State and Data Ownership

- `SceneSnapshotBacking` remains an immutable raw backing carrier.
- `sceneSnapshotBackingFromValidated(...)` owns only construction-time backing
  proof for structure plus existing metadata backing value validation.
- `ScenePolicy` remains the owner for raw import draft validation and for
  minting `ValidatedSceneImportDraft`.
- Public `SceneSnapshot(...)` constructors remain the owner of public object
  aggregate admission.

#### Entry and Exit Boundaries

- Entry boundary for fully validated backing:
  `sceneSnapshotBackingFromValidated(...)`.
- Entry boundary for raw backing:
  direct `SceneSnapshotBacking(...)` construction, usually followed by
  `SceneImportDraft.fromBacking(...)` or explicit unsafe materialization in
  tests/internal negative scenarios.
- Exit boundary:
  a returned value from `sceneSnapshotBackingFromValidated(...)` must have
  passed `sceneValidateSceneSnapshotBackingStructure(...)`.

#### Permitted Extension Seam

- If a future scene backing type gains a separate global structure validator,
  its public `*BackingFromValidated` builder must call the matching
  `*BackingStructure` validator before returning.
- If a future raw builder is needed, its name must not end in
  `BackingFromValidated` unless it proves every validator required by the
  corresponding backing type.

#### Rejected Alternatives

- Rename the current helper to avoid the audit - rejected because it preserves
  a convenient value-only scene backing builder and weakens the validated fast
  path contract.
- Add a second fully validated helper while leaving
  `sceneSnapshotBackingFromValidated(...)` value-only - rejected because it
  preserves the misleading shared helper and leaves future callers exposed to
  the same ambiguity.
- Fix only callers such as `sceneSnapshotFromValidated(...)` or
  `ScenePolicy.validateImportDraft(...)` - rejected because they are downstream
  consumers and do not repair the shared backing-builder root cause.
- Move global structure validation into model projection - rejected because the
  contract-layer validated backing builder is the owner named by the
  architecture family and structural audit.

#### Why This Level Is Correct

- The failing mechanical rule identifies a `*BackingFromValidated` function
  returning a backing type with a separate structure validator.
- The defect exists before import, serialization, runtime projection, or public
  package exposure.
- Fixing the owner once makes every caller of the validated backing helper
  inherit the same structure proof, while raw callers must become explicit by
  using the backing constructor.

## 5. Locked Decisions

1. `sceneSnapshotBackingFromValidated(...)` must call
   `sceneValidateSceneSnapshotBackingStructure(...)` before it returns.
2. The helper must continue to validate camera, background grid, and palette
   metadata values through existing backing metadata validators.
3. Tests that intentionally need malformed scene backing must use
   `SceneSnapshotBacking(...)` directly, not
   `sceneSnapshotBackingFromValidated(...)`.
4. Any duplicate validation removed from downstream code must be removed only
   when the downstream code is not defending a distinct raw/public boundary.
5. `ScenePolicy.validateImportDraft(...)` must keep validating raw draft
   structure because `SceneImportDraft.fromBacking(...)` remains a raw bypass.
6. `KNOWN_ISSUES.md` may remove `KI-15` only after behavioral regression proof
   and the validated backing structure audit are green.

## 6. Result Requirements

1. A `SceneSnapshotBacking` returned by
   `sceneSnapshotBackingFromValidated(...)` cannot contain duplicate content
   layer ids, duplicate node ids across background/content layers, an oversized
   content-layer list, or an oversized scene node count.
2. Raw internal malformed backing remains possible only through explicit raw
   construction and explicit raw seams.
3. Public snapshot construction remains globally valid by construction.
4. Import validation still reports raw draft structure and value failures from
   `ScenePolicy.validateImportDraft(...)`.
5. The contract architecture family no longer has a known issue for validated
   scene backing structure.
6. Repository-local structural tooling catches any future
   `*BackingFromValidated` builder for a structure-validated backing type that
   skips its matching structure validator.

## 7. Execution Order and Gates

### Required Order

- Add failing reproducer proof for `sceneSnapshotBackingFromValidated(...)`
  rejecting malformed scene structure before changing implementation.
- Add guard proof for valid backing and raw explicit bypass behavior before or
  with the owner fix.
- Change only the contract backing owner and direct callers/tests needed to
  adopt the corrected seam.
- Run targeted contract/model proof and the structural audits before removing
  `KI-15`.
- Remove `KI-15` and update architecture-family status only after proof is
  green.
- Run the required code-change verification preset after all code, test,
  issue, changelog, architecture, and plan files are updated.

### Successor Seam and Retirement Gates

- Successor seam:
  `sceneSnapshotBackingFromValidated(...)` is the fully structure-validated
  backing seam.
- Retained raw seam:
  `SceneSnapshotBacking(...)` is the explicit raw internal construction seam.
- Retirement gate:
  no separate function is retired unless implementation discovers a local
  duplicate validation hop that is no longer necessary and does not defend a
  distinct raw/public boundary.
- Known-issue retirement gate:
  `KNOWN_ISSUES.md` may remove `KI-15` only after the reproducer proof, guard
  proof, and `audit_validated_backing_structure` pass.

### Deferred Broad Verification

- Reserve
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`
  for the final gate after implementation, tests, documentation, changelog,
  `KNOWN_ISSUES.md`, `PLAN.md`, and this step document are complete.
- Do not run plain `dart test`; use the repository verification preset or
  package-owned `flutter test` surfaces as required by `AGENTS.md`.

## 8. File Map

### Implementation Files

- `lib/src/contract/internal/snapshot_backing.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/model/scene_import_draft.dart`
- `lib/src/model/scene_snapshot_from_scene.dart`

### Test Files

- `test/contract/scene_structure_validation_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/model/scene_builder_test.dart`
- `test/tool/audit/audit_validated_backing_structure_tool_test.dart`

### Fixtures and Supporting Data

- none

### Registry, Inventory, and Workflow Files

- `KNOWN_ISSUES.md`
- `CHANGELOG.md`
- `PLAN.md`
- `plan/step_39_scene_snapshot_backing_validation_contract.md`
- `docs/architecture/overview.md`
- `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`

### Analysis Area

- `tool/audit_validated_backing_structure.dart`
- `tool/run_repository_audits.dart`
- `tool/invariant_registry.dart`
- `tool/check_guardrails.dart`
- `tool/check_invariant_coverage.dart`
- `tool/check_architecture_atlas.dart`
- `tool/check_public_api_surface.dart`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-NO-EXTERNAL-MUTATION`
- `INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY`
- `INV-ENG-SHARED-SCENE-METADATA-CONTRACT`
- `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`
- `INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES`

### Required Proof

- behavioral proof: `sceneSnapshotBackingFromValidated(...)` rejects duplicate
  node ids and duplicate layer ids, while valid backing still constructs
  successfully
- behavioral proof: explicit raw backing construction still supports malformed
  internal negative scenarios where tests intentionally need a raw bypass
- behavioral proof: `ScenePolicy.validateImportDraft(...)` still validates raw
  `SceneImportDraft.fromBacking(...)` payloads
- structural proof:
  `dart run tool/audit_validated_backing_structure.dart lib/src/contract`
- structural proof:
  `dart run tool/run_repository_audits.dart`
- structural proof:
  `dart run tool/check_guardrails.dart`
- structural proof:
  `dart run tool/check_invariant_coverage.dart`
- structural proof:
  `dart run tool/check_architecture_atlas.dart`
- for this bug fix: add the failing reproducer before the implementation edit,
  plus 1 to 3 neighboring guard tests for valid backing and explicit raw bypass
  behavior

### Allowed Change Surface

- Minimal owner-side changes in `lib/src/contract/internal/snapshot_backing.dart`.
- Minimal downstream call-site cleanup only where the corrected helper would
  otherwise cause duplicated validation on the same already-proven backing.
- Test fixture changes that replace intentional malformed
  `sceneSnapshotBackingFromValidated(...)` calls with direct
  `SceneSnapshotBacking(...)`.
- Documentation and known-issue closure changes required by `AGENTS.md`.

### Forbidden Moves

- Do not broaden public exports or public API surface.
- Do not make `SceneSnapshotBacking` public.
- Do not move full model value validation into the contract layer.
- Do not remove `ScenePolicy.validateImportDraft(...)` structure validation for
  raw `SceneImportDraft.fromBacking(...)` payloads.
- Do not hide raw bypass behavior behind another helper whose name ends in
  `FromValidated`.
- Do not remove `KI-15` before executable proof is green.
- Do not modify unrelated known issues.

### Optional: Recognition Forms That Must Be Supported

- A public top-level function named `*BackingFromValidated` that returns a
  backing type with a matching public `*BackingStructure` validator must reach
  that validator directly or through helper calls.

### Optional: Allowed Forms That Are Not Violations

- Direct `SceneSnapshotBacking(...)` construction remains allowed for raw
  internal and test-owned bypass scenarios.
- `SceneImportDraft.fromBacking(...)` remains allowed as a raw draft carrier
  seam before `ScenePolicy.validateImportDraft(...)`.
- Existing local backing helpers for background layer, content layer, camera,
  background, grid, palette, and node snapshots remain allowed when no separate
  global structure validator exists for their returned backing type.

### Optional: Resolution Rules

- When both metadata validation and structure validation are needed for
  `SceneSnapshotBacking`, `sceneSnapshotBackingFromValidated(...)` must perform
  both before returning.
- When a caller needs malformed scene backing, it must use direct raw backing
  construction and the test name or surrounding assertion must make the raw
  bypass intent visible.

## 10. Vertical Slices

### Slice 1. [x] Validated Scene Backing Owner Fix

#### Slice Contract

Close the root defect at the contract backing owner: first lock the failing
validated backing behavior with reproducer and guard tests, then make
`sceneSnapshotBackingFromValidated(...)` prove global scene structure before it
returns.

#### Change

- Before implementation, add or update contract tests so
  `sceneSnapshotBackingFromValidated(...)`
  rejects duplicate node ids across background/content layers.
- Before implementation, add or update contract tests so
  `sceneSnapshotBackingFromValidated(...)`
  rejects duplicate content-layer ids.
- Before implementation, add a guard test showing a structurally valid
  `sceneSnapshotBackingFromValidated(...)` call still succeeds.
- Before implementation, add or keep a guard test showing direct
  `SceneSnapshotBacking(...)`
  construction is the explicit raw bypass for malformed backing.
- Run the targeted contract test command and record the expected failing
  reproducer before changing implementation.
- Update `sceneSnapshotBackingFromValidated(...)` to validate the constructed
  backing through `sceneValidateSceneSnapshotBackingStructure(...)` before
  returning.
- Keep existing metadata backing validation behavior.
- Replace intentional malformed calls to `sceneSnapshotBackingFromValidated(...)`
  in tests with direct `SceneSnapshotBacking(...)`.
- Remove duplicate same-boundary structure validation only where the corrected
  helper already proves the backing and no raw/public boundary is being
  separately defended.
- Preserve `ScenePolicy.validateImportDraft(...)` raw-draft structure
  validation.

#### Behavioral Verification

- Run the targeted contract test command for the edited contract tests before
  implementation and record the expected failing reproducer.
- After the owner fix, rerun the same targeted contract test command and expect
  it to pass.
- `flutter test --no-pub test/contract`
- `flutter test --no-pub test/model`

#### Structural Verification

- Run
  `dart run tool/audit_validated_backing_structure.dart lib/src/contract`
  before implementation and record the existing `KI-15` failure.
- After the owner fix, rerun the audit and expect it to pass.
- `dart run tool/audit_validated_materialization_paths.dart lib/src/contract`
- `dart run tool/audit_bridge_surfaces.dart`
- `dart run tool/run_repository_audits.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- valid scene backing with unique content-layer ids and unique node ids returns
  successfully
- raw direct `SceneSnapshotBacking(...)` can still represent intentionally
  malformed backing for negative tests
- import draft validation still succeeds for valid raw drafts
- runtime scene export still produces public snapshots through validated
  projection

#### Negative Scenarios

- duplicate node id across background and content layers throws
  `SceneDataException.duplicateNodeId`
- duplicate content-layer id throws `SceneDataException.duplicateLayerId`
- raw draft validation still rejects malformed raw backing at the import
  boundary
- unsafe internal materialization remains explicit and test-only for malformed
  backing preservation scenarios

#### Closure Evidence

- targeted contract/model tests pass
- standalone repository audits pass

### Slice 2. [x] Issue And Architecture Closure

#### Slice Contract

Retire `KI-15` only after executable proof shows the contract backing helper and
structural audit are aligned with the architecture family target rules.

#### Change

- Remove the `KI-15` entry from `KNOWN_ISSUES.md`.
- Update
  `docs/architecture/families/contract_document_model_and_validated_fast_paths.md`
  from `known issue` to `locked` and describe the accepted form without
  preserving the defect narrative.
- Update `docs/architecture/overview.md` so
  `contract_document_model_and_validated_fast_paths` is `locked`.
- Add a `CHANGELOG.md` `Unreleased` entry for the reliability fix.
- Mark this plan step complete in `PLAN.md` and in this step document only
  after all implementation and verification proof is green.

#### Behavioral Verification

- rerun the targeted contract/model tests from Slice 1 after issue and docs
  closure

#### Structural Verification

- `dart run tool/check_architecture_atlas.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_public_api_surface.dart`

#### Fixtures Used

- none

#### Positive Scenarios

- architecture atlas reports all architecture families and proof families valid
- known-issue ledger no longer lists resolved `KI-15`

#### Negative Scenarios

- no remaining `known issue` status may reference `KI-15`
- no `KNOWN_ISSUES.md` entry may remain for a fixed and proven defect

#### Closure Evidence

- `KNOWN_ISSUES.md` no longer contains `KI-15`
- architecture atlas passes
- final required verification preset passes

## 11. Final Verification

- `flutter test --no-pub test/contract`
- `flutter test --no-pub test/model`
- `dart run tool/audit_validated_backing_structure.dart lib/src/contract`
- `dart run tool/audit_validated_materialization_paths.dart lib/src/contract`
- `dart run tool/audit_bridge_surfaces.dart`
- `dart run tool/run_repository_audits.dart`
- `dart run tool/check_architecture_atlas.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

The required preset changed-paths input must include every modified, added,
renamed, or deleted repository-relative path.

## 12. Acceptance Criteria

- `sceneSnapshotBackingFromValidated(...)` proves global scene backing structure
  before returning.
- Intentional malformed scene backing is represented only through explicit raw
  construction in tests or internal raw seams.
- `ScenePolicy.validateImportDraft(...)` continues to validate raw
  `SceneImportDraft.fromBacking(...)` payloads.
- `dart run tool/audit_validated_backing_structure.dart lib/src/contract`
  passes.
- `dart run tool/run_repository_audits.dart` passes.
- `KNOWN_ISSUES.md` no longer lists `KI-15`.
- The contract document model and validated fast paths family is `locked`.
- `CHANGELOG.md`, `PLAN.md`, and this step document agree with the implemented
  closure state.
- The final required verification preset passes with all changed paths listed.
