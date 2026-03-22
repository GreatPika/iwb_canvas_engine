language: russian

# Шаг 19.3. Разделить TxnContext на mutable workspace и derived-state ownership

## 1. Change Mandate

Этот шаг разделяет `TxnContext` на ownership mutable workspace and derived
state materialization so transaction state no longer mixes scene mutation and
index/materialization concerns in one owner.

## 2. Change Boundary

### Included in the Change

- `lib/src/controller/txn_context.dart`

### Not Included in the Change

- Public write boundary
- MutationExecutor ownership
- Invariant sweep
- Interactive stack

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/txn_context.dart`

### Test Files

- `test/controller/internal/change_set_txn_context_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `development_plan/step_19_3_txn_context_workspace_and_derived_state_split.md`

### Analysis Area

- `lib/src/controller/txn_context.dart`
- `test/controller/internal/change_set_txn_context_test.dart`
- `test/controller/internal/spatial_index_cache_test.dart`
- `test/controller/core/scene_controller_copy_on_write_test.dart`
- `test/controller/core/scene_controller_spatial_index_test.dart`
- `test/controller/scene_controller_randomized_txn_test.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one `TxnContext` slice.
- Every modified test must be tied to one listed verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. This step must not introduce a second locator/index cache.
2. Copy-on-write semantics remain protected.
3. Commit candidate behavior remains equivalent.

## 5. Result Requirements

1. `TxnContext` no longer keeps mutable workspace ownership and derived-state
   materialization ownership in one mixed owner body.
2. Copy-on-write and transaction behavior remain equivalent.
3. Current `TxnContext` hotspot improves against the confirmed baseline of
   `RFC 77` and `WMC 118`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- `TxnContext` currently owns mutable scene cloning, layer/node materialization,
  all-node-id materialization, node locator materialization, and derived index
  bookkeeping in one owner.
- The step must reduce this mixed ownership without introducing second caches.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller/txn_context.dart --report-all`
- MCP test runner: `test/controller/internal/change_set_txn_context_test.dart test/controller/internal/spatial_index_cache_test.dart`
- MCP test runner: `test/controller/core/scene_controller_copy_on_write_test.dart test/controller/core/scene_controller_spatial_index_test.dart`
- MCP test runner: `test/controller/scene_controller_randomized_txn_test.dart`
- `dart run tool/check_import_boundaries.dart`

### 6.3 Protected States, Data, or Structures

- Copy-on-write behavior.
- Commit candidate materialization.
- Locator and selection state semantics.

### 6.4 Allowed Semantic Change Zones

- Mutable workspace ownership inside `TxnContext`.
- Derived-state materialization and bookkeeping ownership inside `TxnContext`.

### 6.8 Prohibited

- Adding second caches or sync glue.
- Moving unrelated write-pipeline or invariant logic into this step.
- Hiding mixed ownership behind cosmetic helper extraction.

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

### Slice 1. [ ] Mutable workspace ownership is isolated

#### Slice Contract

Mutable scene workspace ownership is isolated from derived-state materialization
inside the `TxnContext` seam.

#### Change

Разделить mutable workspace responsibilities in `txn_context.dart` from
derived-state materialization responsibilities.

#### Verification

- `dcm calculate-metrics lib/src/controller/txn_context.dart --report-all`
- MCP test runner: `test/controller/internal/change_set_txn_context_test.dart`
- MCP test runner: `test/controller/core/scene_controller_copy_on_write_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- `TxnContext` no longer keeps the replaced mixed workspace / materialization
  body.

### Slice 2. [ ] Derived-state materialization remains exact after the split

#### Slice Contract

Derived-state materialization remains exact after the ownership split and does
not introduce second caches.

#### Change

Перевести remaining derived-state bookkeeping on the new ownership shape and
remove the replaced mixed body.

#### Verification

- `dcm calculate-metrics lib/src/controller/txn_context.dart --report-all`
- MCP test runner: `test/controller/internal/spatial_index_cache_test.dart`
- MCP test runner: `test/controller/core/scene_controller_spatial_index_test.dart`
- MCP test runner: `test/controller/scene_controller_randomized_txn_test.dart`
- `dart run tool/check_import_boundaries.dart`

#### Closure Evidence

- Green run of the listed verifications.
- No second locator/index cache is introduced by the split.

## 9. Final Verification

- `dcm calculate-metrics lib/src/controller/txn_context.dart --report-all`
- MCP test runner: `test/controller/internal/change_set_txn_context_test.dart test/controller/internal/spatial_index_cache_test.dart`
- MCP test runner: `test/controller/core/scene_controller_copy_on_write_test.dart test/controller/core/scene_controller_spatial_index_test.dart`
- MCP test runner: `test/controller/scene_controller_randomized_txn_test.dart`
- `dart run tool/check_import_boundaries.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
