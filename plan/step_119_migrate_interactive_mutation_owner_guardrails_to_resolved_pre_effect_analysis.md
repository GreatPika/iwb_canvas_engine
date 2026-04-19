language: english

# Change Contract

## 1. Change Mandate
This change migrates interactive mutation-owner guardrails from statement-index and source-text matching to resolved pre-effect sequencing analysis.

## 2. Change Boundary

### Included in the Change
- Replacement of `policyIndex`-driven mutation-owner checks in `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` with semantic sequencing checks driven by resolved guard, interrupt, and boundary-call targets.
- Refactor of `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart` so mutation-owner policy data describes semantic expectations instead of statement slots.
- Tool-test and fixture updates for `SceneControllerSelectionMutations` and `SceneControllerSceneMutations`, including the `setCameraOffset(...)` and `replaceScene(...)` special forms.
- `doc/guardrails_state_map.md` updates that stop describing this migrated mutation-owner path as token/source-order backed.

### Not Included in the Change
- Root and capability resolver-purity migration; that is locked in step 118.
- Interactive architecture-boundary migration from `boundary_shape_token_rules.dart`; that is locked in step 120.
- Runtime behavior changes in `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` or the mutation-owner classes.
- Controller-layer lexical guardrail migration in `write_only_mutation_rules.dart`; that is locked in step 121.

## 3. Surrounding Code Review

### Inspected Artifacts
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` — current owner of `_checkMutationOwnerPolicies(...)`, `_checkMutationOwnerPolicy(...)`, and `_isAllowedReplaceSceneInterruptForwarding(...)`; current logic still relies on `policyIndex` and `body.toSource().contains(...)`.
- `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart` — current mutation-owner policy table stores `policyIndex` and raw callback names; `setCameraOffset` and `replaceScene` are encoded as positional exceptions.
- `lib/src/interactive/internal/scene_controller_selection_mutations.dart` — every public selection mutation method currently calls `ensureExternalMutationAllowed(...)` and then delegates to `SceneControllerMutationBoundary`.
- `lib/src/interactive/internal/scene_controller_scene_mutations.dart` — scene mutation methods mostly guard through `ensureExternalMutationAllowed(...)`; `setCameraOffset(...)` currently performs `validateCameraOffset(...)`, `shouldApplyCameraOffset(...)`, and an early return before `interruptForExternalMutation()`; `replaceScene(...)` currently forwards `interruptBeforeApply: interruptForExternalMutation` into `mutations.replaceScene(...)`.
- `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` — canonical interactive write owner; `replaceScene(...)` takes `interruptBeforeApply`, and `setCameraOffset(...)` is the first effectful call after the current preflight.
- `test/tool/support/guardrails_tool_test_support.dart` — current sandbox fixtures for `interactiveSelectionMutationsFixture(...)` and `interactiveSceneMutationsFixture(...)` encode positional expectations that must become semantic.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — existing structural regression harness for missing external-mutation guards, store-controller bypasses, and `replaceScene(...)` forwarding.
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` — runtime proof that `SceneControllerMutationBoundary` remains the write owner and that mutation-owner shells stay thin.
- `tool/src/guardrails/rules/controller/committed_read_side_rules.dart` — closest repository precedent for resolved executable/type analysis that reports boundary violations from analyzer elements rather than from source substrings.
- `doc/guardrails_state_map.md` — explicitly classifies parts of `mutation_boundary_rules.dart` as low-medium reliability.

### Current Entry Path
- `tool/check_guardrails.dart` -> `tool/src/guardrails/guardrails_runner.dart` -> `runInteractiveApiGuardrails(...)` -> `_checkMutationOwnerPolicies(...)`.

### Current Owner
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` with policy data in `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart`.

### Adjacent Abstractions
- `SceneControllerSceneOwner` and `SceneControllerSelectionOwner` — public shells that call the mutation owners after root resolver-purity guards.
- `SceneControllerMutationBoundary` — committed write owner that the mutation-owner shells are required to reach only after the exclusivity guard or interrupt.

### Existing Tests
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — current tool regressions for missing mutation-owner guards and replace-scene forwarding.
- `test/interactive/core/scene_controller_mutation_boundary_test.dart` — runtime proof that mutation-owner shells remain routing-only over the boundary owner.

### Analogous Implementation Path
- `tool/src/guardrails/rules/controller/committed_read_side_rules.dart` — semantic boundary checks driven by resolved executable targets.
- `tool/src/guardrails/rules/public/public_signature_rules.dart` — repository precedent for analyzer-backed proof over string matching.

### Governing Repository Rules
- `AGENTS.md` — code changes must end with `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`.
- `AGENTS.md` — invariant metadata and regression markers must stay consistent with the enforced rule surface.
- `doc/guardrails_state_map.md` — the repository already treats this family as an AST-migration target rather than a token-family worth extending.

### Rejected Misleading Local Patterns
- `policyIndex` in `MutationOwnerPolicySpec` — this is the wrong seam because it encodes statement slot instead of semantic sequencing.
- `_isAllowedReplaceSceneInterruptForwarding(...)` backed by `body.toSource().contains(...)` — this is the wrong owner because it proves spelling of a named argument instead of the callback identity being forwarded.
- A helper indirection that renames the guard callback without resolving its target — this is still a text-level proof and does not survive harmless refactors.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Structural guardrail analysis of interactive mutation-owner sequencing.

#### Selected Architectural Form
- Semantic pre-effect sequencing analysis inside the existing interactive guardrail runner, driven by explicit mutation-owner policy descriptors and resolved call targets.

#### Owning Layer or Module
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` with policy descriptors in `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart`.

#### Dependency Direction
- Policy descriptors feed the interactive rule.
- The rule reads resolved mutation-owner units through `GuardrailContext`.
- Runtime code remains read-only input to the guardrail and does not depend on it.

#### State and Data Ownership
- No runtime state changes.
- Mutation-owner sequencing policy remains owned by the policy table in `committed_read_callback_rules.dart`.
- The rule module owns semantic classification of guard calls, preflight calls, interrupts, and boundary effects.

#### Entry and Exit Boundaries
- Entry: resolved declarations for `SceneControllerSelectionMutations` and `SceneControllerSceneMutations`.
- Exit: `GuardrailViolation` diagnostics from `runInteractiveApiGuardrails(...)`.

#### Permitted Extension Seam
- Private helper functions in `mutation_boundary_rules.dart` that classify resolved invocations and the first boundary effect for a method body.

#### Rejected Alternatives
- Keep statement-slot policy and only resolve the statement at that slot — rejected because the rule would still be brittle under harmless preflight edits.
- Push mutation-owner sequencing proof into runtime tests only — rejected because the repository already expects interactive boundary drift to fail in `check_guardrails.dart`.

#### Why This Level Is Correct
- Mutation-owner exclusivity is already centralized in the interactive guardrail runner and its policy table. The weak part is the positional proof surface, not the owner. Replacing that proof with resolved sequencing keeps the same owner and fixes the actual fragility.

## 5. File Map

### Implementation Files
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`
- `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart`
- `doc/guardrails_state_map.md`

### Test Files
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixtures and Supporting Data
- `test/tool/support/guardrails_tool_test_support.dart`

### Analysis Area
- `lib/src/interactive/internal/{scene_controller_selection_mutations,scene_controller_scene_mutations,scene_controller_mutation_boundary}.dart`
- `tool/src/guardrails/rules/interactive/**`
- `test/interactive/core/scene_controller_mutation_boundary_test.dart`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. `MutationOwnerPolicySpec` stops encoding statement-slot position. The policy table must describe semantic expectations, not a numeric statement index.
2. `SceneControllerSelectionMutations` remains valid only when `ensureExternalMutationAllowed(...)` resolves before the first call into `SceneControllerMutationBoundary`.
3. `SceneControllerSceneMutations.write`, `setBackgroundColor`, `setGridEnabled`, `setGridCellSize`, `addNode`, `ensureLayer`, `patchNode`, `removeNode`, and `clearScene` remain valid only when `ensureExternalMutationAllowed(...)` resolves before the first call into `SceneControllerMutationBoundary`.
4. `SceneControllerSceneMutations.setCameraOffset(...)` keeps its current special sequence: `mutations.validateCameraOffset(...)` and `mutations.shouldApplyCameraOffset(...)` may precede the exclusivity interrupt, an early return after `shouldApplyCameraOffset(...)` remains allowed, and `interruptForExternalMutation()` must resolve before the first effectful `mutations.setCameraOffset(...)` call.
5. `SceneControllerSceneMutations.replaceScene(...)` keeps its current special form: compliance is satisfied only by a resolved `mutations.replaceScene(snapshot, interruptBeforeApply: interruptForExternalMutation)` call. Raw source text matching of the named argument is forbidden.
6. `notifySceneChanged()` stays outside this mutation-owner policy table in this step.
7. Tool fixtures stop encoding required statement slots and start encoding semantic allowed and disallowed pre-effect forms.

## 7. Result Requirements

1. No interactive mutation-owner check depends on `policyIndex`, `body.toSource()`, or string matching of named-argument forwarding.
2. The guardrail still rejects any mutation-owner method that reaches `SceneControllerMutationBoundary` before the required exclusivity guard or interrupt.
3. `setCameraOffset(...)` and `replaceScene(...)` remain accepted in their current semantic forms without forcing an exact statement slot.
4. Tool regressions cover valid preflight, invalid late guard/interrupt, invalid replace-scene forwarding, and direct boundary bypass.
5. `doc/guardrails_state_map.md` no longer describes the migrated mutation-owner path as token/source-order backed.

## 8. Implementation Rules

### Analysis Scope
- Limit analysis to `SceneControllerSelectionMutations` and `SceneControllerSceneMutations`.
- Keep runtime mutation behavior unchanged.
- Keep the current mutation-owner public surface unchanged.

### Target Verification Units
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/support/guardrails_tool_test_support.dart`
- `test/interactive/core/scene_controller_mutation_boundary_test.dart`

### Protected States, Data, or Structures
- Mutation-owner routing over `SceneControllerMutationBoundary`.
- The current `setCameraOffset(...)` preflight and early-return contract.
- The current `replaceScene(...)` interrupt-forwarding contract.
- The existing write-owner split proved by `INV-ENG-INTERACTIVE-MUTATION-BOUNDARY` tests.

### Allowed Semantic Change Zones
- Policy-table shape in `committed_read_callback_rules.dart`.
- Tool-side mutation-owner sequencing analysis.
- Interactive tool-test fixtures and scenarios.
- Reliability notes in `doc/guardrails_state_map.md`.

### Structural Enforcement
- Classify calls by resolved target owner: exclusivity callback, interrupt callback, allowed preflight call, or `SceneControllerMutationBoundary` effect.
- Inspect named arguments of the `mutations.replaceScene(...)` call from AST and resolve the callback expression to the `interruptForExternalMutation` callback element.
- Use AST statement order only after each call is classified semantically.
- Keep diagnostics emitted through `GuardrailViolation`; do not add a second checker or a second policy table.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`
- Negative structural scenarios for a missing exclusivity guard, an interrupt that appears after the first boundary effect, wrong `replaceScene(...)` callback forwarding, and direct store-controller or boundary write bypass.
- Positive structural scenarios for the current `setCameraOffset(...)` preflight sequence and for the current `replaceScene(...)` named-argument forwarding.

### Prohibited
- `policyIndex`-driven sequencing proof.
- `body.toSource()` or source-substring matching for `replaceScene(...)` forwarding.
- Runtime code changes that move ownership away from `SceneControllerMutationBoundary`.
- Fixture logic that hardcodes a required statement slot instead of semantic sequencing.

### Optional: Recognition Forms That Must Be Supported
- Direct `ensureExternalMutationAllowed(...)` invocation before a boundary delegate.
- Direct `interruptForExternalMutation()` invocation before `mutations.setCameraOffset(...)`.
- `mutations.replaceScene(snapshot, interruptBeforeApply: interruptForExternalMutation)`.
- Early return after `mutations.shouldApplyCameraOffset(...)` when no camera change is needed.

### Optional: Allowed Forms That Are Not Violations
- `mutations.validateCameraOffset(...)` before the exclusivity interrupt in `setCameraOffset(...)`.
- `mutations.shouldApplyCameraOffset(...)` before the exclusivity interrupt in `setCameraOffset(...)`.
- `replaceScene(...)` forwarding the interrupt callback without a standalone `interruptForExternalMutation()` statement.

### Optional: Resolution Rules
- A resolved call counts as the exclusivity guard only when it targets the declared `ensureExternalMutationAllowed` callback owned by the mutation-owner class.
- A resolved call counts as the interrupt only when it targets the declared `interruptForExternalMutation` callback owned by the mutation-owner class.
- A resolved call counts as the first boundary effect when it targets `SceneControllerMutationBoundary` and is not one of the explicitly allowed `setCameraOffset(...)` preflight calls.

## 9. Vertical Slices

### Slice 1. [ ] Semantic mutation-owner policy descriptors

#### Slice Contract
The mutation-owner policy table describes semantic sequencing expectations instead of statement slots, and selection mutation owners are enforced from that semantic policy.

#### Change
- Refactor `MutationOwnerPolicySpec` and the `selectionMutationOwnerPolicies` table so policy metadata names the required semantic guard kind instead of a numeric statement index.
- Replace the selection-owner branch of `_checkMutationOwnerPolicy(...)` with resolved detection of `ensureExternalMutationAllowed(...)` before the first boundary effect.
- Preserve current diagnostics at the `interactive API violation` level while shifting proof from syntax slot to semantic sequencing.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- Tool sandbox scenario that accepts a valid selection mutation owner even when a harmless local statement precedes `ensureExternalMutationAllowed(...)`.

#### Structural Verification
- Tool sandbox scenario that fails when `SceneControllerSelectionMutations` reaches `mutations.*` before the resolved `ensureExternalMutationAllowed(...)` callback.

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- `SceneControllerSelectionMutations` methods pass when the exclusivity callback resolves before the first boundary effect.
- A harmless local statement before the exclusivity callback does not fail the rule.

#### Negative Scenarios
- A selection mutation owner with no exclusivity callback fails.
- A selection mutation owner with a boundary delegate before the exclusivity callback fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Tool diagnostics point at the violating method body rather than at a statement-slot assumption.

### Slice 2. [ ] Semantic special-case sequencing for `setCameraOffset(...)` and `replaceScene(...)`

#### Slice Contract
Scene mutation owners accept the current semantic special forms for `setCameraOffset(...)` and `replaceScene(...)` without relying on positional or source-text matching.

#### Change
- Refactor `sceneMutationOwnerPolicies` so `setCameraOffset(...)` and `replaceScene(...)` are represented as semantic special cases.
- Replace `_isAllowedReplaceSceneInterruptForwarding(...)` with AST/resolved inspection of the named `interruptBeforeApply` argument.
- Replace the scene-owner branch of `_checkMutationOwnerPolicy(...)` with resolved sequencing that permits the locked `setCameraOffset(...)` preflight and requires the resolved interrupt before the first effectful camera-offset apply.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- Tool sandbox scenarios that accept the current `setCameraOffset(...)` preflight and the current `replaceScene(...)` forwarding shape.

#### Structural Verification
- Tool sandbox scenarios that fail when the interrupt occurs after `mutations.setCameraOffset(...)` or when `replaceScene(...)` forwards the wrong callback.

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- `setCameraOffset(...)` passes with `validateCameraOffset(...)`, `shouldApplyCameraOffset(...)`, optional early return, `interruptForExternalMutation()`, then `mutations.setCameraOffset(...)`.
- `replaceScene(...)` passes when `interruptBeforeApply` resolves to `interruptForExternalMutation`.

#### Negative Scenarios
- `setCameraOffset(...)` fails when `interruptForExternalMutation()` is missing or occurs after `mutations.setCameraOffset(...)`.
- `replaceScene(...)` fails when `interruptBeforeApply` forwards anything other than `interruptForExternalMutation`.
- A scene mutation owner that bypasses `SceneControllerMutationBoundary` still fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Tool diagnostics distinguish camera-offset sequencing failures from replace-scene forwarding failures.

### Slice 3. [ ] Semantic fixture and documentation surface

#### Slice Contract
Interactive mutation-owner tool regressions and repository documentation describe semantic sequencing rather than positional token matching.

#### Change
- Update `test/tool/support/guardrails_tool_test_support.dart` and `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` so fixture generation and assertions encode semantic allowed/disallowed forms.
- Update `doc/guardrails_state_map.md` to stop classifying the migrated mutation-owner path as token/source-order based.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_mutation_boundary_test.dart`

#### Structural Verification
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- Tool fixtures can encode current valid mutation-owner forms without a numeric statement slot.
- Runtime mutation-boundary proof stays green with no runtime code changes.

#### Negative Scenarios
- Tool regressions continue to fail for missing guards, late guards, invalid forwarding, and direct write bypass.
- Documentation no longer describes this migrated path as token/source-order based.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verification.
- Updated repository documentation records semantic sequencing as the proof surface for the migrated path.

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
