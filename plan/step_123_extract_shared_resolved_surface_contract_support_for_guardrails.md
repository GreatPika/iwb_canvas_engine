language: english

# Change Contract

## 1. Change Mandate
This change extracts shared resolved surface-contract support for guardrails so repeated exact owner/member/constructor/interface/signature checks stop diverging across rule families.

### Program End State
The end state for steps 119 through 126 is one symmetric guardrail architecture: rule families prove semantics through resolved analysis instead of token/lexical heuristics, repeated proof mechanics live in explicit shared support seams, runner ordering and shared state are declared through one inventory, and tool-test scaffolds plus their verification enforcement use canonical owned support seams.

### This Step's Role in the Chain
This step is the first cross-family consolidation pass: it turns migrated local surface-contract mechanics into one explicit shared proof seam and extends the self-guard so later steps can build on the same symmetric architecture instead of reintroducing family-local helpers.

## 2. Change Boundary

### Included in the Change
- Introduce one shared core support module for resolved surface-contract proof under `tool/src/guardrails/core/`.
- Retire the constructor-only helper in `tool/src/guardrails/core/public_constructor_surface_support.dart` into the new shared surface-contract support so constructor policy, exact surface, interface identity, and exact signature proof use one support seam.
- Migrate the repeated surface-contract checks in `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart`, `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`, and the interactive proof owners that remain after steps 119 and 120 (`mutation_boundary_rules.dart`, `interactive_mutation_owner_guard_rules.dart`, and `interactive_architecture_boundary_rules.dart`) to the shared support.
- Extend the step-122 guardrail self-guard so the new shared surface-contract seam and its consumer set are themselves protected against bypass and parallel-helper reintroduction.
- Update tool regressions and `doc/guardrails_state_map.md` so the repository records the new shared surface-contract seam explicitly.

### Not Included in the Change
- Shared sequence/event/routing extraction; that is locked in step 124.
- Declarative rule inventory and runner/state-map consolidation; that is locked in step 125.
- Tool-test scaffold normalization; that is locked in step 126.
- Type-leak traversal or signature-hermeticity graph changes in `resolved_type_leak_traversal.dart` and `signature_leak_support.dart`.
- Runtime behavior changes under `lib/src/**`.

## 3. Surrounding Code Review

### Inspected Artifacts
- `tool/src/guardrails/core/public_constructor_surface_support.dart` — current shared constructor helper; it proves only one narrow surface shape and leaves exact member/interface/signature checks duplicated elsewhere.
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` — already imports the constructor helper and proves interactive constructor policy through a local wrapper instead of a broader shared surface-contract seam.
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` — already imports the constructor helper and also carries local resolved interface/surface checks that overlap in proof shape with other families.
- `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart` — carries repeated owner/member/signature/constructor policy scaffolding with large allowlists and file-specific validators; this is the clearest current structural clone cluster.
- `tool/src/guardrails/core/guardrail_element_utils.dart` — shared resolved element/path helpers that already support source-order and owner matching and are the correct dependency base for a broader shared surface-contract module.
- `tool/src/guardrails/core/resolved_type_leak_traversal.dart` and `tool/src/guardrails/core/signature_leak_support.dart` — repository precedents for shared core proof helpers that remove repeated rule-local traversal logic without moving domain policy into core.
- `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart` (introduced by step 122) — the existing self-guard seam that must be extended so the new shared core support does not become another unguarded symmetry-enabling hotspot.
- `plan/step_120_replace_interactive_boundary_shape_token_guardrails_with_resolved_architecture_boundary_rules.md` — locks category-scoped semantic checks and rejects a new interactive analyzer monolith, which means shared surface-contract support must stay as reusable core proof mechanics, not another rule-local mega-helper.
- `plan/step_121_replace_controller_lexical_write_only_mutation_guardrails_with_resolved_semantics.md` — explicitly requires shared local helper/spec extraction where repeated proof shapes exist; step 123 is the post-migration lift of those repeated shapes into shared core support.
- `plan/step_122_close_resolved_guardrail_proof_surface_and_self_guard_regressions.md` — locks the pre-consolidation self-guard seam and explicitly requires later symmetry-enabling steps to extend that anti-regression surface instead of spawning parallel meta-checkers.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — existing regression surface for interactive constructor and mutation-owner guardrails affected by shared constructor/surface support.
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` — existing regression surface for prepared-replace and controller resolved-surface checks that will move onto the shared core helper seam.

### Current Entry Path
- `tool/check_guardrails.dart` -> `tool/src/guardrails/guardrails_runner.dart` -> `runInteractiveApiGuardrails(...)` / `runControllerApiGuardrails(...)`.

### Current Owner
- Surface-contract proof is partially shared in `public_constructor_surface_support.dart` and otherwise split across `prepared_replace_boundary_rules.dart`, `write_only_mutation_rules.dart`, and `mutation_boundary_rules.dart`.

### Adjacent Abstractions
- `guardrail_element_utils.dart` — shared resolved element ownership/path helpers.
- `resolved_type_leak_traversal.dart` and `signature_leak_support.dart` — current examples of reusable resolved proof mechanics in `core/`.

### Existing Tests
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — interactive structural regression surface.
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` — controller/prepared-replace structural regression surface.

### Analogous Implementation Path
- `tool/src/guardrails/core/public_constructor_surface_support.dart` — existing shared proof helper that already removed one repeated constructor-policy shape.
- `tool/src/guardrails/core/resolved_type_leak_traversal.dart` and `tool/src/guardrails/core/signature_leak_support.dart` — repository precedent for moving repeated resolved proof mechanics into `core/` while keeping domain policy local to rule families.

### Governing Repository Rules
- `AGENTS.md` — reuse established abstractions before creating near-duplicate helpers, and fix repeated weaknesses at the owning shared layer.
- `AGENTS.md` — code changes must finish with `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`.
- `PLAN.md` — step order is authoritative; this step follows the family migrations in steps 119 through 122 and must not reopen their locked domain-specific contracts.

### Rejected Misleading Local Patterns
- Leaving `public_constructor_surface_support.dart` in place and adding more one-off surface helpers beside it — wrong seam because it would preserve support fragmentation under different names.
- Keeping exact member/interface/signature proof local to each rule family — wrong owner because the proof mechanics are already repeated across controller and interactive rules.
- Moving domain policy allowlists into core support — wrong level because core must own mechanics, while rule families retain policy specs and diagnostics.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Shared structural resolved surface-contract proof mechanics.

#### Selected Architectural Form
- One new core support module, `tool/src/guardrails/core/resolved_surface_contract_support.dart`, owns spec-driven resolved validation for exact top-level surface, exact public-member surface, constructor policy, interface identity, and exact method signature checks.

#### Owning Layer or Module
- `tool/src/guardrails/core/resolved_surface_contract_support.dart`.
- `tool/src/guardrails/core/public_constructor_surface_support.dart` is retired into the new shared support.

#### Dependency Direction
- Rule families may depend on `resolved_surface_contract_support.dart`.
- The core support may depend on analyzer APIs, `guardrail_element_utils.dart`, and `guardrail_violation.dart`.
- Rule families keep their own policy specs and violation wording; the core support must not depend on rule-family policy tables.

#### State and Data Ownership
- Rule families own allowed names, required names, interface expectations, and diagnostic detail strings.
- The new core support owns validation mechanics and traversal order for resolved surface contracts.
- No runtime state or runtime policy moves into the tool core support.

#### Entry and Exit Boundaries
- Entry: parsed/resolved declarations and per-rule surface specs.
- Exit: `GuardrailViolation?` results or typed helper outputs consumed by rule families.

#### Permitted Extension Seam
- Add new resolved surface-contract validators or spec fields only in `resolved_surface_contract_support.dart` when the same proof shape appears in more than one rule family.

#### Rejected Alternatives
- Keep constructor policy in `public_constructor_surface_support.dart` and add new unrelated surface helpers next to it — rejected because it preserves fragmented support ownership.
- Build a generic guardrail DSL that mixes policy data, mechanics, and diagnostics in one layer — rejected because the repository still wants explicit rule-family ownership and debuggable local policy specs.

#### Why This Level Is Correct
- The repeated weakness is no longer “one bad rule”; it is the same resolved surface-contract proof shape being reimplemented across multiple families. The correct owner is a shared core helper module that centralizes mechanics while keeping domain policy in the rule families that already own it.

## 5. File Map

### Implementation Files
- `tool/src/guardrails/core/resolved_surface_contract_support.dart`
- `tool/src/guardrails/core/public_constructor_surface_support.dart` (delete)
- `tool/src/guardrails/rules/controller/prepared_replace_boundary_rules.dart`
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart`
- `doc/guardrails_state_map.md`

### Test Files
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`

### Analysis Area
- `tool/src/guardrails/core/**`
- `tool/src/guardrails/rules/controller/**`
- `tool/src/guardrails/rules/interactive/**`
- `test/tool/guardrails/**`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. Shared resolved surface-contract mechanics live in `tool/src/guardrails/core/resolved_surface_contract_support.dart`, not in any rule-family file.
2. `public_constructor_surface_support.dart` is retired into the new shared support; constructor policy is not left behind as a parallel helper seam.
3. Rule families keep domain policy specs and violation wording; the shared support must not become a second owner of rule-specific allowlists or invariants.
4. The shared support must cover exact top-level declaration surface, exact public-member surface, constructor policy, interface identity, and exact method-signature proof.
5. `prepared_replace_boundary_rules.dart`, `write_only_mutation_rules.dart`, `mutation_boundary_rules.dart`, `interactive_mutation_owner_guard_rules.dart`, and `interactive_architecture_boundary_rules.dart` must consume the shared surface-contract support wherever they currently reimplement those proof shapes after the 119/120 part-file split.
6. This step must not introduce a repository-wide generic DSL for guardrails; it extracts mechanics only.
7. The step-122 self-guard seam must be extended in this step so `resolved_surface_contract_support.dart` itself and its intended consumer set become mechanically protected against bypass and parallel surface-helper reintroduction.
8. Structural verification for this step is not satisfied by existing family negatives alone; it must include a mechanical drift check that fails if `public_constructor_surface_support.dart` returns, if a second shared surface-contract helper appears, or if the intended consumers stop depending on the new shared seam.

## 7. Result Requirements

1. Constructor policy proof is no longer owned by a standalone narrow helper separate from the rest of resolved surface-contract support.
2. Prepared-replace boundary checks, controller resolved-surface checks, and the interactive proof owners that remain after the 119/120 part-file split reuse one shared resolved surface-contract support seam.
3. Rule-family files retain local policy data but no longer reimplement the same surface-contract traversal/mechanics inline.
4. `doc/guardrails_state_map.md` records the new shared surface-contract support and no longer describes constructor policy support as a standalone one-off helper.
5. `resolved_surface_contract_support.dart` and its consumer set are covered by the step-122 self-guard seam, so reintroduction of parallel surface-contract helpers or bypassed local clones becomes mechanically visible.

## 8. Implementation Rules

### Analysis Scope
- Limit the extraction to repeated resolved surface-contract mechanics.
- Keep runtime behavior unchanged.
- Keep rule-family policy specs explicit and local.

### Target Verification Units
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

### Protected States, Data, or Structures
- Prepared-replace boundary owner/member/signature contract.
- Controller read-side/render-state interface contract.
- Interactive constructor/owner surface constraints already enforced by current guardrails.

### Allowed Semantic Change Zones
- Shared core surface-contract support.
- Rule-family usage of shared surface-contract support.
- Tool regressions and guardrail-state documentation for the affected families.

### Structural Enforcement
- The shared core module must depend only on analyzer/core guardrail support, not on rule-family policy modules.
- Rule families must pass explicit policy specs into the shared support rather than having the shared support reach into rule-local globals.
- Delete `public_constructor_surface_support.dart` after migrating its consumers.
- Keep diagnostics emitted through the owning rule families; do not move family-specific error wording into the core support.
- Extend `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart` so it asserts `resolved_surface_contract_support.dart` is the only shared surface-contract support owner, `public_constructor_surface_support.dart` is gone, and `prepared_replace_boundary_rules.dart`, `write_only_mutation_rules.dart`, `mutation_boundary_rules.dart`, `interactive_mutation_owner_guard_rules.dart`, and `interactive_architecture_boundary_rules.dart` adopt the shared seam instead of drifting back to local parallel helpers.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`
- Negative structural scenarios already covered by the interactive and controller suites must remain failing after the helper extraction.
- Positive structural scenarios for the canonical prepared-replace, controller, and interactive forms must remain green after the helper extraction.
- Negative self-guard scenarios must fail when `public_constructor_surface_support.dart` returns, when a second shared surface-contract helper appears, or when a migrated consumer stops depending on `resolved_surface_contract_support.dart`.

### Prohibited
- Adding new parallel surface-contract helpers next to `resolved_surface_contract_support.dart`.
- Moving domain policy tables or invariant ownership into the core support.
- Replacing explicit rule-family diagnostics with opaque generic core-support messages.

## 9. Vertical Slices

### Slice 1. [x] Shared resolved surface-contract support replaces constructor-only support

#### Slice Contract
One shared core module owns constructor policy and broader resolved surface-contract validation mechanics.

#### Change
- Add `resolved_surface_contract_support.dart`.
- Move constructor-policy validation out of `public_constructor_surface_support.dart` into the new module.
- Update interactive and controller constructor-policy consumers to import the new shared support.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Structural Verification
- Interactive tool scenarios that fail on constructor-surface violations must continue to fail after the helper migration, and the self-guard suite must fail if `public_constructor_surface_support.dart` reappears or if interactive consumers stop depending on `resolved_surface_contract_support.dart`.

#### Fixtures Used
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Positive Scenarios
- Canonical interactive constructor surfaces remain accepted.

#### Negative Scenarios
- Constructor-policy violations still fail.
- No consumer imports `public_constructor_surface_support.dart` after the migration.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- `public_constructor_surface_support.dart` is retired.

### Slice 2. [x] Prepared-replace surface contracts use shared core support

#### Slice Contract
Prepared-replace boundary owner/member/signature/constructor checks consume shared resolved surface-contract support instead of local repeated mechanics.

#### Change
- Refactor `prepared_replace_boundary_rules.dart` to express its exact owner/member/signature/constructor contracts through shared support specs and helper calls.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`

#### Structural Verification
- Prepared-replace negative scenarios in the controller tool suite continue to fail when owner/member/signature drift is introduced, and the self-guard suite must fail if prepared-replace reintroduces a local parallel surface-contract helper.

#### Fixtures Used
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`

#### Positive Scenarios
- Canonical prepared-replace owner surfaces remain accepted.

#### Negative Scenarios
- Missing required members still fail.
- Signature drift still fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Prepared-replace boundary checks no longer reimplement shared surface-contract mechanics inline.

### Slice 3. [x] Controller and interactive rule families converge on the shared surface-contract seam

#### Slice Contract
Controller write-only surface checks and interactive constructor-surface checks use the same shared resolved surface-contract support seam.

#### Change
- Refactor `write_only_mutation_rules.dart` and `mutation_boundary_rules.dart` to use shared surface-contract validators for their repeated surface/interface/constructor proof shapes.
- Update `doc/guardrails_state_map.md` to record the consolidated shared support.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`

#### Structural Verification
- Existing controller render-state/interface leak scenarios and interactive surface scenarios remain mechanically visible after the extraction, and the self-guard suite must fail if controller or interactive consumers bypass the shared surface-contract seam.

#### Fixtures Used
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`

#### Positive Scenarios
- Canonical controller and interactive surfaces remain accepted.

#### Negative Scenarios
- Interface-identity and surface drift still fail.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verifications.
- `doc/guardrails_state_map.md` records the shared surface-contract seam.

## 10. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`
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
