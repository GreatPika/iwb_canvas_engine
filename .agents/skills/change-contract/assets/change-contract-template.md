# Change Contract

If `4B. Architecture Decision Gate` is filled, stop after section 4.

## 1. Change Mandate

One short statement of the result this change must produce.

## 2. Change Boundary

### Included in the Change

- ...

### Not Included in the Change

- ...

## 3. Surrounding Code Review

### Inspected Artifacts

- `<path>` — `<what it reveals>`

### Current Entry Path

- `<entrypoint / trigger / call chain>`

### Current Owner

- `<module / layer / package / subsystem>`

### Adjacent Abstractions

- `<neighbor abstraction in the same layer>`

### Existing Tests

- `<test file or suite>` — `<what it already proves>`

### Analogous Implementation Path

- `<path>` — `<why it is the closest valid precedent>`

### Governing Repository Rules

- `<rule source>` — `<rule>`

### Rejected Misleading Local Patterns

- `<pattern or path>` — `<why it is the wrong owner, wrong level, or wrong seam>`

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

- ...

#### Selected Architectural Form

- ...

#### Owning Layer or Module

- ...

#### Dependency Direction

- ...

#### State and Data Ownership

- ...

#### Entry and Exit Boundaries

- ...

#### Permitted Extension Seam

- ...

#### Rejected Alternatives

- ... — ...
- ... — ...

#### Why This Level Is Correct

- ...

### 4B. Architecture Decision Gate

#### Recommended Form

- ...

#### Supporting Evidence

- ... — ...

#### Alternatives Considered

- ... — ...

#### User Decision Required

- ...

## 5. Locked Decisions

1. ...
2. ...
3. ...

## 6. Result Requirements

1. ...
2. ...
3. ...

## 7. Execution Order and Gates

### Required Order

- ...

### Successor Seam and Retirement Gates

- ... — ...

### Deferred Broad Verification

- ... — ...

## 8. File Map

### Implementation Files

- ...

### Test Files

- ...

### Fixtures and Supporting Data

- ...

### Registry, Inventory, and Workflow Files

- ...

### Analysis Area

- ...

## 9. Implementation Rules

### Protected Invariants

- ...

### Required Proof

- behavioral proof: ...
- structural proof: ...
- for bug fixes, regressions, false positives, false negatives, and invariant-enforcement gaps: one failing reproducer first, plus 1 to 3 guard tests for neighboring branches of the same contract
- for refactors: existing locking tests must be named or missing characterization tests must be added before structural edits, plus 1 to 3 guard tests for neighboring branches when needed

### Allowed Change Surface

- ...

### Forbidden Moves

- ...

### Optional: Recognition Forms That Must Be Supported

- ...

### Optional: Allowed Forms That Are Not Violations

- ...

### Optional: Resolution Rules

- ...

## 10. Vertical Slices

### Slice N. [ ] <Short Title>

#### Slice Contract

...

#### Change

...

#### Behavioral Verification

- ...

#### Structural Verification

- ...

#### Fixtures Used

- ...

#### Positive Scenarios

- ...

#### Negative Scenarios

- ...

#### Closure Evidence

- ...

## 11. Final Verification

- ...

## 12. Acceptance Criteria

- ...
