language: russian

# Шаг 64. Перестроить `NodePatch` и `NodeSpec`: internal backing/materialization graph

## 1. Change Mandate

Этот шаг переоткрывает старую post-step-`55` asymmetry для
`NodeSpec`
и
`NodePatch`
как ошибочную целевую форму:
trusted boundary assembly уходит из public
`node_spec.dart`
и
`node_patch.dart`
в explicit internal backing/materialization owners,
публичный контракт остаётся совместимым как thin validating wrapper layer,
а
`internal/node_spec_fast_path.dart`
и
`internal/node_patch_fast_path.dart`
закрепляются как thin canonical contract-local construction barrels вместо
того, чтобы оставаться residual implementation buckets.

## 2. Change Boundary

### Included in the Change

- `lib/src/contract/node_spec.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/src/contract/internal/node_spec_backing.dart`
- `lib/src/contract/internal/node_spec_materialization.dart`
- `lib/src/contract/internal/node_patch_backing.dart`
- `lib/src/contract/internal/node_patch_materialization.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/contract_target_architecture.md`
- `plan/step_53_snapshot_fast_path_explicit_internal_owners.md`
- `plan/step_64_node_patch_and_spec_internal_backing_materialization.md`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/model/document_model_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart` only
  if direct adaptation is required to pin the lower-level internal owner
  surfaces mechanically

### Not Included in the Change

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/internal/snapshot*.dart`
- `lib/src/contract/internal/node_boundary_schema*.dart`
- `lib/src/model/**` beyond direct compatibility adaptation required by the
  listed verifications
- `lib/src/serialization/**`
- `lib/src/controller/**`
- `lib/src/render/**`
- `lib/src/view/**`
- `example/**`
- `API_GUIDE.md`
- `README.md`
- `CHANGELOG.md`
- Any new generic helper bucket such as `node_contract_support.dart`
- Producer-side rewiring analogous to snapshot step `53`
- New public exports, new public entrypoints, or public constructor signature
  changes for `NodeSpec`, `NodePatch`, or `CommonNodePatch`

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/node_spec.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/src/contract/internal/node_spec_backing.dart`
- `lib/src/contract/internal/node_spec_materialization.dart`
- `lib/src/contract/internal/node_patch_backing.dart`
- `lib/src/contract/internal/node_patch_materialization.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/contract_target_architecture.md`

### Test Files

- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/model/document_model_test.dart`
- `test/tool/guardrails/guardrails_contract_architecture_tool_test.dart`

### Fixture and Supporting Data Files

- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/contract_target_architecture.md`
- `plan/step_53_snapshot_fast_path_explicit_internal_owners.md`
- `plan/step_64_node_patch_and_spec_internal_backing_materialization.md`

### Analysis Area

- `lib/src/contract/node_spec.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/internal/node_spec*.dart`
- `lib/src/contract/internal/node_patch*.dart`
- `ARCHITECTURE.md`
- `PLAN.md`
- `plan/contract_target_architecture.md`
- `test/contract/**`
- `test/public_api/**`
- `test/model/document_model_test.dart`
- `test/tool/guardrails/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every new internal contract file must be tied to one exact owner role:
  backing, materialization, or canonical fast-path barrel.
- Every modified public contract file must stay a public validating wrapper
  owner and must not absorb a new mixed internal construction bucket.
- Every modified test must pin one proof of public compatibility, internal
  helper compatibility, or structural owner topology.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `plan/contract_target_architecture.md` remains the source of truth for the
   contract target graph and must be updated before implementation when the
   target graph changes.
2. Snapshot-style internal backing/materialization is the chosen fix for
   `NodeSpec` and `NodePatch`; local fast-path matrix compression alone does
   not close the seam anymore.
3. `node_spec.dart` and `node_patch.dart` remain the supported public boundary
   surfaces and must keep public API compatibility.
4. Public `NodeSpec`, `NodePatch`, and `CommonNodePatch` constructors and
   factories remain the normal runtime validation path.
5. `internal/node_spec_fast_path.dart` and
   `internal/node_patch_fast_path.dart`
   remain the canonical contract-local validated construction surfaces, but
   they become thin barrels over backing/materialization owners.
6. Snapshot architecture from step `53` is not reopened here; this step
   mirrors the internal graph pattern locally inside `contract/` without
   producer-side `model/**` rewiring.
7. The correct boundary for internal construction in this step is class-local
   materialization/backing access, not public top-level `prevalidated`
   entrypoints and not package-barrel `hide` suppression.
8. No generic `support`, `helpers`, or `utils` owner bucket is introduced for
   this redesign.

## 5. Result Requirements

1. `lib/src/contract/internal/node_spec_backing.dart` and
   `lib/src/contract/internal/node_spec_materialization.dart` exist and own
   the trusted immutable `NodeSpec` backing graph plus public wrapper
   materialization.
2. `lib/src/contract/internal/node_patch_backing.dart` and
   `lib/src/contract/internal/node_patch_materialization.dart` exist and own
   the trusted immutable `CommonNodePatch` / `NodePatch` backing graph plus
   public wrapper materialization.
3. `lib/src/contract/node_spec.dart` becomes a thin validating public wrapper
   surface over the internal spec backing graph instead of owning trusted
   family assembly itself.
4. `lib/src/contract/node_patch.dart` becomes a thin validating public wrapper
   surface over the internal patch backing graph instead of owning trusted
   family assembly itself.
5. `internal/node_spec_fast_path.dart` and
   `internal/node_patch_fast_path.dart`
   keep the current validated helper names, parameter shapes, and return
   types for white-box callers, but delegate through backing/materialization
   owners.
6. Public validation, defaults, `PatchField` tri-state semantics, and
   immutable stroke-point payload behavior remain unchanged.
7. `lib/iwb_canvas_engine.dart` keeps the same public export surface and does
   not gain `hide`-based suppression for new internal contract helpers.
8. `ARCHITECTURE.md`, `PLAN.md`, and
   `plan/contract_target_architecture.md`
   describe one consistent post-step-`64` contract graph.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The current seam is not just the repeated helper matrix inside
  `node_spec_fast_path.dart`
  and
  `node_patch_fast_path.dart`:
  public
  `node_spec.dart`
  and
  `node_patch.dart`
  still own trusted family assembly through `_validated` / `_internal`
  constructor chains, while the internal fast-path modules route validated
  data back through those public owners.
- Unlike snapshots, the codebase does not currently have a non-contract
  producer-side `NodeSpec` / `NodePatch` graph in `model/**`; the seam is
  contract-local, so the honest fix also stays contract-local.
- This step therefore introduces explicit internal backing/materialization
  owners for spec/patch while keeping downstream runtime/model code on the
  same public boundary objects.
- The redesign must remove the pressure to add public top-level internal
  entrypoints or package-root `hide` suppression by moving internal trusted
  construction behind class-local materialization/backing accessors instead.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/contract/node_spec.dart lib/src/contract/node_patch.dart lib/src/contract/internal/node_spec*.dart lib/src/contract/internal/node_patch*.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract`
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

### 6.3 Protected States, Data, or Structures

- Public `NodeSpec`, `NodePatch`, and `CommonNodePatch` field names, field
  types, and runtime constructor behavior.
- Public validation/default semantics for ids, geometry, opacity, patch
  presence, and family-local fields.
- Immutable ownership of stroke-point collections in both spec and patch
  surfaces.
- White-box validated helper call shapes used by contract tests.
- Public package export surface declared by `lib/iwb_canvas_engine.dart`.

### 6.4 Allowed Semantic Change Zones

- Internal `NodeSpec` backing and materialization ownership.
- Internal `NodePatch` / `CommonNodePatch` backing and materialization
  ownership.
- Public wrapper implementation in `node_spec.dart` and `node_patch.dart`.
- Internal compatibility helpers exposed through the fast-path barrels.
- Architecture/roadmap text and contract/public/model proof tests required to
  pin the new graph.

### 6.8 Prohibited

- Solving the step only by compressing or generifying the current fast-path
  matrices without introducing backing/materialization owners.
- Keeping trusted spec/patch assembly in public `_internal` constructor
  matrices after the redesign.
- Adding public top-level `prevalidated` entrypoints to
  `node_spec.dart`
  or
  `node_patch.dart`.
- Relying on `hide` clauses in `lib/iwb_canvas_engine.dart` to suppress newly
  introduced internal contract helpers.
- Reopening snapshot, model, serialization, render, or view architecture as
  the main subject of this step.
- Adding new public exports or changing public constructor signatures.
- Introducing duplicate synchronized state between public wrappers and
  internal backings.
- Introducing generic `support`, `helpers`, or `utils` buckets instead of the
  focused owner files listed above.
- Metric-only indirection that preserves the old ownership model under new
  names.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. This step is not closed while only one of `NodeSpec` or `NodePatch` has
   moved to an internal backing/materialization graph.
7. A fast-path barrel rewrite without new backing/materialization owners does
   not count as closing any slice.
8. Scope expansion is forbidden until the mandatory slices are closed.

## 8. Vertical Slices

### Slice 1. [x] Move `NodeSpec` onto an internal backing/materialization graph

#### Slice Contract

Public `NodeSpec` variants validate at the boundary and materialize through an
explicit internal spec backing graph instead of owning trusted family assembly
inside `node_spec.dart`.

#### Change

Create the focused internal `NodeSpec` backing/materialization owners, convert
`node_spec.dart` to a thin validating wrapper over them, and reduce
`internal/node_spec_fast_path.dart` to a compatibility barrel that keeps the
existing helper surface while delegating through the new internal graph.

#### Verification

- `dcm calculate-metrics lib/src/contract/node_spec.dart lib/src/contract/internal/node_spec*.dart --report-all`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/model/document_model_test.dart`

#### Positive Scenarios

- Every `NodeSpec` family still constructs through the public API with the
  same field values and defaults.
- White-box validated helpers still return typed public `NodeSpec` objects
  through the same helper names and call shapes.
- `StrokeNodeSpec.points` remains immutable after construction.

#### Negative Scenarios

- Invalid public spec values still fail fast with `ArgumentError`.
- The slice is not accepted if `node_spec.dart` still contains the trusted
  family assembly path and the new files exist only as wrappers around it.

#### Closure Evidence

- Green run of the listed verifications.
- Code inspection shows `node_spec.dart` is a public wrapper owner while
  trusted storage/materialization lives under `internal/node_spec_*.dart`.

### Slice 2. [x] Move `NodePatch` onto an internal backing/materialization graph

#### Slice Contract

Public `CommonNodePatch` and `NodePatch` variants validate at the boundary and
materialize through an explicit internal patch backing graph instead of owning
trusted family assembly inside `node_patch.dart`.

#### Change

Create the focused internal `NodePatch` / `CommonNodePatch`
backing/materialization owners, convert `node_patch.dart` to a thin
validating wrapper over them, and reduce
`internal/node_patch_fast_path.dart`
to a compatibility barrel that keeps the existing helper surface while
delegating through the new internal graph.

#### Verification

- `dcm calculate-metrics lib/src/contract/node_patch.dart lib/src/contract/internal/node_patch*.dart --report-all`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/validated_boundary_value_test.dart`
- `test/model/document_model_test.dart`

#### Positive Scenarios

- Every patch family still preserves tri-state semantics and current default
  absent-field behavior.
- White-box validated helpers still return typed public patch objects through
  the same helper names and call shapes.
- `StrokeNodePatch.points` remains immutable after construction.

#### Negative Scenarios

- Invalid present patch fields still fail fast with `ArgumentError`.
- The slice is not accepted if the new files merely forward back into a public
  trusted `_internal` constructor matrix.

#### Closure Evidence

- Green run of the listed verifications.
- Code inspection shows `node_patch.dart` is a public wrapper owner while
  trusted storage/materialization lives under `internal/node_patch_*.dart`.

### Slice 3. [x] Pin the new contract graph in docs and structural proofs

#### Slice Contract

The contract source-of-truth documents and structural proof surface describe
and verify `NodeSpec` / `NodePatch` as public wrappers over internal
backing/materialization owners, with fast-path files reduced to thin barrels.

#### Change

Update `ARCHITECTURE.md`,
`PLAN.md`,
`plan/contract_target_architecture.md`,
this step document,
and the structural contract tests; adapt guardrail tool tests only if direct
mechanical proof is required for the new lower-level internal files.

#### Verification

- `test/contract/contract_layer_smoke_test.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart` only if tool-test trigger files are
  touched by the implementation

#### Positive Scenarios

- Contract sources stay part-free and the public package surface stays
  unchanged.
- Contract structural proofs pin the fast-path barrels as explicit wrapper
  surfaces over backing/materialization owners.

#### Negative Scenarios

- The slice is not accepted if roadmap/docs still describe post-step-`55`
  asymmetry as intentional.
- The slice is not accepted if structural proofs allow public top-level
  internal helper seams or a new package-root `hide` workaround.

#### Closure Evidence

- Green run of the listed verifications.
- Updated docs and tests point to one consistent post-step-`64` graph.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/contract/node_spec.dart lib/src/contract/node_patch.dart lib/src/contract/internal/node_spec*.dart lib/src/contract/internal/node_patch*.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/analysis/find_similar_clones.dart lib/src/contract`
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
