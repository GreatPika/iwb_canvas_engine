language: russian

# Change Contract

## 1. Change Mandate

Этот шаг завершает scene-document architecture sequence after steps `87-90`:
финальная модель `public document / runtime metadata / internal draft-import`
must be described consistently in repo source-of-truth docs, pinned by
invariants and guardrails, and reflected in the roadmap so the new architecture
stops living as distributed chat context and becomes mechanically enforced
repository knowledge.

## 2. Change Boundary

### Included in the Change

- Final source-of-truth alignment for the scene-document architecture in:
  `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `PLAN.md`,
  steps `87-91`.
- Invariant closure in `tool/invariant_registry.dart` for the final
  scene-document contract wording introduced by steps `87-90`.
- Mechanical guardrail closure in
  `tool/src/guardrails/model_architecture_guardrails.dart` so downstream
  non-model code cannot import the new internal draft/import owner modules
  directly.
- Tool regression coverage for the new model-architecture restriction in
  `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`.
- Proof-marker and proof-wording alignment in the existing proof files that
  declare the final scene-document architecture:
  `test/public_api/validated_boundary_value_test.dart`,
  `test/public_api/scene_builder_test.dart`.

### Not Included in the Change

- Any reopening of production owner changes from steps `87-90`.
- Any new runtime behavior for snapshot construction, import, encode/decode,
  runtime metadata writes, or render/view handling.
- Any new public API type, new JSON schema change, or new compatibility bridge.
- Any new standalone closure tool outside the existing
  `check_guardrails.dart` and `check_invariant_coverage.dart` pipelines.
- Any broad rewrite of existing tool architecture beyond the targeted
  model-guardrail adaptation required by this closure.

## 3. File Map and Analysis Areas

### Implementation Files

- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `PLAN.md`
- `tool/invariant_registry.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`

### Test Files

- `test/public_api/validated_boundary_value_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`

### Fixture and Supporting Data Files

- `plan/step_87_remove_stroke_points_revision_from_public_snapshot_boundary.md`
- `plan/step_88_internal_scene_import_draft_layer.md`
- `plan/step_89_scene_snapshot_global_validity_by_construction.md`
- `plan/step_90_shared_scene_metadata_value_contract_alignment.md`
- `plan/step_91_scene_document_architecture_closure.md`

### Analysis Area

- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `PLAN.md`
- `tool/invariant_registry.dart`
- `tool/check_guardrails.dart`
- `tool/check_invariant_coverage.dart`
- `tool/src/guardrails/model_architecture_guardrails.dart`
- `test/public_api/**`
- `test/tool/guardrails/**`
- `test/tool/support/**`
- `plan/step_87*.md`
- `plan/step_88*.md`
- `plan/step_89*.md`
- `plan/step_90*.md`
- `plan/step_91*.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified documentation file must either describe the final
  scene-document architecture or remove stale pre-step-`87-90` wording.
- Every modified guardrail or tool-test file must pin one structural rule of
  the final `public document / internal draft-import` architecture.
- Every modified proof file must be tied to an invariant title or proof-marker
  alignment required by this closure.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Steps `87-90` define the final production owner graph for this sequence;
   step `91` does not reopen them as its main subject.
2. `StrokeNode.pointsRevision` remains runtime-only metadata and must not
   return to the public snapshot or JSON boundary.
3. Ordinary public `SceneSnapshot(...)` remains globally structurally valid by
   construction; malformed public snapshots remain internal-only.
4. `SceneImportDraft` remains a model-internal pre-canonical import carrier;
   public callers still construct, pass, and receive only `SceneSnapshot`
   values.
5. Shared scene-metadata validation remains one eager contract across public
   constructors, runtime owners, typed import, and JSON decode.
6. The closure must be pinned through the existing
   `tool/check_guardrails.dart` and `tool/check_invariant_coverage.dart`
   pipelines; a separate closure-only tool is not introduced.
7. `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY` remains the structural invariant owner
   for downstream import restrictions on model-internal owner modules; this
   step extends that invariant instead of introducing a parallel structural
   guardrail family for the same rule.
8. `CHANGELOG.md` remains untouched in this step; the user-visible behavior of
   steps `87-90` is already recorded and is not reopened by this closure.

## 5. Result Requirements

1. `README.md`, `API_GUIDE.md`, and `ARCHITECTURE.md` describe one consistent
   scene-document architecture:
   public `SceneSnapshot` as the canonical document boundary,
   runtime-only stroke revision metadata,
   internal-only `SceneImportDraft`,
   globally valid ordinary public snapshots,
   and one shared eager scene-metadata contract.
2. `PLAN.md` and step documents `87-91` describe one consistent migration
   sequence with no stale references to public `pointsRevision`, public invalid
   `SceneSnapshot` construction, or late-only scene-metadata validation.
3. `tool/src/guardrails/model_architecture_guardrails.dart` fails when
   non-model production code imports
   `scene_import_draft.dart`,
   `scene_import_draft_from_snapshot.dart`,
   or `scene_from_import_draft.dart` directly instead of using canonical model
   facades.
4. `tool/invariant_registry.dart` explicitly aligns the final scene-document
   architecture wording with:
   `INV-ENG-STROKE-RUNTIME-GEOMETRY-OWNER`,
   `INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY`,
   `INV-ENG-SHARED-SCENE-METADATA-CONTRACT`,
   and `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY`.
5. `dart run tool/check_guardrails.dart` and
   `dart run tool/check_invariant_coverage.dart` stay green with the updated
   docs, invariant wording, proof markers, and model-architecture restriction.
6. The tool regression matrix contains explicit negative coverage for the new
   draft/import module bans under `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `README.md`, `API_GUIDE.md`, and `ARCHITECTURE.md` already contain pieces of
  the post-step-`87-90` architecture, but those claims are spread across
  different sections and must be converged into one final source-of-truth
  contour.
- `ARCHITECTURE.md` currently still contains the pre-step-`90` wording
  "Ordinary `SceneImportDraft(...)` construction stays on validated backing
  builders", which becomes stale once validated backing builders become honest
  and raw draft assembly must stay explicit.
- `tool/invariant_registry.dart` already declares
  `INV-ENG-STROKE-RUNTIME-GEOMETRY-OWNER`,
  `INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY`,
  `INV-ENG-SHARED-SCENE-METADATA-CONTRACT`,
  and `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY`; closure work must align their
  titles and proof wording with the final scene-document architecture instead
  of creating parallel duplicate invariants.
- `tool/src/guardrails/model_architecture_guardrails.dart` currently restricts
  many internal model owner modules, but it does not yet list
  `scene_import_draft.dart`,
  `scene_import_draft_from_snapshot.dart`,
  or `scene_from_import_draft.dart`.
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
  currently covers many forbidden direct model imports, but it does not yet
  contain negative regression cases for the new draft/import owner modules;
  `test/tool/support/guardrails_tool_test_support.dart` remains the canonical
  sandbox helper surface that those regressions must continue to use.
- `CHANGELOG.md` already contains the user-visible behavior introduced by steps
  `87-90`; this closure step confirms that no additional changelog work is
  part of the closure.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
- MCP test runner: root `.` paths `test/public_api/validated_boundary_value_test.dart`
- MCP test runner: root `.` paths `test/public_api/scene_builder_test.dart`
- MCP test shard preset `core`
- MCP test shard preset `model_contract`
- MCP test shard preset `controller_internal`
- MCP test shard preset `controller`
- MCP test shard preset `render_view`
- MCP test shard preset `interactive`
- MCP test shard preset `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- The production owner graph introduced by steps `87-90`.
- The existing public API and JSON schema.
- Existing user-visible behavior already recorded under `## Unreleased` in
  `CHANGELOG.md`.
- The existing `check_guardrails.dart` runner and the existing invariant
  registry coverage contract.

### 6.4 Allowed Semantic Change Zones

- Source-of-truth documentation and roadmap wording.
- Invariant titles, proof ownership, and proof-marker alignment.
- Model-architecture guardrail restrictions for internal draft/import owners.
- Tool regression tests that prove the new model guardrail restriction.

### 6.8 Prohibited

- Reopening or redesigning the production architecture from steps `87-90`.
- Introducing new runtime or public behavior under the guise of closure.
- Leaving draft/import internal-only rules as prose-only knowledge after this
  step is closed.
- Duplicating the same architectural rule across multiple new invariants when
  an existing invariant owner already covers that rule.
- Keeping stale roadmap/doc wording that still describes public
  `pointsRevision`, public invalid `SceneSnapshot` construction, or
  scene-metadata late-only validation as accepted behavior.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice updates invariant wording, the corresponding proof markers or
   declared proof files must be updated in the same slice.
7. If a slice adds a new guardrail restriction, the same slice must add at
   least one negative tool regression for that restriction.
8. Scope expansion into new production behavior is forbidden until the
   mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] Draft/Import Structural Guardrail Closure

#### Slice Contract

The internal draft/import layer is mechanically protected: downstream
non-model production code cannot import `scene_import_draft.dart`,
`scene_import_draft_from_snapshot.dart`, or `scene_from_import_draft.dart`
directly.

#### Change

Extend `tool/src/guardrails/model_architecture_guardrails.dart` so the
restricted model owner module set includes the three draft/import owner files
introduced by steps `88-90`, and add matching negative regressions in
`test/tool/guardrails/guardrails_model_architecture_tool_test.dart`. Align
`INV-ENG-MODEL-ARCHITECTURE-BOUNDARY` wording in
`tool/invariant_registry.dart` so the invariant explicitly covers the
draft/import owner restriction.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

#### Positive Scenarios

- Existing canonical model facades continue to pass the model architecture
  guardrail.
- Model-owned files may continue to use the internal draft/import owners where
  the architecture already requires them.

#### Negative Scenarios

- Non-model production code importing `scene_import_draft.dart` fails the
  guardrail.
- Non-model production code importing `scene_import_draft_from_snapshot.dart`
  fails the guardrail.
- Non-model production code importing `scene_from_import_draft.dart` fails the
  guardrail.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 2. [ ] Invariant And Proof Contour Closure

#### Slice Contract

The final scene-document architecture is represented coherently in the
invariant registry and its declared proof surfaces, without duplicate or stale
invariant wording.

#### Change

Update `tool/invariant_registry.dart` so the final wording for
`INV-ENG-STROKE-RUNTIME-GEOMETRY-OWNER`,
`INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY`,
`INV-ENG-SHARED-SCENE-METADATA-CONTRACT`,
and `INV-ENG-MODEL-ARCHITECTURE-BOUNDARY` matches the final architecture from
steps `87-90`. Add or adjust proof markers in
`test/public_api/validated_boundary_value_test.dart`,
`test/public_api/scene_builder_test.dart`,
and `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
so the declared proof surfaces stay exact.

#### Verification

- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: root `.` paths `test/public_api/validated_boundary_value_test.dart`
- MCP test runner: root `.` paths `test/public_api/scene_builder_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`

#### Positive Scenarios

- Public proof files still prove ordinary `SceneSnapshot(...)` global validity
  and the shared scene-metadata contract.
- Tool proof files still prove the model architecture boundary after the new
  draft/import restriction is added.

#### Negative Scenarios

- `check_invariant_coverage` fails if the final invariant wording points to
  proof files without matching markers.
- The slice stays open if the registry still describes any pre-step-`87-90`
  contract as current behavior.

#### Closure Evidence

- Green run of the listed verifications.

### Slice 3. [ ] Source-Of-Truth Docs And Roadmap Closure

#### Slice Contract

Repository docs and roadmap describe one final scene-document architecture and
contain no stale wording that contradicts steps `87-90`.

#### Change

Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, `PLAN.md`, and step
documents `87-91` so they describe the same final architecture:
public `SceneSnapshot` as canonical and globally valid,
runtime-only `pointsRevision`,
internal-only `SceneImportDraft`,
one shared eager scene-metadata contract,
and explicit internal-only raw malformed snapshot/metadata assembly.
`CHANGELOG.md` is not modified in this slice.

#### Verification

- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner: root `.` paths `test/public_api/validated_boundary_value_test.dart`
- MCP test runner: root `.` paths `test/public_api/scene_builder_test.dart`

#### Positive Scenarios

- README, API guide, architecture guide, and roadmap all describe the same
  public/runtime/import split.
- Roadmap documents `87-91` read as one continuous migration without
  contradicting owner statements.

#### Negative Scenarios

- The slice stays open if any source-of-truth doc still presents public
  `pointsRevision`, public invalid `SceneSnapshot` construction, or
  scene-metadata late-only validation as accepted behavior.
- The slice stays open if roadmap docs disagree on whether draft/import state
  is public or internal.

#### Closure Evidence

- Green run of the listed verifications.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_tool_test_trigger_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart`
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
