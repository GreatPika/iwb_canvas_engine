language: russian

# Шаг 54. Убрать residual `part`-coupling из `node_spec.dart` и `node_patch.dart` через explicit internal fast-path modules

## 1. Change Mandate

Этот шаг закрывает последние production `part` seams в `contract`: публичные
`node_spec.dart` и `node_patch.dart` становятся `part`-free boundary files, а
их internal validated fast path переносится в normal internal modules без
смены public API и без переноса snapshot-style backing/materialization model на
`NodeSpec` / `NodePatch`.

Closure status after step `55`: the local fast-path split below is now part of
the mechanically pinned final contract graph in
`plan/contract_target_architecture.md` and
`tool/check_guardrails.dart`.

## 2. Change Boundary

### Included in the Change

- `lib/src/contract/node_spec.dart`
- `lib/src/contract/node_patch.dart`
- Removal of `lib/src/contract/internal/node_spec_fast_path.part.dart`
- Removal of `lib/src/contract/internal/node_patch_fast_path.part.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/iwb_canvas_engine.dart` only for direct compatibility adaptation if the
  existing hidden-helper export shape must change to stay non-public
- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/snapshot_immutability_test.dart` only if direct proof
  adaptation is required to pin collection/ownership semantics after the seam
  move
- `PLAN.md`
- `plan/step_54_node_spec_and_patch_explicit_fast_path_modules.md`

### Not Included in the Change

- `lib/src/contract/snapshot.dart`
- `lib/src/contract/internal/snapshot_backing.dart`
- `lib/src/contract/internal/snapshot_materialization.dart`
- `lib/src/contract/internal/snapshot_fast_path.dart`
- `lib/src/contract/internal/node_boundary_schema*.dart`
- `ARCHITECTURE.md`
- `tool/**`
- `example/**`
- Moving contract boundary validation into `model/**` or `controller/**`
- Introducing backing/materialization owners for `NodeSpec` or `NodePatch`
- Splitting `node_spec.dart` or `node_patch.dart` into one public file per
  node family

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/node_spec.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/iwb_canvas_engine.dart`

### Test Files

- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/snapshot_immutability_test.dart`

### Fixture and Supporting Data Files

- `PLAN.md`
- `plan/contract_target_architecture.md`
- `plan/step_53_snapshot_fast_path_explicit_internal_owners.md`
- `plan/step_54_node_spec_and_patch_explicit_fast_path_modules.md`

### Analysis Area

- `lib/src/contract/node_spec.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/internal/node_spec_fast_path.dart`
- `lib/src/contract/internal/node_patch_fast_path.dart`
- `lib/iwb_canvas_engine.dart`
- `test/contract/**`
- `test/public_api/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified public contract file must be tied either to preserving public
  validating constructor behavior or to exposing the exact internal-only
  allocation entrypoints required by the new fast-path modules.
- Every modified internal fast-path file must stay local to exactly one seam:
  `NodeSpec` or `NodePatch`.
- Every modified test must pin either public compatibility or the internal
  validated fast-path helper surface after the move out of `part`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `plan/contract_target_architecture.md` is the source of truth
   for the final post-step-`55` contract owner graph.
2. `node_spec.dart` and `node_patch.dart` remain the supported public boundary
   owners for `NodeSpec` and `NodePatch`.
3. `node_spec.dart` and `node_patch.dart` are `part`-free after this step.
4. `internal/node_spec_fast_path.dart` and `internal/node_patch_fast_path.dart`
   are normal Dart modules and the canonical internal import surfaces for
   validated spec/patch allocation helpers.
5. `node_spec.dart` and `node_patch.dart` expose exact `@internal`
   `*.prevalidated(...)` allocation entrypoints for the new internal modules
   instead of relying on `part`-shared private constructor access.
6. Public constructors and factories in `node_spec.dart` and
   `node_patch.dart` remain the normal runtime path: they validate locally and
   delegate directly to their own exact `*.prevalidated(...)` entrypoints
   instead of calling the new internal fast-path modules.
7. White-box contract tests move to
   `internal/node_spec_fast_path.dart`
   and
   `internal/node_patch_fast_path.dart`
   explicitly; they do not keep resolving validated helpers through the public
   contract library namespace.
8. The existing helper families
   `imageNodeSpecFromValidated`,
   `textNodeSpecFromValidated`,
   `strokeNodeSpecFromValidated`,
   `lineNodeSpecFromValidated`,
   `rectNodeSpecFromValidated`,
   `pathNodeSpecFromValidated`,
   `commonNodePatchFromValidated`,
   `imageNodePatchFromValidated`,
   `textNodePatchFromValidated`,
   `strokeNodePatchFromValidated`,
   `lineNodePatchFromValidated`,
   `rectNodePatchFromValidated`,
   and
   `pathNodePatchFromValidated`
   keep their current names, parameter shapes, and return types.
9. If the package barrel no longer needs `hide` combinators for helper names
   that stopped resolving through the public contract libraries, those stale
   hides are removed instead of being kept as dead compatibility noise.
10. `NodeSpec` and `NodePatch` do not gain snapshot-style backing or
   materialization owners in this step.
11. Public package exports remain unchanged; internal helper surfaces stay
   non-public.

## 5. Result Requirements

1. `node_spec.dart` contains no `part` directive and no `part`-attached
   fast-path helper body.
2. `node_patch.dart` contains no `part` directive and no `part`-attached
   fast-path helper body.
3. `internal/node_spec_fast_path.part.dart` and
   `internal/node_patch_fast_path.part.dart` no longer exist.
4. `internal/node_spec_fast_path.dart` and
   `internal/node_patch_fast_path.dart` exist as normal modules.
5. `NodeSpec` and `NodePatch` public constructors preserve their current
   validation, defaults, immutable payload handling, and public API shape.
6. The validated helper families listed in Locked Decision `8` remain
   available through the new internal modules and no longer depend on
   `part`-shared private access.
7. The validated helper families listed in Locked Decision `8` are no longer
   resolved from the public `node_spec.dart` / `node_patch.dart` libraries;
   white-box callers resolve them from the explicit internal fast-path
   modules.
8. Public `NodeSpec` / `NodePatch` / `CommonNodePatch` constructors and
   factories remain the single runtime validation truth and do not depend on
   the new internal fast-path modules.
9. The package barrel keeps the same public API semantics and does not retain
   stale `hide`-only export noise for helper names that are no longer present
   on the exported public libraries.
10. `rg -n "^(part|part of) " lib/src/contract -g '*.dart'` returns no
    matches.
11. No snapshot-style backing/materialization graph is introduced for
    `NodeSpec` or `NodePatch`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- After step `53`, the only remaining `contract` production seams are local to
  `node_spec.dart` and `node_patch.dart`.
- Unlike snapshots, `NodeSpec` and `NodePatch` do not have a producer-side
  multi-file graph in `model/**`; their fast path is a local validated
  allocation seam rather than a broader construction model.
- The correct fix for this step is therefore local: explicit internal
  fast-path modules plus exact internal allocation entrypoints, not a new
  backing/materialization graph.
- Public constructors and factories remain the normal runtime path; the new
  internal modules exist to house validated helper families for contract-local
  white-box use and must not become a second public-construction route.
- Contract tests currently rely on the validated helper families listed in
  Locked Decision `8`; those helper names should survive the seam move so test
  proof surfaces stay stable.

### 6.2 Target Verification Units

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/contract/node_spec.dart lib/src/contract/node_patch.dart lib/src/contract/internal/node_spec_fast_path.dart lib/src/contract/internal/node_patch_fast_path.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "^(part|part of) " lib/src/contract -g '*.dart'`
- MCP test runner:
  `test/contract test/public_api`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart` files
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Public `NodeSpec` constructor validation and defaulting semantics.
- Public `NodePatch` constructor validation, tri-state payload semantics, and
  `CommonNodePatch` default absent-field behavior.
- Existing write/runtime contracts that consume public `NodeSpec` and
  `NodePatch` values.
- Internal validated helper call shapes used by contract tests.

### 6.4 Allowed Semantic Change Zones

- Public `NodeSpec` / `NodePatch` internal-only allocation entrypoints.
- Public constructor/factory delegation to those exact entrypoints.
- Internal fast-path helper implementation and imports.
- Contract/public-api proof surfaces tied directly to the seam move.
- Minimal package-barrel adaptation required to keep helper surfaces internal.

### 6.8 Prohibited

- Keeping any `part` / `part of` directive in `lib/src/contract/**`.
- Introducing snapshot-style backing/materialization owners for `NodeSpec` or
  `NodePatch`.
- Renaming or widening the validated helper families listed in Locked Decision
  `8`.
- Routing public `NodeSpec` / `NodePatch` / `CommonNodePatch` constructor
  behavior through `internal/node_spec_fast_path.dart` or
  `internal/node_patch_fast_path.dart` instead of direct local validation plus
  `*.prevalidated(...)`.
- Exporting the new internal fast-path modules from the package root.
- Reopening `snapshot.dart` or `node_boundary_schema.dart` as part of this
  step.
- Generic builder/support buckets whose primary purpose is to hide the seam
  without clarifying ownership.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must
   be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. This step closes only if the entire `contract` layer is `part`-free after
   the change; closing just one of the two seams is insufficient.

## 8. Vertical Slices

### Slice 1. [x] Move `NodeSpec` validated fast path into an explicit internal module

#### Slice Contract

`node_spec.dart` becomes `part`-free while validated `NodeSpec` helper
construction survives through `internal/node_spec_fast_path.dart`.

#### Change

Introduce `internal/node_spec_fast_path.dart`, expose the exact `@internal`
`NodeSpec` prevalidated allocation entrypoints required by that module, move
the validated helper family into the new module, and delete
`node_spec_fast_path.part.dart`. Public `NodeSpec` constructors continue to
validate locally and delegate directly to those entrypoints instead of
importing the new internal fast-path barrel.

#### Verification

- `dcm calculate-metrics lib/src/contract/node_spec.dart lib/src/contract/internal/node_spec_fast_path.dart --report-all`
- `! rg -n "part 'internal/node_spec_fast_path.part.dart'|part of '../node_spec.dart'" lib/src/contract`
- MCP test runner:
  `test/contract/validated_fast_path_contract_test.dart test/contract/runtime_contract_interfaces_test.dart`

#### Positive Scenarios

- Public `RectNodeSpec(...)` and other public spec constructors still work in
  runtime/write flows.
- Validated helper construction still builds typed `NodeSpec` values with the
  same defaults and schema semantics.

#### Closure Evidence

- Green run of the listed verifications.
- No `NodeSpec` fast-path helper remains attached via `part`.

### Slice 2. [x] Move `NodePatch` validated fast path into an explicit internal module

#### Slice Contract

`node_patch.dart` becomes `part`-free while validated `NodePatch` /
`CommonNodePatch` helper construction survives through
`internal/node_patch_fast_path.dart`.

#### Change

Introduce `internal/node_patch_fast_path.dart`, expose the exact `@internal`
`NodePatch` and `CommonNodePatch` prevalidated allocation entrypoints required
by that module, move the validated helper family into the new module, and
delete `node_patch_fast_path.part.dart`. Public `NodePatch` /
`CommonNodePatch` constructors and factories continue to validate locally and
delegate directly to those entrypoints instead of importing the new internal
fast-path barrel.

#### Verification

- `dcm calculate-metrics lib/src/contract/node_patch.dart lib/src/contract/internal/node_patch_fast_path.dart --report-all`
- `! rg -n "part 'internal/node_patch_fast_path.part.dart'|part of '../node_patch.dart'" lib/src/contract`
- MCP test runner:
  `test/contract/validated_fast_path_contract_test.dart test/public_api/node_patch_semantics_test.dart`

#### Positive Scenarios

- Public `NodePatch` constructors still expose the same tri-state patch
  semantics.
- Validated helper construction still builds typed `NodePatch` and
  `CommonNodePatch` values with the same defaults.

#### Closure Evidence

- Green run of the listed verifications.
- No `NodePatch` fast-path helper remains attached via `part`.

### Slice 3. [x] Prove the full contract layer is `part`-free after the local seam cleanup

#### Slice Contract

No production `contract` file uses `part` / `part of`, and the remaining
public/internal contract surfaces keep the same supported API shape.

#### Change

Adapt package-barrel hides or white-box test imports as needed, remove the
last `part` residuals from `lib/src/contract/**`, and prove that the public
surface and downstream write/runtime contracts stay intact. After this slice,
validated helper families are reached only through explicit internal fast-path
modules, while public runtime callers continue to use public constructors and
factories.

#### Verification

- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "^(part|part of) " lib/src/contract -g '*.dart'`
- MCP test runner:
  `test/contract test/public_api`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart` files

#### Closure Evidence

- Green run of the listed verifications.
- `rg` returns no remaining `part` / `part of` directives under
  `lib/src/contract/**`.

## 9. Final Verification

- `dart format --output=none --set-exit-if-changed lib test example/lib example/test tool`
- `flutter analyze`
- `(cd example && flutter analyze lib test)`
- `dcm analyze .`
- `dcm calculate-metrics lib/src/contract/node_spec.dart lib/src/contract/node_patch.dart lib/src/contract/internal/node_spec_fast_path.dart lib/src/contract/internal/node_patch_fast_path.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters lib/src/contract`
- `dart run tool/check_import_boundaries.dart`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `rg -n "^(part|part of) " lib/src/contract -g '*.dart'`
- MCP test runner:
  `test/core`
- MCP test runner:
  `test/model test/serialization test/contract test/public_api test/entrypoints`
- MCP test runner:
  `test/controller/internal`
- MCP test runner:
  `test/controller/core test/controller/commands` plus controller-root
  `*_test.dart` files
- MCP test runner:
  `test/render test/view`
- MCP test runner:
  `test/interactive`
- MCP test runner:
  `example/test` with MCP root `example/`
- `flutter test --coverage --no-pub --exclude-tags=tool`
- `dart run tool/check_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
