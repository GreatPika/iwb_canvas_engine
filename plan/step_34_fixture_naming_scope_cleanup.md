# Change Contract

## Goal

Close P6 handoff findings 4 and 7 by aligning checked-in fixture names, wrapper test names, guardrail proof paths, and active documentation references with the behavior those fixtures actually prove, without changing edit/runtime behavior or adding new coverage.

## Evidence

- `P6_HANDOFF_FINDINGS.md` / findings 4 and 7: records that `field_update_nullable_semantics_fixture.dart` is too narrow for its body and `document_summary_publication_fixture.dart` overclaims publication coverage -> the step scope is limited to fixture naming/scope cleanup for those two findings.
- `.research/2026-05-26-fixture-naming-scope-cleanup.md` / research note: records that finding 4's fixture covers multiple `CanvasEdit.updateElement` admission/effect outcomes and finding 7's fixture checks only initial runtime summary coherence against the document projection -> the implementation should rename surfaces rather than expand behavior.
- `test/edit/field_update_nullable_semantics_test.dart` / edit wrapper: runs `test/edit/fixtures/field_update_nullable_semantics_fixture.dart` by literal path -> wrapper filename, test name, and fixture path must move together.
- `test/edit/fixtures/field_update_nullable_semantics_fixture.dart` / edit fixture: tests nullable clear, dynamic non-nullable clear rejection, non-invertible transform rejection, update-kind mismatch rejection, geometry revision effects, and selection pruning -> the durable name should describe field-update admission/effects, not only nullable semantics.
- `tool/guardrails/src/guardrail_executor.dart` / guardrail proof paths: `edit.operation_matrix_complete` includes `test/edit/field_update_nullable_semantics_test.dart` -> the guardrail proof path must be updated with the edit test rename.
- `docs/_registry/sections.yaml`, `docs/contracts/edit_kernel.md`, `docs/verification/tests.md`, and `docs/indexes/by_test_area.md` / active test-id references: the active docs source and generated docs name `test.edit.field_update_nullable_semantics` -> the edit test id and generated outputs must be updated when the proof is renamed.
- `test/runtime/document_summary_publication_test.dart` / runtime wrapper: runs `test/runtime/fixtures/document_summary_publication_fixture.dart` by literal path and its wrapper test says summary coherence with committed document facts -> wrapper filename, test name, and fixture path must move together.
- `test/runtime/fixtures/document_summary_publication_fixture.dart` / runtime fixture: constructs one runtime, reads the initial document projection, and compares resource/layer/element counts with `runtime.state.value.summary` -> the durable name should describe document/runtime summary coherence, not publication transitions.
- `test/runtime/runtime_state_publication_test.dart` and `test/runtime/fixtures/commit_effect_observer_fixture.dart` / publication coverage: existing tests cover initial public state, exactly-one state snapshot after edits, no-op non-publication, and observer delivery after state publication -> finding 7 does not require merging document summary coherence into publication transition coverage.

## Boundaries

Owner:

Fixture naming, wrapper tests, active test proof routing, active documentation registry/generated test references, `P6_HANDOFF_FINDINGS.md`, `PLAN.md`, and this linked step document.

In Scope:

- Rename `test/edit/field_update_nullable_semantics_test.dart` and `test/edit/fixtures/field_update_nullable_semantics_fixture.dart` to `field_update_admission_effects_test.dart` and `field_update_admission_effects_fixture.dart`.
- Rename the edit wrapper test description and fixture test descriptions only as needed to align with field-update admission/effects behavior already present.
- Update `tool/guardrails/src/guardrail_executor.dart` so `edit.operation_matrix_complete` runs the renamed edit test path.
- Update the active edit test id from `test.edit.field_update_nullable_semantics` to `test.edit.field_update_admission_effects` in `docs/_registry/sections.yaml` and dependent generated/checked docs.
- Rename `test/runtime/document_summary_publication_test.dart` and `test/runtime/fixtures/document_summary_publication_fixture.dart` to `document_summary_coherence_test.dart` and `document_summary_coherence_fixture.dart`.
- Rename the runtime wrapper test description and fixture test description only as needed to align with initial summary coherence behavior already present.
- Delete the resolved entries for findings 4 and 7 from `P6_HANDOFF_FINDINGS.md` after the executable and documentation checks prove the cleanup.
- Mark Step 34 complete in `PLAN.md` and this linked step document only after all required checks pass.

Out of Scope:

- Changing edit runtime behavior, runtime state publication behavior, committed store behavior, public APIs, schemas, guardrail semantics, or operation-matrix taxonomy.
- Adding new field-update cases, summary transition cases, publication tests, or merging the document summary coherence proof into `test/runtime/runtime_state_publication_test.dart`.
- Rewriting completed historical plan step files only to replace old paths or old test ids.
- Resolving P6 handoff findings 3 or 5.

Source of Truth:

- Remaining handoff inventory until resolved: `P6_HANDOFF_FINDINGS.md`.
- Roadmap entry and execution state: `PLAN.md` and this linked step document.
- Active documentation test ids and generated docs inputs: `docs/_registry/sections.yaml`; generated docs must be synchronized by `docs/tool/sync_generated_docs.dart`.
- Guardrail test execution routing: `tool/guardrails/src/guardrail_executor.dart`.
- Fixture behavior source: the renamed test and fixture files under `test/edit/**` and `test/runtime/**`.

Compatibility:

- Public API signatures, data formats, runtime behavior, and guardrail ids must not change.
- `edit.operation_matrix_complete` must continue to execute the same edit proof behavior through the renamed path.
- Historical completed plan files may continue to contain old file paths or old test ids as historical records.
- The runtime summary coherence proof remains an in-package public-runtime fixture and does not become a publication-transition proof.

Order Constraints:

1. Rename the edit fixture surface and update its active consumers before changing active docs test ids.
2. Rename the runtime summary fixture surface after the edit proof path is stable; do not merge it into runtime publication coverage.
3. Synchronize generated docs after source registry/docs edits.
4. Update `P6_HANDOFF_FINDINGS.md`, `PLAN.md`, and this step file completion markers only after focused tests and required repository checks pass.

## Execution Units

### [ ] Unit 1: Field Update Admission/Effects Fixture Rename

Owner:

`test/edit/**` owns the edit proof surface; `tool/guardrails/src/guardrail_executor.dart` owns guardrail proof routing for edit tests; `docs/_registry/sections.yaml` owns the active edit test id source.

Boundary:

Only the field-update nullable semantics wrapper/fixture paths, the `edit.operation_matrix_complete` guardrail proof path, active docs registry/generated references to the edit test id/path, and test descriptions needed to match the renamed scope.

Change:

Rename `test/edit/field_update_nullable_semantics_test.dart` to `test/edit/field_update_admission_effects_test.dart` and `test/edit/fixtures/field_update_nullable_semantics_fixture.dart` to `test/edit/fixtures/field_update_admission_effects_fixture.dart`. Update the wrapper's literal fixture path, wrapper test description, and any fixture test/group descriptions that still imply nullable-only scope. Update `tool/guardrails/src/guardrail_executor.dart` to run the renamed edit test path. Rename the active docs test id to `test.edit.field_update_admission_effects` in `docs/_registry/sections.yaml` and synchronize/update dependent active docs references, including `docs/contracts/edit_kernel.md`, `docs/verification/tests.md`, and `docs/indexes/by_test_area.md`. Update the prose in `docs/verification/tests.md` so the renamed id describes the full field-update admission/effects scope: nullable clears, dynamic non-nullable clear rejection, non-invertible transform rejection, mismatched update-kind rejection, geometry revision effects, and selection pruning.

Completion Check:

`dart test test/edit/field_update_admission_effects_test.dart` passes; `dart run tool/guardrails/run.dart --dry-run --guardrail=edit.operation_matrix_complete` exits with code `0` and stdout includes `test/edit/field_update_admission_effects_test.dart`; `rg "field_update_nullable_semantics|test\\.edit\\.field_update_nullable_semantics" test/edit tool/guardrails/src docs/_registry docs/contracts docs/verification docs/indexes` returns no matches; `rg "field update nullable and rejected update semantics" test/edit` returns no matches; `rg "field update admission and effects" test/edit/field_update_admission_effects_test.dart test/edit/fixtures/field_update_admission_effects_fixture.dart` returns matches in both renamed files; `rg "test\\.edit\\.field_update_admission_effects" docs/_registry/sections.yaml docs/contracts/edit_kernel.md docs/verification/tests.md docs/indexes/by_test_area.md` returns matches in all four files; `rg "test/edit/field_update_admission_effects_test\\.dart" docs/verification/tests.md tool/guardrails/src/guardrail_executor.dart` returns matches in both files. The paragraph in `docs/verification/tests.md` that starts with `` `test.edit.field_update_admission_effects` covers`` contains all six phrases: `nullable clears`, `dynamic non-nullable clear`, `non-invertible transform`, `mismatched update-kind`, `geometry revision`, and `selection pruning`.

Depends On:

None.

### [ ] Unit 2: Document Summary Coherence Fixture Rename

Owner:

`test/runtime/**` owns the runtime document summary coherence proof surface.

Boundary:

Only the document summary publication wrapper/fixture paths and test descriptions needed to match the existing initial summary coherence behavior.

Precondition:

Before Unit 2 starts, `git status --short -- test/runtime/runtime_state_publication_test.dart test/runtime/fixtures/commit_effect_observer_fixture.dart` must return no output. If either publication-transition coverage file already has staged or unstaged local changes, stop and report the conflict instead of using those files to absorb the document summary coherence proof.

Change:

Rename `test/runtime/document_summary_publication_test.dart` to `test/runtime/document_summary_coherence_test.dart` and `test/runtime/fixtures/document_summary_publication_fixture.dart` to `test/runtime/fixtures/document_summary_coherence_fixture.dart`. Update the wrapper's literal fixture path, wrapper test description, and fixture test description so they describe runtime/document summary coherence with committed document facts or initial projection counts without implying publication transition coverage.

Completion Check:

`dart test test/runtime/document_summary_coherence_test.dart` passes; `rg "document_summary_publication" test/runtime` returns no matches; `rg "document summary publication|publication/coherence" test/runtime` returns no matches; `rg "document summary coherence" test/runtime/document_summary_coherence_test.dart test/runtime/fixtures/document_summary_coherence_fixture.dart` returns matches in both renamed files; `git status --short -- test/runtime/runtime_state_publication_test.dart test/runtime/fixtures/commit_effect_observer_fixture.dart` returns no output, proving the existing publication-transition coverage files were not used to absorb the renamed document summary coherence fixture.

Depends On:

Unit 1.

### [ ] Unit 3: Handoff Closure And Verification

Owner:

`P6_HANDOFF_FINDINGS.md` owns the temporary cleanup inventory; `PLAN.md` and this linked step document own roadmap completion state; repository verification commands own final proof for the changed Dart/test/tool/docs surfaces.

Boundary:

Only the resolved sections for findings 4 and 7 in `P6_HANDOFF_FINDINGS.md`, the Step 34 entry in `PLAN.md`, this step document's execution-unit checkboxes, and the required verification commands for the changed surfaces.

Change:

After Units 1 and 2 are complete and their focused tests pass, run required mixed code/docs verification from the repository root before changing `P6_HANDOFF_FINDINGS.md`, `PLAN.md`, or this step document's checkboxes:

- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics .`
- `dart test test/edit/field_update_admission_effects_test.dart test/runtime/document_summary_coherence_test.dart`
- `dart run docs/tool/sync_generated_docs.dart --check`
- `dart run docs/tool/check_docs.dart`

If generated docs are stale after the registry/test-id rename, run `dart run docs/tool/sync_generated_docs.dart`, review the generated diff, and rerun both documentation checks. After all commands in this unit pass, delete only the handoff entries for findings 4 and 7 from `P6_HANDOFF_FINDINGS.md`. Preserve unresolved findings 3 and 5. Then mark Step 34 complete in `PLAN.md` and mark this step document's execution-unit checkboxes complete in the same implementation change.

Completion Check:

All commands listed in this unit pass in the repository root before `P6_HANDOFF_FINDINGS.md`, `PLAN.md`, or this step document's checkboxes are updated for closure; after those commands pass, `rg "Field update fixture name is too narrow|Document summary fixture claim is broader than its body" P6_HANDOFF_FINDINGS.md` returns no matches; `rg "CanvasSurface placeholder detector|Schema root fields constant" P6_HANDOFF_FINDINGS.md` returns matches for findings 3 and 5; `PLAN.md` marks Step 34 as `[x]`; this step document marks Units 1 through 3 as `[x]`.

Depends On:

Units 1 and 2.
