---
schema: architecture-design/v4
date: {{DATE}}
commit: {{COMMIT}}
branch: {{BRANCH}}
disposition: {{DISPOSITION}}
outcome: R-001
---

# Design: {{TITLE}}

## Basis

### Sources

| ID | Kind | Locator | Use |
| --- | --- | --- | --- |
| S-001 | {{SOURCE_KIND}} | {{SOURCE_LOCATOR}} | {{SOURCE_USE}} |

### Source Coverage

| Kind | Sources or none |
| --- | --- |
| prior_design | {{PRIOR_DESIGN_SOURCES_OR_NONE}} |
| research | {{RESEARCH_SOURCES_OR_NONE}} |
| plan | {{PLAN_SOURCES_OR_NONE}} |
| user | {{USER_SOURCES_OR_NONE}} |
| repository | {{REPOSITORY_SOURCES_OR_NONE}} |
| other | {{OTHER_SOURCES_OR_NONE}} |

### Evidence

| ID | Source | Locator | Observed fact |
| --- | --- | --- | --- |
| E-001 | S-001 | {{EVIDENCE_LOCATOR}} | {{EVIDENCE_FACT}} |

### Requirements

| ID | Kind | Statement | Basis | Open shape |
| --- | --- | --- | --- | --- |
| R-001 | outcome | {{PRODUCT_OUTCOME}} | S-001, E-001 | {{OUTCOME_OPEN_SHAPE}} |

## Candidate Analysis

- Comparison: `two_or_three`
- Result: `selected F-001`
- Result basis: F-001, F-002, M-001, R-001, E-001

### Forms

| ID | Form | Hard constraints | Main trade-off | Basis |
| --- | --- | --- | --- | --- |
| F-001 | {{FORM_A}} | pass | {{TRADE_OFF_A}} | R-001, E-001 |
| F-002 | {{FORM_B}} | pass | {{TRADE_OFF_B}} | R-001, E-001 |

### Material-Obligation Delta

| ID | Material obligation | F-001 | F-002 | Independent authority |
| --- | --- | --- | --- | --- |
| M-001 | {{MATERIAL_OBLIGATION}} | yes | no | R-001, E-001 |

### Future Pressures

| ID | Pressure | Basis | Treatment | Closure refs | Accepted cost or risk |
| --- | --- | --- | --- | --- | --- |
| P-001 | {{PRESSURE}} | R-001, E-001 | {{PRESSURE_TREATMENT}} | D-001 | {{ACCEPTED_COST_OR_RISK}} |

## Decision Register

### D-001 — {{DECISION_TOPIC}}
- Concerns: `form`, `owner`
- Lock: {{LOCKED_ARCHITECTURE}}
- Open: {{IMPLEMENTATION_FREEDOM}}
- Basis: R-001, E-001
- Form: F-001
- Realizes: M-001
- Depends on: none
- Contract targets: `classification`, `owner`, `unit_family`
- Rationale: {{RATIONALE}}

## Impact Register

None

## Assurance Register

### A-001 — {{ASSURANCE_TOPIC}}
- Verifies: R-001, D-001/owner
- Claim: {{CLAIM}}
- Failure: {{CONCRETE_FAILURE}}
- Oracle: {{DIRECT_ORACLE}}
- Proxy risk: {{PROXY_RISK}}
- Evidence constraints: {{EVIDENCE_CONSTRAINTS}}
- Architecture seam: {{ARCHITECTURE_SEAM}}

## Stop Conditions

### H-001 — {{STOP_CONDITION_TOPIC}}
- Trigger: {{STOP_CONDITION}}
- Invalidates: D-001
- Resolution requires: {{STOP_RESOLUTION}}

## Contract Interface

- Profile: `REFACTOR`
- Obligations: `None`
- ADR Impact: none
- Sources: S-001
- Requirements: R-001
- Commitments: D-001
- Assurance: A-001
- Impacts: none
- Stops: H-001

## Diagrams

None: D-001 makes the relevant ownership and boundary explicit.

## Readiness Matrix

### Architecture Closure

| Concern | Status | Support refs |
| --- | --- | --- |
| owner | closed | D-001 |
| in_scope | {{STATUS}} | {{REFS}} |
| out_of_scope | {{STATUS}} | {{REFS}} |
| source_of_truth | {{STATUS}} | {{REFS}} |
| compatibility | {{STATUS}} | {{REFS}} |
| order | {{STATUS}} | {{REFS}} |
| policy | {{STATUS}} | {{REFS}} |
| dependency | {{STATUS}} | {{REFS}} |
| state_data | {{STATUS}} | {{REFS}} |
| migration_retirement | {{STATUS}} | {{REFS}} |
| temporal | {{STATUS}} | {{REFS}} |
| atomicity | {{STATUS}} | {{REFS}} |
| negative_proof_fixture | {{STATUS}} | {{REFS}} |
| recognition | {{STATUS}} | {{REFS}} |

### Gate Closure

| Gate | Status | Support refs |
| --- | --- | --- |
| Owner-Level Fix | pass | D-001, E-001 |
| Ownership | pass | D-001 |
| Source-Of-Truth Singularity | {{STATUS}} | {{REFS}} |
| Source-Truth Minimality | pass | D-001, M-001 |
| Boundary-Owned Policy | {{STATUS}} | {{REFS}} |
| Dependency Direction | {{STATUS}} | {{REFS}} |
| Solution Proportionality | pass | F-001, F-002, M-001, R-001, E-001 |
| Outcome-Proof Fit | pass | A-001 |
| Verification | pass | A-001 |
| Future Pressure | pass | P-001 |
| Handoff Consumability | pass | CONTRACT, H-001 |
| Negative Proof And Fixture Quarantine | {{STATUS}} | {{REFS}} |
| State/Data Ownership | {{STATUS}} | {{REFS}} |
| Sequenced Migration And Retirement | {{STATUS}} | {{REFS}} |
| Temporal Surface Closure | {{STATUS}} | {{REFS}} |
| All-Or-Nothing Failure Boundary | {{STATUS}} | {{REFS}} |
| Bounded Recognition Scope | {{STATUS}} | {{REFS}} |

## Open Blockers

None
