---
schema: architecture-design/v4
date: 2026-08-09
commit: abc1234
branch: architecture-choice
disposition: BLOCKED
outcome: R-001
---

# Design: Product Trade-Off Requires A Decision

## Basis

### Sources

| ID | Kind | Locator | Use |
| --- | --- | --- | --- |
| S-001 | user | user request | Required product outcome |
| S-002 | repository | `.agents/skills/architecture-design/references/design-rules.md` | Existing architecture compatibility surface |

### Source Coverage

| Kind | Sources or none |
| --- | --- |
| prior_design | none |
| research | none |
| plan | none |
| user | S-001 |
| repository | S-002 |
| other | none |

### Evidence

| ID | Source | Locator | Observed fact |
| --- | --- | --- | --- |
| E-001 | S-002 | `line 1` | The current design workflow can preserve its compatibility boundary without durable replay. |
| E-002 | S-002 | `lines 1-2` | Durable replay would require a new persisted authority and migration contract. |

### Requirements

| ID | Kind | Statement | Basis | Open shape |
| --- | --- | --- | --- | --- |
| R-001 | outcome | Consumers receive the current result. | S-001, E-001 | Whether historical replay is part of the product contract remains undecided. |
| R-002 | constraint | Existing synchronous consumers remain compatible. | S-002, E-001 | Internal implementation remains open. |

## Candidate Analysis

- Comparison: `blocked`
- Result: `blocked B-001`
- Result basis: B-001, F-001, F-002, M-001, M-002, P-001, R-001, R-002, E-001, E-002

### Forms

| ID | Form | Hard constraints | Main trade-off | Basis |
| --- | --- | --- | --- | --- |
| F-001 | Preserve the synchronous current-result seam only. | pass | Lowest complexity but no durable replay. | R-001, R-002, E-001 |
| F-002 | Add a persisted event authority behind a compatibility adapter. | pass | Enables replay but adds durable state, migration, and operations cost. | R-001, R-002, E-001, E-002 |

### Material-Obligation Delta

| ID | Material obligation | F-001 | F-002 | Independent authority |
| --- | --- | --- | --- | --- |
| M-001 | R-002 | yes | yes | R-002 |
| M-002 | Own and migrate a durable replay history. | no | yes | none |

### Future Pressures

| ID | Pressure | Basis | Treatment | Closure refs | Accepted cost or risk |
| --- | --- | --- | --- | --- | --- |
| P-001 | Durable replay may become a required product capability. | R-001, E-001, E-002 | deferred | B-001 | Product scope remains unresolved until the user chooses the replay contract. |

## Open Blockers

### B-001 — Replay contract
- Kind: `user_decision`
- Gate: `Candidate Comparison`
- Need: Decide whether durable historical replay is an accepted product outcome or whether only the current result is required.
- Blocks because: F-001 and F-002 are both viable but have incomparable product capability and lifecycle cost.
- Resolution requires: An explicit user decision on durable replay; implementation preference cannot resolve the trade-off.
- Related: R-001, R-002, F-001, F-002, M-001, M-002, P-001, E-001, E-002
