# Change Contract

## 1. Change Mandate

Establish a validated-only scene-import materialization boundary so raw
`SceneSnapshot` and raw `SceneImportDraft` payloads cannot bypass model import
policy on the way to runtime `Scene`, and retire the sibling snapshot bypass
helper that currently creates semantic drift.

## 2. Change Boundary

### Included in the Change

- Introduce one internal validated import proof stage between raw
  `SceneImportDraft` and runtime/canonical materialization.
- Consolidate raw `SceneSnapshot -> Scene` materialization onto one
  model-owned façade.
- Update the model import spine so runtime scene materialization and canonical
  snapshot export from draft both consume the same validated proof.
- Add regression tests, structural guardrails, invariant coverage, and
  architecture-document updates for the validated import boundary.

### Not Included in the Change

- Any public API rename or supported external surface change.
- Any schema version, JSON field, or diagnostic-path behavior change from Step
  7.
- Any node-level `NodeSnapshot` / `NodeSpec -> SceneNode` redesign.
- Any runtime-center refactor from ADR 0001 or post-target follow-up work from
  ADR 0002.
- Any duplication of scene-range policy inside decode owners or contract
  constructors.

## 3. Surrounding Code Review

### Inspected Artifacts

- `lib/src/model/scene_from_snapshot.dart` — exposes both
  `sceneImportFromSnapshot(...)` and sibling `sceneFromSnapshot(...)`; the
  latter bypasses `ScenePolicy.validateImportDraft(...)` and calls the pure
  materializer directly.
- `lib/src/model/scene_from_import_draft.dart` — `sceneImportFromDraft(...)`
  validates raw drafts, while `sceneFromImportDraft(...)` pure-materializes a
  runtime `Scene` from a `SceneImportDraft`.
- `lib/src/model/scene_policy.dart` — `validateImportDraft(...)` owns scene
  structure/value validation and already acts as the policy gateway reused by
  import, runtime, and encode validation.
- `lib/src/model/scene_import_draft.dart` — `SceneImportDraft` already
  distinguishes ordinary validated construction from explicit raw
  `fromBacking(...)`, and `sceneSnapshotFromValidatedImportDraft(...)` already
  encodes a validated semantic in its name without a corresponding validated
  type.
- `lib/src/model/scene_import_draft_from_snapshot.dart` — typed snapshots
  become raw drafts through snapshot backing without applying import policy at
  this seam.
- `lib/src/model/scene_builder.dart` — canonical builder entrypoints already
  route raw snapshot/json imports through `sceneImportFromDraft(...)` and
  `ScenePolicy.validateImportDraft(...)`.
- `lib/src/model/document.dart` — `txnSceneFromSnapshot(...)` already routes
  through `sceneImportFromSnapshot(...)`, so the transaction façade depends on
  the raw snapshot import seam.
- `lib/src/model/scene_value_validation_scene.dart` — import-draft validation
  owns scene-wide draft value checks and path-surface propagation over
  `SceneImportDraft`.
- `lib/src/model/scene_value_validation_node.dart` — node transform ceilings
  and hit-padding limits are enforced here through `_sceneValidateTransformRanges(...)`,
  not in schema-only constructors.
- `lib/src/contract/internal/node_boundary_schema_snapshot.dart` — snapshot
  schema validation checks common node schema fields and delegates transform
  validation only to directional schema checks.
- `lib/src/contract/internal/node_boundary_schema_common.dart` —
  `validateNodeDirectionalCommonSchemaFields(...)` enforces finite and
  invertible transforms but not scene-range ceilings.
- `test/model/scene_builder_test.dart` — proves the canonical builder path
  rejects out-of-range transform values, proves `ScenePolicy` reuses the draft
  import spine, and currently covers `sceneFromSnapshot(...)` only on a happy
  path.
- `test/model/document_model_test.dart` — proves `txnSceneFromSnapshot(...)`
  rejects neighboring invalid imports and routes internal scene import through
  the model layer.
- `tool/src/guardrails/rules/model/model_architecture_rules.dart` and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` —
  existing structural seam for model-owned architectural restrictions and
  negative tool proofs.
- `lib/src/contract/internal/snapshot_materialization.dart` —
  `sceneSnapshotFromValidatedBacking(...)` is the closest accepted local
  precedent for a validated carrier seam that upgrades a raw backing into
  validated-only materialization without owner-token semantics.
- `test/contract/validated_fast_path_contract_test.dart` — locks the validated
  snapshot-materialization seam against the remaining internal raw bypass.
- `lib/src/controller/scene_snapshot_materializer.dart` — the
  `PreparedSceneReplacement` boundary remains a secondary local precedent for
  nominal internal proof types when owner-token semantics are actually needed.
- `ARCHITECTURE.md` — the model layer owns import/build canonicalization and
  snapshot/runtime mapping, and validation/canonicalization happen before the
  supported public document result.
- `plan/step_7_import_boundary_diagnostic_surface.md` — `SceneImportDraft` and
  snapshot backing are already locked as canonical value carriers only, with
  transient import-path state kept out of carriers.
- `docs/adr/0001_target_engine_architecture.md` and
  `docs/adr/0002_post_target_optimization_scope.md` — accepted architecture
  work targets runtime-center ownership, not this model-layer seam, and
  rejects opportunistic broad redesign.

### Current Entry Path

- Typed snapshot builder:
  `SceneBuilder.buildFromSnapshot(...) -> sceneBuildFromSnapshot(...) ->
  sceneImportDraftFromSnapshot(...) -> sceneImportFromDraft(...) ->
  ScenePolicy.validateImportDraft(...) -> sceneFromImportDraft(...)`.
- Transaction-facing internal façade:
  `txnSceneFromSnapshot(...) -> sceneImportFromSnapshot(...) ->
  sceneImportFromDraft(...) -> ScenePolicy.validateImportDraft(...) ->
  sceneFromImportDraft(...)`.
- Direct bypass:
  `sceneFromSnapshot(...) -> sceneImportDraftFromSnapshot(...) ->
  sceneFromImportDraft(...)`.
- Canonical snapshot validation:
  `sceneCanonicalizeAndValidateSnapshot(...)` and
  `ScenePolicy.validateImportSnapshot(...) ->
  sceneImportDraftFromSnapshot(...) -> ScenePolicy.validateImportDraft(...) ->
  sceneSnapshotFromValidatedImportDraft(...)`.

### Current Owner

- The defect belongs to the model-layer scene import spine across
  `scene_from_snapshot.dart`, `scene_from_import_draft.dart`,
  `scene_policy.dart`, and `scene_import_draft.dart`.

### Adjacent Abstractions

- `lib/src/model/scene_builder.dart` — raw snapshot/json import façades.
- `lib/src/model/document.dart` — transaction-facing model façade.
- `lib/src/model/scene_validation_path_surface.dart` — transient call-time
  import configuration precedent that does not live on carriers.
- `lib/src/model/scene_snapshot_from_scene.dart` — export-side scene/snapshot
  mapping owner.

### Existing Tests

- `test/model/scene_builder_test.dart` — current builder/policy import-spine
  coverage and current `sceneFromSnapshot(...)` happy-path wrapper coverage.
- `test/model/document_model_test.dart` — transaction scene import coverage for
  neighboring invalid inputs.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` —
  negative structural scenarios for model architecture boundaries.

### Analogous Implementation Path

- `lib/src/contract/internal/snapshot_materialization.dart` — closest accepted
  precedent for keeping a raw carrier plus a validated-only materialization
  seam, without introducing transfer-ownership or single-consumption tokens.

### Governing Repository Rules

- `AGENTS.md` — fix repeated defects at the owning layer, prefer
  repository-local enforcement for stable constraints, and do not add new
  general-purpose logic buckets.
- `ARCHITECTURE.md` — the model layer owns import/build canonicalization,
  validation happens before the supported document result, and runtime-scene
  materialization remains engine-owned.
- `plan/step_7_import_boundary_diagnostic_surface.md` — `SceneImportDraft` and
  snapshot backing remain canonical value carriers only; transient import-path
  state must stay out of carriers.
- `tool/invariant_registry.dart` — the current surrounding contracts already
  include `INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY`,
  `INV-ENG-RUNTIME-SCENE-STRUCTURE-OWNER`, and
  `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY`.

### Rejected Misleading Local Patterns

- `lib/src/model/scene_from_snapshot.dart` direct delegation from
  `sceneFromSnapshot(...)` to the pure materializer — symptom-level local
  helper that leaves the raw-vs-validated precondition implicit.
- `lib/src/contract/internal/node_boundary_schema_snapshot.dart` and public
  snapshot constructors — wrong owner for scene-range ceilings and wrong
  `ArgumentError` vs `SceneDataException` boundary.
- Storing validation state or path provenance on `SceneImportDraft` — violates
  the existing carrier-only rule from Step 7.
- Copying scene-range checks into decode owners — duplicates policy across
  decode and validation owners.
- Broadening this step into node/spec/runtime boundary redesign — wider than
  the inspected defect and not justified by current evidence.
- Adding a new general-purpose import gateway/service — duplicates existing
  model owners and cuts against the accepted architecture direction.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Model-layer raw scene import materialization preconditions for the internal
  `SceneSnapshot` / `SceneImportDraft -> Scene` boundary.

#### Selected Architectural Form

- Introduce one opaque internal proof type,
  `ValidatedSceneImportDraft`, between raw `SceneImportDraft` and any
  runtime/canonical materialization.
- `ScenePolicy.validateImportDraft(...)` becomes the only upgrader from raw
  `SceneImportDraft` to `ValidatedSceneImportDraft`.
- `scene_from_import_draft.dart` keeps the raw convenience entry
  `sceneImportFromDraft(...)` but retires the raw pure-materializer seam in
  favor of `sceneFromValidatedImportDraft(...)`.
- `sceneSnapshotFromValidatedImportDraft(...)` consumes the same validated
  proof type as the runtime materializer.
- `scene_from_snapshot.dart` keeps one raw snapshot façade,
  `sceneImportFromSnapshot(...)`, and retires the sibling raw bypass helper
  `sceneFromSnapshot(...)`.
- All model-owned raw snapshot/json/document import entrypoints route through
  `ScenePolicy.validateImportDraft(...)` before runtime scene materialization
  or canonical snapshot export from draft.

#### Owning Layer or Module

- `lib/src/model/scene_import_draft.dart` owns the raw carrier and validated
  proof wrappers.
- `lib/src/model/scene_policy.dart` owns the raw-to-validated upgrade.
- `lib/src/model/scene_from_import_draft.dart` owns validated-only runtime
  materialization.
- `lib/src/model/scene_from_snapshot.dart` owns the single raw snapshot façade.

#### Dependency Direction

- Raw snapshot/json entrypoints produce `SceneImportDraft`.
- `ScenePolicy.validateImportDraft(...)` upgrades the raw draft into
  `ValidatedSceneImportDraft`.
- Only the validated proof flows into
  `sceneFromValidatedImportDraft(...)` or
  `sceneSnapshotFromValidatedImportDraft(...)`.
- `scene_builder.dart`, `document.dart`, and serialization façades continue to
  depend on model façades, not on raw materializer internals.

#### State and Data Ownership

- `SceneImportDraft`, `SceneSnapshotBacking`, and node backing types remain
  canonical raw carriers only; they do not store validation status, diagnostic
  surface, or provenance.
- `ValidatedSceneImportDraft` owns only the proof that full import policy ran;
  it may wrap the same underlying draft/backing without duplicating document
  state.
- No owner token or single-consumption state is introduced for this seam; the
  missing contract is validation proof, not transfer ownership or lifetime.

#### Entry and Exit Boundaries

- Raw draft creation remains allowed at
  `sceneImportDraftFromSnapshot(...)`,
  `sceneBuilderDecodeImportDraftFromJson(...)`, and future model-owned import
  sources.
- Raw snapshot/draft façades remain allowed at
  `sceneImportFromSnapshot(...)`,
  `sceneImportFromDraft(...)`,
  `sceneBuildFromSnapshot(...)`,
  `sceneBuildFromJsonMap(...)`,
  `sceneCanonicalizeAndValidateSnapshot(...)`,
  `ScenePolicy.validateImportSnapshot(...)`,
  `ScenePolicy.validateRuntimeScene(...)`, and
  `ScenePolicy.validateEncodeScene(...)`.
- Only `sceneFromValidatedImportDraft(...)` and
  `sceneSnapshotFromValidatedImportDraft(...)` may materialize output from a
  draft-stage value.

#### Permitted Extension Seam

- New model-owned import sources may produce raw `SceneImportDraft` values and
  pass them through `ScenePolicy.validateImportDraft(...)`.
- New import policy rules extend validation owners under
  `scene_value_validation*.dart` and remain upstream of the validated
  materialization seam.
- Future scene-level raw façades may compose `sceneImportFromDraft(...)`; they
  must not call the validated-only materializer without a
  `ValidatedSceneImportDraft`.

#### Rejected Alternatives

- Keep `sceneFromSnapshot(...)` and only delegate it to
  `sceneImportFromSnapshot(...)` — removes the current symptom but leaves the
  raw-vs-validated materialization contract implicit at the lower seam.
- Push scene-range policy into snapshot schema constructors or
  `validateNodeDirectionalCommonSchemaFields(...)` — wrong owner level and
  wrong public failure contract.
- Store a `validated` flag or path provenance on `SceneImportDraft` — violates
  the carrier-only rule already locked by Step 7.
- Introduce owner-token or single-use semantics like
  `PreparedSceneReplacement` — unnecessary for a model-local validation proof
  with no transfer-lifetime problem.
- Add a new general-purpose import manager/service — extra bucket that
  duplicates existing model owners and conflicts with the accepted target
  architecture.

#### Why This Level Is Correct

- The defect is wholly inside `model/**`, and the current checked-in
  architecture already assigns import/build canonicalization and
  snapshot/runtime mapping to that layer.
- The accepted ADR work targets the runtime center, not this seam, so a local
  model-layer correction is the smallest complete fix.
- The repository already distinguishes raw carriers from validated
  construction; this change finishes that distinction at the scene import
  boundary instead of inventing a new pattern.
- A nominal validated proof type plus one raw snapshot façade removes the drift
  once at the owner boundary and makes reintroduction mechanically visible.

## 5. Locked Decisions

1. The validated proof type is named `ValidatedSceneImportDraft` and lives in
   `lib/src/model/scene_import_draft.dart` beside `SceneImportDraft`; this
   step does not create a separate wrapper file.
2. `ScenePolicy.validateImportDraft(...)` returns
   `ValidatedSceneImportDraft`, and all draft-to-output conversions occur only
   after this upgrade point.
3. The pure runtime materializer is renamed to
   `sceneFromValidatedImportDraft(...)`, and the scene-policy callback typedef
   in `scene_policy.dart` is renamed to match the validated seam.
4. `sceneSnapshotFromValidatedImportDraft(...)` is updated to accept
   `ValidatedSceneImportDraft`, keeping runtime materialization and canonical
   snapshot export on the same proof stage.
5. `sceneFromSnapshot(...)` is removed rather than kept as a delegating alias;
   `sceneImportFromSnapshot(...)` becomes the single raw snapshot-to-scene
   façade.
6. This step does not change `txnNodeFromSnapshot(...)`,
   `txnNodeFromSpec(...)`, or node-level boundary mapping because the inspected
   defect and requested contract are scene-import specific.
7. The structural backstop is an updated model-architecture guardrail plus
   invariant coverage, not public-surface rules or runtime-center architecture
   tests.

## 6. Result Requirements

1. Every raw `SceneSnapshot -> Scene` import inside model and transaction
   façades applies the same structure, value, and range policy before runtime
   scene materialization.
2. No model-owned pure scene materializer accepts `SceneImportDraft`; raw
   drafts must be upgraded through `ScenePolicy.validateImportDraft(...)`
   first.
3. Canonical snapshot export from import drafts and runtime scene
   materialization share the same validated proof stage.
4. Reintroducing a sibling raw snapshot helper or a raw-draft pure materializer
   causes structural proof failure.
5. Public builder/codec behavior and the diagnostic-path contract from Step 7
   remain unchanged.

## 7. Execution Order and Gates

### Required Order

- Add the behavioral reproducer and neighboring guard tests first.
- Add the structural negative proof for the architectural seam before owner-side
  implementation.
- Introduce `ValidatedSceneImportDraft` and migrate
  `scene_policy.dart`, `scene_from_import_draft.dart`, and raw façades to the
  successor seam.
- Migrate remaining in-scope model callers and tests.
- Retire `sceneFromSnapshot(...)` only after the replacement regression has
  moved, consumers are updated, and guardrails, invariant coverage, and
  architecture documents have moved.

### Successor Seam and Retirement Gates

- `sceneFromValidatedImportDraft(...)` and
  `sceneSnapshotFromValidatedImportDraft(...)` are the successor validated-only
  seams; the retirement gate for `sceneFromSnapshot(...)` is zero in-repo
  references plus a green guardrail negative scenario that rejects its
  reintroduction.
- The Slice 1 defect reproducer is intentionally anchored to the current
  `sceneFromSnapshot(...)` bypass. Before `sceneFromSnapshot(...)` is deleted
  in Slice 3, that reproducer must be retargeted to the surviving raw snapshot
  façade coverage in `sceneImportFromSnapshot(...)` and
  `txnSceneFromSnapshot(...)`; the helper-specific assertion may be removed
  only in the same change that adds the replacement regression and proves it
  green.
- `tool/invariant_registry.dart`,
  `tool/check_guardrails.dart`,
  `tool/src/guardrails/rules/model/model_architecture_rules.dart`, and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` must
  reflect the validated import contract before the old seam is considered
  retired.
- `ARCHITECTURE.md` must be updated in the same change that retires the bypass
  so the contract does not live only in chat and tests.

### Deferred Broad Verification

- Full changed-path verification via
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`
  is reserved for the final gate after all slice-local model and tool tests are
  green.
- Tool-test execution remains sequential with the required preset; do not
  overlap `dart run tool/run_tool_tests.dart ...` with other heavyweight runs.

## 8. File Map

### Implementation Files

- `lib/src/model/scene_import_draft.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_from_import_draft.dart`
- `lib/src/model/scene_from_snapshot.dart`
- `lib/src/model/scene_builder.dart`

### Test Files

- `test/model/scene_builder_test.dart`
- `test/model/document_model_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

### Fixtures and Supporting Data

- None.

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_8_validated_import_materialization_boundary.md`
- `ARCHITECTURE.md`
- `tool/check_guardrails.dart`
- `tool/check_invariant_coverage.dart`
- `tool/invariant_registry.dart`
- `tool/run_tool_tests.dart`
- `tool/run_verification_preset.dart`

### Analysis Area

- `tool/src/guardrails/rules/model/model_architecture_rules.dart`

## 9. Implementation Rules

### Protected Invariants

- `SceneImportDraft` remains a canonical raw carrier and does not store
  validation state or diagnostic provenance.
- Full scene import policy is applied once before any raw-draft runtime
  materialization or canonical snapshot export from draft.
- Raw scene snapshot import has one model-owned façade and no sibling bypass
  helper.
- Downstream non-model code continues to use canonical model façades only.
- Register `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY` in
  `tool/invariant_registry.dart` with exactly one required proof
  (`tool/check_guardrails.dart`, `stepId: 'guardrails'`) and exactly one
  regression proof
  (`test/tool/guardrails/guardrails_model_architecture_tool_test.dart`).
- Add matching `// INV:INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY`
  markers in the invariant header block of `tool/check_guardrails.dart` and in
  the opening `group('tool/check_guardrails.dart', ...)` block of
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`.
- The invariant registry entry stays structural-only; the behavioral bypass
  regressions in `test/model/scene_builder_test.dart` and
  `test/model/document_model_test.dart` remain ordinary regression tests, not
  invariant proof surfaces.

### Required Proof

- behavioral proof:
  `test/model/scene_builder_test.dart` must first reproduce the current
  `sceneFromSnapshot(...)` out-of-range transform bypass, and then lock
  neighboring guards for the same import contract in
  `test/model/scene_builder_test.dart` and
  `test/model/document_model_test.dart`; when Slice 3 retires
  `sceneFromSnapshot(...)`, the durable regression must move to the surviving
  raw snapshot façades rather than disappearing with the helper.
- structural proof:
  `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
  must cover negative scenarios that reintroduce `sceneFromSnapshot(...)` or a
  raw `SceneImportDraft` pure materializer, and `tool/invariant_registry.dart`
  must register `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY` with
  `requiredProofs: [RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails')]`
  and
  `regressionProofs: [RegressionProof(path: 'test/tool/guardrails/guardrails_model_architecture_tool_test.dart')]`,
  with matching `// INV:` markers in both declared proof files;
  `dart run tool/check_guardrails.dart` and
  `dart run tool/check_invariant_coverage.dart` must accept the updated rule,
  registry entry, and markers without adding any new verification step or
  preset wiring.
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard
  tests for neighboring branches of the same contract.

### Allowed Change Surface

- The model import spine files listed in section 8.
- Direct regression tests for that spine.
- `tool/check_guardrails.dart`, the model architecture guardrail rule, and its
  negative tool tests.
- `tool/invariant_registry.dart`, `ARCHITECTURE.md`, and plan files required to
  keep the new contract repository-visible.

### Forbidden Moves

- Any public API rename or new public export.
- Any schema/version change or diagnostic-path rename.
- Any validation state, source-path provenance, or mutable flags stored on
  `SceneImportDraft` or snapshot backing carriers.
- Any duplication of scene-range policy inside decode owners or schema
  constructors.
- Any node/spec/runtime seam redesign or runtime-center architecture work.
- Any new general-purpose import coordinator/service.

### Optional: Recognition Forms That Must Be Supported

- The model guardrail must recognize a top-level `sceneFromSnapshot(...)`
  declaration in `lib/src/model/scene_from_snapshot.dart` as a reintroduced raw
  snapshot bypass.
- The model guardrail must recognize a pure scene materializer in
  `lib/src/model/scene_from_import_draft.dart` that accepts `SceneImportDraft`
  instead of `ValidatedSceneImportDraft` as an architectural violation.

### Optional: Allowed Forms That Are Not Violations

- `sceneImportFromDraft(SceneImportDraft rawDraft, ...)` validating raw drafts
  before delegation.
- `sceneFromValidatedImportDraft(ValidatedSceneImportDraft draft, ...)` pure
  runtime materialization after proof.
- `sceneSnapshotFromValidatedImportDraft(ValidatedSceneImportDraft draft)` as
  export from the same proof stage.

### Optional: Resolution Rules

- When a caller holds a raw snapshot or raw draft, route through
  `sceneImportFromSnapshot(...)` or `sceneImportFromDraft(...)`.
- When a caller already holds `ValidatedSceneImportDraft`, route directly to
  `sceneFromValidatedImportDraft(...)` or
  `sceneSnapshotFromValidatedImportDraft(...)`.

## 10. Vertical Slices

### Slice 1. [ ] Lock the scene snapshot bypass regression

#### Slice Contract

Lock the current defect and its immediate neighboring branches with one failing
behavioral reproducer and one failing structural negative scenario before any
owner-side implementation changes.

#### Change

- Add a failing transitional reproducer in `test/model/scene_builder_test.dart`
  proving that `sceneFromSnapshot(...)` currently accepts a typed snapshot
  whose transform exceeds scene import ceilings.
- Add 1 to 3 neighboring guard tests for the same contract in
  `test/model/scene_builder_test.dart` and
  `test/model/document_model_test.dart`.
- Add failing negative guardrail scenarios in
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart` for
  reintroducing `sceneFromSnapshot(...)` or a raw-draft pure materializer.

#### Behavioral Verification

- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/model/document_model_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

#### Fixtures Used

- Existing internal snapshot-bypass helpers in the model tests.
- Existing guardrail sandbox support used by the model architecture tool tests.

#### Positive Scenarios

- Existing happy-path snapshot import coverage remains in place while the new
  regression tests are added.

#### Negative Scenarios

- `sceneFromSnapshot(...)` must reject the same out-of-range transform payload
  that the canonical builder path already rejects.
- Guardrail fixtures that reintroduce `sceneFromSnapshot(...)` or a raw-draft
  pure materializer must fail.

#### Closure Evidence

- The new transitional behavioral reproducer fails on the current code.
- The new structural negative scenarios fail on the current guardrail set.

### Slice 2. [ ] Introduce the validated import proof seam

#### Slice Contract

Replace raw-draft pure scene materialization with a validated-only seam and
migrate all in-scope model import owners to that seam.

#### Change

- Add `ValidatedSceneImportDraft` in `scene_import_draft.dart`.
- Change `ScenePolicy.validateImportDraft(...)` to return the validated proof.
- Rename the pure materializer to `sceneFromValidatedImportDraft(...)` and
  update `sceneSnapshotFromValidatedImportDraft(...)` to consume the same proof
  type.
- Migrate `scene_builder.dart`, `scene_policy.dart`, and
  `scene_from_snapshot.dart` to the successor seam.

#### Behavioral Verification

- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/model/document_model_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

#### Fixtures Used

- Model import regression fixtures from Slice 1.
- Guardrail sandbox fixtures from Slice 1.

#### Positive Scenarios

- Builder, policy, transaction, and snapshot façades accept valid snapshots and
  preserve existing instance-revision behavior.
- A validated import proof can materialize both a runtime scene and a canonical
  snapshot from the same upstream validation result.

#### Negative Scenarios

- Out-of-range transform snapshots are rejected across
  `sceneImportFromSnapshot(...)`, `txnSceneFromSnapshot(...)`, and the builder
  path.
- Raw `SceneImportDraft` values cannot cross the pure materialization seam.

#### Closure Evidence

- No pure scene materializer accepts `SceneImportDraft`.
- All in-scope model import callers compile and pass the locked tests.

### Slice 3. [ ] Retire the bypass helper and publish the invariant

#### Slice Contract

Remove the redundant raw snapshot bypass symbol and register the validated
import boundary as repository source of truth.

#### Change

- Retarget the Slice 1 transitional reproducer from
  `sceneFromSnapshot(...)` to the surviving raw snapshot façades
  (`sceneImportFromSnapshot(...)` and `txnSceneFromSnapshot(...)`) before the
  old helper is deleted.
- Delete `sceneFromSnapshot(...)` and update remaining internal references.
- Register `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY` in
  `tool/invariant_registry.dart` with
  `requiredProofs: [RequiredProof(path: 'tool/check_guardrails.dart', stepId: 'guardrails')]`
  and
  `regressionProofs: [RegressionProof(path: 'test/tool/guardrails/guardrails_model_architecture_tool_test.dart')]`.
- Add `// INV:INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY` markers to
  `tool/check_guardrails.dart` and
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`.
- Update the model guardrail wording/cases and `ARCHITECTURE.md` to describe
  the validated import seam.

#### Behavioral Verification

- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/model/document_model_test.dart`

#### Structural Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `tool/check_invariant_coverage.dart` must accept the new invariant entry
  under the existing `required_code_change` contour without new verification
  scope or preset wiring.

#### Fixtures Used

- Guardrail sandbox fixtures.

#### Positive Scenarios

- `sceneImportFromSnapshot(...)` remains the single raw snapshot façade used by
  model/transaction callers.
- The checked-in architecture documents describe one validated import
  materialization path.

#### Negative Scenarios

- Reintroducing `sceneFromSnapshot(...)` or a raw-draft pure materializer trips
  structural proof.

#### Closure Evidence

- There are zero in-repo references to `sceneFromSnapshot(...)`.
- The transitional `sceneFromSnapshot(...)` reproducer is gone only because an
  equivalent green regression now covers `sceneImportFromSnapshot(...)` and
  `txnSceneFromSnapshot(...)`.
- The invariant registry, direct guardrail check, invariant-coverage check,
  regression proof, and architecture doc all describe the same validated
  import seam.

## 11. Final Verification

- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/model/document_model_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- The model layer has one raw `SceneSnapshot -> Scene` façade and no sibling
  snapshot bypass helper.
- Pure scene materialization from import draft accepts only
  `ValidatedSceneImportDraft`.
- Builder, policy, and transaction scene import paths reject the same
  out-of-range transform payload with the existing `SceneDataException`
  contract.
- `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY`, the model guardrail
  proof, and `ARCHITECTURE.md` all describe and enforce the same seam.
