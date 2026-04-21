# Change Contract

## 1. Change Mandate

This change migrates repository verification to an executable two-owner proof architecture where invariants declare required versus regression proof surfaces, verification graph data has one owner, and markdown documents are fully removed from the machine-checked contour.

## 2. Change Boundary

### Included in the Change

- Remove `AGENTS.md` references and `doc/guardrails_state_map.md` dependencies from every executable checker, parser, and regression test.
- Replace the current invariant proof schema so required proofs reference real executable verification steps and regression proofs stop acting as canonical required evidence.
- Consolidate verification step, preset, trigger, and workflow expectation ownership under one graph owner in `tool/src/verification_contract/**`.
- Make `tool/check_invariant_coverage.dart` validate required-proof reachability through the required code-change contour.
- Keep workflow YAML files hand-authored and validate them against the graph-owned executable contract.
- Preserve downstream machine consumers that rely on verification step ids, including coverage scope suggestions.

### Not Included in the Change

- No changes to `lib/src/**` runtime behavior, scene semantics, or public package API.
- No edits to `AGENTS.md`; it remains out-of-scope human-only text and is not part of this executable contract change.
- No workflow YAML generation.
- No trigger-surface widening as a workaround for unreachable required proofs.
- No return to parsing prose or markdown as machine input.
- No redesign of guardrail rule semantics beyond retiring markdown state-map parsing.

## 3. Surrounding Code Review

### Inspected Artifacts

- `tool/invariant_registry.dart` — current invariant owner; today it exposes `primaryProof` plus optional `toolProof`, which makes tool regression tests look like canonical required proof surfaces.
- `tool/check_invariant_coverage.dart` — validates proof paths and `// INV:<id>` markers, but currently does not validate whether required proof surfaces are reachable from the required verification contour.
- `tool/src/verification_contract/verification_contract_registry.dart` — current owner of step ids, preset membership, trigger entries, and workflow expectations, but it stores them as parallel manual lists.
- `tool/src/verification_contract/verification_contract_resolver.dart` — resolves `required_code_change` from `requiredCodeChangeStepIds` and conditionally appends `tool_tests` from trigger matching.
- `tool/check_verification_contract.dart` — currently mixes executable workflow checks with markdown parsing for `AGENTS.md`.
- `.github/workflows/ci.yaml` — hand-authored executable projection of CI steps and tool-test trigger filters.
- `.github/workflows/perf_nightly.yaml` — hand-authored executable projection of nightly performance and fuzz runs.
- `test/tool/invariant_coverage_tool_test.dart` — current regression suite for proof-path and marker validation.
- `test/tool/run_verification_preset_tool_test.dart` — current resolver contract suite; today it does not lock the full ordered required preset.
- `test/tool/verification_contract_tool_test.dart` — current workflow contract suite; today it encodes the markdown parsing seam and only partial nightly coverage.
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart` — current guardrail inventory suite; today it parses `doc/guardrails_state_map.md`, which is the wrong machine owner.
- `tool/src/check_coverage/coverage_test_target_locator.dart` — downstream machine consumer of `verificationScopeStepIds`, so graph-owner changes must preserve stable scope resolution.
- `tool/src/guardrails/guardrail_rule_inventory.dart` and `tool/src/guardrails/guardrails_runner.dart` — closest valid precedent for a declarative owner module consumed by an executor without direct hard-coded stage calls.

### Current Entry Path

- `tool/run_verification_preset.dart` -> `parseVerificationInvocation(...)` -> `resolveVerificationPlan(...)` -> `tool/src/verification_contract/verification_contract_resolver.dart`.
- `tool/check_invariant_coverage.dart` -> `tool/invariant_registry.dart`.
- `tool/check_verification_contract.dart` -> `tool/src/verification_contract/verification_contract_registry.dart` -> workflow YAML and, today, markdown documents.

### Current Owner

- Invariant ids and declared proof surfaces currently live in `tool/invariant_registry.dart`.
- Executable verification steps, presets, triggers, and workflow expectations currently live in `tool/src/verification_contract/verification_contract_registry.dart`.
- Two non-owners are incorrectly part of the machine contour today: `AGENTS.md` and `doc/guardrails_state_map.md`.

### Adjacent Abstractions

- `tool/src/verification_contract/verification_contract_models.dart` — invocation and resolved-plan models used by the verification CLI.
- `tool/src/verification_contract/verification_contract_runner.dart` — executor for resolved step plans.
- `tool/run_tool_tests.dart` — dedicated tool-test executor that must remain a regression path, not a canonical required-proof owner.
- `tool/src/check_coverage/coverage_machine_report.dart` — downstream machine output that carries preferred verification scope ids.

### Existing Tests

- `test/tool/invariant_coverage_tool_test.dart` — proves current proof-path shapes, marker coverage, and `toolProof` field rules.
- `test/tool/run_verification_preset_tool_test.dart` — proves resolve/run CLI behavior, conditional tool-test scheduling, and explicit tool-test file selection.
- `test/tool/verification_contract_tool_test.dart` — proves workflow drift detection and, today, the unwanted markdown seam.
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart` — proves inventory immutability, ownership, and runner-state contracts; today it also proves the unwanted markdown seam.
- `test/tool/coverage_tool_test.dart` — proves stable preferred verification scope ids in machine coverage output.

### Analogous Implementation Path

- `tool/src/guardrails/guardrail_rule_inventory.dart` plus `tool/src/guardrails/guardrails_runner.dart` — the repository already uses a declarative inventory owner consumed by a runner; this is the closest valid precedent for moving verification graph data behind one executable owner instead of spreading parallel lists across consumers.

### Governing Repository Rules

- Root repository instructions — codebase-specific machine contracts must come from repository-owned executable sources, not ad hoc chat state.
- `PLAN.md` — each step must have a dedicated document; execution contracts belong in the linked step file, not in the index.
- User instruction in this request — remove `AGENTS.md` and `doc/guardrails_state_map.md` from the machine contour; keep only `tool/invariant_registry.dart` and `tool/src/verification_contract/**` as owners; do not patch symptoms by widening trigger surfaces or keeping the old `primaryProof + toolProof` model.
- User instruction in this request — before each fix, first lock the bug with one failing test and add one to three guard tests for neighboring branches of the same contract.

### Rejected Misleading Local Patterns

- `tool/check_verification_contract.dart` parsing `AGENTS.md` — wrong owner and wrong abstraction level because prose is not executable contract data.
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart` parsing `doc/guardrails_state_map.md` — wrong owner because a temporary markdown file is not a machine registry.
- `tool/invariant_registry.dart` treating `test/tool/**` as `primaryProof` for tool-backed invariants — wrong proof role because those files are conditional regression surfaces, not guaranteed required proof execution.
- Expanding `toolTestTriggerEntries` to cover more `lib/src/**` paths — wrong fix level because it patches scheduling symptoms without fixing the proof model.
- Generating workflow YAML from Dart definitions — unnecessary complexity for this repository; hand-authored YAML plus executable drift validation is sufficient.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- Cross-cutting verification proof orchestration and structural-analysis contract ownership.

#### Selected Architectural Form

- A two-owner executable architecture:
- `tool/invariant_registry.dart` owns only invariant ids and their role-based proof declarations.
- `tool/src/verification_contract/**` owns only the executable verification graph: step definitions, preset membership, trigger policy, and workflow expectations.
- Checkers, resolvers, coverage tooling, and workflows consume these owners but do not introduce independent truth.

#### Owning Layer or Module

- Invariant proof ownership: `tool/invariant_registry.dart`.
- Verification graph ownership: `tool/src/verification_contract/verification_contract_registry.dart` together with its existing resolver/models consumers inside `tool/src/verification_contract/**`.
- Drift-check consumers: `tool/check_invariant_coverage.dart`, `tool/check_verification_contract.dart`, `tool/run_verification_preset.dart`, and `tool/src/check_coverage/coverage_test_target_locator.dart`.

#### Dependency Direction

- `tool/invariant_registry.dart` may reference verification step ids as plain stable strings, but it must not depend on verification graph implementation types or on markdown documents.
- `tool/src/verification_contract/**` owns executable step ids and graph derivations and must not depend on markdown documents.
- `tool/check_invariant_coverage.dart` is the only place that joins invariant proof declarations with verification graph reachability.
- `tool/check_verification_contract.dart`, `tool/src/check_coverage/coverage_test_target_locator.dart`, and `tool/src/verification_contract/verification_contract_resolver.dart` consume graph-owned projections rather than maintaining parallel local lists.
- `.github/workflows/*.yaml` remain external executable adapters validated against the graph; the graph does not depend on workflow contents for truth.

#### State and Data Ownership

- Invariant ids, titles, scopes, required proof declarations, and regression proof declarations are owned by `tool/invariant_registry.dart`.
- Verification step ids, preset expansion, trigger surfaces, scope step ids, and workflow run expectations are owned by `tool/src/verification_contract/verification_contract_registry.dart`.
- Markdown documents own no machine state.

#### Entry and Exit Boundaries

- Entry boundaries:
- `tool/check_invariant_coverage.dart` reads invariants plus verification graph reachability.
- `tool/run_verification_preset.dart` and `tool/src/verification_contract/verification_contract_resolver.dart` read the verification graph.
- `tool/check_verification_contract.dart` reads workflows and compares them against graph-derived expectations.
- `tool/src/check_coverage/coverage_test_target_locator.dart` reads graph-owned scope ids.
- Exit boundaries:
- resolved verification plans;
- invariant coverage and reachability diagnostics;
- workflow drift diagnostics;
- coverage machine-report preferred scope ids.

#### Permitted Extension Seam

- New invariant proof requirements may be added only by extending the role-based proof declarations in `tool/invariant_registry.dart`.
- New steps, presets, triggers, workflow expectations, or scope projections may be added only through `tool/src/verification_contract/verification_contract_registry.dart`.
- New executable drift checks may only consume these owners; they may not invent additional registries in markdown or ad hoc local lists.

#### Rejected Alternatives

- Keep `primaryProof + toolProof` and reinterpret them in prose — rejected because the schema itself cannot distinguish mandatory reachable evidence from regression-only surfaces.
- Widen `toolTestTriggerEntries` or always run `tool_tests` — rejected because it patches scheduling symptoms instead of fixing proof-role ownership.
- Keep parsing `AGENTS.md` or `doc/guardrails_state_map.md` — rejected because prose and temporary notes are not executable truth.
- Generate workflow YAML from Dart graph data — rejected because hand-authored workflow files are already acceptable if graph-driven drift validation stays authoritative.

#### Why This Level Is Correct

- The defect is not inside any one workflow or one invariant; it is the mismatch between what is declared as proof and what the repository actually executes. That ownership belongs at the boundary between the invariant registry and the verification graph, not in prose files, not in workflow-only patches, and not in individual tool tests. This level fixes the model once and keeps future drift mechanically visible.

## 5. Locked Decisions

1. `AGENTS.md` and `doc/guardrails_state_map.md` are removed from the machine-checked contour and will not be parsed, validated, or treated as executable contract inputs. `AGENTS.md` remains untouched by this change.
2. The current `primaryProof` plus optional `toolProof` schema is retired. The successor invariant schema is the minimal sufficient split:
   `requiredProofs`, where each entry declares a repo-relative proof path and the executable verification `stepId` that must run it; and `regressionProofs`, where each entry declares only a repo-relative executable proof path.
3. Required proofs may point to top-level `tool/*.dart` files or executable `test/**/*_test.dart` files, but each required proof must contain a matching `// INV:<id>` marker and reference a real verification graph step.
4. Regression proofs are never used to satisfy required-proof reachability. Tool regression tests remain regression surfaces only.
5. `tool/src/verification_contract/verification_contract_registry.dart` becomes the single graph owner for steps, presets, triggers, scope-step ids, and workflow expectations. Resolver, workflow drift checks, and coverage scope suggestions consume graph-derived projections from that owner.
6. Workflow YAML files stay hand-authored and are validated against graph-derived expectations.

## 6. Result Requirements

1. No executable checker, parser, or regression test reads `AGENTS.md` or `doc/guardrails_state_map.md` as machine input.
2. Every invariant required proof resolves to an existing verification graph step and is reachable through the required code-change contour; regression-only proofs do not participate in that reachability contract.
3. `required_code_change`, scope step ids, tool-test triggers, and workflow expectations all come from one graph owner with no parallel manual truth lists left behind in consumers.
4. `tool/check_verification_contract.dart` validates only executable workflow contract data against the graph and no longer contains markdown-specific logic.
5. Downstream machine consumers such as coverage scope suggestions continue to resolve stable verification step ids from the graph owner.

## 7. Execution Order and Gates

### Required Order

- First, remove markdown-based machine seams and lock that retirement with failing tests plus guard tests.
- Second, consolidate executable verification graph ownership and migrate resolver, workflow drift checking, and coverage scope consumers to graph-derived projections.
- Third, migrate invariant proof declarations to the role-based schema and add required-proof reachability checks once graph step ids are stable.
- Only after the successor seams are live may the old proof fields, markdown parsers, and parallel list seams be deleted.

### Successor Seam and Retirement Gates

- Markdown machine seam retirement:
  `_checkAgents(...)`, `agentsVerificationInstruction`, markdown extraction helpers, `parseDocumentedInventory(...)`, `parseDocumentedInvariantMap(...)`, and the `doc/guardrails_state_map.md` dependency may be retired only after verification and guardrail inventory tests prove executable behavior without markdown inputs.
- Verification graph successor seam:
  graph-derived preset membership, trigger projections, scope step ids, and workflow expectations must be consumed by `verification_contract_resolver.dart`, `check_verification_contract.dart`, and `coverage_test_target_locator.dart` before any old parallel list seam is removed.
- Invariant proof successor seam:
  `requiredProofs` plus `regressionProofs` may replace `primaryProof` plus `toolProof` only after `tool/check_invariant_coverage.dart` and its test suite prove marker validation and required-contour reachability under the new schema.

### Deferred Broad Verification

- Full `required_code_change` execution is reserved for the final gate after all successor seams are live, because it is the broadest and most expensive proof of the integrated contract.
- Full targeted tool-test execution for the affected suites is reserved for the final gate after all slices are closed.

## 8. File Map

### Implementation Files

- `tool/invariant_registry.dart`
- `tool/check_invariant_coverage.dart`
- `tool/check_verification_contract.dart`
- `tool/src/verification_contract/verification_contract_registry.dart`
- `tool/src/verification_contract/verification_contract_models.dart`
- `tool/src/verification_contract/verification_contract_resolver.dart`
- `tool/src/check_coverage/coverage_test_target_locator.dart`

### Test Files

- `test/tool/invariant_coverage_tool_test.dart`
- `test/tool/run_verification_preset_tool_test.dart`
- `test/tool/verification_contract_tool_test.dart`
- `test/tool/coverage_tool_test.dart`
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`

### Fixtures and Supporting Data

- Existing inline sandbox fixtures inside `test/tool/run_verification_preset_tool_test.dart`
- Existing inline sandbox fixtures inside `test/tool/verification_contract_tool_test.dart`
- Existing inline sandbox fixtures inside `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`

### Registry, Inventory, and Workflow Files

- `.github/workflows/ci.yaml`
- `.github/workflows/perf_nightly.yaml`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Analysis Area

- `tool/invariant_registry.dart`
- `tool/src/verification_contract/**`
- `tool/src/check_coverage/**`
- `tool/check_*.dart`
- `test/tool/**`
- `.github/workflows/*.yaml`

## 9. Implementation Rules

### Protected Invariants

- Invariant ids and `// INV:<id>` markers remain the canonical invariant claim mechanism.
- `required_code_change` continues to require explicit changed paths as input.
- `tool_tests` remains a conditional regression step for tool-impacting changes only.
- Workflow YAML files remain hand-authored.
- Coverage machine reports continue to emit graph-owned preferred verification scope ids.

### Required Proof

- behavioral proof: before each slice owner change, add one failing regression test that captures the slice’s target bug and add one to three guard tests that lock neighboring branches of the same contract.
- structural proof: each slice must leave behind an executable drift detector that would fail if the retired seam reappears or if a consumer reintroduces independent truth.

### Allowed Change Surface

- Role-based proof declarations in `tool/invariant_registry.dart`
- Graph-owned projections in `tool/src/verification_contract/verification_contract_registry.dart`
- Consumers that read graph-owned data: resolver, workflow drift checker, coverage scope locator
- Retirement of markdown parsing helpers and the temporary markdown state-map file

### Forbidden Moves

- Parsing any markdown file from an executable checker or regression suite
- Reintroducing `primaryProof + toolProof`
- Treating a regression-only proof as sufficient required proof
- Widening `toolTestTriggerEntries` as a substitute for proof-role repair
- Generating workflow YAML
- Leaving duplicate preset, trigger, scope, or workflow lists in consumers after the graph owner exists

### Optional: Resolution Rules

- A required proof path must be repo-relative POSIX and must resolve either to a top-level `tool/*.dart` file or to an executable `test/**/*_test.dart` file.
- A regression proof path must be repo-relative POSIX and must resolve to an executable proof file with a matching `// INV:<id>` marker.
- A required proof `stepId` must resolve through the verification graph owner and must be included in the expanded `required_code_change` contour.
- Workflow drift expectations must be derived from graph-owned step and trigger data rather than copied into independent test fixtures or checker-local lists.

## 10. Vertical Slices

### Slice 1. [ ] Retire Markdown Machine Inputs

#### Slice Contract

Executable verification no longer depends on `AGENTS.md` or `doc/guardrails_state_map.md`, and regression tests prove that missing or edited markdown does not affect machine contract evaluation.

#### Change

Start by adding one failing verification-contract test that proves `check_verification_contract.dart` must ignore `AGENTS.md`, plus one to three guard tests that lock workflow-only drift behavior and guardrail inventory behavior without markdown parsing. Then remove `_checkAgents(...)`, markdown helpers, `agentsVerificationInstruction`, the state-map parsing assertions, and the `doc/guardrails_state_map.md` machine seam. Delete `doc/guardrails_state_map.md` because it is an acknowledged temporary file, not an executable artifact.

#### Behavioral Verification

- `test/tool/verification_contract_tool_test.dart`
- `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`

#### Structural Verification

- Add a regression that fails if `tool/check_verification_contract.dart` reintroduces `AGENTS.md` handling.
- Add a regression that fails if the guardrail inventory suite reintroduces `doc/guardrails_state_map.md` parsing.

#### Fixtures Used

- Inline workflow sandbox fixtures in `test/tool/verification_contract_tool_test.dart`
- Inline guardrail sandbox fixtures in `test/tool/guardrails/guardrails_rule_inventory_tool_test.dart`

#### Positive Scenarios

- Missing `AGENTS.md` does not fail executable verification contract checks.
- Workflow drift still fails when CI or nightly executable entries diverge.
- Guardrail inventory ownership and runner-state tests remain green without any markdown file.

#### Negative Scenarios

- Reintroducing a markdown parser into a checker or regression suite causes the new retirement regressions to fail.
- Retaining `doc/guardrails_state_map.md` parsing keeps the slice open.

#### Closure Evidence

- New markdown-retirement regressions fail before the change and pass after the retirement.
- Existing executable workflow and guardrail inventory regressions remain green.

### Slice 2. [ ] Unify Executable Verification Graph Ownership

#### Slice Contract

One graph owner defines steps, preset membership, trigger policy, scope step ids, and workflow expectations, and all machine consumers resolve those projections from that owner instead of maintaining parallel lists.

#### Change

Start by adding one failing resolver test that locks the full ordered `required_code_change` plan and one to three guard tests that lock trigger derivation, workflow expectation derivation, and stable coverage scope ids. Then refactor `tool/src/verification_contract/verification_contract_registry.dart` into the single graph owner for steps, presets, triggers, scope projections, and workflow expectations. Migrate `verification_contract_resolver.dart`, `check_verification_contract.dart`, and `coverage_test_target_locator.dart` to consume graph-derived projections and retire the old parallel-list seams only after every consumer is migrated.

#### Behavioral Verification

- `test/tool/run_verification_preset_tool_test.dart`
- `test/tool/verification_contract_tool_test.dart`
- `test/tool/coverage_tool_test.dart`

#### Structural Verification

- Add a regression that fails if resolver or workflow checks depend on local parallel step or trigger lists instead of graph-derived projections.
- Add a regression that fails if coverage scope suggestions drift from graph-owned scope ids.

#### Fixtures Used

- Inline verification CLI sandbox fixtures in `test/tool/run_verification_preset_tool_test.dart`
- Inline workflow sandbox fixtures in `test/tool/verification_contract_tool_test.dart`

#### Positive Scenarios

- The full ordered `required_code_change` plan resolves deterministically from graph-owned data.
- Tool-test trigger expectations stay aligned between resolver and CI workflow drift checks.
- Coverage gaps still emit the expected preferred step ids.

#### Negative Scenarios

- Removing or reordering a middle required step causes the new preset regression to fail.
- Diverging workflow expected runs or trigger surfaces from graph-owned data causes workflow regressions to fail.

#### Closure Evidence

- New graph-owner regressions fail before the change and pass after migration.
- Existing resolver, workflow, and coverage regressions remain green.

### Slice 3. [ ] Enforce Role-Based Invariant Proof Reachability

#### Slice Contract

Invariants declare required proofs versus regression proofs under a minimal schema, tool regression tests no longer count as canonical required proof, and `tool/check_invariant_coverage.dart` rejects any required proof that is not reachable through the required verification contour.

#### Change

Start by adding one failing invariant-coverage test that captures the current bug: a tool-backed invariant that points its required proof at a conditional tool regression surface must be rejected. Add one to three guard tests for neighboring branches: a runtime required proof tied to a scope step remains valid, a top-level tool enforcement proof tied to an always-run step remains valid, and regression proofs still require explicit markers. Then replace `primaryProof` plus `toolProof` in `tool/invariant_registry.dart` with the minimal `requiredProofs` plus `regressionProofs` schema, migrate affected invariant entries, and extend `tool/check_invariant_coverage.dart` to validate path shape, marker presence, step existence, and required-contour reachability.

#### Behavioral Verification

- `test/tool/invariant_coverage_tool_test.dart`
- `test/tool/run_verification_preset_tool_test.dart`

#### Structural Verification

- Add a regression that fails if a regression-only proof is treated as satisfying required-proof reachability.
- Add a regression that fails if a required proof references an unknown step id or a step outside the required contour.

#### Fixtures Used

- Inline synthetic invariant registry fixtures in `test/tool/invariant_coverage_tool_test.dart`

#### Positive Scenarios

- A required proof that points to `tool/check_guardrails.dart` or `tool/check_import_boundaries.dart` and references an always-run step is accepted.
- A required proof that points to a runtime test file and references the appropriate scope step is accepted.
- Regression proof files still require explicit invariant markers.

#### Negative Scenarios

- A required proof that references `tool_tests` or any other non-required contour step fails reachability validation.
- An invariant that keeps only regression proofs and no required proof fails contract validation.

#### Closure Evidence

- New required-versus-regression proof regressions fail before the change and pass after migration.
- Existing invariant coverage regressions remain green under the new schema.

## 11. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/verification_contract_tool_test.dart test/tool/guardrails/guardrails_rule_inventory_tool_test.dart test/tool/run_verification_preset_tool_test.dart test/tool/invariant_coverage_tool_test.dart test/tool/coverage_tool_test.dart`
- `dart run tool/check_verification_contract.dart`
- `dart run tool/check_invariant_coverage.dart`
- `printf '%s\n' 'tool/invariant_registry.dart' 'tool/check_invariant_coverage.dart' 'tool/check_verification_contract.dart' 'tool/src/verification_contract/verification_contract_registry.dart' 'tool/src/verification_contract/verification_contract_models.dart' 'tool/src/verification_contract/verification_contract_resolver.dart' 'tool/src/check_coverage/coverage_test_target_locator.dart' 'test/tool/invariant_coverage_tool_test.dart' 'test/tool/run_verification_preset_tool_test.dart' 'test/tool/verification_contract_tool_test.dart' 'test/tool/coverage_tool_test.dart' 'test/tool/guardrails/guardrails_rule_inventory_tool_test.dart' '.github/workflows/ci.yaml' '.github/workflows/perf_nightly.yaml' 'ARCHITECTURE.md' 'CHANGELOG.md' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- `AGENTS.md` and `doc/guardrails_state_map.md` are absent from the machine-checked contour.
- The invariant registry exposes only the role-based proof schema described in this contract.
- Every required proof references a real graph-owned verification step and is reachable through the required contour.
- Tool regression tests no longer count as canonical required proof.
- Resolver, workflow drift checks, and coverage scope suggestions derive their executable data from one verification graph owner.
- Workflow YAML files remain hand-authored and validate cleanly against graph-derived expectations.
- The slice-local regressions and final verification runs listed in this contract pass.
