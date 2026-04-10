language: english

# Change Contract

## 1. Change Mandate
This change fixes `tool/check_coverage.dart` so one machine-first invocation
against the existing LCOV artifact provides enough actionable information for
the implementing agent to choose the next source file and test file without
exploratory repository searches.

## 2. Change Boundary

### Included in the Change
- Machine-first triage output from `dart run tool/check_coverage.dart`.
- Internal decomposition of `check_coverage` logic under `tool/src/`.
- Deterministic source-gap clustering, source context extraction, and test
  target resolution for `lib/src/**` coverage gaps.
- Repository-local documentation updates for the new `check_coverage`
  workflow.

### Not Included in the Change
- Changes to how `flutter test --coverage` produces `coverage/lcov.info`.
- New coverage policy outside the existing `lib/src/**` ownership of
  `tool/check_coverage.dart`.
- New top-level coverage tooling entrypoints.
- Changes to unrelated guardrail, import-boundary, invariant, or public API
  tooling.

## 3. File Map and Analysis Areas

### Implementation Files
- `tool/check_coverage.dart`
- `tool/src/check_coverage/coverage_models.dart`
- `tool/src/check_coverage/coverage_lcov_parser.dart`
- `tool/src/check_coverage/coverage_declaration_locator.dart`
- `tool/src/check_coverage/coverage_test_target_locator.dart`
- `tool/src/check_coverage/coverage_machine_report.dart`
- `README.md`
- `AGENTS.md`
- `API_GUIDE.md`
- `CHANGELOG.md`

### Test Files
- `test/tool/coverage_tool_test.dart`

### Analysis Area
- `tool/check_coverage.dart`
- `tool/src/check_coverage/**`
- `test/tool/coverage_tool_test.dart`
- `lib/src/**`
- `test/**`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `tool/check_coverage.dart` remains the only top-level coverage gate
   entrypoint for `lib/src/**`.
2. The input artifact remains `coverage/lcov.info`; this change must not
   introduce a second coverage artifact format.
3. The machine output is optimized for tool consumption rather than human
   readability.
4. If `check_coverage` grows beyond one cohesive entrypoint file, internal
   logic must move under `tool/src/check_coverage/**` instead of remaining in
   one oversized CLI file.
5. Existing declaration-only and export-only coverage exemptions remain owned
   by `tool/check_coverage.dart`; this step optimizes diagnostics, not policy
   ownership transfer.
6. The machine report must expose one flat actionable gap collection rather
   than a file-grouped report intended for human reading.
7. The machine workflow keeps the existing `--json` and
   `--uncovered-branches` flags and adds one explicit `--changed-only` flag
   for git-based filtering.

## 5. Result Requirements

1. `dart run tool/check_coverage.dart --json` returns one compact machine
   report whose primary payload is a flat `gaps` collection.
2. Each gap record includes exactly these mandatory dimensions when the data
   exists for that gap kind: gap kind code, source path, enclosing declaration
   symbol or file-scope fallback code, declaration range, missed line list,
   missed branch list, compact source snippet, candidate test paths, and
   preferred verification scope.
3. `dart run tool/check_coverage.dart --json --changed-only` restricts the
   machine report to changed source files only, without requiring a separate
   git discovery command outside `tool/check_coverage.dart`.
4. `dart run tool/check_coverage.dart --json --uncovered-branches` reports
   branch gaps only when `coverage/lcov.info` contains branch records and
   signals the missing capability explicitly otherwise.
5. The final `check_coverage` implementation is file-cohesive: CLI
   orchestration, LCOV parsing, declaration resolution, test-target
   resolution, and machine-report assembly do not collapse back into one large
   mixed-responsibility file.
6. Machine gap records use compact machine-oriented codes and fields rather
   than narrative descriptions.
7. The machine report does not require a second grouped lookup to connect a
   gap with its tests, verification scope, declaration, or snippet.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Reuse the existing `analyzer` dev dependency for Dart structural analysis.
- Reuse the repository tooling decomposition pattern already used under
  `tool/src/**`.
- Read repository source files only for the files that appear in the reported
  coverage gaps.
- Read repository test files only to resolve deterministic candidate targets
  for already reported source gaps.

### 6.2 Target Verification Units
- Sandbox process scenarios in `test/tool/coverage_tool_test.dart`.
- Machine-mode scenarios for missing LCOV files, declaration-clustered missed
  lines, declaration-clustered missed branches, missing `BRDA` capability,
  candidate test-target resolution, and changed-file filtering.
- Final repository checks invoked through the canonical verification command in
  `AGENTS.md` for code changes.

### 6.3 Protected States, Data, or Structures
- The existing exit-code contract for:
  - missing `coverage/lcov.info`
  - unknown CLI arguments
  - line-coverage failure
  - success
- The existing `lib/src/**` scan and allow-list/exemption semantics.
- The existing invocation path `dart run tool/check_coverage.dart`.

### 6.4 Allowed Semantic Change Zones
- LCOV parsing and internal coverage data models.
- Mapping missed coverage lines and branches to enclosing Dart declarations.
- Compact machine-report schema and machine-only flags.
- Deterministic candidate test-target and verification-scope resolution.
- Changed-file filtering.
- Internal module boundaries under `tool/src/check_coverage/**`.

### 6.5 Machine Report Contract
- The machine workflow is invoked through:
  - `dart run tool/check_coverage.dart --json`
  - `dart run tool/check_coverage.dart --json --uncovered-branches`
  - `dart run tool/check_coverage.dart --json --uncovered-branches --changed-only`
- The top-level machine payload must contain:
  - `gaps`
  - `warnings`
  - `branchDataAvailable`
  - `changedOnlyApplied`
- `gaps` is the primary machine contract and must be a flat list.
- Each gap record must contain:
  - `k`: gap kind code
  - `p`: normalized source path
  - `sym`: enclosing declaration symbol, or `null` for file-scope fallback
  - `scope`: declaration scope code, with a deterministic file-scope fallback
  - `rng`: declaration or file-scope range
  - `ml`: missed line payloads
  - `mb`: missed branch payloads
  - `sn`: compact source snippet
  - `tt`: candidate test paths
  - `sh`: preferred verification scope id from the canonical verification
    contract registry, or `null`
- Gap kind codes are limited to:
  - `mf` for a source file missing from LCOV
  - `ml` for missed-line-only executable gaps
  - `mb` for branch-only executable gaps
  - `mx` for executable gaps containing both missed lines and missed branches
- `ml` entries must carry line numbers and source text.
- `mb` entries must carry line number, block id, branch id, taken raw value,
  and source text.
- `sn` must be minimal deterministic context derived from repository source,
  not a second full-file payload.

### 6.6 Recognition Forms That Must Be Supported Within This Change
- Whole-file gaps where a `lib/src/**` file is absent from LCOV.
- Multiple missed lines inside one enclosing declaration merged into one
  actionable gap.
- Multiple missed branches inside the same enclosing declaration merged into
  the same actionable gap.
- File-scope gaps for executable regions that do not belong to an enclosing
  declaration.

### 6.7 Allowed Forms That Do Not Count as Violations
- Existing declaration-only allow-list units.
- Existing pure export-only units.
- Missing branch coverage data when LCOV contains no `BRDA` records.

### 6.8 Requirements for Resolution of Links and Structural Analysis
- Use `package:analyzer` to resolve enclosing declarations and declaration
  source ranges instead of regex-only source heuristics.
- Resolve candidate test targets only from files that actually exist under
  `test/**`.
- Use non-interactive git commands for changed-file filtering and degrade
  deterministically when git metadata is unavailable.

### 6.9 Prohibited
- Do not add a second top-level coverage CLI.
- Do not add narrative-only machine output fields whose purpose is human
  readability.
- Do not rescan the same source file separately for each reported gap.
- Do not widen coverage policy ownership beyond the current `lib/src/**` gate.
- Do not make file-grouped machine output the primary machine contract.
- Do not invent candidate test paths or verification scope ids that are not
  supported by the existing repository tree and the canonical verification
  contract registry under `tool/src/verification_contract/**`.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice introduces a new machine flag or machine field, the same slice
   must add the negative and positive sandbox scenarios that prove the field
   or flag behavior.
7. If a slice changes structural analysis, the same slice must prove both a
   recognized executable declaration and a file-scope fallback scenario where
   no enclosing declaration is available.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered
    valid.

## 8. Vertical Slices

### Slice 1. [x] Establish a compact machine-report foundation

#### Slice Contract
`tool/check_coverage.dart` exposes one compact machine-only mode that reports
the current missing-file, missed-line, and missed-branch data from
`coverage/lcov.info` as one flat machine-oriented gap collection without
changing the existing line-coverage gate semantics, and the CLI entrypoint
becomes a thin orchestrator over focused internal modules under
`tool/src/check_coverage/**`.

#### Change
- Extract the current LCOV parsing, option parsing, gap collection, and report
  assembly logic from `tool/check_coverage.dart` into:
  - `tool/src/check_coverage/coverage_models.dart`
  - `tool/src/check_coverage/coverage_lcov_parser.dart`
  - `tool/src/check_coverage/coverage_machine_report.dart`
- Keep `tool/check_coverage.dart` responsible only for CLI orchestration,
  current human-readable mode, and exit-code ownership.
- Replace verbose human-oriented JSON fields with a compact machine-only
  schema whose primary output is one flat `gaps` collection using compact
  kind codes instead of narrative descriptions.
- Keep `--json` as the machine entry flag and `--uncovered-branches` as the
  branch-expansion flag.
- Preserve the existing non-machine CLI output and exit-code semantics.

#### Verification
- `dart run tool/run_tool_tests.dart test/tool/coverage_tool_test.dart`

#### Positive Scenarios
- Machine mode reports missing-from-LCOV source files.
- Machine mode reports missed lines from existing LCOV entries.
- Machine mode reports uncovered branches when `BRDA` entries are present.
- Machine mode emits `gaps`, `warnings`, `branchDataAvailable`, and no
  file-grouped primary payload.

#### Negative Scenarios
- Unknown CLI arguments still fail with the current error contract.
- Missing `coverage/lcov.info` still fails with the current error contract.

#### Closure Evidence
- Green run of the listed verification.
- Sandbox output proving compact machine-mode records for missing files,
  missed lines, and missed branches.

### Slice 2. [x] Cluster gaps by enclosing declaration

#### Slice Contract
The machine report no longer emits raw per-line gaps only; it emits actionable
gap clusters keyed to the enclosing declaration or a file-scope fallback,
including declaration symbol, declaration range, and minimal source context.

#### Change
- Add `tool/src/check_coverage/coverage_declaration_locator.dart`.
- Use `package:analyzer` to map missed lines and branches in each affected
  `lib/src/**` file to the nearest enclosing executable declaration.
- Merge adjacent or same-declaration missed lines and missed branches into one
  actionable gap record.
- Emit declaration symbol, declaration range, and compact source context in
  the machine report.
- Emit deterministic file-scope fallback metadata when no enclosing
  declaration is available.

#### Verification
- `dart run tool/run_tool_tests.dart test/tool/coverage_tool_test.dart`

#### Positive Scenarios
- Missed lines inside one top-level function are merged into one declaration
  gap.
- Missed branches inside one method are attached to the same declaration gap.
- Source context is emitted for each declaration gap.

#### Negative Scenarios
- A gap outside an enclosing declaration is reported as a file-scope fallback
  instead of crashing or being dropped.
- Declaration mapping does not duplicate one missed line across multiple gap
  clusters.

#### Closure Evidence
- Green run of the listed verification.
- Sandbox diagnostics proving declaration-clustered gap output for both a
  declaration-backed case and a file-scope fallback case.

### Slice 3. [x] Resolve candidate tests for each actionable gap

#### Slice Contract
Each actionable machine gap includes deterministic candidate test targets and a
preferred verification scope derived from the existing repository test tree and
the canonical verification contract registry.

#### Change
- Add `tool/src/check_coverage/coverage_test_target_locator.dart`.
- Resolve candidate test files from existing `test/**` paths using
  deterministic path and basename matching against the affected `lib/src/**`
  file and its enclosing module area.
- Attach the preferred verification scope id from
  `tool/src/verification_contract/verification_contract_registry.dart` when
  the resolved target clearly belongs to one scope.
- Keep the result deterministic: if no candidate test exists on disk, emit an
  empty target set instead of inventing one.
- Keep candidate test paths attached directly to each actionable gap instead
  of requiring a second grouped lookup by file.

#### Verification
- `dart run tool/run_tool_tests.dart test/tool/coverage_tool_test.dart`

#### Positive Scenarios
- A render source gap resolves to existing render test files and the
  `render_view` verification scope.
- An interactive source gap resolves to existing interactive test files and
  the `interactive` verification scope.

#### Negative Scenarios
- A source file with no matching tests returns no candidate test paths instead
  of synthetic paths.
- Ambiguous matches remain deterministic across repeated runs.

#### Closure Evidence
- Green run of the listed verification.
- Sandbox diagnostics proving candidate-test and verification-scope fields for
  at least two repository areas.

### Slice 4. [x] Add changed-only triage and close the workflow contract

#### Slice Contract
The machine workflow can restrict output to changed source files from the
current git worktree, and repository documentation points future implementers
to the machine-first `check_coverage` workflow.

#### Change
- Extend `tool/check_coverage.dart` machine mode with the explicit
  `--changed-only` flag that strictly filters to changed source files only.
- Use non-interactive git commands only.
- Update `README.md`, `AGENTS.md`, `API_GUIDE.md`, and `CHANGELOG.md` to
  document the final machine-first workflow and the exact invocation forms:
  - `dart run tool/check_coverage.dart --json`
  - `dart run tool/check_coverage.dart --json --uncovered-branches`
  - `dart run tool/check_coverage.dart --json --uncovered-branches --changed-only`

#### Verification
- `dart run tool/run_tool_tests.dart test/tool/coverage_tool_test.dart`

#### Positive Scenarios
- Only changed source files are returned when the changed-file mode is
  requested.
- The final documented invocation matches the implemented CLI contract.

#### Negative Scenarios
- The changed-file mode degrades deterministically when git metadata is
  unavailable.
- Unchanged files are not returned when the changed-file mode is active.

#### Closure Evidence
- Green run of the listed verification.
- Sandbox diagnostics proving changed-file behavior.
- Documentation diff showing the final workflow contract.

## 9. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/coverage_tool_test.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<path-or->`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
