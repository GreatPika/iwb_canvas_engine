language: english

# Change Contract

## 1. Change Mandate
This change extracts shared semantic sequence-and-routing support for guardrails so repeated guard-before-effect and canonical invocation-routing proof stops living in separate family-specific walkers.

### Program End State
The end state for steps 119 through 126 is one symmetric guardrail architecture: rule families prove semantics through resolved analysis instead of token/lexical heuristics, repeated proof mechanics live in explicit shared support seams, runner ordering and shared state are declared through one inventory, and tool-test scaffolds plus their verification enforcement use canonical owned support seams.

### This Step's Role in the Chain
This step is the second cross-family consolidation pass: it turns migrated local sequence/routing mechanics into one explicit shared proof seam and extends the self-guard so later orchestration and test-layer steps inherit the same symmetric architecture.

## 2. Change Boundary

### Included in the Change
- Introduce one shared core support module for semantic sequence and resolved invocation-routing proof under `tool/src/guardrails/core/`.
- Migrate the interactive entrypoint guard scan in `tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart` onto the shared support.
- Migrate the interactive mutation-owner sequence/routing family locked by step 119 onto the shared support.
- Migrate the canonical controller selection-writer routing proof in `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` onto the shared routing support where the proof shape matches.
- Extend the step-122 self-guard seam so `semantic_sequence_routing_support.dart` and its intended consumers are mechanically protected against duplicate sequence engines, bypassed shared routing, and forbidden alias/dataflow expansion.
- Update affected tool regressions and `doc/guardrails_state_map.md` so the repository records one shared sequence/routing seam instead of repeated local walkers.

### Not Included in the Change
- Shared surface-contract extraction; that is locked in step 123.
- Declarative rule inventory and runner/state-map consolidation; that is locked in step 125.
- Tool-test scaffold normalization; that is locked in step 126.
- Full dataflow or CFG analysis for callback aliases or arbitrary mutation-owner control flow.
- Runtime behavior changes under `lib/src/**`.

## 3. Surrounding Code Review

### Inspected Artifacts
- `tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart` — current interactive-local semantic scan; already owns pure-prelude recognition and first-guard scanning, but the mechanics remain trapped in one family file.
- `plan/step_119_migrate_interactive_mutation_owner_guardrails_to_resolved_pre_effect_analysis.md` — step-119 contract already locks one shared local event model and routing proof family for interactive mutation owners and explicitly rejects alias/dataflow tracking; this is the strongest direct precursor for a shared sequence/routing support seam.
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` — current controller semantic migration target already includes resolved canonical selection-writer routing proof, which overlaps in proof shape with interactive resolved-routing checks even though the domain policy is different.
- `tool/src/guardrails/core/guardrail_element_utils.dart` — shared resolved target/owner helpers already available to both interactive and controller families.
- `tool/src/guardrails/core/resolved_surface_contract_support.dart` (locked by step 123) — adjacent shared proof seam for exact surface contracts; step 124 must complement it with sequence/routing support instead of mixing the two proof categories.
- `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart` (introduced by step 122 and extended by step 123) — the existing self-guard seam that must now cover the shared sequence/routing core and its consumer set.
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` — focused regression surface for interactive entrypoint guard scanning.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — interactive mutation-owner structural regression surface.
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` — controller routing regression surface for canonical selection writer helpers.
- `doc/guardrails_state_map.md` — current state map still reports internal overlap in interactive mutation checks and large bespoke families; it is the document that should record the shared sequence/routing seam once extracted.

### Current Entry Path
- `tool/check_guardrails.dart` -> `tool/src/guardrails/guardrails_runner.dart` -> `runInteractiveApiGuardrails(...)` / `runControllerApiGuardrails(...)`.

### Current Owner
- Sequence/routing proof is currently split across `resolved_entrypoint_guard_rules.dart`, the step-119 mutation-owner family, and controller resolved-routing checks in `write_only_mutation_rules.dart`.

### Adjacent Abstractions
- `guardrail_element_utils.dart` — shared resolved owner/target helpers.
- `resolved_surface_contract_support.dart` (step 123) — adjacent shared seam for non-sequence structural proof.

### Existing Tests
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart` — focused interactive entrypoint sequence regression surface.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — interactive mutation-owner regression surface.
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart` — controller routing regression surface.

### Analogous Implementation Path
- `tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart` — current same-family proof shape for pure-prelude plus required-guard scanning.
- `tool/src/guardrails/core/resolved_type_leak_traversal.dart` — precedent for lifting repeated traversal mechanics into shared core support while leaving rule-local classifiers in place.

### Governing Repository Rules
- `AGENTS.md` — fix repeated weaknesses at the owning shared layer and prefer explicit, debuggable solutions over ad hoc duplicated walkers.
- `AGENTS.md` — code changes must finish with `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`.
- `PLAN.md` — step 119 already locks direct callback forwarding only and rejects alias/dataflow tracking; step 124 must preserve that contract rather than widening analysis scope.
- `plan/step_122_close_resolved_guardrail_proof_surface_and_self_guard_regressions.md` — requires later consolidation steps to extend the same self-guard seam when they introduce new shared proof-support modules.

### Rejected Misleading Local Patterns
- Leaving `_scanEntrypointGuard(...)` as a one-family helper while adding a second independent event/route engine for mutation owners — wrong seam because the repository would keep two proof engines for the same sequence shape.
- Introducing callback alias/dataflow or mini-CFG tracking as the “shared” extraction — wrong level because the locked family contracts explicitly keep routing proof direct and structural.
- Moving domain-specific allowed forms into core support — wrong owner because the shared seam should own mechanics, while rule families still own policy and diagnostics.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Shared structural semantic sequence and resolved invocation-routing proof mechanics.

#### Selected Architectural Form
- One new core support module, `tool/src/guardrails/core/semantic_sequence_routing_support.dart`, owns reusable sequence evaluation, pure-prelude handling, direct resolved invocation matching, and direct callback-routing proof helpers.

#### Owning Layer or Module
- `tool/src/guardrails/core/semantic_sequence_routing_support.dart`.

#### Dependency Direction
- Interactive and controller rule families may depend on the shared sequence/routing support.
- The shared support may depend on analyzer APIs and `guardrail_element_utils.dart`.
- The shared support must not depend on rule-family policy tables or diagnostics.

#### State and Data Ownership
- Rule families own event classification, accepted-form specs, and violation wording.
- The shared support owns generic event-order evaluation and direct resolved routing/callback matching mechanics.
- Alias/dataflow state remains out of scope and is not introduced in the shared support.

#### Entry and Exit Boundaries
- Entry: rule-local semantic events, invocation expressions, and per-rule sequence/routing requirements.
- Exit: helper results and `GuardrailViolation` inputs consumed by the owning rule families.

#### Permitted Extension Seam
- Add new event-order or direct-routing helper capabilities only in `semantic_sequence_routing_support.dart` when more than one rule family needs the same proof shape.

#### Rejected Alternatives
- Keep separate bespoke walkers in interactive entrypoints, interactive mutation owners, and controller routing checks — rejected because the proof mechanics are already converging after steps 119 through 121.
- Build a general-purpose dataflow framework — rejected because the locked contracts call for direct structural routing proof, not broader soundness claims.

#### Why This Level Is Correct
- By this point the repository has multiple resolved, structural sequence/routing checks proving the same kind of thing: “safe prelude, required event, then canonical route.” The correct owner is a shared core mechanic layer that leaves event semantics local but prevents new family-specific walkers from diverging again.

## 5. File Map

### Implementation Files
- `tool/src/guardrails/core/semantic_sequence_routing_support.dart`
- `tool/src/guardrails/rules/interactive/resolved_entrypoint_guard_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_mutation_owner_guard_rules.dart`
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`
- `doc/guardrails_state_map.md`

### Test Files
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`

### Analysis Area
- `tool/src/guardrails/core/**`
- `tool/src/guardrails/rules/interactive/**`
- `tool/src/guardrails/rules/controller/**`
- `test/tool/guardrails/**`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. Shared semantic sequence/routing mechanics live in `tool/src/guardrails/core/semantic_sequence_routing_support.dart`, not in a rule-family file.
2. Rule families keep local event classification, accepted forms, and diagnostics; the shared support must not own domain policy.
3. Pure-prelude recognition and required-event-before-effect evaluation are extracted into the shared support where the proof shape matches.
4. Direct resolved invocation matching and direct callback-routing checks are extracted into the shared support where the proof shape matches.
5. Direct callback routing remains direct-only; callback alias/dataflow tracking is not introduced in this step.
6. Interactive entrypoint guards, interactive mutation-owner sequencing, and controller canonical selection-writer routing must converge on the shared sequence/routing support where their proof mechanics overlap.
7. The step-122 self-guard seam must be extended in this step so `semantic_sequence_routing_support.dart` itself and its intended consumer set become mechanically protected against duplicate walkers, bypassed shared routing, and forbidden alias/dataflow expansion.
8. Structural verification for this step is not satisfied by re-running existing family negatives alone; it must include a mechanical drift check that fails if consumer files keep or reintroduce family-local sequence engines after the shared seam lands.

## 7. Result Requirements

1. Interactive entrypoint guard scanning, interactive mutation-owner sequencing, and controller canonical routing no longer each own bespoke implementations of the same sequence/routing mechanics.
2. Rule-local accepted forms remain explicit, but shared support owns repeated prelude/order/routing mechanics.
3. Direct callback-forwarding proof remains structural and direct; alias or reassignment forwarding is still not recognized as valid.
4. `doc/guardrails_state_map.md` records the shared sequence/routing seam and no longer reports the same mechanics as family-local overlap.
5. `semantic_sequence_routing_support.dart` and its consumer set are covered by the step-122 self-guard seam, so duplicate sequence engines, bypassed shared routing, or alias/dataflow creep become mechanically visible.

## 8. Implementation Rules

### Analysis Scope
- Limit the extraction to repeated sequence/order/routing mechanics.
- Keep runtime behavior unchanged.
- Keep event semantics and allowed-form policy local to the rule families.

### Target Verification Units
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

### Protected States, Data, or Structures
- Interactive entrypoint resolver-purity guard sequence.
- Interactive mutation-owner guard-before-effect and direct replace-scene callback-forwarding contract.
- Canonical controller selection-writer routing through `writer.runtime.execute(...)`.

### Allowed Semantic Change Zones
- Shared sequence/routing core support.
- Rule-family use of shared sequence/routing support.
- Tool regressions and guardrail-state documentation for the affected families.

### Structural Enforcement
- The shared support must not depend on rule-family policy globals or diagnostics.
- Rule families must pass explicit callbacks/specs into shared support for event classification and violation construction.
- Direct callback-forwarding checks must stay resolved and direct-only.
- Do not introduce alias/dataflow or CFG machinery in the shared support.
- Extend `test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart` so it asserts `semantic_sequence_routing_support.dart` is the only shared sequence/routing mechanic owner, `resolved_entrypoint_guard_rules.dart`, `interactive_mutation_owner_guard_rules.dart`, and the canonical routing portion of `write_only_mutation_rules.dart` adopt the shared seam, and no consumer reintroduces a second local sequence engine or alias/dataflow helper.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_guardrail_implementation_tool_test.dart`
- Existing negative structural scenarios for missing guard, late guard, invalid direct routing, wrong callback forwarding, and wrong selection-writer op routing must remain failing.
- Existing positive structural scenarios for harmless prelude, canonical mutation-owner forms, and canonical selection-writer routing must remain green.
- Negative self-guard scenarios must fail when a consumer reintroduces a family-local sequence engine, when direct callback forwarding expands to alias/reassignment recognition, or when the shared sequence/routing support is bypassed.

### Prohibited
- Family-specific duplicate walkers for prelude/order/routing mechanics after the shared support is in place.
- Callback alias/dataflow tracking or CFG-style analysis.
- Moving rule-family accepted-form policy into the shared core support.

## 9. Vertical Slices

### Slice 1. [ ] Shared sequence/routing support subsumes interactive entrypoint guard mechanics

#### Slice Contract
Interactive entrypoint guard scanning uses shared sequence/routing support for pure-prelude and required-guard evaluation.

#### Change
- Add `semantic_sequence_routing_support.dart`.
- Refactor `resolved_entrypoint_guard_rules.dart` to express its pure-prelude and required-guard logic through the shared support.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`

#### Structural Verification
- Existing missing-guard and harmless-prelude scenarios in the interactive entrypoint tool suite remain mechanically visible after the extraction, and the self-guard suite must fail if entrypoint guard scanning keeps or regains a family-local sequence engine.

#### Fixtures Used
- `test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`

#### Positive Scenarios
- Canonical guarded public interactive entrypoints remain accepted.

#### Negative Scenarios
- Missing or late entrypoint guards still fail.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- `_scanEntrypointGuard(...)` no longer owns its own duplicated sequence engine.

### Slice 2. [ ] Interactive mutation-owner sequence/routing converges on shared support

#### Slice Contract
Interactive mutation-owner sequence/routing proof uses the same shared mechanics as interactive entrypoint guard scanning while preserving the step-119 direct-routing contract.

#### Change
- Refactor `interactive_mutation_owner_guard_rules.dart` to consume shared sequence/routing support for event order and direct routing validation.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Structural Verification
- Mutation-owner negative scenarios for missing guard, late guard, late interrupt, wrong direct callback forwarding, alias forwarding, and boundary bypass remain mechanically visible, and the self-guard suite must fail if mutation-owner proof reintroduces alias/dataflow or a second local routing engine.

#### Fixtures Used
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

#### Positive Scenarios
- Canonical mutation-owner standard forms, `setCameraOffset(...)`, and direct `replaceScene(...)` forwarding remain accepted.

#### Negative Scenarios
- Alias or reassigned callback forwarding still fails.
- Late effect ordering still fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Interactive mutation-owner proof no longer owns a family-local duplicate order/routing engine.

### Slice 3. [ ] Controller canonical routing uses the shared invocation-routing seam

#### Slice Contract
Controller canonical selection-writer routing uses the shared direct invocation-routing seam where the proof shape matches interactive direct-route validation.

#### Change
- Refactor the canonical selection-writer routing path in `write_only_mutation_rules.dart` to consume shared direct invocation-routing helpers from `semantic_sequence_routing_support.dart`.
- Update `doc/guardrails_state_map.md` to record the shared sequence/routing seam.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_controller_api_tool_test.dart`

#### Structural Verification
- Controller negative scenarios for wrong op routing remain mechanically visible after the extraction, and the self-guard suite must fail if controller canonical routing bypasses the shared sequence/routing seam.

#### Fixtures Used
- `test/tool/guardrails/guardrails_controller_api_tool_test.dart`

#### Positive Scenarios
- Canonical selection-writer helpers remain accepted.

#### Negative Scenarios
- Wrong op routing still fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- `doc/guardrails_state_map.md` records the shared sequence/routing seam.

## 10. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_resolved_entrypoint_guard_tool_test.dart`
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
