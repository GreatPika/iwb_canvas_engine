language: russian

# Шаг 64. Сжать residual fast-path family matrix в `NodePatch` и `NodeSpec`

## 1. Change Mandate

Этот шаг дожимает residual fast-path family matrix в
`node_patch_fast_path.dart`
и
`node_spec_fast_path.dart`:
ручная матрица `fromValidated` helper-ов и default field factories перестаёт
быть серией почти одинаковых family-local конструкторов и сводится к
компактной внутренней assembly-схеме.

После шага
`node_patch.dart`
и
`node_spec.dart`
сохраняют текущий публичный контракт,
`internal/node_patch_fast_path.dart`
и
`internal/node_spec_fast_path.dart`
остаются canonical internal validated allocation surfaces,
но перестают быть mixed-owner buckets с ручной family-матрицей.

## 2. Change Boundary

### Included in the Change

- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/node_patch.dart` only if direct internal adaptation is
  required to keep the public contract unchanged while compressing the fast
  path
- `lib/src/contract/node_spec.dart` only if direct internal adaptation is
  required to keep the public contract unchanged while compressing the fast
  path
- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart` only if direct proof
  adaptation is required by the new internal assembly form
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart` only
  if direct adaptation is required to pin the canonical internal fast-path
  surface
- `PLAN.md`
- `plan/contract_target_architecture.md`
- `plan/step_54_node_spec_and_patch_explicit_fast_path_modules.md`
- `plan/step_55_contract_final_architecture_closure.md`
- `plan/step_64_node_patch_and_spec_fast_path_family_compression.md`

### Not Included in the Change

- `lib/src/contract/internal/node_boundary_schema*.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/snapshot_backing.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/model/**`
- `lib/src/serialization/**`
- `ARCHITECTURE.md`
- `API_GUIDE.md`
- `README.md`
- `CHANGELOG.md`
- Any new generic helper bucket such as `node_fast_path_support.dart`
- Introducing snapshot-style backing/materialization owners for
  `NodePatch` or `NodeSpec`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `PLAN.md`

### Test Files

- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`

### Fixture and Supporting Data Files

- `plan/contract_target_architecture.md`
- `plan/step_54_node_spec_and_patch_explicit_fast_path_modules.md`
- `plan/step_55_contract_final_architecture_closure.md`
- `plan/step_64_node_patch_and_spec_fast_path_family_compression.md`

### Analysis Area

- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `test/contract/**`
- `test/public_api/node_patch_semantics_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified internal fast-path file must be tied either to removing one
  repeated family-construction matrix or to preserving the canonical internal
  helper surface while doing so.
- Every modified public contract file must only provide direct internal
  compatibility required by the compressed fast path; it must not expose new
  public behavior.
- Every modified test must pin one proof that validated helper behavior or the
  public patch/spec contract stayed equivalent after the compression.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `plan/contract_target_architecture.md` remains the source of truth for the
   post-step-`55` contract graph.
2. `node_patch.dart` and `node_spec.dart` remain the public boundary owners;
   their public contract must not expand in this step.
3. `internal/node_patch_fast_path.dart` and
   `internal/node_spec_fast_path.dart`
   remain the canonical internal validated allocation surfaces.
4. The validated helper family names, parameter shapes, and return types stay
   stable for existing white-box callers.
5. Public `NodePatch`, `CommonNodePatch`, and `NodeSpec` constructors and
   factories remain the normal runtime validation path and must not be turned
   into wrappers over a second public construction route.
6. The correct fix is local internal assembly compression, not snapshot-style
   backing/materialization and not a new generic support bucket.
7. Metric or clone improvement counts only when the current repeated family
   assembly is genuinely removed from the internal fast-path modules.

## 5. Result Requirements

1. `lib/src/contract/internal/node_patch_fast_path.dart` no longer expresses
   the current family matrix as six repeated `...PatchFromValidated(...)`
   helpers plus six parallel default field factories.
2. `lib/src/contract/internal/node_spec_fast_path.dart` no longer expresses
   the current family matrix as six repeated `...SpecFromValidated(...)`
   helpers that rebuild the same common assembly shape.
3. Validated helper families remain available through the same internal module
   surfaces with the same call shapes.
4. `node_patch.dart` and `node_spec.dart` keep the same public API and
   validation semantics.
5. The internal fast-path modules remain canonical and do not split into a new
   public or parallel internal construction path.
6. No generic support bucket or snapshot-style assembly graph is introduced.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Step `54` already moved `NodePatch` and `NodeSpec` fast paths into explicit
  internal modules; the residual seam is now the duplicated family matrix
  inside those modules.
- `node_patch_fast_path.dart` currently repeats the same pattern per family:
  resolve common,
  resolve fields with per-family default factories,
  then allocate the public patch variant.
- `node_spec_fast_path.dart` currently repeats the same common resolution and
  family allocation shape across all supported node families.
- The correct architectural fix is local to the internal fast-path modules:
  a compact internal assembly scheme that keeps the existing helper names and
  public boundary contract intact.
- Public `node_patch.dart` / `node_spec.dart` changes are allowed only when a
  direct internal compatibility edge is required to preserve the unchanged
  public contract while compressing the fast path.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract/internal/node_patch_fast_path.dart lib/src/contract/internal/node_spec_fast_path.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract`
- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `core`
- MCP test runner preset: `example`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`
- `dart run tool/run_tool_tests.dart` only if tool-test trigger files are
  touched by the implementation

### 6.3 Protected States, Data, or Structures

- Public `NodePatch`, `CommonNodePatch`, and `NodeSpec` semantics.
- Existing validated helper call shapes used by white-box contract tests.
- Internal canonical import through the fast-path modules.
- Boundary validation and defaulting semantics on public constructors.

### 6.4 Allowed Semantic Change Zones

- Internal family assembly inside
  `lib/src/contract/internal/node_patch_fast_path.dart`
- Internal family assembly inside
  `lib/src/contract/internal/node_spec_fast_path.dart`
- Minimal direct compatibility adaptation in
  `lib/src/contract/node_patch.dart`
  and
  `lib/src/contract/node_spec.dart`
  if required to keep the public contract unchanged
- Direct proof adaptation in the listed contract/public-api tests

### 6.8 Prohibited

- Expanding the public `NodePatch` or `NodeSpec` contract.
- Introducing snapshot-style backing/materialization owners for
  `NodePatch` or `NodeSpec`.
- Reopening `node_boundary_schema*.dart` or `snapshot*` seams as part of this
  step.
- Replacing the matrix with a new opaque generic framework whose primary
  purpose is only to silence metrics or clone tooling.
- Introducing a new generic helper bucket such as `node_fast_path_support.dart`.
- Expanding the scope into `model/**`, `serialization/**`, or render work.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice changes helper defaults or failure behavior, the exact visible
   surface must be pinned by tests in the same change.
7. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [ ] Compress the `NodePatch` fast-path family matrix

#### Slice Contract

`node_patch_fast_path.dart` keeps the same validated helper surface, but its
family-local `fromValidated` and default-field assembly no longer lives as a
manual six-family matrix.

#### Change

Refactor `lib/src/contract/internal/node_patch_fast_path.dart` so shared
family assembly, default patch field creation, and common patch resolution are
expressed through one compact internal scheme while preserving the current
helper names and return types.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_patch_fast_path.dart lib/src/contract/node_patch.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- MCP test runner preset: `model_contract`

#### Positive Scenarios

- Each `...PatchFromValidated(...)` helper still returns the same public patch
  variant for the same validated inputs.
- Common patch defaults and absent-field behavior remain unchanged.
- Family-local default patch fields remain equivalent to the previous shape.

#### Negative Scenarios

- No new public patch constructor or factory appears.
- The removed matrix does not survive under a different private naming shell.

#### Closure Evidence

- Green run of the listed verifications.
- `node_patch_fast_path.dart` no longer contains the current repeated family
  constructor plus default-field matrix.

### Slice 2. [ ] Compress the `NodeSpec` fast-path family matrix

#### Slice Contract

`node_spec_fast_path.dart` keeps the same validated helper surface, but common
resolution and family allocation stop repeating the same constructor matrix
across all node families.

#### Change

Refactor `lib/src/contract/internal/node_spec_fast_path.dart` so common spec
resolution and family allocation are expressed through one compact internal
assembly scheme while preserving the current helper names, parameter shapes,
and return types.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_spec_fast_path.dart lib/src/contract/node_spec.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- MCP test runner preset: `model_contract`
- MCP test runner preset: `core`
- MCP test runner preset: `example`

#### Positive Scenarios

- Each `...SpecFromValidated(...)` helper still returns the same public spec
  variant for the same validated inputs.
- Common spec defaults remain unchanged.
- White-box fast-path tests continue to resolve the same helper surfaces from
  the internal module.

#### Negative Scenarios

- No new public spec constructor or factory appears.
- The compressed assembly does not reopen snapshot-style or schema-level
  ownership.

#### Closure Evidence

- Green run of the listed verifications.
- `node_spec_fast_path.dart` no longer contains the current repeated family
  constructor matrix.

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
- `dart run tool/run_tool_tests.dart` only if tool-test trigger files are
  touched by the implementation

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
