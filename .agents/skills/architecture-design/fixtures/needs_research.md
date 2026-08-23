---
schema: architecture-design/v4
date: 2026-08-09
commit: abc1234
branch: research-blocker
disposition: BLOCKED
outcome: R-001
---

# Design: Ownership Requires Repository Research

## Basis

### Sources

| ID | Kind | Locator | Use |
| --- | --- | --- | --- |
| S-001 | repository | `AGENTS.md` | Repository ownership policy |
| S-002 | repository | `.agents/skills/architecture-design/references/design-rules.md` | Active architecture-design authority |

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
| E-001 | S-001 | `line 1` | Repository rules require one accepted owner for a durable concern. |
| E-002 | S-002 | `lines 1-2` | Active design rules require repository evidence before selecting an authority. |

### Requirements

| ID | Kind | Statement | Basis | Open shape |
| --- | --- | --- | --- | --- |
| R-001 | outcome | Expose one authoritative current value to consumers. | S-001, S-002, E-001, E-002 | The owner cannot remain open. |

## Candidate Analysis

- Comparison: `blocked`
- Result: `blocked B-001`
- Result basis: B-001, F-001, F-002, M-001, M-002, P-001, R-001, E-001, E-002

### Forms

| ID | Form | Hard constraints | Main trade-off | Basis |
| --- | --- | --- | --- | --- |
| F-001 | Treat AGENTS.md as the direct authority. | pass | May overlook a more specific accepted owner. | R-001, E-001 |
| F-002 | Treat the architecture-design rules as the direct authority. | pass | May confuse workflow ownership with product ownership. | R-001, E-002 |

### Material-Obligation Delta

| ID | Material obligation | F-001 | F-002 | Independent authority |
| --- | --- | --- | --- | --- |
| M-001 | R-001 | yes | yes | R-001 |
| M-002 | Resolve the more specific durable authority. | no | yes | E-001, E-002 |

### Future Pressures

| ID | Pressure | Basis | Treatment | Closure refs | Accepted cost or risk |
| --- | --- | --- | --- | --- | --- |
| P-001 | A more specific accepted authority may exist. | R-001, E-001, E-002 | deferred | B-001 | Candidate comparison remains blocked until repository research resolves the authority. |

## Open Blockers

### B-001 — Conflicting authority
- Kind: `research`
- Gate: `Source Authority`
- Need: Determine which repository surface is the accepted owner of the durable value and whether the other surface is a mirror, cache, or stale claim.
- Blocks because: Candidate forms cannot be compared safely while two incompatible authority claims remain unresolved.
- Resolution requires: Accepted repository evidence or an applicable ADR that establishes one owner and the lifecycle of the other surface.
- Related: R-001, E-001, E-002, F-001, F-002, M-001, M-002, P-001
