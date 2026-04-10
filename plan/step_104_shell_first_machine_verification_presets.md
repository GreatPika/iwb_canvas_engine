language: english

# Change Contract

## 1. Change Mandate
This change introduces one shell-first, machine-only verification preset
contract so the implementing agent can resolve and run canonical repository
verification without MCP-specific orchestration or manual command assembly.

## 2. Change Boundary

### Included in the Change
- One top-level verification preset CLI for machine-first resolve and run
  flows.
- One repo-owned verification contract registry for current required
  code-change checks, current test-area scopes, and current tool-test trigger
  surface.
- Quiet shell execution for successful verification steps and successful tool
  test children.
- Removal of `VERIFICATION.md` and migration of the compact verification
  invocation contract into `AGENTS.md`.
- Repository-local enforcement updates so verification source-of-truth drift
  is mechanically detected.

### Not Included in the Change
- Reducing or expanding the current required code-change quality bar.
- Rewriting benchmark, release-hygiene, or nightly performance workflows.
- New MCP-based verification contracts.
- Git-based auto-scope detection or change classification.

## 3. File Map and Analysis Areas

### Implementation Files
- `tool/run_verification_preset.dart`
- `tool/check_verification_contract.dart`
- `tool/check_tool_test_trigger_surface.dart`
- `tool/run_tool_tests.dart`
- `tool/src/tool_test_runner.dart`
- `tool/src/verification_contract/verification_contract_models.dart`
- `tool/src/verification_contract/verification_contract_registry.dart`
- `tool/src/verification_contract/verification_contract_resolver.dart`
- `tool/src/verification_contract/verification_contract_runner.dart`
- `tool/src/verification_contract/verification_contract_json_report.dart`
- `VERIFICATION.md`
- `AGENTS.md`
- `.github/workflows/ci.yaml`
- `plan/step_103_check_coverage_machine_workflow_optimization.md`

### Test Files
- `test/tool/run_verification_preset_tool_test.dart`
- `test/tool/verification_contract_tool_test.dart`
- `test/tool/run_tool_tests_tool_test.dart`
- `test/tool/support/tool_process_test_support.dart`
- `test/tool/tool_test_trigger_surface_tool_test.dart`

### Analysis Area
- `tool/run_verification_preset.dart`
- `tool/check_verification_contract.dart`
- `tool/check_tool_test_trigger_surface.dart`
- `tool/run_tool_tests.dart`
- `tool/src/tool_test_runner.dart`
- `tool/src/verification_contract/**`
- `test/tool/**`
- `VERIFICATION.md`
- `AGENTS.md`
- `.github/workflows/ci.yaml`
- `plan/step_103_check_coverage_machine_workflow_optimization.md`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. The canonical verification contract after this step is shell-first and
   machine-only; human-readable orchestration output is not a goal of this
   step.
2. MCP is not the repository-owned source of truth for verification after this
   step; at most it may consume the repo-owned contract as an external
   transport layer.
3. This step centralizes and deduplicates the current verification workflow;
   it does not weaken, widen, or reorder the current required code-change
   quality bar beyond what is necessary for deterministic execution.
4. The current verification scopes remain aligned with the existing package
   and example test areas currently used by the repository test workflow.
5. Coverage remains shell-only and tool tests remain a distinct verification
   surface with their existing trigger-based inclusion rule.
6. `VERIFICATION.md` is removed in this step rather than retained as a second
   documentation layer.
7. Repository-local enforcement must detect drift between the verification
   contract registry, `AGENTS.md`, and the CI workflow.

## 5. Result Requirements

1. `dart run tool/run_verification_preset.dart resolve --format=json` returns
   one compact machine payload describing the canonical verification plan for
   the requested preset or scopes without requiring additional repository
   reads from the implementing agent.
2. `dart run tool/run_verification_preset.dart` supports one full required
   code-change preset, one or more explicit production/example scope
   selections derived from the current verification test areas, one
   trigger-based tool-test mode, and explicit tool-test file selection.
3. The resolved plan is deterministic, deduplicated, and ordered so shared
   checks appear once even when multiple scopes are requested together.
4. `dart run tool/run_verification_preset.dart run ...` executes shell steps
   sequentially and emits compact success output while preserving actionable
   diagnostics for failed steps.
5. Successful `dart run tool/run_tool_tests.dart` runs no longer echo child
   `stdout` and `stderr` for every passing tool test file.
6. `AGENTS.md` documents the new shell-first verification invocation contract
   in one compact instruction and no longer points to `VERIFICATION.md`.
7. `VERIFICATION.md` no longer exists in the repository after this step.
8. Drift between the verification contract registry, `AGENTS.md`, and
   `.github/workflows/ci.yaml` fails through a repository-local check.
9. The existing specialized tool-test trigger-surface drift checker is removed
   and its enforcement is absorbed by the new verification contract check.
10. Production/example scope selection and tool-test selection remain separate
    CLI surfaces; the verification CLI does not collapse them into one mixed
    selector type.
11. Trigger-based tool-test resolution is deterministic and uses only explicit
   repeated `--changed-path=<path>` inputs from the caller; this step does
   not infer changed paths from git.
12. Explicit `--tool-test-file=<path>` selection runs only the named tool test
    files and preserves the existing file-by-file execution semantics of
    `tool/run_tool_tests.dart`.
13. `run --preset required_code_change` is the single canonical final
    verification invocation and includes the repository-local drift check plus
    trigger-based tool-test inclusion when the provided `--changed-path`
    inputs match the tool-test trigger surface.
14. `--changed-path=<path>` accepts repository-relative changed paths for
    modified, added, renamed, and deleted files because trigger matching is
    path-based rather than filesystem-existence based.
15. `resolve --format=json` uses one stable top-level machine schema with:
    - `mode`: `preset`, `scope`, `tool_tests`, or `tool_test_file`
    - `selectors`: normalized selector values accepted for the invocation
    - `steps`: ordered deduplicated step records
16. Each machine step record contains exactly:
    - `id`: stable step identifier from the registry
    - `kind`: `shell`, `tool_tests`, or `drift_check`
    - `cmd`: normalized executable command string
    - `cwd`: repository-relative working directory, or `.` when unchanged
    - `reason`: compact machine-oriented inclusion reason

## 6. Implementation Specification

### 6.1 Analysis Scope
- Reuse the current required check commands and current test-area ownership
  already encoded in the repository workflow and current verification
  instructions.
- Resolve package and example test scopes directly to shell command arguments
  instead of MCP shard metadata.
- Keep production/example scope selection, trigger-based tool-test selection,
  and explicit tool-test file selection as separate runtime inputs.
- Keep the top-level CLI as an orchestrator over focused internal modules
  under `tool/src/verification_contract/**`.
- Keep output compact and machine-first; additional repository scans beyond
  the requested preset, scope list, and tool-test trigger inputs are
  forbidden in this step.

### 6.2 Target Verification Units
- Process-level sandbox scenarios in
  `test/tool/run_verification_preset_tool_test.dart`.
- Process-level drift scenarios in
  `test/tool/verification_contract_tool_test.dart`.
- Unit-level and behavior scenarios in `test/tool/run_tool_tests_tool_test.dart`
  for success-output suppression.

### 6.3 Protected States, Data, or Structures
- The current required code-change check list used by the repository workflow.
- The current tool-test trigger list already synchronized between
  `.github/workflows/ci.yaml` and `tool/check_tool_test_trigger_surface.dart`.
- The current repository test-area partition:
  - `core`
  - `model_contract`
  - `controller_internal`
  - `controller`
  - `render_view`
  - `interactive`
  - `example`
- The current shell-only coverage path:
  `flutter test --coverage --no-pub --exclude-tags=tool` followed by
  `dart run tool/check_coverage.dart`.

### 6.4 Allowed Semantic Change Zones
- Machine-only preset selection and CLI argument parsing.
- Preset registry assembly for required checks and explicit scopes.
- Trigger-surface ownership migration into the verification contract registry.
- Explicit changed-path based tool-test resolution.
- Explicit tool-test file passthrough to `tool/run_tool_tests.dart`.
- Deterministic step deduplication and step ordering.
- Compact JSON plan output.
- Shell process execution, exit-code propagation, and quiet-success logging.
- Repository-local drift enforcement between code, documentation, and CI.

### 6.5 Recognition Forms That Must Be Supported Within This Change
- `resolve` for the required code-change preset.
- `resolve` for one explicit scope.
- `resolve` for multiple explicit scopes with shared-step deduplication.
- `resolve --tool-tests --changed-path=<path>` for trigger-based tool-test
  inclusion.
- `resolve --tool-test-file=<path>` for one explicit tool-test file.
- `resolve` for multiple explicit `--tool-test-file=<path>` selections.
- `run` for the required code-change preset.
- `run` for one or more explicit scopes.
- `run --tool-tests --changed-path=<path>` for trigger-based tool-test
  inclusion and omission based on the existing trigger surface.
- `run --tool-test-file=<path>` for one explicit tool-test file.
- `run` for multiple explicit `--tool-test-file=<path>` selections.

### 6.6 Allowed Forms That Do Not Count as Violations
- Reusing the current command lines already owned by the repository workflow.
- Emitting only high-signal per-step status lines on success.
- Returning machine-readable diagnostics only when a step fails or when
  `resolve --format=json` is requested.
- Using compact machine-only field names and stable enum-like values instead
  of narrative prose in the JSON payload.

### 6.7 Requirements for Resolution of Links and Structural Analysis
- The verification contract registry must be the single source of truth for:
  - the required code-change preset;
  - scope-to-path mappings;
  - shell command definitions;
  - whether tool tests are conditionally included;
  - the tool-test trigger surface.
- The machine `resolve --format=json` payload must contain exactly:
  - `mode`
  - `selectors`
  - `steps`
- Each `steps` entry must contain exactly:
  - `id`
  - `kind`
  - `cmd`
  - `cwd`
  - `reason`
- Trigger-based tool-test resolution must consume only repeated
  `--changed-path=<path>` values provided by the caller.
- `--changed-path=<path>` values are matched as repository-relative path
  strings and must not require the referenced path to exist on disk at
  runtime.
- Explicit `--tool-test-file=<path>` values must be passed through without
  registry-side path invention or expansion.
- `tool/check_verification_contract.dart` must validate the resolved registry
  contract against both `AGENTS.md` and `.github/workflows/ci.yaml`.
- The CLI must not parse prose from `AGENTS.md` to build runtime plans;
  documentation is a consumer of the registry, not the source.

### 6.8 Prohibited
- Do not keep MCP-only shard definitions as the canonical runtime contract.
- Do not retain `VERIFICATION.md` as a second verification source of truth.
- Do not introduce a second verification registry outside
  `tool/src/verification_contract/**`.
- Do not infer changed paths from git in this step.
- Do not overload `--scope` to address tool tests or individual tool-test
  files.
- Do not auto-expand one explicit tool-test file into additional tool-test
  files.
- Do not stream full child process output for successful steps by default.
- Do not change benchmark, release-hygiene, or nightly perf workflow logic in
  this step.
- Do not add git-diff-driven scope inference in this step.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes a CLI contract, the same slice must add positive and
   negative process-level scenarios for the new CLI behavior.
7. If a slice changes a repository-local enforcement rule, the same slice must
   prove both a green aligned scenario and at least one drift failure
   scenario.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered
    valid.
11. The required code-change preset must not be declared closed until it
    reproduces the current required repository verification surface without
    MCP-specific runtime requirements.

## 8. Vertical Slices

### Slice 1. [ ] Establish the canonical machine preset registry

#### Slice Contract
`dart run tool/run_verification_preset.dart resolve --format=json` exposes one
deterministic machine-only verification plan for the current required
code-change preset and for explicit scope selections derived from the current
repository test areas.

#### Change
- Add `tool/run_verification_preset.dart` as the only top-level entrypoint for
  verification preset resolution and execution.
- Add these internal modules under `tool/src/verification_contract/**`:
  - `verification_contract_models.dart`
  - `verification_contract_registry.dart`
  - `verification_contract_resolver.dart`
  - `verification_contract_json_report.dart`
- Encode the current required code-change preset from the current repository
  verification workflow.
- Encode the current explicit scopes and shell targets:
  - `core` -> `flutter test --no-pub test/core`
  - `model_contract` -> `flutter test --no-pub test/model test/serialization test/contract test/public_api test/entrypoints`
  - `controller_internal` -> `flutter test --no-pub test/controller/internal`
  - `controller` -> `flutter test --no-pub test/controller/core test/controller/commands test/controller/scene_controller_randomized_txn_test.dart test/controller/scene_invariants_test.dart test/controller/scene_snapshot_invariant_assertions_test.dart`
  - `render_view` -> `flutter test --no-pub test/render test/view`
  - `interactive` -> `flutter test --no-pub test/interactive`
  - `example` -> `(cd example && flutter test --no-pub test)`
- Encode the current tool-test trigger entries in the same registry instead of
  keeping them in a separate documentation-owned list.
- Support exactly these selector modes:
  - `--preset required_code_change` with one or more `--changed-path=<path>`
  - one or more `--scope=<scope>`
  - `--tool-tests` with one or more `--changed-path=<path>`
  - one or more `--tool-test-file=<path>`
- Require exactly one selector mode per invocation; mixed selector modes fail
  with a non-zero exit code.
- Require one or more `--changed-path=<path>` values for
  `--preset required_code_change` and for `--tool-tests`; missing changed
  paths fail with a non-zero exit code.
- Keep `--scope` limited to the production/example scopes encoded in this
  slice; `tools` is not a valid scope.
- Keep `--tool-test-file=<path>` limited to explicit files under `test/tool/**`
  and preserve the file order provided by the caller after path normalization.
- Keep the resolve payload compact and ordered; duplicated steps across
  multiple requested scopes must collapse to one resolved step.
- Keep explicit tool-test file selection exact: the resolved plan must contain
  only the requested tool test files and no trigger-based expansion.
- Emit one stable machine payload whose `steps` list uses only these kinds:
  - `shell`
  - `tool_tests`
  - `drift_check`

#### Verification
- `dart run tool/run_tool_tests.dart test/tool/run_verification_preset_tool_test.dart`

#### Positive Scenarios
- Resolving the required code-change preset returns one ordered machine plan.
- Resolving `render_view` and `interactive` together returns both shell test
  targets with no duplicated shared steps.
- Resolving the `example` scope returns the example-root shell command instead
  of a package-root command.
- Resolving `--tool-tests` with matching `--changed-path` values returns only
  the tool-test step.
- Resolving one `--tool-test-file` returns only that explicit tool-test file.
- Resolving multiple `--tool-test-file` arguments preserves the requested file
  order after normalization.
- Resolving any selector mode returns only the top-level fields `mode`,
  `selectors`, and `steps`, and each step record contains only `id`, `kind`,
  `cmd`, `cwd`, and `reason`.

#### Negative Scenarios
- Missing selector arguments fail.
- Unknown `--preset` fails.
- Unknown `--scope` fails.
- `--tool-tests` without `--changed-path` fails.
- `--preset required_code_change` without `--changed-path` fails.
- Unknown `--tool-test-file` path fails.
- Mixing selector modes fails.

#### Closure Evidence
- Green run of the listed verification.
- Machine payload examples asserted in the sandbox tests for required preset,
  multi-scope deduplication, example-root resolution, trigger-based tool-test
  resolution, and explicit tool-test-file selection.

### Slice 2. [ ] Execute shell presets quietly and suppress passing tool-test noise

#### Slice Contract
`dart run tool/run_verification_preset.dart run ...` executes the resolved
shell plan sequentially with compact success output, and successful
`tool/run_tool_tests.dart` runs no longer emit child output for every passing
tool test file.

#### Change
- Add `tool/src/verification_contract/verification_contract_runner.dart` to run
  resolved shell steps sequentially, preserving non-zero exit codes and
  failure diagnostics.
- Make `tool/run_verification_preset.dart run ...` print one compact status
  line per step on success and print child process output only for failed
  steps.
- Keep `run --tool-test-file=<path>` delegated to
  `tool/run_tool_tests.dart <path>` semantics rather than reimplementing a
  second tool-test executor.
- Update `tool/src/tool_test_runner.dart` and `tool/run_tool_tests.dart` so
  passing child tool-test processes do not stream their buffered `stdout` and
  `stderr`; keep failure output and final summaries intact.
- Keep coverage and tool-test execution sequencing compatible with the current
  repository rule that heavyweight Flutter coverage runs must not execute in
  parallel with tool tests.

#### Verification
- `dart run tool/run_tool_tests.dart test/tool/run_verification_preset_tool_test.dart test/tool/run_tool_tests_tool_test.dart`

#### Positive Scenarios
- A successful `run` invocation emits only compact per-step statuses.
- A successful tool-test run reports file-level pass statuses and summary
  without echoing buffered child process output.
- `run --tool-test-file=<path>` executes only the named tool-test file.

#### Negative Scenarios
- A failing child verification step surfaces its diagnostics and makes the
  preset runner exit non-zero.
- A failing tool-test child still prints its captured output and remains
  listed in the failure summary.
- `run --tool-tests` with non-matching `--changed-path` values skips tool
  tests deterministically instead of running the full tool-test suite.

#### Closure Evidence
- Green run of the listed verifications.
- Sandbox output assertions proving quiet-success behavior for both the preset
  runner and the tool-test runner.

### Slice 3. [ ] Enforce shell-first preset drift across code, docs, and CI

#### Slice Contract
The verification contract registry becomes the repository-owned source of
truth, `VERIFICATION.md` is removed, `AGENTS.md` exposes one compact
shell-first invocation rule, and repository-local enforcement fails when the
registry, docs, or CI drift.

#### Change
- Add `tool/check_verification_contract.dart` as the drift-enforcement
  entrypoint for the verification contract registry, `AGENTS.md`, and
  `.github/workflows/ci.yaml`.
- Add `test/tool/verification_contract_tool_test.dart` with green and
  drift-failure scenarios.
- Delete `VERIFICATION.md`.
- Update `AGENTS.md` so the verification section contains one compact
  instruction that points to the canonical final invocation
  `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-path=<path>...`
  instead of delegating to `VERIFICATION.md`.
- Update `.github/workflows/ci.yaml` so static checks run
  `dart run tool/check_verification_contract.dart`.
- Delete `tool/check_tool_test_trigger_surface.dart` and migrate its trigger
  surface enforcement into the verification contract registry and new drift
  checker.
- Delete `test/tool/tool_test_trigger_surface_tool_test.dart` after its
  scenarios are subsumed by `test/tool/verification_contract_tool_test.dart`.
- Update
  `plan/step_103_check_coverage_machine_workflow_optimization.md` so its
  verification references and source-of-truth wording no longer rely on
  `VERIFICATION.md`.

#### Verification
- `dart run tool/run_tool_tests.dart test/tool/verification_contract_tool_test.dart`

#### Positive Scenarios
- The drift checker passes when the registry, documentation, and CI stay
  aligned.
- The updated `AGENTS.md` names the shell-first preset CLI as the canonical
  final verification invocation contract and documents the explicit
  `--changed-path` requirement.

#### Negative Scenarios
- Drift between registry and `AGENTS.md` fails.
- Drift between registry and `.github/workflows/ci.yaml` fails.
- Drift in the tool-test trigger surface fails through the new contract check.

#### Closure Evidence
- Green run of the listed verification.
- Drift failure assertions proving separate documentation and CI mismatch
  diagnostics.

## 9. Final Verification

- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-path=tool/run_verification_preset.dart --changed-path=tool/run_tool_tests.dart --changed-path=tool/check_verification_contract.dart --changed-path=tool/check_tool_test_trigger_surface.dart --changed-path=tool/src/tool_test_runner.dart --changed-path=AGENTS.md --changed-path=.github/workflows/ci.yaml`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
