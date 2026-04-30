# Change Contract

## 1. Change Mandate

Make load-profile diff reports preserve input report identity and emit
unit-truthful metric values, closing `KI-13` and `KI-14` as consequences of
that single report-contract fix.

## 2. Change Boundary

### Included in the Change

- reject load-profile diff input reports whose `caseCount` is missing,
  non-integral, or different from the `cases` list length
- reject duplicate case names during diff report ingestion before cases are
  converted into name-keyed maps
- keep missing, unexpected, and required-case comparison verdicts as diff policy
  failures rather than report-ingestion errors
- define load-profile metric units in the policy owner so latency and RSS
  metrics have one metric taxonomy source
- change load-profile diff metric output from `baselineUs`, `currentUs`, and
  `deltaAbsUs` to neutral value fields plus an explicit unit
- keep probe diff output on its existing neutral `baselineValue`,
  `currentValue`, and `delta` schema
- update tool tests, known-issue state, architecture-family status, release
  notes, and this plan step in the same implementation change

### Not Included in the Change

- no public package API, public export, runtime model, serialization, or JSON
  document schema change
- no load-profile runner output schema change beyond consuming the existing
  `caseCount` field as required input in the diff layer
- no checked-in baseline regeneration or benchmark measurement rerun
- no CLI parser consolidation, `--help` wording refactor, or shared bench
  command-line support layer
- no general report parser extraction outside `tool/bench/**`
- no benchmark case-body, render/cache, controller, or interaction behavior
  change
- no broad metric-threshold, regression-verdict, or policy-budget change
- no cleanup of unrelated clone-analysis findings in `tool/bench/**` or
  `test/tool/**`

## 3. Surrounding Code Review

### Inspected Artifacts

- `KNOWN_ISSUES.md` - records `KI-13` as active because RSS byte metrics are
  emitted through `...Us` diff fields and `KI-14` as active because diff report
  ingestion does not reject stale `caseCount` or duplicate case names.
- `tool/bench/diff_load_profiles.dart` - `buildDiffReport(...)` reads baseline
  and current reports, converts cases into maps keyed by case name, computes
  policy failures, and currently emits metric diffs with `baselineUs`,
  `currentUs`, and `deltaAbsUs` for every metric.
- `tool/bench/diff_load_profiles.dart` - `_readReportFromObject(...)` validates
  profile, fixed runtime metadata, `cases` shape, metric leaves, and probe
  leaves, but does not validate the report-level `caseCount` field and does not
  reject duplicate case names before returning `_Report`.
- `tool/bench/diff_load_profiles.dart` - `_diffCase(...)` owns operation-level
  metric diff object construction and is the only implementation site for the
  mislabeled value fields.
- `tool/bench/load_profile_policy.dart` - `_loadProfileRequiredMetricKeys`
  contains both latency metrics (`avgUs`, `minUs`, `maxUs`) and RSS byte metrics
  (`avgRssDeltaBytes`, `minRssDeltaBytes`, `maxRssDeltaBytes`) without a unit
  taxonomy API.
- `tool/bench/load_profile_policy.dart` - `validateProducedLoadProfileCaseNames`
  already detects duplicate, missing, and unexpected produced runner cases; this
  is a runner taxonomy validator, not a diff input-integrity validator.
- `tool/bench/run_load_profiles.dart` - generated load-profile reports already
  write `caseCount: parsedCases.length` after runner-side case-name validation.
- `test/tool/bench_diff_load_profiles_test.dart` - owns diff report behavioral
  proof, CLI failure-report proof, metric precision proof, runtime-contour
  proof, missing case proof, missing operation/probe proof, and current
  assertions for the old `...Us` metric fields.
- `test/tool/bench_run_load_profiles_test.dart` - owns runner-side produced
  case validation, including duplicate benchmark case detection through
  `validateProducedLoadProfileCaseNames`.
- `docs/architecture/families/diagnostics_performance_and_debug_surfaces.md` -
  declares diagnostic and benchmark outputs must use truthful schemas and stable
  units; currently marks `KI-13` and `KI-14` as known issues rather than target
  architecture.
- `ARCHITECTURE.md` - states diagnostic load profiles under `tool/bench/**`
  remain repository-owned regression artifacts and the benchmark runner and diff
  layer consume production-owner seams only.
- `tool/invariant_registry.dart` - `INV-ENG-PERFORMANCE-PROOF-CONTOUR` names
  `test/tool/bench_diff_load_profiles_test.dart` and
  `test/tool/bench_run_load_profiles_test.dart` as regression proof for the
  benchmark regression surface.
- `dart run tool/lsp_trace_symbol.dart tool/bench/diff_load_profiles.dart buildDiffReport --direction=both --depth=2 --json`
  - confirms `buildDiffReport(...)` is reached only by the CLI entrypoint and
  diff tests, and delegates report ingestion to `_readReportFromObject(...)`
  and metric construction to `_diffCase(...)`.
- `dart run tool/lsp_trace_symbol.dart tool/bench/diff_load_profiles.dart _readReportFromObject --direction=both --depth=3 --json`
  - confirms `_readReportFromObject(...)` is private to
  `diff_load_profiles.dart` and is the input boundary before case maps are
  constructed.
- `dart run tool/lsp_trace_symbol.dart tool/bench/diff_load_profiles.dart _diffCase --direction=both --depth=3 --json`
  - confirms `_diffCase(...)` is private to `diff_load_profiles.dart` and is
  the metric diff object owner.
- `rg -n "baselineUs|currentUs|deltaAbsUs" tool test docs plan ARCHITECTURE.md API_GUIDE.md README.md CHANGELOG.md KNOWN_ISSUES.md`
  - found the old unit-specific metric diff fields only in the diff tool,
  diff tests, and the active known-issue entry.
- `dart run tool/analysis/find_similar_clones.dart --clusters --top 30 tool/bench 30 18 5 3 0.55 20`
  - found related bench-tool clones in CLI parsing, help printing, operation
  path normalization, and benchmark case bodies; none owns the `KI-13` or
  `KI-14` root cause.
- `dart run tool/analysis/find_similar_clones.dart --clusters --top 30 test/tool 40 24 5 3 0.55 20`
  - found diff fixture similarity in `test/tool/bench_diff_load_profiles_test.dart`,
  which may be reduced only when it directly supports the new proof.
- `dart run tool/run_repository_audits.dart` - current standalone architecture
  audits pass while `KI-13` and `KI-14` remain active, proving these defects
  belong to the benchmark diff proof family rather than an existing structural
  audit.
- `dart run tool/check_guardrails.dart`,
  `dart run tool/check_verification_contract.dart`,
  `dart run tool/check_invariant_coverage.dart`,
  `dart run tool/check_public_api_surface.dart`,
  `dart run tool/check_import_boundaries.dart`, and
  `dart run tool/check_architecture_atlas.dart` - all pass before this step,
  so the contract must preserve the current package/API architecture while
  retiring the known-issue status.

### Current Entry Path

- CLI path:
  `dart run tool/bench/diff_load_profiles.dart --baseline=... --current=... --output=...`
  -> `main(...)` -> `_readJsonFileAsObject(...)` -> `buildDiffReport(...)`
  -> `_readReportFromObject(...)` for baseline/current -> `_diffCase(...)`
  for compared operations.
- Test path:
  `test/tool/bench_diff_load_profiles_test.dart` imports
  `tool/bench/diff_load_profiles.dart` and calls `buildDiffReport(...)`
  directly, then also runs the CLI from a sandbox for failure-report behavior.

### Current Owner

- `tool/bench/**` owns load-profile policy, runner report generation,
  checked-in load-profile baselines, diff parsing, diff comparison, and
  diagnostic benchmark report schemas.
- `tool/bench/diff_load_profiles.dart` owns diff input ingestion and diff
  output construction.
- `tool/bench/load_profile_policy.dart` owns canonical load-profile metric keys
  and is the correct owner for metric-unit taxonomy.

### Adjacent Abstractions

- `LoadProfilePolicy.requiredMetricKeys` supplies the ordered required metric
  keys consumed by runner validation and diff parsing.
- `LoadProfilePolicy.maxRegressionPctByMetric` and
  `LoadProfilePolicy.maxAbsoluteValueByMetric` supply metric-keyed policy data
  already consumed by `_diffCase(...)`.
- `validateProducedLoadProfileCaseNames(...)` validates runner-produced case
  taxonomy and is adjacent but broader than the diff input-integrity guard.
- `_readProbeLeavesByOperation(...)` is the closest existing diff-side input
  shape validator for optional report subtrees.
- `_collectMetricLeaves(...)` is the closest existing diff-side validator for
  required finite metric leaves and duplicate normalized operation paths.

### Existing Tests

- `test/tool/bench_diff_load_profiles_test.dart` - already proves deterministic
  diff output, metric precision, missing required metric failure, missing
  cases, missing required operations/probes, unknown profile failure, runtime
  contour validation, and diagnostic-only RSS metric gating.
- `test/tool/bench_run_load_profiles_test.dart` - already proves runner-side
  duplicate case-name validation and report contract generation.
- `test/tool/bench_selection_control_diagnostics_test.dart` - proves the
  selection diagnostic runner stays independent from `diff_load_profiles.dart`.
- `test/tool/verification_contract_tool_test.dart` - proves verification
  contract coverage for tool workflows that include benchmark checks.

### Analogous Implementation Path

- `tool/bench/run_load_profiles.dart` report construction writes
  `caseCount: parsedCases.length` after validating `parsedCases`; this is the
  producer-side precedent for treating `caseCount` as report identity.
- `tool/bench/run_load_profiles.dart` `validateCollectedBenchmarkCases(...)`
  collects case names before comparing taxonomy; this is the closest precedent
  for validating duplicate names before later map-like normalization.
- `tool/bench/diff_load_profiles.dart` `_readProbeLeavesByOperation(...)`
  rejects malformed optional probe data at the diff input boundary; this is the
  closest diff-side precedent for rejecting malformed report identity before
  comparison.
- `tool/bench/load_profile_policy.dart` already owns metric-keyed policy maps;
  adding metric units there follows the same dependency direction as existing
  threshold policy consumption.

### Governing Repository Rules

- `AGENTS.md` - known issues are active defects only and must be removed in the
  same change that fixes them and adds regression proof.
- `AGENTS.md` - public behavior changes must update `CHANGELOG.md`, and
  architecture or invariant ownership changes must update the relevant
  architecture source of truth.
- `AGENTS.md` - after code changes, run
  `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`
  with every modified path listed.
- `ARCHITECTURE.md` - diagnostic load profiles under `tool/bench/**` are
  repository-owned regression artifacts, and benchmark runner/diff layers
  consume production-owner seams only.
- `docs/architecture/families/diagnostics_performance_and_debug_surfaces.md` -
  diagnostic and benchmark outputs use truthful schemas and stable units.
- `tool/invariant_registry.dart` - `INV-ENG-PERFORMANCE-PROOF-CONTOUR` keeps
  benchmark diff and runner tests as regression proof for this surface.

### Rejected Misleading Local Patterns

- `tool/bench/run_load_profiles.dart` `validateProducedLoadProfileCaseNames(...)`
  - wrong full seam for diff ingestion because it treats missing and unexpected
  cases as runner taxonomy issues, while the diff tool must continue reporting
  those as baseline/current comparison failures.
- `tool/bench/run_selection_control_diagnostics.dart` - wrong owner because
  selection diagnostics are an ad hoc diagnostic report and must not become a
  dependency of canonical load-profile diffing.
- `_parseArgs(...)` and `_printUsageAndExit(...)` clones across bench tools -
  real clone-analysis findings, but not part of the report identity or metric
  schema root cause.
- `_normalizeOperationPath(...)` and `_normalizeMetricOperationPath(...)` clone
  finding - adjacent to metric parsing but not responsible for duplicate case
  names, stale `caseCount`, or unit-mislabeled metric diff fields.
- `test/tool/bench_diff_load_profiles_test.dart` fixture similarity - may be
  cleaned only as slice-local test support and must not become a broad fixture
  refactor objective.
- DCM metric pressure on `buildDiffReport(...)` and `_diffCase(...)` - not a
  valid reason for a metric-only split; any extraction must directly support
  the locked input-integrity or unit-taxonomy contract.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- This is a repository-owned diagnostic benchmark contract fix at the
  `tool/bench/**` layer.

#### Selected Architectural Form

- Keep diff input report integrity checks inside
  `tool/bench/diff_load_profiles.dart` at `_readReportFromObject(...)`, before
  `_Report` construction and before `buildDiffReport(...)` converts cases into
  name-keyed maps.
- Add metric-unit taxonomy to `tool/bench/load_profile_policy.dart` and have
  `tool/bench/diff_load_profiles.dart` consume that taxonomy when constructing
  metric diff objects.
- Keep diff policy comparison ownership in `buildDiffReport(...)` and
  `_diffCase(...)`; only the value-field schema and input-boundary guards
  change.

#### Owning Layer or Module

- Owner: `tool/bench/**`.
- Input integrity owner: `tool/bench/diff_load_profiles.dart`.
- Metric taxonomy owner: `tool/bench/load_profile_policy.dart`.
- Regression proof owner: `test/tool/bench_diff_load_profiles_test.dart`.

#### Dependency Direction

- `diff_load_profiles.dart` may import and consume public declarations from
  `load_profile_policy.dart`.
- `load_profile_policy.dart` must not import `diff_load_profiles.dart`,
  runner code, tests, or report fixtures.
- Tests may import both policy and diff tool code.
- Architecture docs and known-issue state must describe the resulting surface;
  they must not become executable dependencies.

#### State and Data Ownership

- Report identity consists of profile, fixed runtime metadata, `caseCount`, and
  ordered `cases` entries as read from each baseline/current input file.
- `_readReportFromObject(...)` owns validation that input identity is internally
  consistent and non-lossy before data enters `_Report`.
- `LoadProfilePolicy` owns the supported metric keys and each metric key's
  output unit.
- `_diffCase(...)` owns the metric diff values produced for compared
  operations, using policy-owned units.

#### Entry and Exit Boundaries

- Entry boundary: decoded baseline/current JSON maps passed to
  `buildDiffReport(...)`, including CLI-loaded JSON from
  `_readJsonFileAsObject(...)`.
- Ingestion exit boundary: `_Report` must contain unique case names and a case
  list whose length matched the report-level `caseCount`.
- Diff output boundary: every metric diff object under `cases[].operations[]`
  must expose neutral numeric value fields plus explicit unit metadata.
- Failure boundary: malformed report identity remains a `_DiffToolInputException`
  and CLI failure report; policy comparison failures remain ordinary diff
  `failures` entries.

#### Permitted Extension Seam

- `load_profile_policy.dart` may expose a small metric-unit API keyed by
  existing required metric names.
- `diff_load_profiles.dart` may add private helpers for report identity
  validation and metric diff object construction if they reduce direct
  complexity in the touched paths.
- `test/tool/bench_diff_load_profiles_test.dart` may add or adjust inline
  fixtures needed to prove the new input and output contracts.

#### Rejected Alternatives

- Reusing `validateProducedLoadProfileCaseNames(...)` directly in diff parsing
  - rejected because it would convert missing/unexpected baseline/current
  comparison cases into input errors and blur runner taxonomy validation with
  diff report identity validation.
- Introducing a new shared report parser outside `tool/bench/**` - rejected
  because LSP traces show the affected parser is private to the diff tool and
  no other owner consumes this schema.
- Refactoring bench CLI parsing or help output while touching the files -
  rejected because clone analysis found real but unrelated CLI clones that do
  not close either known issue.
- Keeping `baselineUs/currentUs/deltaAbsUs` and adding a separate `unit` field
  - rejected because the field names would remain false for RSS byte metrics.
- Special-casing RSS field names inside `diff_load_profiles.dart` only -
  rejected because metric units belong with the metric taxonomy in
  `load_profile_policy.dart`.
- Regenerating checked-in load-profile baseline JSON - rejected because the
  baseline input schema already contains `caseCount` and raw metrics; only the
  diff report output schema changes.

#### Why This Level Is Correct

- The defects are both in the diff report boundary: one loses malformed input
  identity before comparison, and the other emits misleading diff output fields.
- The runner already produces `caseCount` and validates produced case taxonomy;
  the missing guard is in the consumer that currently trusts and normalizes
  historical artifacts.
- Metric keys and thresholds are already policy-owned, so adding unit taxonomy
  there avoids a second source of metric truth in the diff tool.
- `rg` and LSP traces show the old diff schema fields are not public package API
  and are consumed only by diff tests and known-issue documentation.

## 5. Locked Decisions

1. Metric diff objects must use `baselineValue`, `currentValue`, `deltaAbs`,
   and `unit` instead of `baselineUs`, `currentUs`, and `deltaAbsUs`.
2. Supported initial units are `microseconds` for `avgUs`, `minUs`, and
   `maxUs`, and `bytes` for `avgRssDeltaBytes`, `minRssDeltaBytes`, and
   `maxRssDeltaBytes`.
3. Unknown required metric keys must be rejected by the policy-owned metric-unit
   API rather than silently defaulting to a unit.
4. CLI absolute-limit failure text must read the neutral current value field,
   not any unit-specific field.
5. Diff report ingestion must reject duplicate case names even when the
   duplicate payloads are identical.
6. Diff report ingestion must require `caseCount` to be an integer equal to
   `cases.length`; a missing, fractional, or mismatched value is malformed
   input.
7. Missing required cases, extra cases, missing operations, and missing probes
   remain comparison results in `status`, `summary`, and `failures`.
8. `KNOWN_ISSUES.md` may remove `KI-13` and `KI-14` only after both behavioral
   reproducers and guard tests pass.

## 6. Result Requirements

1. A malformed baseline or current report with duplicate case names cannot be
   silently normalized into one compared case.
2. A malformed baseline or current report with stale or invalid `caseCount`
   cannot be compared.
3. Valid reports with missing required cases still produce a diff report with
   `status: fail` and missing-case summary fields rather than an input
   exception.
4. Latency metric diff objects truthfully identify their unit as
   `microseconds`.
5. RSS metric diff objects truthfully identify their unit as `bytes`.
6. No metric diff object uses a field name that claims a microsecond unit for a
   non-microsecond value.
7. Existing probe diff objects keep their neutral value-field schema.
8. The diagnostics performance architecture family no longer reports `KI-13`
   or `KI-14` as target-architecture exceptions after the implementation
   closes them.

## 7. Execution Order and Gates

### Required Order

- First add failing diff-tool reproducers and guard tests for input report
  integrity in `test/tool/bench_diff_load_profiles_test.dart`.
- Implement the minimal diff-ingestion fix in `tool/bench/diff_load_profiles.dart`
  and run slice-local tool tests before touching metric output schema.
- Next add failing diff-tool reproducers and guard tests for metric unit output
  and old-field retirement.
- Implement metric taxonomy in `tool/bench/load_profile_policy.dart` and
  consume it from `tool/bench/diff_load_profiles.dart`.
- Update known-issue, architecture-family, changelog, and plan-step checkboxes
  only after both code slices have passing proof.
- Run final required verification after all touched paths are known.

### Successor Seam and Retirement Gates

- Successor metric diff schema: `baselineValue`, `currentValue`, `deltaAbs`,
  and `unit`.
- Retired metric diff fields: `baselineUs`, `currentUs`, and `deltaAbsUs`.
- Retirement gate: `test/tool/bench_diff_load_profiles_test.dart` must prove
  latency and RSS metric output use the successor fields and do not contain the
  retired fields.
- Known-issue retirement gate: `KNOWN_ISSUES.md` may remove `KI-13` and
  `KI-14` only after the input-integrity and unit-schema tests pass.
- Architecture-family retirement gate:
  `docs/architecture/families/diagnostics_performance_and_debug_surfaces.md`
  may remove the `known issue` status only in the same change that removes both
  known issues and keeps architecture-atlas validation green.

### Deferred Broad Verification

- Full `required_code_change` verification is reserved for the final gate
  because the implementation touches tool code and repository source-of-truth
  documents.
- Slice-local tool tests must run before the final gate:
  `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart test/tool/bench_run_load_profiles_test.dart`.
- The diagnostics-family tool-test evidence should run before final close:
  `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart test/tool/bench_selection_control_diagnostics_test.dart test/tool/verification_contract_tool_test.dart`.

## 8. File Map

### Implementation Files

- `tool/bench/diff_load_profiles.dart`
- `tool/bench/load_profile_policy.dart`

### Test Files To Edit

- `test/tool/bench_diff_load_profiles_test.dart`

### Verification-Only Test Files

- `test/tool/bench_run_load_profiles_test.dart`
- `test/tool/bench_selection_control_diagnostics_test.dart`
- `test/tool/verification_contract_tool_test.dart`

### Fixtures and Supporting Data

- inline diff report fixtures in `test/tool/bench_diff_load_profiles_test.dart`
- existing checked-in baselines under `tool/bench/baselines/*.json` are input
  evidence only and must not be regenerated for this step

### Registry, Inventory, and Workflow Files

- `PLAN.md`
- `plan/step_38_load_profile_diff_report_contract.md`
- `KNOWN_ISSUES.md`
- `docs/architecture/families/diagnostics_performance_and_debug_surfaces.md`
- `CHANGELOG.md`

### Analysis Area

- `tool/bench/**`
- `test/tool/bench_*_test.dart`
- `tool/invariant_registry.dart`
- `ARCHITECTURE.md`
- `docs/ARCHITECTURE_ATLAS.md`
- `docs/proof_architecture/evidence/proof_inventory.json`

## 9. Implementation Rules

### Protected Invariants

- `INV-ENG-PERFORMANCE-PROOF-CONTOUR` remains the governing invariant for the
  benchmark regression surface.
- Diagnostic load-profile output must use truthful schemas and stable units.
- Benchmark diff must preserve the fixed-harness runtime contour checks already
  in place.
- Public API surface, import boundaries, and engine runtime behavior are out of
  scope and must remain unchanged.

### Required Proof

- behavioral proof: `test/tool/bench_diff_load_profiles_test.dart` must first
  reproduce stale `caseCount`, invalid `caseCount`, duplicate case names, and
  RSS metric output with misleading `...Us` fields before the owner-side fixes.
- behavioral guard proof: add 1 to 3 neighboring tests that valid missing-case
  comparison still returns diff failures, latency metric output carries
  `microseconds`, and probe output remains neutral.
- structural proof: `test/tool/bench_diff_load_profiles_test.dart` must assert
  the retired metric fields are absent from metric diff objects, and
  `dart run tool/analysis/find_similar_clones.dart --clusters --top 30 tool/bench 30 18 5 3 0.55 20`
  must be considered before deciding whether a helper extraction is justified.
- for bug fixes, regressions, false positives, false negatives, and
  invariant-enforcement gaps: add one failing reproducer first for each defect
  class plus the neighboring guard tests before implementation changes.

### Allowed Change Surface

- Add private validation helpers in `tool/bench/diff_load_profiles.dart` for
  report `caseCount` and duplicate case-name detection.
- Add a small metric-unit enum, value object, or string-returning API in
  `tool/bench/load_profile_policy.dart`.
- Update `_diffCase(...)` metric object construction and regression failure text
  to consume the neutral value fields.
- Update only the diff-test fixtures needed to express the new proof clearly.
- Update repository source-of-truth documents required to close the known
  issues.

### Forbidden Moves

- Do not move runner-side missing/unexpected case taxonomy validation into diff
  input parsing.
- Do not make `load_profile_policy.dart` depend on diff, runner, tests, or
  checked-in baseline files.
- Do not add a new shared parser or CLI-support module unless a failing test in
  this step proves it is required for the locked contract.
- Do not retain `baselineUs`, `currentUs`, or `deltaAbsUs` as compatibility
  aliases in metric diff output.
- Do not change raw load-profile runner report metrics or checked-in baseline
  JSON format.
- Do not regenerate performance baselines.
- Do not refactor unrelated clone-analysis findings, DCM metric findings, CLI
  argument parsing, benchmark case bodies, or selection diagnostics.
- Do not remove `KI-13` or `KI-14` before automated regression proof passes.

### Optional: Recognition Forms That Must Be Supported

- Flat metric maps such as `metrics.single_node_patch.avgUs`.
- Nested metric maps where an outer `metrics` key is normalized away before
  operation comparison.
- Reports with required cases missing from one or both sides, which remain
  comparison failures rather than malformed input.
- Reports with optional `probes` omitted for cases without required probes,
  preserving existing probe behavior.

### Optional: Allowed Forms That Are Not Violations

- RSS metrics remaining diagnostic-only when they have no configured regression
  threshold.
- Negative RSS deltas when the raw benchmark result reports them as finite
  numeric values.
- Existing `baselineValue` and `currentValue` fields in probe diff objects.
- Existing clone-analysis findings outside the touched input and metric schema
  contract.

### Optional: Resolution Rules

- If a metric key appears in `LoadProfilePolicy.requiredMetricKeys`, it must
  have a policy-owned unit.
- If `caseCount` and `cases.length` disagree, reject the report before any case
  map is built.
- If the same case name appears more than once in one input report, reject the
  report before comparison, regardless of whether the duplicate payloads match.
- If the diff CLI catches a report-ingestion error, it must keep writing the
  existing top-level failure report shape with `status: fail`.

## 10. Vertical Slices

### Slice 1. [ ] Diff Input Report Identity

#### Slice Contract

Malformed load-profile diff input reports with duplicate case names or invalid
`caseCount` are rejected before baseline/current cases are normalized into maps,
while valid reports with missing required cases still reach diff policy
comparison.

#### Change

- Add failing reproducer tests in `test/tool/bench_diff_load_profiles_test.dart`
  for stale `caseCount`, missing or non-integral `caseCount`, and duplicate
  case names.
- Add a neighboring guard test proving missing required cases still produce a
  diff report with `status: fail`, not a report-ingestion exception.
- Implement report identity validation in `_readReportFromObject(...)` or a
  private helper it calls before `_Report` construction.

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart`

#### Structural Verification

- `dart run tool/lsp_trace_symbol.dart tool/bench/diff_load_profiles.dart _readReportFromObject --direction=both --depth=3 --json`
- `rg -n "validateProducedLoadProfileCaseNames|caseCount|duplicate benchmark cases" tool/bench/diff_load_profiles.dart tool/bench/load_profile_policy.dart tool/bench/run_load_profiles.dart test/tool/bench_diff_load_profiles_test.dart test/tool/bench_run_load_profiles_test.dart`

#### Fixtures Used

- inline baseline/current report maps in
  `test/tool/bench_diff_load_profiles_test.dart`

#### Positive Scenarios

- a valid report with `caseCount == cases.length` parses
- a valid report with missing required cases still produces diff failures

#### Negative Scenarios

- duplicate case name in baseline report is rejected
- duplicate case name in current report is rejected
- stale `caseCount` is rejected
- missing or non-integral `caseCount` is rejected

#### Closure Evidence

- slice-local tool tests pass
- structural trace still shows `_readReportFromObject(...)` as the diff input
  owner
- no missing-case comparison tests were converted into input-error tests

### Slice 2. [ ] Unit-Truthful Metric Diff Schema

#### Slice Contract

Every load-profile metric diff object emits neutral value fields and a
policy-owned unit, with no retired `...Us` fields remaining in metric diff
output.

#### Change

- Add failing reproducer tests in `test/tool/bench_diff_load_profiles_test.dart`
  showing RSS metric output currently carries `...Us` fields.
- Add neighboring guard tests proving latency metrics report
  `unit: microseconds`, RSS metrics report `unit: bytes`, retired fields are
  absent, and probe diffs keep their existing neutral fields.
- Add policy-owned metric-unit taxonomy in
  `tool/bench/load_profile_policy.dart`.
- Update metric diff construction and absolute-threshold failure text in
  `tool/bench/diff_load_profiles.dart`.

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_diff_load_profiles_test.dart`
- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart`

#### Structural Verification

- `dart run tool/lsp_trace_symbol.dart tool/bench/diff_load_profiles.dart _diffCase --direction=both --depth=3 --json`
- `rg -n "baselineUs|currentUs|deltaAbsUs" tool/bench test/tool/bench_diff_load_profiles_test.dart KNOWN_ISSUES.md`
- `dart run tool/analysis/find_similar_clones.dart --clusters --top 30 tool/bench 30 18 5 3 0.55 20`
- `dcm calculate-metrics tool/bench/diff_load_profiles.dart tool/bench/load_profile_policy.dart`

#### Fixtures Used

- inline full smoke report fixtures in
  `test/tool/bench_diff_load_profiles_test.dart`

#### Positive Scenarios

- latency metric diff output uses neutral value fields and
  `unit: microseconds`
- RSS metric diff output uses neutral value fields and `unit: bytes`
- probe diff output remains unchanged
- fractional metric precision remains preserved

#### Negative Scenarios

- metric diff output does not contain `baselineUs`
- metric diff output does not contain `currentUs`
- metric diff output does not contain `deltaAbsUs`
- policy-owned unit lookup rejects or fails fast for an unsupported required
  metric key

#### Closure Evidence

- slice-local tool tests pass
- search output shows retired fields no longer remain in implementation or
  active tests, except historical completed plan documents if present
- DCM metric output is reviewed as a signal; no metric-only refactor is
  required unless the implementation materially worsens touched functions

### Slice 3. [ ] Known-Issue And Architecture Retirement

#### Slice Contract

The repository source of truth no longer reports `KI-13` or `KI-14` as active
after the executable proof for both defects passes.

#### Change

- Remove `KI-13` and `KI-14` from `KNOWN_ISSUES.md`.
- Update
  `docs/architecture/families/diagnostics_performance_and_debug_surfaces.md`
  so its status no longer depends on those known issues.
- Add an `Unreleased` entry to `CHANGELOG.md` for the benchmark diff input
  validation and metric diff schema correction.
- Mark this step complete in `PLAN.md` and this contract only after final
  verification for the implementation change passes.

#### Behavioral Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart test/tool/bench_selection_control_diagnostics_test.dart test/tool/verification_contract_tool_test.dart`

#### Structural Verification

- `dart run tool/check_architecture_atlas.dart`
- `rg -n "KI-13|KI-14|known issue" KNOWN_ISSUES.md docs/architecture/families/diagnostics_performance_and_debug_surfaces.md docs/ARCHITECTURE_ATLAS.md`

#### Fixtures Used

- none

#### Positive Scenarios

- architecture-family status reflects the fixed benchmark schema and validation
  contract
- changelog communicates the tool-visible diff schema change
- plan checkboxes accurately reflect completed implementation work

#### Negative Scenarios

- `KNOWN_ISSUES.md` no longer lists resolved `KI-13` or `KI-14`
- architecture-family status no longer links to resolved known issues

#### Closure Evidence

- architecture atlas passes
- search output shows no active references to `KI-13` or `KI-14` outside
  completed historical plan text if any
- final required verification passes

## 11. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/bench_run_load_profiles_test.dart test/tool/bench_diff_load_profiles_test.dart test/tool/bench_selection_control_diagnostics_test.dart test/tool/verification_contract_tool_test.dart`
- `dart run tool/check_architecture_atlas.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_verification_contract.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/analysis/find_similar_clones.dart --clusters --top 30 tool/bench 30 18 5 3 0.55 20`
- `dcm analyze .`
- `dcm calculate-metrics tool/bench/diff_load_profiles.dart tool/bench/load_profile_policy.dart`
- `printf '%s\n' 'PLAN.md' 'plan/step_38_load_profile_diff_report_contract.md' 'tool/bench/load_profile_policy.dart' 'tool/bench/diff_load_profiles.dart' 'test/tool/bench_diff_load_profiles_test.dart' 'KNOWN_ISSUES.md' 'docs/architecture/families/diagnostics_performance_and_debug_surfaces.md' 'CHANGELOG.md' | dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=-`

## 12. Acceptance Criteria

- `KI-13` and `KI-14` are removed from active known issues only after
  regression proof passes.
- Duplicate diff input case names are rejected before comparison.
- Missing, non-integral, or mismatched diff input `caseCount` is rejected before
  comparison.
- Missing required cases remain diff policy failures.
- Metric diff output uses `baselineValue`, `currentValue`, `deltaAbs`, and
  `unit`.
- Metric diff output does not emit `baselineUs`, `currentUs`, or `deltaAbsUs`.
- Latency and RSS metric units are supplied by `load_profile_policy.dart`, not
  hard-coded as local diff output assumptions.
- Probe diff output remains compatible with its existing neutral field schema.
- Architecture-family status, changelog, plan checkboxes, and known-issue state
  match the implemented behavior.
- Final verification commands listed in section 11 pass, or any environment
  blocker is reported with the exact command and failure.
