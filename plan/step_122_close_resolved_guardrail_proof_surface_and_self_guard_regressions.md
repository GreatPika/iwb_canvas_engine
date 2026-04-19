language: english

# Change Contract

## 1. Change Mandate
This change closes the resolved-guardrail proof surface by moving interactive resolver-purity primary proof back to runtime and by adding analyzer-backed self-guard regressions that prevent the migrated weak rule families from reintroducing raw source-token scanning.

## 2. Change Boundary

### Included in the Change
- `tool/invariant_registry.dart` updates that repoint `INV-ENG-INTERACTIVE-RESOLVER-PURITY` primary proof to the existing runtime proof surface.
- A new analyzer-backed tool test that guards the migrated weak rule files against reintroducing `readAsStringSync`, `toSource()`, `requireSourceTokens`, `requireTokenOrder`, and the deleted `resolver_purity_rules.dart` dependency.
- `doc/guardrails_state_map.md` updates that record the new targeted meta-control for the migrated files and the corrected proof-surface ownership for interactive resolver purity.

### Not Included in the Change
- Broad clone/metrics policy for all guardrails; this step adds targeted self-guard regressions over the migrated weak families, not repository-wide clone governance.
- Additional runtime behavior changes in `lib/src/interactive/**`.
- Additional architecture-boundary migration beyond the rule families covered by steps 118 through 121.
- CI workflow edits; the new tool test stays under existing tool-test execution.

## 3. Surrounding Code Review

### Inspected Artifacts
- `tool/invariant_registry.dart` — `INV-ENG-INTERACTIVE-RESOLVER-PURITY` currently declares `scope: 'engine-runtime'` but points both `primaryProof.path` and `toolProof.regressionPath` at `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`; this is the current proof-surface mismatch.
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart` — already contains runtime `INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY` cases proving that public interactive entrypoints invoked from `moveCommitDeltaResolver` throw before commit completes and gesture state is cleared.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — current structural regression path for interactive guardrails; it remains the correct `toolProof.regressionPath` after the proof-surface fix.
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` — migrated interactive rule owner that must not reintroduce raw source-token scanning after steps 118 through 120.
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart` — semantic replacement for the retired boundary-shape token family and a direct candidate for self-guard regression.
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` — migrated controller rule owner that must not reintroduce the deleted lexical/source-body heuristics after step 121.
- `doc/guardrails_state_map.md` — currently reports meta-control for guardrails itself as `NOT STARTED`; after the migrated files are covered by a dedicated self-guard test, that statement must become more precise.
- `tool/check_invariant_coverage.dart` — repository tool that verifies invariant ids, proof-path shape, and explicit marker coverage.
- `tool/check_verification_contract.dart` — repository tool that verifies the documented verification contract; no workflow change is expected in this step.
- `AGENTS.md` — confirms that invariant definitions belong in `tool/invariant_registry.dart` and that code changes must finish through the required verification preset.

### Current Entry Path
- Proof metadata: `tool/invariant_registry.dart`.
- Runtime proof path: `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`.
- Tool regression path: `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`.
- Tool-test execution: `dart run tool/run_tool_tests.dart ...` under the existing repository wrapper.

### Current Owner
- Proof-surface ownership is split between `tool/invariant_registry.dart` and the existing runtime/tool tests.
- There is no dedicated self-guard test for the migrated weak guardrail files yet.

### Adjacent Abstractions
- `tool/check_guardrails.dart` — enforcement entrypoint for tool-side guardrails; unchanged in this step.
- `tool/check_invariant_coverage.dart` — repository-native checker for invariant metadata and marker coverage.

### Existing Tests
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart` — current runtime witness for interactive resolver purity.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — current structural regression surface for the interactive guardrail.

### Analogous Implementation Path
- `tool/check_invariant_coverage.dart` — repository precedent for metadata-to-proof-surface verification.
- `tool/src/guardrails/rules/public/public_signature_rules.dart` and `tool/src/guardrails/rules/controller/committed_read_side_rules.dart` — strong semantic rule families that are good self-guard targets precisely because they avoid raw source-token helpers.

### Governing Repository Rules
- `AGENTS.md` — invariant definitions belong in `tool/invariant_registry.dart` and code changes must finish with `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`.
- `AGENTS.md` — tool tests must run through `dart run tool/run_tool_tests.dart`, not through direct ad hoc `dart test` shell commands.
- `doc/guardrails_state_map.md` — broader guardrails clone/metrics meta-control is still absent, so this step must describe its narrower targeted self-guard honestly rather than claiming repository-wide completion.

### Rejected Misleading Local Patterns
- Keeping `INV-ENG-INTERACTIVE-RESOLVER-PURITY` primary proof on a tool test — wrong proof surface, because the invariant is explicitly runtime-scoped and already has a runtime witness.
- A grep-style self-guard that scans raw file text for banned substrings — wrong proof shape, because the same migration is explicitly moving the repository away from text scanning; the self-guard must be analyzer-backed too.
- Claiming that clone/metrics meta-control is fully solved — wrong repository statement, because this step adds targeted regression coverage for the migrated weak files, not a repository-wide clone gate.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Verification metadata ownership plus targeted analyzer-backed self-guard regression.

#### Selected Architectural Form
- Keep proof metadata in `tool/invariant_registry.dart`, keep runtime and tool proof in their current test files, and add one dedicated analyzer-backed tool test that asserts the migrated weak rule files do not use banned raw source-token APIs or the deleted token helper dependency.

#### Owning Layer or Module
- Proof metadata: `tool/invariant_registry.dart`.
- Self-guard regression: `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`.

#### Dependency Direction
- The registry points at existing runtime and tool tests.
- The self-guard test reads guardrail source files through analyzer APIs.
- No runtime file or production tool file depends on the self-guard test.

#### State and Data Ownership
- No runtime state changes.
- Invariant proof ownership stays in the registry.
- Banned implementation-pattern policy for the migrated weak files lives only in the dedicated self-guard test.

#### Entry and Exit Boundaries
- Entry: `tool/invariant_registry.dart` and the migrated weak rule files under `tool/src/guardrails/rules/**`.
- Exit: corrected invariant metadata and failing analyzer-backed self-guard assertions when banned source-token APIs return.

#### Permitted Extension Seam
- One new test file at `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`.

#### Rejected Alternatives
- Add a new production tool entrypoint for self-guarding the guardrail implementation — rejected because existing tool-test infrastructure already owns this verification surface.
- Keep meta-control as a documentation note only — rejected because the repository needs a mechanical regression that fails when raw source-token scanning returns.

#### Why This Level Is Correct
- Proof-surface ownership already lives in the invariant registry, and the regression belongs in the existing tool-test layer. This keeps metadata, runtime proof, tool proof, and self-guard each in the repository location that already owns that responsibility.
- This step protects the resolved/non-token direction after the weak-family migrations, but it is intentionally a targeted anti-regression layer rather than a claim that all remaining resolved proof duplication is already consolidated.

## 5. File Map

### Implementation Files
- `tool/invariant_registry.dart`
- `doc/guardrails_state_map.md`

### Test Files
- `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`

### Analysis Area
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart`
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. `INV-ENG-INTERACTIVE-RESOLVER-PURITY.primaryProof.path` moves to `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`.
2. `INV-ENG-INTERACTIVE-RESOLVER-PURITY.toolProof.enforcementPath` remains `tool/check_guardrails.dart`, and `toolProof.regressionPath` remains `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`.
3. The new self-guard test is analyzer-backed. It does not scan raw file text for banned substrings.
4. The self-guard test covers the migrated weak rule owners only: `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`, `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart`, and `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`.
5. The self-guard test fails on reintroduction of `File.readAsStringSync`, `AstNode.toSource()`, `requireSourceTokens`, `requireTokenOrder`, or any dependency on `resolver_purity_rules.dart` inside the covered migrated rule files.
6. `doc/guardrails_state_map.md` must record targeted self-guard coverage for the migrated weak files and must not claim that repository-wide clone/metrics meta-control is complete.
7. This step records and protects the migrated direction, but it does not count as full guardrail implementation symmetry or full consolidation of repeated resolved proof shapes; repository documentation must leave that distinction explicit.

## 7. Result Requirements

1. `INV-ENG-INTERACTIVE-RESOLVER-PURITY` declares a runtime primary proof and a tool regression proof that match the actual repository evidence.
2. The migrated weak rule files have a mechanical analyzer-backed regression that fails when raw source-token APIs or the deleted helper dependency return.
3. Repository documentation records targeted meta-control for the migrated weak files without overstating broader guardrails governance.
4. `tool/check_invariant_coverage.dart` passes with the updated proof metadata.
5. Repository documentation explicitly distinguishes “protected against raw token-regression” from “fully consolidated/symmetric guardrail implementation”.

## 8. Implementation Rules

### Analysis Scope
- Limit metadata changes to the proof-surface correction for `INV-ENG-INTERACTIVE-RESOLVER-PURITY`.
- Limit self-guard coverage to the migrated weak rule files from steps 118 through 121.
- Do not add a new production tool command.

### Target Verification Units
- `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `tool/check_invariant_coverage.dart`

### Protected States, Data, or Structures
- Runtime proof ownership for `INV-ENG-INTERACTIVE-RESOLVER-PURITY`.
- Tool regression ownership for `INV-ENG-INTERACTIVE-RESOLVER-PURITY`.
- The semantic, non-token implementation form of the migrated weak guardrail files.

### Allowed Semantic Change Zones
- Proof metadata in `tool/invariant_registry.dart`.
- The dedicated self-guard tool test.
- Documentation for guardrail state and targeted meta-control.

### Structural Enforcement
- The self-guard test must parse the covered rule files with analyzer APIs and inspect invocations/imports/identifiers semantically.
- The self-guard test must fail on the banned implementation APIs and the deleted helper dependency listed in the locked decisions.
- Keep self-guard coverage inside `test/tool/guardrails/**` so the existing repository tool-test execution owns it.
- `doc/guardrails_state_map.md` must describe this step as targeted anti-regression over migrated weak files, not as completion of broader guardrail symmetry or clone governance.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- Negative self-guard scenarios for `readAsStringSync`, `toSource()`, `requireSourceTokens`, `requireTokenOrder`, and `resolver_purity_rules.dart` dependency reintroduction.

### Prohibited
- Tool-only primary proof for `INV-ENG-INTERACTIVE-RESOLVER-PURITY`.
- Grep-style raw text scanning in the new self-guard test.
- Expanding this step into repository-wide clone/metrics governance.
- Production-code changes that reintroduce the deleted token helper.
- Treating targeted self-guard coverage as evidence that overall guardrail implementation symmetry or duplication control is complete.

### Optional: Recognition Forms That Must Be Supported
- Analyzer-backed detection of `File.readAsStringSync` invocations.
- Analyzer-backed detection of `AstNode.toSource()` invocations.
- Analyzer-backed detection of imports or references to `resolver_purity_rules.dart`.
- Analyzer-backed detection of calls to `requireSourceTokens` and `requireTokenOrder`.

### Optional: Allowed Forms That Are Not Violations
- Ordinary string literals used in diagnostics or repository-relative paths when they are not used as proof over whole-source text.
- Runtime and tool proof living in separate test files for the same invariant when the registry metadata points to them correctly.

### Optional: Resolution Rules
- The self-guard test must identify banned API usage from parsed/resolved nodes, not from raw file text substrings.
- A banned helper dependency is present only when the covered file imports or references the deleted helper semantically.

## 9. Vertical Slices

### Slice 1. [ ] Runtime primary proof ownership is restored for interactive resolver purity

#### Slice Contract
`INV-ENG-INTERACTIVE-RESOLVER-PURITY` declares a runtime primary proof and keeps the interactive tool test as tool regression proof.

#### Change
- Update `tool/invariant_registry.dart` so `primaryProof.path` points to `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`.
- Keep `toolProof.enforcementPath` at `tool/check_guardrails.dart` and keep `toolProof.regressionPath` at `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`.

#### Behavioral Verification
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

#### Structural Verification
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used
- None.

#### Positive Scenarios
- Runtime resolver-purity tests remain green.
- Invariant coverage validation accepts the updated primary proof path.

#### Negative Scenarios
- The registry no longer reports the tool test as both the runtime primary proof and the tool regression proof.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- `tool/invariant_registry.dart` reflects the corrected proof ownership.

### Slice 2. [ ] Analyzer-backed self-guard protects the migrated weak rule files

#### Slice Contract
A dedicated analyzer-backed tool test fails when the migrated weak rule files reintroduce banned raw source-token APIs or the deleted helper dependency.

#### Change
- Add `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`.
- Parse the covered migrated rule files with analyzer APIs and assert absence of `File.readAsStringSync`, `AstNode.toSource()`, `requireSourceTokens`, `requireTokenOrder`, and any import/reference to `resolver_purity_rules.dart`.
- Keep the test scoped to the covered migrated weak files named in the locked decisions.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`

#### Structural Verification
- The self-guard test must fail when any banned API or helper dependency is reintroduced into a covered file.

#### Fixtures Used
- None.

#### Positive Scenarios
- The current migrated weak rule files pass the self-guard.
- Diagnostic strings or path strings that are not used for raw source proof do not fail the self-guard.

#### Negative Scenarios
- Reintroduced `readAsStringSync` fails.
- Reintroduced `toSource()` fails.
- Reintroduced `requireSourceTokens` or `requireTokenOrder` fails.
- Reintroduced `resolver_purity_rules.dart` dependency fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- The self-guard diagnostics identify the offending file and banned API.

### Slice 3. [ ] Documentation records the corrected proof surface and targeted meta-control honestly

#### Slice Contract
Repository documentation records runtime primary proof for interactive resolver purity and targeted self-guard coverage for the migrated weak files without claiming repository-wide meta-control completion.

#### Change
- Update `doc/guardrails_state_map.md` so the invariant/proof notes reflect the runtime primary proof for interactive resolver purity.
- Update the state-map meta-control status to describe the new targeted self-guard over migrated weak files and to keep broader clone/metrics governance marked as still outstanding.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

#### Structural Verification
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

#### Fixtures Used
- None.

#### Positive Scenarios
- Documentation names the corrected runtime primary proof and the targeted self-guard test.
- Repository verification passes without CI workflow edits.

#### Negative Scenarios
- Documentation does not claim that repository-wide clone/metrics meta-control is done.
- Documentation does not claim that interactive resolver purity is tool-primary anymore.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verifications.
- Updated documentation names the corrected proof surface and the targeted self-guard honestly.

## 10. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

## 11. Acceptance Criteria

- The change mandate is satisfied.
- The surrounding code review records actual repository evidence.
- The architectural form is explicit, justified, and locked at the correct level.
- No material architectural choice remains to the implementing agent.
- Result requirements are satisfied.
- Implementation rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
