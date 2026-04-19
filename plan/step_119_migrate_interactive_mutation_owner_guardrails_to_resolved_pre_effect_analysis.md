language: english

# Change Contract

## 1. Change Mandate
This change migrates interactive mutation-owner guardrails from positional/token checks to a symmetric resolved sequence-and-routing proof family for interactive mutation owners.

### Program End State
The end state for steps 119 through 126 is one symmetric guardrail architecture: rule families prove semantics through resolved analysis instead of token/lexical heuristics, repeated proof mechanics live in explicit shared support seams, runner ordering and shared state are declared through one inventory, and tool-test scaffolds plus their verification enforcement use canonical owned support seams.

### This Step's Role in the Chain
This step moves the interactive mutation-owner family onto the target resolved sequence-and-routing form and leaves cross-family shared-engine extraction, declarative runner inventory, and normalized tool-test scaffolds to steps 123 through 126.

## 2. Change Boundary

### Included in the Change
- Replace statement-slot and source-text mutation-owner checks in `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` with resolved semantic sequence and routing checks for `SceneControllerSelectionMutations` and `SceneControllerSceneMutations`.
- Introduce a dedicated interactive mutation-owner guard part file under the existing interactive runner so mutation-owner proof stops accumulating inline inside `mutation_boundary_rules.dart`.
- Refactor `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart` so mutation-owner policy data becomes a thin semantic descriptor table for method surface and required sequence/routing contracts instead of statement slots or boundary-helper semantics.
- Update `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` and `test/tool/support/guardrails_tool_test_support.dart` so tool regressions cover canonical allowed forms, forbidden sequence drift, forbidden routing drift, and forbidden callback-forwarding drift from the new proof model.
- Update `doc/guardrails_state_map.md` so the mutation-owner family is recorded as resolved sequence/routing proof rather than positional token matching.

### Not Included in the Change
- Root and capability resolver-purity migration from step 118.
- Interactive architecture-boundary migration from step 120.
- Controller-layer lexical migration from step 121.
- Cross-domain extraction of shared guardrail engines across interactive/controller/public families; this step leaves a reusable local proof seam inside the interactive family only.
- Runtime behavior changes in `lib/src/interactive/internal/**`.

## 3. Surrounding Code Review

### Inspected Artifacts
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` — current interactive rule entrypoint; mutation-owner proof still lives inline here and currently depends on `policyIndex` plus source-text forwarding checks.
- `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart` — current mutation-owner policy owner; today it stores statement-slot data and callback spellings, which is too weak for resolved sequence/routing proof.
- `tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart` — existing interactive-local semantic scan from step 118; it already defines the current family shape for pure-prelude recognition and resolved guard ownership and is the closest local precedent for mutation-owner sequence scanning.
- `tool/src/guardrails/rules/interactive/boundary_shape_token_rules.dart` — current token monolith scheduled for replacement in step 120; it is the nearby negative precedent showing what step 119 must not become in analyzer form.
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` — current weak controller family scheduled for semantic migration in step 121; its contract explicitly moves toward shared local helper/spec forms for repeated proof shapes, which step 119 must align with.
- `tool/src/guardrails/core/guardrail_element_utils.dart` — existing resolved ownership/path helper seam used by stronger guardrails and available to the interactive family.
- `lib/src/interactive/internal/scene_controller_selection_mutations.dart` — canonical selection mutation-owner shell; each public method currently calls `ensureExternalMutationAllowed(...)` before delegating to `SceneControllerMutationBoundary`.
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart` — canonical scene mutation-owner shell; standard scene mutations use `ensureExternalMutationAllowed(...)`, `setCameraOffset(...)` performs validation/read preflight before `interruptForExternalMutation()`, and `replaceScene(...)` forwards `interruptBeforeApply: interruptForExternalMutation`.
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` — canonical interactive write owner; mutation-owner shells route into this boundary and the runtime invariant already treats it as the sole committed-write owner.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — current structural regression harness for interactive guardrails, including mutation-owner guard and forwarding failures.
- `test/tool/support/guardrails_tool_test_support.dart` — sandbox fixture owner for mutation-owner shells and boundary-owner scaffolds.
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` — runtime proof for `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY`; this remains the behavioral owner for write ownership.
- `plan/step_120_replace_interactive_boundary_shape_token_guardrails_with_resolved_architecture_boundary_rules.md` — step-120 contract locks category-scoped semantic part-file decomposition and explicitly forbids replacing a token monolith with an analyzer monolith.
- `plan/step_121_replace_controller_lexical_write_only_mutation_guardrails_with_resolved_semantics.md` — step-121 contract locks shared local helper/spec extraction for repeated resolved proof shapes and rejects bespoke lexical replacements.
- `plan/step_122_close_resolved_guardrail_proof_surface_and_self_guard_regressions.md` — step-122 contract explicitly distinguishes targeted anti-regression from full symmetry/consolidation; step 119 must leave the family in a reusable local form without pretending consolidation is already done.

### Current Entry Path
- `tool/check_guardrails.dart` -> `tool/src/guardrails/guardrails_runner.dart` -> `runInteractiveApiGuardrails(...)` -> `_checkMutationOwnerPolicies(...)`.

### Current Owner
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` with mutation-owner policy metadata in `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart`.

### Adjacent Abstractions
- `resolved_entrypoint_guard_rules.dart` — existing interactive-local resolved guard scan for root/capability entrypoints.
- `SceneControllerSelectionOwner` and `SceneControllerSceneOwner` — public shells above the mutation owners.
- `SceneControllerMutationBoundary` — runtime owner that performs committed writes and callback-orchestrated replace-scene application.

### Existing Tests
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — current tool-side mutation-owner structural regression surface.
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` — runtime proof that mutation-owner shells remain routing-only over the boundary owner.

### Analogous Implementation Path
- `tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart` — closest same-family precedent for resolved sequence scanning over pure prelude plus canonical guard ownership.
- `tool/src/guardrails/rules/controller/committed_read_side_rules.dart` — closest repository precedent for resolved ownership/routing proof that does not duplicate runtime behavior in policy tables.
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` (target form locked by step 121) — closest planned precedent for repeated local proof shapes being factored into shared local helpers/specs instead of bespoke walkers.

### Governing Repository Rules
- `AGENTS.md` — fixes must go to the owning layer and should not leave stable knowledge split across duplicated policy owners.
- `AGENTS.md` — code changes must end with `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`.
- `AGENTS.md` — runtime tests remain the source of truth for runtime behavior; tool guardrails are structural proof and must not re-own behavioral semantics they do not need.
- `PLAN.md` — step order is authoritative; step 119 must stay compatible with the already-locked step 120, 121, and 122 contracts.
- `doc/guardrails_state_map.md` — the repository already treats this family as part of the AST/resolved migration path, not as a place to extend token proof.

### Rejected Misleading Local Patterns
- `policyIndex` in `MutationOwnerPolicySpec` — wrong seam because it encodes statement slot rather than semantic sequence/routing contract.
- `_isAllowedReplaceSceneInterruptForwarding(...)` backed by `body.toSource().contains(...)` — wrong proof because it proves named-argument spelling instead of resolved callback routing.
- A second inline analyzer monolith inside `mutation_boundary_rules.dart` — wrong shape because step 120 already forbids the same monolith pattern for the interactive family.
- Local callback alias/dataflow tracking for `interruptBeforeApply` forwarding — wrong seam because it creates a partial flow engine for a narrow contract and does not align with the intended family-level sequence/routing proof shape.
- Boundary-helper semantics stored in policy metadata — wrong owner because runtime helper semantics belong to the boundary/runtime layer, not to the descriptor table.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Structural semantic sequence-and-routing proof for interactive mutation-owner entrypoints.

#### Selected Architectural Form
- A category-scoped interactive mutation-owner guard part that provides one local semantic event model for mutation-owner methods and one local resolved routing validator for callback-forwarding forms.

#### Owning Layer or Module
- Tool rule owner: `tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart` as a `part of 'mutation_boundary_rules.dart';`.
- Thin mutation-owner descriptor owner: `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart`.
- Runner wiring remains in `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`.

#### Dependency Direction
- `committed_read_callback_rules.dart` may provide only thin mutation-owner semantic descriptors to the interactive mutation-owner guard part.
- `interactive_mutation_owner_guard_rules.dart` may reuse resolved ownership/path helpers already present in `resolved_entrypoint_guard_rules.dart` and `guardrail_element_utils.dart`.
- The mutation-owner guard part reads resolved interactive units through `GuardrailContext`.
- Runtime code under `lib/src/interactive/internal/**` remains read-only input and must not depend on tool-side proof helpers.

#### State and Data Ownership
- Runtime write semantics remain owned by `SceneControllerMutationBoundary` and runtime tests.
- The interactive mutation-owner guard part owns only mutation-owner sequence/routing proof over resolved AST nodes and resolved targets.
- `committed_read_callback_rules.dart` owns only thin method-level semantic descriptors: required guard/interrupt kind, required routing shape, and narrow special-form flags where repository evidence already locks them.
- The tool must not own mutable alias state, callback dataflow state, or a second policy table of boundary-helper behavior.

#### Entry and Exit Boundaries
- Entry: resolved methods in `SceneControllerSelectionMutations`, `SceneControllerSceneMutations`, and resolved targets they invoke.
- Exit: `GuardrailViolation` diagnostics from `runInteractiveApiGuardrails(...)`.

#### Permitted Extension Seam
- Private semantic-event classifiers, sequence evaluators, and resolved routing validators inside `interactive_mutation_owner_guard_rules.dart`, backed by thin descriptors from `committed_read_callback_rules.dart`.

#### Rejected Alternatives
- Keep the mutation-owner migration inline in `mutation_boundary_rules.dart` as one large analyzer procedure — rejected because it reproduces the same monolith shape that step 120 forbids for the interactive family.
- Store helper-level boundary semantics in `MutationOwnerPolicySpec` — rejected because that would make the descriptor table a second owner of runtime behavior.
- Extract a cross-domain generic framework in this step — rejected because the chain explicitly defers broader symmetry/consolidation beyond steps 118 through 122.

#### Why This Level Is Correct
- This keeps mutation-owner proof in the same interactive rule family as step 118 while shaping it like the later resolved families: category-scoped part file, thin descriptors, one local event model, and one local routing proof seam. That is the smallest change that fixes the weak positional/token seam without locking the repository into another bespoke interactive-only engine or prematurely inventing a cross-domain framework.

## 5. File Map

### Implementation Files
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart`
- `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart`
- `doc/guardrails_state_map.md`

### Test Files
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/interactive/core/scene_controller_mutation_boundary_test.dart`

### Fixtures and Supporting Data
- `test/tool/support/guardrails_tool_test_support.dart`

### Analysis Area
- `lib/src/interactive/internal/{scene_controller_selection_mutations,scene_controller_scene_mutations,scene_controller_mutation_boundary}.dart`
- `tool/src/guardrails/rules/interactive/**`
- `test/tool/guardrails/**`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. Step 119 introduces `interactive_mutation_owner_guard_rules.dart` as the mutation-owner semantic proof owner and removes inline mutation-owner proof growth from `mutation_boundary_rules.dart` beyond runner wiring.
2. `MutationOwnerPolicySpec` stops encoding statement slots and must not encode boundary-helper allowlists, callback alias behavior, or helper-level runtime semantics.
3. Selection and scene mutation owners must be enforced through one shared local semantic event model inside `interactive_mutation_owner_guard_rules.dart`; step 119 must not create separate proof engines for selection and scene owners.
4. `setCameraOffset(...)` and `replaceScene(...)` may remain special forms, but only as narrow local sequence/routing validators or narrow descriptor flags layered on the same event model and routing validators.
5. `replaceScene(...)` callback-forwarding proof accepts only direct owned callback expressions such as `interruptForExternalMutation` or `this.interruptForExternalMutation`; local variable aliases and reassignment-based forwarding are not supported forms in this step.
6. `SceneControllerSelectionMutations` methods remain valid only when `ensureExternalMutationAllowed(...)` resolves before the first effectful boundary route.
7. `SceneControllerSceneMutations.write`, `setBackgroundColor`, `setGridEnabled`, `setGridCellSize`, `addNode`, `ensureLayer`, `patchNode`, `removeNode`, and `clearScene` remain valid only when `ensureExternalMutationAllowed(...)` resolves before the first effectful boundary route.
8. `SceneControllerSceneMutations.setCameraOffset(...)` remains valid only when the canonical current preflight form is preserved and `interruptForExternalMutation()` resolves before the effectful camera-offset apply route.
9. `notifySceneChanged()` remains outside the mutation-owner descriptor table in this step.
10. This step must leave an interactive-local sequence/routing proof seam that later consolidation can absorb; it must not claim to complete cross-domain guardrail symmetry by itself.

## 7. Result Requirements

1. No mutation-owner guardrail path depends on `policyIndex`, `body.toSource()`, or string matching of named-argument forwarding.
2. Interactive mutation-owner guardrails are organized as one category-scoped semantic sequence/routing part plus thin descriptors, not as inline runner logic plus policy-owned helper semantics.
3. Selection-owner and scene-owner mutation sequencing share one local semantic event model and one local routing-proof family.
4. The current canonical `setCameraOffset(...)` and `replaceScene(...)` runtime forms remain accepted without changing runtime code.
5. Local callback alias forwarding and reassigned callback forwarding for `replaceScene(...)` are rejected by tool regressions.
6. `doc/guardrails_state_map.md` records the mutation-owner family as resolved sequence/routing proof and does not describe it as positional token matching.

## 8. Implementation Rules

### Analysis Scope
- Limit the migration to interactive mutation-owner structural proof.
- Keep runtime mutation behavior unchanged.
- Keep the current mutation-owner public surface unchanged.
- Do not expand this step into cross-domain guardrail-framework extraction.

### Target Verification Units
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `test/interactive/core/scene_controller_mutation_boundary_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

### Protected States, Data, or Structures
- `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY` runtime ownership split.
- Direct mutation-owner routing over `SceneControllerMutationBoundary`.
- The current canonical `setCameraOffset(...)` and `replaceScene(...)` runtime forms.
- The step-118 interactive family shape where resolved sequence scanning is local to the family and does not depend on raw source matching.

### Allowed Semantic Change Zones
- Interactive mutation-owner descriptor shape.
- Interactive mutation-owner semantic event classification.
- Interactive mutation-owner routing validation.
- Tool fixtures, regressions, and documentation for the mutation-owner family.

### Structural Enforcement
- Introduce `interactive_mutation_owner_guard_rules.dart` as a `part of 'mutation_boundary_rules.dart';` and move mutation-owner semantic proof there.
- Reuse existing pure-prelude and resolved-ownership helpers from the interactive family where they fit the locked proof shape instead of duplicating near-identical local scans.
- Model mutation-owner proof as semantic events and resolved routing, not as raw statement positions.
- Keep descriptor data thin; helper-level runtime semantics must not be expressed as policy-table allowlists.
- Validate `replaceScene(...)` forwarding through resolved direct callback routing only; do not add callback alias/dataflow tracking.
- Keep diagnostics emitted through `GuardrailViolation`; do not add a second checker or tool entrypoint.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- Negative structural scenarios for a missing exclusivity guard, a late exclusivity guard, a late interrupt in `setCameraOffset(...)`, wrong `replaceScene(...)` callback forwarding, local alias callback forwarding, reassigned alias callback forwarding, and direct boundary bypass.
- Positive structural scenarios for harmless local prelude before the required guard, the current canonical `setCameraOffset(...)` preflight, and direct `replaceScene(..., interruptBeforeApply: interruptForExternalMutation)` forwarding.

### Prohibited
- A second inline analyzer monolith in `mutation_boundary_rules.dart`.
- Callback alias/dataflow tracking for mutation-owner proof.
- Boundary-helper allowlists or helper-level runtime semantics stored in `MutationOwnerPolicySpec`.
- Separate bespoke walkers for selection owners and scene owners.
- Runtime code changes that move ownership away from `SceneControllerMutationBoundary`.
- Presenting this step as full cross-domain guardrail symmetry or full proof-engine consolidation.

### Optional: Recognition Forms That Must Be Supported
- Direct `ensureExternalMutationAllowed(...)` invocation before the first effectful boundary route.
- Direct `interruptForExternalMutation()` invocation before `mutations.setCameraOffset(...)`.
- `mutations.replaceScene(snapshot, interruptBeforeApply: interruptForExternalMutation)`.
- `mutations.replaceScene(snapshot, interruptBeforeApply: this.interruptForExternalMutation)`.
- Early return after the current canonical camera-offset preflight when no camera change is needed.

### Optional: Allowed Forms That Are Not Violations
- Pure local statements before the required guard or interrupt when they do not route into the boundary owner.
- The current canonical camera-offset preflight form before `interruptForExternalMutation()`.
- Direct callback forwarding without a standalone `interruptForExternalMutation()` statement in `replaceScene(...)`.

### Optional: Resolution Rules
- A resolved call counts as the exclusivity guard only when it targets the declared `ensureExternalMutationAllowed` callback owned by the mutation-owner class.
- A resolved call counts as the interrupt only when it targets the declared `interruptForExternalMutation` callback owned by the mutation-owner class.
- A resolved route counts as the effectful boundary route only when it targets the canonical boundary owner in the mutation-owner contract.
- A callback-forwarding expression counts only when the resolved expression is a direct owned callback reference, not a local alias or reassigned temporary.

## 9. Vertical Slices

### Slice 1. [ ] Category-scoped mutation-owner proof owner and thin descriptors

#### Slice Contract
Interactive mutation-owner proof lives in a dedicated semantic part file and is configured by thin semantic descriptors rather than statement slots or helper-behavior policy.

#### Change
- Add `interactive_mutation_owner_guard_rules.dart` as the mutation-owner semantic proof owner under `mutation_boundary_rules.dart`.
- Rewire `runInteractiveApiGuardrails(...)` so mutation-owner proof dispatches into the new part file.
- Refactor `MutationOwnerPolicySpec` in `committed_read_callback_rules.dart` so it describes only method surface and required sequence/routing contract, not statement slots or helper-level semantics.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Structural Verification
- Tool sandbox scenario that fails when a selection mutation owner reaches the boundary before `ensureExternalMutationAllowed(...)`.
- Tool sandbox scenario that fails when a standard scene mutation owner reaches the boundary before `ensureExternalMutationAllowed(...)`.

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- Selection mutation owners pass when the required guard resolves before the first effectful route.
- Standard scene mutation owners pass when the required guard resolves before the first effectful route.

#### Negative Scenarios
- Missing guard fails.
- Late guard fails.
- Descriptor data no longer depends on a required statement slot.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verifications.
- Mutation-owner proof no longer expands inline in `mutation_boundary_rules.dart`.

### Slice 2. [ ] Shared local semantic event model covers selection and scene mutation owners

#### Slice Contract
Selection-owner and scene-owner mutation methods are enforced through one shared local semantic event model rather than separate bespoke walkers.

#### Change
- Implement one local semantic event model in `interactive_mutation_owner_guard_rules.dart` for pure prelude, required guard/interrupt, boundary route, and effectful boundary route.
- Build one local sequence evaluator over that event model and apply it to both selection and scene mutation owners.
- Reuse existing interactive-family pure-prelude and resolved-ownership helpers where they fit the locked form.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- Tool sandbox scenario that accepts a harmless local statement before `ensureExternalMutationAllowed(...)`.

#### Structural Verification
- Tool sandbox scenario that fails when `SceneControllerSelectionMutations` reaches `mutations.*` before the required guard.
- Tool sandbox scenario that fails when `SceneControllerSceneMutations` reaches an effectful boundary route before the required guard.

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- Harmless local prelude before the guard is accepted.
- Shared sequence logic accepts the canonical standard selection and scene forms.

#### Negative Scenarios
- Early boundary route fails for selection owners.
- Early boundary route fails for standard scene owners.
- A second bespoke owner-specific proof path is not needed to cover standard cases.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verifications.
- Selection and standard scene mutation methods are covered by the same local event model.

### Slice 3. [ ] Special-form routing for `replaceScene(...)` and `setCameraOffset(...)` stays narrow

#### Slice Contract
`replaceScene(...)` and `setCameraOffset(...)` remain accepted only through narrow local sequence/routing validators layered on the shared event model, without alias-flow or policy-owned helper semantics.

#### Change
- Add a direct resolved routing validator for `replaceScene(..., interruptBeforeApply: ...)`.
- Add a narrow local special-form validator for the canonical `setCameraOffset(...)` preflight sequence.
- Keep both special forms on top of the same event model and routing helpers rather than introducing dedicated standalone walkers.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`

#### Structural Verification
- Tool sandbox scenario that fails when `replaceScene(...)` forwards the wrong callback.
- Tool sandbox scenario that fails when `replaceScene(...)` forwards through a local alias.
- Tool sandbox scenario that fails when `replaceScene(...)` forwards through a reassigned alias.
- Tool sandbox scenario that fails when `interruptForExternalMutation()` appears after the effectful `setCameraOffset(...)` route.

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- Canonical direct `replaceScene(...)` forwarding passes.
- Canonical `setCameraOffset(...)` preflight passes unchanged.

#### Negative Scenarios
- Wrong direct callback forwarding fails.
- Local alias forwarding fails.
- Reassigned alias forwarding fails.
- Late interrupt in `setCameraOffset(...)` fails.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verifications.
- Special forms are covered without policy-owned helper semantics or alias/dataflow tracking.

### Slice 4. [ ] Fixtures and documentation reflect the sequence/routing proof family honestly

#### Slice Contract
Interactive mutation-owner fixtures and repository documentation describe the family as resolved sequence/routing proof and do not overstate full symmetry/consolidation.

#### Change
- Update mutation-owner tool fixtures and assertions so they encode the allowed and forbidden sequence/routing forms locked in this contract.
- Update `doc/guardrails_state_map.md` so this family is recorded as resolved sequence/routing proof.
- Keep documentation explicit that this step improves local family shape but does not complete cross-domain proof-engine consolidation.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`

#### Structural Verification
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- Tool fixtures can encode canonical mutation-owner sequence/routing forms without statement slots.
- Runtime mutation-boundary proof remains green with no runtime code changes.

#### Negative Scenarios
- Documentation does not describe the family as token/source-order based.
- Documentation does not claim that full cross-domain guardrail symmetry is already complete.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verifications.
- Updated documentation records the mutation-owner family honestly.

## 10. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
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
