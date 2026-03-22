language: russian

# Шаг 19.4. Разрезать invariant sweep на атомарные owners и proof surface

## 1. Change Mandate

Этот шаг разрезает invariant sweep в `scene_invariants.dart` на атомарные
owners and proof surface without changing committed-store invariant semantics.

## 2. Change Boundary

### Included in the Change

- `lib/src/controller/scene_invariants.dart`

### Not Included in the Change

- Commit lifecycle outside invariant sweep
- `TxnContext` ownership split
- Interactive stack

## 3. File Map and Analysis Areas

### Implementation Files

- `lib/src/controller/scene_invariants.dart`

### Test Files

- `test/controller/scene_invariants_test.dart`
- `test/controller/scene_snapshot_invariant_assertions_test.dart`
- `test/controller/support/scene_snapshot_invariant_assertions.dart`

### Fixture and Supporting Data Files

- `analysis_options.yaml`
- `tool/invariant_registry.dart`
- `development_plan/step_19_4_scene_invariants_decomposition_and_proof_surface.md`

### Analysis Area

- `lib/src/controller/scene_invariants.dart`
- `test/controller/scene_invariants_test.dart`
- `test/controller/scene_snapshot_invariant_assertions_test.dart`
- `test/controller/support/scene_snapshot_invariant_assertions.dart`
- `tool/invariant_registry.dart`

### Outside the Change Boundary

- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule

- Every modified implementation file must be tied to one invariant slice.
- Every modified test or proof-support file must be tied to one listed
  verification.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. Critical and non-critical invariant tiers remain explicit.
2. Invariant semantics remain behaviorally equivalent.
3. Invariant coverage discipline remains enforced through
   `tool/invariant_registry.dart` and `check_invariant_coverage.dart`.

## 5. Result Requirements

1. Invariant sweep no longer keeps unrelated invariant families inside one giant
   body.
2. Invariant semantics and proof coverage remain equivalent.
3. Current hotspot improves against the confirmed baseline:
   `txnCollectStoreInvariantViolations(...): CC 25, params 9, SLOC 132`.

## 6. Implementation Specification

### 6.1 Analysis Scope

- The current hotspot is concentrated in
  `txnCollectStoreInvariantViolations(...)`.
- The step must split invariant ownership by invariant family or proof surface
  rather than by cosmetic helper extraction.

### 6.2 Target Verification Units

- `dcm calculate-metrics lib/src/controller/scene_invariants.dart --report-all`
- MCP test runner: `test/controller/scene_invariants_test.dart test/controller/scene_snapshot_invariant_assertions_test.dart`
- `dart run tool/check_invariant_coverage.dart`

### 6.3 Protected States, Data, or Structures

- Invariant semantics.
- Critical vs non-critical invariant distinction.
- Invariant registry coverage.

### 6.4 Allowed Semantic Change Zones

- Invariant family ownership inside `scene_invariants.dart`
- Proof-surface decomposition for invariant checks

### 6.8 Prohibited

- Changing invariant semantics to reduce metrics.
- Leaving the same mixed invariant sweep hidden behind private wrappers.
- Breaking invariant coverage discipline.

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

### Slice 1. [ ] Invariant families have separate owners

#### Slice Contract

The invariant sweep is decomposed into separate owners per invariant family or
proof surface.

#### Change

Разрезать `txnCollectStoreInvariantViolations(...)` into atomic invariant
owners without changing invariant meaning.

#### Verification

- `dcm calculate-metrics lib/src/controller/scene_invariants.dart --report-all`
- MCP test runner: `test/controller/scene_invariants_test.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Giant mixed invariant sweep is no longer present in the same form.

### Slice 2. [ ] Proof surface remains exact after the split

#### Slice Contract

Invariant proof surface remains exact after the decomposition.

#### Change

Update proof-support wiring and invariants coverage linkage to match the new
ownership shape.

#### Verification

- MCP test runner: `test/controller/scene_snapshot_invariant_assertions_test.dart`
- `dart run tool/check_invariant_coverage.dart`

#### Closure Evidence

- Green run of the listed verifications.
- Invariant coverage remains green after the split.

## 9. Final Verification

- `dcm calculate-metrics lib/src/controller/scene_invariants.dart --report-all`
- MCP test runner: `test/controller/scene_invariants_test.dart test/controller/scene_snapshot_invariant_assertions_test.dart`
- `dart run tool/check_invariant_coverage.dart`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
