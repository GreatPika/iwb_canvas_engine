language: russian

# Шаг 58. Исправить метрику сходства, diagnostics и CLI-контракт утилиты clone analysis

## 1. Change Mandate

This change fixes the confirmed correctness defects in
`tool/analysis/find_similar_clones.dart` so clone similarity metrics, parser
diagnostics, and CLI parameter handling become trustworthy before any
architecture-oriented feature work starts.

## 2. Change Boundary

### Included in the Change

- Consistency fixes for fingerprint accounting, overlap/jaccard calculation,
  and match-kind/report semantics under `tool/analysis/src/`.
- Collection and propagation of analyzer parse diagnostics for malformed or
  partially parsed files.
- Strict validation of numeric positional CLI arguments instead of silent
  fallback to defaults.
- Tool regression tests and plan updates required to pin these fixes.

### Not Included in the Change

- AST-aware canonicalization, architectural context/risk scoring, fragment
  search, drift analysis, or noise suppression from `plan/clone.md`.
- Any new clone-analysis mode, additional report mode, or broader report
  redesign beyond what is required to correct the confirmed defects.
- Changes outside the tool/test/plan zones listed below unless a targeted
  verification cannot close without them.

## 3. File Map and Analysis Areas

### Implementation Files

- `tool/analysis/src/clone_analysis_cli.dart`
- `tool/analysis/src/clone_analysis_collector.dart`
- `tool/analysis/src/clone_analysis_engine.dart`
- `tool/analysis/src/clone_analysis_models.dart`
- `tool/analysis/src/clone_analysis_report.dart`
- `PLAN.md`

### Test Files

- `test/tool/find_similar_clones_tool_test.dart`
- `test/tool/support/tool_process_test_support.dart` only if direct adaptation
  is required by the new regression coverage

### Fixture and Supporting Data Files

- `plan/clone.md`
- `plan/step_58_clone_analysis_correctness_and_diagnostics.md`

### Analysis Area

- `tool/analysis/**`
- `test/tool/find_similar_clones_tool_test.dart`
- `test/tool/support/**`
- `PLAN.md`
- `plan/clone.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must fix one of the confirmed defect
  classes for this step: similarity-accounting correctness, parser-diagnostic
  visibility, positional CLI validation, or misleading match labeling/report
  semantics.
- Every modified test file must pin at least one confirmed defect with an
  executable regression.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step fixes only the confirmed correctness defects in the existing
   clone-analysis tool and does not start feature work from `plan/clone.md`.
2. The confirmed defect set for this step is limited to similarity-metric
   consistency, parser-diagnostic visibility, positional numeric argument
   validation, and misleading raw-`exact` labeling.
3. The existing CLI entrypoint and the `pairs` / `clusters` report modes remain
   the protected operating surface for this step.
4. Regression proof for this area stays in the tool-test surface, with
   `test/tool/find_similar_clones_tool_test.dart` as the primary owner.

## 5. Result Requirements

1. Similarity metrics use one consistent fingerprint basis, so identical
   normalized blocks are not downgraded by repeated selected fingerprints.
2. Text and JSON output do not claim raw source-level exactness for matches
   that are equal only after normalization.
3. Files with analyzer parse diagnostics produce explicit parse-error output in
   tool results even when `parseString(...)` does not throw.
4. Invalid numeric positional CLI arguments fail with an explicit usage error
   and do not silently fall back to defaults.
5. Valid inputs continue to analyze successfully in both `pairs` and
   `clusters` modes.
6. `test/tool/find_similar_clones_tool_test.dart` contains regression coverage
   for the confirmed defect set and stays green through the canonical tool-test
   entrypoint.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `tool/analysis/src/clone_analysis_engine.dart` currently deduplicates
  fingerprint hashes per block before pair accumulation while similarity
  denominators use total selected fingerprints, which makes the metric
  internally inconsistent.
- `test/tool/find_similar_clones_tool_test.dart` currently encodes the
  repeated-k-gram case as `structural` with
  `bestPair=alpha <-> beta  overlap=81.0%  sharedFingerprints=17`.
- `tool/analysis/src/clone_analysis_collector.dart` currently records only
  thrown exceptions and does not surface analyzer parser diagnostics from
  malformed input.
- The current JSON run on malformed Dart input yields `scannedFiles=1`,
  `scannedBlocks=0`, and `parseErrors=[]`, so parse failure is invisible to the
  consumer.
- `tool/analysis/src/clone_analysis_cli.dart` currently falls back to defaults
  when numeric positional arguments fail to parse.
- `tool/analysis/src/clone_analysis_models.dart` currently exposes
  `CloneMatchKind.exact` even though the collector aggressively normalizes
  identifiers and literals.

### 6.2 Target Verification Units

- `dart run tool/run_tool_tests.dart`
- `dart run tool/analysis/find_similar_clones.dart tool/analysis --top 10`
- `dart run tool/analysis/find_similar_clones.dart lib --top 20 --clusters`

### 6.3 Protected States, Data, or Structures

- Existing CLI entrypoint `tool/analysis/find_similar_clones.dart`.
- Existing supported options: `--json`, `--clusters`, `--exclude-main`,
  and `--top`.
- Existing pair-vs-cluster report selection flow.
- Existing Dart-file discovery and skip rules outside the confirmed defect
  fixes for this step.
- Tool-test sandbox support used by `test/tool/find_similar_clones_tool_test.dart`.

### 6.4 Allowed Semantic Change Zones

- Fingerprint counting and overlap/jaccard/match-kind calculation.
- Parse-diagnostic collection and parse-error propagation through text/JSON
  reporting.
- Positional CLI numeric parsing and usage-error behavior.
- Report fields directly affected by corrected match labeling or parse errors.
- Tool regression tests for the confirmed defect set.

### 6.8 Prohibited

- Implementing AST-aware canonicalization, architectural context/risk scoring,
  fragment search, drift analysis, or noise suppression in this step.
- Adding a second normalization mode, a new CLI mode, or a new report mode in
  this step.
- Preserving current buggy metric or labeling behavior by weakening tests to
  match the old output.
- Silently accepting invalid numeric positional arguments.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must be
   covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Fix similarity accounting and match-kind honesty

#### Slice Contract

Similarity metrics are calculated on one consistent fingerprint basis, and the
tool no longer claims raw source-level exactness for normalized-only matches.

#### Change

Align fingerprint accounting between pair accumulation and similarity
denominators, adjust match-kind model/report semantics accordingly, and replace
the existing repeated-k-gram regression in
`test/tool/find_similar_clones_tool_test.dart` with assertions that pin the
corrected behavior.

#### Verification

- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Two identical normalized bodies with repeated selected fingerprints report
  full similarity instead of the current depressed overlap.
- Two semantically different bodies that only converge after coarse
  normalization are not labeled as raw exact matches.

#### Negative Scenarios

- Cluster grouping across connected duplicates remains intact after the metric
  fix.
- Text and JSON reporting do not reintroduce a raw `exact` label through a
  secondary code path.

#### Closure Evidence

- Green run of `dart run tool/run_tool_tests.dart`.
- Updated regression assertions in `test/tool/find_similar_clones_tool_test.dart`
  no longer encode `overlap=81.0%` for the repeated-k-gram case.

### Slice 2. [x] Surface parser diagnostics and reject invalid positional args

#### Slice Contract

Parser diagnostics are visible to tool consumers, and invalid numeric
positional arguments fail explicitly instead of silently using defaults.

#### Change

Collect analyzer parse diagnostics in the collector/report/CLI path, tighten
positional numeric parsing, and extend
`test/tool/find_similar_clones_tool_test.dart` with direct regressions for
malformed input and invalid numeric arguments.

#### Verification

- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Malformed Dart input produces explicit parse-error output in JSON and text
  reporting.
- Invalid numeric positional input exits with a usage error instead of
  continuing with defaults.
- Valid positional numeric inputs still run successfully.

#### Negative Scenarios

- Clean files do not gain synthetic parse errors.
- Omitted optional positional arguments still use the documented defaults.

#### Closure Evidence

- Green run of `dart run tool/run_tool_tests.dart`.
- Updated regression assertions in `test/tool/find_similar_clones_tool_test.dart`
  cover malformed input and invalid positional input.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner preset: `core`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `controller_internal`
- MCP test runner preset: `controller`
- MCP test runner preset: `render_view`
- MCP test runner preset: `interactive`
- MCP test runner preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
