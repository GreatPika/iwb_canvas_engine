language: russian

# Шаг 60. Добавить fragment-level clone search по последовательностям top-level statements

## 1. Change Mandate

This change introduces deterministic fragment-level clone search for
block-bodied executables so the tool can detect repeated contiguous statement
sequences inside large methods without requiring new tuning parameters or
heuristic risk models.

## 2. Change Boundary

### Included in the Change

- Collection of top-level statement boundaries for block-bodied executables.
- Deterministic fragment candidate extraction from matched fingerprint runs.
- Fragment-level pair reporting with exact matched-fragment line ranges.
- Tool regression tests and plan updates required to pin the new fragment
  search behavior.

### Not Included in the Change

- Architectural risk scoring, project-map configuration, or layer/module
  interpretation.
- Clone-pattern classification, drift analysis, or safe-noise suppression.
- New CLI flags or new tuning parameters for fragment search.
- Cluster-mode aggregation of fragment matches beyond the explicit rules of
  this step.
- Changes outside the tool/test/plan zones listed below unless a targeted
  verification cannot close without them.

## 3. File Map and Analysis Areas

### Implementation Files

- `tool/analysis/src/clone_analysis_collector.dart`
- `tool/analysis/src/clone_analysis_engine.dart`
- `tool/analysis/src/clone_analysis_models.dart`
- `tool/analysis/src/clone_analysis_report.dart`
- `tool/analysis/src/clone_analysis_fragmenter.dart`
- `PLAN.md`

### Test Files

- `test/tool/find_similar_clones_tool_test.dart`
- `test/tool/support/tool_process_test_support.dart` only if direct adaptation
  is required by the new fragment-search regressions

### Fixture and Supporting Data Files

- `plan/clone.md`
- `plan/step_59_clone_analysis_portable_canonicalizer.md`
- `plan/step_60_clone_analysis_fragment_level_search.md`

### Analysis Area

- `tool/analysis/**`
- `test/tool/find_similar_clones_tool_test.dart`
- `test/tool/support/**`
- `PLAN.md`
- `plan/clone.md`
- `plan/step_59_clone_analysis_portable_canonicalizer.md`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must either record top-level statement
  boundaries, derive deterministic fragment candidates, or report accepted
  fragment matches.
- Every modified test file must pin one concrete fragment-search behavior or
  regression introduced by this step.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step starts only after the portable canonicalizer from step `59` is
   closed and verified.
2. Fragment search applies only to `BlockFunctionBody` executables.
3. Fragment boundaries align only to contiguous top-level statements in the
   executable body block.
4. Nested statements inside `if`, `for`, `while`, `switch`, `try`, and other
   inner blocks do not become independent fragment roots in this step.
5. Fragment candidates are derived only from matched whole-body fingerprint
   occurrences; the tool must not generate all possible statement windows.
6. Existing numeric thresholds from the current CLI/config are reused; this
   step introduces no new search parameters.
7. Pair mode is the detailed inspection mode and includes both whole-body and
   accepted fragment matches.
8. Cluster mode is the repository overview mode and remains based only on
   whole-body matches in this step.
9. Pair-mode reporting must keep whole-body and fragment matches explicitly
   separated instead of mixing them into one undifferentiated result stream.

## 5. Result Requirements

1. The tool can detect repeated contiguous top-level statement sequences inside
   large block-bodied executables even when whole-body overlap is too low to
   report the owner pair as a whole-body clone.
2. Accepted fragment matches report the owner executable location plus the
   exact matched fragment line ranges on both sides.
3. Whole-body pair detection remains available after fragment search is added.
4. Pair-mode output distinguishes whole-body matches from fragment matches.
5. Cluster-mode output remains available and continues to reflect whole-body
   clone matches only.
6. No new CLI options or tuning parameters are required to use fragment
   search.
7. `test/tool/find_similar_clones_tool_test.dart` contains regression coverage
   for fragment detection and for the preserved whole-body/cluster behavior.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `plan/clone.md` identifies fragment-level clone search inside methods as the
  next deterministic improvement after canonicalization.
- The current tool analyzes only entire executable bodies, so repeated
  statement sequences inside large methods may remain undetected when whole-body
  overlap stays below the existing thresholds.
- This step must improve that signal without adding a second search pipeline
  that requires new tuning knobs or heuristic ranking models.
- The step depends on the stable canonicalizer from step `59`, because
  fragment matching must use the improved canonical token stream rather than the
  removed coarse normalizer.
- The user-facing logic of the tool is fixed in this step:
  cluster mode remains the whole-body architectural overview,
  while pair mode becomes the detailed inspection surface that can show both
  whole-body and fragment matches.

### 6.2 Target Verification Units

- `dart run tool/run_tool_tests.dart`
- `dart run tool/analysis/find_similar_clones.dart tool/analysis --top 10`
- `dart run tool/analysis/find_similar_clones.dart lib --top 20 --clusters`

### 6.3 Protected States, Data, or Structures

- Existing CLI entrypoint and supported options of
  `tool/analysis/find_similar_clones.dart`.
- Canonicalizer semantics delivered by step `59`.
- Whole-body pair detection and current whole-body cluster-mode behavior.
- Correctness fixes delivered by step `58`.

### 6.4 Allowed Semantic Change Zones

- Top-level statement-boundary extraction for block-bodied executables.
- Fragment candidate derivation from matched fingerprint runs.
- Fragment-local similarity calculation and pair reporting.
- Tool regression tests that pin fragment detection behavior.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- contiguous top-level statement fragment
- fragment clone inside otherwise non-clone large methods
- fragment bounded by one top-level statement
- fragment bounded by multiple contiguous top-level statements
- block-bodied executable without any accepted fragment
- non-block executable body

### 6.6 Allowed Forms That Do Not Count as Violations

- Expression-bodied and empty executables remain whole-body-only inputs and do
  not produce fragment candidates.
- A whole-body clone may still appear in pair mode together with additional
  fragment matches from the same owner pair.
- Cluster mode may omit fragment matches entirely in this step.
- Pair mode may report zero fragment matches even when whole-body matches are
  present.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The collector must record top-level statement ranges only for
  `BlockFunctionBody.block.statements`.
- Each recorded statement range must include canonical token start index,
  canonical token end index, start line, and end line within the owner
  executable token stream.
- Fragment candidate derivation occurs before whole-body overlap filtering and
  may inspect any owner pair with at least `minSharedFingerprints` shared
  fingerprint occurrences.
- For a candidate owner pair, matched fingerprint occurrences must be grouped
  by constant position delta `tokenPosA - tokenPosB`.
- Within each delta group, a run is maximal only when successive matched
  occurrences advance by exactly `+1` in both token-position sequences.
- Each run defines raw token spans
  `[runStartPos, runEndPos + kGramSize - 1]` on both sides.
- Each raw token span must expand outward to the smallest enclosing contiguous
  top-level statement range in the corresponding executable.
- Fragment candidates are deduplicated by
  `(ownerA id, firstStatementA, lastStatementA, ownerB id, firstStatementB, lastStatementB)`.
- For every deduplicated fragment candidate, the engine must slice canonical
  tokens to the fragment ranges and rerun the existing k-gram hashing plus
  fingerprint selection pipeline on those fragment slices.
- A fragment result is accepted only when both fragment slices have
  `tokenCount >= minTokens`, the fragment-local shared fingerprint count is at
  least `minSharedFingerprints`, and the fragment-local overlap is at least
  `minOverlap`.
- Whole-body results and fragment-level results must be explicitly marked in
  the result model with one fixed result-kind field.
- Pair-mode report output must render whole-body results and fragment results in
  separate sections, with all whole-body results first and all fragment results
  second.
- Pair-mode report output for a fragment result must print the owner executable
  location, the exact matched fragment line range on each side, and the parent
  executable line range on each side.
- Cluster-mode construction must ignore fragment-level results in this step.

### 6.8 Prohibited

- Generating all possible contiguous statement windows before matching.
- Adding a second configuration surface or new CLI thresholds for fragment
  search.
- Building fragment candidates from nested statements below the top-level body
  statement list in this step.
- Adding architectural risk scoring, project-map parsing, drift analysis, or
  clone-pattern classification in this step.

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

### Slice 1. [ ] Record top-level statement boundaries for block-bodied executables

#### Slice Contract

Block-bodied executables expose deterministic top-level statement boundary
metadata that can be used later for fragment extraction without changing
whole-body clone semantics.

#### Change

Extend collection/model surfaces to record canonical token and line ranges for
each top-level statement in a `BlockFunctionBody`, and add regressions that pin
the recorded boundary behavior for block-bodied and non-block executables.

#### Verification

- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- A block-bodied function records one boundary entry per top-level statement in
  source order.
- Non-block executables still collect as whole bodies and produce no fragment
  boundaries.

#### Negative Scenarios

- Nested statements inside top-level control-flow statements do not become
  independent boundary roots.
- Existing whole-body clone search output remains available after boundary
  collection is added.

#### Closure Evidence

- Green run of `dart run tool/run_tool_tests.dart`.
- Updated regressions in `test/tool/find_similar_clones_tool_test.dart` pin the
  top-level statement-boundary rules from this contract.

### Slice 2. [ ] Derive and report accepted fragment-level clone pairs

#### Slice Contract

Pair-mode clone analysis reports accepted fragment-level matches for contiguous
top-level statement sequences derived from matched fingerprint runs.

#### Change

Introduce `tool/analysis/src/clone_analysis_fragmenter.dart`, derive fragment
candidates from matched fingerprint runs using the exact rules of this
contract, calculate fragment-local similarity, and adapt pair reporting/tests
to pin exact matched-fragment output.

#### Verification

- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Two large methods with one repeated contiguous top-level statement sequence
  are reported through a fragment-level match even when their whole-body
  overlap remains below the reporting threshold.
- A repeated contiguous statement sequence spanning multiple top-level
  statements is reported with exact fragment line ranges.
- Pair mode still reports whole-body matches separately from fragment matches.

#### Negative Scenarios

- Cluster mode remains whole-body-only.
- Fragment search does not fabricate matches from nested statement bodies that
  are not top-level statement ranges.
- Fragment search does not require new CLI parameters.
- Pair mode does not mix whole-body and fragment matches into one
  undifferentiated list.

#### Closure Evidence

- Green run of `dart run tool/run_tool_tests.dart`.
- Updated regressions in `test/tool/find_similar_clones_tool_test.dart` pin the
  exact fragment-candidate derivation and reporting behavior from this
  contract.

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
