# Design: Topic

---
date: YYYY-MM-DD
designer: Codex
commit: SHORT_COMMIT
branch: CURRENT_BRANCH
design_question: "Original user request"
---

## Disposition

READY_FOR_CONTRACT | ARCHITECTURE_GATE | NEEDS_RESEARCH | DESIGN_NOT_REQUIRED

## Product Outcome

Plain-language result and non-goals.

## Target Contract Classification

- Profile: ...
- Obligations: ...

## Research Inputs

- `.research/YYYY-MM-DD-topic.md` - fact supplied.
- Or: None provided; direct repository evidence used.

## Repository Evidence

`Evidence Consequence Link`: each fact below must state the decision, boundary,
unit, proof surface, or review consequence it supports. Use exact `path:line`
evidence for stable text and name exceptions for new files, generated outputs,
or command/config surfaces without stable lines.

- `path:line` - observed fact -> supported decision/boundary/unit/proof/review consequence.

## Design Form Candidates

### Candidate A. Name

- Form:
- Why it could work:
- Gate failures or risks:

### Candidate B. Name

- Form:
- Why it could work:
- Gate failures or risks:

## Known Future Pressures

| Pressure | Evidence | How the selected form responds | Accepted cost or risk |
|---|---|---|---|

## Selected Form

The chosen form and why it is the best fit.

## Decision Trace

Preserve `Decision Chain Of Custody`: source inputs and locked decisions must
map to the future contract field, execution unit, or proof surface that carries
them forward.

| Decision ID | Decision | Evidence | Contract handoff target |
|---|---|---|---|
| D1 | ... | `path:line` | `Boundaries.Owner` / `Boundaries.Source of Truth` / `Unit N` / proof surface |

## Outcome-Proof Fit

| Claim | Direct outcome | Proxy risk | Required proof surface or strategy |
|---|---|---|---|
| ... | direct outcome, or checked proxy when explicitly claimed | weaker signal that could pass while the claim is false | surface or strategy that exposes a false claimed outcome |

## Hard Gate Check

| Gate | Result | Evidence |
|---|---|---|
| Root cause | pass/fail | ... |
| Ownership | pass/fail | ... |
| Source of truth | pass/fail | ... |
| Boundary | pass/fail | ... |
| Dependency direction | pass/fail | ... |
| State/data | pass/fail/not applicable | ... |
| Seam | pass/fail/not applicable | ... |
| Temporal/reentrancy | pass/fail/not applicable | ... |
| All-or-nothing behavior | pass/fail/not applicable | ... |
| Outcome-Proof Fit | pass/fail/not applicable | ... |
| Verification | pass/fail | ... |
| Future pressure | pass/fail/not found after targeted inspection | ... |

## Lock-Required Facts

- Owner:
- Owning layer/module/document family:
- Seam:
- Dependency/import direction:
- State/data ownership:
- Entry boundaries:
- Exit boundaries:
- File placement basis:
- Execution order constraints:
- Temporal/reentrancy invariant and callback surfaces:
- All-or-nothing irreversible point and failure boundary:
- Rejected alternatives:
- Verification strategy:

## Diagram Need Assessment

| Design question | Needed? | Diagram kind | Reason |
|---|---:|---|---|
| Does the design change ownership, layer, package, or component boundaries? | yes/no | c4/none | ... |
| Does it change data flow, state ownership, cache ownership, resource movement, or lifecycle movement? | yes/no | data_flow/none | ... |
| Does it depend on call order, lifecycle order, sync/async ordering, failure ordering, or migration order? | yes/no | sequence/none | ... |
| Does it introduce or alter observer/listener/callback delivery, guard windows, public-state publication, or reentrancy-sensitive ordering? | yes/no | sequence/none | ... |
| Does it introduce or alter modes, statuses, terminal states, sessions, or transition rules? | yes/no | state/none | ... |
| Does it create, replace, migrate, or retire a shared seam? | yes/no | c4/data_flow/sequence/none | ... |
| Does it change public API consumer flow, payload shape, or compatibility behavior? | yes/no | sequence/data_flow/none | ... |
| Does it introduce or change analyzer, guardrail, or structural-recognition pipeline behavior? | yes/no | data_flow/sequence/none | ... |

## Provisional Diagrams

Include Mermaid diagrams only when the assessment says they are needed.

## Source-Of-Truth Impact

`Source-Of-Truth Singularity`: durable meaning must have one owning source of
truth and a real human or machine consumer. Name cache/performance duplication
only when the invariant and proof strategy are explicit.

Name future docs, diagrams, registries, contracts, or roadmap files that a later
Change Contract must update. Do not edit them now.

## Verification Impact

Name future tests, analyzers, guardrails, docs checks, semantic searches, or
other proof surfaces that a later Change Contract should use. Do not edit them
now.

## Verification Strategy

Describe proof strategy appropriate to the target profile and obligations.

## Change Contract Handoff

- Required profile:
- Required obligations:
- Decision IDs / Decision Trace rows to preserve:
- Evidence to cite:
- Contract constraints or sequencing facts:
- Required proof surfaces:

## Open Decisions

Only decisions that block or constrain the next step.
