language: english

# Change Contract

## 1. Change Mandate
This change normalizes guardrail tool-test scaffolds around canonical manifests and retires the current mixed support seam cleanly, so large inline sandbox fixtures stop diverging across suites without breaking the surviving import-boundary helpers or the repository's verification-contract enforcement.

### Program End State
The end state for steps 119 through 126 is one symmetric guardrail architecture: rule families prove semantics through resolved analysis instead of token/lexical heuristics, repeated proof mechanics live in explicit shared support seams, runner ordering and shared state are declared through one inventory, and tool-test scaffolds plus their verification enforcement use canonical owned support seams.

### This Step's Role in the Chain
This step closes the chain at the test/support layer: it makes fixture ownership, sandbox helpers, verification-contract inventory, and CI trigger enforcement match the same explicit symmetric architecture that steps 119 through 125 establish in the rule and runner layers.

## 2. Change Boundary

### Included in the Change
- Introduce canonical manifest-based fixture support under `test/tool/support/` for guardrail sandbox source trees.
- Split oversized mixed-responsibility tool-test support into one guardrail manifest owner, one guardrail writer owner, one guardrail sandbox/bootstrap helper owner, one import-boundaries sandbox helper owner, and one shared diagnostic-matcher owner so canonical fixture data, sandbox creation, and stderr matcher helpers stop accumulating in one file.
- Migrate every active guardrail suite that currently imports `guardrails_tool_test_support.dart` to the new support split, including the interactive, controller, public, contract, model, layout/entrypoint, and rule-inventory suites.
- Migrate the current import-boundaries suites that import `guardrails_tool_test_support.dart` onto the dedicated non-guardrail successor seam before deleting the old file.
- Delete `test/tool/support/guardrails_tool_test_support.dart` after its responsibilities are moved into the locked manifest/writer/bootstrap split.
- Add one dedicated structural regression that makes duplicate-builder drift and manifest-ownership drift mechanically visible.
- Update the verification-contract registry/test path inventory and `.github/workflows/ci.yaml` tool-test trigger list so the deleted support file is replaced by the new owned support paths in repository-local enforcement.
- Update `doc/guardrails_state_map.md` only if it currently describes the deleted support seam or the affected scaffold ownership; otherwise leave repository documentation unchanged in this step.

### Not Included in the Change
- Guardrail rule semantics or runtime behavior.
- Declarative rule inventory work; that is locked in step 125.
- Repository-wide normalization of every tool test outside the current consumers of `guardrails_tool_test_support.dart`.
- Import-boundary rule semantics; only their shared sandbox/diagnostic support ownership moves in this step.

## 3. Surrounding Code Review

### Inspected Artifacts
- `test/tool/support/guardrails_tool_test_support.dart` — current monolithic guardrail sandbox support file at 1672 lines; it mixes canonical fixture text, sandbox writers, interactive/controller/public support scaffolds, and mutation fixture builders in one file.
- `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`, `import_boundaries_layer_dag_tool_test.dart`, `import_boundaries_external_packages_tool_test.dart`, and `import_boundaries_layout_tool_test.dart` — all currently import `guardrails_tool_test_support.dart`; they prove the file is already a broader tool-test seam via `createImportBoundariesSandbox()` and shared `diagnostic(...)` matcher usage, not a guardrail-only helper.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` plus `test/tool/guardrails/interactive_api/**` — current interactive guardrail suite is now physically decomposed into one executable entrypoint with `part` files grouped by semantic interactive guardrail families, but the suite still owns canonical sandbox scaffolds inline and remains a primary normalization target for this step.
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` — current controller guardrail suite at 3032 lines; keeps its own `_committedMutationAccessFixture(...)` builder inline and repeats large canonical support scaffolds.
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` — current focused interactive suite at 1135 lines; still duplicates `_sceneControllerFixture(...)` rather than consuming one canonical manifest source.
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart` and `guardrails_public_signature_hermeticity_tool_test.dart` — both depend on shared interactive architecture support scaffolds from `guardrails_tool_test_support.dart`, which means public guardrail suites are also coupled to the same mixed support owner.
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`, `guardrails_model_architecture_tool_test.dart`, and `guardrails_layout_and_entrypoints_tool_test.dart` — all currently import `guardrails_tool_test_support.dart`; the contract/model suites depend on `createGuardrailsSandbox()`, `writeMinimalControllerStore()`, and `diagnostic(...)`, while the layout suite depends on `createGuardrailsSandbox()`, `writeMinimalControllerStore()`, and `writeCanonicalPublicExportScaffold(...)`, so these suites must receive explicit successor seams in this step rather than being left as implicit fallout from deleting the old file.
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart` — current declarative-inventory suite still imports `guardrails_tool_test_support.dart` for `createGuardrailsSandbox()`, `writeCanonicalPublicExportScaffold(...)`, and `writeMinimalControllerStore(...)`; because this suite proves runner/inventory contracts, omitting it from the migration would leave a hidden legacy seam consumer behind even if every other guardrail suite moved.
- `test/tool/support/tool_process_test_support.dart` — current stable owner of sandbox creation and tool-process execution; this should remain the execution seam and not be replaced.
- `test/tool/support/public_entrypoint_contract.dart` — current focused support precedent showing that small, responsibility-specific support files already exist and work well in this layer.
- `tool/src/verification_contract/verification_contract_registry.dart` — the repository-local verification contract currently treats `test/tool/support/guardrails_tool_test_support.dart` as an explicit trigger entry, so deleting the file without updating the registry would contradict existing enforcement.
- `test/tool/verification_contract_tool_test.dart` — regression test that hardcodes the same trigger-entry path and must move with the registry update for this step to remain executable.
- `.github/workflows/ci.yaml` — the live CI tool-test trigger filter still lists `test/tool/support/guardrails_tool_test_support.dart`; since `tool/check_verification_contract.dart` validates registry entries against this workflow, the workflow is part of the same enforcement seam for this step.

### Current Entry Path
- Guardrail tool suites under `test/tool/guardrails/**` create sandboxes through `createGuardrailsSandbox()` and then write large inline or helper-driven source trees before running `check_guardrails.dart`.
- Import-boundary suites under `test/tool/import_boundaries/**` create sandboxes through `createImportBoundariesSandbox()` from the same mixed support file before running `check_import_boundaries.dart`.
- `tool/check_verification_contract.dart` enforces the current support-file path through `verification_contract_registry.dart`, with `verification_contract_tool_test.dart` asserting the same trigger inventory mechanically.

### Current Owner
- Canonical guardrail sandbox scaffolds are split between one huge mixed support file and additional inline builders inside large test suites, while the same mixed support file also owns surviving import-boundary sandbox/bootstrap helpers and shared stderr matchers.

### Adjacent Abstractions
- `tool_process_test_support.dart` — sandbox execution seam that should remain stable.
- `public_entrypoint_contract.dart` — example of a focused support module in the same layer.
- `verification_contract_registry.dart` / `verification_contract_tool_test.dart` / `.github/workflows/ci.yaml` — existing repository-local enforcement seam that must stay aligned with the owned support-path inventory.

### Existing Tests
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/interactive_api/**`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `test/tool/verification_contract_tool_test.dart`
- `.github/workflows/ci.yaml`

### Analogous Implementation Path
- `public_entrypoint_contract.dart` — precedent for keeping canonical test data in a focused support module instead of in large test suites.
- The post-step-123/124 shared proof-support work — architectural precedent that symmetry should include the test layer, not only the production rule layer.
- `verification_contract_registry.dart` plus `tool/check_verification_contract.dart` — repository precedent that support-path ownership should be mechanically enumerated in one explicit inventory and kept aligned with the live CI workflow instead of left as prose-only knowledge.

### Governing Repository Rules
- `AGENTS.md` — keep files cohesive and do not add a new concern to an already mixed file.
- `AGENTS.md` — prefer mechanically enforced repository-local structure over ad hoc repeated prose or repeated manual wiring.
- `AGENTS.md` — treat the repository as the source of truth and update existing enforcement when repository-specific ownership changes.
- `PLAN.md` — the guardrail roadmap now explicitly targets symmetry beyond the weak-family migrations, so test scaffolds must stop being an asymmetrical tangle of inline builders.

### Rejected Misleading Local Patterns
- Keeping `guardrails_tool_test_support.dart` as the permanent catch-all for every new guardrail scaffold — wrong owner because the file is already a mixed hotspot.
- Moving all fixture text into each test suite “for readability” — wrong seam because it preserves duplication of canonical scaffolds.
- Generating fixtures from opaque templates with hidden substitution logic — wrong level because tests still need explicit, auditable manifests and focused overrides.
- Deleting `guardrails_tool_test_support.dart` while leaving `createImportBoundariesSandbox()` / `diagnostic(...)` users, verification-contract trigger entries, or `.github/workflows/ci.yaml` untouched — wrong execution shape because the repository already has live non-guardrail and enforcement consumers of that file.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Guardrail tool-test fixture ownership, plus retirement of the current mixed support seam without breaking the remaining shared tool-test consumers.

#### Selected Architectural Form
- Introduce manifest-based canonical fixture support under `test/tool/support/` with one guardrail manifest owner file, one guardrail writer owner file, one guardrail sandbox/bootstrap helper file, one import-boundaries sandbox helper file, and one shared diagnostic-matcher file. Guardrail suites express only per-case overrides against canonical manifests instead of defining their own large inline fixture builders; import-boundaries suites move onto the dedicated non-guardrail helpers; `tool_process_test_support.dart` remains the execution seam; and the verification-contract inventory plus `.github/workflows/ci.yaml` are updated to the new support-path set in the same step.

#### Owning Layer or Module
- `test/tool/support/guardrail_fixture_manifest.dart`
- `test/tool/support/guardrail_fixture_writer.dart`
- `test/tool/support/guardrails_sandbox_support.dart`
- `test/tool/support/import_boundaries_sandbox_support.dart`
- `test/tool/support/tool_diagnostic_matchers.dart`
- `test/tool/support/guardrails_tool_test_support.dart` is deleted.
- `tool/src/verification_contract/verification_contract_registry.dart` remains the explicit trigger-entry inventory owner, and `.github/workflows/ci.yaml` plus `test/tool/verification_contract_tool_test.dart` must be kept in sync with it.

#### Dependency Direction
- Guardrail test suites depend on manifest/writer support plus `guardrails_sandbox_support.dart`, `tool_diagnostic_matchers.dart`, and `tool_process_test_support.dart`.
- Import-boundaries suites depend on `import_boundaries_sandbox_support.dart`, `tool_diagnostic_matchers.dart`, and `tool_process_test_support.dart`.
- Manifest/writer support depends on sandbox file-writing helpers, not on specific test suites.
- `guardrails_sandbox_support.dart` depends on `tool_process_test_support.dart` for sandbox execution but does not own canonical fixture text.
- `import_boundaries_sandbox_support.dart` depends on `tool_process_test_support.dart` for sandbox execution but does not own guardrail manifests.
- `tool_diagnostic_matchers.dart` is the only shared owner of the generic `diagnostic(...)` matcher.
- Verification-contract registry/test depend on the explicit successor support-path inventory, not on the deleted legacy path.
- Test suites must not own canonical fixture definitions that already exist in the manifest layer.

#### State and Data Ownership
- Canonical scaffold source trees and fixture variants live in manifest definitions under `test/tool/support/`.
- Sandbox materialization mechanics live in the writer support.
- Guardrail-specific sandbox/bootstrap helpers live in `guardrails_sandbox_support.dart`.
- Import-boundaries sandbox/bootstrap helpers live in `import_boundaries_sandbox_support.dart`.
- Shared stderr diagnostic matchers live in `tool_diagnostic_matchers.dart`.
- Test suites own only scenario-specific overrides and expectations.
- Verification-contract trigger entries for the affected support paths live in `verification_contract_registry.dart` and must be mirrored in `.github/workflows/ci.yaml`.

#### Entry and Exit Boundaries
- Entry: guardrail manifests plus per-test overrides, import-boundaries sandbox bootstrap calls, verification-contract trigger entries for the owned support paths, and the matching CI workflow trigger list.
- Exit: materialized sandbox source trees, the existing tool-process results from `runSandboxTool(...)`, and verification-contract checks that fail when the owned support inventory or its CI workflow mirror drifts.

#### Permitted Extension Seam
- Add new canonical manifest shapes or new supported override fields only under `test/tool/support/guardrail_fixture_manifest.dart` and `test/tool/support/guardrail_fixture_writer.dart` when more than one test suite needs them.
- Add new guardrail-specific sandbox/bootstrap helpers only under `test/tool/support/guardrails_sandbox_support.dart`.
- Add new import-boundaries sandbox/bootstrap helpers only under `test/tool/support/import_boundaries_sandbox_support.dart`.
- Add new shared stderr matchers only under `test/tool/support/tool_diagnostic_matchers.dart` when more than one tool-test family uses them.

#### Rejected Alternatives
- Keep adding builders to `guardrails_tool_test_support.dart` — rejected because the file is already a mixed hotspot.
- Hide canonical scaffolds behind string-template code generation — rejected because test fixtures must remain explicit and reviewable.
- Keep `diagnostic(...)` and `createImportBoundariesSandbox()` in a guardrail-named support file after deleting the old mixed owner — rejected because that would just recreate the same ownership ambiguity under a new name.

#### Why This Level Is Correct
- The repeated weakness is the mixed support seam itself. The correct repair is to give guardrail canonical fixtures, import-boundaries sandbox helpers, shared stderr matchers, verification-contract path inventory, and the matching CI workflow trigger list explicit owners, so the deleted legacy file does not leave hidden runtime or enforcement consumers behind.

## 5. File Map

### Implementation Files
- `test/tool/support/guardrail_fixture_manifest.dart`
- `test/tool/support/guardrail_fixture_writer.dart`
- `test/tool/support/guardrails_sandbox_support.dart`
- `test/tool/support/import_boundaries_sandbox_support.dart`
- `test/tool/support/tool_diagnostic_matchers.dart`
- `test/tool/support/guardrails_tool_test_support.dart` (delete)
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/interactive_api/**`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `tool/src/verification_contract/verification_contract_registry.dart`
- `test/tool/verification_contract_tool_test.dart`
- `.github/workflows/ci.yaml`

### Test Files
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `test/tool/verification_contract_tool_test.dart`
- `test/tool/guardrails/guardrails_fixture_manifest_support_tool_test.dart`

### Analysis Area
- `test/tool/support/**`
- `test/tool/guardrails/**`
- `test/tool/import_boundaries/**`
- `tool/src/verification_contract/**`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. Canonical guardrail sandbox fixtures move into manifest-based support under `test/tool/support/guardrail_fixture_manifest.dart`.
2. `tool_process_test_support.dart` remains the sandbox execution seam; this step does not replace process execution helpers.
3. `guardrails_sandbox_support.dart` is the only guardrail-specific bootstrap helper owner and may contain guardrail sandbox creation plus guardrail-specific common helpers only; it must not own canonical fixture text or import-boundaries helpers.
4. `import_boundaries_sandbox_support.dart` is the only owner of `createImportBoundariesSandbox()` and any shared import-boundaries bootstrap helpers; import-boundaries suites must not keep importing a guardrail-named support file.
5. `tool_diagnostic_matchers.dart` is the only shared owner of the generic `diagnostic(...)` matcher used across guardrail and import-boundaries tool suites.
6. Large canonical fixture builders such as `_sceneControllerFixture(...)` and `_committedMutationAccessFixture(...)` must not remain duplicated inline across suites once equivalent manifest support exists.
7. `guardrails_tool_test_support.dart` is deleted; it does not survive as a compatibility façade.
8. `verification_contract_registry.dart`, `verification_contract_tool_test.dart`, and `.github/workflows/ci.yaml` must replace the deleted support-file path with the explicit successor support-path set from this step.
9. `test/tool/guardrails/guardrails_fixture_manifest_support_tool_test.dart` must mechanically fail when canonical scaffold ownership drifts back into suites, whether that drift reuses old helper names or returns under renamed suite-local builders/manifests, or when `guardrails_tool_test_support.dart` returns.
10. Every pre-step guardrail-suite importer of `guardrails_tool_test_support.dart` must be assigned to an explicit vertical slice and to an explicit final-verification command; listing a suite only in the file map or required test strategy is not sufficient.
11. Canonical scaffold migration must copy the currently authoritative source literally from the repository owner that already defines it; this step must not reconstruct interactive, controller, or public canonical source trees from memory, partial paraphrase, or failing-test backfill.
12. `guardrails_tool_test_support.dart` may exist only as the temporary migration carrier while successor owners are being introduced; it must not be deleted until every code consumer, verification-contract inventory entry, and CI trigger entry has moved to the explicit successor seams.

## 7. Result Requirements

1. Every current importer of `guardrails_tool_test_support.dart` moves onto an explicit successor seam: guardrail suites consume the new canonical manifest/bootstrap support, and import-boundaries suites consume `import_boundaries_sandbox_support.dart` plus `tool_diagnostic_matchers.dart`.
2. `guardrails_tool_test_support.dart` is deleted and replaced by the locked `guardrail_fixture_manifest.dart` / `guardrail_fixture_writer.dart` / `guardrails_sandbox_support.dart` / `import_boundaries_sandbox_support.dart` / `tool_diagnostic_matchers.dart` split.
3. Interactive, controller, and shared public guardrail suites use the same manifest/writer seam for the canonical scaffolds they share.
4. `guardrails_contract_architecture_tool_test.dart` and `guardrails_model_architecture_tool_test.dart` adopt `guardrails_sandbox_support.dart` plus `tool_diagnostic_matchers.dart`, and `guardrails_layout_and_entrypoints_tool_test.dart` adopts `guardrails_sandbox_support.dart` plus `guardrail_fixture_manifest.dart` / `guardrail_fixture_writer.dart` with `public_entrypoint_contract.dart` retained as the export-contract expectation owner; none continue importing the deleted support file.
5. `verification_contract_registry.dart`, `verification_contract_tool_test.dart`, and `.github/workflows/ci.yaml` enumerate the successor support paths and no longer reference the deleted support file.
6. `guardrails_fixture_manifest_support_tool_test.dart` mechanically fails when duplicate canonical scaffold ownership or misplaced manifest ownership return, even if the duplicated builders/manifests use new names.
7. Adding a new guardrail sandbox scenario no longer requires copying a large canonical fixture builder into another test suite.
8. `guardrails_rule_inventory_tool_test.dart` uses the same successor seam as the other guardrail suites and is not left on the deleted legacy support file.

## 8. Implementation Rules

### Analysis Scope
- Limit normalization to the current `guardrails_tool_test_support.dart` consumer set plus the verification-contract inventory and CI workflow trigger list that enforce that support seam.
- Keep tool semantics unchanged.
- Keep sandbox process execution on the existing support seam.

### Target Verification Units
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart`
- `test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `test/tool/verification_contract_tool_test.dart`
- `dart run tool/check_verification_contract.dart`
- `test/tool/guardrails/guardrails_fixture_manifest_support_tool_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

### Protected States, Data, or Structures
- Canonical interactive scene-controller and mutation-owner scaffold shapes.
- Canonical controller committed-mutation/prepared-replace scaffold shapes.
- Canonical public entrypoint/export scaffold shapes already shared through support helpers.
- Existing import-boundaries sandbox creation flow.
- Verification-contract trigger-entry coverage for the owned tool-test support paths.
- CI tool-test trigger coverage for the owned tool-test support paths.
- Existing sandbox execution flow through `runSandboxTool(...)`.

### Allowed Semantic Change Zones
- Guardrail tool-test support ownership and fixture normalization.
- Import-boundaries support ownership extracted from the deleted mixed support file.
- Verification-contract registry/test path inventory and CI workflow trigger list for the affected support files.
- Test-suite use of canonical manifests/writers.
- Documentation of the normalized support seam where needed.

### Required Execution Order
1. Introduce the new support owners and move the canonical interactive scaffold onto the manifest/writer seam first.
2. Move the canonical controller committed-mutation/prepared-replace scaffold onto the same manifest/writer seam second.
3. Migrate the remaining guardrail consumers of canonical scaffolds and sandbox/bootstrap helpers, including the public-facing, layout, contract, model, and rule-inventory suites.
4. Migrate import-boundaries consumers onto `import_boundaries_sandbox_support.dart` plus `tool_diagnostic_matchers.dart`.
5. Update `verification_contract_registry.dart`, `test/tool/verification_contract_tool_test.dart`, and `.github/workflows/ci.yaml` to the successor support-path inventory.
6. Delete `guardrails_tool_test_support.dart` only after steps 1 through 5 are complete and `rg "guardrails_tool_test_support.dart"` finds no remaining code or enforcement references outside the structural regression that intentionally forbids its return.

### Structural Enforcement
- Canonical scaffolds used by more than one suite must live under `test/tool/support/`, not inline in a test suite.
- Test suites must express per-case overrides against manifests instead of redefining the whole canonical scaffold shape.
- Keep canonical fixture data auditable as plain support code and manifests; do not hide it behind opaque template expansion.
- `guardrails_fixture_manifest_support_tool_test.dart` must parse the affected suite/support files and fail when canonical scaffold source or canonical manifest ownership for the shared interactive scene-controller shape, the shared controller committed-mutation/prepared-replace shape, or the shared public scaffold shape reappears outside `guardrail_fixture_manifest.dart` / `guardrail_fixture_writer.dart`, regardless of helper naming, including drift inside `test/tool/guardrails/interactive_api/**`, or when `guardrails_tool_test_support.dart` exists again.
- Import-boundaries suites must consume `import_boundaries_sandbox_support.dart` and `tool_diagnostic_matchers.dart`; recreating `createImportBoundariesSandbox()` or generic `diagnostic(...)` in a guardrail-named file is forbidden.
- `verification_contract_tool_test.dart` and `dart run tool/check_verification_contract.dart` must fail if the verification-contract registry or `.github/workflows/ci.yaml` still references `test/tool/support/guardrails_tool_test_support.dart` or omits any successor support path that this step makes authoritative.
- Every guardrail suite that imported `guardrails_tool_test_support.dart` before this step must be named in at least one vertical slice and in final verification; file-map presence alone is not acceptance evidence.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/verification_contract_tool_test.dart`
- `dart run tool/check_verification_contract.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_fixture_manifest_support_tool_test.dart`
- Existing negative and positive guardrail scenarios must remain unchanged in meaning after the fixture normalization.
- Existing import-boundaries and verification-contract scenarios must remain unchanged in meaning after the support-file retirement.
- The live CI workflow must stay aligned with the verification-contract inventory after the support-file retirement.

### Prohibited
- Reintroducing `guardrails_tool_test_support.dart` after the split.
- Leaving duplicated canonical fixture builders inline in more than one suite when manifest support covers the same shape.
- Replacing explicit support code with opaque string-template generation.
- Deleting the legacy support file without migrating the import-boundaries helpers and verification-contract trigger inventory to the locked successor seams.
- Reconstructing canonical scaffold files by approximation instead of literally transferring the authoritative repository-owned scaffold source into the manifest layer before switching consumers.

## 9. Vertical Slices

### Slice 1. [x] Canonical manifest/writer support replaces duplicated interactive scene-controller fixture builders

#### Slice Contract
Interactive scene-controller canonical scaffolds are owned by manifest/writer support under `test/tool/support/` instead of duplicated inline builders across the executable suite entrypoint or any `test/tool/guardrails/interactive_api/**` `part` file.

#### Change
- Add `guardrail_fixture_manifest.dart` and `guardrail_fixture_writer.dart`.
- Migrate the canonical interactive scene-controller scaffold used by the interactive suites onto the new manifest/writer support.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`

#### Structural Verification
- `guardrails_fixture_manifest_support_tool_test.dart` must fail if interactive suites regain ownership of the canonical interactive scene-controller scaffold shape outside the manifest layer, regardless of helper naming.

#### Fixtures Used
- `test/tool/support/guardrail_fixture_manifest.dart`
- `test/tool/support/guardrail_fixture_writer.dart`

#### Positive Scenarios
- Existing interactive guardrail scenarios remain green with manifest-based canonical scaffolds.

#### Negative Scenarios
- Canonical interactive fixture drift is no longer introduced by copying an outdated inline builder into another suite.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verification.
- Duplicated inline `_sceneControllerFixture(...)` ownership is removed for canonical cases.

### Slice 2. [x] Controller committed-mutation and prepared-replace scaffolds converge on the manifest seam

#### Slice Contract
Canonical controller guardrail scaffolds use the same manifest/writer seam instead of suite-local large builders.

#### Change
- Migrate controller committed-mutation/prepared-replace scaffold shapes onto manifest-based support.
- Remove or reduce suite-local `_committedMutationAccessFixture(...)` ownership where canonical manifest support now covers the shared shape.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`

#### Structural Verification
- `guardrails_fixture_manifest_support_tool_test.dart` must fail if the controller suite regains ownership of the canonical committed-mutation/prepared-replace scaffold shape or other canonical manifest data outside the manifest layer, regardless of helper naming.

#### Fixtures Used
- `test/tool/support/guardrail_fixture_manifest.dart`
- `test/tool/support/guardrail_fixture_writer.dart`

#### Positive Scenarios
- Existing controller guardrail scenarios remain green with manifest-based canonical scaffolds.

#### Negative Scenarios
- Canonical controller scaffold drift is no longer introduced by copying large inline builders.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Canonical controller scaffold ownership lives in the manifest layer.

### Slice 3. [x] Shared public-facing and rule-inventory suites consume the normalized scaffold seam while the legacy seam remains migration-only

#### Slice Contract
Shared public-facing and rule-inventory guardrail suites consume the normalized scaffold seam, and `guardrails_tool_test_support.dart` is reduced to migration-only responsibilities while downstream consumers are still being switched.

#### Change
- Migrate shared public-facing suites that consume interactive architecture support scaffolds onto the normalized manifest/writer seam.
- Migrate `guardrails_rule_inventory_tool_test.dart` onto the same explicit successor seam used by other guardrail suites.
- Add `guardrails_sandbox_support.dart` for guardrail-specific bootstrap helpers, but do not delete `guardrails_tool_test_support.dart` in this slice; deletion is reserved for the final migration slice after every remaining consumer and enforcement entry has moved.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_fixture_manifest_support_tool_test.dart`

#### Structural Verification
- `guardrails_fixture_manifest_support_tool_test.dart` must fail if canonical scaffold ownership is again split between suites and support files, or if `guardrails_public_surface_tool_test.dart`, `guardrails_public_signature_hermeticity_tool_test.dart`, or `guardrails_rule_inventory_tool_test.dart` still import `guardrails_tool_test_support.dart`.

#### Fixtures Used
- `test/tool/support/guardrail_fixture_manifest.dart`
- `test/tool/support/guardrail_fixture_writer.dart`
- `test/tool/support/guardrails_sandbox_support.dart`

#### Positive Scenarios
- Public-facing suites continue to pass with the normalized scaffold seam.
- The rule-inventory suite continues to prove runner/inventory contracts while using the same successor support ownership as other guardrail suites.

#### Negative Scenarios
- The rule-inventory suite cannot remain as a hidden consumer of the legacy mixed support seam after the other guardrail suites migrate.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verification.
- `guardrails_public_surface_tool_test.dart`, `guardrails_public_signature_hermeticity_tool_test.dart`, and `guardrails_rule_inventory_tool_test.dart` no longer import `guardrails_tool_test_support.dart`.

### Slice 4. [x] Remaining guardrail architecture/layout suites adopt explicit successor seams

#### Slice Contract
Deleting `guardrails_tool_test_support.dart` no longer breaks the remaining guardrail architecture/layout suites because each migrates to an explicit successor seam instead of relying on implicit fallout from the file deletion.

#### Change
- Migrate `guardrails_contract_architecture_tool_test.dart` and `guardrails_model_architecture_tool_test.dart` onto `guardrails_sandbox_support.dart` plus `tool_diagnostic_matchers.dart`.
- Migrate `guardrails_layout_and_entrypoints_tool_test.dart` onto `guardrails_sandbox_support.dart` plus `guardrail_fixture_manifest.dart` / `guardrail_fixture_writer.dart`, with `public_entrypoint_contract.dart` retained for export-contract expectations, instead of `guardrails_tool_test_support.dart`.
- Keep canonical public export scaffold materialization in `guardrail_fixture_manifest.dart` / `guardrail_fixture_writer.dart`, with `public_entrypoint_contract.dart` retained as the export-contract expectation owner; do not re-home any of that ownership inside the layout suite.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`

#### Structural Verification
- `guardrails_fixture_manifest_support_tool_test.dart` must fail if `guardrails_contract_architecture_tool_test.dart`, `guardrails_model_architecture_tool_test.dart`, or `guardrails_layout_and_entrypoints_tool_test.dart` still import `guardrails_tool_test_support.dart`, or if canonical public scaffold ownership is reintroduced inside the layout suite outside the locked support owners.

#### Fixtures Used
- `test/tool/support/guardrails_sandbox_support.dart`
- `test/tool/support/tool_diagnostic_matchers.dart`
- `test/tool/support/guardrail_fixture_manifest.dart`
- `test/tool/support/guardrail_fixture_writer.dart`
- `test/tool/support/public_entrypoint_contract.dart`

#### Positive Scenarios
- Contract/model/layout guardrail suites continue to pass after adopting the explicit successor seams.

#### Negative Scenarios
- The deleted mixed support file cannot remain imported by contract/model/layout suites.
- The layout suite cannot reclaim ownership of canonical public export scaffold builders.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verification.
- Every pre-step contract/model/layout guardrail-suite importer of `guardrails_tool_test_support.dart` now imports only its locked successor seams.

### Slice 5. [x] Import-boundaries, verification-contract enforcement, and legacy-file retirement close together

#### Slice Contract
Deleting `guardrails_tool_test_support.dart` no longer breaks non-guardrail tool suites or repository-local verification enforcement because both move to explicit successor seams first, and the legacy file is removed only after no runtime or enforcement consumer remains.

#### Change
- Add `import_boundaries_sandbox_support.dart` and `tool_diagnostic_matchers.dart`.
- Migrate import-boundaries suites off `guardrails_tool_test_support.dart`.
- Update `verification_contract_registry.dart`, `verification_contract_tool_test.dart`, and `.github/workflows/ci.yaml` so the deleted support-file path is replaced by the authoritative successor support-path inventory.
- Delete `guardrails_tool_test_support.dart` only after every guardrail suite, every import-boundaries suite, `verification_contract_registry.dart`, `test/tool/verification_contract_tool_test.dart`, and `.github/workflows/ci.yaml` have already moved off the legacy path.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/verification_contract_tool_test.dart`
- `dart run tool/check_verification_contract.dart`

#### Structural Verification
- `test/tool/verification_contract_tool_test.dart` and `dart run tool/check_verification_contract.dart` must fail if the deleted legacy support path remains in `verification_contract_registry.dart` or `.github/workflows/ci.yaml`, or if the successor support-path inventory drifts between them.

#### Fixtures Used
- `test/tool/support/import_boundaries_sandbox_support.dart`
- `test/tool/support/tool_diagnostic_matchers.dart`
- `tool/src/verification_contract/verification_contract_registry.dart`
- `.github/workflows/ci.yaml`

#### Positive Scenarios
- Existing import-boundaries suites continue to pass with the dedicated sandbox helper and shared diagnostic matcher.
- Verification-contract checks continue to accept the canonical trigger-entry inventory after the support-path rename/split.
- The live CI workflow continues to satisfy `check_verification_contract.dart` after the support-path rename/split.

#### Negative Scenarios
- A stale `test/tool/support/guardrails_tool_test_support.dart` trigger entry in the verification-contract registry fails.
- Reintroducing `createImportBoundariesSandbox()` in a guardrail-named support file is not allowed.
- Deleting the legacy file before code consumers or enforcement entries are switched is not allowed.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verification.
- The deleted legacy support path is absent from both code consumers and verification-contract enforcement.

## 10. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_surface_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_public_signature_hermeticity_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_model_architecture_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_layout_and_entrypoints_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_controller_structure_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layer_dag_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_external_packages_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/import_boundaries/import_boundaries_layout_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/verification_contract_tool_test.dart`
- `dart run tool/check_verification_contract.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_fixture_manifest_support_tool_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`
- Final verification is incomplete unless every pre-step importer of `guardrails_tool_test_support.dart` is either deleted or covered by the commands above.

## 11. Acceptance Criteria

- The change mandate is satisfied.
- The surrounding code review records actual repository evidence.
- The architectural form is explicit, justified, and locked at the correct level.
- No material architectural choice remains to the implementing agent.
- Result requirements are satisfied.
- Implementation rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
