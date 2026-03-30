language: russian

# Шаг 59. Заменить грубую нормализацию на portable AST-aware canonicalizer

## 1. Change Mandate

This change replaces the current coarse token normalization in
`tool/analysis/find_similar_clones.dart` with one portable AST-aware
canonicalizer so clone matching preserves structural meaning while ignoring only
rename-only noise from executable-local variables.

## 2. Change Boundary

### Included in the Change

- Replacement of the collector-side coarse identifier/literal normalization
  with one syntax-only canonicalization pipeline.
- Canonical handling for parameters, executable-local variables, and fixed
  literal categories.
- Tool regression tests required to pin the canonicalizer semantics.
- Plan updates required to track the step and its verification.

### Not Included in the Change

- Fragment-level clone search inside method subranges.
- Architectural context, project-map configuration, or risk scoring.
- Clone-pattern classification, drift analysis, or safe-noise suppression.
- Changes outside the tool/test/plan zones listed below unless a targeted
  verification cannot close without them.

## 3. File Map and Analysis Areas

### Implementation Files

- `tool/analysis/src/clone_analysis_collector.dart`
- `tool/analysis/src/clone_analysis_canonicalizer.dart`
- `PLAN.md`

### Test Files

- `test/tool/find_similar_clones_tool_test.dart`
- `test/tool/support/tool_process_test_support.dart` only if direct adaptation
  is required by the new canonicalizer regressions

### Fixture and Supporting Data Files

- `plan/clone.md`
- `plan/step_59_clone_analysis_portable_canonicalizer.md`

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

- Every modified implementation file must either introduce the canonicalizer or
  route existing collection through it.
- Every modified test file must pin one concrete canonicalization rule or
  regression caused by removing the old coarse normalizer.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step uses one portable syntax-only AST canonicalizer and does not use
   resolved analyzer symbols or a package-level analysis context.
2. The tool keeps exactly one canonicalization mode; no fallback or parallel
   coarse-normalization path is allowed.
3. Parameters are canonicalized as `PARAM_n` in source order per executable.
4. Executable-local variables are canonicalized as `LOCAL_n` in first-
   declaration order per executable.
5. Catch variables and `for` / `for-in` loop variables are executable-local
   variables and must also canonicalize as `LOCAL_n`.
6. All identifiers other than the bound parameter/local references above keep
   their original lexeme.
7. Literal normalization is fixed to these exact canonical tokens only:
   `INT`, `DOUBLE`, `STR`, `true`, `false`, and `null`.
8. Named-argument labels are not rewritten as `PARAM_n` or `LOCAL_n`.

## 5. Result Requirements

1. Clone detection no longer collapses all identifiers into one token class.
2. Two executables that differ only by parameter or executable-local variable
   names still match through stable `PARAM_n` / `LOCAL_n` canonicalization.
3. Called member names, field names, constructor names, type names, and named-
   argument labels remain distinguishable in the canonical token stream.
4. Integer, double, string, bool, and null literals canonicalize only to the
   fixed literal-token set from this contract.
5. The tool continues to operate without repository-specific configuration.
6. `test/tool/find_similar_clones_tool_test.dart` contains regression coverage
   for the canonicalizer rules above and stays green through the canonical
   tool-test entrypoint.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `plan/clone.md` fixes the next highest-priority improvement as removal of
  coarse normalization in favor of one AST-aware canonicalizer.
- The current collector still rewrites every identifier to `ID`, which hides
  member/type/call semantics that are necessary for better structural clone
  signals.
- The correctness fixes from step `58` are the dependency for this step and are
  not reopened here.
- The canonicalizer must stay portable across repositories, so the chosen
  implementation cannot depend on repo-local path conventions or resolved
  package graph state.
- The canonicalizer remains a flat token producer for the existing collector
  output; this step does not replace the fingerprint engine or pair/cluster
  pipeline.

### 6.2 Target Verification Units

- `dart run tool/run_tool_tests.dart`
- `dart run tool/analysis/find_similar_clones.dart tool/analysis --top 10`
- `dart run tool/analysis/find_similar_clones.dart lib --top 20 --clusters`

### 6.3 Protected States, Data, or Structures

- Existing CLI entrypoint and supported options of
  `tool/analysis/find_similar_clones.dart`.
- Existing pair-vs-cluster reporting flow.
- Correctness fixes delivered by step `58`.
- Portability of the clone-analysis tool across repositories without mandatory
  repo-local configuration.

### 6.4 Allowed Semantic Change Zones

- Canonical token production from AST nodes.
- Collection-time routing from executable bodies into the canonicalizer.
- Token-line tracking derived from canonical-token emission points.
- Tool regression tests that pin canonicalizer behavior.

### 6.5 Recognition Forms That Must Be Supported Within This Change

- parameter reference
- local-variable reference
- catch-parameter reference
- `for` / `for-in` loop-variable reference
- method invocation name
- constructor invocation name
- property-access field name
- named-argument label

### 6.6 Allowed Forms That Do Not Count as Violations

- Keywords, punctuation, and operators remain as their existing lexical form.
- Type names, class names, enum values, field names, method names, constructor
  names, and top-level declaration names keep their original lexeme.
- Expression-bodied, block-bodied, constructor-bodied, and top-level function
  executables all remain valid collection inputs for this step.

### 6.7 Requirements for Resolution of Links and Structural Analysis

- The canonicalizer must maintain an explicit executable-local lexical-scope
  stack and bind parameter/local references from syntax alone.
- `FormalParameter` declarations allocate `PARAM_n` indexes in source order per
  executable.
- Local variable declarations allocate `LOCAL_n` indexes in first-declaration
  order per executable.
- Catch variables and `for` / `for-in` loop variables allocate `LOCAL_n`
  indexes using the same first-declaration order rule.
- Repeated references to the same bound parameter/local within one executable
  must reuse the same canonical token.
- Canonical token order must remain source-order stable so the existing
  fingerprint engine receives a deterministic flat stream.
- The collector must derive line mapping from canonical-token emission points
  instead of raw `Token.next` traversal.

### 6.8 Prohibited

- Introducing a resolved-symbol dependency or project-wide analysis context in
  this step.
- Reintroducing a coarse fallback mode alongside the canonicalizer.
- Rewriting identifiers other than parameter/local references into synthetic
  canonical names.
- Adding fragment search, project-map configuration, risk scoring, drift
  analysis, or clone-pattern classification in this step.

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

### Slice 1. [ ] Replace coarse normalization with one portable canonicalizer

#### Slice Contract

Clone analysis uses one portable AST-aware canonicalizer with only the fixed
parameter/local/literal rewrites defined by this contract.

#### Change

Introduce `tool/analysis/src/clone_analysis_canonicalizer.dart`, route the
collector through it, remove the old `ID` / `NUM` / `STR`-style coarse
normalization path, and update regressions to pin the new canonical form.

#### Verification

- `dart run tool/run_tool_tests.dart`

#### Positive Scenarios

- Functions that differ only by parameter names still match through `PARAM_n`.
- Functions that differ only by local, catch, or loop-variable names still
  match through `LOCAL_n`.
- Integer literals canonicalize to `INT`, floating-point literals to `DOUBLE`,
  string literals to `STR`, and bool/null literals to `true`, `false`, and
  `null`.

#### Negative Scenarios

- Named-argument labels are preserved and are not rewritten into `PARAM_n` or
  `LOCAL_n`.
- Called member names, field names, constructor names, and type names are
  preserved and are not collapsed into one synthetic identifier token.
- The tool still runs without project-map configuration or analyzer resolution
  state.

#### Closure Evidence

- Green run of `dart run tool/run_tool_tests.dart`.
- Updated regressions in `test/tool/find_similar_clones_tool_test.dart` pin the
  exact `PARAM_n` / `LOCAL_n` and literal-token rules from this contract.

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
