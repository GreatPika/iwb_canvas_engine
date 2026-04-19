language: english

# Change Contract

## 1. Change Mandate
This change registers guardrail rules declaratively so runner order, rule metadata, and state-map ownership stop drifting across separate manual lists.

### Program End State
The end state for steps 119 through 126 is one symmetric guardrail architecture: rule families prove semantics through resolved analysis instead of token/lexical heuristics, repeated proof mechanics live in explicit shared support seams, runner ordering and shared state are declared through one inventory, and tool-test scaffolds plus their verification enforcement use canonical owned support seams.

### This Step's Role in the Chain
This step makes the orchestration layer match the symmetric proof architecture built in steps 119 through 124: rule ordering, metadata, and shared runner state become explicit inventory-owned contracts before step 126 normalizes the test-support layer.

## 2. Change Boundary

### Included in the Change
- Introduce one ordered guardrail stage inventory under `tool/src/guardrails/`.
- Wire `tool/src/guardrails/guardrails_runner.dart` to evaluate rules from that inventory instead of from a hardcoded sequence of direct function calls.
- Activate `GuardrailRule` and `GuardrailRuleMetadata` as the repository-local metadata contract for active guardrail rule families.
- Introduce an explicit runner-state contract for cross-stage shared artifacts so the current `public surface -> public signature` handoff stops living as an implicit direct-call dependency inside `guardrails_runner.dart`.
- Add a dedicated tool regression that validates rule inventory uniqueness, invariant-id coverage against `tool/invariant_registry.dart`, and consistency between the inventory and the runner/state-map ownership that remains explicit in repository docs.
- Add at least one end-to-end tool scenario that exercises `tool/check_guardrails.dart` against a sandbox with multiple simultaneous violations so runner fail-fast behavior and inventory order are proved through the real entrypoint, not only through metadata assertions.
- Update `doc/guardrails_state_map.md` so its runner-entrypoint and invariant-to-rule sections align with the declarative inventory.

### Not Included in the Change
- Shared proof-support extraction; that is locked in steps 123 and 124.
- Tool-test scaffold normalization; that is locked in step 126.
- Runtime behavior changes under `lib/src/**`.
- Repository-wide generation of all documentation from code; this step reduces drift for guardrail rule inventory and state-map ownership only.

## 3. Surrounding Code Review

### Inspected Artifacts
- `tool/src/guardrails/core/guardrail_rule.dart` — current repository-local rule wrapper type; it exists but is not used by the runner today and currently has no way to express ordered shared state handoff.
- `tool/src/guardrails/core/guardrail_rule_metadata.dart` — current metadata value object; it also exists but is unused in active rule registration and currently models only one `invariantId`, which is too narrow for the real many-to-many family/invariant map.
- `tool/src/guardrails/guardrails_runner.dart` — current runner manually imports rule families and hardcodes evaluation order through direct top-level function calls.
- `tool/invariant_registry.dart` — machine-readable source of truth for invariant ids and proof ownership; guardrail rule metadata must stay aligned with these ids rather than inventing parallel identifiers ad hoc.
- `doc/guardrails_state_map.md` — current state map manually lists invariant-to-rule ownership and explicit runner entrypoints, and those sections are therefore prone to drift from the actual runner wiring.
- `tool/src/guardrails/rules/public/public_surface_rules.dart` — current public guardrail family entrypoint; it returns `PublicSurfaceGuardrailResult` and therefore already produces shared runner artifacts (`exportedSurfaces`) for a downstream stage.
- `tool/src/guardrails/rules/public/public_signature_rules.dart` — current public signature guardrail family entrypoint; it requires `exportedSurfaces` from the public-surface stage, proving that the runner already has an ordered cross-stage data dependency.
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` — current interactive guardrail family entrypoint.
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart` — current controller guardrail family entrypoint.
- `tool/src/guardrails/rules/model/model_architecture_rules.dart` — current model guardrail family entrypoint.
- `tool/src/guardrails/rules/contract/contract_architecture_rules.dart` — current contract guardrail family entrypoint.

### Current Entry Path
- `tool/check_guardrails.dart` -> `tool/src/guardrails/guardrails_runner.dart` -> hardcoded ordered rule-family calls.

### Current Owner
- Runner order is currently owned only by `guardrails_runner.dart`.
- Rule metadata types exist in `core/` but are not the active owner of rule registration.
- Cross-stage shared artifacts are currently owned only by ad hoc local variables in `guardrails_runner.dart`.
- `doc/guardrails_state_map.md` keeps a second manual description of rule ownership and runner entrypoints.

### Adjacent Abstractions
- `tool/invariant_registry.dart` — machine-readable proof inventory for invariants.
- `doc/guardrails_state_map.md` — human-facing rule ownership/state summary that currently mirrors runner wiring manually.

### Existing Tests
- There is currently no dedicated tool test that validates active guardrail rule inventory, metadata uniqueness, state-map alignment, or runner fail-fast order through `check_guardrails.dart`.

### Analogous Implementation Path
- `tool/invariant_registry.dart` — repository precedent for a machine-readable inventory that tool tests validate against structural rules.
- `tool/src/guardrails/core/guardrail_rule.dart` and `guardrail_rule_metadata.dart` — existing local abstractions that should become the active registration seam instead of remaining dead support types.

### Governing Repository Rules
- `AGENTS.md` — prefer mechanically enforced repository-local rules over prose-only guidance when recurring drift is visible.
- `AGENTS.md` — code changes must finish with `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`.
- `PLAN.md` — steps 123 and 124 already consolidate proof mechanics; step 125 must consolidate rule inventory/orchestration without reopening family-level semantics.

### Rejected Misleading Local Patterns
- Keeping `guardrails_runner.dart` as the only ordered rule inventory while also maintaining a separate manual state-map list — wrong seam because the repository would keep two unsynchronized ownership tables.
- Adding a second manual metadata table separate from `GuardrailRule`/`GuardrailRuleMetadata` — wrong level because the repository already has dedicated metadata types that should become the one active registration contract.
- Generating the whole state map from heuristics over the filesystem — wrong seam because the repository already knows the active rule inventory explicitly and should keep that inventory intentional.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Guardrail stage inventory, ordering, metadata ownership, and cross-stage shared-artifact handoff.

#### Selected Architectural Form
- One ordered inventory module, `tool/src/guardrails/guardrail_rule_inventory.dart`, exports the active ordered guardrail stages for the tool. Each stage is a `GuardrailRule` entry with plural invariant ownership metadata and an explicit run contract over a shared `GuardrailRunState`. The runner initializes the state once, executes the stages in inventory order, threads state forward, and keeps fail-fast behavior unchanged. The initial shared artifact scope is locked to the existing `exportedSurfaces` handoff from the public-surface stage to the public-signature stage.

#### Owning Layer or Module
- `tool/src/guardrails/guardrail_rule_inventory.dart`.
- `tool/src/guardrails/core/guardrail_run_state.dart`.

#### Dependency Direction
- Rule-family modules export `GuardrailRule` stage definitions or factories.
- `guardrail_rule_inventory.dart` imports rule-family modules and owns active stage order.
- `guardrails_runner.dart` imports only the inventory, not individual rule families.
- `guardrails_runner.dart` owns `GuardrailRunState` initialization and threads it through the ordered stages.
- Tests and documentation checks may read the inventory and the runner-state contract, but rule families must not depend on the runner.

#### State and Data Ownership
- Active stage ordering and per-stage metadata live only in `guardrail_rule_inventory.dart`.
- Cross-stage shared artifacts live only in `GuardrailRunState`.
- `PublicSurfaceGuardrailResult.exportedSurfaces` becomes the first explicit shared artifact stored in `GuardrailRunState`; the public-surface stage is its sole producer and the public-signature stage is its sole consumer.
- Invariant proof ownership remains in `tool/invariant_registry.dart`.
- `doc/guardrails_state_map.md` remains a documentation artifact, but its runner-entrypoint and invariant-to-rule sections must align with the declarative inventory.

#### Entry and Exit Boundaries
- Entry: active guardrail stage definitions plus invariant ids and the initial empty `GuardrailRunState`.
- Exit: ordered stage execution in `guardrails_runner.dart`, updated shared runner state, and failing inventory/state-map regression tests when drift is introduced.

#### Permitted Extension Seam
- Add a new active stage by defining/exporting a `GuardrailRule` in the owning family module, declaring its `invariantIds`, and then adding it to `guardrail_rule_inventory.dart`.
- Add a new shared runner artifact only by extending `GuardrailRunState` and explicitly locking its producer/consumer stages.

#### Rejected Alternatives
- Keep direct runner calls and add metadata only for documentation — rejected because runner/state-map drift would remain possible.
- Build a second registry separate from `GuardrailRule` and `GuardrailRuleMetadata` — rejected because the repository already has the right local types.

#### Why This Level Is Correct
- The problem is not inside one guardrail family; it is the orchestration seam itself. The correct owner is a single declarative stage inventory plus an explicit shared runner-state contract, because the repository already has ordered cross-stage behavior and at least one real shared artifact handoff (`exportedSurfaces`) that cannot be represented as independent stateless family calls without reintroducing implicit branches.

## 5. File Map

### Implementation Files
- `tool/src/guardrails/guardrail_rule_inventory.dart`
- `tool/src/guardrails/guardrails_runner.dart`
- `tool/src/guardrails/core/guardrail_rule.dart`
- `tool/src/guardrails/core/guardrail_rule_metadata.dart`
- `tool/src/guardrails/core/guardrail_run_state.dart`
- `tool/src/guardrails/rules/public/public_surface_rules.dart`
- `tool/src/guardrails/rules/public/public_signature_rules.dart`
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`
- `tool/src/guardrails/rules/controller/write_only_mutation_rules.dart`
- `tool/src/guardrails/rules/model/model_architecture_rules.dart`
- `tool/src/guardrails/rules/contract/contract_architecture_rules.dart`
- `doc/guardrails_state_map.md`

### Test Files
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`

### Analysis Area
- `tool/src/guardrails/**`
- `tool/invariant_registry.dart`
- `doc/guardrails_state_map.md`
- `test/tool/guardrails/**`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. `tool/src/guardrails/guardrail_rule_inventory.dart` becomes the single ordered inventory of active guardrail stages.
2. `GuardrailRule` and `GuardrailRuleMetadata` become active repository contracts, not dead support types.
3. `guardrails_runner.dart` must evaluate the inventory, not a parallel hardcoded list of rule-family calls.
4. Every active stage entry in the inventory must declare a stable rule id, `invariantIds`, area, and description.
5. Inventory `invariantIds` must resolve to real entries in `tool/invariant_registry.dart`, and the metadata shape must support many-to-many family/invariant ownership without forcing a one-stage/one-invariant fiction.
6. `doc/guardrails_state_map.md` runner-entrypoint and invariant-to-rule sections must stay aligned with the declarative inventory, and a dedicated tool test must make drift mechanically visible.
7. This step does not create a second invariant registry; invariant proof ownership remains in `tool/invariant_registry.dart`.
8. `GuardrailRunState` is the only allowed owner of cross-stage shared artifacts; the initial locked artifact is `exportedSurfaces`, produced by the public-surface stage and consumed by the public-signature stage.
9. Inventory/rule wiring verification is not complete until at least one end-to-end sandbox scenario proves that `check_guardrails.dart` still reports the first failing stage according to inventory order and still stops after the first violation.

## 7. Result Requirements

1. Active guardrail stage order is declared once in `guardrail_rule_inventory.dart` and no longer duplicated in `guardrails_runner.dart`.
2. `GuardrailRule`, `GuardrailRuleMetadata`, and `GuardrailRunState` are actively used by the guardrails tool.
3. The current `public surface -> public signature` shared-artifact handoff is explicit in `GuardrailRunState` rather than being an implicit direct-call dependency inside `guardrails_runner.dart`.
4. A dedicated inventory regression fails when rule ids collide, when inventory invariant ids are unknown, when the documented runner/state-map ownership drifts from the inventory, when the producer/consumer contract for `exportedSurfaces` drifts, or when the real tool entrypoint stops honoring inventory order and fail-fast semantics.
5. `doc/guardrails_state_map.md` runner-entrypoint and invariant-to-rule sections reflect the declarative inventory rather than a hand-maintained runner list.

## 8. Implementation Rules

### Analysis Scope
- Limit the change to guardrail rule inventory/orchestration and state-map alignment.
- Keep rule-family semantics unchanged.
- Keep invariant proof ownership in `tool/invariant_registry.dart`.
- Keep the current `exportedSurfaces` dataflow semantics unchanged while making that handoff explicit in runner state.

### Target Verification Units
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

### Protected States, Data, or Structures
- Active rule execution order in the guardrails tool.
- The ordered `public surface -> public signature` handoff of `exportedSurfaces`.
- Invariant-id ownership in `tool/invariant_registry.dart`.
- Documented guardrail runner/invariant-to-rule ownership in `doc/guardrails_state_map.md`.

### Allowed Semantic Change Zones
- Guardrail rule inventory and metadata wiring.
- Runner orchestration over the active inventory.
- Documentation of runner ownership and invariant-to-rule mapping.
- Tool regression coverage for inventory/state-map drift.

### Structural Enforcement
- `guardrails_runner.dart` must import the inventory module, not individual rule-family entrypoints.
- Rule inventory metadata must be explicit in code, not inferred from filenames.
- The dedicated inventory test must validate rule-id uniqueness, invariant-id existence, documented runner/state-map alignment, and the explicit producer/consumer contract for `GuardrailRunState.exportedSurfaces`.
- The dedicated inventory test must also execute `check_guardrails.dart` on a sandbox with more than one simultaneous violation and assert that the reported failure corresponds to the first inventory entry that should fail.
- Keep `tool/invariant_registry.dart` as the source of truth for invariant ids; do not duplicate invariant metadata into the rule inventory beyond the required invariant id reference.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
- `dart run tool/check_invariant_coverage.dart`
- Negative structural scenarios for duplicate rule ids, unknown invariant ids, state-map sections that drift from the declarative inventory, a broken `exportedSurfaces` producer/consumer contract, and a sandbox where multiple rule families could fail but the tool must still report only the earliest failing stage in inventory order.

### Prohibited
- A parallel hardcoded rule-order list in `guardrails_runner.dart`.
- A second manual guardrail metadata table separate from `GuardrailRule` / `GuardrailRuleMetadata`.
- Heuristic reconstruction of rule inventory from the filesystem in place of explicit registration.

## 9. Vertical Slices

### Slice 1. [ ] Declarative guardrail stage inventory replaces direct runner wiring and locks the public-surface handoff

#### Slice Contract
The guardrails tool evaluates an explicit ordered inventory of `GuardrailRule` stages instead of hardcoded direct family calls, and the current `public surface -> public signature` handoff is made explicit in runner state.

#### Change
- Add `guardrail_rule_inventory.dart`.
- Add `guardrail_run_state.dart`.
- Export active `GuardrailRule` stage entries from each guardrail family.
- Refactor `guardrails_runner.dart` to iterate the inventory and thread `GuardrailRunState`, with `exportedSurfaces` written by the public-surface stage and read by the public-signature stage.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`

#### Structural Verification
- `guardrails_rule_inventory_tool_test.dart` must include an end-to-end `check_guardrails.dart` sandbox scenario that proves inventory order and fail-fast behavior through the real runner entrypoint, plus a structural scenario that fails when the public-signature stage no longer receives `exportedSurfaces` from runner state.

#### Fixtures Used
- None.

#### Positive Scenarios
- The active rule families still execute in the intended order.
- A sandbox with two simultaneous violations still reports the earlier inventory rule and stops there.
- The public-signature stage still receives the exported surface data produced by the public-surface stage without recomputing it locally.

#### Negative Scenarios
- There is no second hardcoded order list left in the runner.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- `guardrails_runner.dart` imports the inventory instead of individual rule-family entrypoints.

### Slice 2. [ ] Inventory metadata is mechanically aligned with many-to-many invariant ownership

#### Slice Contract
The declarative inventory fails mechanically when stage metadata drifts from the repository’s many-to-many family/invariant ownership.

#### Change
- Add `guardrails_rule_inventory_tool_test.dart`.
- Widen guardrail metadata to represent `invariantIds`.
- Validate rule-id uniqueness and invariant-id existence against `tool/invariant_registry.dart`.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`

#### Structural Verification
- `dart run tool/check_invariant_coverage.dart`

#### Fixtures Used
- None.

#### Positive Scenarios
- Every active stage references only real invariant ids and may legitimately map to more than one invariant.

#### Negative Scenarios
- Duplicate rule ids fail.
- Unknown invariant ids fail.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Inventory metadata is mechanically checked against the invariant registry.

### Slice 3. [ ] State-map runner and invariant ownership stay aligned with the inventory

#### Slice Contract
`doc/guardrails_state_map.md` runner-entrypoint and invariant-to-rule sections stay aligned with the declarative inventory.

#### Change
- Update `doc/guardrails_state_map.md`.
- Extend `guardrails_rule_inventory_tool_test.dart` so documented runner-entrypoint and invariant-to-rule sections are checked against the declarative inventory.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`

#### Structural Verification
- A changed inventory or changed state-map section fails when the other side is not updated to match.

#### Fixtures Used
- `doc/guardrails_state_map.md`

#### Positive Scenarios
- Runner-entrypoint and invariant-to-rule sections match the active inventory.

#### Negative Scenarios
- Manual documentation drift fails mechanically.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- `doc/guardrails_state_map.md` reflects the declarative inventory.

## 10. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`
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
