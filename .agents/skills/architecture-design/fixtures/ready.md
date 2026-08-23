---
schema: architecture-design/v4
date: 2026-08-09
commit: abc1234
branch: test-branch
disposition: READY_FOR_CONTRACT
outcome: R-001
---

# Design: Existing Owner Publishes One Current Result

## Basis

### Sources

| ID | Kind | Locator | Use |
| --- | --- | --- | --- |
| S-001 | repository | `AGENTS.md` | Repository ownership rule |
| S-002 | repository | `.agents/skills/architecture-design/references/design-rules.md` | Current architecture owner and review seam |

### Source Coverage

| Kind | Sources or none |
| --- | --- |
| prior_design | none |
| research | none |
| plan | none |
| user | none |
| repository | S-001, S-002 |
| other | none |

### Evidence

| ID | Source | Locator | Observed fact |
| --- | --- | --- | --- |
| E-001 | S-001 | `line 1` | Repository work preserves one authoritative owner for each stable concern. |
| E-002 | S-002 | `lines 1-2` | The active architecture-design rules own design decisions and review boundaries. |
| E-003 | S-002 | `line 1` | This fixture introduces no mutable state, migration, callback surface, transaction, or multi-effect failure boundary. |
| E-004 | S-002 | `line 2` | This fixture claims no structural negative guarantee, fixture-owned production value, or recognizer. |

### Requirements

| ID | Kind | Statement | Basis | Open shape |
| --- | --- | --- | --- | --- |
| R-001 | outcome | Existing owners publish one current result that consumers can observe after mutation. | S-001, E-001, E-002 | Internal helper and collection shape remain open. |
| R-002 | repository_rule | The existing owner remains the sole durable authority for the result. | S-001, E-001 | Publication mechanics remain open. |
| R-003 | exclusion | Product behavior and public result format do not change. | S-002, E-002 | Internal organization remains open. |

## Candidate Analysis

- Comparison: `two_or_three`
- Result: `selected F-001`
- Result basis: F-001, F-002, M-001, M-002, M-003, R-001, R-002, E-001, E-002

### Forms

| ID | Form | Hard constraints | Main trade-off | Basis |
| --- | --- | --- | --- | --- |
| F-001 | Publish the current result from the existing owner. | pass | Reuses the existing synchronous owner seam. | R-001, R-002, E-001, E-002 |
| F-002 | Copy the result into a second durable registry for consumers. | pass | Adds a second lifecycle and drift risk. | R-001, E-002 |

### Material-Obligation Delta

| ID | Material obligation | F-001 | F-002 | Independent authority |
| --- | --- | --- | --- | --- |
| M-001 | R-001 | yes | yes | R-001 |
| M-002 | Maintain a second durable result registry. | no | yes | none |
| M-003 | Keep publication at the existing owner boundary. | yes | no | R-002, E-001 |

### Future Pressures

| ID | Pressure | Basis | Treatment | Closure refs | Accepted cost or risk |
| --- | --- | --- | --- | --- | --- |
| P-001 | More consumers may need the current result. | S-002, E-002 | absorbed | D-001 | Synchronous fan-out remains an accepted cost until measured evidence requires another form. |

## Decision Register

### D-001 — Ownership and authority
- Concerns: `form`, `owner`, `source_of_truth`, `policy`, `dependency`
- Lock: `ExistingOwner` remains the sole authority and publishes its immutable current result through its existing public seam; consumers depend on that seam rather than a copied registry.
- Open: Internal helper, collection, and notification mechanics remain implementation choices inside the owner boundary.
- Basis: R-001, R-002, E-001, E-002
- Form: F-001
- Realizes: M-001, M-003
- Depends on: none
- Contract targets: `classification`, `owner`, `source_of_truth`, `policy`, `dependency`, `unit_family`
- Rationale: This form satisfies the outcome without adding another durable lifecycle or drift path.

### D-002 — Scope boundary
- Concerns: `in_scope`, `out_of_scope`
- Lock: Current-result publication is in scope; product behavior and public result format are out of scope.
- Open: Internal file and helper decomposition remain open.
- Basis: R-001, R-003, E-002
- Form: F-001
- Realizes: none
- Depends on: D-001
- Contract targets: `scope`, `unit_family`
- Rationale: The architecture change is limited to exposing already-owned state.

### D-003 — Compatibility and observation order
- Concerns: `compatibility`, `order`
- Lock: The public result format remains unchanged, and a direct read after a successful mutation observes the new current value.
- Open: The internal publication implementation remains open as long as the observable order holds.
- Basis: R-001, R-003, E-002
- Form: F-001
- Realizes: none
- Depends on: D-001
- Contract targets: `compatibility`, `order`, `acceptance`, `verification`
- Rationale: The outcome requires freshness, not a new event or callback contract.

## Impact Register

None

## Assurance Register

### A-001 — Current-result freshness
- Verifies: R-001, D-001/owner, D-001/source_of_truth, D-001/policy, D-001/dependency, D-003/compatibility, D-003/order
- Claim: Consumers observe the owner's new current result after a successful mutation.
- Failure: A consumer reads the stale pre-mutation value or reads from a copied authority.
- Oracle: Mutate through the owning public boundary, then read through the consumer-visible owner seam and observe the new value.
- Proxy risk: A mock call, emitted event, or constructed object can pass while the consumer-visible value remains stale.
- Evidence constraints: Exercise the real owning boundary and consumer-visible read path; do not inspect private helper shape or a copied inventory.
- Architecture seam: The existing architecture-design owner boundary and its direct consumer path.

## Stop Conditions

### H-001 — Ownership contradiction
- Trigger: Repository evidence shows another accepted authority or requires a public-format change that conflicts with D-001 or D-003.
- Invalidates: D-001, D-002, D-003, A-001
- Resolution requires: Re-open architecture selection with the conflicting authority or compatibility requirement as canonical evidence.

## Contract Interface

- Profile: `REFACTOR`
- Obligations: `None`
- ADR Impact: none
- Sources: S-001, S-002
- Requirements: R-001, R-002, R-003
- Commitments: D-001, D-002, D-003
- Assurance: A-001
- Impacts: none
- Stops: H-001

## Diagrams

None: D-001 and D-003 make ownership, dependency direction, and observation order explicit without another representation.

## Readiness Matrix

### Architecture Closure

| Concern | Status | Support refs |
| --- | --- | --- |
| owner | closed | D-001 |
| in_scope | closed | D-002 |
| out_of_scope | closed | D-002 |
| source_of_truth | closed | D-001 |
| compatibility | closed | D-003 |
| order | closed | D-003 |
| policy | closed | D-001 |
| dependency | closed | D-001 |
| state_data | not_applicable | E-003 |
| migration_retirement | not_applicable | E-003 |
| temporal | not_applicable | E-003 |
| atomicity | not_applicable | E-003 |
| negative_proof_fixture | not_applicable | E-004 |
| recognition | not_applicable | E-004 |

### Gate Closure

| Gate | Status | Support refs |
| --- | --- | --- |
| Owner-Level Fix | pass | D-001, A-001, E-001 |
| Ownership | pass | D-001, A-001 |
| Source-Of-Truth Singularity | pass | D-001, A-001 |
| Source-Truth Minimality | pass | D-001, A-001, M-002 |
| Boundary-Owned Policy | pass | D-001, A-001 |
| Dependency Direction | pass | D-001, A-001 |
| Solution Proportionality | pass | F-001, F-002, M-001, M-002, M-003, R-001, R-002, E-001 |
| Outcome-Proof Fit | pass | A-001 |
| Verification | pass | A-001 |
| Future Pressure | pass | P-001 |
| Handoff Consumability | pass | CONTRACT, H-001 |
| Negative Proof And Fixture Quarantine | not_applicable | E-004 |
| State/Data Ownership | not_applicable | E-003 |
| Sequenced Migration And Retirement | not_applicable | E-003 |
| Temporal Surface Closure | not_applicable | E-003 |
| All-Or-Nothing Failure Boundary | not_applicable | E-003 |
| Bounded Recognition Scope | not_applicable | E-004 |

## Open Blockers

None
