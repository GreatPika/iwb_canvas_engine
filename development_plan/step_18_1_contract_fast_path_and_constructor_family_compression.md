language: russian

# Шаг 18.1. Свести contract fast path и constructor families к компактной `schema-first` assembly

## 1. Change Mandate

Этот шаг сжимает contract-side family assembly для `snapshot/spec/patch` и их
validated fast path-ов вокруг уже существующего schema owner-а без изменения
public contract surface.
Snapshot-side validated fast-path consumer migration outside contract-owned
files remains downstream work of `18.2` and `18.3`.

## 2. Change Boundary

### Included in the Change

- `lib/src/contract/internal/node_boundary_schema.dart`
- `lib/src/contract/internal/node_boundary_schema_patch.part.dart`
- `lib/src/contract/internal/node_boundary_schema_spec.part.dart`
- `lib/src/contract/internal/node_boundary_schema_snapshot.part.dart`
- `lib/src/contract/internal/node_patch_fast_path.part.dart`
- `lib/src/contract/internal/node_spec_fast_path.part.dart`
- `lib/src/contract/internal/snapshot_fast_path.part.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/snapshot.dart`

### Not Included in the Change

- `lib/src/model/**`
- `lib/src/serialization/**`
- JSON transport semantics
- Runtime orchestration and render/view work

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/contract/internal/node_boundary_schema.dart`
- `lib/src/contract/internal/node_boundary_schema_patch.part.dart`
- `lib/src/contract/internal/node_boundary_schema_spec.part.dart`
- `lib/src/contract/internal/node_boundary_schema_snapshot.part.dart`
- `lib/src/contract/internal/node_patch_fast_path.part.dart`
- `lib/src/contract/internal/node_spec_fast_path.part.dart`
- `lib/src/contract/internal/snapshot_fast_path.part.dart`
- `lib/src/contract/node_patch.dart`
- `lib/src/contract/node_spec.dart`
- `lib/src/contract/snapshot.dart`

### Test Files

- `test/contract/contract_layer_smoke_test.dart`
- `test/contract/owned_collections_test.dart`
- `test/contract/runtime_contract_interfaces_test.dart`
- `test/contract/validated_fast_path_contract_test.dart`
- `test/contract/validated_internal_helpers_test.dart`
- `test/public_api/node_patch_semantics_test.dart`
- `test/public_api/snapshot_immutability_test.dart`
- `test/public_api/validated_boundary_value_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_18_1_contract_fast_path_and_constructor_family_compression.md`

### Analysis Area

- `lib/src/contract/**`
- `test/contract/**`
- `test/public_api/**`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one contract-side slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `NodeBoundarySchema` remains the only private contract-owned owner of field
   semantics.
2. Public contract types remain explicit.
3. Validated fast path-ы stay already-validated builders and do not become
   generic parsers.
4. External JSON contract and schema versioning remain unchanged.
5. This step must delete duplicate family assembly and not move it into a
   second helper table.

## 5. Result Requirements

1. Contract seam no longer keeps duplicate family assembly across public
   constructors and validated fast path-ы for the same node family.
2. Public constructor behavior and fast-path output stay equivalent to the
   current public contract.
3. The current confirmed contract-side hotspots improve against the starting
   baseline for the files fully owned by this step:
   `node_patch_fast_path.part.dart = 7 HIGH+`,
   `node_spec_fast_path.part.dart = 7 HIGH+`.
4. `snapshot_fast_path.part.dart` remains behaviorally aligned with the new
   compact contract assembly, while its downstream consumer-side hotspot
   closure is deferred to `18.2` and `18.3`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- Current confirmed parameter hotspots inside the seam are:
  - `textNodePatchFromValidated(...) = 12`
  - `textNodeSpecFromValidated(...) = 19`
- Current confirmed `snapshot` fast-path hotspot
  `textNodeSnapshotFromValidated(...) = 21` cannot be fully closed inside this
  step without migrating model and decode consumers that are out of boundary
  for `18.1`; that closure is owned downstream by `18.2` and `18.3`.
- Current confirmed clone families remain inside the contract seam between
  public constructor bodies and validated fast paths.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/contract/internal/node_boundary_schema.dart lib/src/contract/internal/node_boundary_schema_patch.part.dart lib/src/contract/internal/node_boundary_schema_spec.part.dart lib/src/contract/internal/node_boundary_schema_snapshot.part.dart lib/src/contract/internal/node_patch_fast_path.part.dart lib/src/contract/internal/node_spec_fast_path.part.dart lib/src/contract/internal/snapshot_fast_path.part.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/contract`
- MCP test runner: `test/contract/contract_layer_smoke_test.dart test/contract/owned_collections_test.dart test/contract/runtime_contract_interfaces_test.dart test/contract/validated_fast_path_contract_test.dart test/contract/validated_internal_helpers_test.dart`
- MCP test runner: `test/public_api/node_patch_semantics_test.dart test/public_api/snapshot_immutability_test.dart test/public_api/validated_boundary_value_test.dart`
- `dart run tool/check_public_api_surface.dart`

### 6.3 Protected States, Data, or Structures

- Public constructor surface for `NodePatch`, `NodeSpec`, and `SceneSnapshot`.
- Already-validated behavior of internal fast paths.
- `NodeBoundarySchema` ownership of field semantics.

### 6.4 Allowed Semantic Change Zones

- Common and family-specific contract-side assembly for constructor inputs.
- Fast-path family assembly for already-validated values.
- Thin helper glue inside `lib/src/contract/internal/**`.

### 6.8 Prohibited

- Introducing a second contract-side owner of the same family assembly.
- Changing accepted public inputs or output semantics.
- Leaving legacy duplicate family bodies next to the new compact assembly.

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

### Slice 1. [x] Compact contract-side family assembly exists

#### Slice Contract

Contract seam has one compact private assembly for common and family-specific
constructor input handling inside the allowed contract zone.

#### Change

Свести repeating family assembly in `node_patch.dart`, `node_spec.dart`,
`snapshot.dart`, and related internal helpers to one compact contract-side
path derived from `NodeBoundarySchema`.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_boundary_schema.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- MCP test runner: `test/contract/contract_layer_smoke_test.dart test/contract/validated_internal_helpers_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Contract seam no longer keeps separate handwritten family assembly in the
  migrated constructor bodies.

### Slice 2. [x] Fast path and public constructors consume the same compact path

#### Slice Contract

Validated fast paths and public constructors consume the same compact family
assembly without keeping duplicate bodies for the same node family.

#### Change

Перевести `node_patch_fast_path.part.dart` and
`node_spec_fast_path.part.dart` на тот же compact assembly, close the
contract-owned fast-path hotspots in those files, and align
`snapshot_fast_path.part.dart` with the same assembly without reopening
downstream consumer migration that belongs to `18.2` and `18.3`.

#### Verification

- `dcm calculate-metrics lib/src/contract/internal/node_patch_fast_path.part.dart lib/src/contract/internal/node_spec_fast_path.part.dart lib/src/contract/internal/snapshot_fast_path.part.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/contract`
- MCP test runner: `test/contract/validated_fast_path_contract_test.dart test/contract/runtime_contract_interfaces_test.dart`
- MCP test runner: `test/public_api/node_patch_semantics_test.dart test/public_api/snapshot_immutability_test.dart test/public_api/validated_boundary_value_test.dart`
- `dart run tool/check_public_api_surface.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Clone inventory for `lib/src/contract` no longer shows the replaced public /
  fast-path family in the same form for the migrated contract-owned families.
- `node_patch_fast_path.part.dart` and `node_spec_fast_path.part.dart`
  improve against the starting hotspot baseline of this step.

## 9. Final Verification

- `dcm calculate-metrics lib/src/contract/internal/node_boundary_schema.dart lib/src/contract/internal/node_boundary_schema_patch.part.dart lib/src/contract/internal/node_boundary_schema_spec.part.dart lib/src/contract/internal/node_boundary_schema_snapshot.part.dart lib/src/contract/internal/node_patch_fast_path.part.dart lib/src/contract/internal/node_spec_fast_path.part.dart lib/src/contract/internal/snapshot_fast_path.part.dart lib/src/contract/node_patch.dart lib/src/contract/node_spec.dart lib/src/contract/snapshot.dart --report-all`
- `dart run tool/analysis/find_similar_clones.dart --clusters --json lib/src/contract`
- MCP test runner: `test/contract/contract_layer_smoke_test.dart test/contract/owned_collections_test.dart test/contract/runtime_contract_interfaces_test.dart test/contract/validated_fast_path_contract_test.dart test/contract/validated_internal_helpers_test.dart`
- MCP test runner: `test/public_api/node_patch_semantics_test.dart test/public_api/snapshot_immutability_test.dart test/public_api/validated_boundary_value_test.dart`
- `dart run tool/check_public_api_surface.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
