# Change Contract

Contract Mode: FULL
Contract Profile: BEHAVIOR_CHANGE | REFACTOR | SOURCE_OF_TRUTH_DOCS | ANALYZER_RULE
Contract Obligations: none | BUG_FIX, SEAM_MIGRATION, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

### In Scope

### Out of Scope

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for the change, not target-state requirements.

### Entry Paths

### Current Owners

### Existing Checks

### Valid Precedents

### Repository Rules

### Misleading Patterns

## 3. Architecture Decision

### Selected Form

### Ownership

### Seam

### Dependency Direction

### State and Data Ownership

### Entry and Exit Boundaries

### Verification Strategy

### Decision Ledger

Durable decision IDs table, or one no-ID sentence when no later section needs a decision ID.

| ID | Decision | Owner | Proof |
|---|---|---|---|

### Rejected Alternatives

## 4. Execution Guardrails

### Required Order

### Cross-Slice Constraints

### Seam Migration

### Forbidden Moves

### Deferred Broad Verification

## 5. Proof Plan

Self-contained reusable proof IDs, or one sentence that all proof is slice-local and not used by the final gate.

### P1. Purpose

```sh
command-or-check
```

Expected signal.

## 6. Vertical Slices

### Slice 1. [ ] Title

#### Implements

#### Obligations Covered

#### Files

- File role: `path` — slice-local responsibility.

#### Change

#### Proof

#### Closure

## 7. Final Gate

### Run Proof Set

List the concrete proof IDs from section 5 that must pass before closure.

### Done When

- all referenced Decision Ledger decisions have passing proof;
- all Contract Obligations are satisfied;
- all retired seams have negative proof;
- no out-of-scope files were changed;
- whitespace validation passes.
