language: english

# Change Contract

## 1. Change Mandate
This change migrates interactive root and capability resolver-purity guardrails from token-order checks to resolved AST entrypoint analysis.

## 2. Change Boundary

### Included in the Change
- Resolved-AST replacement of the root `SceneController` public-entrypoint purity checks inside `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`.
- Resolved-AST replacement of the capability-owner purity checks for `SceneControllerInteractionOwner`, `SceneControllerSceneOwner`, and `SceneControllerSelectionOwner`.
- Tool-test updates that prove missing guards, late guards, and the `dispose(... allowAfterDispose: true)` exception from analyzer-backed rule logic.
- `doc/guardrails_state_map.md` updates that stop describing the migrated root/capability purity path as token/source-order backed.

### Not Included in the Change
- Mutation-owner sequencing in `SceneControllerSceneMutations` and `SceneControllerSelectionMutations`; that is locked in step 119.
- Interactive architecture-boundary migration from `boundary_shape_token_rules.dart`; that is locked in step 120.
- Removal of `tool/src/guardrails/rules/interactive/resolver_purity_rules.dart`; that deletion is locked in step 120 after its final callers are gone.
- Runtime behavior changes in `lib/src/interactive/**`.

## 3. Surrounding Code Review

### Inspected Artifacts
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` — current owner of `_checkRootEntrypoints(...)`, `_checkInteractiveEntrypointGuard(...)`, `_checkCapabilityEntrypoints(...)`, and `_checkCapabilityEntrypointGuard(...)`; current implementation still assumes exact block-body statement position.
- `tool/src/guardrails/rules/interactive/resolver_purity_rules.dart` — current source-token helper built around `source.contains`, `indexOf`, and `_maskNonCodeText`; this is the fragile seam that must stop owning root/capability purity proof.
- `tool/src/guardrails/support/guardrail_context.dart` — provides cached `ResolvedUnitResult` and `ResolvedLibraryResult`, which is the repository-native seam for resolved guardrail analysis.
- `tool/src/guardrails/rules/public/public_signature_rules.dart` — closest high-reliability precedent for repository-local guardrails that resolve libraries and inspect semantic targets instead of source text.
- `tool/src/guardrails/rules/controller/committed_read_side_rules.dart` — closest repository precedent for resolved executable/type leak checks that build diagnostics from analyzer elements.
- `lib/src/interactive/scene_controller.dart` — `SceneController` owns `_ensurePublicSideEffectAllowed(...)`; `dispose()` is the only public entrypoint that currently passes `allowAfterDispose: true`.
- `lib/src/interactive/scene_controller_interaction.dart` — `SceneControllerInteractionOwner` currently delegates through `_access.runtime.ensurePublicSideEffectAllowed(...)` before public pointer/config entrypoints.
- `lib/src/interactive/scene_controller_scene.dart` — `SceneControllerSceneOwner` uses a function-typed `ensurePublicSideEffectAllowed` field, so the guard check must support `FunctionExpressionInvocation`, not only `MethodInvocation`.
- `lib/src/interactive/scene_controller_selection.dart` — `SceneControllerSelectionOwner` currently delegates through `_runtime.ensurePublicSideEffectAllowed(...)` before public selection entrypoints.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — existing structural regression surface for missing purity guards, wrong guard placement, and invalid `allowAfterDispose` use.
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart` — runtime `INV-ENG-INTERACTIVE-RESOLVER-PURITY` witness that already proves effectful public interactive calls from `moveCommitDeltaResolver` throw before commit completes.
- `doc/guardrails_state_map.md` — records `resolver_purity_rules.dart` and parts of `mutation_boundary_rules.dart` as low-medium reliability and names AST migration as the next queue.

### Current Entry Path
- `tool/check_guardrails.dart` -> `tool/src/guardrails/guardrails_runner.dart` -> `runInteractiveApiGuardrails(...)` -> `_checkRootEntrypoints(...)` / `_checkCapabilityEntrypoints(...)`.

### Current Owner
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`.

### Adjacent Abstractions
- `tool/src/guardrails/rules/interactive/committed_read_callback_rules.dart` — policy table for mutation-owner exclusivity; same interactive rule family, different invariant.
- `tool/src/guardrails/rules/interactive/boundary_shape_token_rules.dart` — token-heavy interactive architecture checks that still consume `resolver_purity_rules.dart`; separate migration step.

### Existing Tests
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — current tool regression harness for resolver-purity diagnostics.
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart` — runtime proof that effectful public entrypoints invoked from `moveCommitDeltaResolver` are rejected before commit completes and gesture state is cleared.

### Analogous Implementation Path
- `tool/src/guardrails/rules/public/public_signature_rules.dart` — resolves libraries and traverses semantic types instead of matching source substrings.
- `tool/src/guardrails/rules/controller/committed_read_side_rules.dart` — resolves executable and interface surfaces from analyzer elements and reports violations from element identity.

### Governing Repository Rules
- `AGENTS.md` — any code change must finish with `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`.
- `AGENTS.md` — invariant definitions and proof metadata remain in `tool/invariant_registry.dart`; tool-only enforcement is not a substitute for runtime proof.
- `doc/guardrails_state_map.md` — the repository already classifies this family as low-medium reliability and explicitly prioritizes AST migration over more token matching.

### Rejected Misleading Local Patterns
- `tool/src/guardrails/rules/interactive/resolver_purity_rules.dart` — token scanning is the wrong proof owner for resolver purity because it proves spelling and source order instead of semantic guard ownership.
- Exact-first-statement guard enforcement in `mutation_boundary_rules.dart` — this is the wrong seam because it rejects semantically equivalent harmless leading scaffolding and still depends on syntactic slot position.
- Runtime purity tests as the only protection — this is the wrong level because it catches drift only after the structure already changed, while the repository expects a fail-fast guardrail at tool time.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Structural guardrail analysis of public interactive entrypoints.

#### Selected Architectural Form
- Resolved-AST entrypoint guard analysis inside the existing interactive guardrail runner, with guard recognition based on analyzer-resolved invocation targets and pre-effect statement inspection.

#### Owning Layer or Module
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`.

#### Dependency Direction
- The guardrail reads resolved interactive source units through `GuardrailContext`.
- The interactive runtime and tests do not take any dependency on tool internals.
- No new top-level tool entrypoint is introduced.

#### State and Data Ownership
- No runtime state changes.
- Guardrail-only policy state remains private to `mutation_boundary_rules.dart`.
- Runtime behavioral proof stays in `test/interactive/core/scene_controller_interactive_actions_effects_test.dart` and is not duplicated into tool logic.

#### Entry and Exit Boundaries
- Entry: resolved declarations for `SceneController`, `SceneControllerInteractionOwner`, `SceneControllerSceneOwner`, and `SceneControllerSelectionOwner`.
- Exit: `GuardrailViolation` diagnostics from `runInteractiveApiGuardrails(...)`.

#### Permitted Extension Seam
- Private helper functions inside `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` that classify guard invocations and first effectful owner interactions from AST nodes and resolved elements.

#### Rejected Alternatives
- Keep `resolver_purity_rules.dart` and swap token strings for different token strings — rejected because the invariant would still depend on source scanning instead of semantic ownership.
- Move resolver-purity enforcement into runtime tests only — rejected because the repository already expects interactive structural drift to fail in `check_guardrails.dart`.

#### Why This Level Is Correct
- Resolver purity is already enforced from `runInteractiveApiGuardrails(...)`, and the weak part is the analysis technique, not the owner module. Keeping the rule in the same module fixes fragility once without splitting policy across callers, tests, or runtime code.

## 5. File Map

### Implementation Files
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`
- `doc/guardrails_state_map.md`

### Test Files
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixtures and Supporting Data
- `test/tool/support/guardrails_tool_test_support.dart`

### Analysis Area
- `tool/src/guardrails/rules/interactive/**`
- `lib/src/interactive/{scene_controller,scene_controller_interaction,scene_controller_scene,scene_controller_selection}.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. `runInteractiveApiGuardrails(...)` remains the only tool owner for root and capability resolver-purity enforcement.
2. Root `SceneController` purity checks must resolve `_ensurePublicSideEffectAllowed(...)` from analyzer-backed invocation targets; `source.contains`, `indexOf`, `toSource`, `requireSourceTokens`, and `requireTokenOrder` are forbidden in this path.
3. Capability-owner purity checks must support both resolved `MethodInvocation` and resolved `FunctionExpressionInvocation`, because `SceneControllerSceneOwner` calls a function-typed field while the other capability owners call methods.
4. `dispose()` remains the only public entrypoint that may pass `allowAfterDispose: true`; every other public entrypoint must continue to reject that flag.
5. Compliance is defined as “the canonical purity guard resolves before the first effectful owner interaction,” not “the guard is the first statement.”
6. A pre-guard statement is allowed only when it is AST-local and side-effect free. Any resolved call or write that touches `_graph`, `_storeController`, `_access`, `_runtime`, `_mutations`, `sceneControllerGraph*`, capability delegates, or `super.dispose()` counts as effectful and must remain after the guard.
7. `resolver_purity_rules.dart` is not allowed to gain any new responsibility in this step.

## 7. Result Requirements

1. Root and capability resolver-purity guardrails pass and fail from resolved AST analysis only.
2. Missing purity guards, late purity guards, invalid `allowAfterDispose` use, and unguarded capability delegates remain mechanically visible through `check_guardrails.dart`.
3. Semantically harmless leading scaffolding that does not touch controller or capability owners is no longer rejected solely because it is not statement slot zero.
4. `doc/guardrails_state_map.md` stops describing root/capability resolver-purity enforcement as token/source-order backed.

## 8. Implementation Rules

### Analysis Scope
- Limit analysis to root `SceneController` public entrypoints and the three capability owners.
- Do not change mutation-owner policy handling in this step.
- Do not modify runtime behavior in `lib/src/interactive/**`.

### Target Verification Units
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

### Protected States, Data, or Structures
- Public `SceneController` entrypoint purity contract.
- Public capability-owner purity contract.
- `dispose(... allowAfterDispose: true)` exception contract.
- Existing runtime resolver-purity behavior proved by `INV-ENG-INTERACTIVE-RESOLVER-PURITY` tests.

### Allowed Semantic Change Zones
- Tool-side purity guard recognition.
- Tool-side diagnostic selection for missing and late guards.
- Tool-test scaffolds that prove valid and invalid guard placement.
- Reliability notes in `doc/guardrails_state_map.md`.

### Structural Enforcement
- Load parsed/resolved units through `GuardrailContext`.
- Resolve the canonical guard target from analyzer nodes instead of comparing textual invocation spellings.
- Inspect AST statement order only after each candidate call/write is classified semantically.
- Keep diagnostics emitted from `GuardrailViolation`; do not introduce a second tool result channel.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
- Negative structural scenarios for a missing guard, a guard after an effectful owner call, `allowAfterDispose: true` on a non-`dispose` entrypoint, and `dispose()` without `allowAfterDispose: true`.
- Positive structural scenarios for a direct canonical guard and for harmless leading scaffolding followed by the canonical guard.

### Prohibited
- Raw source scanning APIs in the migrated purity path.
- New top-level tool entrypoints for interactive purity.
- Moving purity policy into runtime code.
- Leaving statement-slot assumptions in tests after the rule becomes semantic.

### Optional: Recognition Forms That Must Be Supported
- Direct `_ensurePublicSideEffectAllowed(...)` invocation on `SceneController`.
- `_access.runtime.ensurePublicSideEffectAllowed(...)` on `SceneControllerInteractionOwner`.
- `ensurePublicSideEffectAllowed(...)` as a function-typed field invocation on `SceneControllerSceneOwner`.
- `_runtime.ensurePublicSideEffectAllowed(...)` on `SceneControllerSelectionOwner`.

### Optional: Allowed Forms That Are Not Violations
- A local variable declaration initialized from parameters, literals, or already-guarded getters before the purity guard.
- A pure branch that returns before any controller/capability owner interaction.
- `SceneController.dispose()` calling `_ensurePublicSideEffectAllowed(..., allowAfterDispose: true)`.

### Optional: Resolution Rules
- Guard recognition must compare resolved elements, not raw invocation text.
- A function-typed field invocation counts as the canonical guard only when the resolved element is the declared `ensurePublicSideEffectAllowed` field/getter owned by the capability owner.
- A method invocation counts as effectful when its resolved target belongs to a controller/capability owner delegate or writes to owner-held state before the purity guard.

## 9. Vertical Slices

### Slice 1. [ ] Resolved root `SceneController` purity analysis

#### Slice Contract
`_checkRootEntrypoints(...)` accepts and rejects `SceneController` public entrypoints from resolved guard-target and pre-effect analysis rather than statement-slot matching.

#### Change
- Replace the current first-statement `_interactiveGuardContext(...)` purity path with a resolved block-body walk that finds the first semantic purity guard and the first effectful owner interaction.
- Keep `dispose()` flag validation in the same rule path, but derive it from the resolved guard invocation.
- Preserve current diagnostic wording category (`interactive API violation`) while shifting the proof source from syntax slot to resolved analysis.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- Tool sandbox scenario that accepts a harmless local binding before `_ensurePublicSideEffectAllowed(...)`.

#### Structural Verification
- Tool sandbox scenario that fails when `_ensurePublicSideEffectAllowed(...)` appears after an effectful `sceneControllerGraph*` call or `_storeController` interaction.

#### Fixtures Used
- Existing sandbox harness in `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`.

#### Positive Scenarios
- A public `SceneController` method with the canonical `_ensurePublicSideEffectAllowed(...)` call before the first effectful owner interaction passes.
- A public `SceneController` method with a harmless local binding before the canonical guard passes.

#### Negative Scenarios
- A public `SceneController` method with no purity guard fails.
- A public `SceneController` method with the purity guard after an effectful owner interaction fails.
- `dispose()` without `allowAfterDispose: true` fails.
- Any non-`dispose` public entrypoint with `allowAfterDispose: true` fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Tool diagnostics point at the offending declaration line for missing and late guards.

### Slice 2. [ ] Resolved capability-owner purity analysis

#### Slice Contract
`_checkCapabilityEntrypoints(...)` accepts and rejects capability-owner entrypoints from resolved guard targets, including function-typed field invocation on `SceneControllerSceneOwner`.

#### Change
- Replace `_qualifiedInvocationNameFromStatement(...)` purity gating for capability owners with resolved guard recognition that supports `MethodInvocation` and `FunctionExpressionInvocation`.
- Detect the first effectful capability delegate call semantically instead of requiring the guard to be statement zero.
- Keep the current owner set (`SceneControllerInteractionOwner`, `SceneControllerSceneOwner`, `SceneControllerSelectionOwner`) unchanged.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- Tool sandbox scenario that accepts `SceneControllerSceneOwner` after a harmless local binding followed by `ensurePublicSideEffectAllowed(...)`.

#### Structural Verification
- Tool sandbox scenarios that fail when `_access.runtime`, `_mutations`, or `_runtime` are touched before the canonical guard in the corresponding capability owner.

#### Fixtures Used
- Existing sandbox harness in `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`.

#### Positive Scenarios
- Each capability owner passes with its canonical guard target before the first effectful delegate.
- `SceneControllerSceneOwner` passes when the canonical function-typed field invocation is used.

#### Negative Scenarios
- A capability owner with no canonical guard fails.
- A capability owner with a delegate call before the canonical guard fails.
- A capability owner that uses the wrong guard owner fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Tool diagnostics distinguish the offending capability owner and method.

### Slice 3. [ ] Tool regression surface matches the semantic purity contract

#### Slice Contract
Interactive tool regressions and repository documentation describe resolver purity as a semantic resolved-AST rule, not as a token/source-order rule.

#### Change
- Update `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` so the accepted and rejected cases map to semantic pre-effect analysis instead of statement-slot expectations.
- Update `doc/guardrails_state_map.md` so the migrated root/capability purity path is no longer described as token/source-order backed.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`

#### Structural Verification
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- Tool regressions accept semantically valid purity guards even when a harmless local statement precedes them.
- Runtime resolver-purity tests remain green without runtime code changes.

#### Negative Scenarios
- Tool regressions continue to fail for missing guards, late guards, and invalid `allowAfterDispose` usage.
- Documentation no longer claims this migrated path is token/source-order based.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verification.
- Updated repository documentation names resolved AST analysis as the proof surface for the migrated path.

## 10. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_interactive_actions_effects_test.dart`
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
